import AppKit
import Foundation

// MARK: - Wedge layout

struct WedgeLayout {
    let node: FileNode
    let depth: Int          // 0 = innermost ring
    /// Angles in "clockwise-from-north" radians (0 = top, π/2 = right, π = bottom, 3π/2 = left)
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let color: NSColor

    var angularSpan: Double { endAngle - startAngle }

    /// Convert a "clockwise-from-north" angle to Core Graphics math angle (counter-clockwise from east).
    static func cgAngle(_ a: Double) -> CGFloat { CGFloat(Double.pi / 2 - a) }

    var cgStart: CGFloat { WedgeLayout.cgAngle(startAngle) }
    var cgEnd:   CGFloat { WedgeLayout.cgAngle(endAngle) }

    func contains(point: CGPoint, center: CGPoint) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        guard radius >= innerRadius && radius < outerRadius else { return false }

        // Convert point angle to clockwise-from-north
        var mathAngle = atan2(Double(dy), Double(dx))          // CG math angle
        var cwAngle = Double.pi / 2 - mathAngle                 // clockwise-from-north
        // Normalise to [0, 2π)
        cwAngle = cwAngle.truncatingRemainder(dividingBy: 2 * .pi)
        if cwAngle < 0 { cwAngle += 2 * .pi }

        return cwAngle >= startAngle && cwAngle < endAngle
    }
}

// MARK: - Callbacks

typealias NodeCallback = (FileNode?) -> Void

// MARK: - SunburstNSView

final class SunburstNSView: NSView {
    // Public inputs
    var root: FileNode? { didSet { recompute() } }
    var highlightedNode: FileNode? { didSet { needsDisplay = true } }

    // Callbacks (set by the Representable coordinator)
    var onHover: NodeCallback = { _ in }
    var onSelect: NodeCallback = { _ in }
    var onZoom: NodeCallback = { _ in }

    // Derived layout
    private var wedges: [WedgeLayout] = []
    private var center: CGPoint = .zero

    // Geometry constants (proportional to view size)
    private var centerRadius: CGFloat { min(bounds.width, bounds.height) * 0.08 }
    private var maxRadius:    CGFloat { min(bounds.width, bounds.height) * 0.46 }
    private let maxDepth = 4
    private let minAngularSpan = 2 * Double.pi / 360   // 1 degree minimum wedge

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    private func setup() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = CGColor.clear
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self, userInfo: nil
        ))
    }

    // MARK: - Layout computation

    private func recompute() {
        wedges = []
        guard let root else { needsDisplay = true; return }
        let ringWidth = (maxRadius - centerRadius) / CGFloat(maxDepth)
        computeWedges(
            node: root,
            startAngle: 0,
            endAngle: 2 * .pi,
            depth: 0,
            ringWidth: ringWidth,
            hueBase: nil
        )
        needsDisplay = true
    }

    private func computeWedges(
        node: FileNode,
        startAngle: Double,
        endAngle: Double,
        depth: Int,
        ringWidth: CGFloat,
        hueBase: CGFloat?
    ) {
        guard depth < maxDepth, node.size > 0 else { return }
        let inner = centerRadius + CGFloat(depth) * ringWidth
        let outer = inner + ringWidth - 1

        var children = node.sortedChildren.filter { $0.size > 0 }
        // Aggregate tiny children into "Other"
        let threshold = node.size / 200   // < 0.5% → other
        var visible: [FileNode] = []
        var otherSize: Int64 = 0
        for child in children {
            if child.size >= threshold {
                visible.append(child)
            } else {
                otherSize += child.size
            }
        }
        if otherSize > 0 {
            visible.append(FileNode(url: node.url, name: "Other", isDirectory: false, size: otherSize))
        }
        children = visible

        let parentSpan = endAngle - startAngle
        var current = startAngle
        let totalSize = children.reduce(0) { $0 + $1.size }

        for (i, child) in children.enumerated() {
            let fraction = Double(child.size) / Double(max(totalSize, 1))
            let span = fraction * parentSpan
            guard span >= minAngularSpan else { current += span; continue }

            let hue: CGFloat
            if let base = hueBase {
                // Slightly shift each sibling from its parent hue for variety
                hue = (base + CGFloat(i) * 0.03).truncatingRemainder(dividingBy: 1)
            } else {
                // Top level: use the curated Apple-palette hues evenly spaced
                let palette = SunburstNSView.topHues
                hue = palette[i % palette.count]
            }
            let color = colorFor(node: child, depth: depth, hue: hue)

            wedges.append(WedgeLayout(
                node: child,
                depth: depth,
                startAngle: current,
                endAngle: current + span,
                innerRadius: inner,
                outerRadius: outer,
                color: color
            ))

            computeWedges(
                node: child,
                startAngle: current,
                endAngle: current + span,
                depth: depth + 1,
                ringWidth: ringWidth,
                hueBase: hue
            )
            current += span
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Clear so prior frame doesn't bleed through on redraw
        ctx.clear(bounds)

        // Wedges
        for wedge in wedges {
            drawWedge(wedge, ctx: ctx, highlighted: wedge.node.id == highlightedNode?.id)
        }

        // Center disc
        drawCenterDisc(ctx: ctx)
    }

    private func drawWedge(_ wedge: WedgeLayout, ctx: CGContext, highlighted: Bool) {
        let path = CGMutablePath()
        path.addArc(center: center, radius: wedge.outerRadius,
                    startAngle: wedge.cgStart, endAngle: wedge.cgEnd, clockwise: true)
        path.addArc(center: center, radius: wedge.innerRadius,
                    startAngle: wedge.cgEnd, endAngle: wedge.cgStart, clockwise: false)
        path.closeSubpath()

        let fillColor: NSColor
        if highlighted {
            fillColor = wedge.color.blended(withFraction: 0.25, of: .white) ?? wedge.color
        } else {
            fillColor = wedge.color
        }
        ctx.setFillColor(fillColor.cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        // Separator stroke
        ctx.setStrokeColor(NSColor.windowBackgroundColor.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private func drawCenterDisc(ctx: CGContext) {
        guard let root else { return }
        let r = centerRadius
        let discRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

        // Frosted disc
        ctx.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor)
        ctx.fillEllipse(in: discRect)
        ctx.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: discRect)

        // Size label
        let sizeStr = ByteCountFormatter.string(fromByteCount: root.size, countStyle: .file)
        let fontSize = max(9, r * 0.26)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: sizeStr, attributes: attrs)
        let strSize = str.size()
        str.draw(in: CGRect(
            x: center.x - strSize.width / 2,
            y: center.y - strSize.height / 2,
            width: strSize.width, height: strSize.height
        ))

        // Root name label (smaller, below size)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(7, fontSize * 0.75), weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let nameStr = NSAttributedString(string: root.name, attributes: nameAttrs)
        let nameSize = nameStr.size()
        nameStr.draw(in: CGRect(
            x: center.x - nameSize.width / 2,
            y: center.y - strSize.height / 2 - nameSize.height - 1,
            width: nameSize.width, height: nameSize.height
        ))
    }

    // MARK: - Mouse events

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = wedgeAt(point: point)
        onHover(hit?.node)
    }

    override func mouseExited(with event: NSEvent) { onHover(nil) }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = wedgeAt(point: point) else {
            // Click on center disc → zoom out
            onZoom(nil)
            return
        }
        onSelect(hit.node)
        if hit.node.isDirectory {
            onZoom(hit.node)
        }
    }

    // Right-click → add to collector
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let hit = wedgeAt(point: point) {
            onSelect(hit.node)
        }
    }

    private func wedgeAt(point: CGPoint) -> WedgeLayout? {
        wedges.last(where: { $0.contains(point: point, center: center) })
    }

    // MARK: - Resize

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        recompute()
    }

    // MARK: - Colors

    // Vivid Apple-palette style: high saturation at depth 0, desaturating and darkening slightly inward.
    // Uses system accent-aware colours at depth 0 to feel native.
    private static let topHues: [CGFloat] = [
        0.02,  // red-orange
        0.08,  // orange
        0.14,  // amber
        0.25,  // yellow-green
        0.36,  // green
        0.48,  // teal
        0.57,  // cyan-blue
        0.63,  // blue
        0.71,  // indigo
        0.80,  // purple
        0.88,  // magenta
        0.94,  // pink-red
    ]

    private func colorFor(node: FileNode, depth: Int, hue: CGFloat) -> NSColor {
        if node.name == "Other" {
            return NSColor(white: 0.55, alpha: 0.7)
        }
        let saturation: CGFloat = max(0.40, 0.82 - CGFloat(depth) * 0.10)
        let brightness:  CGFloat = max(0.50, 0.92 - CGFloat(depth) * 0.09)
        return NSColor(hue: hue.truncatingRemainder(dividingBy: 1),
                       saturation: saturation,
                       brightness: brightness,
                       alpha: 1)
    }
}
