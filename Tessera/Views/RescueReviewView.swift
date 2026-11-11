import SwiftUI
import AppKit

/// One group, opened in Rescue's main area. Nothing starts selected. Files
/// stage only by explicit choice; managed stores route to their owner.
struct RescueReviewView: View {
    @ObservedObject var vm: ScanViewModel
    @ObservedObject var workspace: RescueWorkspaceModel
    let review: RescueReviewSnapshot

    private static let pitch: CGFloat = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { workspace.closeReview() } label: {
                Label("Back to Rescue", systemImage: "chevron.left")
            }
            .tesseraButtonStyle(.flat)
            .controlSize(.small)
            .keyboardShortcut("[", modifiers: .command)
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
                .overlay(alignment: .top) { Divider() }
                .overlay(alignment: .bottom) { Divider() }
            }

            if let item = workspace.detailItem { detail(item) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("Managed by \(route.ownerName == "Finder" ? (review.items.first?.recommendation.owner ?? "its app") : route.ownerName)")
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

    @ViewBuilder
    private var handoffStatus: some View {
        switch workspace.handoff {
        case .none:
            EmptyView()
        case .waiting(let owner), .deferred(let owner):
            HStack(spacing: 8) {
                Text("Opened \(owner). Tessera checks again when you return.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Don't check") { workspace.cancelHandoff() }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        Button("Select all") { workspace.selectAllEligible() }
            .tesseraButtonStyle(.flat)
            .controlSize(.small)
            .disabled(workspace.eligibleVisibleIDs.isEmpty)
            .accessibilityLabel("Select all items that can be added")
        if count > 0 {
            Button("Clear") { workspace.clearSelection() }
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
        }
        Spacer(minLength: 0)
        Button {
            Task { await workspace.stageSelection() }
        } label: {
            Text(count == 0
                 ? "Add to Cleanup List"
                 : "Add \(Theme.itemCount(count)) · \(Theme.format(workspace.selectedBytes))")
        }
        .tesseraButtonStyle(.flatProminent)
        .controlSize(.regular)
        .disabled(!workspace.canStage)
        .help(busy ? "Wait for the current scan or cleanup to finish." : "Adds only the selected items. Nothing moves yet.")
    }

    private func row(_ item: RescueReviewSnapshot.Item) -> some View {
        let recommendation = item.recommendation
        let selected = workspace.selection.contains(recommendation.id)
        let inList = vm.isCollected(recommendation.node)
        let isDetail = workspace.detailItemID == recommendation.id
        return HStack(spacing: 10) {
            if item.heldReason == nil {
                Button { workspace.toggle(item) } label: {
                    Image(systemName: selected || inList ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected || inList ? Theme.electricBlue : Theme.mutedForeground)
                }
                .tesseraButtonStyle(.interactive)
                .disabled(inList)
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

            Button { workspace.detailItemID = isDetail ? nil : recommendation.id } label: {
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
            .accessibilityLabel("\(recommendation.node.name), \(Theme.format(recommendation.physicalBytes))")
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
