import SwiftUI
import AppKit

// MARK: - SunburstChart

/// Pure-Canvas sunburst (ring chart) that renders up to five rings around a
/// central glass hub. Layout is precomputed when `root` or the available size
/// changes; only hover/selection state varies per frame.
struct SunburstChart: View {
    let root: FileNode?
    let hoveredNode: FileNode?
    let selectedNode: FileNode?
    let onHover: (FileNode?) -> Void
    let onSelect: (FileNode?) -> Void
    let onZoomIn: (FileNode) -> Void
    let onZoomOut: () -> Void
    let onAddToCollector: (FileNode) -> Void
    let onRevealInFinder: (FileNode) -> Void

    // Tuning constants
    private static let maxRings = 5
    private static let hubFraction: CGFloat = 0.17
    private static let minWedgeDegrees: Double = 0.7
    private static let aggregateFraction: Double = 0.004   // 0.4 %
    private static let gapDegrees: Double = 1.2
    private static let maxWedgesPerRing = 60
    private static let ringInset: CGFloat = 1.5            // hairline separation

    // Cached layout, recomputed only on root/size change.
    @State private var layout: [Wedge] = []
    @State private var layoutSize: CGSize = .zero
    @State private var layoutRootID: UUID?
    @State private var appearProgress: Double = 0          // 0…1 sweep-in
    @State private var cursor: CGPoint = .zero
    @State private var hovering = false
    /// This view's frame in window coordinates, used to convert global
    /// right-click events into local space.
    @State private var windowFrame: CGRect = .zero
    /// Measured tooltip size for accurate edge clamping.
    @State private var tooltipSize: CGSize = .zero
    /// Local NSEvent monitor for right-clicks; removed on disappear.
    @State private var rightClickMonitor: Any?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let chartRadius = side / 2 * 0.96
            let hubRadius = chartRadius * Self.hubFraction

            ZStack {
                canvas(center: center, chartRadius: chartRadius, hubRadius: hubRadius)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p):
                            cursor = p
                            hovering = true
                            updateHover(at: p, center: center,
                                        chartRadius: chartRadius, hubRadius: hubRadius)
                        case .ended:
                            hovering = false
                            onHover(nil)
                        }
                    }
                    .gesture(clickGesture(center: center, chartRadius: chartRadius,
                                          hubRadius: hubRadius))
                    .contextMenu { contextMenuItems(center: center, chartRadius: chartRadius,
                                                    hubRadius: hubRadius) }

                hub(center: center, radius: hubRadius)

                if hovering, let node = hoveredNode {
                    tooltip(for: node, in: geo.size)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { windowFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, f in windowFrame = f }
                }
            )
            .onAppear {
                rebuild(size: geo.size)
                installRightClickMonitor()
            }
            .onDisappear { removeRightClickMonitor() }
            .onChange(of: geo.size) { _, s in rebuild(size: s) }
            .onChange(of: root?.id) { _, _ in rebuild(size: geo.size) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Canvas

    private func canvas(center: CGPoint, chartRadius: CGFloat, hubRadius: CGFloat) -> some View {
        let ringSpan = (chartRadius - hubRadius) / CGFloat(Self.maxRings)
        // Fall back to a fresh layout when the cache hasn't been primed yet
        // (e.g. offscreen rendering where onAppear never fires).
        let cachePrimed = layoutRootID == root?.id && !layout.isEmpty
        let wedges = cachePrimed ? layout : root.map { Self.buildLayout(root: $0) } ?? []
        let progress = cachePrimed ? appearProgress : 1.0
        return Canvas { ctx, _ in
            for wedge in wedges {
                let inner = hubRadius + CGFloat(wedge.depth) * ringSpan + Self.ringInset
                let outer = hubRadius + CGFloat(wedge.depth + 1) * ringSpan - Self.ringInset
                let isHovered = wedge.node.id == hoveredNode?.id

                // Sweep-in: scale the swept angle by appearProgress.
                let start = wedge.startAngle
                let end = start + (wedge.endAngle - wedge.startAngle) * progress
                guard end - start > 0.0001 else { continue }

                // Hit-testing and drawing share identical geometry — no radial
                // pop. Hover is conveyed purely via fill brightening and a glow
                // stroke so clicks always land on the wedge under the cursor.
                let path = wedgePath(center: center,
                                     inner: inner, outer: outer,
                                     start: start, end: end)

                ctx.fill(path, with: .style(fill(for: wedge)))

                if isHovered {
                    ctx.fill(path, with: .color(.white.opacity(0.28)))
                    ctx.stroke(path, with: .color(.white.opacity(0.85)),
                               style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
                if wedge.node.id == selectedNode?.id {
                    ctx.stroke(path, with: .color(.white.opacity(0.9)),
                               style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: hoveredNode?.id)
        .animation(.easeInOut(duration: 0.35), value: layoutRootID)
    }

    private func fill(for wedge: Wedge) -> AnyShapeStyle {
        switch wedge.node.kind {
        case .hiddenSpace: return AnyShapeStyle(Theme.hiddenSpaceColor)
        case .aggregate:   return AnyShapeStyle(Theme.aggregateColor)
        case .regular, .package:
            return Theme.wedgeGradient(hue: wedge.hue, depth: wedge.depth)
        }
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

    private func hub(center: CGPoint, radius: CGFloat) -> some View {
        let node = root
        return VStack(spacing: 2) {
            if isZoomed {
                Image(systemName: "chevron.up")
                    .font(.system(size: max(9, radius * 0.18), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(node?.name ?? "—")
                .font(.system(size: max(10, radius * 0.20), weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(Theme.format(node?.size ?? 0))
                .font(.system(size: max(9, radius * 0.17), weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(radius * 0.18)
        .frame(width: radius * 2, height: radius * 2)
        .glassEffect(.regular.interactive(), in: Circle())
        .position(center)
        .contentShape(Circle())
        .onTapGesture { if isZoomed { onZoomOut() } }
        .help(isZoomed ? "Zoom out" : "")
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 240, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func clickGesture(center: CGPoint, chartRadius: CGFloat,
                              hubRadius: CGFloat) -> some Gesture {
        SpatialTapGesture().onEnded { value in
            guard let wedge = hitTest(at: value.location, center: center,
                                      chartRadius: chartRadius, hubRadius: hubRadius) else {
                onSelect(nil); return
            }
            if wedge.node.isSynthetic {
                // Synthetic wedges ("Other" / hidden space) aren't real files;
                // tapping them is a no-op selection.
                onSelect(nil)
            } else if wedge.node.isDirectory {
                onZoomIn(wedge.node)
            } else {
                onSelect(wedge.node)
            }
        }
    }

    @ViewBuilder
    private func contextMenuItems(center: CGPoint, chartRadius: CGFloat,
                                  hubRadius: CGFloat) -> some View {
        let node = hitTest(at: cursor, center: center,
                           chartRadius: chartRadius, hubRadius: hubRadius)?.node
        if let node, !node.isSynthetic {
            Button("Add to Collector") { onAddToCollector(node) }
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
            if let local = localPoint(for: event) {
                cursor = local
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
        let dx = p.x - center.x, dy = p.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        guard r >= hubRadius, r <= chartRadius else { return nil }
        let ringSpan = (chartRadius - hubRadius) / CGFloat(Self.maxRings)
        let depth = Int((r - hubRadius) / ringSpan)
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

    private func rebuild(size: CGSize) {
        guard let root, size.width > 1, size.height > 1 else {
            layout = []; return
        }
        let same = layoutRootID == root.id && layoutSize == size
        layout = Self.buildLayout(root: root)
        layoutSize = size
        if !same {
            layoutRootID = root.id
            appearProgress = 0
            withAnimation(.easeInOut(duration: 0.35)) { appearProgress = 1 }
        } else {
            appearProgress = 1
        }
    }

    /// Walk the tree breadth-by-depth, allocating angular spans proportional to
    /// size, aggregating tiny siblings into a synthetic "Other" wedge.
    static func buildLayout(root: FileNode) -> [Wedge] {
        var out: [Wedge] = []

        func recurse(parent: FileNode, depth: Int, start: Double, sweep: Double,
                     hue: Double, inheritHue: Bool) {
            guard depth < maxRings else { return }
            let kids = parent.sortedChildren
            guard !kids.isEmpty else { return }
            let parentSize = max(1, Double(parent.size))

            // Fold tiny children into a single synthetic "Other" wedge — at EVERY
            // depth, not just the root ring. The threshold is relative to the
            // parent's size (which equals the root total at depth 0, so the top
            // ring is unchanged). Without this, a directory with hundreds of small
            // children (e.g. an iCloud .Trash) spends its whole sweep on
            // inter-wedge gaps and renders nothing (usable <= 0).
            var visible: [FileNode] = []
            var aggregateSize: Int64 = 0
            for k in kids {
                if Double(k.size) / parentSize < aggregateFraction {
                    aggregateSize += k.size
                } else {
                    visible.append(k)
                }
            }
            // Hard cap on real wedges per ring; fold the remainder into "Other".
            // Bounds the gap budget and per-frame work regardless of fan-out.
            if visible.count > maxWedgesPerRing {
                for extra in visible[maxWedgesPerRing...] { aggregateSize += extra.size }
                visible = Array(visible.prefix(maxWedgesPerRing))
            }
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
                    let childHue: Double
                    if depth == 0 {
                        childHue = Theme.topHues[i % Theme.topHues.count]
                    } else {
                        // inherit with a small per-sibling drift
                        let drift = (Double(i) - Double(n - 1) / 2) * 0.012
                        childHue = (hue + drift).truncatingRemainder(dividingBy: 1).magnitude
                    }
                    let wedge = Wedge(node: entry.node, depth: depth,
                                      startAngle: cursor, endAngle: cursor + span, hue: childHue)
                    out.append(wedge)
                    if entry.node.isDirectory && !entry.node.isSynthetic {
                        recurse(parent: entry.node, depth: depth + 1,
                                start: cursor, sweep: span, hue: childHue, inheritHue: true)
                    }
                }
                cursor += span + gap
            }
        }

        // Start at -90° so the first wedge begins at the top.
        recurse(parent: root, depth: 0, start: -90, sweep: 360,
                hue: 0, inheritHue: false)
        return out
    }

    private var accessibilitySummary: String {
        guard let root else { return "Sunburst chart, no data" }
        return "Sunburst chart of \(root.name), total size \(Theme.format(root.size))"
    }

    // MARK: - Wedge model

    struct Wedge: Identifiable {
        let id = UUID()
        let node: FileNode
        let depth: Int
        let startAngle: Double   // degrees
        let endAngle: Double
        let hue: Double
    }
}
