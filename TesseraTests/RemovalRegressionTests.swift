import Testing
import Foundation
@testable import Tessera

@Suite("Removal regressions", .serialized)
@MainActor
struct RemovalRegressionTests {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("A coverage gap blocks overlapping targets and leaves known siblings usable")
    func scopedCoverage() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([1]).write(to: url.appendingPathComponent("known"))
        let root = try await FileScanner.scan(url: url) { _ in }
        let known = try #require(root.children.first)
        root.setScanCoverageGaps([url.appendingPathComponent("unreadable").path])
        #expect(DeletionService.preflight(known) == .ready)
        #expect(DeletionService.preflight(root) == .incompleteScan)
    }

    @Test("New protected data below an unchanged ancestor fails live preflight")
    func newProtectedDescendant() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let nested = url.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data([1]).write(to: nested.appendingPathComponent("old"))
        let root = try await FileScanner.scan(url: url) { _ in }
        let target = try #require(root.children.first)
        try Data([2]).write(to: nested.appendingPathComponent("new.qcow2"))
        #expect(DeletionService.preflight(target) == .protected)
        #expect(FileManager.default.fileExists(atPath: nested.path))
    }

    @Test("Async cleanup yields the main actor, holds the source, and prunes partial success")
    func responsivePartialCleanup() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        for index in 0..<128 {
            try Data(repeating: 1, count: 4096).write(to: url.appendingPathComponent("file-\(index)"))
        }
        let vm = ScanViewModel()
        vm.startScan(volumeURL: url)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!vm.isScanning)
        let root = try #require(vm.rootNode)
        let targets = root.children
        let stale = try #require(targets.first)
        try Data(repeating: 9, count: 16384).write(to: stale.url)
        for node in targets { vm.addToCollector(node) }
        let removal = Task { try await vm.deletePermanently(targets) }
        await Task.yield()
        #expect(vm.isDeleting)
        vm.startScan(volumeURL: url)
        #expect(!vm.isScanning)
        vm.clearCollector()
        #expect(vm.collector.count == targets.count)
        do {
            try await removal.value
            Issue.record("The stale file must fail identity validation")
        } catch { }
        #expect(!vm.isDeleting)
        #expect(vm.deletionProgress == targets.count)
        #expect(root.children.count == 1)
        #expect(root.children.first?.id == stale.id)
        #expect(vm.collector.map(\.id) == [stale.id])
        #expect(FileManager.default.fileExists(atPath: stale.url.path))
    }
}
