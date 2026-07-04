import SwiftUI
import AppKit

// MARK: - Drag & drop plumbing

/// Shared state for dragging a chart wedge into the bottom collector dock.
///
/// Owned by `ContentView`, observed by the chart (which drives the drag) and the
/// dock (which highlights itself when the cursor is over it). All coordinates live
/// in the `.named(appSpace)` coordinate space so the chart's live drag location and
/// the dock's registered frame are directly comparable.
@MainActor
final class CollectorDragController: ObservableObject {
    /// Name of the shared coordinate space declared once at the app root.
    nonisolated static let appSpace = "app"

    /// The node currently being dragged from the chart, if any.
    @Published private(set) var node: FileNode?
    /// Cursor location (app space) while dragging — drives the floating preview.
    @Published private(set) var location: CGPoint = .zero
    /// Whether the cursor is over the collector, for highlight + drop routing.
    @Published private(set) var isOverCollector = false

    private var collectorFrame: CGRect?

    var isDragging: Bool { node != nil }

    /// The dock registers its frame (app space) here as geometry settles.
    func setCollectorFrame(_ rect: CGRect) { collectorFrame = rect }

    func begin(_ node: FileNode, at point: CGPoint) {
        self.node = node
        self.location = point
        self.isOverCollector = isInsideCollector(point)
    }

    func update(to point: CGPoint) {
        guard node != nil else { return }
        location = point
        isOverCollector = isInsideCollector(point)
    }

    /// Resolve the drop and reset. Returns the node if it landed on the collector,
    /// or nil if it was released elsewhere.
    func end() -> FileNode? {
        defer { reset() }
        guard let node, isInsideCollector(location) else { return nil }
        return node
    }

    func reset() {
        node = nil
        isOverCollector = false
    }

    private func isInsideCollector(_ point: CGPoint) -> Bool {
        collectorFrame?.contains(point) ?? false
    }
}

// MARK: - Collector dock

/// Full-width bottom dock that replaces the old right-side collector. Staged
/// items live here as wrapping chips (each showing where it came from), with
/// "Clear" and "Delete Permanently" buttons. The whole dock is the collector
/// drop target for wedges dragged out of the chart.
struct CollectorDock: View {
    @ObservedObject var vm: ScanViewModel
    @ObservedObject var drag: CollectorDragController
    /// Primary, recoverable action: move the entire collector to the Trash.
    var onTrashAll: () -> Void
    /// Secondary, destructive action: confirm, then permanently delete the
    /// entire collector.
    var onDeleteAll: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    /// Natural height of the wrapped chips, measured so the scroll area grows with
    /// content up to `maxChipsHeight`, then scrolls vertically instead of off-screen.
    @State private var chipsHeight: CGFloat = 0
    private let maxChipsHeight: CGFloat = 160

    var body: some View {
        collectorColumn
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(GlassTuning.cardMaterial, in: shape)
            .overlay {
                // Electric-blue ring when a slice is hovering the collector area.
                shape.strokeBorder(
                    Theme.electricBlue.opacity(drag.isOverCollector ? 0.9 : 0.0),
                    lineWidth: 2
                )
                .animation(.easeOut(duration: 0.12), value: drag.isOverCollector)
            }
            .liquidGlassDepth(shape, shadowRadius: 26, shadowY: 14)
            // Register the whole dock as the collector drop zone.
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named(CollectorDragController.appSpace))
            } action: { drag.setCollectorFrame($0) }
    }

    // MARK: Collector column

    private var collectorColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if vm.collector.isEmpty {
                emptyHint
            } else {
                chips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("COLLECTOR")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)
            if !vm.collector.isEmpty {
                Text("· \(vm.collector.count) · \(Theme.format(vm.collectorTotalSize))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tint)
            }
            Spacer()
            if !vm.collector.isEmpty {
                Button("Clear") { vm.clearCollector() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .font(.caption.weight(.medium))

                // Secondary, irreversible escape hatch — clearly labelled and
                // confirmed before it runs.
                Button(role: .destructive, action: onDeleteAll) {
                    Label("Delete Permanently", systemImage: "trash.slash.fill")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.glass)
                .tint(.red)
                .controlSize(.small)
                .help("Permanently delete — cannot be undone")

                // Primary, recommended action: recoverable from the Finder Trash.
                Button(action: onTrashAll) {
                    Label("Move to Trash", systemImage: "trash.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .help("Move to Trash — restore later from Finder if needed")
            }
        }
    }

    private var emptyHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .foregroundStyle(.tint)
            Text("Drag slices from the chart here to collect them for review, then delete them together.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    }

    private var chips: some View {
        ScrollView(.vertical, showsIndicators: true) {
            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(vm.collector) { node in
                    CollectorChip(node: node) { vm.removeFromCollector(node) }
                }
            }
            .padding(.vertical, 2)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chipsHeight = $0 }
        }
        .frame(height: min(chipsHeight, maxChipsHeight))
    }

}

// MARK: - Collector chip

/// A single staged item, showing its name, source folder ("where it's coming
/// from") and size, with a remove button.
private struct CollectorChip: View {
    let node: FileNode
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: Theme.icon(for: node))
                .font(.subheadline)
                .foregroundStyle(.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(node.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(sourcePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Theme.format(node.size))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tint)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            } label: {
                Image(systemName: "magnifyingglass.circle.fill")
                    .foregroundStyle(.tint)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder to check before deleting")

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .help("Remove from collector")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 240)
        .background {
            let s = RoundedRectangle(cornerRadius: 14, style: .continuous)
            s.fill(.white.opacity(0.06))
                .overlay(s.strokeBorder(Theme.electricBlue.opacity(0.25), lineWidth: 1))
        }
    }

    /// The parent folder, with the home directory abbreviated to `~`.
    private var sourcePath: String {
        let dir = node.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir == home { return "~" }
        if dir.hasPrefix(home + "/") { return "~" + dir.dropFirst(home.count) }
        return dir
    }
}

// MARK: - Flow layout

/// Lays children left-to-right, wrapping to a new row when the next child would
/// overflow the available width. The collector uses this so chips fill out into
/// rows and scroll vertically, instead of running off the right edge in a single
/// endless horizontal strip.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0 && rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + lineSpacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)

        return CGSize(width: maxWidth.isFinite ? maxWidth : widestRow, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Drag preview

/// The floating chip that tracks the cursor while a slice is being dragged.
/// Rendered as an overlay in the app coordinate space by `ContentView`.
struct DragPreview: View {
    let node: FileNode

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: Theme.icon(for: node))
                .font(.subheadline.weight(.semibold))
            Text(node.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(Theme.format(node.size))
                .font(.system(.caption, design: .monospaced))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 240)
        .background {
            let s = Capsule()
            s.fill(Theme.electricBlue.opacity(0.85))
                .overlay(s.strokeBorder(.white.opacity(0.6), lineWidth: 1))
        }
        .shadow(color: Theme.electricBlue.opacity(0.6), radius: 14, y: 6)
        .allowsHitTesting(false)
    }
}
