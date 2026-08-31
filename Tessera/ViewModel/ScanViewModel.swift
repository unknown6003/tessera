import SwiftUI
import AppKit

@MainActor
final class ScanViewModel: ObservableObject {
    // MARK: - Published state
    @Published var rootNode: FileNode?
    @Published var currentRoot: FileNode?        // zoom target within the chart
    @Published var hoveredNode: FileNode?
    @Published var selectedNode: FileNode?
    @Published var collector: [FileNode] = []
    /// Post-scan cleanup suggestions (caches, temp, Adobe media cache, …). Filled
    /// asynchronously after the tree is built; nil until then.
    @Published var cleanupReport: CleanupReport?
    /// Duplicate finder (standard detection + premium AI triage).
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var isFindingDuplicates = false
    @Published var didRunDuplicates = false
    @Published var duplicateProgress = DuplicateProgress()
    @Published var isScanning = false
    @Published var progress = ScanProgress()
    /// Changes when an already-published tree is mutated in place (for example,
    /// after cleanup). The chart uses this to invalidate angular layout without
    /// tying expensive layout work to window-size changes.
    @Published private(set) var chartRevision: UInt64 = 0
    @Published var errorMessage: String?
    @Published var needsFullDiskAccess = false
    /// Drives the first-launch onboarding prompt that asks for Full Disk Access
    /// once, up front, instead of failing per-directory mid-scan.
    @Published var showFDAOnboarding = false
    private var fdaDismissedThisSession = false

    // MARK: - Rescue plan
    @Published var selectedSourceURL: URL?
    @Published private(set) var rescuePhase: RescuePhase = .needsRescue
    @Published private(set) var rescuePlan: RescuePlan?
    @Published private(set) var savedRescueCase: SavedRescueCase?
    @Published private(set) var restoredRescueCandidateIDs: Set<String> = []
    @Published private(set) var restoredRescueCaseIsStale = false
    @Published var rescueGoal: RescueGoal = .normalWork
    @Published var requiredRescueSpace: Int64?
    @Published private(set) var rescueVerification: RescueVerification?
    @Published private(set) var lastRescueError: String?

    /// The volume whose scan results are currently on screen — set when a scan
    /// completes, cleared when a new scan starts. Drives the sidebar's "Viewing"
    /// indicator and the "you switched away from what's displayed" affordance.
    @Published private(set) var scannedURL: URL?

    private var scanTask: Task<Void, Never>?
    /// Monotonically identifies the scan allowed to publish into this view model.
    /// Cancelling a task is cooperative: an older scanner may still deliver a
    /// progress callback or finish while its replacement is already running.
    /// Every async publication is therefore gated by this generation.
    private var scanGeneration: UInt64 = 0
    private var duplicateTask: Task<Void, Never>?
    private var duplicateCancel: DuplicateCancelToken?
    /// Invalidates results and progress from duplicate scans whose blocking GCD
    /// work can outlive the Swift task that originally awaited it.
    private var duplicateGeneration: UInt64 = 0
    /// The last volume scanned, so a re-scan of the same volume can reuse the
    /// previous tree for incremental speedup.
    private var lastScannedURL: URL?
    private var pendingRescueCase: SavedRescueCase?

    /// Completed scans kept in memory so switching between disks/cloud is instant
    /// (no re-scan). Capped (LRU) because each tree can be large.
    private struct CachedScan {
        let rootNode: FileNode
        let currentRoot: FileNode?
        let cleanupReport: CleanupReport?
        let duplicateGroups: [DuplicateGroup]
        let didRunDuplicates: Bool
        let collector: [FileNode]
        let progress: ScanProgress
        let rescuePlan: RescuePlan?
        let rescuePhase: RescuePhase
        let rescueGoal: RescueGoal
        let requiredRescueSpace: Int64?
        let rescueVerification: RescueVerification?
        let lastRescueError: String?
        let restoredRescueCandidateIDs: Set<String>
        let restoredRescueCaseIsStale: Bool
    }
    private var scanCache: [URL: CachedScan] = [:]
    private var cacheLRU: [URL] = []
    // A full-disk FileNode tree can contain millions of objects. Keeping the
    // displayed tree plus three more complete trees caused severe memory pressure
    // (and eventual OS termination) after switching sources. One warm tree keeps
    // instant back-navigation without multiplying the scan's peak footprint.
    private let maxCachedScans = 1
    /// Diagnostic: true when the last scan ended via CancellationError.
    private(set) var scanTaskWasCancelled = false

    init() {
        savedRescueCase = nil
        do {
            savedRescueCase = try RescueCaseStore.load()
        } catch {
            lastRescueError = "The saved rescue case could not be read. Scan again to start a new case."
        }
    }

    // MARK: - Computed

    var collectorTotalSize: Int64 { collector.reduce(0) { $0 + $1.size } }

    // MARK: - Scan

    func startScan(volumeURL: URL) {
        selectedSourceURL = volumeURL
        if let pendingRescueCase,
           pendingRescueCase.sourcePath != volumeURL.standardizedFileURL.path {
            self.pendingRescueCase = nil
        }
        scanGeneration &+= 1
        let generation = scanGeneration
        scanTask?.cancel()
        // Preserve the scan currently on screen so switching back to it is instant.
        saveCurrentToCache()
        // Incremental re-scan: reuse a prior tree for this volume (from the cache, or
        // the one already displayed) as a baseline. Unchanged subtrees (by directory
        // modtime) are skipped, and any directory whose contents changed — including
        // via deletions the user just made — has a new modtime, so it's re-scanned
        // for fresh sizes.
        let cache = scanCache[volumeURL]?.rootNode ?? (volumeURL == scannedURL ? rootNode : nil)
        // The local reference above is all the incremental scanner needs. Do not
        // retain a second root for the same source in the LRU while rebuilding it;
        // reused subtrees already stay alive through `cache`.
        scanCache.removeValue(forKey: volumeURL)
        cacheLRU.removeAll { $0 == volumeURL }
        lastScannedURL = volumeURL
        scannedURL = nil
        rootNode = nil
        scanTaskWasCancelled = false
        currentRoot = nil
        hoveredNode = nil
        selectedNode = nil
        collector = []
        cleanupReport = nil
        rescuePlan = nil
        rescuePhase = .scanning
        restoredRescueCandidateIDs = []
        restoredRescueCaseIsStale = false
        rescueVerification = nil
        lastRescueError = nil
        stopDuplicateSearch()
        duplicateGroups = []
        didRunDuplicates = false
        duplicateProgress = DuplicateProgress()
        errorMessage = nil
        needsFullDiskAccess = false
        isScanning = true
        progress = ScanProgress(currentPath: volumeURL.path)

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let node = try await FileScanner.scan(url: volumeURL, cache: cache) { [weak self] prog in
                    Task { @MainActor [weak self] in
                        guard let self, self.scanGeneration == generation else { return }
                        // Monotonicity guard: discard stale ticks that arrive out of
                        // order (the @MainActor hop can reorder them). Accept the
                        // final tick, or any tick that advances a monotonic counter.
                        if prog.isComplete
                            || prog.bytesFound >= self.progress.bytesFound
                            || prog.dirsScanned >= self.progress.dirsScanned
                            || prog.dirsDiscovered > self.progress.dirsDiscovered {
                            self.progress = prog
                        }
                    }
                }
                // Cancellation can race with a scanner completing. Only the most
                // recently started scan may replace the chart or its source state.
                // A superseded scan returns here and skips trailing cleanup safely:
                // that cleanup is guarded by the same generation comparison.
                guard self.scanGeneration == generation else { return }
                let treeIsEmpty = node.children.isEmpty
                let volumePath = volumeURL.path
                let isVolumeRoot = volumePath == "/"
                let isUnreadable = !FileManager.default.isReadableFile(atPath: volumePath)
                // Classify cleanup suggestions off the main actor (pure CPU over the
                // already-built tree, no I/O) BEFORE publishing it. While this runs,
                // `node` is still exclusively owned by this task: `rootNode` /
                // `currentRoot` were cleared at scan start and the collector is empty,
                // so the tree is unreachable from the UI and nothing can mutate
                // `children` underneath the walk. Publishing first and classifying
                // afterwards would race the collector delete flow, which mutates the
                // same arrays on the main actor.
                let ownerState = CleanupOwnerState.current()
                self.rescuePhase = .diagnosing
                let diagnosis = await Task.detached(priority: .utility) {
                    let coverage = RescueCoverage.inspect(root: node, sourceIsReadable: !isUnreadable)
                    let report = CleanupClassifier.classify(root: node, ownerState: ownerState,
                                                            coverageComplete: coverage.state == .complete)
                    let measurement = RescueMeasurement.capture(volumeURL: volumeURL, root: node)
                    return (coverage, report, measurement)
                }.value

                // A newer scan may have started while classifying — it owns the UI
                // state now, so this one publishes nothing.
                guard self.scanGeneration == generation else { return }
                if treeIsEmpty && (isVolumeRoot || isUnreadable) {
                    self.needsFullDiskAccess = true
                }
                let (coverage, report, measurement) = diagnosis
                let plan = RescuePlan(sourceURL: volumeURL, report: report,
                                      measurement: measurement, coverage: coverage,
                                      goal: self.rescueGoal,
                                      requiredSpace: self.requiredRescueSpace)
                // Single atomic publish point: tree and its report together.
                self.rootNode = node
                self.currentRoot = node
                self.scannedURL = volumeURL
                self.cleanupReport = report
                self.rescuePlan = plan
                self.rescuePhase = .planReady
                let hasSavedCaseToReview = self.pendingRescueCase != nil
                if !hasSavedCaseToReview {
                    self.stageSafeCleanup()
                }
                self.restoreSavedRescueCaseIfNeeded(plan: plan)
                // Safe candidates are staged for review on a fresh scan. A saved case
                // never stages its old selection; the user must ask for that again.
            } catch is CancellationError {
                // User stopped the current scan — not an error. A cancellation
                // from a superseded scan must not change its replacement's state.
                if self.scanGeneration == generation {
                    self.scanTaskWasCancelled = true
                    self.rescuePhase = .needsRescue
                }
            } catch {
                if self.scanGeneration == generation {
                    self.errorMessage = error.localizedDescription
                    self.rescuePhase = .needsRescue
                }
            }
            if self.scanGeneration == generation {
                self.isScanning = false
                self.scanTask = nil
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    /// Whether the most recently requested source can be scanned again after a
    /// failure. `scannedURL` is intentionally nil while a scan is in flight, so
    /// retry state must use the requested URL instead of the last published tree.
    var canRetryLastScan: Bool { lastScannedURL != nil && !isScanning }

    func retryLastScan() {
        guard let url = lastScannedURL, !isScanning else { return }
        startScan(volumeURL: url)
    }

    // MARK: - Scan cache (instant disk/cloud switching)

    /// True if a completed scan for `url` is cached and can be shown instantly.
    func hasCachedScan(for url: URL) -> Bool { scanCache[url] != nil }

    /// Snapshot the scan currently on screen into the cache so the user can return
    /// to it without re-scanning. No-op mid-scan or before the first scan.
    private func saveCurrentToCache() {
        guard let root = rootNode, let url = scannedURL, !isScanning else { return }
        scanCache[url] = CachedScan(
            rootNode: root, currentRoot: currentRoot, cleanupReport: cleanupReport,
            duplicateGroups: duplicateGroups,
            didRunDuplicates: didRunDuplicates, collector: collector, progress: progress,
            rescuePlan: rescuePlan, rescuePhase: rescuePhase, rescueGoal: rescueGoal,
            requiredRescueSpace: requiredRescueSpace, rescueVerification: rescueVerification,
            lastRescueError: lastRescueError,
            restoredRescueCandidateIDs: restoredRescueCandidateIDs,
            restoredRescueCaseIsStale: restoredRescueCaseIsStale)
        touchLRU(url)
        while cacheLRU.count > maxCachedScans {
            scanCache.removeValue(forKey: cacheLRU.removeFirst())
        }
    }

    private func touchLRU(_ url: URL) {
        cacheLRU.removeAll { $0 == url }
        cacheLRU.append(url)
    }

    /// Switch the display to a cached scan for `url` without re-scanning. Returns
    /// true if it switched. Used when the user taps a previously-scanned source.
    @discardableResult
    func showCachedScanIfAvailable(for url: URL) -> Bool {
        guard url != scannedURL, let cached = scanCache[url] else { return false }
        if isScanning {
            // Invalidate every callback/result from the in-flight scan before
            // restoring the cached tree. Cancellation alone is cooperative.
            scanGeneration &+= 1
            scanTask?.cancel()
            scanTask = nil
            isScanning = false
        }
        // Cancelling the awaiting Task is not enough: DuplicateFinder runs on a
        // blocking GCD worker and only its token can stop it. Invalidate both its
        // result and progress before publishing the cached source.
        stopDuplicateSearch()
        // Preserve what we're leaving, then restore the requested scan.
        saveCurrentToCache()

        rootNode = cached.rootNode
        currentRoot = cached.currentRoot ?? cached.rootNode
        cleanupReport = cached.cleanupReport
        duplicateGroups = cached.duplicateGroups
        didRunDuplicates = cached.didRunDuplicates
        collector = cached.collector
        progress = cached.progress
        rescuePlan = cached.rescuePlan
        rescuePhase = cached.rescuePhase
        rescueGoal = cached.rescueGoal
        requiredRescueSpace = cached.requiredRescueSpace
        rescueVerification = cached.rescueVerification
        lastRescueError = cached.lastRescueError
        restoredRescueCandidateIDs = cached.restoredRescueCandidateIDs
        restoredRescueCaseIsStale = cached.restoredRescueCaseIsStale
        pendingRescueCase = nil
        selectedSourceURL = url
        scannedURL = url
        lastScannedURL = url

        hoveredNode = nil
        selectedNode = nil
        isFindingDuplicates = false
        errorMessage = nil
        needsFullDiskAccess = false
        touchLRU(url)
        return true
    }

    // MARK: - Chart navigation

    func zoomIn(to node: FileNode) {
        guard node.isDirectory else { return }
        currentRoot = node
        hoveredNode = nil
        selectedNode = node
    }

    func zoomOut() {
        guard let current = currentRoot, let parent = current.parent else { return }
        currentRoot = parent
        selectedNode = parent
        hoveredNode = nil
    }

    func zoomToRoot() {
        currentRoot = rootNode
        selectedNode = rootNode
        hoveredNode = nil
    }

    // MARK: - Collector

    func addToCollector(_ node: FileNode) {
        guard !node.isSynthetic else { return }
        // The app-uninstaller can mint nodes outside the scanned tree. Apply the
        // path gate before consulting the current plan, so protected roots cannot
        // enter the collector just because they have no recommendation row.
        guard CleanupClassifier.protectedCategory(for: node.url.path) == nil else { return }
        func isAncestorOrSame(_ ancestor: FileNode, _ descendant: FileNode) -> Bool {
            var cursor: FileNode? = descendant
            while let current = cursor {
                if current.id == ancestor.id { return true }
                cursor = current.parent
            }
            return false
        }
        if let protected = rescuePlan?.protectedRecommendations,
           protected.contains(where: { recommendation in
               return isAncestorOrSame(recommendation.node, node)
                   || isAncestorOrSame(node, recommendation.node)
           }) {
            return
        }
        guard !collector.contains(where: { $0.id == node.id }) else { return }

        // Refuse if any existing collector item is an ancestor of this node.
        func isAncestor(_ candidate: FileNode, of target: FileNode) -> Bool {
            var cursor = target.parent
            while let p = cursor {
                if p.id == candidate.id { return true }
                cursor = p.parent
            }
            return false
        }
        guard !collector.contains(where: { isAncestor($0, of: node) }) else { return }

        // Remove any existing collector items that are descendants of the new node
        // (collecting a parent supersedes its children).
        collector.removeAll { isAncestor(node, of: $0) }

        collector.append(node)
        if rescuePlan != nil { rescuePhase = .staged }
    }

    func removeFromCollector(_ node: FileNode) {
        collector.removeAll { $0.id == node.id }
        if rescuePlan != nil, collector.isEmpty { rescuePhase = .reviewing }
    }

    func clearCollector() {
        collector = []
        if rescuePlan != nil { rescuePhase = .reviewing }
    }

    /// True if `node` is staged — either directly, or covered by a collected
    /// ancestor (collecting a parent supersedes its children). Used to render the
    /// per-suggestion Add/Added toggle.
    func isCollected(_ node: FileNode) -> Bool {
        if collector.contains(where: { $0.id == node.id }) { return true }
        var cursor = node.parent
        while let p = cursor {
            if collector.contains(where: { $0.id == p.id }) { return true }
            cursor = p.parent
        }
        return false
    }

    // MARK: - Cleanup suggestions → collector
    //
    // These ONLY stage items into the collector (reusing addToCollector's dedup /
    // ancestor / supersede rules). Nothing is deleted here — the user reviews the
    // collector and deletes manually through the existing confirmation flow.

    /// Add every safe-regenerable suggestion (caches, build products, …) to the
    /// collector. The one-button action. Review-tier items are never included.
    func stageSafeCleanup() {
        guard let report = cleanupReport else { return }
        for node in report.safeNodes { addToCollector(node) }
        if !collector.isEmpty { rescuePhase = .staged }
    }

    /// Add one suggestion group to the collector (used for opt-in review rows).
    func stageCleanupGroup(_ group: CleanupReport.Group) {
        guard group.risk != .protected else { return }
        for node in group.nodes { addToCollector(node) }
        if !collector.isEmpty { rescuePhase = .staged }
    }

    /// Whether every node in a group is currently staged.
    func isGroupStaged(_ group: CleanupReport.Group) -> Bool {
        !group.nodes.isEmpty && group.nodes.allSatisfy { isCollected($0) }
    }

    /// Add the group if it isn't fully staged, otherwise pull it back out — the
    /// per-group Add/Added control.
    func toggleCleanupGroup(_ group: CleanupReport.Group) {
        if isGroupStaged(group) {
            for node in group.nodes { removeFromCollector(node) }
        } else {
            stageCleanupGroup(group)
        }
    }

    func beginTrashConfirmation() {
        guard !collector.isEmpty else { return }
        if rescuePlan != nil { rescuePhase = .confirmingTrash }
    }

    func cancelTrashConfirmation() {
        guard rescuePhase == .confirmingTrash else { return }
        rescuePhase = collector.isEmpty ? .reviewing : .staged
    }

    /// True once all safe groups are staged — disables the "add all safe" button.
    var safeGroupsAllStaged: Bool {
        guard let report = cleanupReport, !report.safeGroups.isEmpty else { return false }
        return report.safeGroups.allSatisfy { isGroupStaged($0) }
    }

    // MARK: - Rescue case

    /// Open the current plan without staging anything. A saved case never
    /// authorizes an action; it only restores a local review context.
    func beginRescueReview() {
        guard rescuePlan != nil else {
            rescuePhase = .needsRescue
            return
        }
        if rescueVerification != nil || lastRescueError != nil {
            rescuePhase = .result
            return
        }
        rescuePhase = collector.isEmpty ? .reviewing : .staged
    }

    func updateRescueGoal(_ goal: RescueGoal, requiredSpace: Int64?) {
        let changed = rescueGoal != goal || requiredRescueSpace != requiredSpace
        rescueGoal = goal
        requiredRescueSpace = requiredSpace
        if let plan = rescuePlan {
            rescuePlan = plan.changingGoal(to: goal, requiredSpace: requiredSpace)
            if changed, rescueVerification != nil || lastRescueError != nil {
                rescueVerification = nil
                lastRescueError = nil
                rescuePhase = collector.isEmpty ? .reviewing : .staged
            }
        }
    }

    func saveRescueCase() {
        guard let plan = rescuePlan else { return }
        let stagedIDs = Set(collector.compactMap { node in
            plan.recommendations.first(where: { $0.node.id == node.id })?.id
        })
        rescuePhase = .remembering
        persistRescueCase(candidateIDs: stagedIDs)
    }

    func discardSavedRescueCase() {
        RescueCaseStore.clear()
        savedRescueCase = nil
        pendingRescueCase = nil
        restoredRescueCandidateIDs = []
        restoredRescueCaseIsStale = false
    }

    /// Reopen means scan the saved source again, then show the old selection as
    /// review context. It never silently adds the old items to the collector.
    func reopenSavedRescueCase() {
        guard let saved = savedRescueCase else { return }
        pendingRescueCase = saved
        rescueGoal = saved.goal
        requiredRescueSpace = saved.requiredSpace
        startScan(volumeURL: URL(fileURLWithPath: saved.sourcePath))
    }

    /// Restore a saved selection only after the user explicitly asks. Protected
    /// recommendations can never enter the collector through this path.
    func stageRestoredRescueCase() {
        guard let plan = rescuePlan else { return }
        for recommendation in plan.recommendations
            where restoredRescueCandidateIDs.contains(recommendation.id)
                && recommendation.risk != .protected {
            addToCollector(recommendation.node)
        }
    }

    private func restoreSavedRescueCaseIfNeeded(plan: RescuePlan) {
        guard let saved = pendingRescueCase else { return }
        pendingRescueCase = nil
        restoredRescueCaseIsStale = saved.ruleVersion != CleanupClassifier.ruleVersion
        guard saved.sourcePath == plan.sourcePath,
              !restoredRescueCaseIsStale else {
            restoredRescueCandidateIDs = []
            rescuePhase = .reviewing
            return
        }
        guard let savedIdentities = saved.candidateIdentities else {
            // Cases written before identity persistence are review history only;
            // a matching category/path is not enough to stage after a rescan.
            restoredRescueCaseIsStale = true
            restoredRescueCandidateIDs = []
            rescuePhase = .reviewing
            return
        }
        let currentRecommendations = Dictionary(uniqueKeysWithValues: plan.recommendations.map { ($0.id, $0) })
        var restoredIDs = Set<String>()
        var identityMismatch = false
        for candidateID in saved.candidateIDs {
            guard let savedIdentity = savedIdentities[candidateID],
                  let recommendation = currentRecommendations[candidateID],
                  let currentIdentity = recommendation.identity,
                  savedIdentity.matches(currentIdentity) else {
                identityMismatch = true
                continue
            }
            restoredIDs.insert(candidateID)
        }
        restoredRescueCandidateIDs = restoredIDs
        restoredRescueCaseIsStale = identityMismatch
        guard !identityMismatch else {
            rescueVerification = nil
            lastRescueError = nil
            rescuePhase = .reviewing
            return
        }
        rescueVerification = saved.verification
        lastRescueError = saved.errorMessage
        rescuePhase = saved.phase == .result && (saved.verification != nil || saved.errorMessage != nil)
            ? .result : .reviewing
    }

    private func persistRescueCase(candidateIDs: Set<String>) {
        guard let plan = rescuePlan else { return }
        let wasRemembering = rescuePhase == .remembering
        let candidateIdentities: [String: ScanIdentity] = Dictionary(uniqueKeysWithValues: plan.recommendations.compactMap { recommendation in
            guard candidateIDs.contains(recommendation.id), let identity = recommendation.identity else { return nil }
            return (recommendation.id, identity)
        })
        let rescueCase = SavedRescueCase(
            id: savedRescueCase?.id ?? UUID(),
            sourcePath: plan.sourcePath,
            goal: plan.goal,
            requiredSpace: plan.requiredSpace,
            candidateIDs: candidateIDs.sorted(),
            candidateIdentities: candidateIdentities,
            ruleVersion: CleanupClassifier.ruleVersion,
            savedAt: Date(),
            phase: rescuePhase,
            measurement: plan.measurement,
            coverage: plan.coverage,
            verification: rescueVerification,
            errorMessage: lastRescueError
        )
        do {
            try RescueCaseStore.save(rescueCase)
            savedRescueCase = rescueCase
        } catch {
            if lastRescueError == nil {
                lastRescueError = "The rescue case could not be saved on this Mac."
            }
            if wasRemembering {
                rescuePhase = collector.isEmpty ? .reviewing : .staged
            }
        }
    }

    // MARK: - Duplicate finder
    //
    // Fully on-device (DuplicateFinder): detection + keeper heuristic, no network.

    /// Scan the current tree for exact-content duplicate files. Detection runs on a
    /// GCD worker pool (off the cooperative pool, since it does blocking reads).
    func findDuplicates() {
        guard let root = rootNode, !isFindingDuplicates else { return }
        stopDuplicateSearch()
        let generation = duplicateGeneration
        let token = DuplicateCancelToken()
        duplicateCancel = token
        isFindingDuplicates = true
        didRunDuplicates = true
        duplicateGroups = []
        duplicateProgress = DuplicateProgress()
        let onProgress: @Sendable (DuplicateProgress) -> Void = { [weak self] prog in
            Task { @MainActor [weak self] in
                guard let self,
                      self.duplicateGeneration == generation,
                      !token.isCancelled else { return }
                self.duplicateProgress = prog
            }
        }
        // Snapshot the candidate files on the main actor before handing them to the
        // background pass, so the background never walks `FileNode.children` while the
        // collector delete flow can mutate the same arrays on the main actor.
        let files = DuplicateFinder.collectFiles(root: root)
        duplicateTask = Task { [weak self] in
            let groups: [DuplicateGroup] = await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    cont.resume(returning: DuplicateFinder.find(files: files, cancel: token, progress: onProgress))
                }
            }
            guard let self,
                  self.duplicateGeneration == generation,
                  !token.isCancelled else { return }
            self.duplicateGroups = groups
            self.isFindingDuplicates = false
            self.duplicateTask = nil
            self.duplicateCancel = nil
        }
    }

    func cancelDuplicates() {
        stopDuplicateSearch()
    }

    /// Cancel both layers of duplicate work and invalidate every queued
    /// publication. The GCD worker is cooperative, so generation gating remains
    /// necessary for a progress callback already enqueued on the main actor.
    private func stopDuplicateSearch() {
        duplicateGeneration &+= 1
        duplicateCancel?.cancel()
        duplicateTask?.cancel()
        duplicateCancel = nil
        duplicateTask = nil
        isFindingDuplicates = false
    }

    /// Total bytes reclaimable across all duplicate groups.
    var duplicateReclaimableBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    /// Stage the removable copies (all but the keeper) of one group.
    func stageDuplicateGroup(_ group: DuplicateGroup) {
        for node in group.removableFiles { addToCollector(node) }
    }

    /// True once every removable copy in a group is staged.
    func isDuplicateGroupStaged(_ group: DuplicateGroup) -> Bool {
        let removable = group.removableFiles
        return !removable.isEmpty && removable.allSatisfy { isCollected($0) }
    }

    func toggleDuplicateGroup(_ group: DuplicateGroup) {
        if isDuplicateGroupStaged(group) {
            for node in group.removableFiles { removeFromCollector(node) }
        } else {
            stageDuplicateGroup(group)
        }
    }

    /// Stage the removable copies across every duplicate group.
    func stageAllDuplicates() {
        for group in duplicateGroups { stageDuplicateGroup(group) }
    }

    var allDuplicatesStaged: Bool {
        !duplicateGroups.isEmpty && duplicateGroups.allSatisfy { isDuplicateGroupStaged($0) }
    }

    // MARK: - App Uninstaller
    //
    // Staging only: the app bundle + every associated leftover are turned into
    // explicit-URL FileNodes and added to the collector via the usual dedup rules.
    // Nothing is deleted here — the user reviews the staged set and trashes it
    // through the existing confirmation flow. PRIVACY: enumeration is on-device.

    /// Stage an app's bundle and all of its leftovers into the collector. The
    /// nodes are minted with explicit URLs (so they reveal/trash correctly) and
    /// .regular kind (so they are non-synthetic and deletable).
    func stageAppForUninstall(_ app: InstalledApp) {
        addToCollector(uninstallNode(url: app.appURL, name: app.appURL.lastPathComponent,
                                     isDirectory: true, size: app.appBytes))
        for leftover in app.leftovers {
            let isDir = (try? leftover.url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            addToCollector(uninstallNode(url: leftover.url, name: leftover.url.lastPathComponent,
                                         isDirectory: isDir, size: leftover.bytes))
        }
    }

    /// Stage every item in an orphaned-leftover group (support files of a removed
    /// app) into the collector. Nodes are minted with explicit URLs + .regular kind
    /// so they reveal/trash correctly through the normal confirm flow.
    func stageOrphanGroup(_ group: AppUninstaller.OrphanGroup) {
        for item in group.items {
            let isDir = (try? item.url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? true
            addToCollector(uninstallNode(url: item.url, name: item.url.lastPathComponent,
                                         isDirectory: isDir, size: item.bytes))
        }
    }

    /// True once every item in an orphan group is staged — drives the Add/Staged
    /// toggle in the view.
    func isOrphanGroupStaged(_ group: AppUninstaller.OrphanGroup) -> Bool {
        guard !group.items.isEmpty else { return false }
        return group.items.allSatisfy { item in
            collector.contains { $0.url.standardizedFileURL == item.url.standardizedFileURL }
        }
    }

    /// True once the app bundle and every leftover are staged — drives the
    /// Uninstall/Staged toggle in the view.
    func isAppStaged(_ app: InstalledApp) -> Bool {
        let staged: (URL) -> Bool = { url in
            self.collector.contains { $0.url.standardizedFileURL == url.standardizedFileURL }
        }
        guard staged(app.appURL) else { return false }
        return app.leftovers.allSatisfy { staged($0.url) }
    }

    /// Mint (or reuse an existing collector node for) a uninstall target. Reusing
    /// keeps `addToCollector`'s identity-based dedup working across taps.
    private func uninstallNode(url: URL, name: String, isDirectory: Bool, size: Int64) -> FileNode {
        if let existing = collector.first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            return existing
        }
        return FileNode(url: url, name: name, isDirectory: isDirectory, size: size, kind: .regular,
                        identity: ScanIdentity.current(at: url))
    }

    // MARK: - Delete

    /// Move every collected item to the Trash (recoverable), then prune them from
    /// the tree. The default, recommended action — restore from Finder if needed.
    func moveCollectorToTrash() throws {
        try moveToTrash(collector)
    }

    /// Move `nodes` to the Trash (recoverable — restore from Finder) and prune the
    /// successfully-trashed ones from both the tree and the collector. Synthetic
    /// nodes are ignored. Throws if every move failed.
    func moveToTrash(_ nodes: [FileNode]) throws {
        let targets = topLevelTargets(nodes.filter { !$0.isSynthetic })
        guard !targets.isEmpty else { return }
        let before = currentRescueMeasurement()
        if rescuePlan != nil {
            rescueVerification = nil
            lastRescueError = nil
            rescuePhase = .moving
        }

        var attemptedTargets: [FileNode] = []
        var failures: [DeletionService.DeletionError] = []
        var measurementMismatchPaths: [String] = []
        do {
            try holdIfRescueOwnerIsActive(targets)
            for target in targets {
                try holdIfRescueOwnerIsActive([target])
                attemptedTargets.append(target)
                let itemBefore = currentRescueCapacity()
                let itemFailures = try DeletionService.trash([target])
                if let failure = itemFailures.first {
                    failures.append(failure)
                    if rescuePlan != nil {
                        persistRescueCase(candidateIDs: stagedRescueCandidateIDs())
                    }
                    continue
                }

                // Prune each successful item before sampling the next one. This
                // keeps the tree and the remaining collector aligned if capacity
                // accounting changes between items.
                try prune([target], failures: [])
                if let itemBefore,
                   let itemAfter = currentRescueCapacity(),
                   let beforeBytes = itemBefore.primaryBytes,
                   let afterBytes = itemAfter.primaryBytes,
                   max(0, afterBytes - beforeBytes) != target.physicalSize {
                    measurementMismatchPaths.append(target.url.standardizedFileURL.path)
                }
                if rescuePlan != nil {
                    persistRescueCase(candidateIDs: stagedRescueCandidateIDs())
                }
            }
            recordRescueResult(before: before, targets: attemptedTargets, failures: failures,
                               measurementMismatchPaths: measurementMismatchPaths)
            if let firstFailure = failures.first { throw firstFailure }
        } catch {
            if rescuePlan != nil {
                if error is RescueActionError {
                    let attemptedIDs = Set(attemptedTargets.map(\.id))
                    let heldTargets = targets.filter { !attemptedIDs.contains($0.id) }
                    recordRescueResult(before: before, targets: attemptedTargets, failures: failures,
                                       measurementMismatchPaths: measurementMismatchPaths,
                                       heldNodes: heldTargets,
                                       errorMessage: error.localizedDescription)
                } else {
                    lastRescueError = error.localizedDescription
                    rescuePhase = .result
                    persistRescueCase(candidateIDs: stagedRescueCandidateIDs())
                }
            }
            throw error
        }
    }

    private func holdIfRescueOwnerIsActive(_ targets: [FileNode]) throws {
        guard let plan = rescuePlan,
              CleanupOwnerState.current() == .active else { return }
        let targetIDs = Set(targets.map(\.id))
        guard plan.recommendations.contains(where: {
            targetIDs.contains($0.node.id) && $0.category.confidence == .safeRegenerable
        }) else { return }
        throw RescueActionError.ownerActive("Xcode is active. Close it, then review the rescue plan again before moving generated files.")
    }

    private func stagedRescueCandidateIDs() -> Set<String> {
        guard let plan = rescuePlan else { return [] }
        return Set(collector.compactMap { node in
            plan.recommendations.first(where: { $0.node.id == node.id })?.id
        })
    }

    /// Permanently delete every collected item, then prune them from the tree.
    func deleteCollector() throws {
        try deletePermanently(collector)
    }

    /// Permanently delete `nodes` from disk (NOT the Trash — see `DeletionService`)
    /// and prune the successfully-deleted ones from both the tree and the
    /// collector. Synthetic nodes are ignored. Throws if every deletion failed.
    func deletePermanently(_ nodes: [FileNode]) throws {
        let targets = topLevelTargets(nodes.filter { !$0.isSynthetic })
        guard !targets.isEmpty else { return }
        try holdIfRescueOwnerIsActive(targets)
        let failures = try DeletionService.delete(targets)
        try prune(targets, failures: failures)
    }

    private func topLevelTargets(_ nodes: [FileNode]) -> [FileNode] {
        let targetIDs = Set(nodes.map(\.id))
        return nodes.filter { node in
            var cursor = node.parent
            while let parent = cursor {
                if targetIDs.contains(parent.id) { return false }
                cursor = parent.parent
            }
            return true
        }
    }

    private func currentRescueMeasurement() -> RescueMeasurement? {
        guard let rootNode, let scannedURL else { return nil }
        return RescueMeasurement.capture(volumeURL: scannedURL, root: rootNode)
    }

    private func currentRescueCapacity() -> RescueMeasurement? {
        guard let scannedURL else { return nil }
        return RescueMeasurement.captureCapacity(volumeURL: scannedURL)
    }

    private func recordRescueResult(before: RescueMeasurement?, targets: [FileNode],
                                    failures: [DeletionService.DeletionError],
                                    measurementMismatchPaths: [String],
                                    heldNodes: [FileNode] = [],
                                    errorMessage: String? = nil) {
        guard rescuePlan != nil else { return }
        rescuePhase = .verifying
        let failedURLs = Set(failures.map { $0.url.standardizedFileURL })
        let movedBytes = targets
            .filter { !failedURLs.contains($0.url.standardizedFileURL) }
            .reduce(0) { $0 + $1.physicalSize }
        let failedBytes = targets
            .filter { failedURLs.contains($0.url.standardizedFileURL) }
            .reduce(0) { $0 + $1.physicalSize }
        let movedPaths = targets
            .filter { !failedURLs.contains($0.url.standardizedFileURL) }
            .map { $0.url.standardizedFileURL.path }
        let attemptedIDs = Set(targets.map(\.id))
        let explicitHeldIDs = Set(heldNodes.map(\.id))
        let heldRecommendations = rescuePlan?.recommendations.filter {
            !attemptedIDs.contains($0.node.id)
                && ($0.risk != .safe || explicitHeldIDs.contains($0.node.id))
        } ?? []
        let heldRecommendationIDs = Set(heldRecommendations.map { $0.node.id })
        let unplannedHeldNodes = heldNodes.filter { !heldRecommendationIDs.contains($0.id) }
        rescueVerification = RescueVerification(
            requestedBytes: rescuePlan?.targetSpace,
            movedBytes: movedBytes,
            movedPaths: movedPaths.isEmpty ? nil : movedPaths,
            failedBytes: failedBytes,
            failedPaths: failures.map { $0.url.standardizedFileURL.path },
            heldBytes: heldRecommendations.reduce(0) { $0 + $1.physicalBytes }
                + unplannedHeldNodes.reduce(0) { $0 + $1.physicalSize },
            heldPaths: heldRecommendations.map(\.path)
                + unplannedHeldNodes.map { $0.url.standardizedFileURL.path },
            measurementMismatchPaths: measurementMismatchPaths.isEmpty ? nil : measurementMismatchPaths,
            before: before,
            after: currentRescueMeasurement()
        )
        lastRescueError = errorMessage ?? failures.first?.localizedDescription
        rescuePhase = .result
        persistRescueCase(candidateIDs: stagedRescueCandidateIDs())
    }

    /// Shared post-removal cleanup for both the trash and permanent-delete paths:
    /// prune the items that actually went away from the tree and the collector,
    /// reset hover/selection, keep `currentRoot` reachable, and re-throw the first
    /// failure (if any) so the caller can surface it.
    private func prune(_ targets: [FileNode], failures: [DeletionService.DeletionError]) throws {
        let failedURLs = Set(failures.map { $0.url.standardizedFileURL })

        // Drop any target whose ancestor is also being removed: pruning the ancestor
        // already detaches the descendant, and calling `remove` for both would
        // double-subtract the descendant's bytes (and try to remove an already-gone
        // child). `addToCollector` supersedes descendants today, but enforce the
        // invariant here so the public delete entry points are safe for any caller.
        let targetIDs = Set(targets.map(\.id))
        func hasAncestorInSet(_ node: FileNode) -> Bool {
            var cursor = node.parent
            while let c = cursor {
                if targetIDs.contains(c.id) { return true }
                cursor = c.parent
            }
            return false
        }
        let topLevel = targets.filter { !hasAncestorInSet($0) }

        let removed = topLevel.filter { !failedURLs.contains($0.url.standardizedFileURL) }
        let removedIDs = Set(removed.map(\.id))
        for node in removed {
            node.parent?.remove(node)
        }
        // Clear from the collector everything that actually went away: the removed
        // nodes themselves and any staged descendant detached along with a removed
        // ancestor, so nothing dangling stays staged.
        func wasRemoved(_ node: FileNode) -> Bool {
            var cursor: FileNode? = node
            while let c = cursor {
                if removedIDs.contains(c.id) { return true }
                cursor = c.parent
            }
            return false
        }
        collector.removeAll { wasRemoved($0) }

        // Always clear hover/selection after a delete.
        hoveredNode = nil
        selectedNode = nil

        // Ensure currentRoot is still reachable from rootNode.
        // Walk its parent chain; if it doesn't terminate at rootNode, walk upward
        // through .parent until we find a node whose chain does, or fall back to rootNode.
        func isReachable(_ node: FileNode, from root: FileNode) -> Bool {
            var cursor: FileNode? = node
            while let c = cursor {
                if c.id == root.id { return true }
                cursor = c.parent
            }
            return false
        }

        var correctedRoot = currentRoot
        if let root = rootNode, let candidate = correctedRoot {
            if !isReachable(candidate, from: root) {
                // Walk up from candidate until we find a reachable ancestor.
                var cursor: FileNode? = candidate.parent
                var found: FileNode? = nil
                while let c = cursor {
                    if isReachable(c, from: root) {
                        found = c
                        break
                    }
                    cursor = c.parent
                }
                correctedRoot = found ?? root
            }
        }

        // Publish the corrected root and separately invalidate the cached angular
        // layout when the existing tree actually changed.
        currentRoot = correctedRoot
        if !removed.isEmpty { chartRevision &+= 1 }

        if let firstFailure = failures.first {
            throw firstFailure
        }
    }

    // MARK: - Full Disk Access

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Probe whether the app currently holds Full Disk Access. We try to open a
    /// couple of TCC-protected files that always exist in a user's home but are
    /// only readable with FDA granted. A successful `open` (or a non-permission
    /// error) means access is granted; `EPERM`/`EACCES` means it is denied.
    ///
    /// This is the same signal macOS uses, observed without prompting: an app
    /// with FDA can open these, one without cannot.
    nonisolated static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let probes = [
            home + "/Library/Application Support/com.apple.TCC/TCC.db",
            home + "/Library/Safari/Bookmarks.plist",
        ]
        for path in probes where FileManager.default.fileExists(atPath: path) {
            let fd = open(path, O_RDONLY)
            if fd >= 0 {
                close(fd)
                return true
            }
            if errno == EPERM || errno == EACCES {
                return false
            }
        }
        // Neither probe file exists (unusual) — don't block the user on a guess.
        return true
    }

    /// Re-evaluate FDA status and drive the onboarding overlay. Called on launch
    /// and whenever the app reactivates (e.g. returning from System Settings), so
    /// granting access auto-dismisses the prompt with no further action.
    func refreshFullDiskAccessStatus() {
        // Headless/automation runs must never block on UI.
        if ProcessInfo.processInfo.environment["SO_AUTOSCAN"] != nil { return }

        if Self.hasFullDiskAccess() {
            showFDAOnboarding = false
            needsFullDiskAccess = false
        } else if !fdaDismissedThisSession {
            showFDAOnboarding = true
        }
    }

    /// User chose to proceed without granting access. Suppress the overlay for the
    /// rest of this session; the per-scan `needsFullDiskAccess` card still appears
    /// if a scan later comes back empty for lack of permission.
    func dismissFDAOnboarding() {
        fdaDismissedThisSession = true
        showFDAOnboarding = false
    }
}
