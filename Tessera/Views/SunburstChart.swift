import SwiftUI
import AppKit

// MARK: - Map snapshot

/// One folder on the map, built once per folder and tree revision. The map,
/// the child browser and Details all read colour and order from it, so a
/// dot, a wedge and a Details badge cannot disagree. Synthetic "Other" nodes
/// are minted here once, so their identity survives redraws and resizes.
struct MapSnapshot: Sendable {
    let folder: FileNode
    let revision: ScanTreeRevision
    let wedges: [SunburstChart.Wedge]
    /// Every direct child, in `FileNode.largestFirst` order (the map's order).
    let children: [FileNode]
    private let wedgeIndex: [ObjectIdentifier: Int]
    private let childIndex: [ObjectIdentifier: Int]

    /// Safe off the main actor while the tree is pinned by `readTree`.
    nonisolated static func build(folder: FileNode, revision: ScanTreeRevision,
                                  cancellation: TreeReadCancellation? = nil) -> MapSnapshot? {
        let children = folder.sortedChildren
        if cancellation?.isCancelled == true { return nil }
        let wedges = SunburstChart.buildLayout(root: folder)
        if cancellation?.isCancelled == true { return nil }
        var wedgeIndex: [ObjectIdentifier: Int] = [:]
        wedgeIndex.reserveCapacity(wedges.count)
        for (index, wedge) in wedges.enumerated() { wedgeIndex[wedge.node.id] = index }
        var childIndex: [ObjectIdentifier: Int] = [:]
        childIndex.reserveCapacity(children.count)
        for (index, child) in children.enumerated() { childIndex[child.id] = index }
        return MapSnapshot(folder: folder, revision: revision, wedges: wedges, children: children,
                           wedgeIndex: wedgeIndex, childIndex: childIndex)
    }

    func child(_ id: ObjectIdentifier) -> FileNode? {
        childIndex[id].map { children[$0] }
    }

    /// Position of a direct child in `children`, without a linear search.
    func childIndexOf(_ id: ObjectIdentifier) -> Int? { childIndex[id] }

    func wedge(for node: FileNode) -> SunburstChart.Wedge? {
        wedgeIndex[node.id].map { wedges[$0] }
    }

    /// The colour the map uses for `node`, at any depth. A node deeper than
    /// the outer ring takes its drawn ancestor's colour. A node the map folds
    /// into "Other" or a sliver takes the aggregate neutral. Nil for the
    /// folder itself and for nodes outside it.
    func color(for node: FileNode, highContrast: Bool) -> Color? {
        if let synthetic = Theme.syntheticColor(for: node.kind, highContrast: highContrast) { return synthetic }
        var cursor: FileNode? = node
        while let current = cursor, current.id != folder.id {
            if let wedge = wedge(for: current) {
                if current.id == node.id || wedge.depth == SunburstChart.maxRings - 1 {
                    return SunburstChart.color(for: wedge, highContrast: highContrast)
                }
                return Theme.wedgeColor(palette: nil, depth: 0, highContrast: highContrast)
            }
            cursor = current.parent
        }
        return nil
    }
}

// MARK: - SunburstChart

/// Pure-Canvas sunburst (ring chart) that renders up to five rings around a
/// central hub. Angular layout is precomputed when `root` or its content
/// revision changes; resizing only updates Canvas geometry, while hover/selection
/// vary per frame.
struct SunburstChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast
    /// The folder on screen and its precomputed wedges.
    let map: MapSnapshot?
    let hoveredNode: FileNode?
    let selectedNode: FileNode?
    let onHover: (FileNode?) -> Void
    let onSelect: (FileNode?) -> Void
    let onZoomIn: (FileNode) -> Void
    let onZoomOut: () -> Void
    let onAddToCollector: (FileNode) -> Void
    let onRevealInFinder: (FileNode) -> Void
    /// Space: Quick Look the selection. The caller skips synthetic nodes.
    let onQuickLook: (FileNode) -> Void
    /// Drives drag-and-drop of wedges into the bottom dock.
    @ObservedObject var drag: CollectorDragController
    /// Called when a wedge is dropped onto a dock zone (collector or trash).
    let onDrop: (FileNode) -> Void

    // Tuning constants
    nonisolated static let maxRings = 5
    private static let hubFraction: CGFloat = 0.17
    nonisolated private static let minWedgeDegrees: Double = 0.7
    nonisolated static let aggregateFraction: Double = 0.004   // 0.4 %
    /// Wedges narrower than this keep their place but draw in the aggregate
    /// neutral, so slivers do not add noise to the branch colours.
    nonisolated static let smallWedgeDegrees: Double = 1.0
    nonisolated private static let gapDegrees: Double = 1.2
    nonisolated private static let maxWedgesPerRing = 60
    private static let ringInset: CGFloat = 1.5            // hairline separation
    private static let minimumRenderableSide: CGFloat = 120

    /// Geometry shared by drawing and hit testing. Returning nil for transient
    /// zero/tiny sizes prevents a live resize from producing a zero ring span
    /// (which previously reached `Int(.nan)` in hit testing and crashed).
    struct ChartGeometry: Equatable {
        let center: CGPoint
        let chartRadius: CGFloat
        let hubRadius: CGFloat
        let ringSpan: CGFloat
    }

    static func chartGeometry(for size: CGSize) -> ChartGeometry? {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        let side = min(size.width, size.height)
        guard side >= minimumRenderableSide else { return nil }
        let chartRadius = side / 2 * 0.96
        let hubRadius = chartRadius * hubFraction
        let ringSpan = (chartRadius - hubRadius) / CGFloat(maxRings)
        guard chartRadius.isFinite, hubRadius.isFinite, ringSpan.isFinite,
              ringSpan > 0 else { return nil }
        return ChartGeometry(
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            chartRadius: chartRadius,
            hubRadius: hubRadius,
            ringSpan: ringSpan
        )
    }

    private var root: FileNode? { map?.folder }
    private var layout: [Wedge] { map?.wedges ?? [] }
    private var highContrast: Bool { contrast == .increased }
    /// The folder the sweep-in last ran for. Unprimed views draw at full sweep.
    @State private var sweptRootID: ObjectIdentifier?
    @State private var appearProgress: Double = 0          // 0…1 sweep-in
    @State private var cursor: CGPoint = .zero
    @State private var hovering = false
    /// This view's frame in window coordinates, used to convert global
    /// right-click events into local space.
    @State private var windowFrame: CGRect = .zero
    /// This view's frame in the shared "app" coordinate space, used to convert a
    /// drag's app-space start point into local space for wedge hit-testing.
    @State private var chartFrameInApp: CGRect = .zero
    /// Measured tooltip size for accurate edge clamping.
    @State private var tooltipSize: CGSize = .zero
    /// Local NSEvent monitor for right-clicks; removed on disappear.
    @State private var rightClickMonitor: Any?
    @FocusState private var mapFocused: Bool

    var body: some View {
        GeometryReader { geo in
            if let geometry = Self.chartGeometry(for: geo.size) {
                ZStack {
                    // Flat design: the wedges sit directly on the solid window
                    // background. No frosted plate, no vibrancy.
                    canvas(center: geometry.center,
                           chartRadius: geometry.chartRadius,
                           hubRadius: geometry.hubRadius)
                        // Make the entire chart frame hit-testable, including the
                        // transparent gaps between wedges, so hover and taps always land.
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let p):
                                cursor = p
                                hovering = true
                                updateHover(at: p, center: geometry.center,
                                            chartRadius: geometry.chartRadius,
                                            hubRadius: geometry.hubRadius)
                            case .ended:
                                hovering = false
                                onHover(nil)
                            }
                        }
                        // One tap handler. A count-2 gesture would make every
                        // single click wait for the double-click interval.
                        // AppKit's click count tells the second click apart.
                        .onTapGesture(coordinateSpace: .local) { location in
                            guard isEnabled else { return }
                            handleTap(at: location, center: geometry.center,
                                      chartRadius: geometry.chartRadius,
                                      hubRadius: geometry.hubRadius)
                        }
                        // Drag a wedge out to the dock. Simultaneous so it coexists
                        // with tap (a click never moves far enough to start a drag).
                        .simultaneousGesture(
                            dragGesture(center: geometry.center,
                                        chartRadius: geometry.chartRadius,
                                        hubRadius: geometry.hubRadius)
                        )
                        .contextMenu {
                            contextMenuItems(center: geometry.center,
                                             chartRadius: geometry.chartRadius,
                                             hubRadius: geometry.hubRadius)
                        }

                    hub(radius: geometry.hubRadius)

                    // Keyboard focus: a 1 pt cyan circle just outside the
                    // rings. The system ring would use the system accent.
                    if mapFocused {
                        Circle()
                            .strokeBorder(Theme.electricBlue, lineWidth: 1)
                            .frame(width: geometry.chartRadius * 2 + 8, height: geometry.chartRadius * 2 + 8)
                            .position(geometry.center)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }

                    if hovering, let node = hoveredNode {
                        tooltip(for: node, in: geo.size)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                windowFrame = proxy.frame(in: .global)
                                chartFrameInApp = proxy.frame(in: .named(CollectorDragController.appSpace))
                            }
                            .onChange(of: proxy.frame(in: .global)) { _, f in windowFrame = f }
                            .onChange(of: proxy.frame(in: .named(CollectorDragController.appSpace))) { _, f in
                                chartFrameInApp = f
                            }
                        }
                )
                .onAppear {
                    sweepIn()
                    installRightClickMonitor()
                }
                .onDisappear { removeRightClickMonitor() }
                .onChange(of: root?.id) { _, _ in sweepIn() }
            } else {
                Color.clear
            }
        }
        // Keyboard: Tab reaches the map. Left and Right move between
        // siblings, Down moves to the first child ring, Up to the parent,
        // Return opens a folder, Escape clears the selection.
        .focusable(isEnabled)
        .focused($mapFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return, .space]) { press in
            guard isEnabled, press.modifiers.isDisjoint(with: [.command, .option, .control]) else {
                return .ignored
            }
            return handleKey(press.key) ? .handled : .ignored
        }
        .onExitCommand { if isEnabled { onSelect(nil) } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Use the arrow keys to move between items. Return opens a folder. Space shows a Quick Look preview. Command-Delete adds the selection to the Cleanup List.")
        .accessibilityChildren { accessibleWedges }
    }

    // MARK: - Keyboard

    /// Moves the selection through the cached layout. No tree walk: siblings
    /// and children come from `layout`, which is already in angular order.
    private func handleKey(_ key: KeyEquivalent) -> Bool {
        let wedges = layout
        guard !wedges.isEmpty else { return false }
        guard let current = selectedNode,
              let index = wedges.firstIndex(where: { $0.node.id == current.id }) else {
            if key == .return, let selectedNode, selectedNode.isDirectory, !selectedNode.isSynthetic,
               selectedNode.id != root?.id {
                onZoomIn(selectedNode)
                return true
            }
            onSelect(wedges[0].node)
            return true
        }
        let wedge = wedges[index]
        switch key {
        case .space:
            if !current.isSynthetic { onQuickLook(current) }
        case .leftArrow, .rightArrow:
            let siblings = wedges.filter { $0.depth == wedge.depth && $0.node.parent?.id == wedge.node.parent?.id }
            guard let at = siblings.firstIndex(where: { $0.node.id == current.id }), siblings.count > 1 else { return true }
            let step = key == .rightArrow ? 1 : siblings.count - 1
            onSelect(siblings[(at + step) % siblings.count].node)
        case .downArrow:
            if let child = wedges[(index + 1)...].first(where: { $0.depth == wedge.depth + 1 && $0.node.parent?.id == current.id }) {
                onSelect(child.node)
            }
        case .upArrow:
            if wedge.depth > 0, let parent = current.parent { onSelect(parent) }
            else if isZoomed { onZoomOut() }
        case .return:
            if current.isDirectory && !current.isSynthetic { onZoomIn(current) }
        default:
            return false
        }
        return true
    }

    /// One VoiceOver element per wedge in the two inner rings (bounded by the
    /// per-ring cap), labeled with name, size and share of its parent.
    @ViewBuilder private var accessibleWedges: some View {
        let total = Double(max(1, root?.size ?? 1))
        ForEach(layout.filter { $0.depth < 2 }) { wedge in
            let node = wedge.node
            let parentSize = Double(max(1, node.parent?.size ?? Int64(total)))
            let percent = Int((Double(node.size) / parentSize * 100).rounded())
            Text("\(node.name), \(Theme.format(node.size)), \(percent)% of \(node.parent?.name ?? root?.name ?? "total")")
                .accessibilityAddTraits(node.id == selectedNode?.id ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { onSelect(node) }
                .accessibilityAction(named: "Open") {
                    if node.isDirectory && !node.isSynthetic { onZoomIn(node) }
                }
        }
        if isZoomed {
            Button("Go up one level") { onZoomOut() }
        }
    }

    private var accessibilityValue: String {
        if let selectedNode {
            return "Selected \(selectedNode.name), \(Theme.format(selectedNode.size))"
        }
        return "No item selected"
    }

    // MARK: - Canvas

    private func canvas(center: CGPoint, chartRadius: CGFloat, hubRadius: CGFloat) -> some View {
        let ringSpan = (chartRadius - hubRadius) / CGFloat(Self.maxRings)
        let wedges = layout
        // Offscreen rendering never runs onAppear; draw it at full sweep.
        let progress = sweptRootID == root?.id ? appearProgress : 1.0
        return Canvas { ctx, _ in
            // Drawn after every fill, so neighbours never cover the outline.
            var selectedPath: Path?
            for wedge in wedges {
                let inner = hubRadius + CGFloat(wedge.depth) * ringSpan + Self.ringInset
                let outer = hubRadius + CGFloat(wedge.depth + 1) * ringSpan - Self.ringInset
                let isHovered = wedge.node.id == hoveredNode?.id
                let isSelected = wedge.node.id == selectedNode?.id

                // Sweep-in: scale the swept angle by appearProgress.
                let start = wedge.startAngle
                let end = start + (wedge.endAngle - wedge.startAngle) * progress
                guard end - start > 0.0001 else { continue }

                // Hit-testing and drawing share identical geometry — no radial
                // pop. Hover/selection are conveyed purely via fill brightening,
                // a rim light, and glow strokes so clicks always land on the
                // wedge under the cursor.
                let path = wedgePath(center: center,
                                     inner: inner, outer: outer,
                                     start: start, end: end)

                // Flat solid fill — one categorical color per wedge.
                ctx.fill(path, with: .color(Self.color(for: wedge, highContrast: highContrast)))

                // Hairline gap in the background color separates adjacent wedges,
                // exactly like the tiles in the app icon.
                ctx.stroke(path, with: .color(Theme.bg),
                           style: StrokeStyle(lineWidth: 1, lineJoin: .round))

                if isHovered {
                    // Flat hover: a plain white wash, no blur/glow.
                    ctx.fill(path, with: .color(.white.opacity(0.14)))
                }
                if isSelected { selectedPath = path }
            }
            if let selectedPath {
                // A dark halo under a white line stays visible on every branch
                // hue, including the cyan one.
                ctx.stroke(selectedPath, with: .color(Theme.bg),
                           style: StrokeStyle(lineWidth: 5, lineJoin: .round))
                ctx.stroke(selectedPath, with: .color(.white),
                           style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: hoveredNode?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedNode?.id)
    }

    /// Fill for a wedge. Every wedge keeps its top-level branch hue and steps
    /// toward the background with depth. Synthetic kinds keep fixed neutrals.
    /// `MapSnapshot.color` uses this too, so the legend and Details match.
    nonisolated static func color(for wedge: Wedge, highContrast: Bool) -> Color {
        Theme.syntheticColor(for: wedge.node.kind, highContrast: highContrast)
            ?? Theme.wedgeColor(palette: wedge.palette, depth: wedge.depth, highContrast: highContrast)
    }

    /// Build an annular sector path (rounded line caps via stroked arcs not used;
    /// solid filled sector with arc joins keeps it crisp at 60fps).
    private func wedgePath(center: CGPoint, inner: CGFloat, outer: CGFloat,
                           start: Double, end: Double) -> Path {
        var p = Path()
        let s = Angle(degrees: start)
        let e = Angle(degrees: end)
        p.addArc(center: center, radius: outer, startAngle: s, endAngle: e, clockwise: false)
        p.addArc(center: center, radius: inner, startAngle: e, endAngle: s, clockwise: true)
        p.closeSubpath()
        return p
    }

    // MARK: - Center hub

    /// The hub is centred naturally by the parent `ZStack` (its centre coincides
    /// with the chart's geometric centre), so it does NOT use `.position`.
    /// `.position` makes a view's hit-test frame fill the entire parent, which —
    /// combined with interactive glass — is exactly what used to swallow every
    /// hover and click meant for the wedges.
    private func hub(radius: CGFloat) -> some View {
        let node = root
        return VStack(spacing: 2) {
            if isZoomed {
                Image(systemName: "chevron.up")
                    .font(.system(size: max(9, radius * 0.18), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            // Size only: the folder's name is already the window's title.
            Text(Theme.format(node?.size ?? 0))
                .font(.system(size: max(15, radius * 0.30), weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(radius * 0.18)
        .frame(width: radius * 2, height: radius * 2)
        // Flat: a solid disc with a hairline edge. When the hub is actually
        // clickable (zoomed in) the edge picks up the accent so it reads as a
        // button instead of inert decoration.
        .background(Circle().fill(Theme.card))
        .overlay(
            Circle()
                .strokeBorder(isZoomed ? Theme.electricBlue : Theme.border,
                              lineWidth: isZoomed ? 1.5 : 1)
                .allowsHitTesting(false)
        )
        .contentShape(Circle())
        // Pass hover/clicks through to the wedges below. Only when zoomed in does
        // the hub become an active target (tap = zoom out).
        .allowsHitTesting(isZoomed)
        .onTapGesture { if isEnabled && isZoomed { onZoomOut() } }
        .help(isZoomed ? "Go back up one level" : "")
    }

    private var isZoomed: Bool { root?.parent != nil }

    // MARK: - Tooltip

    @ViewBuilder
    private func tooltip(for node: FileNode, in size: CGSize) -> some View {
        let total = max(1, root?.size ?? 1)
        let pct = Double(node.size) / Double(total) * 100
        VStack(alignment: .leading, spacing: 2) {
            Text(node.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1).truncationMode(.middle)
            HStack(spacing: 6) {
                Text(Theme.format(node.size))
                    .monospacedDigit()
                Text(String(format: "%.1f%%", pct))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: 240, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { tooltipSize = $0 }
        .position(tooltipPosition(in: size))
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func tooltipPosition(in size: CGSize) -> CGPoint {
        // Clamp using the measured tooltip size so wide tooltips (up to 240pt)
        // never spill off the chart edge.
        let w = tooltipSize.width, h = tooltipSize.height
        var x = cursor.x + w / 2 + 16
        var y = cursor.y - h / 2 - 16
        x = min(max(w / 2 + 4, x), size.width - w / 2 - 4)
        y = min(max(h / 2 + 4, y), size.height - h / 2 - 4)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Interaction

    /// The first click selects at once. The second click of a double click
    /// opens a folder. A third click does nothing more.
    private func handleTap(at location: CGPoint, center: CGPoint,
                           chartRadius: CGFloat, hubRadius: CGFloat) {
        guard let wedge = hitTest(at: location, center: center,
                                  chartRadius: chartRadius, hubRadius: hubRadius) else {
            onSelect(nil); return
        }
        // A click gives the map keyboard focus, so arrow keys act at once.
        mapFocused = true
        let clicks = NSApp.currentEvent?.clickCount ?? 1
        if clicks == 2 {
            if wedge.node.isDirectory && !wedge.node.isSynthetic {
                onSelect(wedge.node)
                onZoomIn(wedge.node)
            }
            return
        }
        if clicks == 1 { onSelect(wedge.node) }
    }

    /// Drag a real wedge out of the chart and into the bottom dock. On first
    /// movement we hit-test the grab point to identify the wedge; thereafter we
    /// just track the cursor so the dock can highlight the live drop zone.
    private func dragGesture(center: CGPoint, chartRadius: CGFloat,
                             hubRadius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(CollectorDragController.appSpace))
            .onChanged { value in
                guard isEnabled else { return }
                if drag.node == nil {
                    // Convert the app-space grab point into chart-local space.
                    let localStart = CGPoint(x: value.startLocation.x - chartFrameInApp.minX,
                                             y: value.startLocation.y - chartFrameInApp.minY)
                    guard let wedge = hitTest(at: localStart, center: center,
                                              chartRadius: chartRadius, hubRadius: hubRadius),
                          !wedge.node.isSynthetic else { return }
                    onSelect(wedge.node)
                    drag.begin(wedge.node, at: value.location)
                    onHover(nil)   // suppress the tooltip while dragging
                } else {
                    drag.update(to: value.location)
                }
            }
            .onEnded { value in
                guard isEnabled, drag.node != nil else { drag.reset(); return }
                drag.update(to: value.location)
                if let dropped = drag.end() {
                    onDrop(dropped)
                }
            }
    }

    @ViewBuilder
    private func contextMenuItems(center: CGPoint, chartRadius: CGFloat,
                                  hubRadius: CGFloat) -> some View {
        let node = selectedNode
        if let node, !node.isSynthetic {
            if node.isDirectory {
                Button("Open Folder") { onZoomIn(node) }
            }
            Button("Add to Cleanup List") { onAddToCollector(node) }
            Button("Reveal in Finder") { onRevealInFinder(node) }
        } else {
            // Synthetic wedge (or empty space): explain why no actions apply.
            Text(syntheticMenuLabel(for: node))
                .disabled(true)
        }
    }

    /// Informational menu label for synthetic / empty hit targets.
    private func syntheticMenuLabel(for node: FileNode?) -> String {
        switch node?.kind {
        case .aggregate:    return "Aggregated small items"
        case .hiddenSpace:  return "Space not visible to the scan"
        case .cloudOnlyStorage: return "Online-only cloud storage (not scanned)"
        case .crossVolume:  return "Separate volume mounted here (e.g. a Simulator runtime)"
        default:            return "Nothing here"
        }
    }

    // MARK: - Right-click monitor

    /// Install a local monitor so right-clicks update `cursor` even when the
    /// user never hovered first (onContinuousHover would otherwise leave it
    /// stale/zero). The monitor converts the event's window-space location into
    /// this view's local coordinate space using the cached `windowFrame`.
    private func installRightClickMonitor() {
        guard rightClickMonitor == nil else { return }
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { event in
            if isEnabled, let local = localPoint(for: event),
               let geometry = Self.chartGeometry(for: windowFrame.size) {
                cursor = local
                onSelect(hitTest(at: local, center: geometry.center,
                                 chartRadius: geometry.chartRadius,
                                 hubRadius: geometry.hubRadius)?.node)
            }
            return event
        }
    }

    private func removeRightClickMonitor() {
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
            rightClickMonitor = nil
        }
    }

    /// Convert a right-mouse event into this view's local (SwiftUI, top-left
    /// origin) coordinate space, or nil if it lands outside the chart.
    private func localPoint(for event: NSEvent) -> CGPoint? {
        guard let window = event.window, windowFrame != .zero else { return nil }
        // Event location is in window coordinates (AppKit: bottom-left origin).
        let inWindow = event.locationInWindow
        let height = window.contentLayoutRect.height
        // Flip to top-left origin to match SwiftUI's `.global` frame.
        let flippedY = height - inWindow.y
        let local = CGPoint(x: inWindow.x - windowFrame.minX,
                            y: flippedY - windowFrame.minY)
        guard local.x >= 0, local.y >= 0,
              local.x <= windowFrame.width, local.y <= windowFrame.height else {
            return nil
        }
        return local
    }

    private func updateHover(at p: CGPoint, center: CGPoint,
                            chartRadius: CGFloat, hubRadius: CGFloat) {
        let wedge = hitTest(at: p, center: center,
                            chartRadius: chartRadius, hubRadius: hubRadius)
        if wedge?.node.id != hoveredNode?.id {
            onHover(wedge?.node)
        }
    }

    /// Precise polar hit-testing against the cached layout.
    private func hitTest(at p: CGPoint, center: CGPoint,
                         chartRadius: CGFloat, hubRadius: CGFloat) -> Wedge? {
        Self.hitTest(in: layout, at: p, center: center,
                     chartRadius: chartRadius, hubRadius: hubRadius)
    }

    /// Pure, side-effect-free polar hit-test: which wedge in `layout` contains
    /// the point `p`? Static so it can be unit-tested against `buildLayout`
    /// output without a live view. Returns nil inside the hub hole
    /// (`r < hubRadius`) and outside the chart (`r > chartRadius`). The drawing
    /// code in `canvas` uses this exact geometry, so a click always lands on the
    /// wedge under the cursor.
    static func hitTest(in layout: [Wedge], at p: CGPoint, center: CGPoint,
                        chartRadius: CGFloat, hubRadius: CGFloat) -> Wedge? {
        guard chartRadius.isFinite, hubRadius.isFinite,
              chartRadius > hubRadius, hubRadius >= 0 else { return nil }
        let dx = p.x - center.x, dy = p.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        guard r.isFinite else { return nil }
        guard r >= hubRadius, r <= chartRadius else { return nil }
        let ringSpan = (chartRadius - hubRadius) / CGFloat(maxRings)
        guard ringSpan.isFinite, ringSpan > 0 else { return nil }
        let rawDepth = (r - hubRadius) / ringSpan
        guard rawDepth.isFinite, rawDepth >= 0 else { return nil }
        let depth = min(maxRings - 1, Int(rawDepth))
        var deg = Angle(radians: atan2(dy, dx)).degrees
        if deg < 0 { deg += 360 }

        for wedge in layout where wedge.depth == depth {
            var s = wedge.startAngle.truncatingRemainder(dividingBy: 360)
            var e = wedge.endAngle.truncatingRemainder(dividingBy: 360)
            if s < 0 { s += 360 }
            if e < 0 { e += 360 }
            if e < s {  // wraps past 0°
                if deg >= s || deg <= e { return wedge }
            } else if deg >= s && deg <= e {
                return wedge
            }
        }
        return nil
    }

    // MARK: - Layout

    /// Sweep the wedges in once per folder. Reduce Motion skips it.
    private func sweepIn() {
        guard let root else { return }
        guard sweptRootID != root.id else { return }
        sweptRootID = root.id
        if reduceMotion {
            appearProgress = 1
        } else {
            appearProgress = 0
            withAnimation(.easeInOut(duration: 0.35)) { appearProgress = 1 }
        }
    }

    /// Walk the tree breadth-by-depth, allocating angular spans proportional to
    /// size, aggregating tiny siblings into a synthetic "Other" wedge.
    /// Bounded top-K selection for one ring. O(k) for k children: each child
    /// is compared once with the threshold; only children at or above it can
    /// be inserted, and the kept list never exceeds `maxWedgesPerRing`, so an
    /// insertion costs at most `maxWedgesPerRing` comparisons. When sizes add
    /// up to the parent (as `recomputeDirectorySizes` makes them), at most
    /// `1 / aggregateFraction` = 250 children pass the threshold.
    nonisolated static func visibleChildren(of parent: FileNode, parentSize: Double)
        -> (visible: [FileNode], aggregateSize: Int64) {
        var visible: [FileNode] = []
        visible.reserveCapacity(min(parent.children.count, maxWedgesPerRing + 1))
        var aggregateSize: Int64 = 0
        for child in parent.children {
            guard Double(child.size) / parentSize >= aggregateFraction else {
                aggregateSize += child.size
                continue
            }
            if visible.count == maxWedgesPerRing, let last = visible.last,
               !FileNode.largestFirst(child, last) {
                aggregateSize += child.size
                continue
            }
            let index = visible.firstIndex { FileNode.largestFirst(child, $0) } ?? visible.endIndex
            visible.insert(child, at: index)
            if visible.count > maxWedgesPerRing { aggregateSize += visible.removeLast().size }
        }
        return (visible, aggregateSize)
    }

    /// True when the layout for `root` could visit more than `limit` children
    /// in total. Walks the same directories `buildLayout` may enter (five
    /// rings, real folders only) and stops as soon as the count passes
    /// `limit`, so the check itself costs O(limit).
    nonisolated static func layoutWork(of root: FileNode, exceeds limit: Int) -> Bool {
        var visited = 0
        var queue: [(node: FileNode, depth: Int)] = [(root, 0)]
        var head = 0
        while head < queue.count {
            let (node, depth) = queue[head]
            head += 1
            visited += node.children.count
            if visited > limit { return true }
            guard depth + 1 < maxRings else { continue }
            for child in node.children where child.isDirectory && !child.isSynthetic {
                queue.append((child, depth + 1))
            }
        }
        return false
    }

    nonisolated static func buildLayout(root: FileNode) -> [Wedge] {
        var out: [Wedge] = []

        func recurse(parent: FileNode, depth: Int, start: Double, sweep: Double,
                     palette: Int?) {
            guard depth < maxRings else { return }
            guard !parent.children.isEmpty else { return }
            let parentSize = max(1, Double(parent.size))

            // Fold tiny children into a single synthetic "Other" wedge — at EVERY
            // depth, not just the root ring. The threshold is relative to the
            // parent's size (which equals the root total at depth 0, so the top
            // ring is unchanged). Without this, a directory with hundreds of small
            // children (e.g. an iCloud .Trash) spends its whole sweep on
            // inter-wedge gaps and renders nothing (usable <= 0).
            //
            // One pass, no full sort: the visible wedges are the first
            // `maxWedgesPerRing` children in `FileNode.largestFirst` order whose
            // share reaches `aggregateFraction`. Everything else, below the
            // threshold or past the cap, sums into "Other". This is the same
            // set, order and sum the old sort-then-filter produced.
            let (visible, aggregateSize) = visibleChildren(of: parent, parentSize: parentSize)
            var entries: [(node: FileNode, size: Int64)] = visible.map { ($0, $0.size) }
            if aggregateSize > 0 {
                let other = FileNode(url: parent.url, name: "Other",
                                     isDirectory: false, size: aggregateSize, kind: .aggregate)
                entries.append((other, aggregateSize))
            }

            let n = entries.count
            // Clamp the per-wedge gap so the total gap budget can never swallow the
            // sweep (which would zero out `usable`). In the common case (few
            // children) this stays at gapDegrees and the look is unchanged.
            let gap = min(gapDegrees, sweep * 0.35 / Double(max(1, n)))
            let gaps = gap * Double(n)
            let usable = max(0, sweep - gaps)
            var cursor = start

            for (i, entry) in entries.enumerated() {
                let frac = Double(entry.size) / parentSize
                let span = usable * frac
                if span >= minWedgeDegrees {
                    // Top ring: the rank picks the branch colour (it matches the
                    // Largest items legend). Deeper rings inherit it unchanged.
                    // Slivers turn neutral; their children stay neutral too.
                    let branch = depth == 0 ? i : palette
                    let childPalette = sweep * frac < smallWedgeDegrees ? nil : branch
                    let wedge = Wedge(node: entry.node, depth: depth,
                                      startAngle: cursor, endAngle: cursor + span,
                                      palette: childPalette)
                    out.append(wedge)
                    if entry.node.isDirectory && !entry.node.isSynthetic {
                        recurse(parent: entry.node, depth: depth + 1,
                                start: cursor, sweep: span, palette: childPalette)
                    }
                }
                cursor += span + gap
            }
        }

        // Start at -90° so the first wedge begins at the top.
        recurse(parent: root, depth: 0, start: -90, sweep: 360, palette: nil)
        return out
    }

    private var accessibilitySummary: String {
        guard let root else { return "Sunburst chart, no data" }
        return "Sunburst chart of \(root.name), total size \(Theme.format(root.size))"
    }

    // MARK: - Wedge model

    struct Wedge: Identifiable, Sendable {
        let id = UUID()
        let node: FileNode
        let depth: Int
        let startAngle: Double   // degrees
        let endAngle: Double
        /// Top-level branch index into `Theme.sunburstColors`; nil for slivers.
        let palette: Int?
    }
}

extension SunburstChart {
    /// Offscreen automation renders a bare tree (see `DebugAutomation`). It
    /// builds its own snapshot; the app passes the shared one.
    init(root: FileNode?, contentRevision: UInt64, hoveredNode: FileNode?, selectedNode: FileNode?,
         onHover: @escaping (FileNode?) -> Void, onSelect: @escaping (FileNode?) -> Void,
         onZoomIn: @escaping (FileNode) -> Void, onZoomOut: @escaping () -> Void,
         onAddToCollector: @escaping (FileNode) -> Void, onRevealInFinder: @escaping (FileNode) -> Void,
         drag: CollectorDragController, onDrop: @escaping (FileNode) -> Void) {
        let map = root.flatMap {
            MapSnapshot.build(folder: $0, revision: ScanTreeRevision(rootID: $0.id, revision: contentRevision))
        }
        self.init(map: map, hoveredNode: hoveredNode, selectedNode: selectedNode,
                  onHover: onHover, onSelect: onSelect, onZoomIn: onZoomIn, onZoomOut: onZoomOut,
                  onAddToCollector: onAddToCollector, onRevealInFinder: onRevealInFinder,
                  onQuickLook: { _ in }, drag: drag, onDrop: onDrop)
    }
}
