import SwiftUI

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
    private static let ringInset: CGFloat = 1.5            // hairline separation
    private static let hoverPop: CGFloat = 3.0

    // Cached layout, recomputed only on root/size change.
    @State private var layout: [Wedge] = []
    @State private var layoutSize: CGSize = .zero
    @State private var layoutRootID: UUID?
    @State private var appearProgress: Double = 0          // 0…1 sweep-in
    @State private var cursor: CGPoint = .zero
    @State private var hovering = false

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
            .onAppear { rebuild(size: geo.size) }
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
                let pop: CGFloat = isHovered ? Self.hoverPop : 0

                // Sweep-in: scale the swept angle by appearProgress.
                let start = wedge.startAngle
                let end = start + (wedge.endAngle - wedge.startAngle) * progress
                guard end - start > 0.0001 else { continue }

                let path = wedgePath(center: center,
                                     inner: inner + pop, outer: outer + pop,
                                     start: start, end: end)

                ctx.fill(path, with: .style(fill(for: wedge)))

                if isHovered {
                    ctx.fill(path, with: .color(.white.opacity(0.18)))
                    ctx.stroke(path, with: .color(.white.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1, lineJoin: .round))
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
        .position(tooltipPosition(in: size))
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func tooltipPosition(in size: CGSize) -> CGPoint {
        let w: CGFloat = 130, h: CGFloat = 44
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
            if wedge.node.isDirectory && !wedge.node.isSynthetic {
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
        Button("Add to Collector") { if let node { onAddToCollector(node) } }
            .disabled(node?.isSynthetic ?? true)
        Button("Reveal in Finder") { if let node { onRevealInFinder(node) } }
            .disabled(node?.isSynthetic ?? true)
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
        let total = max(1, Double(root.size))

        func recurse(parent: FileNode, depth: Int, start: Double, sweep: Double,
                     hue: Double, inheritHue: Bool) {
            guard depth < maxRings else { return }
            let kids = parent.sortedChildren
            guard !kids.isEmpty else { return }
            let parentSize = max(1, Double(parent.size))

            // Aggregate tiny children (relative to the CURRENT ROOT) into "Other".
            var visible: [FileNode] = []
            var aggregateSize: Int64 = 0
            for k in kids {
                if depth == 0 && Double(k.size) / total < aggregateFraction {
                    aggregateSize += k.size
                } else {
                    visible.append(k)
                }
            }
            var entries: [(node: FileNode, size: Int64)] = visible.map { ($0, $0.size) }
            if aggregateSize > 0 {
                let other = FileNode(url: parent.url, name: "Other",
                                     isDirectory: false, size: aggregateSize, kind: .aggregate)
                entries.append((other, aggregateSize))
            }

            let n = entries.count
            let gaps = gapDegrees * Double(n)
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
                cursor += span + gapDegrees
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
