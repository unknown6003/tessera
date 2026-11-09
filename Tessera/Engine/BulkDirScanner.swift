import Foundation

// MARK: - Entry info

struct EntryInfo: Sendable {
    var name: String
    var type: EntryType
    var inode: UInt64
    var device: UInt32
    var linkCount: UInt32
    var logicalSize: Int64
    var allocatedSize: Int64
    var flags: UInt32
    /// Directory modification time in nanoseconds. Bumps when entries are
    /// added/removed/renamed — the version signal for incremental re-scan.
    var modTime: Int64 = 0

    /// SF_DATALESS (0x40000000): the item is online-only / not materialized.
    /// For files this means ~0 local disk; for directories it means descending
    /// would force a slow provider round-trip.
    var isDataless: Bool { (flags & 0x40000000) != 0 }

    enum EntryType: Sendable { case file, directory, symlink, other }
}

// MARK: - Package extensions

private let packageExtensions: Set<String> = [
    "app", "bundle", "framework", "plugin", "kext",
    "docx", "xlsx", "pptx", "pages", "numbers", "key",
    "pkg", "xpc", "qlgenerator", "prefpane", "mdimporter",
    "driver", "dext", "systemextension", "appex",
]

struct DirectoryListing: Sendable {
    var entries: [EntryInfo]
    var unreadablePaths: [String] = []
}

final class DirectoryReadSession: @unchecked Sendable {
    struct TestRead: Sendable {
        let delaySeconds: Double
        let timeoutSeconds: Double
    }

    let testReads: [String: TestRead]
    let testDatalessSuffix: String?
    private let lock = NSLock()
    private var stopped = false
    private var failedProviders = Set<String>()
    private var providerAttempts = 0

    init(testReads: [String: TestRead] = [:], testDatalessSuffix: String? = nil) {
        self.testReads = testReads
        self.testDatalessSuffix = testDatalessSuffix
    }

    var isCancelled: Bool { lock.withLock { stopped } }
    var providerReadAttempts: Int { lock.withLock { providerAttempts } }
    func cancel() { lock.withLock { stopped = true } }

    func canRead(_ provider: String?) -> Bool {
        lock.withLock {
            guard !stopped, provider.map({ !failedProviders.contains($0) }) ?? true else { return false }
            if provider != nil { providerAttempts += 1 }
            return true
        }
    }

    func hold(_ provider: String?) {
        guard let provider else { return }
        _ = lock.withLock { failedProviders.insert(provider) }
    }
}

// MARK: - BulkScratch

/// Per-thread reusable buffers for one directory enumeration. Allocated once and
/// reused across every directory a thread visits, so the scan stops paying a
/// fresh ~MB allocation (and the page faults that come with touching cold pages)
/// for each of a million directories. One instance per worker; never shared
/// between threads concurrently.
final class BulkScratch {
    /// Maximum decoded entries per batch. Large folders continue on the same descriptor.
    static let entryCapacity = 1024
    /// Kernel listing buffer for getattrlistbulk. Larger = fewer syscalls.
    static let readBufferBytes = 512 * 1024

    let entryBuffer: UnsafeMutableBufferPointer<BREntry>
    let readBuffer: UnsafeMutableRawPointer

    let session: DirectoryReadSession
    let onBatch: @Sendable () -> Void

    init(session: DirectoryReadSession = DirectoryReadSession(), entryCapacity: Int = BulkScratch.entryCapacity,
         onBatch: @escaping @Sendable () -> Void = {}) {
        precondition((1...BulkScratch.entryCapacity).contains(entryCapacity))
        self.session = session
        self.onBatch = onBatch
        entryBuffer = UnsafeMutableBufferPointer<BREntry>.allocate(capacity: entryCapacity)
        readBuffer = UnsafeMutableRawPointer.allocate(byteCount: BulkScratch.readBufferBytes, alignment: 16)
    }

    deinit {
        entryBuffer.deallocate()
        readBuffer.deallocate()
    }
}

// MARK: - BulkDirScanner

enum BulkDirScanner {

    private static let helperSlots = DispatchSemaphore(value: 4)

    /// Holds the syscall result across the sacrificial-thread / waiter boundary.
    /// The DispatchSemaphore signal/wait pair establishes the happens-before, but
    /// the lock keeps it free of data-race diagnostics and safe if abandoned.
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: DirectoryListing?
        var value: DirectoryListing? {
            get { lock.lock(); defer { lock.unlock() }; return stored }
            set { lock.lock(); stored = newValue; lock.unlock() }
        }
    }

    private static func providerRoot(_ path: String) -> String? {
        for marker in ["/Library/CloudStorage", "/Mobile Documents"] {
            guard let range = path.range(of: marker),
                  range.upperBound == path.endIndex || path[range.upperBound] == "/" else { continue }
            let root = String(path[..<range.upperBound])
            if marker == "/Mobile Documents" { return root }
            let tail = path[range.upperBound...].split(separator: "/")
            return tail.first.map { root + "/" + $0 } ?? root
        }
        return nil
    }

    private static func isHangProne(_ path: String) -> Bool { providerRoot(path) != nil }

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
    static func timedEntries(atPath path: String, timeoutSeconds: Double = 5,
                             session: DirectoryReadSession = DirectoryReadSession()) async -> [EntryInfo]? {
        let testRead = session.testReads[path]
        if testRead == nil, !isHangProne(path) {
            return entriesResult(atPath: path, scratch: BulkScratch(session: session))?.entries
        }

        let timeout = testRead?.timeoutSeconds ?? timeoutSeconds
        return await withCheckedContinuation { (cont: CheckedContinuation<[EntryInfo]?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: listingWithDeadline(atPath: path, timeoutSeconds: timeout,
                                                          session: session, onBatch: {})?.entries)
            }
        }
    }

    /// Worker-thread enumeration of a directory. Reads inline (fast, zero
    /// dispatch) for local directories; for hang-prone cloud/FileProvider
    /// directories, or an exact path with a session-owned test read, uses a hard
    /// deadline and returns nil if the directory blows it (caller skips it).
    ///
    /// MUST be called from a dedicated worker thread, never the Swift cooperative
    /// pool: the deadline path blocks the calling thread while it waits.
    static func workerEntries(atPath path: String, scratch: BulkScratch) -> [EntryInfo]? {
        workerListing(atPath: path, scratch: scratch)?.entries
    }

    static func workerListing(atPath path: String, scratch: BulkScratch) -> DirectoryListing? {
        let provider = providerRoot(path)
        guard scratch.session.canRead(provider) else { return nil }
        let testRead = scratch.session.testReads[path]
        if testRead != nil || provider != nil {
            let timeout = testRead?.timeoutSeconds ?? 10
            return listingWithDeadline(atPath: path, timeoutSeconds: timeout,
                                       session: scratch.session, onBatch: scratch.onBatch)
        }
        return entriesResult(atPath: path, scratch: scratch)
    }

    private static func listingWithDeadline(atPath path: String, timeoutSeconds: Double,
                                            session: DirectoryReadSession,
                                            onBatch: @escaping @Sendable () -> Void) -> DirectoryListing? {
        let provider = providerRoot(path)
        guard session.canRead(provider) else { return nil }
        let deadline = DispatchTime.now() + timeoutSeconds
        while helperSlots.wait(timeout: min(deadline, .now() + .milliseconds(50))) == .timedOut {
            if session.isCancelled { return nil }
            if DispatchTime.now() >= deadline {
                session.hold(provider)
                return nil
            }
        }
        let sem = DispatchSemaphore(value: 0)
        let box = ResultBox()
        DispatchQueue.global(qos: .utility).async {
            defer { helperSlots.signal(); sem.signal() }
            let scratch = BulkScratch(session: session, onBatch: onBatch)
            box.value = entriesResult(atPath: path, scratch: scratch)
        }
        // Poll only the owned read within its fixed deadline, so cancellation
        // does not wait for an uninterruptible provider call.
        while sem.wait(timeout: min(deadline, .now() + .milliseconds(50))) == .timedOut {
            if session.isCancelled { return nil }
            if DispatchTime.now() >= deadline {
                session.hold(provider)
                return nil
            }
        }
        return box.value
    }

    /// Treat package directories (.app, .framework, …) as leaf "directories the user
    /// thinks of as files" only at presentation level; the scanner must still descend
    /// into them to measure their size, so they are reported as `.directory` here and
    /// flagged via `isPackageName`.
    static func isPackageName(_ name: String) -> Bool {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return false }
        return packageExtensions.contains(String(name[name.index(after: dot)...]).lowercased())
    }

    /// Convenience for callers without a reusable scratch (tests, the cloud
    /// deadline path). Allocates a one-shot scratch; the hot scan path uses
    /// `entries(atPath:scratch:)` with a per-worker buffer instead.
    static func entries(atPath path: String) -> [EntryInfo] {
        entriesResult(atPath: path)?.entries ?? []
    }

    static func entries(atPath path: String, scratch: BulkScratch) -> [EntryInfo] {
        entriesResult(atPath: path, scratch: scratch)?.entries ?? []
    }

    private static func entriesResult(atPath path: String) -> DirectoryListing? {
        entriesResult(atPath: path, scratch: BulkScratch())
    }

    private static func entriesResult(atPath path: String, scratch: BulkScratch) -> DirectoryListing? {
        if let delay = scratch.session.testReads[path] {
            Thread.sleep(forTimeInterval: delay.delaySeconds)
        }

        guard !scratch.session.isCancelled, var list = rawEntries(atPath: path, scratch: scratch) else { return nil }

        guard let suffix = scratch.session.testDatalessSuffix else { return list }
        list.entries = list.entries.map { entry in
            guard entry.name.hasSuffix(suffix) else { return entry }
            var e = entry
            e.flags |= 0x40000000   // SF_DATALESS
            return e
        }
        return list
    }

    private static func rawEntries(atPath path: String, scratch: BulkScratch) -> DirectoryListing? {
        // getattrlistbulk via C bridge, using the caller's reusable buffers so
        // there is no per-directory allocation.
        let cEntries = scratch.entryBuffer
        var directory = BRDirectory()
        guard br_directory_open(path, &directory) == 0 else {
            return fallbackEntries(atPath: path, session: scratch.session)
        }
        defer { br_directory_close(&directory) }
        var entries: [EntryInfo] = []
        while true {
            guard !scratch.session.isCancelled else { return nil }
            let count = br_directory_read(&directory, cEntries.baseAddress,
                                          Int32(cEntries.count), scratch.readBuffer,
                                          Int32(BulkScratch.readBufferBytes))
            guard count >= 0 else { return fallbackEntries(atPath: path, session: scratch.session) }
            if count == 0 { return DirectoryListing(entries: entries) }
            entries.append(contentsOf: (0 ..< Int(count)).compactMap { swiftEntry(from: cEntries[$0]) })
            scratch.onBatch()
        }
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
            logicalSize: c.logical_size,
            allocatedSize: c.alloc_size,
            flags: c.flags,
            modTime: c.mod_time
        )
    }

    // MARK: - Fallback

    static func fallbackEntries(atPath path: String, session: DirectoryReadSession) -> DirectoryListing? {
        var directory = BRDirectory()
        guard br_directory_open(path, &directory) == 0 else { return nil }
        guard let stream = Darwin.fdopendir(directory.fd) else {
            br_directory_close(&directory)
            return nil
        }
        // fdopendir owns the descriptor until closedir.
        defer { Darwin.closedir(stream) }
        var entries: [EntryInfo] = []
        var unreadablePaths: [String] = []
        while true {
            guard !session.isCancelled else { return nil }
            errno = 0
            guard let record = Darwin.readdir(stream) else {
                return errno == 0 ? DirectoryListing(entries: entries, unreadablePaths: unreadablePaths) : nil
            }
            var nameBytes = record.pointee.d_name
            let name = withUnsafeBytes(of: &nameBytes) {
                String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            if name == "." || name == ".." { continue }
            var sb = Darwin.stat()
            guard Darwin.fstatat(directory.fd, name, &sb, AT_SYMLINK_NOFOLLOW) == 0 else {
                unreadablePaths.append(path + "/" + name)
                continue
            }
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

            entries.append(EntryInfo(
                name: name,
                type: entryType,
                inode: UInt64(sb.st_ino),
                device: UInt32(bitPattern: sb.st_dev),
                linkCount: UInt32(sb.st_nlink),
                logicalSize: Int64(sb.st_size),
                allocatedSize: Int64(sb.st_blocks) * 512,
                flags: sb.st_flags,
                modTime: Int64(sb.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(sb.st_mtimespec.tv_nsec)
            ))
        }
    }
}
