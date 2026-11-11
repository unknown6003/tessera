import Foundation
import Darwin

/// Narrow removal mechanism. The caller owns operation, owner and protection authority.
/// No recovery record grants permission to resume deletion after a failure or relaunch.
enum VerifiedTrashRemoval {
    enum Reason: Equatable, Sendable {
        case invalidManifest
        case unsupported
        case changed
        case system(Int32)
        case interrupted
    }

    struct Failure: Error, Sendable {
        let reason: Reason
        /// Reveal this folder in Finder. It contains recovery.json and any held objects.
        let recoveryURL: URL?
        let removedEntryCount: Int
    }

    /// Requires the exact private operation manifest, including the empty root key.
    /// Unsupported or changed trees must be held and handled through Finder.
    static func remove(at url: URL, expected: [String: TrashFileState]) throws {
        do {
            let trash = try FileManager.default.url(for: .trashDirectory, in: .userDomainMask,
                                                   appropriateFor: url, create: false)
            try remove(at: url, expected: expected, trashDirectory: trash, checkpoint: { _ in })
        } catch let failure as Failure { throw failure }
        catch { throw Failure(reason: .unsupported, recoveryURL: nil, removedEntryCount: 0) }
    }

    // Instance-local test seam. Production never accepts a caller-supplied Trash root.
    enum Checkpoint {
        case beforeAcquisition
        case acquired(URL)
        case beforeEntry(String)
        case acquiredEntry(String, URL)
        case didUnlink(String)
    }

    static func remove(at url: URL, expected: [String: TrashFileState], trashDirectory: URL,
                       checkpoint: @escaping (Checkpoint) throws -> Void) throws {
        let work = Work(url: url, expected: expected, trash: trashDirectory, checkpoint: checkpoint)
        do { try work.run() }
        catch let failure as Failure { throw failure }
        catch let reason as Stop { throw Failure(reason: reason.reason, recoveryURL: work.recovery,
                                                 removedEntryCount: work.removed) }
        catch { throw Failure(reason: .interrupted, recoveryURL: work.recovery,
                              removedEntryCount: work.removed) }
    }

    private struct Stop: Error { let reason: Reason }

    private final class Descriptor {
        let value: Int32
        init(_ value: Int32) throws {
            guard value >= 0 else { throw Stop(reason: .system(errno)) }
            self.value = value
        }
        deinit { Darwin.close(value) }
    }

    private final class Work {
        let url: URL
        let expected: [String: TrashFileState]
        let trash: URL
        let checkpoint: (Checkpoint) throws -> Void
        var recovery: URL?
        var removed = 0
        lazy var slotIndices = Dictionary(uniqueKeysWithValues: expected.keys.sorted().enumerated().map { ($0.element, $0.offset) })
        var stage: Descriptor?
        var journal: Descriptor?
        var stageInfo = Darwin.stat()

        init(url: URL, expected: [String: TrashFileState], trash: URL,
             checkpoint: @escaping (Checkpoint) throws -> Void) {
            self.url = url
            self.expected = expected
            self.trash = trash
            self.checkpoint = checkpoint
        }

        func run() throws {
            try validateManifest()
            guard url.isFileURL, trash.isFileURL,
                  url.deletingLastPathComponent().standardizedFileURL == trash.standardizedFileURL,
                  VerifiedTrashRemoval.validName(url.lastPathComponent), let root = expected[""] else {
                throw Stop(reason: .invalidManifest)
            }
            let parent = try openAbsoluteDirectory(trash)
            let parentInfo = try info(parent.value)
            var filesystem = Darwin.statfs()
            try VerifiedTrashRemoval.check(fstatfs(parent.value, &filesystem))
            guard filesystem.f_flags & UInt32(MNT_LOCAL) != 0 else { throw Stop(reason: .unsupported) }
            guard UInt32(bitPattern: parentInfo.st_dev) == root.device,
                  parentInfo.st_uid == geteuid(), parentInfo.st_mode & 0o022 == 0 else {
                throw Stop(reason: .unsupported)
            }
            // Resource metadata is checked before acquisition. All destructive I/O uses fds.
            let volume = try trash.resourceValues(forKeys: [.volumeUUIDStringKey, .volumeURLKey])
            guard volume.volumeUUIDString == root.volumeIdentifier,
                  volume.volume?.resolvingSymlinksInPath().standardizedFileURL == root.volumeRoot else {
                throw Stop(reason: .changed)
            }
            let volumeFD = try openAbsoluteDirectory(root.volumeRoot)
            guard (try info(volumeFD.value)).st_dev == parentInfo.st_dev else {
                throw Stop(reason: .changed)
            }
            let stageName = ".tessera-removal-" + UUID().uuidString
            try VerifiedTrashRemoval.check(mkdirat(parent.value, stageName, 0o700))
            recovery = trash.appendingPathComponent(stageName, isDirectory: true)
            let staging = try openDirectory(parent.value, stageName)
            stage = staging
            stageInfo = try info(staging.value)
            guard stageInfo.st_uid == geteuid(), stageInfo.st_mode & 0o777 == 0o700,
                  stageInfo.st_dev == parentInfo.st_dev else { throw Stop(reason: .unsupported) }
            try writeJournal(staging.value, root: root)
            try VerifiedTrashRemoval.check(fsync(staging.value))
            try VerifiedTrashRemoval.check(fsync(parent.value))
            let original = try openObject(parent.value, url.lastPathComponent, root)
            try matches(try info(original.value), root, moved: false)
            try sameEntry(parent.value, url.lastPathComponent, try info(original.value))
            try checkpoint(.beforeAcquisition)
            // RENAME_EXCL never overwrites an existing staging entry.
            try acquire(parent.value, url.lastPathComponent, "item")
            try VerifiedTrashRemoval.check(fsync(staging.value))
            try VerifiedTrashRemoval.check(fsync(parent.value))
            let heldURL = try recoveryURL("item")
            try checkpoint(.acquired(heldURL))
            let held = try openObject(staging.value, "item", root)
            try matches(try info(held.value), root, moved: true)
            var seen = Set<String>()
            try verify(held, key: "", moved: true, seen: &seen, depth: 0)
            guard seen.count == expected.count else { throw Stop(reason: .changed) }
            try erase(held, parent: staging.value, name: "item", key: "", depth: 0)
            // Cleanup is also descriptor-relative and checks each staging name first.
            try sameEntry(parent.value, stageName, stageInfo)
            guard try names(staging.value) == ["recovery.json"] else { throw Stop(reason: .changed) }
            guard let journal else { throw Stop(reason: .changed) }
            try sameEntry(staging.value, "recovery.json", try info(journal.value))
            try VerifiedTrashRemoval.check(unlinkat(staging.value, "recovery.json", 0))
            try VerifiedTrashRemoval.check(fsync(staging.value))
            try sameEntry(parent.value, stageName, stageInfo)
            try VerifiedTrashRemoval.check(unlinkat(parent.value, stageName, AT_REMOVEDIR))
            recovery = nil
            try VerifiedTrashRemoval.check(fsync(parent.value))
        }

        func validateManifest() throws {
            guard !expected.isEmpty, expected.count <= 10_000, let root = expected[""] else {
                throw Stop(reason: .invalidManifest)
            }
            for (key, value) in expected {
                let parts = key.split(separator: "/", omittingEmptySubsequences: false)
                guard key.isEmpty || (parts.count <= 128 && parts.allSatisfy { VerifiedTrashRemoval.validName(String($0)) }),
                      value.isUsable, value.flags == 0, value.owner == geteuid(),
                      value.device == root.device, value.volumeIdentifier == root.volumeIdentifier,
                      value.volumeRoot == root.volumeRoot else { throw Stop(reason: .unsupported) }
                if !key.isEmpty {
                    let parent = key.split(separator: "/").dropLast().joined(separator: "/")
                    guard expected[parent]?.isDirectory == true else { throw Stop(reason: .invalidManifest) }
                }
            }
        }

        func verify(_ fd: Descriptor, key: String, moved: Bool, seen: inout Set<String>, depth: Int) throws {
            guard depth <= 128, let state = expected[key], seen.insert(key).inserted else {
                throw Stop(reason: .changed)
            }
            try matches(try info(fd.value), state, moved: moved)
            if state.isDirectory {
                for name in try names(fd.value) {
                    let childKey = key.isEmpty ? name : key + "/" + name
                    guard let child = expected[childKey] else { throw Stop(reason: .changed) }
                    let childFD = try openObject(fd.value, name, child)
                    try verify(childFD, key: childKey, moved: false, seen: &seen, depth: depth + 1)
                    try sameEntry(fd.value, name, try info(childFD.value))
                }
                try matches(try info(fd.value), state, moved: moved)
            }
        }

        func erase(_ fd: Descriptor, parent: Int32, name: String, key: String, depth: Int) throws {
            guard depth <= 128, let state = expected[key], let staging = stage else {
                throw Stop(reason: .changed)
            }
            if state.isDirectory {
                try matchesDirectory(try info(fd.value), state)
                for childName in try names(fd.value) {
                    let childKey = key.isEmpty ? childName : key + "/" + childName
                    guard let child = expected[childKey] else { throw Stop(reason: .changed) }
                    let childFD = try openObject(fd.value, childName, child)
                    try erase(childFD, parent: fd.value, name: childName, key: childKey, depth: depth + 1)
                }
                guard try names(fd.value).isEmpty else { throw Stop(reason: .changed) }
                try matchesDirectory(try info(fd.value), state)
            } else {
                try matches(try info(fd.value), state, moved: key.isEmpty)
            }
            try checkpoint(.beforeEntry(key))
            // Isolate every name before its last identity check. A swapped leaf is held.
            guard let index = slotIndices[key] else { throw Stop(reason: .changed) }
            let slot = "entry-\(index)"
            try acquire(parent, name, slot)
            try VerifiedTrashRemoval.check(fsync(staging.value))
            try VerifiedTrashRemoval.check(fsync(parent))
            try checkpoint(.acquiredEntry(key, try recoveryURL(slot)))
            let acquired = try openObject(staging.value, slot, state)
            if state.isDirectory {
                try matchesDirectory(try info(acquired.value), state)
                guard try names(acquired.value).isEmpty else { throw Stop(reason: .changed) }
            } else {
                try matches(try info(acquired.value), state, moved: true)
            }
            let heldInfo = try info(acquired.value)
            try sameEntry(staging.value, slot, heldInfo)
            try VerifiedTrashRemoval.check(unlinkat(staging.value, slot, state.isDirectory ? AT_REMOVEDIR : 0))
            removed += 1
            try VerifiedTrashRemoval.check(fsync(staging.value))
            try checkpoint(.didUnlink(key))
        }

        func writeJournal(_ fd: Int32, root: TrashFileState) throws {
            // Slot mapping is durable before any rename, including a later leaf acquisition.
            let entries: [[String: Any]] = expected.keys.sorted().enumerated().map { index, key in
                ["relativePath": key, "slot": "entry-\(index)",
                 "device": expected[key]!.device, "inode": String(expected[key]!.inode)]
            }
            let record: [String: Any] = ["format": 1, "originalTrashURL": url.absoluteString,
                                       "device": root.device, "inode": String(root.inode),
                                       "expectedEntryCount": expected.count, "entries": entries,
                                       "policy": "inspect-only; never resume deletion from this record"]
            let bytes = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            let file = try Descriptor(openat(fd, "recovery.json", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600))
            journal = file
            try bytes.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let count = Darwin.write(file.value, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { throw Stop(reason: .system(count < 0 ? errno : EIO)) }
                    offset += count
                }
            }
            try VerifiedTrashRemoval.check(fsync(file.value))
            // Require the durable flush on supported local macOS filesystems, else hold.
            try VerifiedTrashRemoval.check(fcntl(file.value, F_FULLFSYNC))
        }

        func acquire(_ parent: Int32, _ name: String, _ slot: String) throws {
            guard let staging = stage else { throw Stop(reason: .unsupported) }
            try VerifiedTrashRemoval.check(renameatx_np(parent, name, staging.value, slot, UInt32(RENAME_EXCL)))
        }

        func recoveryURL(_ name: String) throws -> URL {
            guard let recovery else { throw Stop(reason: .unsupported) }
            return recovery.appendingPathComponent(name)
        }

        func openAbsoluteDirectory(_ url: URL) throws -> Descriptor {
            guard url.isFileURL, url.path.hasPrefix("/") else { throw Stop(reason: .unsupported) }
            var fd = try Descriptor(Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC))
            for part in url.path.split(separator: "/") {
                guard VerifiedTrashRemoval.validName(String(part)) else { throw Stop(reason: .unsupported) }
                fd = try openDirectory(fd.value, String(part))
            }
            return fd
        }

        func openDirectory(_ parent: Int32, _ name: String) throws -> Descriptor {
            try Descriptor(openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC))
        }

        func openFile(_ parent: Int32, _ name: String) throws -> Descriptor {
            try Descriptor(openat(parent, name, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC))
        }

        func openObject(_ parent: Int32, _ name: String, _ state: TrashFileState) throws -> Descriptor {
            let fd = try state.isDirectory ? openDirectory(parent, name) : openFile(parent, name)
            let current = try info(fd.value)
            guard current.st_mode & S_IFMT == (state.isDirectory ? S_IFDIR : S_IFREG),
                  current.st_flags == 0, UInt32(bitPattern: current.st_dev) == state.device else {
                throw Stop(reason: .unsupported)
            }
            return fd
        }

        func names(_ fd: Int32) throws -> [String] {
            // A fresh open description avoids sharing a directory stream offset with fd.
            let copy = try openDirectory(fd, ".")
            let raw = dup(copy.value)
            guard raw >= 0 else { throw Stop(reason: .system(errno)) }
            guard let stream = fdopendir(raw) else {
                let code = errno
                Darwin.close(raw)
                throw Stop(reason: .system(code))
            }
            defer { closedir(stream) }
            var result: [String] = []
            while true {
                errno = 0
                guard let entry = readdir(stream) else {
                    if errno != 0 { throw Stop(reason: .system(errno)) }
                    break
                }
                let nameLength = Int(entry.pointee.d_namlen)
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: nameLength + 1) { String(validatingCString: $0) }
                }
                guard let name else { throw Stop(reason: .unsupported) }
                if name == "." || name == ".." { continue }
                guard VerifiedTrashRemoval.validName(name), result.count < 10_000 else { throw Stop(reason: .unsupported) }
                result.append(name)
            }
            return result.sorted()
        }

        func info(_ fd: Int32) throws -> Darwin.stat {
            var value = Darwin.stat()
            try VerifiedTrashRemoval.check(fstat(fd, &value))
            return value
        }

        func sameEntry(_ parent: Int32, _ name: String, _ value: Darwin.stat) throws {
            var current = Darwin.stat()
            try VerifiedTrashRemoval.check(fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW))
            guard current.st_dev == value.st_dev, current.st_ino == value.st_ino,
                  current.st_mode == value.st_mode, current.st_birthtimespec.tv_sec == value.st_birthtimespec.tv_sec,
                  current.st_birthtimespec.tv_nsec == value.st_birthtimespec.tv_nsec else {
                throw Stop(reason: .changed)
            }
        }

        func state(_ value: Darwin.stat, _ expected: TrashFileState) -> TrashFileState {
            TrashFileState(stat: value, volumeIdentifier: expected.volumeIdentifier, volumeRoot: expected.volumeRoot)
        }

        func matches(_ value: Darwin.stat, _ expected: TrashFileState, moved: Bool) throws {
            let current = state(value, expected)
            guard current.isUsable, current.flags == 0,
                  moved ? expected.sameMovedObject(as: current) : expected == current else {
                throw Stop(reason: .changed)
            }
        }

        func matchesDirectory(_ value: Darwin.stat, _ expected: TrashFileState) throws {
            // Our own child renames change directory times, size and link count.
            // Identity and fixed metadata retain the original authority; new names are held.
            guard expected.sameAncestor(as: state(value, expected)), value.st_flags == 0 else {
                throw Stop(reason: .changed)
            }
        }
    }

    private static func validName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.utf8.contains(0)
    }

    private static func check(_ result: Int32) throws {
        guard result == 0 else { throw Stop(reason: .system(errno)) }
    }
}
