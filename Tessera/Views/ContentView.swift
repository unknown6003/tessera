import SwiftUI
import AppKit
import QuickLook

struct ContentView: View {
    private enum CompactPane: String, CaseIterable, Identifiable {
        case items, details
        var id: String { rawValue }
        var title: String { self == .items ? "Items" : "Details" }
    }

    private enum AppMode: String, CaseIterable, Identifiable {
        case explore, rescue
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private struct RemovalSnapshot: Identifiable {
        let id = UUID()
        let nodes: [FileNode]
        let sourcePath: String
        let rootID: ObjectIdentifier?
        let revision: UInt64
        let collectorIDs: Set<ObjectIdentifier>
        /// Rescue shows the capacity goal in the confirmation; Explore does not.
        var startedInRescue = false
        /// Automation only: open the review with its Trash confirmation shown.
        var confirmOnOpen = false
    }

    /// Folders up to this many children build their map on the main actor.
    /// Wider folders sort off the main actor through `vm.readTree`.
    private static let syncMapChildLimit = 5_000
    private static let browserRowHeight: CGFloat = 28
    /// Content width needed to show Details as its own column beside the map
    /// and the browser without shrinking the map.
    private static let detailsColumnMinimumContent: CGFloat = 980
    /// Browser columns narrower than this use two-line rows, so names wrap
    /// instead of truncating.
    private static let twoLineColumnWidth: CGFloat = 290

    @StateObject private var vm = ScanViewModel(defaults: DebugAutomation.defaults)
    @StateObject private var drag = CollectorDragController()
    @EnvironmentObject private var updater: UpdaterController
    @ObservedObject private var analytics = Analytics.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var appMode: AppMode = .explore
    @State private var showSidebar = true
    @State private var showInspector = false
    @State private var windowWidth: CGFloat = 1240
    /// Narrow windows share the right column between the browser and Details.
    @State private var compactPane: CompactPane = .items
    @FocusState private var browserFocused: Bool
    /// The folder on screen, shared by the map, the child browser and Details.
    @State private var map: MapSnapshot?
    @State private var mapTask: Task<Void, Never>?
    @State private var quickLookURL: URL?
    /// Closes Quick Look on a second ⌘Y. The preview panel becomes the key
    /// window, so the window's own ⌘Y button never sees that key press.
    @State private var quickLookKeyMonitor: Any?
    /// Display names from the source list ("iCloud Drive", not the folder's
    /// on-disk name). Filled by `Sidebar`; no metadata read happens here.
    @State private var sourceNames: [URL: String] = [:]
    @State private var queuedReviewAction: RemovalSnapshot?
    @State private var queuedReviewIsPermanent = false
    @State private var reviewSnapshot: RemovalSnapshot?
    @State private var removalRequested = false
    @State private var deleteErrorTitle = "Could not remove items"
    @State private var deleteError: String?

    private var removalBusy: Bool { vm.isDeleting || removalRequested }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Sidebar(vm: vm, sourceNames: $sourceNames)
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
                            if detailsBeside {
                                Divider()
                                InspectorView(vm: vm, mapColor: mapColor)
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
            // The onboarding card is modal: nothing behind it takes focus or
            // reaches VoiceOver while it shows.
            .disabled(vm.showFDAOnboarding)
            .accessibilityHidden(vm.showFDAOnboarding)
        }
        .frame(minWidth: 820, minHeight: 600)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .background(Theme.bg.ignoresSafeArea())
        .background(TransparentWindowConfigurator())
        .background(KeyboardShortcuts(vm: vm, onQuickLook: quickLook)
            .disabled(removalBusy || vm.isScanning || vm.showFDAOnboarding))
        .tint(Theme.electricBlue)
        .preferredColorScheme(.dark)
        .coordinateSpace(.named(CollectorDragController.appSpace))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { showSidebar.toggle() } label: {
                    Label("Sources", systemImage: "sidebar.left")
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .help(showSidebar ? "Hide sources (⌃⌘S)" : "Show sources (⌃⌘S)")
                .disabled(vm.showFDAOnboarding)
            }
            ToolbarItem(placement: .principal) {
                Picker("Workspace", selection: $appMode) {
                    ForEach(AppMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                .disabled(vm.showFDAOnboarding)
            }
            ToolbarItem(placement: .primaryAction) {
                CleanupActionBar(vm: vm, returnScreen: modeScreen, onRescue: { appMode = .rescue })
                    .disabled(removalBusy || vm.isScanning || vm.rootNode == nil || vm.showFDAOnboarding)
            }
            ToolbarItem(placement: .primaryAction) {
                // Wide windows show Details beside the map; narrow windows
                // show it inline below the map. No popover.
                Button {
                    showInspector.toggle()
                    if showInspector { compactPane = .details }
                } label: {
                    Label("Details", systemImage: "sidebar.right")
                }
                .keyboardShortcut("i", modifiers: [.command, .control])
                .help("Show or hide selected item details (⌃⌘I)")
                .disabled(appMode != .explore || vm.showFDAOnboarding)
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
        .onChange(of: vm.currentRoot?.id, initial: true) { _, _ in refreshMap() }
        .onChange(of: vm.treeRevision) { _, _ in refreshMap() }
        // A read refused during a removal runs again when the removal ends.
        .onChange(of: vm.isDeleting) { _, deleting in if !deleting { refreshMap() } }
        .quickLookPreview($quickLookURL)
        .onAppear(perform: installQuickLookKeyMonitor)
        .onDisappear {
            if let monitor = quickLookKeyMonitor { NSEvent.removeMonitor(monitor) }
            quickLookKeyMonitor = nil
        }
        // Analytics: fixed screen names and counts only. No names or paths.
        .onChange(of: appMode, initial: true) { _, _ in
            if reviewSnapshot == nil { recordScreen(modeScreen) }
        }
        .onChange(of: reviewSnapshot?.id) { _, id in
            if let id, let snapshot = reviewSnapshot, snapshot.id == id {
                recordScreen(.review)
                analytics.capture(.cleanupReviewOpened, values: ["items": .integer(snapshot.nodes.count)])
            } else if id == nil {
                recordScreen(modeScreen)
            }
        }
        .onChange(of: vm.showFDAOnboarding, initial: true) { _, shown in
            if shown { analytics.capture(.permissionPrompted) }
        }
        .onChange(of: removalRequested) { _, _ in syncUpdaterBusy() }
        .onChange(of: vm.collector.isEmpty) { _, _ in syncUpdaterBusy() }
        .sheet(item: $reviewSnapshot, onDismiss: finishReview) { snapshot in
            CleanupReviewSheet(vm: vm, nodes: snapshot.nodes, sourcePath: snapshot.sourcePath,
                                   rootID: snapshot.rootID, revision: snapshot.revision,
                                   startedInRescue: snapshot.startedInRescue,
                                   confirmOnOpen: snapshot.confirmOnOpen,
                                   onTrash: { nodes in
                                       queueReviewAction(nodes, permanent: false)
                                   }, onDelete: { nodes in
                                       queueReviewAction(nodes, permanent: true)
                                   })
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
        .onReceive(NotificationCenter.default.publisher(for: .init("Tessera.captureState"))) { note in
            guard ProcessInfo.processInfo.environment["SO_CAPTURE_VARIANTS"] == "1",
                  let source = vm.scannedURL,
                  source.resolvingSymlinksInPath().path.contains("/tmp/tessera-"),
                  let state = note.userInfo?["state"] as? String else { return }
            reviewSnapshot = nil
            showInspector = state == "details"
            if state == "details" { compactPane = .details }
            if state == "details" { vm.selectedNode = vm.rootNode?.largestChildren(limit: 1).first }
            appMode = state == "rescue" ? .rescue : .explore
            if state == "review" || state == "confirm" {
                for node in vm.rootNode?.largestChildren(limit: 3) ?? [] { vm.addToCollector(node) }
                if state == "review" { openReview() }
                else if var snapshot = self.snapshot(vm.collector) {
                    snapshot.confirmOnOpen = true
                    reviewSnapshot = snapshot
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            DebugAutomation.cleanPreferences()
        }
        .onChange(of: vm.isScanning) { _, scanning in
            if scanning {
                reviewSnapshot = nil
                drag.reset()
            }
        }
    }

    private var sourceHeader: some View {
        HStack(spacing: 12) {
            // Name and status only. The full path of the selection lives in the
            // inspector, so one state never repeats the same path.
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.rootNode == nil ? sourceName : displayName(for: vm.scannedURL, fallback: vm.rootNode?.name))
                    .font(.headline)
                    .lineLimit(1)
                    .help(vm.scannedURL?.path ?? vm.selectedSourceURL?.path ?? "")
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if removalBusy {
                ProgressView().controlSize(.small)
                Text("Removing \(vm.deletionProgress) of \(vm.deletionTotal)")
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel("Removal progress")
            } else if !vm.isScanning {
                Button {
                    if let source = vm.selectedSourceURL { vm.startScan(volumeURL: source) }
                } label: {
                    // Short, fixed labels. The source name is in the title,
                    // the subtitle and the sidebar, not in the button.
                    Label(scanButtonTitle, systemImage: "arrow.clockwise")
                }
                .disabled(vm.selectedSourceURL == nil)
                .buttonStyle(.flat)
                .controlSize(.small)
                .keyboardShortcut("r", modifiers: .command)
                .help(showsOtherSource ? "Scan \(sourceName) (⌘R)" : "Scan this source again (⌘R)")
                .accessibilityHint(showsOtherSource ? "Scans \(sourceName)" : "Scans \(sourceName) again")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    /// The sidebar selection differs from the scan on screen.
    private var showsOtherSource: Bool {
        vm.rootNode != nil && vm.scannedURL != nil && vm.selectedSourceURL != vm.scannedURL
    }

    private var headerSubtitle: String {
        if vm.rootNode == nil {
            return vm.selectedSourceURL == nil ? "Choose a source to begin" : "Not scanned yet"
        }
        if showsOtherSource {
            return "\(sourceName) is selected and not scanned yet."
        }
        return vm.scanStatus.isEmpty ? "Scan complete" : vm.scanStatus
    }

    private var scanButtonTitle: String {
        if vm.rootNode == nil { return "Scan" }
        return showsOtherSource ? "Scan Selected Source" : "Rescan"
    }

    /// The selected source's name, as the source list shows it.
    private var sourceName: String {
        guard vm.selectedSourceURL != nil else { return "Tessera" }
        return displayName(for: vm.selectedSourceURL, fallback: nil)
    }

    private func displayName(for url: URL?, fallback: String?) -> String {
        guard let url else { return fallback ?? "Tessera" }
        if let name = sourceNames[url] ?? sourceNames[url.standardizedFileURL] { return name }
        if let fallback { return fallback }
        return url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
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
                    let column = min(320, max(230, geometry.size.width * 0.36))
                    HStack(spacing: 16) {
                        chart
                        rightColumn(twoLine: column < Self.twoLineColumnWidth)
                            .frame(width: column)
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 8) {
                        chart
                        rightColumn(twoLine: false)
                            .frame(height: stackedBrowserHeight(available: geometry.size.height))
                            .padding(.horizontal, 20)
                    }
                }
            }
            if !showInspector { selectedItemBar }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Details gets its own column only when the map keeps its size.
    private var detailsBeside: Bool {
        showInspector && windowWidth - (showSidebar ? 211 : 0) >= Self.detailsColumnMinimumContent
    }

    /// The browser, or in narrow windows the browser and Details behind one
    /// switch. Details never takes height from the map.
    @ViewBuilder private func rightColumn(twoLine: Bool) -> some View {
        if showInspector && !detailsBeside {
            VStack(spacing: 8) {
                Picker("Show", selection: $compactPane) {
                    ForEach(CompactPane.allCases) { pane in Text(pane.title).tag(pane) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Right column")
                if compactPane == .details {
                    InspectorView(vm: vm, mapColor: mapColor)
                } else {
                    childBrowser(twoLine: twoLine)
                }
            }
        } else {
            childBrowser(twoLine: twoLine)
        }
    }

    /// Presentation-only flag: the stacked browser shows 4 or 8 rows before it
    /// scrolls, and never more than 40 % of the height. It never changes
    /// scanning, order or cleanup protection.
    private func stackedBrowserHeight(available: CGFloat) -> CGFloat {
        let rows = CGFloat(analytics.compactLegend ? 4 : 8) * Self.browserRowHeight + 28
        return min(rows, max(120, available * 0.4))
    }

    private var chart: some View {
        SunburstChart(map: map,
                      hoveredNode: vm.hoveredNode, selectedNode: vm.selectedNode,
                      onHover: { vm.hoveredNode = $0 }, onSelect: { vm.selectedNode = $0 },
                      onZoomIn: { vm.zoomIn(to: $0) }, onZoomOut: { vm.zoomOut() },
                      onAddToCollector: { if !removalBusy { vm.addToCollector($0) } },
                      onRevealInFinder: { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) },
                      onQuickLook: quickLook,
                      drag: drag, onDrop: { if !removalBusy { vm.addToCollector($0) } })
            .disabled(removalBusy)
    }

    private var modeScreen: AnalyticsScreen { appMode == .rescue ? .rescue : .explore }

    /// `start` is idempotent. Calling it here keeps the first screen event
    /// even when the window appears before the app delegate starts analytics.
    private func recordScreen(_ screen: AnalyticsScreen) {
        analytics.start()
        analytics.screen(screen)
    }

    private var highContrast: Bool { contrast == .increased }

    /// The map's colour for any node, including deep selections.
    private func mapColor(_ node: FileNode) -> Color? {
        map?.color(for: node, highContrast: highContrast)
    }

    private var mapIsStale: Bool {
        guard let current = vm.currentRoot else { return false }
        return map?.folder.id != current.id || map?.revision != vm.treeRevision
    }

    /// Build the map for the folder on screen once per folder and revision.
    /// Wide folders sort off the main actor on a pinned tree; the result is
    /// dropped if the source, folder or revision changed meanwhile.
    private func refreshMap() {
        guard let folder = vm.currentRoot else {
            mapTask?.cancel()
            mapTask = nil
            map = nil
            return
        }
        let revision = vm.treeRevision
        if let map, map.folder.id == folder.id, map.revision == revision { return }
        mapTask?.cancel()
        mapTask = nil
        if folder.children.count <= Self.syncMapChildLimit {
            map = MapSnapshot.build(folder: folder, revision: revision)
            return
        }
        mapTask = Task { @MainActor in
            guard vm.currentRoot?.id == folder.id, vm.treeRevision == revision else { return }
            let built = await vm.readTree { _, cancellation in
                MapSnapshot.build(folder: folder, revision: revision, cancellation: cancellation)
            }
            guard !Task.isCancelled, let built = built ?? nil,
                  vm.currentRoot?.id == folder.id, vm.treeRevision == revision else { return }
            map = built
        }
    }

    /// Local monitor: sees key presses in every Tessera window, including the
    /// Quick Look panel. It acts only on ⌘Y while a preview is open; every
    /// other event passes through unchanged.
    ///
    /// AppKit declares the handler as a plain `@escaping (NSEvent) -> NSEvent?`
    /// and calls it only for events sent through the app's own event loop, on
    /// the main thread. `MainActor.assumeIsolated` states that contract for
    /// Swift 6 and traps if it is ever broken. The decision stays synchronous,
    /// because the handler must return the event or nil at once.
    private func installQuickLookKeyMonitor() {
        guard quickLookKeyMonitor == nil else { return }
        quickLookKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isCommandY = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
                && event.charactersIgnoringModifiers?.lowercased() == "y"
            guard isCommandY else { return event }
            let closed = MainActor.assumeIsolated { () -> Bool in
                guard quickLookURL != nil else { return false }
                quickLookURL = nil
                return true
            }
            return closed ? nil : event
        }
    }

    private func quickLook(_ node: FileNode) {
        guard !node.isSynthetic else { return }
        quickLookURL = quickLookURL == nil ? node.url : nil
    }

    // MARK: - Child browser

    /// Every child of the folder on screen, in map order. A lazy SwiftUI
    /// stack, not an AppKit table: it takes keyboard focus on click, draws
    /// its own focus ring, and stays below sheets. ↑↓ move, Home and End jump,
    /// Page Up and Down move 10 rows, Return or double-click opens a folder,
    /// Space shows Quick Look, Escape clears the selection.
    private func childBrowser(twoLine: Bool) -> some View {
        let children = map?.children ?? []
        let total = Double(max(1, map?.folder.size ?? 1))
        let selectedID = vm.selectedNode?.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("In this folder").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                if mapIsStale {
                    ProgressView().controlSize(.mini).accessibilityHidden(true)
                    Text("Sorting…").font(.caption).foregroundStyle(Theme.mutedForeground)
                } else {
                    Text(Theme.itemCount(children.count)).font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(children) { node in
                            browserRow(node, total: total, twoLine: twoLine,
                                       selected: node.id == selectedID)
                                .id(node.id)
                                .contentShape(Rectangle())
                                .onTapGesture { browserClick(node) }
                                .contextMenu { browserMenu(node) }
                        }
                    }
                    .padding(4)
                }
                // Keep the selection visible, whether it came from the map,
                // the keyboard or Details.
                .onChange(of: vm.selectedNode?.id) { _, id in
                    guard let id, map?.child(id) != nil else { return }
                    proxy.scrollTo(id)
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.electricBlue, lineWidth: 2)
                    .opacity(browserFocused ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .focusable(!removalBusy)
            .focused($browserFocused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.upArrow, .downArrow, .home, .end, .pageUp, .pageDown, .return, .space]) { press in
                guard !removalBusy, press.modifiers.isDisjoint(with: [.command, .option, .control]) else {
                    return .ignored
                }
                return handleBrowserKey(press.key) ? .handled : .ignored
            }
            .onExitCommand { if !removalBusy { vm.selectedNode = nil } }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Items in \(map?.folder.name ?? "this folder")")
        }
        .disabled(removalBusy)
    }

    /// Click 1 selects and focuses the browser at once. Click 2 opens a folder.
    private func browserClick(_ node: FileNode) {
        guard !removalBusy else { return }
        browserFocused = true
        let clicks = NSApp.currentEvent?.clickCount ?? 1
        if clicks == 2 {
            if node.isDirectory && !node.isSynthetic { vm.zoomIn(to: node) }
        } else if clicks == 1 {
            vm.selectedNode = node
        }
    }

    private func handleBrowserKey(_ key: KeyEquivalent) -> Bool {
        guard let map, !map.children.isEmpty else { return false }
        let children = map.children
        let index = vm.selectedNode.flatMap { node in map.childIndexOf(node.id) }
        func select(_ i: Int) { vm.selectedNode = children[min(children.count - 1, max(0, i))] }
        switch key {
        case .downArrow: select(index.map { $0 + 1 } ?? 0)
        case .upArrow: select(index.map { $0 - 1 } ?? children.count - 1)
        case .home: select(0)
        case .end: select(children.count - 1)
        case .pageDown: select((index ?? -1) + 10)
        case .pageUp: select((index ?? children.count) - 10)
        case .return:
            guard let index else { return false }
            let node = children[index]
            if node.isDirectory && !node.isSynthetic { vm.zoomIn(to: node) }
        case .space:
            guard let index else { return false }
            quickLook(children[index])
        default:
            return false
        }
        return true
    }

    private func browserRow(_ node: FileNode, total: Double, twoLine: Bool, selected: Bool) -> some View {
        let share = Double(node.size) / total * 100
        let percent = share > 0 && share < 1 ? "<1%" : "\(Int(share.rounded()))%"
        let opens = node.isDirectory && !node.isSynthetic
        let color = map?.color(for: node, highContrast: highContrast)
            ?? Theme.wedgeColor(palette: nil, depth: 0, highContrast: highContrast)
        let dot = Circle().fill(color).frame(width: 8, height: 8)
            .overlay(Circle().strokeBorder(highContrast ? Theme.foreground.opacity(0.6) : .clear, lineWidth: 1))
        let chevron = Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.mutedForeground)
            .opacity(opens ? 1 : 0)
        return Group {
            if twoLine {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    dot
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.name).lineLimit(2).truncationMode(.middle)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Theme.format(node.size)) · \(percent)").font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.mutedForeground)
                    }
                    Spacer(minLength: 0)
                    chevron
                }
            } else {
                HStack(spacing: 8) {
                    dot
                    Text(node.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(percent).monospacedDigit().foregroundStyle(Theme.mutedForeground)
                    Text(Theme.format(node.size)).monospacedDigit().fixedSize()
                    chevron
                }
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, twoLine ? 5 : 0)
        .frame(minHeight: Self.browserRowHeight)
        .background(selected ? Theme.selectionTint : .clear, in: RoundedRectangle(cornerRadius: 6))
        .help(node.name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.name), \(Theme.format(node.size)), \(percent) of this folder\(opens ? ", folder" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { vm.selectedNode = node }
        .accessibilityAction(named: "Open") { if opens { vm.zoomIn(to: node) } }
        .accessibilityAction(named: "Quick Look") { quickLook(node) }
    }

    @ViewBuilder private func browserMenu(_ node: FileNode) -> some View {
        if node.isSynthetic {
            Text("This item describes space, not a removable file.").disabled(true)
        } else {
            if node.isDirectory { Button("Open Folder") { vm.zoomIn(to: node) } }
            Button("Quick Look") { quickLook(node) }
            Button("Add to Cleanup List") { vm.addToCollector(node) }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
        }
    }

    /// Compact selection actions for when Details is hidden. Name and
    /// size only; the full path stays in Details.
    private var selectedItemBar: some View {
        HStack(spacing: 10) {
            if let node = vm.selectedNode {
                Text(node.name).font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                Text(Theme.format(node.size)).font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.mutedForeground)
                Spacer(minLength: 8)
                if !node.isSynthetic {
                    if node.isDirectory {
                        Button("Open") { vm.zoomIn(to: node) }
                            .help("Open this folder on the map (⌘↓)")
                    }
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
                    if vm.isCollected(node) {
                        Label("In Cleanup List", systemImage: "checkmark")
                            .font(.callout).foregroundStyle(Theme.mutedForeground)
                    } else {
                        Button("Add to Cleanup List") { vm.addToCollector(node) }
                            .help("Add to Cleanup List (⌘⌫)")
                    }
                }
            } else {
                Text("Select an item for actions. Double-click a folder to open it.")
                    .font(.caption).foregroundStyle(Theme.mutedForeground)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
        .buttonStyle(.flat)
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
                    Text(sourceName).font(.headline)
                    Text(source.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.middle)
                    Button { vm.startScan(volumeURL: source) } label: {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                    .accessibilityHint("Scans \(sourceName)")
                    .buttonStyle(.flatProminent).controlSize(.large)
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
            Button("Open System Settings") { vm.openFullDiskAccessSettings() }.buttonStyle(.flatProminent)
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Scan failed", systemImage: "exclamationmark.triangle").font(.title2)
            Text(message).foregroundStyle(.secondary).textSelection(.enabled)
            if vm.canRetryLastScan {
                Button("Try again") { vm.errorMessage = nil; vm.retryLastScan() }
                    .buttonStyle(.flatProminent).disabled(removalBusy)
            }
            Button("Dismiss") { vm.errorMessage = nil }
        }
    }

    private func openReview() {
        guard !vm.isScanning, !removalBusy, let snapshot = snapshot(vm.collector) else { return }
        reviewSnapshot = snapshot
    }

    private func snapshot(_ nodes: [FileNode]) -> RemovalSnapshot? {
        guard !nodes.isEmpty, let path = vm.scannedURL?.standardizedFileURL.path else { return nil }
        return RemovalSnapshot(nodes: nodes, sourcePath: path, rootID: vm.rootNode?.id,
                               revision: vm.chartRevision, collectorIDs: Set(vm.collector.map(\.id)),
                               startedInRescue: appMode == .rescue)
    }

    private func queueReviewAction(_ nodes: [FileNode], permanent: Bool) {
        guard let review = reviewSnapshot, !nodes.isEmpty else { return }
        queuedReviewAction = RemovalSnapshot(nodes: nodes, sourcePath: review.sourcePath,
                                            rootID: review.rootID, revision: review.revision,
                                            collectorIDs: Set(nodes.map(\.id)),
                                            startedInRescue: review.startedInRescue)
        queuedReviewIsPermanent = permanent
        reviewSnapshot = nil
    }

    private func finishReview() {
        guard let snapshot = queuedReviewAction else { return }
        queuedReviewAction = nil
        // The user already confirmed inside the review sheet. Check the
        // snapshot again before acting; perform* checks it once more after the
        // async hop.
        guard !removalBusy, snapshotIsCurrent(snapshot) else {
            vm.cancelTrashConfirmation()
            deleteErrorTitle = "Review needed"
            deleteError = "The scan or Cleanup List changed. Open the list and review it again."
            return
        }
        if queuedReviewIsPermanent { performDelete(snapshot) }
        else { performTrash(snapshot) }
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
        .help("Go to the top of this scan")
        .accessibilityLabel("Top of scan")
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
    let onQuickLook: (FileNode) -> Void
    var body: some View {
        ZStack {
            // Finder-style keys. Escape is not bound here: the map and list
            // handle it with onExitCommand, so text fields and dialogs keep it.
            Button("Zoom Out") { vm.zoomOut() }.keyboardShortcut(.upArrow, modifiers: .command)
            Button("Open") {
                if let node = vm.selectedNode, node.isDirectory, !node.isSynthetic, node.id != vm.currentRoot?.id {
                    vm.zoomIn(to: node)
                }
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            Button("Add to Cleanup List") {
                if let node = vm.selectedNode, !node.isSynthetic { vm.addToCollector(node) }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            Button("Quick Look") {
                if let node = vm.selectedNode, !node.isSynthetic { onQuickLook(node) }
            }
            .keyboardShortcut("y", modifiers: .command)
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
                    Analytics.shared.capture(.permissionDismissed)
                    vm.dismissFDAOnboarding()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.flat)
                .controlSize(.large)
            }
        }
        .padding(28)
        .background(Theme.elevated, in: shape)
        .liquidGlassDepth(shape, shadowRadius: 40, shadowY: 22)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
