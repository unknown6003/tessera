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
    var onFinishTrash: (() -> Void)? = nil
    /// The summary the user dismissed, or one from before a source change.
    /// A new removal has a new id, so its result always shows, even when
    /// `isDeleting` changes too fast for SwiftUI to see both values.
    @State private var hiddenSummaryID: UUID?

    /// The dock shows only the removal it just ran. Rescue keeps its own
    /// full-plan verification in the Rescue workspace; its held list can
    /// include risk items the user never selected, so it is never read here.
    /// There is no Undo: Tessera cannot restore files itself.
    private var shownSummary: ScanViewModel.RemovalSummary? {
        guard !vm.isDeleting, let summary = vm.lastRemovalSummary,
              summary.id != hiddenSummaryID else { return nil }
        return summary
    }

    var body: some View {
        // One row. A refusal notice or the last removal's result replaces
        // the hint line inside it, so the bottom of the window never stacks
        // three bars.
        dockRow
            .background(drag.isOverCollector ? Theme.selectionTint : Theme.surface)
            .onChange(of: vm.scannedURL) { _, _ in hiddenSummaryID = vm.lastRemovalSummary?.id }
            .onChange(of: vm.lastRemovalSummary?.id) { _, id in
                guard id != nil, let summary = vm.lastRemovalSummary else { return }
                AccessibilityNotification.Announcement(Self.resultText(summary)).post()
            }
            .onChange(of: vm.collectorNotice) { _, notice in
                if let notice { AccessibilityNotification.Announcement(notice).post() }
            }
    }

    private var dockRow: some View {
        HStack(spacing: 12) {
            Image(systemName: dockSymbol)
                .font(.title3).foregroundStyle(dockSymbolColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.collector.isEmpty ? "Cleanup List" :
                     "Cleanup List · \(Theme.itemCount(vm.collector.count)) · \(Theme.format(vm.collectorTotalSize)) allocated")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                if let notice = vm.collectorNotice {
                    Text(notice)
                        .font(.caption).foregroundStyle(Theme.foreground)
                        .lineLimit(2)
                } else if let summary = shownSummary {
                    Text(Self.resultText(summary))
                        .font(.caption.monospacedDigit()).foregroundStyle(Theme.foreground)
                        .lineLimit(2)
                        .accessibilityLabel("Removal result. \(Self.resultText(summary))")
                } else if vm.collector.isEmpty {
                    Text("Drop a map item here, or press ⌘⌫ on a selected item.")
                        .font(.caption).foregroundStyle(Theme.mutedForeground)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if vm.hasTrackedTrash, let onFinishTrash {
                Button("Finish in Trash…", action: onFinishTrash)
                    .tesseraButtonStyle(.flat).controlSize(.small)
                    .disabled(vm.isScanning || vm.isDeleting || vm.isReadingTree)
                    .help("Review only items moved by this cleanup before permanent removal.")
            }
            if vm.hasTrashMoveHistory,
               let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
                Button("Show Trash") { NSWorkspace.shared.open(trash) }
                    .tesseraButtonStyle(.flat).controlSize(.small)
            }
            if vm.collectorNotice == nil, let summary = shownSummary {
                Button("Dismiss") { hiddenSummaryID = summary.id }
                    .tesseraButtonStyle(.flat).controlSize(.small)
                    .accessibilityLabel("Dismiss removal result")
            }
            if vm.isDeleting {
                ProgressView(value: Double(vm.deletionProgress), total: Double(max(1, vm.deletionTotal)))
                    .frame(width: 120)
                    .accessibilityLabel("Removing items")
                    .accessibilityValue("\(vm.deletionProgress) of \(vm.deletionTotal)")
            } else if vm.collector.isEmpty {
                // One filled accent control per view: the review CTA fills only
                // when there is something to review.
                Button("Review List…", action: onReview)
                    .tesseraButtonStyle(.flat)
                    .disabled(true)
            } else {
                Button("Review List…", action: onReview)
                    .tesseraButtonStyle(.flatProminent)
                    .disabled(vm.isScanning)
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                    .help("Review every path before anything moves (⇧⌘L)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            if drag.isOverCollector { Rectangle().fill(Theme.electricBlue).frame(height: 2) }
        }
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(CollectorDragController.appSpace))
        } action: { drag.setCollectorFrame($0) }
        .onDisappear { drag.setCollectorFrame(.zero) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cleanup List")
    }

    private var dockSymbol: String {
        if drag.isOverCollector { return "plus.circle.fill" }
        if vm.collectorNotice != nil { return "info.circle" }
        if let summary = shownSummary {
            return summary.failed > 0 || summary.held > 0 ? "exclamationmark.triangle" : "checkmark.circle"
        }
        return "checklist"
    }

    private var dockSymbolColor: Color {
        if vm.collectorNotice == nil, let summary = shownSummary, summary.failed > 0 { return Theme.danger }
        return Theme.electricBlue
    }

    /// "Moved 1 item (16.8 MB allocated) to Trash." Held and failed counts
    /// appear only when this action held or failed something.
    static func resultText(_ summary: ScanViewModel.RemovalSummary) -> String {
        let verb = summary.permanently ? "Deleted" : "Moved"
        let target = summary.permanently ? "" : " to Trash"
        var text = "\(verb) \(Theme.itemCount(summary.moved)) (\(Theme.format(summary.movedBytes)) allocated)\(target)."
        var problems: [String] = []
        if summary.held > 0 { problems.append("\(summary.held) held") }
        if summary.failed > 0 { problems.append("\(summary.failed) failed") }
        if !problems.isEmpty { text += " " + problems.joined(separator: ", ") + "." }
        return text
    }

}

/// The review uses one source and one scan. A rescan cannot silently replace
/// paths in the open sheet. Removals update both the review and staged list.
/// Confirmation dialogs attach to this sheet, so Cancel returns to the same
/// rows and total.
struct CleanupReviewSheet: View {
    private struct Item: Identifiable {
        let node: FileNode
        let path: String
        let bytes: Int64
        let recommendation: CleanupRecommendation?
        var id: ObjectIdentifier { node.id }
    }

    @ObservedObject var vm: ScanViewModel
    let sourcePath: String
    let rootID: ObjectIdentifier?
    let revision: UInt64
    /// Rescue shows the reviewed risk mix in the confirmation.
    let startedInRescue: Bool
    var onTrash: ([FileNode]) -> Void
    var onDelete: ([FileNode]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Item]
    @State private var reviewedCollectorIDs: Set<ObjectIdentifier>
    @State private var showTrashConfirm: Bool
    @State private var showDeleteConfirm = false
    /// Escape for the two alerts below. Their Cancel holds Return, the safe
    /// default, so no alert button holds Escape.
    @State private var escapeMonitor: Any?
    @State private var listHeight: CGFloat = 0

    /// Keeps header, footer and list inside the 820x600 minimum window.
    private static let maxListHeight: CGFloat = 300

    init(vm: ScanViewModel, nodes: [FileNode], sourcePath: String,
         rootID: ObjectIdentifier?, revision: UInt64, startedInRescue: Bool = false,
         confirmOnOpen: Bool = false,
         onTrash: @escaping ([FileNode]) -> Void,
         onDelete: @escaping ([FileNode]) -> Void) {
        self.vm = vm
        self.sourcePath = sourcePath
        self.rootID = rootID
        self.revision = revision
        self.startedInRescue = startedInRescue
        self.onTrash = onTrash
        self.onDelete = onDelete
        // One lookup table per sheet, not one linear search per row per render.
        let plan = Dictionary((vm.rescuePlan?.recommendations ?? []).map { ($0.node.id, $0) },
                              uniquingKeysWith: { first, _ in first })
        _items = State(initialValue: nodes.map {
            Item(node: $0, path: $0.url.path, bytes: $0.physicalSize, recommendation: plan[$0.id])
        })
        _reviewedCollectorIDs = State(initialValue: Set(nodes.map(\.id)))
        _showTrashConfirm = State(initialValue: confirmOnOpen && !nodes.isEmpty)
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
            header
            Divider()
            if !isCurrent {
                Label("The scan or list changed. Close this sheet and review the current list.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.subheadline)
                    .padding(.horizontal, 24).padding(.vertical, 10)
            }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in row(item) }
                    if items.isEmpty {
                        Text("The Cleanup List is empty.").foregroundStyle(Theme.mutedForeground).padding(24)
                    }
                }
                .padding(.horizontal, 24)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            // Grows with its rows, then scrolls; the footer total stays pinned.
            .frame(height: min(max(listHeight, 44), Self.maxListHeight))
            Divider()
            footer
        }
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.bg)
        .confirmationDialog(trashTitle, isPresented: $showTrashConfirm, titleVisibility: .visible) {
            Button("Move to Trash") { onTrash(items.map(\.node)) }
            // Cancel is the Return and Escape action; the sheet stays open.
            Button("Cancel", role: .cancel) { vm.cancelTrashConfirmation() }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(trashMessage)
        }
        .confirmationDialog("Permanently delete \(Theme.itemCount(items.count)) (\(Theme.format(total)))?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Move to Trash Instead") { requestTrash() }
            Button("Delete Permanently", role: .destructive) { onDelete(items.map(\.node)) }
            Button("Cancel", role: .cancel) {}
                .keyboardShortcut(.defaultAction)
        } message: {
            Text("This cannot be undone. Check every path first.")
        }
        .onAppear {
            if showTrashConfirm { vm.beginTrashConfirmation() }
            installEscapeMonitor()
        }
        .onDisappear { removeEscapeMonitor() }
        .onChange(of: vm.isScanning) { _, scanning in
            if scanning { showTrashConfirm = false; showDeleteConfirm = false }
        }
    }

    /// Escape closes an open alert as Cancel does; the sheet stays open.
    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        let trash = $showTrashConfirm, delete = $showDeleteConfirm, model = vm
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53,
                  event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]) else { return event }
            let closed = MainActor.assumeIsolated { () -> Bool in
                guard trash.wrappedValue || delete.wrappedValue else { return false }
                if trash.wrappedValue {
                    trash.wrappedValue = false
                    model.cancelTrashConfirmation()
                }
                delete.wrappedValue = false
                return true
            }
            return closed ? nil : event
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Review Cleanup List").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    .tesseraButtonStyle(.flat)
            }
            Text("Check every path. Removing a row keeps its file in place.")
                .font(.callout).foregroundStyle(Theme.mutedForeground)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private func row(_ item: Item) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: Theme.icon(for: item.node)).foregroundStyle(Theme.mutedForeground)
                    .frame(width: 20).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.node.name).font(.body.weight(.medium)).lineLimit(1)
                        if let recommendation = item.recommendation {
                            tag(recommendation.risk.title, color: riskColor(recommendation.risk))
                            tag(recommendation.owner, color: Theme.mutedForeground)
                        }
                    }
                    Text(item.path).font(.caption.monospaced()).foregroundStyle(Theme.mutedForeground)
                        .lineLimit(1).truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(item.path)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Theme.format(item.bytes)).font(.callout.monospacedDigit())
                    .fixedSize()
                Button {
                    vm.removeFromCollector(item.node)
                    items.removeAll { $0.id == item.id }
                    reviewedCollectorIDs.remove(item.id)
                } label: { Image(systemName: "minus.circle") }
                .tesseraButtonStyle(.icon(size: 24))
                .help("Remove from Cleanup List. The file stays in place.")
                .accessibilityLabel("Remove \(item.node.name) from Cleanup List")
                .disabled(!isCurrent)
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .contain)
            .contextMenu {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([item.node.url])
                }
            }
            Divider()
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
            .lineLimit(1)
            .fixedSize()
    }

    private func riskColor(_ risk: CleanupRisk) -> Color {
        switch risk {
        case .safe: return Theme.electricBlue
        case .protected: return Theme.danger
        default: return Theme.crossVolumeColor
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Theme.itemCount(items.count)).foregroundStyle(Theme.mutedForeground)
                Spacer()
                Text("\(Theme.format(total)) allocated").font(.headline.monospacedDigit())
            }
            Text("Trash is recoverable. Free space is measured separately after removal.")
                .font(.caption).foregroundStyle(Theme.mutedForeground)
            HStack {
                Menu("More") {
                    Button("Empty List") {
                        vm.clearCollector()
                        items = []
                        reviewedCollectorIDs = []
                    }
                    Divider()
                    Button("Delete Permanently…", role: .destructive) { showDeleteConfirm = true }
                }
                .fixedSize()
                Spacer()
                Button("Move to Trash…") { requestTrash() }
                    .tesseraButtonStyle(.flatProminent)
            }
            .disabled(!isCurrent || items.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func requestTrash() {
        guard isCurrent, !items.isEmpty else { return }
        vm.beginTrashConfirmation()
        showTrashConfirm = true
    }

    private var trashTitle: String {
        "Move \(Theme.itemCount(items.count)) (\(Theme.format(total))) to Trash?"
    }

    /// The optional additional-space goal stays in Rescue. Confirmation names
    /// the reviewed action and risk mix without reviving the old capacity target.
    private var trashMessage: String {
        let base = "You can restore items from Trash. They can still use disk space until permanently removed."
        guard startedInRescue, let plan = vm.rescuePlan else { return base }
        let ids = Set(items.map(\.id))
        let parts = [(CleanupRisk.safe, "safe"), (.review, "marked Review first"), (.protected, "protected")]
            .compactMap { risk, title -> String? in
                let count = plan.recommendations.filter { ids.contains($0.node.id) && $0.risk == risk }.count
                return count > 0 ? "\(count) \(title)" : nil
            }
        var message = base
        if !parts.isEmpty { message += " In this list: " + parts.joined(separator: ", ") + "." }
        return message
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
