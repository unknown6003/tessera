import Testing
import Foundation
@testable import Tessera

// MARK: - Fakes

@MainActor
private final class FakeRescueHost: RescueHost {
    var rescueSelectedSource: URL? = URL(fileURLWithPath: "/fixture")
    var rescueReportSource: String? = "/fixture"
    var rescueRevision: ScanTreeRevision
    var rescueReport: CleanupReport?
    var rescueIsScanning = false
    var rescueIsBusy = false
    var ownerStates: [CleanupOwnerState] = [.stopped]
    var rescueCurrentOwnerState: CleanupOwnerState {
        if ownerStates.count > 1 { return ownerStates.removeFirst() }
        return ownerStates.first ?? .unknown
    }
    var rescueMeasuredAt: Date? = Date(timeIntervalSince1970: 1)
    var acceptsStaging = true
    var staged: [FileNode] = []
    var rescueCollectedNodes: [FileNode] { staged }
    var scans: [URL] = []
    let root: FileNode

    init(report: CleanupReport?, root: FileNode) {
        self.rescueReport = report
        self.root = root
        self.rescueRevision = ScanTreeRevision(rootID: ObjectIdentifier(root), revision: 1)
    }

    func rescueStage(_ node: FileNode) -> Bool {
        guard acceptsStaging else { return false }
        staged.append(node)
        return true
    }
    func rescueStartScan(_ url: URL) { scans.append(url) }
    func rescueRead<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value? {
        rescueIsBusy ? nil : work()
    }
}

@MainActor
private final class FakeOpener: RescueOwnerOpening {
    var installed: Set<String> = []
    var opens: [URL] = []
    var reveals: [[URL]] = []
    var revealSucceeds = true

    func applicationURL(bundleID: String) -> URL? {
        installed.contains(bundleID) ? URL(fileURLWithPath: "/Applications/\(bundleID).app") : nil
    }
    func openApplication(at url: URL) async -> Bool { opens.append(url); return true }
    func reveal(_ urls: [URL]) -> Bool { reveals.append(urls); return revealSucceeds }
}

private func identity(_ path: String, inode: UInt64, size: Int64) -> ScanIdentity {
    ScanIdentity(path: path, volumeIdentifier: "vol-1", device: 1, inode: inode,
                 resourceType: .directory, allocatedSize: size)
}

private func node(_ name: String, size: Int64, inode: UInt64?) -> FileNode {
    let path = "/fixture/\(name)"
    return FileNode(url: URL(fileURLWithPath: path), name: name, isDirectory: true, size: size,
                    identity: inode.map { identity(path, inode: $0, size: size) })
}

private func freshDefaults() -> (UserDefaults, String) {
    let name = TestPreferenceDomain.prefix + "rescue." + UUID().uuidString
    return (UserDefaults(suiteName: name)!, name)
}

@MainActor
private func waitForReview(_ model: RescueWorkspaceModel) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while model.review == nil, model.isOpeningReview, ContinuousClock.now < deadline {
        await Task.yield()
    }
    try #require(model.review != nil)
}

// MARK: - Tests

@Suite("Rescue workspace")
@MainActor
struct RescueWorkspaceTests {
    /// A small safe group, a larger review group and the largest managed store.
    private func fixture(defaults: UserDefaults,
                         identityCheck: @escaping @Sendable (String) -> ScanIdentity? = { _ in nil },
                         opener: FakeOpener = FakeOpener(),
                         capacity: @escaping (URL) -> RescueCapacityReading = { _ in
                             RescueCapacityReading(volumeID: "vol-1", freeBytes: 10, availableBytes: nil,
                                                   checkedAt: Date())
                         })
        -> (RescueWorkspaceModel, FakeRescueHost, [CleanupRecommendation]) {
        let derived = node("DerivedData", size: 100, inode: 11)
        let cacheA = node("CacheA", size: 300, inode: 12)
        let cacheB = node("CacheB", size: 200, inode: 13)
        let unidentified = node("CacheC", size: 50, inode: nil)
        let docker = node(".docker", size: 900, inode: 14)
        let recommendations = [
            CleanupRecommendation(node: derived, category: CleanupCatalog.xcodeDerived),
            CleanupRecommendation(node: cacheA, category: CleanupCatalog.userCaches),
            CleanupRecommendation(node: cacheB, category: CleanupCatalog.userCaches),
            CleanupRecommendation(node: unidentified, category: CleanupCatalog.userCaches),
            CleanupRecommendation(node: docker, category: CleanupCatalog.protectedVirtualDisk),
        ]
        let root = FileNode(url: URL(fileURLWithPath: "/fixture"), name: "fixture", isDirectory: true, size: 1550,
                            children: [derived, cacheA, cacheB, unidentified, docker])
        let host = FakeRescueHost(report: CleanupReport(recommendations: recommendations), root: root)
        let model = RescueWorkspaceModel(host: host, opener: opener, defaults: defaults,
                                         readCapacity: capacity, currentIdentity: identityCheck,
                                         observeApp: false)
        return (model, host, recommendations)
    }

    @Test("Rows rank by allocated size, not by risk tier, and filters split files from managed stores")
    func ranking() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, _, _) = fixture(defaults: defaults)
        #expect(model.rows.map(\.bytes) == [900, 550, 100])
        #expect(model.rows.first?.kind == .managed)
        #expect(model.rows.first?.actionTitle == "Review options")
        model.filter = .files
        #expect(model.visibleRows.map(\.bytes) == [550, 100])
        model.filter = .managed
        #expect(model.visibleRows.count == 1)
        #expect(model.count(for: .all) == 3)
    }

    @Test("Keep hides one exact object, persists, ignores a replacement, and restores")
    func keepAndRestore() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, host, recs) = fixture(defaults: defaults)
        let cacheA = recs[1]
        model.keep(cacheA)
        let caches = model.rows.first { $0.categoryID == CleanupCatalog.userCaches.id }
        #expect(caches?.bytes == 250)
        #expect(caches?.keptCount == 1)

        // A second coordinator with the same store sees the kept choice.
        let again = RescueWorkspaceModel(host: host, opener: FakeOpener(), defaults: defaults, observeApp: false)
        #expect(again.keptForCurrentSource.count == 1)
        #expect(again.isResolved(again.keptForCurrentSource[0]))

        // A new object at the same path does not inherit the choice.
        let replacement = CleanupRecommendation(node: node("CacheA", size: 300, inode: 99),
                                                category: CleanupCatalog.userCaches)
        host.rescueReport = CleanupReport(recommendations: [replacement])
        host.rescueRevision = ScanTreeRevision(rootID: host.rescueRevision.rootID, revision: 2)
        again.hostDidChange()
        #expect(again.rows.first?.bytes == 300)
        #expect(!again.isResolved(again.keptForCurrentSource[0]))

        // The same object on another source is not hidden either.
        let item = again.keptForCurrentSource[0]
        #expect(!item.matches(cacheA, sourcePath: "/other"))

        again.restore(item)
        #expect(again.keptForCurrentSource.isEmpty)
        let reloaded = RescueWorkspaceModel(host: host, opener: FakeOpener(), defaults: defaults, observeApp: false)
        #expect(reloaded.keptItems.isEmpty)
    }

    @Test("An item without a stable identity cannot be kept")
    func keepNeedsIdentity() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, _, recs) = fixture(defaults: defaults)
        #expect(!model.canKeep(recs[3]))
        model.keep(recs[3])
        #expect(model.keptItems.isEmpty)
    }

    @Test("Review starts empty, holds ineligible items, and stages only unchanged explicit choices")
    func reviewStaging() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        // CacheB changed on disk after the scan.
        let check: @Sendable (String) -> ScanIdentity? = { path in
            path.hasSuffix("CacheB") ? identity(path, inode: 77, size: 200) : identity(path, inode: path.hasSuffix("CacheA") ? 12 : 0, size: 300)
        }
        let (model, host, _) = fixture(defaults: defaults, identityCheck: check)
        let caches = try #require(model.rows.first { $0.bytes == 550 })
        model.openReview(caches)
        try await waitForReview(model)
        #expect(model.selection.isEmpty)
        #expect(model.reviewItems.map(\.recommendation.node.name) == ["CacheA", "CacheB", "CacheC"])
        #expect(model.reviewItems.last?.heldReason != nil)

        model.selectAllEligible()
        #expect(model.selection.count == 2)
        #expect(model.selectedBytes == 500)
        await model.stageSelection()
        #expect(host.staged.map(\.name) == ["CacheA"])
        #expect(model.reviewNotice?.contains("Held 1") == true)

        model.closeReview()
        #expect(model.review == nil)
        #expect(model.returnGroupID == caches.id)
    }

    @Test("Staged items stay inspectable but cannot inflate a new staging choice")
    func stagedItemsAreNotEligible() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, host, _) = fixture(defaults: defaults)
        let row = try #require(model.rows.first { $0.bytes == 550 })
        model.openReview(row)
        try await waitForReview(model)
        let item = try #require(model.reviewItems.first)
        model.toggle(item)
        #expect(model.selection == [item.recommendation.id])
        host.staged = [item.recommendation.node]
        model.hostDidChange()
        #expect(model.selection.isEmpty)
        #expect(model.reviewItems.count == 3)
        model.toggle(item)
        #expect(model.selection.isEmpty)
        model.selectAllEligible()
        #expect(model.selection.count == 1)
        #expect(model.selectedBytes == 200)
        #expect(!model.eligibleVisibleIDs.contains(item.recommendation.id))
        host.staged = []
        model.hostDidChange()
        model.selectAllEligible()
        #expect(model.selection.count == 2)
        #expect(model.selectedBytes == 500)
    }

    @Test("Back keeps explicit choices only within the same source and revision")
    func backKeepsChoices() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, host, _) = fixture(defaults: defaults)
        let row = try #require(model.rows.first { $0.bytes == 550 })
        model.openReview(row)
        try await waitForReview(model)
        let item = try #require(model.reviewItems.first)
        model.toggle(item)
        model.closeReview()
        model.openReview(row)
        try await waitForReview(model)
        #expect(model.selection == [item.recommendation.id])
        host.rescueRevision = ScanTreeRevision(rootID: host.rescueRevision.rootID, revision: 2)
        model.hostDidChange()
        model.openReview(row)
        try await waitForReview(model)
        #expect(model.selection.isEmpty)
    }

    @Test("Focused item offsets stay correct as the review search changes")
    func filteredFocusIndex() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, host, _) = fixture(defaults: defaults)
        model.openReview(try #require(model.rows.first { $0.bytes == 550 }))
        try await waitForReview(model)
        let item = try #require(model.reviewItems.first { $0.recommendation.node.name == "CacheB" })
        model.detailItemID = item.recommendation.id
        #expect(model.detailIndex == 1)
        model.reviewSearch = "CacheB"
        #expect(model.detailIndex == 0)
        #expect(model.detailItem?.recommendation.id == item.recommendation.id)
        model.reviewSearch = "CacheA"
        #expect(model.detailIndex == nil)
        #expect(model.detailItem == nil)
        model.reviewSearch = ""
        #expect(model.detailIndex == 1)
        #expect(host.staged.isEmpty)
    }

    @Test("Managed stores cannot be selected")
    func managedHeld() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let (model, host, _) = fixture(defaults: defaults)
        model.openReview(try #require(model.rows.first))
        try await waitForReview(model)
        #expect(model.eligibleVisibleIDs.isEmpty)
        model.toggle(try #require(model.reviewItems.first))
        #expect(model.selection.isEmpty)
        await model.stageSelection()
        #expect(host.staged.isEmpty)
        #expect(model.review?.route?.ownerName == "Docker")
    }

    @Test("A new scan revision or source drops the review and stages nothing")
    func staleReview() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let check: @Sendable (String) -> ScanIdentity? = { identity($0, inode: 12, size: 300) }
        let (model, host, _) = fixture(defaults: defaults, identityCheck: check)
        let caches = try #require(model.rows.first { $0.bytes == 550 })

        model.openReview(caches)
        try await waitForReview(model)
        model.selectAllEligible()
        host.rescueRevision = ScanTreeRevision(rootID: host.rescueRevision.rootID, revision: 9)
        await model.stageSelection()
        #expect(host.staged.isEmpty)
        #expect(model.review == nil)

        host.rescueRevision = ScanTreeRevision(rootID: host.rescueRevision.rootID, revision: 10)
        model.hostDidChange()
        model.openReview(caches)
        try await waitForReview(model)
        model.selectAllEligible()
        host.rescueReportSource = "/elsewhere"
        model.hostDidChange()
        #expect(model.review == nil)
        await model.stageSelection()
        #expect(host.staged.isEmpty)
    }

    @Test("Staging waits while a scan or removal is busy")
    func busyBlocksStaging() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let check: @Sendable (String) -> ScanIdentity? = { identity($0, inode: 12, size: 300) }
        let (model, host, _) = fixture(defaults: defaults, identityCheck: check)
        model.openReview(try #require(model.rows.first { $0.bytes == 550 }))
        try await waitForReview(model)
        model.selectAllEligible()
        host.rescueIsScanning = true
        #expect(!model.canStage)
        await model.stageSelection()
        #expect(host.staged.isEmpty)
    }

    @Test("A selected source mismatch and refused collector additions never report success")
    func refusedStaging() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let check: @Sendable (String) -> ScanIdentity? = { identity($0, inode: 12, size: 300) }
        let (model, host, _) = fixture(defaults: defaults, identityCheck: check)
        model.openReview(try #require(model.rows.first { $0.bytes == 550 }))
        try await waitForReview(model)
        model.selectAllEligible()
        host.rescueSelectedSource = URL(fileURLWithPath: "/other")
        #expect(!model.canStage)
        await model.stageSelection()
        #expect(host.staged.isEmpty)
        host.rescueSelectedSource = URL(fileURLWithPath: "/fixture")
        host.acceptsStaging = false
        await model.stageSelection()
        #expect(host.staged.isEmpty)
        #expect(model.reviewNotice?.hasPrefix("Nothing was added.") == true)
    }

    @Test("Generated items hold when their owner is active or starts during identity checks")
    func ownerChangeBlocksStaging() async throws {
        let scenarios: [[CleanupOwnerState]] = [[.active], [.stopped, .active], [.unknown]]
        for states in scenarios {
            let (defaults, name) = freshDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            let check: @Sendable (String) -> ScanIdentity? = { identity($0, inode: 11, size: 100) }
            let (model, host, _) = fixture(defaults: defaults, identityCheck: check)
            let row = try #require(model.rows.first { $0.bytes == 100 })
            model.openReview(row)
            try await waitForReview(model)
            model.selectAllEligible()
            host.ownerStates = states
            await model.stageSelection()
            #expect(host.staged.isEmpty)
            #expect(model.review == nil)
            #expect(model.reviewNotice?.contains("Nothing was added") == true)
        }
    }

    @Test("The goal measures Free now change on the same drive only")
    func goalMeasurement() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let gb: Int64 = 1_000_000_000
        var next = RescueCapacityReading(volumeID: "vol-1", freeBytes: 10 * gb, availableBytes: 40 * gb, checkedAt: Date())
        let (model, host, _) = fixture(defaults: defaults, capacity: { _ in next })
        model.setGoal(additionalGB: 5)
        #expect(model.goal?.status == .progress(change: 0, remaining: 5 * gb))

        // Staged bytes do not move the goal.
        host.staged = [host.root]
        next = RescueCapacityReading(volumeID: "vol-1", freeBytes: 13 * gb, availableBytes: 45 * gb, checkedAt: Date())
        model.checkGoal()
        #expect(model.goal?.status == .progress(change: 3 * gb, remaining: 2 * gb))

        next = RescueCapacityReading(volumeID: "vol-1", freeBytes: 9 * gb, availableBytes: 45 * gb, checkedAt: Date())
        model.checkGoal()
        #expect(model.goal?.status == .progress(change: -gb, remaining: 6 * gb))

        next = RescueCapacityReading(volumeID: "vol-1", freeBytes: 16 * gb, availableBytes: 45 * gb, checkedAt: Date())
        host.rescueMeasuredAt = Date(timeIntervalSince1970: 2)
        model.hostDidChange()
        #expect(model.goal?.status == .reached(change: 6 * gb))

        next = RescueCapacityReading(volumeID: "vol-2", freeBytes: 30 * gb, availableBytes: nil, checkedAt: Date())
        model.checkGoal()
        if case .unverified = model.goal?.status {} else { Issue.record("another drive must not verify the goal") }

        next = RescueCapacityReading(volumeID: "vol-1", freeBytes: nil, availableBytes: nil, checkedAt: Date())
        model.checkGoal()
        if case .unverified = model.goal?.status {} else { Issue.record("an unknown reading must not verify the goal") }
    }

    @Test("A goal reads the displayed report source when another source is selected")
    func goalUsesDisplayedSource() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        var reads: [String] = []
        var displayedFree: Int64 = 10_000_000_000
        let (model, host, _) = fixture(defaults: defaults, capacity: { url in
            reads.append(url.path)
            return RescueCapacityReading(volumeID: url.path,
                freeBytes: url.path == "/fixture" ? displayedFree : 100_000_000_000,
                availableBytes: nil, checkedAt: Date())
        })
        host.rescueSelectedSource = URL(fileURLWithPath: "/other-drive")
        model.setGoal(additionalGB: 1)
        #expect(reads == ["/fixture"])
        displayedFree += 500_000_000
        model.checkGoal()
        #expect(reads == ["/fixture", "/fixture"])
        #expect(model.goal?.status == .progress(change: 500_000_000, remaining: 500_000_000))
    }

    @Test("Mixed communication stores route the visible or inspected item to its owner")
    func mixedOwnerRoutes() async throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let messages = FileNode(url: URL(fileURLWithPath: "/fixture/Users/q/Library/Messages"),
            name: "Messages", isDirectory: true, size: 300)
        let signal = FileNode(url: URL(fileURLWithPath: "/fixture/Users/q/Library/Application Support/Signal"),
            name: "Signal", isDirectory: true, size: 100)
        let recommendations = [messages, signal].map {
            CleanupRecommendation(node: $0, category: CleanupCatalog.protectedCommunication)
        }
        let root = FileNode(url: URL(fileURLWithPath: "/fixture"), name: "fixture",
            isDirectory: true, size: 400, children: [messages, signal])
        let host = FakeRescueHost(report: CleanupReport(recommendations: recommendations), root: root)
        let model = RescueWorkspaceModel(host: host, opener: FakeOpener(), defaults: defaults,
            observeApp: false)
        let row = try #require(model.rows.first)
        #expect(model.route(for: row)?.bundleID == nil)
        model.openReview(row)
        try await waitForReview(model)
        #expect(model.reviewOwnerRoute?.bundleID == nil)
        model.reviewSearch = "Signal"
        #expect(model.reviewOwnerRoute?.ownerName == "Finder")
        #expect(model.reviewOwnerPaths == [signal.url.path])
        model.reviewSearch = ""
        model.detailItemID = recommendations[0].id
        #expect(model.reviewOwnerRoute?.bundleID == "com.apple.MobileSMS")
        #expect(model.reviewOwnerPaths == [messages.url.path])
    }

    @Test("Owner return refreshes once, only after leaving through this flow")
    func ownerReturnOnce() async {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let opener = FakeOpener()
        opener.installed = ["com.docker.docker"]
        let (model, host, _) = fixture(defaults: defaults, opener: opener)

        // An ordinary app switch does nothing.
        model.appDidResignActive()
        model.appDidBecomeActive()
        #expect(host.scans.isEmpty)

        let route = RescueOwnerRoute.route(categoryID: "owner.virtualdisk", path: "/fixture/.docker")
        await model.openOwner(route, revealing: ["/fixture/.docker"])
        #expect(opener.opens.count == 1)
        #expect(model.handoff == .waiting(ownerName: "Docker"))

        // Activation without leaving first is not a return.
        model.appDidBecomeActive()
        #expect(host.scans.isEmpty)

        model.appDidResignActive()
        model.appDidBecomeActive()
        model.appDidBecomeActive()
        model.appDidResignActive()
        model.appDidBecomeActive()
        #expect(host.scans == [URL(fileURLWithPath: "/fixture")])
        #expect(model.handoff == .none)
    }

    @Test("Owner return waits for a busy lock and drops a changed source")
    func ownerReturnBusyAndSource() async {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let opener = FakeOpener()
        opener.installed = ["com.docker.docker"]
        let (model, host, _) = fixture(defaults: defaults, opener: opener)
        let route = RescueOwnerRoute.route(categoryID: "owner.docker", path: "/fixture/.docker")

        await model.openOwner(route, revealing: [])
        model.appDidResignActive()
        host.rescueIsBusy = true
        model.appDidBecomeActive()
        #expect(host.scans.isEmpty)
        #expect(model.handoff == .deferred(ownerName: "Docker"))
        model.hostDidChange()
        #expect(host.scans.isEmpty)
        host.rescueIsBusy = false
        model.hostDidChange()
        model.hostDidChange()
        #expect(host.scans.count == 1)

        await model.openOwner(route, revealing: [])
        model.appDidResignActive()
        host.rescueSelectedSource = URL(fileURLWithPath: "/other")
        model.hostDidChange()
        model.appDidBecomeActive()
        #expect(host.scans.count == 1)
        #expect(model.handoff == .none)
    }

    @Test("A failed owner launch can be retried without leaving the review")
    func retryOwner() async {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let opener = FakeOpener()
        let (model, host, _) = fixture(defaults: defaults, opener: opener)
        let route = RescueOwnerRoute.route(categoryID: "owner.docker", path: "/fixture/.docker")
        await model.openOwner(route, revealing: ["/fixture/.docker"])
        #expect(opener.opens.isEmpty)
        opener.installed = ["com.docker.docker"]
        await model.retryOwnerHandoff()
        #expect(opener.opens.count == 1)
        model.appDidResignActive()
        model.appDidBecomeActive()
        #expect(host.scans.count == 1)
    }

    @Test("A missing owner falls back to Finder and arms no refresh")
    func missingOwner() async {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let opener = FakeOpener()
        let (model, host, _) = fixture(defaults: defaults, opener: opener)
        let route = RescueOwnerRoute.route(categoryID: "owner.orbstack", path: "/x")
        await model.openOwner(route, revealing: ["/fixture/.docker"])
        #expect(opener.reveals.count == 1)
        if case .failed(let message) = model.handoff {
            #expect(message.contains("OrbStack"))
        } else {
            Issue.record("a missing owner must explain the failure")
        }
        model.appDidResignActive()
        model.appDidBecomeActive()
        #expect(host.scans.isEmpty)

        // An unknown protected class keeps a working Finder route.
        let unknown = RescueOwnerRoute.route(categoryID: "owner.something-new", path: "/x")
        #expect(unknown.bundleID == nil)
        #expect(unknown.actionTitle == "Show in Finder")
    }
}
