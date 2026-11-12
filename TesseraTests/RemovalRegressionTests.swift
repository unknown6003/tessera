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

    @Test("Finishing tracked Trash replaces and saves the operation result", arguments: [false, true])
    func finishPublishesResult(partial: Bool) async throws {
        let fs = try TrashOperationTests.Fixture()
        defer { fs.clean() }
        for name in ["a.bin", "b.bin", "c.bin"] {
            try Data(repeating: 1, count: 4096).write(to: fs.source.appendingPathComponent(name))
        }
        let sentinel = fs.trash.appendingPathComponent("unrelated.bin")
        try Data([9]).write(to: sentinel)
        let domain = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let vm = ScanViewModel(defaults: defaults, makeTrashOperation: { TrashOperation(fileSystem: fs) })
        vm.startScan(volumeURL: fs.source)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, .now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!vm.isScanning)
        let root = try #require(vm.rootNode)
        try await vm.moveToTrash(root.children)
        #expect(vm.rescueVerification?.removalMethod == .trash)
        let snapshot = try await vm.reviewTrackedTrash()
        try #require(snapshot.review.items.count == 3)
        try #require(snapshot.review.items.allSatisfy { $0.hold == nil })
        if partial {
            try Data(repeating: 2, count: 8192).write(to: fs.trash.appendingPathComponent("b.bin"))
            fs.removalFailureNames = ["c.bin"]
        }
        let before = vm.rescuePlan?.measurement
        try await vm.finishTrackedTrash(snapshot, selecting: Set(snapshot.review.items.map(\.id)))
        let result = try #require(vm.rescueVerification)
        #expect(result.removalMethod == .permanent)
        #expect(result.removalTitle == "Deleted permanently")
        #expect(!result.recoveryNote.contains("empty it"))
        #expect(result.before == before)
        #expect(result.after == vm.rescuePlan?.measurement)
        #expect(result.after?.measuredAt != before?.measuredAt)
        #expect(result.movedPaths?.count == (partial ? 1 : 3))
        #expect(result.heldPaths?.count == (partial ? 1 : 0))
        #expect(result.failedPaths.count == (partial ? 1 : 0))
        #expect(result.heldPaths?.allSatisfy { $0.hasSuffix("b.bin") } == true)
        #expect(result.failedPaths.allSatisfy { $0.hasSuffix("c.bin") })
        let removedIDs = snapshot.review.items.filter { !partial || $0.item.trashURL.lastPathComponent == "a.bin" }.map(\.id)
        #expect(result.movedBytes == removedIDs.reduce(0) { $0 + (snapshot.allocatedBytes[$1] ?? 0) })
        #expect(vm.savedRescueCase?.verification == result)
        #expect(vm.savedRescueCase?.measurement == result.after)
        #expect(try RescueCaseStore.load(defaults: defaults)?.verification == result)
        #expect(vm.lastRemovalSummary?.permanently == true)
        #expect(vm.lastRemovalSummary?.held == (partial ? 1 : 0))
        #expect(vm.lastRemovalSummary?.failed == (partial ? 1 : 0))
        #expect(vm.hasTrackedTrash == partial)
        #expect(try Data(contentsOf: sentinel) == Data([9]))
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

    @Test("Legacy capacity targets do not grade a measured cleanup result")
    func legacyTargetDoesNotGradeCleanup() {
        let before = RescueMeasurement(volumePath: "/fixture", totalBytes: 1_000,
            availableBytes: 100, freeBytes: 100, logicalBytes: 900, physicalBytes: 900,
            measuredAt: Date(timeIntervalSince1970: 1))
        let after = RescueMeasurement(volumePath: "/fixture", totalBytes: 1_000,
            availableBytes: 130, freeBytes: 130, logicalBytes: 870, physicalBytes: 870,
            measuredAt: Date(timeIntervalSince1970: 2))
        let result = RescueVerification(requestedBytes: 250, movedBytes: 30,
            movedPaths: nil, failedBytes: 0, failedPaths: [], heldBytes: nil, heldPaths: nil,
            measurementMismatchPaths: nil, before: before, after: after)
        #expect(result.status == "Verified after measurement")
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

    @Test("An Explore removal summary excludes unrelated held Rescue recommendations")
    func removalSummaryIsOperationScoped() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 1, count: 4096).write(to: url.appendingPathComponent("owned-disposable.bin"))
        let protectedFolder = url.appendingPathComponent(".docker", isDirectory: true)
        try FileManager.default.createDirectory(at: protectedFolder, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 8192).write(to: protectedFolder.appendingPathComponent("keep.qcow2"))
        let suiteName = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: url)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!vm.isScanning)
        let target = try #require(vm.rootNode?.children.first { $0.name == "owned-disposable.bin" })
        let unrelated = try #require(vm.rootNode?.children.first { $0.name == ".docker" })
        try #require(vm.rescuePlan?.recommendations.contains { $0.node.id == unrelated.id && $0.risk == .protected } == true)
        let bytes = target.physicalSize
        vm.addToCollector(target)
        vm.addToCollector(target)
        try #require(vm.collectorNotice != nil)
        try await vm.deletePermanently([target])
        let summary = try #require(vm.lastRemovalSummary)
        #expect(vm.collectorNotice == nil)
        #expect(summary.moved == 1 && summary.movedBytes == bytes)
        #expect(summary.held == 0 && summary.failed == 0)
        #expect(summary.permanently)
        #expect(vm.rescueVerification?.heldPaths?.contains(unrelated.url.path) == true)
        #expect(vm.rescueVerification?.requestedBytes == nil)
        #expect(vm.savedRescueCase?.verification?.requestedBytes == nil)
        #expect(FileManager.default.fileExists(atPath: unrelated.url.path))
    }

    @Test("Removing the scanned source clears its tree and recommendations")
    func removalOfScanRoot() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 1, count: 4096).write(to: url.appendingPathComponent("owned.dmg"))
        let suiteName = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: url)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!vm.isScanning)
        let root = try #require(vm.rootNode)
        try #require(!root.children.isEmpty)
        vm.addToCollector(root)

        try await vm.deletePermanently([root])

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(vm.rootNode == nil)
        #expect(vm.currentRoot == nil)
        #expect(vm.collector.isEmpty)
        #expect(vm.cleanupReport?.recommendations.isEmpty == true)
        #expect(vm.rescuePlan?.recommendations.isEmpty == true)
        #expect(vm.rescueVerification?.movedPaths == [url.standardizedFileURL.path])
        #expect(vm.lastRemovalSummary?.moved == 1)
        #expect(!vm.hasCachedScan(for: url))
    }

    @Test("Only a same-source refresh retains the displayed Rescue result")
    func refreshKeepsSameSourceResults() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([1]).write(to: url.appendingPathComponent("owned.dmg"))
        let other = try fixture()
        defer { try? FileManager.default.removeItem(at: other) }
        let suiteName = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: url)
        #expect(!vm.hasRescueResultsForSelectedSource)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!vm.isScanning)
        let rootID = try #require(vm.rootNode?.id)
        let checked = try #require(vm.rescuePlan?.measurement.measuredAt)

        vm.startScan(volumeURL: url.standardizedFileURL)
        #expect(vm.isScanning)
        #expect(vm.hasRescueResultsForSelectedSource)
        #expect(vm.rootNode?.id == rootID)
        #expect(vm.rescuePlan?.measurement.measuredAt == checked)
        vm.cancelScan()
        #expect(vm.rootNode?.id == rootID)
        #expect(vm.rescuePlan?.measurement.measuredAt == checked)

        vm.startScan(volumeURL: other)
        #expect(vm.isScanning)
        #expect(!vm.hasRescueResultsForSelectedSource)
        vm.cancelScan()
    }

    @Test("Successful removal refreshes Rescue rows from the pruned tree")
    func removalRefreshesRescueReport() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 1, count: 4096).write(to: url.appendingPathComponent("first.dmg"))
        try Data(repeating: 2, count: 8192).write(to: url.appendingPathComponent("second.dmg"))
        let suiteName = TestPreferenceDomain.prefix + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let vm = ScanViewModel(defaults: defaults)
        vm.startScan(volumeURL: url)
        let deadline = ContinuousClock.now + .seconds(15)
        while vm.isScanning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!vm.isScanning)
        let target = try #require(vm.rootNode?.children.first { $0.name == "first.dmg" })
        let remaining = try #require(vm.rootNode?.children.first { $0.name == "second.dmg" })
        try #require(vm.cleanupReport?.recommendations.count == 2)
        let workspace = RescueWorkspaceModel(vm: vm, defaults: defaults)
        try #require(workspace.rows.first?.itemCount == 2)

        try await vm.deletePermanently([target])
        workspace.hostDidChange()

        #expect(vm.cleanupReport?.recommendations.map(\.node.id) == [remaining.id])
        #expect(vm.rescuePlan?.recommendations.map(\.node.id) == [remaining.id])
        #expect(workspace.rows.count == 1)
        #expect(workspace.rows.first?.itemCount == 1)
        #expect(workspace.rows.first?.bytes == remaining.physicalSize)
        #expect(FileManager.default.fileExists(atPath: remaining.url.path))
    }

    @Test("A cancelled background tree read holds cleanup until the worker returns")
    func treeReadExcludesRemoval() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([1]).write(to: url.appendingPathComponent("data"))
        let suiteName = TestPreferenceDomain.prefix + UUID().uuidString
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
        let suiteName = TestPreferenceDomain.prefix + UUID().uuidString
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
