import Foundation

// MARK: - Entry info

struct EntryInfo {
    var name: String
    var type: EntryType
    var inode: UInt64
    var device: UInt32
    var linkCount: UInt32
    var allocatedSize: Int64

    enum EntryType { case file, directory, symlink, other }
}

// MARK: - Package extensions

private let packageExtensions: Set<String> = [
    "app", "bundle", "framework", "plugin", "kext",
    "docx", "xlsx", "pptx", "pages", "numbers", "key",
    "pkg", "xpc", "qlgenerator", "prefpane", "mdimporter",
    "driver", "dext", "systemextension", "appex",
]

// MARK: - BulkDirScanner

enum BulkDirScanner {
    private static let maxEntriesPerDir = 4096

    // MARK: - Test seams (test-only)
    //
    // These are `nonisolated(unsafe)` by design: the test suite runs serially and
    // mutates them only from a single test thread, so no synchronization is needed.
    // They must not be touched by production code.

    /// When set, `entries(atPath:)` sleeps for `seconds` if the path ends with
    /// `pathSuffix` — used to exercise the timeout/sacrificial-thread path.
    nonisolated(unsafe) static var _testDelay: (pathSuffix: String, seconds: Double)? = nil

    /// When set, `timedEntries` uses this timeout instead of its default.
    nonisolated(unsafe) static var _timeoutSecondsOverride: Double? = nil

    /// Holds the syscall result across the sacrificial-thread / waiter boundary.
    /// The DispatchSemaphore signal/wait pair establishes the happens-before, but
    /// the lock keeps it free of data-race diagnostics and safe if abandoned.
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [EntryInfo]?
        var value: [EntryInfo]? {
            get { lock.lock(); defer { lock.unlock() }; return stored }
            set { lock.lock(); stored = newValue; lock.unlock() }
        }
    }

    /// Directories under a cloud-sync provider are the *only* ones whose
    /// `getattrlistbulk` can block uninterruptibly in the kernel — iCloud Drive
    /// ("Mobile Documents") and third-party FileProvider services mounted under
    /// "~/Library/CloudStorage". Local APFS directories never hang (and other
    /// devices are excluded by the scanner's mount-boundary gate), so they must
    /// not pay for the sacrificial-thread guard — that overhead, multiplied over
    /// millions of directories, is what made full-disk scans crawl.
    private static func isHangProne(_ path: String) -> Bool {
        path.contains("/Mobile Documents") || path.contains("/Library/CloudStorage")
    }

    /// Enumerate a directory, guarding only the directories that can actually
    /// hang. Local directories are read directly on the calling worker (fast,
    /// zero dispatch). Cloud/FileProvider directories go through a sacrificial
    /// thread with a hard deadline: the syscall runs on one GCD worker while a
    /// second waits on it with a timeout and abandons it if it never returns.
    ///
    /// Returns nil only when a guarded directory blows its deadline (caller skips
    /// it). Crucially there is no per-directory Swift `Task`/timer: an uncancelled
    /// timer per directory accumulates into hundreds of thousands of live timers
    /// on a large scan and throttles the whole concurrency runtime.
    static func timedEntries(atPath path: String, timeoutSeconds: Double = 5) async -> [EntryInfo]? {
        // Fast path: local directory, read inline. Test seams force the guarded
        // path so the timeout/abandon logic stays exercised by the suite.
        if _testDelay == nil, _timeoutSecondsOverride == nil, !isHangProne(path) {
            return entries(atPath: path)
        }

        let timeout = _timeoutSecondsOverride ?? timeoutSeconds
        return await withCheckedContinuation { (cont: CheckedContinuation<[EntryInfo]?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let sem = DispatchSemaphore(value: 0)
                let box = ResultBox()
                DispatchQueue.global(qos: .userInitiated).async {
                    box.value = entries(atPath: path)
                    sem.signal()
                }
                if sem.wait(timeout: .now() + timeout) == .timedOut {
                    cont.resume(returning: nil)       // abandon the hung worker
                } else {
                    cont.resume(returning: box.value)
                }
            }
        }
    }

    /// Treat package directories (.app, .framework, …) as leaf "directories the user
    /// thinks of as files" only at presentation level; the scanner must still descend
    /// into them to measure their size, so they are reported as `.directory` here and
    /// flagged via `isPackageName`.
    static func isPackageName(_ name: String) -> Bool {
        packageExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    static func entries(atPath path: String) -> [EntryInfo] {
        // Test-only delay hook (see `_testDelay`).
        if let delay = _testDelay, path.hasSuffix(delay.pathSuffix) {
            Thread.sleep(forTimeInterval: delay.seconds)
        }

        // Try getattrlistbulk via C bridge.
        // Allocate without zero-fill — only indices 0..<count are read, and the C
        // side fully populates each written entry. Deallocated unconditionally.
        let cEntries = UnsafeMutableBufferPointer<BREntry>.allocate(capacity: maxEntriesPerDir)
        defer { cEntries.deallocate() }

        let count = br_scan_directory(path, cEntries.baseAddress, Int32(maxEntriesPerDir))
        if count >= 0 {
            // A completely full buffer may mean the directory was truncated;
            // re-read with the unbounded fallback to avoid silently dropping entries.
            if Int(count) == maxEntriesPerDir {
                return fallbackEntries(atPath: path)
            }
            return (0 ..< Int(count)).compactMap { swiftEntry(from: cEntries[$0]) }
        }

        // Fallback: readdir via FileManager + lstat
        return fallbackEntries(atPath: path)
    }

    // MARK: - BREntry → EntryInfo

    private static func swiftEntry(from c: BREntry) -> EntryInfo? {
        var c = c
        let name = withUnsafeBytes(of: &c.name) { buf -> String in
            guard let base = buf.baseAddress else { return "" }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
        guard !name.isEmpty else { return nil }

        let entryType: EntryInfo.EntryType
        switch c.type {
        case UInt32(BR_TYPE_DIR): entryType = .directory
        case UInt32(BR_TYPE_LNK): entryType = .symlink
        case UInt32(BR_TYPE_REG): entryType = .file
        default: entryType = .other
        }

        return EntryInfo(
            name: name,
            type: entryType,
            inode: c.inode,
            device: c.devid,
            linkCount: c.nlink,
            allocatedSize: c.alloc_size
        )
    }

    // MARK: - Fallback

    private static func fallbackEntries(atPath path: String) -> [EntryInfo] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []

        return names.compactMap { name -> EntryInfo? in
            var sb = Darwin.stat()
            guard Darwin.lstat(path + "/" + name, &sb) == 0 else { return nil }
            let mode = sb.st_mode & S_IFMT

            let entryType: EntryInfo.EntryType
            if mode == S_IFLNK {
                entryType = .symlink
            } else if mode == S_IFDIR {
                entryType = .directory
            } else if mode == S_IFREG {
                entryType = .file
            } else {
                entryType = .other
            }

            return EntryInfo(
                name: name,
                type: entryType,
                inode: UInt64(sb.st_ino),
                device: UInt32(bitPattern: sb.st_dev),
                linkCount: UInt32(sb.st_nlink),
                allocatedSize: Int64(sb.st_blocks) * 512
            )
        }
    }
}
