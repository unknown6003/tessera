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
