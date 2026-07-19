import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var vm = ScanViewModel()
    /// Drives drag-and-drop of chart wedges into the bottom dock.
    @StateObject private var drag = CollectorDragController()
    /// Auto-updater. We only talk to it to say "don't relaunch right now".
    @EnvironmentObject private var updater: UpdaterController

    /// Whether the "permanently delete the whole collector" confirmation is showing.
    @State private var showDeleteAllConfirm = false
    /// Title for the failure alert ("Move to Trash Failed" / "Delete Failed").
    @State private var deleteErrorTitle = "Couldn’t Remove Items"
    @State private var deleteError: String?

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                Sidebar(vm: vm)
                    .frame(width: 252)

                VStack(spacing: 12) {
                    if vm.rootNode != nil {
                        CleanupActionBar(vm: vm)
                    }
                    centerArea
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                InspectorView(vm: vm)
                    .frame(width: 296)
            }

            // Full-width collector dock + trash drop-zone, shown once there's a
            // chart to drag from.
            if vm.rootNode != nil {
                CollectorDock(vm: vm, drag: drag,
                              onTrashAll: { performTrash(vm.collector) },
                              onDeleteAll: { showDeleteAllConfirm = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(minWidth: 920, minHeight: 600)
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
            "Permanently Delete \(vm.collector.count) Item\(vm.collector.count == 1 ? "" : "s")?",
            isPresented: $showDeleteAllConfirm,
            titleVisibility: .visible
        ) {
            // Safe option first, so it reads as the default/recommended path.
            Button("Move to Trash Instead") {
                performTrash(vm.collector)
            }
            .keyboardShortcut(.defaultAction)
            Button("Delete \(vm.collector.count) Item\(vm.collector.count == 1 ? "" : "s") Permanently", role: .destructive) {
                performDelete(vm.collector)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees \(Theme.format(vm.collectorTotalSize)) immediately and cannot be undone. To keep the option to restore, move the items to the Trash instead.")
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
    }

    /// Move `nodes` to the Trash (recoverable), surfacing any failure as an alert.
    /// The default action — no confirmation needed since it can be undone in Finder.
    private func performTrash(_ nodes: [FileNode]) {
        deleteError = nil
        do {
            try vm.moveToTrash(nodes)
        } catch {
            deleteErrorTitle = "Move to Trash Failed"
            deleteError = error.localizedDescription
        }
    }

    /// Permanently delete `nodes`, surfacing any failure as an alert.
    private func performDelete(_ nodes: [FileNode]) {
        deleteError = nil
        do {
            try vm.deletePermanently(nodes)
        } catch {
            deleteErrorTitle = "Delete Failed"
            deleteError = error.localizedDescription
        }
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
                hint("arrow.down.to.line", "Drag a slice to the list below to remove it")
            }
            .fixedSize(horizontal: true, vertical: false)

            Label("Click: open · Center: back · Drag: add to Cleanup List",
                  systemImage: "cursorarrow.click")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption)
        .foregroundStyle(Theme.mutedForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        .allowsHitTesting(false)
    }

    private func hint(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.electricBlue)
            Text(text)
        }
    }

    // MARK: - Glass card wrapper

    private func centeredCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(40)
            .frame(maxWidth: 460)
            // Behind-window glass so the empty / scanning / error cards refract the
            // desktop instead of refracting nothing over the transparent window.
            .desktopGlassPanel(cornerRadius: 28, shadowRadius: 34, shadowY: 18)
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
                Text("See what's using your disk")
                    .font(.title2.weight(.semibold))
                Text("Pick a disk in the list on the left, then click the blue **Scan** button at the bottom of that list. Tessera reads the whole drive and maps it — nothing is changed or deleted.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                if let url = vm.scannedURL {
                    Button("Try Again") {
                        vm.errorMessage = nil
                        vm.startScan(volumeURL: url)
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
                        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
        vm.currentRoot = node
        vm.selectedNode = node
        vm.hoveredNode = nil
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
        VStack(spacing: 24) {
            PulsingRings()
                .frame(width: 140, height: 140)

            VStack(spacing: 6) {
                Text("Scanning…")
                    .font(.title2.weight(.semibold))
                if let fraction = vm.progress.fraction {
                    Text("\(Int(fraction * 100))%")
                        .font(.system(.largeTitle, design: .rounded).weight(.medium).monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.smooth, value: fraction)
                }
            }

            HStack(spacing: 28) {
                counter(value: "\(vm.progress.filesScanned)", label: "Files")
                counter(value: Theme.format(vm.progress.bytesFound), label: "Found")
            }

            Text(vm.progress.currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 360)

            Button(role: .cancel) {
                vm.cancelScan()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.flat)
            .controlSize(.large)
        }
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

// MARK: - Pulsing concentric rings

/// Flat indeterminate scan indicator: a hairline track with a single accent arc
/// sweeping around it, and a solid hub. No gradients, glows, or glass.
private struct PulsingRings: View {
    var body: some View {
        ZStack {
            // Static hairline track.
            Circle()
                .strokeBorder(Theme.border, lineWidth: 3)

            // One accent arc, rotating steadily — clearly "working", never "stuck".
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let angle = Angle(degrees: (t * 110).truncatingRemainder(dividingBy: 360))
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(Theme.electricBlue,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(angle)
                    .padding(1.5)
            }

            // Solid hub.
            Circle()
                .fill(Theme.card)
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                .overlay(
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.electricBlue)
                )
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
/// dims the window behind a glass card and auto-dismisses the moment access is
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
                .padding(40)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.18))
                    .frame(width: 96, height: 96)
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
        .padding(40)
        .background(Theme.elevated, in: shape)
        .liquidGlassDepth(shape, shadowRadius: 40, shadowY: 22)
    }
}
