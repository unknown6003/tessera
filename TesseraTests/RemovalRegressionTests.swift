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

    @Test("A parent replaced by a symlink after preparation cannot redirect removal")
    func replacedAncestor() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let original = url.appendingPathComponent("original")
        let moved = url.appendingPathComponent("moved")
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        try Data([1]).write(to: original.appendingPathComponent("data"))
        let root = try await FileScanner.scan(url: url) { _ in }
        let file = try #require(root.children.first?.children.first)
        let prepared = DeletionService.prepare(file)
        #expect(prepared.check == .ready)
        try FileManager.default.moveItem(at: original, to: moved)
        try FileManager.default.createSymbolicLink(at: original, withDestinationURL: moved)
        #expect(DeletionService.perform(prepared, permanently: true) != nil)
        #expect(FileManager.default.fileExists(atPath: moved.appendingPathComponent("data").path))
    }

    @Test("Old saved results decode as recoverable Trash moves")
    func oldResultCompatibility() throws {
        let json = Data("""
        {"movedBytes":4096,"failedBytes":0,"failedPaths":[]}
        """.utf8)
        let result = try JSONDecoder().decode(RescueVerification.self, from: json)
        #expect(result.removalMethod == nil)
        #expect(result.removalTitle == "Moved to Trash")
        #expect(result.recoveryNote.contains("empty it"))
    }

    @Test("A resource fork uses the same logical size in scan and removal checks")
    func resourceForkIdentity() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let file = url.appendingPathComponent("forked.dat")
        try Data(repeating: 1, count: 4096).write(to: file)
        try Data(repeating: 2, count: 16384).write(to: file.appendingPathComponent("..namedfork/rsrc"))
        let root = try await FileScanner.scan(url: url) { _ in }
        let node = try #require(root.children.first)
        let expected = try #require(node.scanIdentity)
        let current = try #require(ScanIdentity.current(at: file))
        #expect(expected.logicalSize == 4096)
        #expect(expected.matches(current))
        let prepared = DeletionService.prepare(node)
        #expect(prepared.check == .ready)
        #expect(DeletionService.perform(prepared, permanently: true) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A cancelled background tree read holds cleanup until the worker returns")
    func treeReadExcludesRemoval() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([1]).write(to: url.appendingPathComponent("data"))
        let suiteName = "TesseraTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: url)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let root = try #require(vm.rootNode)
        let target = try #require(root.children.first)
        let release = DispatchSemaphore(value: 0)
        let reader = Task {
            await vm.readTree { tree, cancel in
                _ = release.wait(timeout: .now() + .seconds(3))
                return (tree.children.count, cancel.isCancelled)
            }
        }
        defer { release.signal() }
        while !vm.isReadingTree, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(vm.isReadingTree)
        do {
            try await vm.deletePermanently([target])
            Issue.record("Cleanup must not mutate a tree with an active reader")
        } catch { }
        reader.cancel()
        #expect(vm.isReadingTree)
        release.signal()
        let result = await reader.value
        #expect(result?.0 == 1)
        #expect(result?.1 == true)
        #expect(!vm.isReadingTree)
        #expect(!vm.isDeleting)
        #expect(FileManager.default.fileExists(atPath: target.url.path))
    }

    @Test("Async cleanup yields the main actor, holds the source, and prunes partial success")
    func responsivePartialCleanup() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        for index in 0..<128 {
            try Data(repeating: 1, count: 4096).write(to: url.appendingPathComponent("file-\(index)"))
        }
        let suiteName = "TesseraTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = ScanViewModel(defaults: defaults)
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
        #expect(vm.rescueVerification?.removalMethod == .permanent)
        #expect(vm.rescueVerification?.removalTitle == "Deleted permanently")
        #expect(vm.savedRescueCase?.verification?.removalMethod == .permanent)
        #expect(vm.rescuePlan?.measurement == vm.rescueVerification?.after)
        #expect(vm.savedRescueCase?.measurement == vm.rescueVerification?.after)
        #expect(vm.deletionProgress == targets.count)
        #expect(root.children.count == 1)
        #expect(root.children.first?.id == stale.id)
        #expect(vm.collector.map(\.id) == [stale.id])
        #expect(FileManager.default.fileExists(atPath: stale.url.path))
    }
}
