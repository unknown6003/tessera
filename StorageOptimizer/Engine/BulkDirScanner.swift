import Foundation

// MARK: - Entry info

struct EntryInfo {
    var name: String
    var type: EntryType
    var inode: UInt64
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
    private static let maxEntriesPerDir = 16_384

    static func entries(in dirURL: URL) -> [EntryInfo] {
        let path = dirURL.withUnsafeFileSystemRepresentation { ptr -> String? in
            ptr.map { String(cString: $0) }
        } ?? dirURL.path

        // Try getattrlistbulk via C bridge
        var cEntries = [BREntry](repeating: BREntry(), count: maxEntriesPerDir)
        let count = br_scan_directory(path, &cEntries, Int32(maxEntriesPerDir))
        if count >= 0 {
            return (0 ..< Int(count)).compactMap { i in
                swiftEntry(from: cEntries[i])
            }
        }

        // Fallback: readdir via FileManager + lstat
        return fallbackEntries(in: dirURL)
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
        case UInt32(BR_TYPE_DIR):
            let ext = (name as NSString).pathExtension.lowercased()
            entryType = packageExtensions.contains(ext) ? .file : .directory
        case UInt32(BR_TYPE_LNK): entryType = .symlink
        case UInt32(BR_TYPE_REG): entryType = .file
        default: entryType = .other
        }

        return EntryInfo(
            name: name,
            type: entryType,
            inode: c.inode,
            allocatedSize: c.alloc_size
        )
    }

    // MARK: - Fallback

    private static func fallbackEntries(in dirURL: URL) -> [EntryInfo] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: nil, options: []
        )) ?? []

        return urls.compactMap { url -> EntryInfo? in
            var sb = Darwin.stat()
            guard Darwin.lstat(url.path, &sb) == 0 else { return nil }
            let mode = sb.st_mode & S_IFMT
            let name = url.lastPathComponent
            let ext  = url.pathExtension.lowercased()

            let entryType: EntryInfo.EntryType
            if mode == S_IFLNK {
                entryType = .symlink
            } else if mode == S_IFDIR {
                entryType = packageExtensions.contains(ext) ? .file : .directory
            } else if mode == S_IFREG {
                entryType = .file
            } else {
                entryType = .other
            }

            return EntryInfo(
                name: name,
                type: entryType,
                inode: UInt64(sb.st_ino),
                allocatedSize: Int64(sb.st_blocks) * 512
            )
        }
    }
}
