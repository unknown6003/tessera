import SwiftUI
import AppKit

struct ContentView: View {
    private enum AppMode: String, CaseIterable, Identifiable {
        case explore, rescue
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private struct RemovalSnapshot {
        let nodes: [FileNode]
        let sourcePath: String
        let rootID: ObjectIdentifier?
        let revision: UInt64
        let collectorIDs: Set<ObjectIdentifier>
    }

    @StateObject private var vm = ScanViewModel()
    @StateObject private var drag = CollectorDragController()
    @EnvironmentObject private var updater: UpdaterController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appMode: AppMode = .explore
    @State private var showSidebar = true
    @State private var showInspector = false
    @State private var showCompactInspector = false
    @State private var windowWidth: CGFloat = 1240
    @State private var queuedReviewAction: RemovalSnapshot?
    @State private var queuedReviewIsPermanent = false
    @State private var showReview = false
    @State private var reviewSnapshot: RemovalSnapshot?
    @State private var showTrashConfirm = false
    @State private var showDeleteAllConfirm = false
    @State private var pendingTrash: RemovalSnapshot?
    @State private var pendingDelete: RemovalSnapshot?
    @State private var removalRequested = false
    @State private var deleteErrorTitle = "Could not remove items"
    @State private var deleteError: String?

    private var removalBusy: Bool { vm.isDeleting || removalRequested }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Sidebar(vm: vm)
                    .frame(width: showSidebar ? 210 : 0)
                    .clipped()
                    .opacity(showSidebar ? 1 : 0)
                    .accessibilityHidden(!showSidebar)
                    .disabled(removalBusy || !showSidebar)
                if showSidebar { Divider() }

                VStack(spacing: 0) {
                    sourceHeader
                    Divider()
                    if vm.isScanning {
                        ScanningView(vm: vm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if appMode == .rescue && vm.errorMessage == nil && !vm.needsFullDiskAccess {
                        rescueWorkspace
                    } else {
                        HStack(spacing: 0) {
                            centerArea
                            if showInspector && geometry.size.width >= 1100 {
                                Divider()
                                InspectorView(vm: vm)
                                    .frame(width: min(300, max(240, geometry.size.width * 0.22)))
                            }
                        }
                    }
                    if vm.rootNode != nil || removalBusy {
                        Divider()
                        CollectorDock(vm: vm, drag: drag, onReview: openReview)
                            .disabled(removalBusy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .background(Theme.bg.ignoresSafeArea())
        .background(TransparentWindowConfigurator())
        .background(KeyboardShortcuts(vm: vm).disabled(removalBusy || vm.isScanning))
        .tint(Theme.electricBlue)
        .preferredColorScheme(.dark)
        .coordinateSpace(.named(CollectorDragController.appSpace))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { showSidebar.toggle() } label: {
                    Label("Sources", systemImage: "sidebar.left")
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .help(showSidebar ? "Hide sources" : "Show sources")
            }
            ToolbarItem(placement: .principal) {
                Picker("Workspace", selection: $appMode) {
                    ForEach(AppMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            ToolbarItem(placement: .primaryAction) {
                CleanupActionBar(vm: vm, onRescue: { appMode = .rescue })
                    .disabled(removalBusy || vm.isScanning || vm.rootNode == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if windowWidth < 1100 { showCompactInspector.toggle() }
                    else { showInspector.toggle() }
                } label: {
                    Label("Details", systemImage: "sidebar.right")
                }
                .keyboardShortcut("i", modifiers: [.command, .control])
                .help("Show or hide selected item details")
                .disabled(appMode != .explore)
                .popover(isPresented: $showCompactInspector) {
                    InspectorView(vm: vm).frame(width: 320, height: 500)
                }
            }
        }
        .overlay {
            if let node = drag.node {
                DragPreview(node: node).position(drag.location).allowsHitTesting(false)
            }
        }
        .overlay {
            if vm.showFDAOnboarding { FullDiskAccessOnboarding(vm: vm) }
        }
        .transaction { if reduceMotion { $0.animation = nil } }
        .onChange(of: vm.isScanning, initial: true) { _, _ in syncUpdaterBusy() }
        .onChange(of: vm.isDeleting) { _, _ in syncUpdaterBusy() }
        .onChange(of: removalRequested) { _, _ in syncUpdaterBusy() }
        .onChange(of: vm.collector.isEmpty) { _, _ in syncUpdaterBusy() }
        .sheet(isPresented: $showReview, onDismiss: finishReview) {
            if let snapshot = reviewSnapshot {
                CleanupReviewSheet(vm: vm, nodes: snapshot.nodes, sourcePath: snapshot.sourcePath,
                                   rootID: snapshot.rootID, revision: snapshot.revision,
                                   onTrash: { nodes in
                                       queueReviewAction(nodes, permanent: false)
                                   }, onDelete: { nodes in
                                       queueReviewAction(nodes, permanent: true)
                                   })
            }
        }
        .confirmationDialog("Move \(pendingTrash?.nodes.count ?? 0) items to Trash?",
                            isPresented: $showTrashConfirm, titleVisibility: .visible) {
            Button("Move to Trash") {
                if let snapshot = pendingTrash { performTrash(snapshot) }
            }
            Button("Cancel", role: .cancel) { vm.cancelTrashConfirmation() }
        } message: {
            Text("Move \(Theme.format(pendingTrash?.nodes.reduce(0) { $0 + $1.physicalSize } ?? 0)) to Finder Trash. \(pendingTrashRiskSummary) \(pendingTrashTargetSummary) You can restore these items. Trash uses disk space until you empty it.")
        }
        .confirmationDialog("Permanently delete \(pendingDelete?.nodes.count ?? 0) items?",
                            isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("Move to Trash Instead") {
                if let snapshot = pendingDelete { requestTrash(snapshot) }
            }
            Button("Delete Permanently", role: .destructive) {
                if let snapshot = pendingDelete { performDelete(snapshot) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(Theme.format(pendingDelete?.nodes.reduce(0) { $0 + $1.physicalSize } ?? 0)) and cannot be undone. Check every path in the Cleanup List first.")
        }
        .alert(deleteErrorTitle, isPresented: Binding(
            get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
        )) { Button("OK") { deleteError = nil } } message: { Text(deleteError ?? "") }
        .onAppear {
            vm.refreshFullDiskAccessStatus()
            SharedScanContext.shared.register(vm)
            DebugAutomation.runIfRequested(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.refreshFullDiskAccessStatus()
        }
        .onChange(of: showTrashConfirm) { _, presented in
            if !presented {
                if !removalRequested { vm.cancelTrashConfirmation() }
                pendingTrash = nil
            }
        }
        .onChange(of: showDeleteAllConfirm) { _, presented in
            if !presented { pendingDelete = nil }
        }
        .onChange(of: vm.scannedURL) { _, _ in
            showTrashConfirm = false
            showDeleteAllConfirm = false
        }
        .onChange(of: vm.isScanning) { _, scanning in
            if scanning {
                showTrashConfirm = false
                showDeleteAllConfirm = false
                drag.reset()
            }
        }
    }

    private var sourceHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.currentRoot?.name ?? sourceName)
                    .font(.headline)
                    .lineLimit(1)
                Text(vm.scannedURL?.path ?? vm.selectedSourceURL?.path ?? "Choose a source to begin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            if removalBusy {
                ProgressView().controlSize(.small)
                Text("Removing \(vm.deletionProgress) of \(vm.deletionTotal)")
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel("Removal progress")
            } else if !vm.isScanning {
                if !vm.scanStatus.isEmpty, vm.rootNode != nil {
                    Text(vm.scanStatus).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if vm.scannedURL != nil && vm.selectedSourceURL != vm.scannedURL {
                    Text("Scan \(sourceName)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Button {
                    if let source = vm.selectedSourceURL { vm.startScan(volumeURL: source) }
                } label: {
                    Label(vm.selectedSourceURL == vm.scannedURL ? "Rescan" : "Scan source",
                          systemImage: "arrow.clockwise")
                }
                .disabled(vm.selectedSourceURL == nil)
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var sourceName: String {
        guard let source = vm.selectedSourceURL else { return "Tessera" }
        return source.lastPathComponent.isEmpty ? source.path : source.lastPathComponent
    }

    private var rescueWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if vm.rootNode == nil { emptyContent }
                CleanupSuggestionsView(vm: vm, onMoveToTrash: openReview)
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .disabled(removalBusy)
    }

    @ViewBuilder private var centerArea: some View {
        if vm.needsFullDiskAccess {
            taskState { fullDiskAccessContent }
        } else if let error = vm.errorMessage {
            taskState { errorContent(error) }
        } else if vm.rootNode == nil {
            taskState { emptyContent }
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        VStack(spacing: 0) {
            if let current = vm.currentRoot { breadcrumb(for: current) }
            GeometryReader { geometry in
                if geometry.size.width >= 580 {
                    HStack(spacing: 16) {
                        chart
                        largestItems.frame(width: min(230, geometry.size.width * 0.30))
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        chart
                        largestItems
                            .frame(height: min(142, max(86, geometry.size.height * 0.24)))
                            .padding(.horizontal, 20)
                    }
                }
            }
            selectedItemBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chart: some View {
        SunburstChart(root: vm.currentRoot, contentRevision: vm.chartRevision,
                      hoveredNode: vm.hoveredNode, selectedNode: vm.selectedNode,
                      onHover: { vm.hoveredNode = $0 }, onSelect: { vm.selectedNode = $0 },
                      onZoomIn: { vm.zoomIn(to: $0) }, onZoomOut: { vm.zoomOut() },
                      onAddToCollector: { if !removalBusy { vm.addToCollector($0) } },
                      onRevealInFinder: { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) },
                      drag: drag, onDrop: { if !removalBusy { vm.addToCollector($0) } })
            .disabled(removalBusy)
    }

    private var largestItems: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Largest items").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(vm.currentRoot?.largestChildren(limit: 5) ?? []) { node in
                        HStack(spacing: 6) {
                            Button { vm.selectedNode = node } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: Theme.icon(for: node))
                                        .foregroundStyle(Theme.electricBlue).frame(width: 16)
                                    Text(node.name).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 4)
                                    Text(Theme.format(node.size)).monospacedDigit().foregroundStyle(.secondary)
                                }
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 6)
                                .background(vm.selectedNode?.id == node.id ? Theme.selectionTint : .clear,
                                            in: RoundedRectangle(cornerRadius: 4))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Select \(node.name), \(Theme.format(node.size))")
                            .accessibilityAddTraits(vm.selectedNode?.id == node.id ? .isSelected : [])
                            if node.isDirectory && !node.isSynthetic {
                                Button { vm.zoomIn(to: node) } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .buttonStyle(.borderless)
                                .help("Open \(node.name)")
                                .accessibilityLabel("Open \(node.name)")
                            }
                        }
                    }
                }
            }
        }
        .disabled(removalBusy)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Largest items")
        .onMoveCommand { direction in
            guard !removalBusy else { return }
            let nodes = vm.currentRoot?.largestChildren(limit: 5) ?? []
            guard !nodes.isEmpty else { return }
            let index = nodes.firstIndex { $0.id == vm.selectedNode?.id }
            if direction == .down { vm.selectedNode = nodes[min(nodes.count - 1, (index ?? -1) + 1)] }
            if direction == .up { vm.selectedNode = nodes[max(0, (index ?? nodes.count) - 1)] }
        }
    }

    private var selectedItemBar: some View {
        HStack(spacing: 10) {
            if let node = vm.selectedNode {
                Text(node.url.path).font(.caption).lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                if !node.isSynthetic {
                    if node.isDirectory { Button("Open") { vm.zoomIn(to: node) } }
                    Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
                    Button(vm.isCollected(node) ? "Added" : "Add to Cleanup List") { vm.addToCollector(node) }
                        .disabled(vm.isCollected(node))
                }
            } else {
                Text("Select an item for actions. Open folders with a double-click.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .disabled(removalBusy)
    }

    private func taskState<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().padding(32).frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().frame(width: 64, height: 64).accessibilityHidden(true)
            Text("See where your space goes").font(.title.weight(.semibold))
            Text("Choose a source, then scan it. Explore the map or use Rescue to review cleanup suggestions.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let source = vm.selectedSourceURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text(source.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.middle)
                    Button { vm.startScan(volumeURL: source) } label: {
                        Label("Scan \(sourceName)", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(removalBusy)
                }
            }
            Text("Scanning does not change your files.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var fullDiskAccessContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Full Disk Access needed", systemImage: "lock.shield").font(.title2)
            Text("Grant access in System Settings, then scan again.").foregroundStyle(.secondary)
            Button("Open System Settings") { vm.openFullDiskAccessSettings() }.buttonStyle(.borderedProminent)
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Scan failed", systemImage: "exclamationmark.triangle").font(.title2)
            Text(message).foregroundStyle(.secondary).textSelection(.enabled)
            if vm.canRetryLastScan {
                Button("Try again") { vm.errorMessage = nil; vm.retryLastScan() }
                    .buttonStyle(.borderedProminent).disabled(removalBusy)
            }
            Button("Dismiss") { vm.errorMessage = nil }
        }
    }

    private func openReview() {
        guard !vm.isScanning, !removalBusy, let snapshot = snapshot(vm.collector) else { return }
        reviewSnapshot = snapshot
        showReview = true
    }

    private func snapshot(_ nodes: [FileNode]) -> RemovalSnapshot? {
        guard !nodes.isEmpty, let path = vm.scannedURL?.standardizedFileURL.path else { return nil }
        return RemovalSnapshot(nodes: nodes, sourcePath: path, rootID: vm.rootNode?.id,
                               revision: vm.chartRevision, collectorIDs: Set(vm.collector.map(\.id)))
    }

    private func queueReviewAction(_ nodes: [FileNode], permanent: Bool) {
        guard let review = reviewSnapshot, !nodes.isEmpty else { return }
        queuedReviewAction = RemovalSnapshot(nodes: nodes, sourcePath: review.sourcePath,
                                            rootID: review.rootID, revision: review.revision,
                                            collectorIDs: Set(nodes.map(\.id)))
        queuedReviewIsPermanent = permanent
        showReview = false
    }

    private func finishReview() {
        guard let snapshot = queuedReviewAction else { return }
        queuedReviewAction = nil
        if queuedReviewIsPermanent { requestDelete(snapshot) }
        else { requestTrash(snapshot) }
    }

    private func requestTrash(_ snapshot: RemovalSnapshot) {
        guard !removalBusy, snapshotIsCurrent(snapshot) else {
            deleteErrorTitle = "Review needed"
            deleteError = "The scan or Cleanup List changed. Open the list and review it again."
            return
        }
        pendingTrash = snapshot
        vm.beginTrashConfirmation()
        showTrashConfirm = true
    }

    private func requestDelete(_ snapshot: RemovalSnapshot) {
        guard !removalBusy, snapshotIsCurrent(snapshot) else {
            deleteErrorTitle = "Review needed"
            deleteError = "The scan or Cleanup List changed. Open the list and review it again."
            return
        }
        pendingDelete = snapshot
        showDeleteAllConfirm = true
    }

    private func snapshotIsCurrent(_ snapshot: RemovalSnapshot) -> Bool {
        !vm.isScanning && !vm.isDeleting
            && snapshot.sourcePath == vm.scannedURL?.standardizedFileURL.path
            && snapshot.rootID == vm.rootNode?.id
            && snapshot.revision == vm.chartRevision
            && snapshot.collectorIDs == Set(vm.collector.map(\.id))
            && Set(snapshot.nodes.map(\.id)).isSubset(of: snapshot.collectorIDs)
    }

    private func performTrash(_ snapshot: RemovalSnapshot) {
        removalRequested = true
        deleteError = nil
        Task { @MainActor in
            defer { removalRequested = false }
            guard snapshotIsCurrent(snapshot) else {
                vm.cancelTrashConfirmation()
                deleteErrorTitle = "Move to Trash failed"
                deleteError = "The scan or Cleanup List changed. Review the current list before moving anything."
                return
            }
            do { try await vm.moveToTrash(snapshot.nodes) }
            catch { deleteErrorTitle = "Move to Trash failed"; deleteError = error.localizedDescription }
        }
    }

    private func performDelete(_ snapshot: RemovalSnapshot) {
        removalRequested = true
        deleteError = nil
        Task { @MainActor in
            defer { removalRequested = false }
            guard snapshotIsCurrent(snapshot) else {
                deleteErrorTitle = "Delete failed"
                deleteError = "The scan or Cleanup List changed. Review the current list before deleting anything."
                return
            }
            do { try await vm.deletePermanently(snapshot.nodes) }
            catch { deleteErrorTitle = "Delete failed"; deleteError = error.localizedDescription }
        }
    }

    private var pendingTrashRiskSummary: String {
        guard let plan = vm.rescuePlan, let nodes = pendingTrash?.nodes else { return "Review the exact paths." }
        let parts = [(CleanupRisk.safe, "safe"), (.review, "review"), (.protected, "protected")].compactMap { risk, title -> String? in
            let count = nodes.filter { node in plan.recommendations.first { $0.node.id == node.id }?.risk == risk }.count
            return count > 0 ? "\(count) \(title)" : nil
        }
        return parts.isEmpty ? "Review the exact paths." : parts.joined(separator: ", ") + "."
    }

    private var pendingTrashTargetSummary: String {
        guard let plan = vm.rescuePlan, let target = plan.targetSpace else { return "No capacity target is available." }
        return "Goal: under \(Int((plan.capacityGoal * 100).rounded()))% used, \(Theme.format(target)) free."
    }

    private func syncUpdaterBusy() {
        updater.isBusy = vm.isScanning || removalBusy || !vm.collector.isEmpty
    }

    // MARK: - Breadcrumb

    private func breadcrumb(for node: FileNode) -> some View {
        let ancestors = ancestorChain(of: node)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                breadcrumbHome
                ForEach(ancestors) { ancestor in
                    chevron
                    Button(ancestor.name) { selectBreadcrumbNode(ancestor) }
                        .buttonStyle(.interactive)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                if !ancestors.isEmpty { chevron }
                breadcrumbCurrent(node)
            }
            .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 6) {
                breadcrumbHome
                if !ancestors.isEmpty {
                    chevron
                    Menu {
                        ForEach(ancestors) { ancestor in
                            Button(ancestor.name) { selectBreadcrumbNode(ancestor) }
                        }
                    } label: {
                        Label("Path", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Open parent folders")
                    chevron
                }
                breadcrumbCurrent(node)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var breadcrumbHome: some View {
        Button {
            vm.zoomToRoot()
        } label: {
            Image(systemName: "house.fill")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.interactive)
        .help("Zoom to root")
    }

    private func breadcrumbCurrent(_ node: FileNode) -> some View {
        HStack(spacing: 6) {
            Text(node.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text(Theme.format(node.size))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    private func selectBreadcrumbNode(_ node: FileNode) {
        vm.zoomIn(to: node)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func ancestorChain(of node: FileNode) -> [FileNode] {
        var chain: [FileNode] = []
        var cursor = node.parent
        while let c = cursor {
            chain.insert(c, at: 0)
            cursor = c.parent
        }
        return chain
    }
}

// MARK: - Scan status

private struct ScanningView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(vm.scanStatus.isEmpty ? "Scanning source" : vm.scanStatus)
                .font(.title2.weight(.semibold))
            Text("Tessera is reading this source. Your files stay in place.")
                .foregroundStyle(.secondary)
            ProgressView().progressViewStyle(.linear)
                .accessibilityLabel("Scan in progress")
            HStack(spacing: 24) {
                metric("Files read", "\(vm.progress.filesScanned)")
                metric("Folders read", "\(vm.progress.dirsScanned)")
                metric("Mapped", Theme.format(vm.progress.bytesFound))
            }
            if let start = vm.scanStartedAt {
                HStack(spacing: 6) {
                    Text("Elapsed")
                    Text(start, style: .timer).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Text(vm.progress.currentPath.isEmpty ? "Preparing source…" : vm.progress.currentPath)
                .font(.caption.monospaced()).foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Cancel scan", role: .cancel) { vm.cancelScan() }
                .buttonStyle(.bordered).keyboardShortcut(".", modifiers: .command)
        }
        .padding(32)
        .frame(maxWidth: 560, alignment: .leading)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title3.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct KeyboardShortcuts: View {
    @ObservedObject var vm: ScanViewModel
    var body: some View {
        ZStack {
            Button("Zoom Out") { vm.zoomOut() }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("Clear Selection") { vm.selectedNode = nil }.keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}

// MARK: - Full Disk Access onboarding

/// First-launch overlay that asks for Full Disk Access once, up front, so the
/// app can read the whole disk instead of failing per-directory mid-scan. It
    /// dims the window behind a solid card and auto-dismisses the moment access is
/// detected (the window re-checks on reactivation).
private struct FullDiskAccessOnboarding: View {
    @ObservedObject var vm: ScanViewModel

    private let steps: [(symbol: String, text: String)] = [
        ("1.circle.fill", "Click **Open System Settings** below."),
        ("2.circle.fill", "Find **Tessera** in the list and turn it on."),
        ("3.circle.fill", "Return here. Scanning unlocks automatically."),
    ]

    var body: some View {
        ZStack {
            // Scrim that darkens and blurs the app behind the card.
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()

            card
                .frame(maxWidth: 520)
                .padding(24)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.18))
                .frame(width: 80, height: 80)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 10) {
                Text("Grant Full Disk Access")
                    .font(.title.weight(.semibold))
                Text("Tessera needs Full Disk Access to measure every folder on your Mac. You can also choose a folder without granting full access.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(steps, id: \.symbol) { step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: step.symbol)
                            .font(.title3)
                            .foregroundStyle(.tint)
                        Text(.init(step.text))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    vm.openFullDiskAccessSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.flatProminent)
                .controlSize(.large)

                Button("Not Now") {
                    vm.dismissFDAOnboarding()
                }
                .buttonStyle(.flat)
                .controlSize(.large)
            }
        }
        .padding(28)
        .background(Theme.elevated, in: shape)
        .liquidGlassDepth(shape, shadowRadius: 40, shadowY: 22)
    }
}
