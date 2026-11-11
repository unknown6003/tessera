import SwiftUI
import AppKit
import Combine

// MARK: - Host seam

/// The scan state Rescue reads, and the three existing actions it may call.
/// ScanViewModel is the live host. Tests use a small fake. The host never
/// gets a removal method from this seam.
@MainActor
protocol RescueHost: AnyObject {
    /// The source the person chose. A pending owner return is for this source.
    var rescueSelectedSource: URL? { get }
    /// The source of the published report.
    var rescueReportSource: String? { get }
    var rescueRevision: ScanTreeRevision { get }
    var rescueReport: CleanupReport? { get }
    var rescueIsScanning: Bool { get }
    /// Removal or another lock that must stop a new scan or staging.
    var rescueIsBusy: Bool { get }
    /// When the published capacity reading was taken.
    var rescueMeasuredAt: Date? { get }
    func rescueStage(_ node: FileNode) -> Bool
    func rescueStartScan(_ url: URL)
    /// Run bounded read work off the main thread. Nil when the tree is busy.
    func rescueRead<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value?
}

extension ScanViewModel: RescueHost {
    var rescueSelectedSource: URL? { selectedSourceURL?.standardizedFileURL }
    var rescueReportSource: String? { rescuePlan?.sourcePath }
    var rescueRevision: ScanTreeRevision { treeRevision }
    var rescueReport: CleanupReport? { cleanupReport }
    var rescueIsScanning: Bool { isScanning }
    var rescueIsBusy: Bool { isDeleting }
    var rescueMeasuredAt: Date? { rescuePlan?.measurement.measuredAt }
    func rescueStage(_ node: FileNode) -> Bool {
        let wasCollected = isCollected(node)
        addToCollector(node)
        return !wasCollected && collector.contains { $0 === node }
    }
    func rescueStartScan(_ url: URL) { startScan(volumeURL: url) }
    func rescueRead<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value? {
        await readTree { _, _ in work() }
    }
}

// MARK: - System seams

/// Opens owners and Finder. The live value uses public NSWorkspace calls.
@MainActor
protocol RescueOwnerOpening {
    func applicationURL(bundleID: String) -> URL?
    func openApplication(at url: URL) async -> Bool
    func reveal(_ urls: [URL]) -> Bool
}

struct SystemOwnerOpener: RescueOwnerOpening {
    func applicationURL(bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    func openApplication(at url: URL) async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                continuation.resume(returning: app != nil && error == nil)
            }
        }
    }

    func reveal(_ urls: [URL]) -> Bool {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return false }
        NSWorkspace.shared.activateFileViewerSelecting(existing)
        return true
    }
}

/// One plain capacity read for the drive that holds a source.
struct RescueCapacityReading: Equatable, Sendable {
    let volumeID: String?
    let freeBytes: Int64?
    let availableBytes: Int64?
    let checkedAt: Date

    static func read(_ url: URL, at date: Date = Date()) -> RescueCapacityReading {
        let values = try? url.resourceValues(forKeys: [
            .volumeIdentifierKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        return RescueCapacityReading(
            volumeID: values?.volumeIdentifier.map { String(describing: $0) },
            freeBytes: values?.volumeAvailableCapacity.map(Int64.init),
            availableBytes: values?.volumeAvailableCapacityForImportantUsage,
            checkedAt: date)
    }
}

// MARK: - Value types

enum RescueFilter: String, CaseIterable, Identifiable {
    case all, files, managed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .files: return "Files to review"
        case .managed: return "Managed by apps"
        }
    }
}

/// The verified way to manage an owner store. Unknown classes keep a generic
/// Finder route, so no row ends on dead text.
struct RescueOwnerRoute: Equatable, Sendable {
    let ownerName: String
    /// Nil means Finder is the route.
    let bundleID: String?
    /// Plain steps to follow in the owner.
    let steps: String
    let dataAtRisk: String

    var actionTitle: String { bundleID == nil ? "Show in Finder" : "Open \(ownerName)" }

    static func route(categoryID: String, path: String) -> RescueOwnerRoute {
        let p = path.lowercased()
        switch categoryID {
        case "owner.docker":
            return docker
        case "owner.orbstack":
            return orbStack
        case "owner.virtualdisk":
            if p.contains("orbstack") { return orbStack }
            if p.contains("/.docker") || p.hasSuffix("docker.raw") || p.contains("/containers/com.docker") { return docker }
            if p.hasSuffix(".utm") || p.contains(".utm/") {
                return RescueOwnerRoute(ownerName: "UTM", bundleID: "com.utmapp.UTM",
                    steps: "Shut the VM down. Use its drive settings to reclaim space, or remove a VM you no longer need. Back it up first.",
                    dataAtRisk: "The guest system, its apps and files, and any snapshots.")
            }
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "Open the virtual machine app that made this file. Shut the VM down and manage its disk there.",
                dataAtRisk: "The guest system, its apps and files, and any snapshots.")
        case "owner.simulators":
            return RescueOwnerRoute(ownerName: "Xcode", bundleID: "com.apple.dt.Xcode",
                steps: "In Xcode, open Settings > Components and remove runtimes you do not test on.",
                dataAtRisk: "The test environment for that runtime. You can download it again.")
        case "owner.photos":
            return RescueOwnerRoute(ownerName: "Photos", bundleID: "com.apple.Photos",
                steps: "In Photos, open Settings > iCloud and choose Optimize Mac Storage, or move the library to an external drive and open it there first.",
                dataAtRisk: "Originals and edits. Deletions in iCloud Photos reach your other devices.")
        case "owner.mail":
            return RescueOwnerRoute(ownerName: "Mail", bundleID: "com.apple.mail",
                steps: "In Mail, delete large messages or attachments you saved elsewhere, then empty Mail's Trash.",
                dataAtRisk: "Messages and attachments. On IMAP accounts, deletion also reaches the server.")
        case "owner.snapshots":
            return RescueOwnerRoute(ownerName: "Disk Utility", bundleID: "com.apple.DiskUtility",
                steps: "In Disk Utility, choose View > Show APFS Snapshots to inspect them. macOS also removes local snapshots when it needs space.",
                dataAtRisk: "Earlier versions of your files.")
        case "owner.communication":
            if p.contains("/library/messages") {
                return RescueOwnerRoute(ownerName: "Messages", bundleID: "com.apple.MobileSMS",
                    steps: "In Messages, delete large conversations or attachments you do not need.",
                    dataAtRisk: "Conversations and attachments. Deletion can sync to your other devices.")
            }
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "Open the app that owns this data and use its own storage controls.",
                dataAtRisk: "Messages, attachments, drafts and sync state.")
        case "owner.backup":
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "Connect the device, select it in Finder, then open General > Manage Backups. Check a backup before you delete or archive it.",
                dataAtRisk: "That backup's restore point. It may be the only copy.")
        case "owner.cloud":
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "In Finder, select the downloaded items and choose Remove Download. Check that sync has finished first.",
                dataAtRisk: "Offline access until you download the items again.")
        case "owner.profile":
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "Quit the app, then use its own clear-data or cache setting.",
                dataAtRisk: "Sessions, saved logins, drafts and history.")
        case "system.trash":
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "Review the Trash in Finder. Put back anything you need, then empty it from Finder.",
                dataAtRisk: "Trash recovery for everything in it.")
        default:
            return RescueOwnerRoute(ownerName: "Finder", bundleID: nil,
                steps: "Open the app that owns this data and use its own storage controls.",
                dataAtRisk: "Data that the owner app manages.")
        }
    }

    private static let docker = RescueOwnerRoute(ownerName: "Docker", bundleID: "com.docker.docker",
        steps: "In Docker, review images, stopped containers, volumes and build cache. Remove only what you no longer need.",
        dataAtRisk: "Volumes and stopped containers can hold data you want.")
    private static let orbStack = RescueOwnerRoute(ownerName: "OrbStack", bundleID: "dev.kdrag0n.MacVirt",
        steps: "In OrbStack, remove unused containers, images, volumes or machines. Its disk file shrinks as data is deleted.",
        dataAtRisk: "Volumes, machines and stopped containers can hold data you want.")
}

/// One row of the ranked list.
struct RescueGroupRow: Identifiable, Equatable {
    enum Kind: Equatable { case files, managed }

    let id: String
    let title: String
    let owner: String
    let reason: String
    let effect: String
    let symbol: String
    let bytes: Int64
    let itemCount: Int
    let keptCount: Int
    let kind: Kind
    let categoryID: String
    let firstPath: String?

    var actionTitle: String { kind == .files ? "Review files" : "Review options" }
}

/// One explicit Keep choice. Matching needs the object identity as well as
/// the path, so a replacement at the same path does not inherit it.
struct RescueKeptItem: Codable, Equatable, Identifiable {
    let id: UUID
    let categoryID: String
    let path: String
    let sourcePath: String
    let volumeIdentifier: String?
    let resourceIdentifier: String?
    let device: UInt32?
    let inode: UInt64?
    let keptAt: Date

    init?(recommendation: CleanupRecommendation, sourcePath: String, at date: Date = Date()) {
        guard let identity = recommendation.identity, identity.hasStableObjectIdentifier else { return nil }
        id = UUID()
        categoryID = recommendation.category.id
        path = recommendation.path
        self.sourcePath = sourcePath
        volumeIdentifier = identity.volumeIdentifier
        resourceIdentifier = identity.resourceIdentifier
        device = identity.device
        inode = identity.inode
        keptAt = date
    }

    func matches(_ recommendation: CleanupRecommendation, sourcePath: String) -> Bool {
        guard self.sourcePath == sourcePath, path == recommendation.path,
              categoryID == recommendation.category.id,
              let identity = recommendation.identity, identity.hasStableObjectIdentifier else { return false }
        if let volumeIdentifier, identity.volumeIdentifier != volumeIdentifier { return false }
        if let device, identity.device != device { return false }
        if let resourceIdentifier {
            return identity.resourceIdentifier == resourceIdentifier
        }
        guard let inode else { return false }
        return identity.inode == inode
    }
}

/// An optional goal: this many more bytes free on the source's drive.
struct RescueSpaceGoal: Equatable {
    enum Status: Equatable {
        /// The baseline or the latest reading is missing or on another drive.
        case unverified(String)
        case progress(change: Int64, remaining: Int64)
        case reached(change: Int64)
    }

    let additionalBytes: Int64
    let baseline: RescueCapacityReading
    var latest: RescueCapacityReading

    var status: Status {
        guard let base = baseline.freeBytes else { return .unverified("Free space could not be read when the goal was set.") }
        guard let now = latest.freeBytes else { return .unverified("Free space could not be read.") }
        guard baseline.volumeID != nil, baseline.volumeID == latest.volumeID else {
            return .unverified("The reading is for a different drive.")
        }
        let change = now - base
        return change >= additionalBytes
            ? .reached(change: change)
            : .progress(change: change, remaining: additionalBytes - change)
    }
}

/// A frozen, sorted view of one group, built off the main thread.
final class RescueReviewSnapshot: Identifiable {
    struct Item: Sendable {
        let recommendation: CleanupRecommendation
        let lowerName: String
        /// Nil when the item can be staged.
        let heldReason: String?
    }

    let groupID: String
    let title: String
    let kind: RescueGroupRow.Kind
    let route: RescueOwnerRoute?
    let sourcePath: String
    let revision: ScanTreeRevision
    let items: [Item]
    private let indexByNode: [ObjectIdentifier: Int]

    init(groupID: String, title: String, kind: RescueGroupRow.Kind, route: RescueOwnerRoute?,
         sourcePath: String, revision: ScanTreeRevision, items: [Item]) {
        self.groupID = groupID
        self.title = title
        self.kind = kind
        self.route = route
        self.sourcePath = sourcePath
        self.revision = revision
        self.items = items
        var index: [ObjectIdentifier: Int] = [:]
        index.reserveCapacity(items.count)
        for (offset, item) in items.enumerated() { index[item.recommendation.node.id] = offset }
        indexByNode = index
    }

    func item(for node: FileNode) -> Item? { indexByNode[node.id].map { items[$0] } }

    /// Largest first; ties by path. Eligibility checks walk each directory
    /// once, so this runs off the main thread.
    static func buildItems(_ recommendations: [CleanupRecommendation]) -> [Item] {
        recommendations
            .sorted {
                $0.physicalBytes != $1.physicalBytes ? $0.physicalBytes > $1.physicalBytes : $0.path < $1.path
            }
            .map { recommendation in
                Item(recommendation: recommendation,
                     lowerName: recommendation.node.name.lowercased(),
                     heldReason: heldReason(recommendation))
            }
    }

    static func heldReason(_ recommendation: CleanupRecommendation) -> String? {
        if recommendation.risk == .protected || recommendation.action == .handoff {
            return "Managed by \(recommendation.owner). Use the owner route."
        }
        if recommendation.node.isSynthetic { return "This describes space, not a file." }
        if !(recommendation.identity?.hasStableObjectIdentifier ?? false) {
            return "Tessera cannot identify this item reliably. Scan again."
        }
        if CleanupClassifier.protectedCategory(for: recommendation.path) != nil
            || CleanupClassifier.hasProtectedDescendant(recommendation.node) {
            return "It contains protected owner data. Review its contents in Explore."
        }
        if CleanupClassifier.hasOpaqueDescendant(recommendation.node) {
            return "Part of it was not scanned. Review its contents in Explore."
        }
        return nil
    }
}

// MARK: - Coordinator

/// Rescue's local state: ranked rows, review, kept items, the optional goal
/// and owner returns. It stages only through the host's collector and never
/// removes anything. Names and paths stay on this Mac.
@MainActor
final class RescueWorkspaceModel: ObservableObject {
    enum HandoffState: Equatable {
        case none
        /// The owner opened. Waiting for Tessera to lose and regain focus.
        case waiting(ownerName: String)
        /// The person came back while a scan or removal was busy.
        case deferred(ownerName: String)
        case failed(String)
    }

    static let keptItemsKey = "rescue.keptItems.v1"

    @Published var filter: RescueFilter = .all
    @Published var searchText = ""
    @Published private(set) var rows: [RescueGroupRow] = []
    @Published private(set) var keptItems: [RescueKeptItem] = []
    @Published var showsExcluded = false

    @Published private(set) var review: RescueReviewSnapshot? { didSet { refreshReviewItems() } }
    @Published private(set) var isOpeningReview = false
    @Published var reviewSearch = "" { didSet { refreshReviewItems() } }
    /// The review's visible items, cached so a render never refilters 100k rows.
    @Published private(set) var reviewItems: [RescueReviewSnapshot.Item] = []
    /// The same items as nodes, for WindowedRows.
    @Published private(set) var reviewNodes: [FileNode] = []
    @Published var selection = Set<String>()
    @Published var detailItemID: String?
    @Published private(set) var reviewNotice: String?
    @Published private(set) var isStaging = false
    /// The group last opened. Back brings its row into view and focus.
    @Published private(set) var returnGroupID: String?

    @Published private(set) var goal: RescueSpaceGoal?
    @Published private(set) var handoff: HandoffState = .none

    private weak var host: (any RescueHost)?
    private let opener: any RescueOwnerOpening
    private let defaults: UserDefaults
    private let readCapacity: (URL) -> RescueCapacityReading
    private let currentIdentity: @Sendable (String) -> ScanIdentity?

    private var departureGeneration: UInt64 = 0
    private var pendingHandoff: (source: URL, ownerName: String, leftApp: Bool)?
    private struct ReportKey: Equatable {
        let revision: ScanTreeRevision
        let source: String?
        let measuredAt: Date?
    }
    private var lastReportKey: ReportKey?
    private var reviewTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(host: any RescueHost,
         opener: any RescueOwnerOpening = SystemOwnerOpener(),
         defaults: UserDefaults = .standard,
         readCapacity: @escaping (URL) -> RescueCapacityReading = { RescueCapacityReading.read($0) },
         currentIdentity: @escaping @Sendable (String) -> ScanIdentity? = {
             ScanIdentity.current(at: URL(fileURLWithPath: $0))
         },
         observeApp: Bool = true) {
        self.host = host
        self.opener = opener
        self.defaults = defaults
        self.readCapacity = readCapacity
        self.currentIdentity = currentIdentity
        keptItems = Self.loadKept(defaults)
        if observeApp {
            let center = NotificationCenter.default
            center.publisher(for: NSApplication.didResignActiveNotification)
                .sink { [weak self] _ in MainActor.assumeIsolated { self?.appDidResignActive() } }
                .store(in: &cancellables)
            center.publisher(for: NSApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in MainActor.assumeIsolated { self?.appDidBecomeActive() } }
                .store(in: &cancellables)
        }
        hostDidChange()
    }

    /// Observe a live view model. Cheap scalar checks run after each change.
    convenience init(vm: ScanViewModel, defaults: UserDefaults = .standard) {
        self.init(host: vm, defaults: defaults)
        vm.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.hostDidChange() } }
            .store(in: &cancellables)
    }

    // MARK: Host changes

    /// Call after the host publishes. Rebuilds rows only for a new report,
    /// drops a stale review, and runs a deferred owner-return check.
    func hostDidChange() {
        guard let host else { return }
        let key = ReportKey(revision: host.rescueRevision, source: host.rescueReportSource,
                            measuredAt: host.rescueMeasuredAt)
        if key != lastReportKey {
            let measurementChanged = key.measuredAt != lastReportKey?.measuredAt
            lastReportKey = key
            rebuildRows()
            if let review, review.revision != key.revision || review.sourcePath != key.source {
                closeReview(notice: "The scan changed. Open the group again to review current items.")
            }
            if measurementChanged, goal != nil { checkGoal() }
        }
        if let pending = pendingHandoff, pending.source != host.rescueSelectedSource {
            pendingHandoff = nil
            handoff = .none
        }
        if case .deferred = handoff { runOwnerReturnRefresh() }
    }

    // MARK: Ranked rows

    var visibleRows: [RescueGroupRow] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return rows.filter { row in
            switch filter {
            case .all: break
            case .files: guard row.kind == .files else { return false }
            case .managed: guard row.kind == .managed else { return false }
            }
            return query.isEmpty || row.title.lowercased().contains(query) || row.owner.lowercased().contains(query)
        }
    }

    func count(for filter: RescueFilter) -> Int {
        switch filter {
        case .all: return rows.count
        case .files: return rows.filter { $0.kind == .files }.count
        case .managed: return rows.filter { $0.kind == .managed }.count
        }
    }

    private func rebuildRows() {
        guard let host, let report = host.rescueReport, let source = host.rescueReportSource else {
            rows = []
            return
        }
        let keptByPath = Dictionary(grouping: keptItems.filter { $0.sourcePath == source }, by: \.path)
        var built: [(row: RescueGroupRow, order: Int)] = []
        for (order, group) in report.groups.enumerated() {
            var bytes: Int64 = 0
            var count = 0
            var kept = 0
            var firstPath: String?
            for recommendation in group.recommendations {
                if let candidates = keptByPath[recommendation.path],
                   candidates.contains(where: { $0.matches(recommendation, sourcePath: source) }) {
                    kept += 1
                    continue
                }
                bytes += recommendation.physicalBytes
                count += 1
                if firstPath == nil { firstPath = recommendation.path }
            }
            guard count > 0 else { continue }
            let managed = group.risk == .protected
            let row = RescueGroupRow(
                id: group.id, title: group.category.title, owner: group.category.owner,
                reason: group.category.explanation, effect: group.category.sideEffect,
                symbol: group.category.symbol, bytes: bytes, itemCount: count, keptCount: kept,
                kind: managed ? .managed : .files, categoryID: group.category.id, firstPath: firstPath)
            built.append((row, order))
        }
        // Largest measured footprint first. Ties keep the report's order.
        rows = built.sorted {
            $0.row.bytes != $1.row.bytes ? $0.row.bytes > $1.row.bytes : $0.order < $1.order
        }.map(\.row)
    }

    func route(for row: RescueGroupRow) -> RescueOwnerRoute? {
        row.kind == .managed ? RescueOwnerRoute.route(categoryID: row.categoryID, path: row.firstPath ?? "") : nil
    }

    // MARK: Review

    private func refreshReviewItems() {
        guard let review else {
            reviewItems = []
            reviewNodes = []
            return
        }
        let kept = Dictionary(grouping: keptItems.filter { $0.sourcePath == review.sourcePath }, by: \.path)
        let query = reviewSearch.trimmingCharacters(in: .whitespaces).lowercased()
        let items = review.items.filter { item in
            guard query.isEmpty || item.lowerName.contains(query) else { return false }
            guard let candidates = kept[item.recommendation.path] else { return true }
            return !candidates.contains { $0.matches(item.recommendation, sourcePath: review.sourcePath) }
        }
        reviewItems = items
        reviewNodes = items.map(\.recommendation.node)
    }

    func reviewItem(for node: FileNode) -> RescueReviewSnapshot.Item? { review?.item(for: node) }

    var detailItem: RescueReviewSnapshot.Item? {
        guard let detailItemID else { return nil }
        return reviewItems.first { $0.recommendation.id == detailItemID }
    }

    var detailIndex: Int? {
        guard let detailItemID else { return nil }
        return reviewItems.firstIndex { $0.recommendation.id == detailItemID }
    }

    /// Open one group in the main area. Nothing starts selected.
    func openReview(_ row: RescueGroupRow) {
        guard let host, let report = host.rescueReport, let source = host.rescueReportSource,
              let group = report.groups.first(where: { $0.id == row.id }) else { return }
        reviewTask?.cancel()
        returnGroupID = row.id
        selection = []
        detailItemID = nil
        reviewSearch = ""
        reviewNotice = nil
        isOpeningReview = true
        let revision = host.rescueRevision
        let recommendations = group.recommendations
        let route = self.route(for: row)
        reviewTask = Task { [weak self] in
            let items = await host.rescueRead { RescueReviewSnapshot.buildItems(recommendations) }
            guard let self, !Task.isCancelled else { return }
            self.isOpeningReview = false
            guard let items, host.rescueRevision == revision, host.rescueReportSource == source else {
                self.reviewNotice = "Tessera is busy or the scan changed. Try again in a moment."
                return
            }
            self.review = RescueReviewSnapshot(groupID: row.id, title: row.title, kind: row.kind,
                                               route: route, sourcePath: source, revision: revision,
                                               items: items)
        }
    }

    /// Back to the ranked list. The filter, search and the opened row stay.
    func closeReview(notice: String? = nil) {
        reviewTask?.cancel()
        isOpeningReview = false
        review = nil
        selection = []
        detailItemID = nil
        reviewNotice = notice
    }

    var eligibleVisibleIDs: [String] {
        reviewItems.filter { $0.heldReason == nil }.map(\.recommendation.id)
    }

    func toggle(_ item: RescueReviewSnapshot.Item) {
        guard item.heldReason == nil else { return }
        let id = item.recommendation.id
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    func selectAllEligible() { selection.formUnion(eligibleVisibleIDs) }
    func clearSelection() { selection = [] }

    var selectedBytes: Int64 {
        guard let review else { return 0 }
        return review.items.reduce(0) {
            selection.contains($1.recommendation.id) && $1.heldReason == nil ? $0 + $1.recommendation.physicalBytes : $0
        }
    }

    var canStage: Bool {
        guard let host, review != nil else { return false }
        return host.rescueSelectedSource?.path == review?.sourcePath
            && !selection.isEmpty && !isStaging && !host.rescueIsScanning && !host.rescueIsBusy
    }

    /// Stage the explicit eligible selection through the host's collector.
    /// The scan revision and source are checked before and after the
    /// identity check; changed objects are held, not retargeted.
    func stageSelection() async {
        guard let host, let review, canStage else { return }
        guard host.rescueRevision == review.revision, host.rescueReportSource == review.sourcePath else {
            closeReview(notice: "The scan changed. Open the group again to review current items.")
            return
        }
        let kept = keptItems.filter { $0.sourcePath == review.sourcePath }
        let chosen = review.items.filter { item in
            selection.contains(item.recommendation.id) && item.heldReason == nil
                && !kept.contains(where: { keptItem in
                    keptItem.matches(item.recommendation, sourcePath: review.sourcePath)
                })
        }.map(\.recommendation)
        guard !chosen.isEmpty else { return }
        isStaging = true
        defer { isStaging = false }
        let identity = currentIdentity
        let checks: [(String, String, ScanIdentity?)] = chosen.map { ($0.id, $0.path, $0.identity) }
        let unchanged: Set<String> = await Task.detached(priority: .userInitiated) {
            var ok = Set<String>()
            for (id, path, expected) in checks {
                guard let expected, let current = identity(path), expected.matches(current) else { continue }
                ok.insert(id)
            }
            return ok
        }.value
        guard self.review === review, host.rescueRevision == review.revision,
              host.rescueReportSource == review.sourcePath,
              host.rescueSelectedSource?.path == review.sourcePath,
              !host.rescueIsScanning, !host.rescueIsBusy else {
            closeReview(notice: "The scan changed while checking. Nothing was added.")
            return
        }
        var addedBytes: Int64 = 0
        var added = 0
        for recommendation in chosen where unchanged.contains(recommendation.id) {
            if host.rescueStage(recommendation.node) {
                added += 1
                addedBytes += recommendation.physicalBytes
            }
        }
        let held = chosen.count - added
        selection.subtract(chosen.filter { unchanged.contains($0.id) }.map(\.id))
        var notice = added > 0
            ? "Added \(Theme.itemCount(added)) · \(Theme.format(addedBytes)) to the Cleanup List."
            : "Nothing was added."
        if held > 0 { notice += " Held \(Theme.itemCount(held)) that changed or could not enter the list. Review them again." }
        reviewNotice = notice
    }

    // MARK: Kept items

    func keep(_ recommendation: CleanupRecommendation) {
        guard let source = host?.rescueReportSource,
              let item = RescueKeptItem(recommendation: recommendation, sourcePath: source) else { return }
        keptItems.removeAll { $0.matches(recommendation, sourcePath: source) }
        keptItems.append(item)
        selection.remove(recommendation.id)
        if detailItemID == recommendation.id { detailItemID = nil }
        saveKept()
        rebuildRows()
        refreshReviewItems()
    }

    func canKeep(_ recommendation: CleanupRecommendation) -> Bool {
        recommendation.identity?.hasStableObjectIdentifier ?? false
    }

    func restore(_ item: RescueKeptItem) {
        keptItems.removeAll { $0.id == item.id }
        saveKept()
        rebuildRows()
        refreshReviewItems()
    }

    /// Whether a kept choice matches an item in the current report. An
    /// unresolved choice is shown with an explanation.
    func isResolved(_ item: RescueKeptItem) -> Bool {
        guard let host, let report = host.rescueReport, item.sourcePath == host.rescueReportSource else { return false }
        return report.recommendations.contains { $0.path == item.path && item.matches($0, sourcePath: item.sourcePath) }
    }

    var keptForCurrentSource: [RescueKeptItem] {
        guard let source = host?.rescueReportSource else { return [] }
        return keptItems.filter { $0.sourcePath == source }
    }

    private static func loadKept(_ defaults: UserDefaults) -> [RescueKeptItem] {
        guard let data = defaults.data(forKey: keptItemsKey),
              let items = try? JSONDecoder().decode([RescueKeptItem].self, from: data) else { return [] }
        return items
    }

    private func saveKept() {
        if let data = try? JSONEncoder().encode(keptItems) { defaults.set(data, forKey: Self.keptItemsKey) }
    }

    // MARK: Goal

    /// Set an additional-free-space goal. The baseline is Free now on the
    /// source's drive at this moment.
    func setGoal(additionalGB: Double) {
        guard additionalGB.isFinite, additionalGB > 0, additionalGB < 100_000,
              let source = host?.rescueSelectedSource else { return }
        let reading = readCapacity(source)
        let bytes = Int64((additionalGB * 1_000_000_000).rounded())
        goal = RescueSpaceGoal(additionalBytes: bytes, baseline: reading, latest: reading)
    }

    func clearGoal() { goal = nil }

    /// Read Free now again. Staged and Trash bytes never enter this figure.
    func checkGoal() {
        guard var current = goal, let source = host?.rescueSelectedSource else { return }
        current.latest = readCapacity(source)
        goal = current
    }

    // MARK: Owner handoff

    /// Open the owner, or Finder at the item. Only a successful open through
    /// this call arms the one automatic check on return.
    func openOwner(_ route: RescueOwnerRoute, revealing paths: [String]) async {
        guard let host, let source = host.rescueSelectedSource else { return }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        let departureBeforeOpen = departureGeneration
        var opened = false
        if let bundleID = route.bundleID {
            if let appURL = opener.applicationURL(bundleID: bundleID) {
                opened = await opener.openApplication(at: appURL)
            }
            if !opened {
                handoff = .failed("\(route.ownerName) is not installed or did not open. \(route.steps)")
                _ = opener.reveal(urls)
                return
            }
        } else {
            opened = opener.reveal(urls)
            if !opened {
                handoff = .failed("Tessera could not show this item in Finder. It may have moved. Scan again.")
                return
            }
        }
        guard source == host.rescueSelectedSource else { return }
        pendingHandoff = (source, route.ownerName, departureGeneration != departureBeforeOpen)
        handoff = .waiting(ownerName: route.ownerName)
        if pendingHandoff?.leftApp == true, NSApp?.isActive == true { appDidBecomeActive() }
    }

    func cancelHandoff() {
        pendingHandoff = nil
        handoff = .none
    }

    func appDidResignActive() {
        departureGeneration &+= 1
        if var pending = pendingHandoff {
            pending.leftApp = true
            pendingHandoff = pending
        }
    }

    /// One fresh check of the same source after returning from an owner.
    /// Ordinary app switches do nothing.
    func appDidBecomeActive() {
        guard let pending = pendingHandoff, pending.leftApp else { return }
        handoff = .deferred(ownerName: pending.ownerName)
        runOwnerReturnRefresh()
    }

    private func runOwnerReturnRefresh() {
        guard let host, let pending = pendingHandoff else {
            handoff = .none
            return
        }
        guard pending.source == host.rescueSelectedSource else {
            pendingHandoff = nil
            handoff = .none
            return
        }
        guard !host.rescueIsScanning, !host.rescueIsBusy else { return }
        pendingHandoff = nil
        handoff = .none
        closeReview()
        host.rescueStartScan(pending.source)
    }
}
