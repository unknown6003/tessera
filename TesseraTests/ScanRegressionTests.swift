import Testing
import Foundation
@testable import Tessera

@Suite("Scan regressions", .serialized)
struct ScanRegressionTests {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Literal path matching preserves Foundation behavior for ASCII, Unicode and NUL")
    func literalPathMatching() {
        let roots = ["", "/", "/users/sample/library/application support/google/chrome/default/cache",
                     "/volumes/archive/backups", "/users/sample/projects/" + String(repeating: "deep/", count: 300),
                     "/users/caf\u{e9}/library/caches", "/users/cafe\u{301}/library/caches",
                     "/users/sample/adobe\u{301}/cache", "/users/界/library/cloudstorage/provider",
                     "/users/sample\0/after-null"]
        let ruleParts = [
            "/library/application support/mobilesync/backup",
            "/time machine/",
            "/.docker/",
            "/.parallels/",
            "/library/cloudstorage/",
            "/library/mobile documents/",
            "/library/application support/google/chrome",
            "/library/application support/microsoft edge",
            "/library/application support/brave-browser",
            "/library/application support/firefox",
            "/library/application support/com.microsoft.vscode",
            "/library/messages",
            "/library/application support/discord",
            "/library/application support/telegram",
            "/library/application support/whatsapp",
            "/library/application support/signal",
            "/adobe",
            "/adobe/cameraraw",
            "lightroom",
            "/caches/",
            "/.gradle",
            "cocoapods",
            "/.cache/yarn",
            "/.cargo/registry",
            "/google/chrome",
            "/firefox/",
            "/com.apple.safari",
            "/microsoft edge",
            "/brave-browser",
            "/library/caches",
            "/developer/",
            "/documents/",
            "/projects/",
            "/code/",
            "/src/",
            "/library/logs",
            "/users/"
        ]
        let parts = ruleParts + ["", "/", "cache", "/library/caches", "chrome", "/volumes/", "deep/",
                     "adobe", "adob\u{e9}", "cafe\u{301}", "界", "after-null", "\0/after", "missing"]
        for root in roots + parts.map({ "/users/sample" + $0 + "/nested" }) {
            let input = CleanupPath(root)
            for part in parts {
                #expect(input.contains(part) == root.contains(part), "Substring mismatch for \(root.debugDescription) and \(part.debugDescription)")
                #expect(input.hasPrefix(part) == root.hasPrefix(part))
                #expect(input.hasSuffix(part) == root.hasSuffix(part))
            }
        }
    }

    @Test("Known descendant names retain every protected owner boundary")
    func protectedDescendantPaths() {
        let protected = ["item.vmdk", ".Trash/file", "VM.backupbundle/file",
                         "Library/CloudStorage/provider/file", "Library/Messages/Attachments/file",
                         "Library/Application Support/Google/Chrome/Default/Cache/file"]
        for (home, relative) in ["sample", "界"].flatMap({ home in
            (protected + ["cache.bin"]).map { (home, $0) }
        }) {
            let root = FileNode(url: URL(fileURLWithPath: "/Users/\(home)/Library/Developer/Xcode"),
                                name: "Xcode", isDirectory: true, size: 0)
            let derived = FileNode(name: "DerivedData", isDirectory: true, size: 0,
                                   identity: ScanIdentity(device: 1, inode: 2, resourceType: .directory))
            root.setChildren([derived])
            let components = relative.split(separator: "/").map(String.init)
            var parent = derived
            for (index, name) in components.enumerated() {
                let child = FileNode(name: name, isDirectory: index < components.count - 1, size: 1)
                parent.setChildren([child])
                parent = child
            }
            root.recomputeDirectorySizes()
            let report = CleanupClassifier.classify(root: root)
            let recommendation = report.recommendations.first { $0.node === derived }
            #expect(recommendation?.risk == (relative == "cache.bin" ? .safe : .review))
            #expect(CleanupClassifier.hasProtectedDescendant(derived) == protected.contains(relative))
        }
    }

    @Test("Bulk enumeration keeps every entry across output and kernel batches", arguments: [8191, 8192, 8193, 20000])
    func wideDirectory(count: Int) throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        for index in 0..<count {
            let path = url.appendingPathComponent("entry-\(index)").path
            let fd = Darwin.open(path, O_CREAT | O_WRONLY, 0o600)
            #expect(fd >= 0)
            if fd >= 0 { Darwin.close(fd) }
        }
        let entries = BulkDirScanner.entries(atPath: url.path)
        #expect(entries.count == count)
        #expect(Set(entries.map(\.name)).count == count)
        #expect(entries.allSatisfy { $0.type == .file })
    }

    @Test("Tiny output batches preserve leftover kernel records")
    func tinyBatches() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        for index in 0..<107 {
            try Data().write(to: url.appendingPathComponent("item-\(index)"))
        }
        let scratch = BulkScratch(entryCapacity: 3)
        let entries = BulkDirScanner.entries(atPath: url.path, scratch: scratch)
        #expect(Set(entries.map(\.name)) == Set((0..<107).map { "item-\($0)" }))
    }

    @Test("A cancelled directory session stops before opening the source")
    func cancelledSession() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let session = DirectoryReadSession()
        session.cancel()
        #expect(BulkDirScanner.workerListing(atPath: url.path, scratch: BulkScratch(session: session)) == nil)
    }

    @Test("A held provider does not affect a readable sibling provider or a later scan")
    func providerScope() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let first = url.appendingPathComponent("Library/CloudStorage/provider-a")
        let second = url.appendingPathComponent("Library/CloudStorage/provider-b")
        for provider in [first, second] {
            try FileManager.default.createDirectory(at: provider, withIntermediateDirectories: true)
            try Data([1]).write(to: provider.appendingPathComponent("local"))
        }
        let session = DirectoryReadSession()
        session.hold(first.path)
        #expect(BulkDirScanner.workerListing(atPath: first.path, scratch: BulkScratch(session: session)) == nil)
        #expect(BulkDirScanner.workerListing(atPath: second.path, scratch: BulkScratch(session: session))?.entries.count == 1)
        #expect(BulkDirScanner.workerListing(atPath: first.path, scratch: BulkScratch())?.entries.count == 1)
    }

    @Test("Bulk enumeration retains long UTF-8 directory names and their children")
    func unicodeDirectory() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let name = String(repeating: "界", count: 150)
        let child = url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 8192).write(to: child.appendingPathComponent("data"))
        let entries = BulkDirScanner.entries(atPath: url.path)
        #expect(entries.map(\.name) == [name])
        let root = try await FileScanner.scan(url: url) { _ in }
        #expect(root.children.first?.name == name)
        #expect(root.children.first?.children.first?.name == "data")
        #expect(root.size > 0)
        #expect(root.scanCoverageGaps.isEmpty)
    }

    @Test("Rescan reads file writes and nested additions under unchanged ancestors")
    func rescanDescendants() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let ancestor = url.appendingPathComponent("a")
        let nested = ancestor.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appendingPathComponent("data")
        try Data(repeating: 1, count: 4096).write(to: file)
        let original = try await FileScanner.scan(url: url) { _ in }
        let ancestorDate = try FileManager.default.attributesOfItem(atPath: ancestor.path)[.modificationDate]
        try Data(repeating: 2, count: 65536).write(to: file)
        try Data(repeating: 3, count: 8192).write(to: nested.appendingPathComponent("new"))
        #expect(try FileManager.default.attributesOfItem(atPath: ancestor.path)[.modificationDate] as? Date == ancestorDate as? Date)
        let updated = try await FileScanner.scan(url: url, cache: original) { _ in }
        let fresh = try await FileScanner.scan(url: url) { _ in }
        #expect(updated.size == fresh.size)
        #expect(updated.size > original.size)
        #expect(updated.children.first?.children.first?.children.count == 2)
        #expect(original.children.first?.parent === original)
    }

    @Test("Unknown remaining work never produces a guessed percentage")
    func progress() {
        var progress = ScanProgress(filesScanned: 100, bytesFound: 1000, dirsScanned: 99,
                                    dirsDiscovered: 100, volumeUsedTotal: 1000)
        #expect(progress.fraction == nil)
        progress.isComplete = true
        #expect(progress.fraction == 1)
    }

    @Test("Identity storage keeps optional metadata distinct from zero and retains located records")
    func identityStorage() {
        let identities = [ScanIdentity(resourceType: .file),
            ScanIdentity(device: 0, inode: 0, resourceType: .directory,
                         logicalSize: 0, allocatedSize: 0, modificationTime: 0),
            ScanIdentity(device: 7, inode: UInt64.max, resourceType: .package,
                         logicalSize: 8192, allocatedSize: 4096, modificationTime: 12345),
            ScanIdentity(path: "/fixture/item", volumeIdentifier: "volume", resourceIdentifier: "object",
                         device: 1, inode: 2, resourceType: .file, logicalSize: 8192,
                         allocatedSize: 4096, modificationTime: 12345)]
        for identity in identities {
            let node = FileNode(name: "item", isDirectory: identity.resourceType.isDirectory,
                                size: 4096, identity: identity)
            #expect(node.scanIdentity == identity)
            node.overrideSize(0)
            #expect(node.scanIdentity == identity)
        }
        #expect(FileNode(name: "missing", isDirectory: false, size: 0).scanIdentity == nil)
    }

    @Test("Deep tree URL assembly and batch size changes avoid recursive calls")
    func deepTree() {
        let root = FileNode(url: URL(fileURLWithPath: "/fixture"), name: "fixture", isDirectory: true, size: 0)
        var chain = [root]
        for _ in 0..<2000 {
            let child = FileNode(name: "d", isDirectory: true, size: 0)
            chain.last!.setChildren([child])
            chain.append(child)
        }
        let file = FileNode(name: "data", isDirectory: false, size: 4096)
        chain.last!.setChildren([file])
        root.recomputeDirectorySizes()
        #expect(root.size == 4096)
        #expect(file.url.path.hasSuffix("/d/data"))
        chain.last!.removeChildren(withIDs: [file.id])
        #expect(root.size == 0)
        // Release parent links in order while every node is still retained.
        for node in chain { node.setChildren([]) }
    }
}
