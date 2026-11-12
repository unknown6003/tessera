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

    /// A map builds on the main actor only when the layout can visit at most
    /// this many children in total, across all five rings. Otherwise it
    /// builds off the main actor through `vm.readTree`. The check itself
    /// stops after this many children (`SunburstChart.layoutWork`).
    private static let syncMapWorkLimit = 5_000
    /// Fixed row pitch. Every row has exactly this height, so a row's offset
    /// is `index × height` and no row needs to be measured or created to
    /// scroll to it.
    private static let browserRowHeight: CGFloat = 28
    private static let browserTwoLineRowHeight: CGFloat = 58
    /// Content width needed to show Details as its own column beside the map
    /// and the browser without shrinking the map.
    private static let detailsColumnMinimumContent: CGFloat = 980
    /// Browser columns narrower than this use two-line rows, so names wrap
    /// instead of truncating.
    private static let twoLineColumnWidth: CGFloat = 290
    /// Flag-gated compact pitch for single-line browser rows (`tessera-
    /// compact-legend`, variant `compact`). 24 pt fits one callout line with
    /// the existing paddings, keeps keyboard targets clear of each other and
    /// leaves the two-line pitch untouched. Presentation only.
    private static let compactRowHeight: CGFloat = 24

    @StateObject private var vm: ScanViewModel
    @StateObject private var rescueWorkspaceModel: RescueWorkspaceModel
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
    /// Set by the first selection in this window; hides the selection hint.
    @State private var hasSelectedOnce = false
    /// Set when the browser had keyboard focus right before a Details toggle,
    /// a pane switch, a sidebar toggle or a resize rebuilt it. The rebuilt
    /// browser takes focus back once, in `onAppear`.
    @State private var refocusBrowserOnAppear = false
    /// Set when Details replaced a focused browser in the narrow switch.
    /// Returning to Items, or hiding Details, gives the browser focus back.
    @State private var browserFocusBeforeDetails = false
    /// This view's own window, reported by `TransparentWindowConfigurator`.
    /// A reference box, so setting it never re-renders the view.
    @State private var ownWindow = WindowReference()

    private final class WindowReference {
        weak var window: NSWindow?
    }
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
    @State private var trashFinishReview: ScanViewModel.TrashFinishReview?
    @State private var reviewSnapshot: RemovalSnapshot?
    @State private var removalRequested = false
    @State private var deleteErrorTitle = "Could not remove items"
    @State private var deleteError: String?

    init() {
        let model = ScanViewModel(defaults: DebugAutomation.defaults)
        _vm = StateObject(wrappedValue: model)
        _rescueWorkspaceModel = StateObject(wrappedValue: RescueWorkspaceModel(vm: model, defaults: DebugAutomation.defaults))
    }

    private var removalBusy: Bool { vm.isDeleting || removalRequested }
    /// The Cleanup List dock is on screen.
    private var dockIsVisible: Bool {
        vm.rootNode != nil || removalBusy || vm.lastRemovalSummary != nil || vm.hasTrackedTrash
    }

    // The body is split into stages so each modifier chain type-checks on
    // its own (Swift 6 timed out on one long chain). The stages nest in the
    // original modifier order, so handler order and behaviour are unchanged.
    var body: some View {
        withLifecycle(withPresentation(withAnalyticsHandlers(withStateHandlers(withWindowChrome(windowLayout)))))
    }

    private var windowLayout: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Sidebar(vm: vm, sourceNames: $sourceNames, onKeyboardFocus: dropBrowserFocusIntent)
                    .frame(width: showSidebar ? 210 : 0)
                    .clipped()
                    .opacity(showSidebar ? 1 : 0)
                    .accessibilityHidden(!showSidebar)
                    .disabled(removalBusy || !showSidebar)
                if showSidebar { Divider() }

                VStack(spacing: 0) {
                    sourceHeader
                    if vm.isScanning && !(appMode == .rescue && vm.hasRescueResultsForSelectedSource) {
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
                    if dockIsVisible {
                        Divider()
                        CollectorDock(vm: vm, drag: drag, onReview: openReview, onFinishTrash: openTrashFinish)
                            .disabled(removalBusy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusSection()
            }
            // The onboarding card is modal: nothing behind it takes focus or
            // reaches VoiceOver while it shows.
            .disabled(vm.showFDAOnboarding)
            .accessibilityHidden(vm.showFDAOnboarding)
        }
    }

    private func withWindowChrome(_ content: some View) -> some View {
        content
            .frame(minWidth: 820, minHeight: 600)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                changeBrowserHost { windowWidth = width }
            }
            .background(Theme.bg.ignoresSafeArea())
            .background(TransparentWindowConfigurator(onWindow: { ownWindow.window = $0 }))
            .background(KeyboardShortcuts(vm: vm, onQuickLook: quickLook)
                .disabled(removalBusy || vm.isScanning || vm.showFDAOnboarding))
            .tint(Theme.electricBlue)
            .preferredColorScheme(.dark)
            .coordinateSpace(.named(CollectorDragController.appSpace))
            .toolbar { toolbarItems }
            // One continuous plane under the bar. macOS 26 draws the window
            // toolbar with Liquid Glass by default; here it paints the same
            // near-black as the window and always shows that background, so
            // nothing frosted separates the bar from the header and content.
            .toolbarBackground(Theme.bg, for: .windowToolbar)
            .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
            .overlay {
                if let node = drag.node {
                    DragPreview(node: node).position(drag.location).allowsHitTesting(false)
                }
            }
            .overlay {
                if vm.showFDAOnboarding { FullDiskAccessOnboarding(vm: vm) }
            }
            .transaction { if reduceMotion { $0.animation = nil } }
    }

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            // In an HStack so the toolbar keeps the Tessera style and its
            // cyan focus ring; a bare toolbar button gets the system ring.
            HStack(spacing: 0) {
                Button { changeBrowserHost { showSidebar.toggle() } } label: {
                    Label("Sources", systemImage: "sidebar.left")
                }
                .toolbarIconButton()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .help(showSidebar ? "Hide sources (⌃⌘S)" : "Show sources (⌃⌘S)")
            .disabled(vm.showFDAOnboarding)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .principal) {
            WorkspaceSwitch(
                label: "Workspace",
                titles: AppMode.allCases.map(\.title),
                selection: Binding(
                    get: { AppMode.allCases.firstIndex(of: appMode) ?? 0 },
                    set: { appMode = AppMode.allCases[$0] }))
            .frame(width: 190, height: 36)
            .disabled(vm.showFDAOnboarding)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) {
            CleanupActionBar(vm: vm, returnScreen: modeScreen, onRescue: { appMode = .rescue })
                .disabled(removalBusy || vm.isScanning || vm.rootNode == nil || vm.showFDAOnboarding)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) {
            // Wide windows show Details beside the map; narrow windows
            // show it inline below the map. No popover.
            HStack(spacing: 0) {
                Button {
                    changeBrowserHost {
                        showInspector.toggle()
                        if showInspector { compactPane = .details }
                    }
                } label: {
                    Label("Details", systemImage: "sidebar.right")
                }
                .toolbarIconButton()
            }
            .keyboardShortcut("i", modifiers: [.command, .control])
            .help("Show or hide selected item details (⌃⌘I)")
            .disabled(appMode != .explore || vm.showFDAOnboarding)
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private func withStateHandlers(_ content: some View) -> some View {
        content
            .onChange(of: vm.isScanning, initial: true) { _, _ in syncUpdaterBusy() }
            .onChange(of: vm.isDeleting) { _, _ in syncUpdaterBusy() }
            .onChange(of: vm.currentRoot?.id, initial: true) { _, _ in refreshMap() }
            .onChange(of: vm.treeRevision) { _, _ in refreshMap() }
            .onChange(of: vm.selectedNode?.id) { _, id in if id != nil { hasSelectedOnce = true } }
            // A pending refocus is only for the next rebuild. Once the browser
            // has focus, or the user leaves Explore, drop it.
            .onChange(of: browserFocused) { _, focused in if focused { refocusBrowserOnAppear = false } }
            .onChange(of: appMode) { _, _ in
                refocusBrowserOnAppear = false
                browserFocusBeforeDetails = false
            }
            // A read refused during a removal runs again when the removal ends.
            .onChange(of: vm.isDeleting) { _, deleting in if !deleting { refreshMap() } }
            .quickLookPreview($quickLookURL)
            .onAppear(perform: installQuickLookKeyMonitor)
            .onDisappear(perform: uninstallQuickLookKeyMonitor)
    }

    /// Analytics: fixed screen names and counts only. No names or paths.
    private func withAnalyticsHandlers(_ content: some View) -> some View {
        content
            .onChange(of: appMode, initial: true) { _, _ in
                if reviewSnapshot == nil { recordScreen(modeScreen) }
            }
            .onChange(of: reviewSnapshot?.id) { _, id in recordReviewScreen(id) }
            .onChange(of: vm.showFDAOnboarding, initial: true) { _, shown in
                if shown { analytics.capture(.permissionPrompted) }
            }
            .onChange(of: removalRequested) { _, _ in syncUpdaterBusy() }
            .onChange(of: vm.collector.isEmpty) { _, _ in syncUpdaterBusy() }
    }

    private func recordReviewScreen(_ id: UUID?) {
        if let id, let snapshot = reviewSnapshot, snapshot.id == id {
            recordScreen(.review)
            analytics.capture(.cleanupReviewOpened, values: ["items": .integer(snapshot.nodes.count)])
        } else if id == nil {
            recordScreen(modeScreen)
        }
    }

    private func withPresentation(_ content: some View) -> some View {
        content
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
            .sheet(item: $trashFinishReview) { snapshot in
                TrashFinishReviewView(vm: vm, snapshot: snapshot)
            }
            .alert(deleteErrorTitle, isPresented: Binding(
                get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
            )) { Button("OK") { deleteError = nil } } message: { Text(deleteError ?? "") }
    }

    private func openTrashFinish() {
        guard !removalBusy, reviewSnapshot == nil, trashFinishReview == nil else { return }
        removalRequested = true
        Task {
            defer { removalRequested = false }
            do { trashFinishReview = try await vm.reviewTrackedTrash() }
            catch {
                deleteErrorTitle = "Could not review Trash items"
                deleteError = error.localizedDescription
            }
        }
    }

    private func withLifecycle(_ content: some View) -> some View {
        content
            .onAppear {
                vm.refreshFullDiskAccessStatus()
                SharedScanContext.shared.register(vm)
                DebugAutomation.runIfRequested(vm: vm)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                vm.refreshFullDiskAccessStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("Tessera.captureState")),
                       perform: handleCaptureState)
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

    /// Automation only: shows a fixed UI state for capture runs.
    private func handleCaptureState(_ note: Notification) {
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

    /// One compact navigation row: where you are (breadcrumb, or the source
    /// name), one short status, and the scan button. It replaces the old
    /// title row plus a separate breadcrumb row, so the scan root's name
    /// appears once, and content starts higher.
    private var sourceHeader: some View {
        HStack(spacing: 10) {
            if let current = vm.currentRoot, showsBreadcrumb {
                breadcrumb(for: current)
            } else {
                Text(vm.rootNode == nil ? sourceName : rootDisplayName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .help(vm.scannedURL?.path ?? vm.selectedSourceURL?.path ?? "")
            }
            Spacer(minLength: 8)
            if let notice = headerNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(Theme.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
            }
            if removalBusy {
                ProgressView().controlSize(.small)
                Text("Removing \(vm.deletionProgress) of \(vm.deletionTotal)")
                    .font(.caption.monospacedDigit())
                    .accessibilityLabel("Removal progress")
            } else if !vm.isScanning && showsHeaderScanButton {
                Button {
                    if let source = vm.selectedSourceURL { vm.startScan(volumeURL: source) }
                } label: {
                    // Short, fixed labels. The source name is in the title,
                    // the status and the sidebar, not in the button.
                    Label(scanButtonTitle, systemImage: "arrow.clockwise")
                }
                .disabled(vm.selectedSourceURL == nil)
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
                .keyboardShortcut("r", modifiers: .command)
                .help(showsOtherSource ? "Scan \(sourceName) (⌘R)" : "Scan this source again (⌘R)")
                .accessibilityHint(showsOtherSource ? "Scans \(sourceName)" : "Scans \(sourceName) again")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// The breadcrumb takes the title's place while Explore shows a map.
    private var showsBreadcrumb: Bool {
        appMode == .explore && !vm.isScanning && vm.errorMessage == nil && !vm.needsFullDiskAccess
    }

    /// The scan root by its source-list name ("iCloud Drive"), not its
    /// on-disk folder name.
    private var rootDisplayName: String {
        displayName(for: vm.scannedURL, fallback: vm.rootNode?.name)
    }

    /// At most one short status beside the scan button. "Scanning" while a
    /// scan runs; the scanning view shows the phase.
    private var headerNotice: String? {
        if vm.isScanning { return "Scanning" }
        if vm.rootNode == nil {
            return vm.selectedSourceURL == nil ? "Choose a source to begin" : "Not scanned yet"
        }
        if showsOtherSource { return "\(sourceName) is selected and not scanned yet." }
        return vm.scanStatus.isEmpty ? nil : vm.scanStatus
    }

    /// The sidebar selection differs from the scan on screen.
    private var showsOtherSource: Bool {
        vm.rootNode != nil && vm.scannedURL != nil && vm.selectedSourceURL != vm.scannedURL
    }

    private var scanButtonTitle: String {
        if vm.rootNode == nil { return "Scan" }
        return showsOtherSource ? "Scan Selected Source" : "Rescan"
    }

    /// One scan action per view. The header keeps Rescan while a result is on
    /// screen, and the placeholder when no source is chosen. The empty state,
    /// an error card and Full Disk Access each own their body action, so no
    /// view shows two scan buttons.
    private var showsHeaderScanButton: Bool {
        !vm.needsFullDiskAccess && vm.errorMessage == nil
            && (vm.rootNode != nil || vm.selectedSourceURL == nil)
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
                // The dock shows whenever a scan or removal is on screen and has
                // the filled review button; the page's own button covers only
                // the case without a dock.
                CleanupSuggestionsView(vm: vm, workspace: rescueWorkspaceModel, onMoveToTrash: dockIsVisible ? nil : { openReview() })
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
            GeometryReader { geometry in
                if geometry.size.width >= 580 {
                    let column = min(320, max(230, geometry.size.width * 0.36))
                    let spacing: CGFloat = 16
                    let horizontalPadding: CGFloat = 20
                    let mapWidth = max(0, min(geometry.size.height,
                        geometry.size.width - column - spacing - 2 * horizontalPadding))
                    HStack(spacing: spacing) {
                        chart.frame(width: mapWidth)
                        rightColumn(twoLine: column < Self.twoLineColumnWidth)
                            .frame(width: column)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        chart
                        rightColumn(twoLine: false)
                            .frame(height: stackedBrowserHeight(available: geometry.size.height))
                            .padding(.horizontal, 20)
                    }
                }
            }
            // Matches the Details column's top inset, so both column
            // headers sit on one line.
            .padding(.top, 12)
            if showsSelectionBar { selectedItemBar }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The selection bar repeats Details' actions, so it shows only while
    /// Details is not on screen (including the Items side of the narrow
    /// switch). Its hint shows only until the first selection.
    private var showsSelectionBar: Bool {
        let detailsVisible = showInspector && (detailsBeside || compactPane == .details)
        guard !detailsVisible else { return false }
        return vm.selectedNode != nil || !hasSelectedOnce
    }

    /// Details gets its own column only when the map keeps its size.
    private var detailsBeside: Bool {
        showInspector && windowWidth - (showSidebar ? 211 : 0) >= Self.detailsColumnMinimumContent
    }

    // MARK: - Browser focus across rebuilds

    /// Where the browser lives. A change in any field gives it a new view
    /// identity (a different `if` branch), so SwiftUI drops its focus.
    private struct BrowserHost: Equatable {
        /// Below the map (chart area under 580 pt) instead of beside it.
        let stacked: Bool
        /// Inside the narrow Items / Details switch.
        let switched: Bool
        /// False while the switch shows Details instead of the browser.
        let visible: Bool
    }

    private var browserHost: BrowserHost {
        let sidebar: CGFloat = showSidebar ? 211 : 0
        let beside = detailsBeside
        let inspector: CGFloat = beside ? min(300, max(240, windowWidth * 0.22)) + 1 : 0
        let switched = showInspector && !beside
        return BrowserHost(stacked: windowWidth - sidebar - inspector < 580,
                           switched: switched,
                           visible: !(switched && compactPane == .details))
    }

    /// Runs a layout change and records whether the browser should take
    /// focus back. Reads `browserFocused` before the change, while the old
    /// browser still exists, so the value is current. Records nothing when
    /// the browser keeps its place, so an ordinary resize never moves focus.
    private func changeBrowserHost(_ change: () -> Void) {
        let old = browserHost
        let wasFocused = browserFocused
        change()
        let new = browserHost
        guard appMode == .explore, old != new else { return }
        if !new.visible {
            // Details replaces the browser. Remember to come back.
            browserFocusBeforeDetails = wasFocused
            refocusBrowserOnAppear = false
        } else if !old.visible {
            // Back to Items, or Details hidden.
            refocusBrowserOnAppear = browserFocusBeforeDetails
            browserFocusBeforeDetails = false
        } else {
            // Same browser, new container (resize, sidebar, Details column).
            refocusBrowserOnAppear = wasFocused
        }
    }

    /// The user moved keyboard focus to the map or the source list. A
    /// stored request to refocus the browser is now stale; drop it.
    private func dropBrowserFocusIntent() {
        refocusBrowserOnAppear = false
        browserFocusBeforeDetails = false
    }

    /// Gives focus back to a rebuilt browser only when nothing else should
    /// keep it: this view's own window is the key window (not Settings,
    /// another Tessera window, a sheet or the Quick Look panel), it has no
    /// sheet attached and no text editor active, and no removal or
    /// onboarding runs.
    private func restoreBrowserFocusIfNeeded() {
        guard refocusBrowserOnAppear else { return }
        refocusBrowserOnAppear = false
        guard !removalBusy, reviewSnapshot == nil, quickLookURL == nil, !vm.showFDAOnboarding,
              appMode == .explore,
              let window = ownWindow.window, NSApp.keyWindow === window,
              window.attachedSheet == nil, !(window.firstResponder is NSText) else { return }
        browserFocused = true
    }

    /// The browser, or in narrow windows the browser and Details behind one
    /// switch. Details never takes height from the map.
    @ViewBuilder private func rightColumn(twoLine: Bool) -> some View {
        if showInspector && !detailsBeside {
            VStack(spacing: 8) {
                Picker("Show", selection: Binding(
                    get: { compactPane },
                    set: { pane in changeBrowserHost { compactPane = pane } }
                )) {
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

    /// Presentation-only flags: the stacked browser shows 4 or 8 rows before
    /// it scrolls (max 40 % of the height), and the single-line row pitch
    /// follows `compactRowHeight`. Neither changes scanning, order or
    /// cleanup protection.
    private func stackedBrowserHeight(available: CGFloat) -> CGFloat {
        let pitch = singleRowPitch
        let rows = CGFloat(analytics.compactLegend ? 4 : 8) * pitch + 28
        return min(rows, max(120, available * 0.4))
    }

    /// The pitch single-line browser rows actually use. Without the flag this
    /// stays exactly the historical 28 pt; with it, the compact 24 pt.
    private var singleRowPitch: CGFloat {
        analytics.compactLegend ? Self.compactRowHeight : Self.browserRowHeight
    }

    private var chart: some View {
        SunburstChart(map: map,
                      hoveredNode: vm.hoveredNode, selectedNode: vm.selectedNode,
                      onHover: { vm.hoveredNode = $0 }, onSelect: { vm.selectedNode = $0 },
                      onZoomIn: { vm.zoomIn(to: $0) }, onZoomOut: { vm.zoomOut() },
                      onAddToCollector: { if !removalBusy { vm.addToCollector($0) } },
                      onRevealInFinder: { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) },
                      onQuickLook: quickLook,
                      drag: drag, onDrop: { if !removalBusy { vm.addToCollector($0) } },
                      onKeyboardFocus: dropBrowserFocusIntent)
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
        if !SunburstChart.layoutWork(of: folder, exceeds: Self.syncMapWorkLimit) {
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

    private func uninstallQuickLookKeyMonitor() {
        if let monitor = quickLookKeyMonitor { NSEvent.removeMonitor(monitor) }
        quickLookKeyMonitor = nil
    }

    private func quickLook(_ node: FileNode) {
        guard !node.isSynthetic else { return }
        quickLookURL = quickLookURL == nil ? node.url : nil
    }

    // MARK: - Child browser

    /// Every child of the folder on screen, in map order. Windowed: a spacer
    /// keeps the full height (`count × pitch`), and only the rows inside the
    /// visible rect exist as views. No AppKit table, so it takes keyboard
    /// focus on click and stays below sheets. ↑↓ move, Home and End jump,
    /// Page Up and Down move 10 rows, Return or double-click opens a folder,
    /// Space shows Quick Look, Escape clears the selection. Every child is
    /// reachable by scrolling and by the keys; none is hidden or paged out.
    private func childBrowser(twoLine: Bool) -> some View {
        let children = map?.children ?? []
        let total = Double(max(1, map?.folder.size ?? 1))
        let selectedID = vm.selectedNode?.id
        let pitch = twoLine ? Self.browserTwoLineRowHeight : singleRowPitch
        let selectedIndex = selectedID.flatMap { map?.childIndexOf($0) }
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
            // Focus shows on a row, not on the panel: the selected row (or the
            // first row, where ↓ starts, when nothing is selected) gets a
            // stronger fill and a 1 pt ring.
            let cursorID = selectedIndex == nil ? children.first?.id : selectedID
            WindowedRows(children: children, pitch: pitch, folderID: map?.folder.id,
                         selectedIndex: selectedIndex) { node in
                browserRow(node, total: total, twoLine: twoLine,
                           selected: node.id == selectedID,
                           focused: browserFocused && node.id == cursorID, height: pitch)
                    .contentShape(Rectangle())
                    .onTapGesture { browserClick(node) }
                    .contextMenu { browserMenu(node) }
            }
            // The panel ends with its rows; it never fills empty height.
            .frame(maxHeight: CGFloat(children.count) * pitch + 8)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
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
            .accessibilityHint("\(Theme.itemCount(children.count)). Use the arrow keys, Home and End to move through all of them.")
            Spacer(minLength: 0)
        }
        .disabled(removalBusy)
        .onAppear(perform: restoreBrowserFocusIfNeeded)
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

    private func browserRow(_ node: FileNode, total: Double, twoLine: Bool, selected: Bool,
                            focused: Bool, height: CGFloat) -> some View {
        let share = Double(node.size) / total * 100
        let percent = share > 0 && share < 1 ? "<1%" : "\(Int(share.rounded()))%"
        let opens = node.isDirectory && !node.isSynthetic
        // Muted text is 3.57:1 on the focused fill, so selected rows use the
        // foreground colour for size and percent (9.06:1 or more).
        let secondary = selected ? Theme.foreground : Theme.mutedForeground
        let fill: Color = !selected ? .clear : (focused ? Theme.electricBlue.opacity(0.26) : Theme.selectionTint)
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
                            .foregroundStyle(secondary)
                    }
                    Spacer(minLength: 0)
                    chevron
                }
            } else {
                HStack(spacing: 8) {
                    dot
                    Text(node.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(percent).monospacedDigit().foregroundStyle(secondary)
                    Text(Theme.format(node.size)).monospacedDigit().fixedSize()
                    chevron
                }
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, twoLine ? 5 : 0)
        // Exact height: the window and the scroll offsets depend on it. Two
        // lines of callout plus one caption line fit in the two-line pitch.
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Theme.electricBlue, lineWidth: 1)
                .opacity(focused ? 1 : 0)
                .allowsHitTesting(false)
        )
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
                            .tesseraButtonStyle(.flat)
                            .help("Open this folder on the map (⌘↓)")
                    }
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
                        .tesseraButtonStyle(.flat)
                    if vm.isCollected(node) {
                        Label("In Cleanup List", systemImage: "checkmark")
                            .font(.callout).foregroundStyle(Theme.mutedForeground)
                            // One text element; the checkmark is decoration.
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("In Cleanup List")
                    } else {
                        Button("Add to Cleanup List") { vm.addToCollector(node) }
                            .tesseraButtonStyle(.flat)
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
            DecorativeAppIcon()
                .frame(width: 64, height: 64).accessibilityHidden(true)
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
                    .tesseraButtonStyle(.flatProminent).controlSize(.large)
                    // The header scan button is hidden in this state, so the
                    // body CTA carries ⌘R while it is on screen.
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Scan \(sourceName) (⌘R)")
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
            Button("Open System Settings") { vm.openFullDiskAccessSettings() }.tesseraButtonStyle(.flatProminent)
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Scan failed", systemImage: "exclamationmark.triangle").font(.title2)
            Text(message).foregroundStyle(.secondary).textSelection(.enabled)
            if vm.canRetryLastScan {
                Button("Try again") { vm.errorMessage = nil; vm.retryLastScan() }
                    .tesseraButtonStyle(.flatProminent).disabled(removalBusy)
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
                    Button(crumbName(ancestor)) { selectBreadcrumbNode(ancestor) }
                        .tesseraButtonStyle(.interactive)
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedForeground)
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
                            Button(crumbName(ancestor)) { selectBreadcrumbNode(ancestor) }
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
    }

    /// The scan root shows its source-list name; other folders their own.
    private func crumbName(_ node: FileNode) -> String {
        node.parent == nil ? rootDisplayName : node.name
    }

    private var breadcrumbHome: some View {
        Button {
            vm.zoomToRoot()
        } label: {
            Image(systemName: "house.fill")
                .font(.caption.weight(.semibold))
        }
        .tesseraButtonStyle(.interactive)
        .help("Go to the top of this scan")
        .accessibilityLabel("Top of scan")
    }

    /// The folder on screen: the window's title, then its size.
    private func breadcrumbCurrent(_ node: FileNode) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(crumbName(node))
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(vm.scannedURL?.path ?? "")
                .accessibilityAddTraits(.isHeader)
            Text(Theme.format(node.size))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.mutedForeground)
                .fixedSize()
        }
    }

    private func selectBreadcrumbNode(_ node: FileNode) {
        vm.zoomIn(to: node)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(Theme.mutedForeground)
            .accessibilityHidden(true)
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

// MARK: - Windowed browser rows

/// A vertical list with a fixed row pitch that creates views only for the
/// rows in the visible rect. A spacer above and below keeps the full content
/// height (`count × pitch`), so the scroll bar and every offset are exact.
/// Scroll state lives here, so scrolling re-renders only this view.
///
/// Bounds: drawing is O(visible rows + 2 × overscan). Showing a selected row
/// is O(1): its offset is `index × pitch`. Nothing searches rows by id or
/// creates rows that are not on screen. Uses `ScrollPosition`,
/// `scrollPosition(_:anchor:)` and `onScrollGeometryChange(for:of:action:)`,
/// all public SwiftUI API on macOS 15.0 and later.
struct WindowedRows<Row: View>: View {
    private struct Item: Identifiable {
        let index: Int
        let node: FileNode
        var id: ObjectIdentifier { node.id }
    }

    let children: [FileNode]
    let pitch: CGFloat
    let folderID: ObjectIdentifier?
    let selectedIndex: Int?
    @ViewBuilder let row: (FileNode) -> Row

    private static var overscan: Int { 8 }
    private static var padding: CGFloat { 4 }

    @State private var position = ScrollPosition(idType: Int.self)
    /// First and last row with any part visible; -1 before the first
    /// geometry callback. Changes only when the view crosses a row boundary,
    /// so a pixel of scrolling does not re-render the rows.
    @State private var window = Window()
    /// The exact visible rect. A reference box: writing it never re-renders.
    @State private var edges = Edges()

    private struct Window: Equatable {
        var first = -1
        var last = -1
    }

    private final class Edges {
        var rect: CGRect = .zero
        /// Set after the first valid geometry has revealed the selection.
        var hasRevealed = false
    }

    /// Everything that can move the selected row. One handler compares old
    /// and new, so a folder change and a selection change in the same update
    /// make one scroll, not two competing ones.
    private struct RevealKey: Equatable {
        let folderID: ObjectIdentifier?
        let selectedIndex: Int?
        let pitch: CGFloat
    }

    var body: some View {
        let range = drawnRange
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: CGFloat(range.lowerBound) * pitch)
                .accessibilityHidden(true)
            ForEach(range.map { Item(index: $0, node: children[$0]) }) { item in
                row(item.node)
            }
            Color.clear.frame(height: CGFloat(children.count - range.upperBound) * pitch)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(Self.padding)
        .scrollContainer(position: $position) { rect in
            edges.rect = rect
            updateWindow()
            // A view made after the selection (Items ↔ Details, a new window
            // layout) starts at the top. Reveal the selection once, on the
            // first valid geometry. Later geometry never scrolls, so a scroll
            // cannot feed back into another scroll.
            if !edges.hasRevealed, rect.height > 0 {
                edges.hasRevealed = true
                if let selectedIndex { show(selectedIndex) }
            }
        }
        .onChange(of: RevealKey(folderID: folderID, selectedIndex: selectedIndex, pitch: pitch)) { old, new in
            if old.folderID != new.folderID {
                // New folder: start at the top, or at the least offset that
                // shows a selection that belongs to the new folder.
                position.scrollTo(y: new.selectedIndex.map { offsetFromTop(showing: $0) } ?? 0)
                return
            }
            // Resizing can switch between one- and two-line rows; the window
            // is recomputed for the new pitch before the selection is shown.
            if old.pitch != new.pitch { updateWindow() }
            if let index = new.selectedIndex,
               old.selectedIndex != new.selectedIndex || old.pitch != new.pitch {
                show(index)
            }
        }
    }

    private func updateWindow() {
        let rect = edges.rect
        guard rect.height > 0 else { return }
        let first = max(0, Int(((rect.minY - Self.padding) / pitch).rounded(.down)))
        let last = max(first, Int(((rect.maxY - Self.padding) / pitch).rounded(.up)) - 1)
        let next = Window(first: first, last: last)
        if next != window { window = next }
    }

    private var drawnRange: Range<Int> {
        let count = children.count
        guard count > 0 else { return 0..<0 }
        guard window.first >= 0 else { return 0..<min(count, 40) }
        let lower = min(max(0, window.first - Self.overscan), count)
        let upper = min(count, window.last + 1 + Self.overscan)
        if lower < upper { return lower..<upper }
        // The window is past the end (the list shrank): draw the tail.
        return max(0, count - 2 * Self.overscan)..<count
    }

    /// Scroll the least distance that shows row `index` in full. Does
    /// nothing when the row is already fully visible, or before the first
    /// valid geometry (the first-geometry reveal handles that case).
    private func show(_ index: Int) {
        let rect = edges.rect
        guard rect.height > 0 else { return }
        let top = Self.padding + CGFloat(index) * pitch
        let bottom = top + pitch
        let target: CGFloat
        if top < rect.minY {
            target = max(0, top - Self.padding)
        } else if bottom > rect.maxY {
            target = max(0, bottom + Self.padding - rect.height)
        } else {
            return
        }
        guard abs(target - rect.minY) >= 0.5 else { return }
        position.scrollTo(y: target)
    }

    /// The offset that shows row `index` when the list starts at the top:
    /// 0 if the row is already in the first screenful, else the least offset
    /// that brings its bottom edge into view.
    private func offsetFromTop(showing index: Int) -> CGFloat {
        let height = edges.rect.height
        let bottom = Self.padding + CGFloat(index + 1) * pitch
        guard height > 0, bottom + Self.padding > height else { return 0 }
        return bottom + Self.padding - height
    }
}

private extension View {
    /// Wraps the content in a vertical scroll view driven by `position`, and
    /// reports its visible rect in content coordinates.
    func scrollContainer(position: Binding<ScrollPosition>,
                         onVisibleRect: @escaping (CGRect) -> Void) -> some View {
        ScrollView(.vertical) { self }
            .scrollPosition(position)
            .onScrollGeometryChange(for: CGRect.self, of: { $0.visibleRect }) { _, rect in
                onVisibleRect(rect)
            }
    }
}

// MARK: - Scan status

private struct ScanningView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // The phase only; the header says "Scanning".
            Text(vm.scanStatus.isEmpty ? "Reading files" : vm.scanStatus)
                .font(.title2.weight(.semibold))
            Text("Tessera is reading this source. Your files stay in place.")
                .foregroundStyle(.secondary)
            ProgressView().progressViewStyle(.linear)
                .accessibilityLabel("Scan in progress")
            HStack(spacing: 24) {
                // Locale grouping: 100,000, not 100000.
                metric("Files read", vm.progress.filesScanned.formatted())
                metric("Folders read", vm.progress.dirsScanned.formatted())
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
                .tesseraButtonStyle(.flat).keyboardShortcut(".", modifiers: .command)
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
            // These buttons carry shortcuts only. They are not Tab stops.
            Button("Zoom Out") { vm.zoomOut() }.keyboardShortcut(.upArrow, modifiers: .command).focusable(false)
            Button("Open") {
                if let node = vm.selectedNode, node.isDirectory, !node.isSynthetic, node.id != vm.currentRoot?.id {
                    vm.zoomIn(to: node)
                }
            }
            .keyboardShortcut(.downArrow, modifiers: .command).focusable(false)
            Button("Add to Cleanup List") {
                if let node = vm.selectedNode, !node.isSynthetic { vm.addToCollector(node) }
            }
            .keyboardShortcut(.delete, modifiers: .command).focusable(false)
            Button("Quick Look") {
                if let node = vm.selectedNode, !node.isSynthetic { onQuickLook(node) }
            }
            .keyboardShortcut("y", modifiers: .command).focusable(false)
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
                .tesseraButtonStyle(.flatProminent)
                .controlSize(.large)

                Button("Not Now") {
                    Analytics.shared.capture(.permissionDismissed)
                    vm.dismissFDAOnboarding()
                }
                .keyboardShortcut(.cancelAction)
                .tesseraButtonStyle(.flat)
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
