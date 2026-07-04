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
    /// On-device LLM verdicts for the large directories the rules didn't recognize.
    @Published var smartSuggestions: [SmartCleanupClassifier.Result] = []
    /// True while the on-device model is judging the long tail.
    @Published var isClassifyingSmart = false
    /// Natural-language cleanup: the user's typed goal, the resolved result, and
    /// whether the planner is currently working.
    @Published var nlIntent: String = ""
    @Published var nlResult: NLCleanupResult?
    @Published var isPlanning = false
    /// Duplicate finder (standard detection + premium AI triage).
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var isFindingDuplicates = false
    @Published var didRunDuplicates = false
    @Published var duplicateProgress = DuplicateProgress()
    @Published var isScanning = false
    @Published var progress = ScanProgress()
    @Published var errorMessage: String?
    @Published var needsFullDiskAccess = false
    /// Drives the first-launch onboarding prompt that asks for Full Disk Access
    /// once, up front, instead of failing per-directory mid-scan.
    @Published var showFDAOnboarding = false
    private var fdaDismissedThisSession = false

    /// The volume whose scan results are currently on screen — set when a scan
    /// completes, cleared when a new scan starts. Drives the sidebar's "Viewing"
    /// indicator and the "you switched away from what's displayed" affordance.
    @Published private(set) var scannedURL: URL?

    private var scanTask: Task<Void, Never>?
    private var duplicateTask: Task<Void, Never>?
    private var duplicateCancel: DuplicateCancelToken?
    /// The last volume scanned, so a re-scan of the same volume can reuse the
    /// previous tree for incremental speedup.
    private var lastScannedURL: URL?

    /// Completed scans kept in memory so switching between disks/cloud is instant
    /// (no re-scan). Capped (LRU) because each tree can be large.
    private struct CachedScan {
        let rootNode: FileNode
        let currentRoot: FileNode?
        let cleanupReport: CleanupReport?
        let smartSuggestions: [SmartCleanupClassifier.Result]
        let duplicateGroups: [DuplicateGroup]
        let didRunDuplicates: Bool
        let collector: [FileNode]
        let progress: ScanProgress
    }
    private var scanCache: [URL: CachedScan] = [:]
    private var cacheLRU: [URL] = []
    private let maxCachedScans = 3
    /// Diagnostic: true when the last scan ended via CancellationError.
    private(set) var scanTaskWasCancelled = false

    // MARK: - Computed

    var collectorTotalSize: Int64 { collector.reduce(0) { $0 + $1.size } }

    // MARK: - Scan

    func startScan(volumeURL: URL) {
        scanTask?.cancel()
        // Preserve the scan currently on screen so switching back to it is instant.
        saveCurrentToCache()
        // Incremental re-scan: reuse a prior tree for this volume (from the cache, or
        // the one already displayed) as a baseline. Unchanged subtrees (by directory
        // modtime) are skipped, and any directory whose contents changed — including
        // via deletions the user just made — has a new modtime, so it's re-scanned
        // for fresh sizes.
        let cache = scanCache[volumeURL]?.rootNode ?? (volumeURL == scannedURL ? rootNode : nil)
        lastScannedURL = volumeURL
        scannedURL = nil
        rootNode = nil
        scanTaskWasCancelled = false
        currentRoot = nil
        hoveredNode = nil
        selectedNode = nil
        collector = []
        cleanupReport = nil
        smartSuggestions = []
        isClassifyingSmart = false
        nlResult = nil
        isPlanning = false
        duplicateCancel?.cancel()
        duplicateTask?.cancel()
        duplicateGroups = []
        isFindingDuplicates = false
        didRunDuplicates = false
        duplicateProgress = DuplicateProgress()
        errorMessage = nil
        needsFullDiskAccess = false
        isScanning = true
        progress = ScanProgress(currentPath: volumeURL.path)

        scanTask = Task {
            do {
                let node = try await FileScanner.scan(url: volumeURL, cache: cache) { [weak self] prog in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
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
                let treeIsEmpty = node.children.isEmpty
                let volumePath = volumeURL.path
                let isVolumeRoot = volumePath == "/"
                let isUnreadable = !FileManager.default.isReadableFile(atPath: volumePath)
                if treeIsEmpty && (isVolumeRoot || isUnreadable) {
                    self.needsFullDiskAccess = true
                }
                self.rootNode = node
                self.currentRoot = node
                self.scannedURL = volumeURL
                // Classify cleanup suggestions off the main actor (pure CPU over the
                // already-built tree, no I/O), then publish — doesn't gate the scan.
                Task { @MainActor [weak self] in
                    let report = await Task.detached(priority: .utility) {
                        CleanupClassifier.classify(root: node)
                    }.value
                    guard let self else { return }
                    self.cleanupReport = report
                    // Suggestions are NOT auto-staged. The user reviews the groups
                    // and chooses what to add — per group, or all-safe at once —
                    // then deletes from the collector behind the usual confirmation.

                    // Smart pass: the on-device model judges the largest directories
                    // the rules didn't recognize. Its picks are only SUGGESTED for
                    // the user to add manually — NEVER auto-staged. A small on-device
                    // model is not reliable enough to stage deletions (it has
                    // confidently mislabeled iCloud Drive, Messages, and Preferences
                    // as "cache"), so only the deterministic rule matches above are
                    // auto-staged; the model just surfaces candidates for review.
                    await self.classifySmart(root: node, report: report)
                }
            } catch is CancellationError {
                // User stopped the scan — not an error.
                self.scanTaskWasCancelled = true
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isScanning = false
        }
    }

    func cancelScan() {
        scanTask?.cancel()
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
            smartSuggestions: smartSuggestions, duplicateGroups: duplicateGroups,
            didRunDuplicates: didRunDuplicates, collector: collector, progress: progress)
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
        if isScanning { scanTask?.cancel(); isScanning = false }
        duplicateTask?.cancel()
        // Preserve what we're leaving, then restore the requested scan.
        saveCurrentToCache()

        rootNode = cached.rootNode
        currentRoot = cached.currentRoot ?? cached.rootNode
        cleanupReport = cached.cleanupReport
        smartSuggestions = cached.smartSuggestions
        duplicateGroups = cached.duplicateGroups
        didRunDuplicates = cached.didRunDuplicates
        collector = cached.collector
        progress = cached.progress
        scannedURL = url
        lastScannedURL = url

        hoveredNode = nil
        selectedNode = nil
        nlResult = nil
        nlIntent = ""
        isFindingDuplicates = false
        isClassifyingSmart = false
        isPlanning = false
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
    }

    func removeFromCollector(_ node: FileNode) {
        collector.removeAll { $0.id == node.id }
    }

    func clearCollector() {
        collector = []
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
    }

    /// Add one suggestion group to the collector (used for opt-in review rows).
    func stageCleanupGroup(_ group: CleanupReport.Group) {
        for node in group.nodes { addToCollector(node) }
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

    /// True once all safe groups are staged — disables the "add all safe" button.
    var safeGroupsAllStaged: Bool {
        guard let report = cleanupReport, !report.safeGroups.isEmpty else { return false }
        return report.safeGroups.allSatisfy { isGroupStaged($0) }
    }

    // MARK: - Natural-language cleanup
    //
    // The flagship AI feature. The user's typed goal is turned into a structured
    // query (by the on-device model when downloaded, or the built-in keyword parser
    // otherwise) and run entirely on-device against the cleanup report. Matching
    // items are surfaced for review — staged into the collector, never deleted.
    // PRIVACY: everything runs locally; nothing about the user's files is sent.

    struct NLCleanupResult: Sendable {
        let intent: String
        let query: CleanupQuery
        let nodes: [FileNode]
        let usedAI: Bool
        var totalBytes: Int64 { nodes.reduce(0) { $0 + $1.size } }
        var isEmpty: Bool { nodes.isEmpty }
    }

    /// Plan + run the current `nlIntent` against the scan. No-op without a report.
    func runNaturalLanguageCleanup() {
        let intent = nlIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intent.isEmpty, let report = cleanupReport else { return }
        isPlanning = true
        nlResult = nil
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            let plan = await IntentPlanner.plan(intent: intent, todayEpoch: now)
            let nodes = CleanupQueryEngine.execute(plan.query, report: report, nowEpoch: now)
            self.nlResult = NLCleanupResult(intent: intent, query: plan.query,
                                            nodes: nodes, usedAI: plan.usedAI)
            self.isPlanning = false
        }
    }

    /// Stage every node the last NL result matched into the collector for review.
    func stageNLResult() {
        guard let result = nlResult else { return }
        for node in result.nodes { addToCollector(node) }
    }

    /// True once every NL-matched node is staged — drives the Add/Added toggle.
    var nlResultAllStaged: Bool {
        guard let result = nlResult, !result.nodes.isEmpty else { return false }
        return result.nodes.allSatisfy { isCollected($0) }
    }

    /// Clear the current NL result and input.
    func clearNLResult() {
        nlResult = nil
        nlIntent = ""
    }

    // MARK: - Duplicate finder
    //
    // Fully on-device (DuplicateFinder): detection + keeper heuristic, no network.

    /// Scan the current tree for exact-content duplicate files. Detection runs on a
    /// GCD worker pool (off the cooperative pool, since it does blocking reads).
    func findDuplicates() {
        guard let root = rootNode, !isFindingDuplicates else { return }
        duplicateCancel?.cancel()
        let token = DuplicateCancelToken()
        duplicateCancel = token
        isFindingDuplicates = true
        didRunDuplicates = true
        duplicateGroups = []
        duplicateProgress = DuplicateProgress()
        let onProgress: @Sendable (DuplicateProgress) -> Void = { [weak self] prog in
            Task { @MainActor in self?.duplicateProgress = prog }
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
            guard let self, !token.isCancelled else { return }
            self.duplicateGroups = groups
            self.isFindingDuplicates = false
        }
    }

    func cancelDuplicates() {
        duplicateCancel?.cancel()
        duplicateTask?.cancel()
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

    /// Run the smart (on-device LLM) pass over the long tail the rules didn't
    /// recognize and publish the suggestions. Picks are review-only — never
    /// auto-staged. No-op when the on-device model isn't available.
    func classifySmart(root: FileNode, report: CleanupReport) async {
        guard SmartCleanupClassifier.isAvailable else { return }
        isClassifyingSmart = true
        let matched = Set(report.groups.flatMap(\.nodes).map(\.id))
        // Collect candidates on the main actor (this walks `FileNode.children`) before
        // the detached classify task, so the background never traverses the tree while
        // the collector delete flow can mutate `children` on the main actor.
        let candidates = SmartCleanupClassifier.candidates(root: root, excluding: matched)
        let smart = await Task.detached(priority: .utility) {
            await SmartCleanupClassifier.classify(candidates: candidates)
        }.value
        smartSuggestions = smart.filter(\.safeToDelete).sorted { $0.node.size > $1.node.size }
        isClassifyingSmart = false
    }

    /// Re-run smart suggestions on the current tree (e.g. right after the user
    /// activates their subscription) without a full re-scan.
    func refreshSmartSuggestions() {
        guard let root = rootNode, let report = cleanupReport else { return }
        Task { await classifySmart(root: root, report: report) }
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
        return FileNode(url: url, name: name, isDirectory: isDirectory, size: size, kind: .regular)
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
        let targets = nodes.filter { !$0.isSynthetic }
        guard !targets.isEmpty else { return }
        let failures = try DeletionService.trash(targets.map(\.url))
        try prune(targets, failures: failures)
    }

    /// Permanently delete every collected item, then prune them from the tree.
    func deleteCollector() throws {
        try deletePermanently(collector)
    }

    /// Permanently delete `nodes` from disk (NOT the Trash — see `DeletionService`)
    /// and prune the successfully-deleted ones from both the tree and the
    /// collector. Synthetic nodes are ignored. Throws if every deletion failed.
    func deletePermanently(_ nodes: [FileNode]) throws {
        let targets = nodes.filter { !$0.isSynthetic }
        guard !targets.isEmpty else { return }
        let failures = try DeletionService.delete(targets.map(\.url))
        try prune(targets, failures: failures)
    }

    /// Shared post-removal cleanup for both the trash and permanent-delete paths:
    /// prune the items that actually went away from the tree and the collector,
    /// reset hover/selection, keep `currentRoot` reachable, and re-throw the first
    /// failure (if any) so the caller can surface it.
    private func prune(_ targets: [FileNode], failures: [DeletionService.DeletionError]) throws {
        let failedURLs = Set(failures.map(\.url))

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

        let removed = topLevel.filter { !failedURLs.contains($0.url) }
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

        // Force chart redraw with the corrected (and safe) root.
        currentRoot = nil
        currentRoot = correctedRoot

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
