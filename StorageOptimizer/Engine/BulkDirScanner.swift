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
    private static let maxEntriesPerDir = 32_768

    /// Box for handing the result across the sacrificial-thread boundary.
    private final class ResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [EntryInfo]?
        let semaphore = DispatchSemaphore(value: 0)

        func store(_ entries: [EntryInfo]) {
            lock.lock(); stored = entries; lock.unlock()
            semaphore.signal()
        }
        func take() -> [EntryInfo]? {
            lock.lock(); defer { lock.unlock() }
            return stored
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
    /// Returns nil when the deadline passes (caller should skip the directory).
    static func timedEntries(atPath path: String, timeoutSeconds: Double = 5) -> [EntryInfo]? {
        let box = ResultBox()
        DispatchQueue.global(qos: .utility).async {
            box.store(entries(atPath: path))
        }
        guard box.semaphore.wait(timeout: .now() + timeoutSeconds) == .success else {
            return nil
        }
        return box.take()
    }

    /// Treat package directories (.app, .framework, …) as leaf "directories the user
    /// thinks of as files" only at presentation level; the scanner must still descend
    /// into them to measure their size, so they are reported as `.directory` here and
    /// flagged via `isPackageName`.
    static func isPackageName(_ name: String) -> Bool {
        packageExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    static func entries(atPath path: String) -> [EntryInfo] {
        // Try getattrlistbulk via C bridge
        var cEntries = [BREntry](repeating: BREntry(), count: maxEntriesPerDir)
        let count = br_scan_directory(path, &cEntries, Int32(maxEntriesPerDir))
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
