import Foundation
import Testing
@testable import Tessera

@Suite("Explicit cleanup and lossless scan cancellation")
@MainActor
struct ScanFlowTests {
    @Test("A scan never adds safe cleanup candidates without an explicit action")
    func scanDoesNotStageCleanup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tessera-flow-" + UUID().uuidString)
        let cache = root.appendingPathComponent("Library/Developer/Xcode/DerivedData/Sample/Build")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 7, count: 4096).write(to: cache.appendingPathComponent("sample.o"))
        let suite = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: root)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, .now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!vm.isScanning)
        #expect(vm.rootNode != nil)
        #expect(vm.cleanupReport != nil)
        #expect(vm.collector.isEmpty)
    }

    @Test("Cancel keeps the prior tree, selection and staged items and rejects late results")
    func cancelKeepsPreviousResult() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tessera-flow-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([1, 2]).write(to: root.appendingPathComponent("sample"))
        let suite = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: root)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, .now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let tree = try #require(vm.rootNode)
        let file = try #require(tree.children.first)
        vm.selectedNode = file
        vm.addToCollector(file)
        vm.startScan(volumeURL: root)
        #expect(vm.rootNode === tree, "A rescan must retain the displayed result until publication")
        vm.cancelScan()
        try await Task.sleep(for: .milliseconds(100))
        #expect(!vm.isScanning)
        #expect(vm.rootNode === tree)
        #expect(vm.scannedURL == root)
        #expect(vm.selectedNode?.id == file.id)
        #expect(vm.collector.map(\.id) == [file.id])
        #expect(vm.scanStatus == "Scan stopped. Showing previous results.")
    }
}
