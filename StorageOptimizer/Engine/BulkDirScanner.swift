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

    /// Resume-once latch so whichever of {result, deadline} fires first wins.
    private final class OnceFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        func tryFire() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if fired { return false }
            fired = true
            return true
        }
    }

    /// Enumerate a directory with a hard deadline.
    ///
    /// `getattrlistbulk` can block *uninterruptibly in the kernel* on dead
    /// FileProvider mounts (iCloud Drive "Mobile Documents", CloudStorage) and
    /// stalled network filesystems — no cancellation reaches it. The only safe
    /// defense is to issue the syscall on a sacrificial GCD thread and abandon
    /// it on timeout; a dead subtree then costs one deadline instead of hanging
    /// the whole scan forever.
    ///
    /// This must be async (suspending), NOT a semaphore wait: blocking the
    /// caller’s cooperative-pool thread starves the very GCD work it waits on
    /// once all pool threads are blocked, causing spurious timeouts and silently
    /// dropped subtrees.
    ///
    /// Returns nil when the deadline passes (caller should skip the directory).
    static func timedEntries(atPath path: String, timeoutSeconds: Double = 5) async -> [EntryInfo]? {
        let timeout = _timeoutSecondsOverride ?? timeoutSeconds
        return await withCheckedContinuation { (cont: CheckedContinuation<[EntryInfo]?, Never>) in
            let once = OnceFlag()
            DispatchQueue.global(qos: .userInitiated).async {
                let result = entries(atPath: path)
                if once.tryFire() { cont.resume(returning: result) }
            }
            // The deadline must NOT run on the GCD pool: when a burst of dead
            // directories hangs hundreds of sacrificial workers, the pool is
            // exhausted and asyncAfter timers never fire — freezing the scan.
            // Task.sleep runs on the Swift Concurrency runtime, which the GCD
            // clog cannot block.
            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(for: .seconds(timeout))
                if once.tryFire() { cont.resume(returning: nil) }
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
