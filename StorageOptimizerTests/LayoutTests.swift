import Testing
import Foundation
@testable import StorageOptimizer

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
}
