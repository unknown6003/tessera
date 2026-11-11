import SwiftUI
import AppKit

/// One group, opened in Rescue's main area. Nothing starts selected. Files
/// stage only by explicit choice; managed stores route to their owner.
struct RescueReviewView: View {
    @ObservedObject var vm: ScanViewModel
    @ObservedObject var workspace: RescueWorkspaceModel
    let review: RescueReviewSnapshot

    private static let pitch: CGFloat = 50
    private enum Focus: Hashable {
        case back, search, selectAll, clear, add, rows
        case rowSelect(String), rowDetail(String)
    }
    @FocusState private var focus: Focus?
    @State private var ownWindow = WindowReference()

    private final class WindowReference { weak var window: NSWindow? }
    private var rowsFocused: Bool { focus == .rows }
    private var canMoveFocus: Bool {
        guard let window = ownWindow.window else { return false }
        return NSApp.keyWindow === window && window.attachedSheet == nil
            && !(window.firstResponder is NSText) && workspace.review === review
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { workspace.closeReview() } label: {
                Label("Back to Rescue", systemImage: "chevron.left")
            }
            .tesseraButtonStyle(.flat)
            .controlSize(.small)
            .keyboardShortcut("[", modifiers: .command)
            .focused($focus, equals: .back)
            .accessibilityHint("Returns to the ranked list at the same group.")

            header
                .background { RevealOnAppear() }

            if let route = review.route { ownerGuidance(route) }
            if review.kind == .files { selectionBar }

            if let notice = workspace.reviewNotice {
                Text(notice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if workspace.reviewItems.isEmpty {
                Text(workspace.reviewSearch.isEmpty ? "No items left in this group." : "No items match this search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                WindowedRows(children: workspace.reviewNodes, pitch: Self.pitch,
                             folderID: ObjectIdentifier(review),
                             selectedIndex: workspace.detailIndex) { node in
                    if let item = workspace.reviewItem(for: node) { row(item) }
                }
                .frame(height: min(CGFloat(workspace.reviewNodes.count) * Self.pitch + 8, 420))
                .focusable().focused($focus, equals: .rows)
                .focusEffectDisabled()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Items in \(review.title)")
                .accessibilityHint("Use arrow keys to inspect items. Space selects an eligible item. Home and End reach the first and last item.")
                .onKeyPress(keys: [.upArrow, .downArrow, .home, .end, .pageUp, .pageDown, .space]) { press in
                    guard rowsFocused, press.modifiers.intersection([.command, .control, .option]).isEmpty else {
                        return .ignored
                    }
                    return handleRowKey(press.key) ? .handled : .ignored
                }
                .overlay(alignment: .top) { Divider() }
                .overlay(alignment: .bottom) { Divider() }
            }

            if let item = workspace.detailItem { detail(item) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TransparentWindowConfigurator(onWindow: { window in
            let firstAttach = ownWindow.window == nil
            ownWindow.window = window
            if firstAttach, canMoveFocus { focus = .back }
        }))
        .onChange(of: focus) { _, value in
            if value == .rows, workspace.detailIndex == nil {
                workspace.detailItemID = workspace.reviewItems.first?.recommendation.id
            }
        }
    }

    private var header: some View {
        let items = workspace.reviewItems
        let bytes = items.reduce(Int64(0)) { $0 + $1.recommendation.physicalBytes }
        return VStack(alignment: .leading, spacing: 4) {
            Text(review.title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("\(Theme.itemCount(items.count)) · \(Theme.format(bytes)) allocated · in \(URL(fileURLWithPath: review.sourcePath).lastPathComponent)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Managed stores

    private func ownerGuidance(_ route: RescueOwnerRoute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manage with \(route.ownerName == "Finder" ? (review.items.first?.recommendation.owner ?? "its app") : route.ownerName)")
                .font(.headline)
            Text(route.steps)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("At risk: \(route.dataAtRisk)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tessera does not delete this store. When you come back, it checks this source once.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !vm.collector.isEmpty {
                Text("That fresh check clears the Cleanup List. Review the current items before adding them again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                let paths = workspace.reviewItems.prefix(1).map(\.recommendation.path)
                Task { await workspace.openOwner(route, revealing: paths) }
            } label: {
                Label(route.actionTitle, systemImage: route.bundleID == nil ? "folder" : "arrow.up.forward.app")
            }
            .tesseraButtonStyle(.flatProminent)
            .controlSize(.regular)
            handoffStatus
        }
        .padding(.vertical, 6)
    }

    private var handoffStatus: some View {
        RescueHandoffStatusView(workspace: workspace, font: .caption)
    }

    // MARK: Files

    private var selectionBar: some View {
        let busy = vm.isScanning || vm.isDeleting
        let count = workspace.selection.count
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { selectionControls(busy: busy, count: count) }
            VStack(alignment: .leading, spacing: 8) { selectionControls(busy: busy, count: count) }
        }
    }

    @ViewBuilder
    private func selectionControls(busy: Bool, count: Int) -> some View {
        TextField("Search names", text: $workspace.reviewSearch)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 140, maxWidth: 220)
            .accessibilityLabel("Search item names in this group")
            .focused($focus, equals: .search)
        Button("Select all") { workspace.selectAllEligible() }
            .tesseraButtonStyle(.flat)
            .controlSize(.small)
            .disabled(workspace.eligibleVisibleIDs.isEmpty)
            .focused($focus, equals: .selectAll)
            .accessibilityLabel("Select all items that can be added")
        if count > 0 {
            Button("Clear") { workspace.clearSelection() }
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
                .focused($focus, equals: .clear)
        }
        Spacer(minLength: 0)
        Button {
            let restoreFocus = focus == .add
            Task {
                await workspace.stageSelection()
                if restoreFocus, (focus == .add || focus == nil), canMoveFocus {
                    focus = workspace.reviewItems.isEmpty ? .back : .rows
                }
                if canMoveFocus, let notice = workspace.reviewNotice {
                    var announcement = AttributedString(notice)
                    announcement.accessibilitySpeechAnnouncementPriority = .high
                    AccessibilityNotification.Announcement(announcement).post()
                }
            }
        } label: {
            Text(count == 0
                 ? "Add to Cleanup List"
                 : "Add \(Theme.itemCount(count)) · \(Theme.format(workspace.selectedBytes))")
        }
        .tesseraButtonStyle(.flatProminent)
        .controlSize(.regular)
        .disabled(!workspace.canStage)
        .focused($focus, equals: .add)
        .help(busy ? "Wait for the current scan or cleanup to finish." : "Adds only the selected items. Nothing moves yet.")
    }

    private func row(_ item: RescueReviewSnapshot.Item) -> some View {
        let recommendation = item.recommendation
        let selected = workspace.selection.contains(recommendation.id)
        let inList = vm.isCollected(recommendation.node)
        let isDetail = workspace.detailItemID == recommendation.id
        return HStack(spacing: 10) {
            if item.heldReason == nil {
                Button {
                    workspace.detailItemID = recommendation.id
                    workspace.toggle(item)
                    focus = .rows
                } label: {
                    Image(systemName: selected || inList ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected || inList ? Theme.electricBlue : Theme.mutedForeground)
                }
                .tesseraButtonStyle(.interactive)
                .disabled(inList)
                .focused($focus, equals: .rowSelect(recommendation.id))
                .accessibilityLabel("Select \(recommendation.node.name)")
                .accessibilityValue(inList ? "In Cleanup List" : (selected ? "Selected" : "Not selected"))
            } else {
                Image(systemName: "lock.fill")
                    .font(.body)
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(width: 22)
                    .help(item.heldReason ?? "")
                    .accessibilityLabel("Held")
            }

            Button {
                workspace.detailItemID = isDetail ? nil : recommendation.id
                focus = .rows
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.node.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.heldReason ?? recommendation.reason)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .tesseraButtonStyle(.interactive)
            .focused($focus, equals: .rowDetail(recommendation.id))
            .accessibilityLabel("\(recommendation.node.name), \(Theme.format(recommendation.physicalBytes)) allocated. Owner: \(recommendation.owner).")
            .accessibilityValue(item.heldReason ?? (inList ? "In Cleanup List" : ""))
            .accessibilityHint(isDetail ? "Hides details" : "Shows path, owner and effect")

            Text(Theme.format(recommendation.physicalBytes))
                .font(.callout.monospacedDigit().weight(.semibold))
                .fixedSize()
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 6)
        .frame(height: Self.pitch)
        .background(isDetail ? Theme.selectionTint : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            if isDetail && rowsFocused {
                RoundedRectangle(cornerRadius: 6).stroke(Theme.electricBlue, lineWidth: 1)
            }
        }
    }

    private func handleRowKey(_ key: KeyEquivalent) -> Bool {
        let items = workspace.reviewItems
        guard !items.isEmpty, !vm.isScanning, !vm.isDeleting else { return false }
        let index = workspace.detailIndex
        let next: Int
        switch key {
        case .upArrow: next = max(0, (index ?? 1) - 1)
        case .downArrow: next = min(items.count - 1, (index ?? -1) + 1)
        case .home: next = 0
        case .end: next = items.count - 1
        case .pageUp: next = max(0, (index ?? 8) - 8)
        case .pageDown: next = min(items.count - 1, (index ?? -1) + 8)
        case .space:
            guard let index else { return false }
            let item = items[index]
            if !vm.isCollected(item.recommendation.node) { workspace.toggle(item) }
            return true
        default: return false
        }
        workspace.detailItemID = items[next].recommendation.id
        return true
    }

    private func detail(_ item: RescueReviewSnapshot.Item) -> some View {
        let recommendation = item.recommendation
        return VStack(alignment: .leading, spacing: 6) {
            Text(recommendation.node.name)
                .font(.headline)
            Text(recommendation.path)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Text(sizeLine(recommendation))
                .font(.caption.monospacedDigit())
            Text("Owner: \(recommendation.owner)")
                .font(.caption)
            Text("Why: \(recommendation.reason)")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Text("Effect: \(recommendation.sideEffect)")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if let held = item.heldReason {
                Text("Held: \(held)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([recommendation.node.url])
                }
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
                Button("Keep") { workspace.keep(recommendation) }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
                    .disabled(!workspace.canKeep(recommendation))
                    .help(workspace.canKeep(recommendation)
                          ? "Hide this item from Rescue on this Mac. You can restore it."
                          : "Tessera cannot identify this item reliably, so it cannot remember it.")
                    .accessibilityLabel("Keep \(recommendation.node.name) and hide it from Rescue")
            }
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sizeLine(_ recommendation: CleanupRecommendation) -> String {
        var line = "\(Theme.format(recommendation.physicalBytes)) allocated"
        if let logical = recommendation.logicalBytes { line += " · \(Theme.format(logical)) logical" }
        return line + ". Space returns only after removal, and shared blocks can reduce it."
    }
}


struct RescueHandoffStatusView: View {
    @ObservedObject var workspace: RescueWorkspaceModel
    let font: Font

    var body: some View {
        Group {
            switch workspace.handoff {
            case .none:
                EmptyView()
            case .waiting(let owner), .deferred(let owner):
                HStack(spacing: 8) {
                    Text("Opened \(owner). Tessera checks this source once when you return.")
                        .foregroundStyle(Theme.mutedForeground)
                    Button("Don't check") { workspace.cancelHandoff() }
                        .tesseraButtonStyle(.flat).controlSize(.small)
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                Button("Retry") { Task { await workspace.retryOwnerHandoff() } }
                    .tesseraButtonStyle(.flat).controlSize(.small)
                    .disabled(workspace.isOpeningOwner)
            }
        }.font(font)
    }
}
