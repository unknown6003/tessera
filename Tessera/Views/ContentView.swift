import SwiftUI
import AppKit

struct ContentView: View {
    private enum AppMode: String, CaseIterable, Identifiable {
        case explore
        case rescue

        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    @StateObject private var vm = ScanViewModel()
    /// Drives drag-and-drop of chart wedges into the bottom dock.
    @StateObject private var drag = CollectorDragController()
    /// Auto-updater. We only talk to it to say "don't relaunch right now".
    @EnvironmentObject private var updater: UpdaterController

    /// Whether the "permanently delete the whole collector" confirmation is showing.
    @State private var showDeleteAllConfirm = false
    /// Separate confirmation for the recoverable Trash action.
    @State private var showTrashConfirm = false
    @State private var pendingTrashNodes: [FileNode] = []
    @State private var pendingTrashSourcePath: String?
    /// Snapshot the irreversible action too, so a confirmation cannot act on a
    /// newer collector after a scan or selection change.
    @State private var pendingDeleteNodes: [FileNode] = []
    @State private var pendingDeleteSourcePath: String?
    /// Title for the failure alert ("Move to Trash Failed" / "Delete Failed").
    @State private var deleteErrorTitle = "Couldn’t Remove Items"
    @State private var deleteError: String?
    @State private var appMode: AppMode = .explore

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Sidebar(vm: vm)
                    .frame(width: 238)

                if appMode == .rescue {
                    rescueWorkspace
                } else {
                    exploreWorkspace
                    InspectorView(vm: vm)
                        .frame(width: 278)
                }
            }

            // Full-width collector dock + trash drop-zone, shown once there's a
            // chart to drag from.
            if appMode == .explore, vm.rootNode != nil {
                CollectorDock(vm: vm, drag: drag,
                              onTrashAll: { requestTrash(vm.collector) },
                              onDeleteAll: { requestDelete(vm.collector) })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(minWidth: 980, minHeight: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Flat, solid near-black background — no vibrancy, no desktop refraction,
        // so the app renders identically regardless of what sits behind it.
        .background(Theme.bg.ignoresSafeArea())
        .background(TransparentWindowConfigurator())
        .background(KeyboardShortcuts(vm: vm))
        .tint(Theme.electricBlue)
        .preferredColorScheme(.dark)
        // Shared coordinate space so the chart's drag location and the dock's drop
        // zones are measured against the same origin.
        .coordinateSpace(.named(CollectorDragController.appSpace))
        // Floating chip that follows the cursor mid-drag.
        .overlay {
            if let node = drag.node {
                DragPreview(node: node)
                    .position(drag.location)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if vm.showFDAOnboarding {
                FullDiskAccessOnboarding(vm: vm)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.smooth(duration: 0.3), value: vm.showFDAOnboarding)
        .animation(.smooth(duration: 0.3), value: vm.rootNode != nil)
        // Updates install and relaunch the app on their own — but never mid-scan,
        // and never while the user has files staged in the Cleanup List (a relaunch
        // would throw that list away). While either is true the update is held and
        // applied as soon as the app goes idle.
        .onChange(of: vm.isScanning, initial: true) { _, _ in syncUpdaterBusy() }
        .onChange(of: vm.collector.isEmpty) { _, _ in syncUpdaterBusy() }
        .confirmationDialog(
            "Move \(pendingTrashNodes.count) Item\(pendingTrashNodes.count == 1 ? "" : "s") to Trash?",
            isPresented: $showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash") {
                let nodes = pendingTrashNodes
                pendingTrashNodes = []
                performTrash(nodes)
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                vm.cancelTrashConfirmation()
                pendingTrashNodes = []
            }
        } message: {
            Text("This moves \(Theme.format(pendingTrashNodes.reduce(0) { $0 + $1.physicalSize })) to Finder Trash (\(pendingTrashRiskSummary)). \(pendingTrashTargetSummary) The items can be restored, but Trash still uses disk space until you empty it.")
        }
        .confirmationDialog(
            "Permanently Delete \(pendingDeleteNodes.count) Item\(pendingDeleteNodes.count == 1 ? "" : "s")?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            // Safe option first, so it reads as the default/recommended path.
            Button("Move to Trash Instead") {
                let nodes = pendingDeleteNodes
                pendingDeleteNodes = []
                pendingDeleteSourcePath = nil
                showDeleteAllConfirm = false
                requestTrash(nodes)
            }
            .keyboardShortcut(.defaultAction)
            Button("Delete \(pendingDeleteNodes.count) Item\(pendingDeleteNodes.count == 1 ? "" : "s") Permanently", role: .destructive) {
                performDelete(pendingDeleteNodes)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees \(Theme.format(pendingDeleteNodes.reduce(0) { $0 + $1.physicalSize })) immediately and cannot be undone. To keep the option to restore, move the items to the Trash instead.")
        }
        .alert(deleteErrorTitle, isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .onAppear {
            vm.refreshFullDiskAccessStatus()
            // Expose this window's single VM to the Finder Service provider, and run
            // any scan it requested before the window existed (cold launch).
            SharedScanContext.shared.register(vm)
            DebugAutomation.runIfRequested(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Returning from System Settings after granting access auto-dismisses.
            vm.refreshFullDiskAccessStatus()
        }
        .onChange(of: showTrashConfirm) { _, isPresented in
            if !isPresented {
                vm.cancelTrashConfirmation()
                pendingTrashNodes = []
                pendingTrashSourcePath = nil
            }
        }
        .onChange(of: showDeleteAllConfirm) { _, isPresented in
            if !isPresented {
                pendingDeleteNodes = []
                pendingDeleteSourcePath = nil
            }
        }
        .onChange(of: vm.scannedURL) { _, _ in
            if showTrashConfirm {
                showTrashConfirm = false
                vm.cancelTrashConfirmation()
                pendingTrashNodes = []
                pendingTrashSourcePath = nil
            }
            if showDeleteAllConfirm {
                showDeleteAllConfirm = false
                pendingDeleteNodes = []
                pendingDeleteSourcePath = nil
            }
        }
    }

    private var exploreWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            appHeader
            modeSwitcher
            if vm.rootNode != nil {
                CleanupActionBar(vm: vm, onRescue: {
                    withAnimation(.smooth(duration: 0.25)) {
                        appMode = .rescue
                    }
                })
            }
            centerArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rescueWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            appHeader
            modeSwitcher

            ScrollView(.vertical, showsIndicators: true) {
                CleanupSuggestionsView(vm: vm, onMoveToTrash: {
                    requestTrash(vm.collector)
                })
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            Text("Workspace")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Workspace", selection: $appMode) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer(minLength: 0)
        }
    }

    /// Queue the recoverable action behind its own confirmation.
    private func requestTrash(_ nodes: [FileNode]) {
        guard !nodes.isEmpty, !vm.isScanning,
              let sourcePath = vm.scannedURL?.standardizedFileURL.path else { return }
        pendingTrashNodes = nodes
        pendingTrashSourcePath = sourcePath
        vm.beginTrashConfirmation()
        showTrashConfirm = true
    }

    /// Queue the irreversible action behind a source- and collector-bound
    /// confirmation. It remains a separate legacy action from Rescue's Trash flow.
    private func requestDelete(_ nodes: [FileNode]) {
        guard !nodes.isEmpty, !vm.isScanning,
              let sourcePath = vm.scannedURL?.standardizedFileURL.path else { return }
        pendingDeleteNodes = nodes
        pendingDeleteSourcePath = sourcePath
        showDeleteAllConfirm = true
    }

    /// Move `nodes` to the Trash (recoverable), surfacing any failure as an alert.
    private func performTrash(_ nodes: [FileNode]) {
        deleteError = nil
        defer { pendingTrashSourcePath = nil }
        let currentSourcePath = vm.scannedURL?.standardizedFileURL.path
        let collectorIDs = Set(vm.collector.map(\.id))
        guard !vm.isScanning,
              pendingTrashSourcePath == currentSourcePath,
              Set(nodes.map(\.id)).isSubset(of: collectorIDs) else {
            vm.cancelTrashConfirmation()
            deleteErrorTitle = "Move to Trash Failed"
            deleteError = "The scan or cleanup list changed. Review the current plan before moving anything."
            return
        }
        do {
            try vm.moveToTrash(nodes)
        } catch {
            deleteErrorTitle = "Move to Trash Failed"
            deleteError = error.localizedDescription
        }
    }

    private var pendingTrashRiskSummary: String {
        guard let plan = vm.rescuePlan else { return "review the exact paths" }
        let risks: [(CleanupRisk, String)] = [
            (.safe, "safe"), (.review, "review"), (.protected, "protected")
        ]
        let parts = risks.compactMap { item -> String? in
            let count = pendingTrashNodes.filter { node in
                plan.recommendations.first(where: { $0.node.id == node.id })?.risk == item.0
            }.count
            return count > 0 ? "\(count) \(item.1)" : nil
        }
        return parts.isEmpty ? "review the exact paths" : parts.joined(separator: ", ")
    }

    private var pendingTrashTargetSummary: String {
        guard let plan = vm.rescuePlan, let target = plan.targetSpace else {
            return "No capacity target is available."
        }
        let goal = Int((plan.capacityGoal * 100).rounded())
        return "Target: keep used space below \(goal)% (\(Theme.format(target)) free)."
    }

    /// Permanently delete `nodes`, surfacing any failure as an alert.
    private func performDelete(_ nodes: [FileNode]) {
        deleteError = nil
        defer {
            pendingDeleteNodes = []
            pendingDeleteSourcePath = nil
        }
        let currentSourcePath = vm.scannedURL?.standardizedFileURL.path
        let collectorIDs = Set(vm.collector.map(\.id))
        guard !vm.isScanning,
              pendingDeleteSourcePath == currentSourcePath,
              Set(nodes.map(\.id)).isSubset(of: collectorIDs) else {
            deleteErrorTitle = "Delete Failed"
            deleteError = "The scan or cleanup list changed. Review the current plan before deleting anything."
            return
        }
        do {
            try vm.deletePermanently(nodes)
        } catch {
            deleteErrorTitle = "Delete Failed"
            deleteError = error.localizedDescription
        }
    }

    // MARK: - App header

    private var appHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentSourceTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(currentSourceDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Label(currentStateTitle, systemImage: currentStateSymbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(currentStateColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var currentSourceTitle: String {
        if let root = vm.currentRoot { return root.name }
        if let source = vm.selectedSourceURL, !source.lastPathComponent.isEmpty {
            return source.lastPathComponent
        }
        return "Choose a storage source"
    }

    private var currentSourceDetail: String {
        if let source = vm.scannedURL { return source.standardizedFileURL.path }
        if let source = vm.selectedSourceURL { return source.standardizedFileURL.path }
        return "Select a disk, folder, cloud source, or server from the sidebar."
    }

    private var currentStateTitle: String {
        if vm.isScanning { return "Scanning" }
        if vm.needsFullDiskAccess { return "Access needed" }
        if vm.errorMessage != nil { return "Scan failed" }
        if vm.rootNode != nil { return "Ready" }
        return "Not scanned"
    }

    private var currentStateSymbol: String {
        if vm.isScanning { return "arrow.triangle.2.circlepath" }
        if vm.needsFullDiskAccess { return "lock.shield" }
        if vm.errorMessage != nil { return "exclamationmark.triangle" }
        return vm.rootNode != nil ? "checkmark.circle" : "circle"
    }

    private var currentStateColor: Color {
        if vm.needsFullDiskAccess || vm.errorMessage != nil { return .orange }
        return vm.rootNode != nil ? Theme.electricBlue : .secondary
    }

    // MARK: - Center area

    @ViewBuilder
    private var centerArea: some View {
        ZStack {
            if vm.needsFullDiskAccess {
                centeredCard { fullDiskAccessContent }
            } else if let error = vm.errorMessage {
                centeredCard { errorContent(error) }
            } else if vm.rootNode == nil && vm.isScanning {
                centeredCard { ScanningView(vm: vm) }
            } else if vm.rootNode == nil {
                centeredCard { emptyContent }
            } else {
                chartContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.35), value: vm.rootNode?.id)
        .animation(.smooth(duration: 0.25), value: vm.isScanning)
    }

    // MARK: - Chart + breadcrumb

    @ViewBuilder
    private var chartContent: some View {
        // Give navigation and help their own rows. Overlaying them on the chart
        // made the visible circle collide with controls as the window narrowed.
        VStack(spacing: 8) {
            if let current = vm.currentRoot {
                breadcrumb(for: current)
            }

            SunburstChart(
                root: vm.currentRoot,
                contentRevision: vm.chartRevision,
                hoveredNode: vm.hoveredNode,
                selectedNode: vm.selectedNode,
                onHover: { vm.hoveredNode = $0 },
                onSelect: { vm.selectedNode = $0 },
                onZoomIn: { vm.zoomIn(to: $0) },
                onZoomOut: { vm.zoomOut() },
                onAddToCollector: { vm.addToCollector($0) },
                onRevealInFinder: { node in
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                },
                drag: drag,
                onDrop: { node in vm.addToCollector(node) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            chartHints
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Always-visible, plain-language legend for the chart's three interactions.
    private var chartHints: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                hint("cursorarrow.click", "Click a slice to open it")
                hint("arrow.up.left.circle", "Click the middle to go back")
                hint("arrow.down.to.line", "Drag a slice to review")
            }
            .fixedSize(horizontal: true, vertical: false)

            Label("Click: open · Center: back · Drag: review",
                  systemImage: "cursorarrow.click")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption)
        .foregroundStyle(Theme.mutedForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .padding(.top, 2)
        .allowsHitTesting(false)
    }

    private func hint(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.electricBlue)
            Text(text)
        }
    }

    // MARK: - Centered task card

    private func centeredCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(32)
            .frame(maxWidth: 520)
            .desktopGlassPanel(cornerRadius: 16, shadowRadius: 12, shadowY: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: - Empty state

    private var emptyContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "internaldrive")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
            Text("Make room with confidence")
                .font(.title2.weight(.semibold))
            Text("Choose a source, then scan it here. Tessera maps the drive and builds a safe rescue plan — nothing moves while it measures.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if let source = vm.selectedSourceURL {
                Button {
                    vm.startScan(volumeURL: source)
                } label: {
                    Label("Scan \(source.lastPathComponent.isEmpty ? "this source" : source.lastPathComponent)",
                          systemImage: "lifepreserver.fill")
                }
                .buttonStyle(.flatProminent)
                .controlSize(.large)
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Full Disk Access

    private var fullDiskAccessContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text("Full Disk Access Required")
                    .font(.title2.weight(.semibold))
                Text("Grant Full Disk Access in System Settings, then scan again.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Open System Settings") {
                vm.openFullDiskAccessSettings()
            }
            .buttonStyle(.flatProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Error

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.red)
            VStack(spacing: 8) {
                Text("Scan Failed")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                if vm.canRetryLastScan {
                    Button("Try Again") {
                        vm.errorMessage = nil
                        vm.retryLastScan()
                    }
                    .buttonStyle(.flatProminent)
                    .controlSize(.large)
                }
                Button("Dismiss") {
                    vm.errorMessage = nil
                }
                .buttonStyle(.flat)
                .controlSize(.large)
            }
        }
    }

    /// Hold back a self-relaunch while a scan is running or files are staged.
    private func syncUpdaterBusy() {
        updater.isBusy = vm.isScanning || !vm.collector.isEmpty
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
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: 560)
        .background(Theme.elevated, in: Capsule())
        .liquidGlassDepth(Capsule(), highlight: 0.9, shadowRadius: 16, shadowY: 8)
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

// MARK: - Scanning state

private struct ScanningView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning locally")
                        .font(.title2.weight(.semibold))
                    Text("Tessera is reading the source. Your files are not changed.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if let fraction = vm.progress.fraction {
                ProgressView(value: fraction)
                    .tint(Theme.electricBlue)
                Text("\(Int(fraction * 100))% complete")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: fraction)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            HStack(spacing: 24) {
                counter(value: "\(vm.progress.filesScanned)", label: "Items read")
                counter(value: Theme.format(vm.progress.bytesFound), label: "Mapped")
            }

            Text(vm.progress.currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .cancel) {
                vm.cancelScan()
            } label: {
                Label("Stop scan", systemImage: "stop.fill")
            }
            .buttonStyle(.flat)
            .controlSize(.regular)
        }
        .frame(maxWidth: 440, alignment: .leading)
    }

    private func counter(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.smooth, value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Keyboard shortcuts (hidden helper buttons)

private struct KeyboardShortcuts: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        ZStack {
            Button("Zoom Out") { vm.zoomOut() }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("Clear Selection") { vm.selectedNode = nil }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
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
        ("3.circle.fill", "Return here — scanning unlocks automatically."),
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
                Text("Tessera needs Full Disk Access to measure every folder on your Mac. Grant it once and you're set — no more per-folder prompts.")
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
