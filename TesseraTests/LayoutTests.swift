import Testing
import Foundation
@testable import Tessera

// MARK: - Sunburst layout

@Suite("Sunburst Layout Tests")
@MainActor
struct LayoutTests {

    /// Regression: a directory with hundreds of small children used to render NO
    /// nested ring at all. Aggregation into "Other" was gated on `depth == 0`, so
    /// at depth >= 1 every child stayed "visible"; the per-wedge gaps then summed
    /// past the parent's sweep and `usable` collapsed to 0, dropping the entire
    /// sub-ring (this is exactly why an iCloud `.Trash` wedge showed nothing
    /// inside it). The fix aggregates tiny children at every depth and clamps the
    /// gap budget, so large grandchildren and an "Other" wedge still render.
    @Test("A deep directory with hundreds of small children still renders its nested ring")
    func deepFanOutStillRendersNestedRing() {
        let base = URL(fileURLWithPath: "/tmp/layout-fanout")

        let root = FileNode(url: base, name: "root", isDirectory: true, size: 0)

        // The dominant directory: two large children plus 300 tiny ones. The
        // tiny ones are each < 0.4 % of the parent (so they aggregate), but in
        // aggregate they dominate the child count — enough to blow the gap budget
        // under the old logic.
        let dominant = FileNode(url: base.appendingPathComponent("dominant"),
                                name: "dominant", isDirectory: true, size: 0)
        let bigA = FileNode(url: base.appendingPathComponent("dominant/bigA"),
                            name: "bigA", isDirectory: false, size: 40)
        let bigB = FileNode(url: base.appendingPathComponent("dominant/bigB"),
                            name: "bigB", isDirectory: false, size: 40)
        var dominantChildren = [bigA, bigB]
        for i in 0 ..< 300 {
            dominantChildren.append(
                FileNode(url: base.appendingPathComponent("dominant/tiny\(i)"),
                         name: "tiny\(i)", isDirectory: false, size: 1))
        }
        dominant.setChildren(dominantChildren)

        // A small sibling so `dominant` is ~95 % of the root (its sweep is large).
        let sibling = FileNode(url: base.appendingPathComponent("sibling"),
                               name: "sibling", isDirectory: false, size: 20)

        root.setChildren([dominant, sibling])
        root.recomputeDirectorySizes()

        let wedges = SunburstChart.buildLayout(root: root)
        let depth1 = wedges.filter { $0.depth == 1 }

        #expect(depth1.contains { $0.node.name == "bigA" },
                "Large grandchild bigA must render as a depth-1 wedge")
        #expect(depth1.contains { $0.node.name == "bigB" },
                "Large grandchild bigB must render as a depth-1 wedge")
        #expect(depth1.contains { $0.node.kind == .aggregate },
                "The 300 tiny children must collapse into an 'Other' wedge, not vanish")
    }

    /// All wedge angles must be finite and ordered; no NaN/inf can reach Canvas.
    @Test("Every wedge has finite, ordered angles")
    func wedgeAnglesAreFinite() {
        let base = URL(fileURLWithPath: "/tmp/layout-angles")
        let root = FileNode(url: base, name: "root", isDirectory: true, size: 0)
        let dir = FileNode(url: base.appendingPathComponent("d"),
                           name: "d", isDirectory: true, size: 0)
        let f1 = FileNode(url: base.appendingPathComponent("d/f1"),
                          name: "f1", isDirectory: false, size: 300)
        let f2 = FileNode(url: base.appendingPathComponent("d/f2"),
                          name: "f2", isDirectory: false, size: 700)
        dir.setChildren([f1, f2])
        root.setChildren([dir])
        root.recomputeDirectorySizes()

        for w in SunburstChart.buildLayout(root: root) {
            #expect(w.startAngle.isFinite && w.endAngle.isFinite)
            #expect(w.endAngle >= w.startAngle)
        }
    }

    // MARK: - Hit-testing

    private func chartGeometry(for size: CGSize)
        -> (center: CGPoint, chartRadius: CGFloat, hubRadius: CGFloat, ringSpan: CGFloat) {
        guard let geometry = SunburstChart.chartGeometry(for: size) else {
            Issue.record("Expected renderable chart geometry for \(size)")
            return (.zero, 0, 0, 0)
        }
        return (geometry.center, geometry.chartRadius,
                geometry.hubRadius, geometry.ringSpan)
    }

    @Test("Chart follows the smaller window dimension in portrait, landscape, and square layouts")
    func chartGeometryIsResponsive() {
        let landscape = SunburstChart.chartGeometry(for: CGSize(width: 900, height: 300))
        let portrait = SunburstChart.chartGeometry(for: CGSize(width: 300, height: 900))
        let square = SunburstChart.chartGeometry(for: CGSize(width: 300, height: 300))

        #expect(landscape != nil && portrait != nil && square != nil)
        #expect(landscape?.chartRadius == portrait?.chartRadius)
        #expect(portrait?.chartRadius == square?.chartRadius)
        #expect(landscape?.center == CGPoint(x: 450, y: 150))
        #expect(portrait?.center == CGPoint(x: 150, y: 450))
    }

    @Test("Transient zero and tiny layouts do not create invalid chart geometry or hit-test traps")
    func invalidChartGeometryIsRejected() {
        #expect(SunburstChart.chartGeometry(for: .zero) == nil)
        #expect(SunburstChart.chartGeometry(for: CGSize(width: 40, height: 400)) == nil)
        #expect(SunburstChart.hitTest(in: [], at: .zero, center: .zero,
                                     chartRadius: 0, hubRadius: 0) == nil)
        #expect(SunburstChart.hitTest(in: [], at: .zero, center: .zero,
                                     chartRadius: .nan, hubRadius: 0) == nil)
    }

    private func multiRingRoot() -> FileNode {
        let base = URL(fileURLWithPath: "/tmp/layout-hittest")
        let root = FileNode(url: base, name: "root", isDirectory: true, size: 0)
        var tops: [FileNode] = []
        for d in 0 ..< 5 {
            let dir = FileNode(url: base.appendingPathComponent("d\(d)"),
                               name: "d\(d)", isDirectory: true, size: 0)
            var kids: [FileNode] = []
            for c in 0 ..< 4 {
                let sub = FileNode(url: base.appendingPathComponent("d\(d)/c\(c)"),
                                   name: "c\(c)", isDirectory: true, size: 0)
                let leaf = FileNode(url: base.appendingPathComponent("d\(d)/c\(c)/leaf"),
                                    name: "leaf", isDirectory: false, size: Int64(120 + c * 40))
                sub.setChildren([leaf])
                kids.append(sub)
            }
            dir.setChildren(kids)
            tops.append(dir)
        }
        root.setChildren(tops)
        root.recomputeDirectorySizes()
        return root
    }

    /// The drawing geometry and the hit-test geometry must agree: a click on the
    /// angular/radial midpoint of any rendered wedge must resolve back to that
    /// exact wedge. This is what makes the chart clickable — the regression the
    /// `.position`'d interactive-glass hub used to mask by swallowing all events.
    @Test("Every wedge's midpoint hit-tests back to itself")
    func clickMapsToWedge() {
        let root = multiRingRoot()
        let wedges = SunburstChart.buildLayout(root: root)
        #expect(!wedges.isEmpty)

        let g = chartGeometry(for: CGSize(width: 800, height: 800))

        for w in wedges {
            let midDeg = (w.startAngle + w.endAngle) / 2
            let midRad = midDeg * .pi / 180
            let radius = g.hubRadius + (CGFloat(w.depth) + 0.5) * g.ringSpan
            let p = CGPoint(x: g.center.x + cos(midRad) * radius,
                            y: g.center.y + sin(midRad) * radius)
            let hit = SunburstChart.hitTest(in: wedges, at: p, center: g.center,
                                            chartRadius: g.chartRadius, hubRadius: g.hubRadius)
            #expect(hit?.id == w.id,
                    "midpoint of '\(w.node.name)' (depth \(w.depth)) should hit itself, got '\(hit?.node.name ?? "nil")'")
        }
    }

    /// Points in the central hub hole and beyond the outer rim hit nothing, so a
    /// click there clears the selection rather than mis-selecting an edge wedge.
    @Test("Hub hole and area beyond the rim hit nothing")
    func hitTestMissesHubAndBeyondRim() {
        let root = multiRingRoot()
        let wedges = SunburstChart.buildLayout(root: root)
        let g = chartGeometry(for: CGSize(width: 800, height: 800))

        // Dead centre — inside the hub hole.
        #expect(SunburstChart.hitTest(in: wedges, at: g.center, center: g.center,
                                      chartRadius: g.chartRadius, hubRadius: g.hubRadius) == nil)
        // Just inside the hub radius.
        let nearCentre = CGPoint(x: g.center.x + g.hubRadius * 0.5, y: g.center.y)
        #expect(SunburstChart.hitTest(in: wedges, at: nearCentre, center: g.center,
                                      chartRadius: g.chartRadius, hubRadius: g.hubRadius) == nil)
        // Beyond the outer rim.
        let beyond = CGPoint(x: g.center.x + g.chartRadius + 20, y: g.center.y)
        #expect(SunburstChart.hitTest(in: wedges, at: beyond, center: g.center,
                                      chartRadius: g.chartRadius, hubRadius: g.hubRadius) == nil)
    }
}
