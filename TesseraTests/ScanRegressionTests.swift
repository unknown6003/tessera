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
