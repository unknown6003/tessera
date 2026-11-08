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

// MARK: - Cleanup List

struct CollectorDock: View {
    @ObservedObject var vm: ScanViewModel
    @ObservedObject var drag: CollectorDragController
    var onReview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: drag.isOverCollector ? "plus.circle.fill" : "checklist")
                .font(.title3).foregroundStyle(Theme.electricBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cleanup List").font(.subheadline.weight(.semibold))
                Text(vm.collector.isEmpty ? "Drop a map item here to review it." :
                     "\(Theme.itemCount(vm.collector.count)) · \(Theme.format(vm.collectorTotalSize)) allocated")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if vm.isDeleting {
                ProgressView(value: Double(vm.deletionProgress), total: Double(max(1, vm.deletionTotal)))
                    .frame(width: 120)
                    .accessibilityLabel("Removing items")
                    .accessibilityValue("\(vm.deletionProgress) of \(vm.deletionTotal)")
            } else {
                Button("Review list…", action: onReview)
                    .buttonStyle(.flatProminent)
                    .disabled(vm.collector.isEmpty || vm.isScanning)
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(drag.isOverCollector ? Theme.selectionTint : Theme.surface)
        .overlay(alignment: .top) {
            if drag.isOverCollector { Rectangle().fill(Theme.electricBlue).frame(height: 2) }
        }
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(CollectorDragController.appSpace))
        } action: { drag.setCollectorFrame($0) }
        .onDisappear { drag.setCollectorFrame(.zero) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cleanup List drop target")
    }
}

/// The review uses one source and one scan. A rescan cannot silently replace
/// paths in the open sheet. Removals update both the review and staged list.
struct CleanupReviewSheet: View {
    private struct Item: Identifiable {
        let node: FileNode
        let path: String
        let bytes: Int64
        var id: ObjectIdentifier { node.id }
    }

    @ObservedObject var vm: ScanViewModel
    let sourcePath: String
    let rootID: ObjectIdentifier?
    let revision: UInt64
    var onTrash: ([FileNode]) -> Void
    var onDelete: ([FileNode]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Item]
    @State private var reviewedCollectorIDs: Set<ObjectIdentifier>

    init(vm: ScanViewModel, nodes: [FileNode], sourcePath: String,
         rootID: ObjectIdentifier?, revision: UInt64, onTrash: @escaping ([FileNode]) -> Void,
         onDelete: @escaping ([FileNode]) -> Void) {
        self.vm = vm
        self.sourcePath = sourcePath
        self.rootID = rootID
        self.revision = revision
        self.onTrash = onTrash
        self.onDelete = onDelete
        _items = State(initialValue: nodes.map { Item(node: $0, path: $0.url.path, bytes: $0.physicalSize) })
        _reviewedCollectorIDs = State(initialValue: Set(nodes.map(\.id)))
    }

    private var isCurrent: Bool {
        !vm.isScanning && !vm.isDeleting
            && vm.scannedURL?.standardizedFileURL.path == sourcePath
            && vm.rootNode?.id == rootID
            && vm.chartRevision == revision
            && Set(vm.collector.map(\.id)) == reviewedCollectorIDs
    }

    private var total: Int64 { items.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Review Cleanup List").font(.title2.weight(.semibold))
                    Spacer()
                    Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                }
                Text(sourcePath).font(.caption.monospaced()).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("Check every path. Removing an item from this list keeps its file in place.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(24)
            Divider()
            if !isCurrent {
                Label("The scan or list changed. Close this sheet and review the current list.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.subheadline).padding(20)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: Theme.icon(for: item.node)).foregroundStyle(.secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.node.name).font(.body.weight(.medium))
                                Text(item.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                                if let recommendation = vm.rescuePlan?.recommendations.first(where: { $0.node.id == item.id }) {
                                    Text("\(recommendation.risk.title) · \(recommendation.reason)")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Theme.format(item.bytes)).font(.subheadline.monospacedDigit())
                                .fixedSize()
                            Button {
                                vm.removeFromCollector(item.node)
                                items.removeAll { $0.id == item.id }
                                reviewedCollectorIDs.remove(item.id)
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(item.node.name) from Cleanup List")
                            .disabled(!isCurrent)
                        }
                        .padding(.vertical, 16)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.node.url])
                            }
                        }
                        Divider()
                    }
                    if items.isEmpty {
                        Text("The Cleanup List is empty.").foregroundStyle(.secondary).padding(32)
                    }
                }
                .padding(.horizontal, 24)
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Theme.itemCount(items.count)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Theme.format(total)) allocated").font(.headline.monospacedDigit())
                }
                Text("Finder Trash is recoverable. Moving files to Trash does not free disk space until Trash is emptied.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Menu("More") {
                        Button("Empty list") {
                            vm.clearCollector()
                            items = []
                            reviewedCollectorIDs = []
                        }
                        Divider()
                        Button("Delete Permanently…", role: .destructive) { onDelete(items.map(\.node)) }
                    }
                    .fixedSize()
                    Spacer()
                    Button("Move to Trash…") { onTrash(items.map(\.node)) }
                        .buttonStyle(.flatProminent)
                }
                .disabled(!isCurrent || items.isEmpty)
            }
            .padding(24)
        }
        .frame(width: 700, height: 620)
        .background(Theme.bg)
    }
}

// MARK: - Flow layout

/// Shared wrapping layout for compact tool controls.
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
        .foregroundStyle(Theme.brandInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 240)
        .background(Theme.electricBlue, in: Capsule())
        // Flat: a neutral drop shadow for lift, never a colored glow.
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        .allowsHitTesting(false)
    }
}
