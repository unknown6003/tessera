import SwiftUI
import AppKit

/// Built-in (rule-based, on-device) cleanup suggestions. Every group has its own
/// Add/Added toggle so the user picks exactly what to stage — just caches, builds
/// without downloads, whatever. A convenience button stages all safe groups at
/// once. Nothing here deletes anything — the user reviews the collector and
/// confirms deletion through the existing flow. The AI tier lives separately in
/// SmartSuggestionsView.
struct CleanupSuggestionsView: View {
    @ObservedObject var vm: ScanViewModel

    private var hasAnything: Bool {
        vm.cleanupReport.map { !$0.isEmpty } ?? false
    }

    var body: some View {
        if hasAnything {
            VStack(alignment: .leading, spacing: 12) {
                FeatureSectionLabel("Cleanup Suggestions")

                if let report = vm.cleanupReport {
                    if !report.safeGroups.isEmpty {
                        Button {
                            vm.stageSafeCleanup()
                        } label: {
                            Label("Add all safe — \(Theme.format(report.safeTotalBytes))",
                                  systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .disabled(vm.safeGroupsAllStaged)

                        Text("Add groups individually below, or all safe ones at once. Nothing is deleted until you review the collector and confirm.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(report.safeGroups) { group in
                            groupRow(group)
                        }
                    }

                    if !report.reviewGroups.isEmpty {
                        FeatureSectionLabel("Review before clearing")
                            .padding(.top, 4)
                        Text("Likely reclaimable but possibly personal — added only if you choose.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(report.reviewGroups) { group in
                            groupRow(group)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func groupRow(_ group: CleanupReport.Group) -> some View {
        let staged = vm.isGroupStaged(group)
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: group.category.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(group.category.confidence == .safeRegenerable ? Theme.electricBlue : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(group.category.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(group.nodes.count) item\(group.nodes.count == 1 ? "" : "s") · \(group.category.explanation)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Text(Theme.format(group.totalBytes))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)

            if let largest = group.nodes.first {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([largest.url])
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.glass).controlSize(.small)
                .help("Reveal the largest item in Finder")
            }

            addToggle(isAdded: staged) { vm.toggleCleanupGroup(group) }
        }
        .padding(.vertical, 2)
    }

    /// Per-row Add/Added toggle — tinted with a checkmark once the row is staged.
    private func addToggle(isAdded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(isAdded ? "Added" : "Add", systemImage: isAdded ? "checkmark" : "plus")
                .font(.caption.weight(.medium))
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .tint(isAdded ? Theme.electricBlue : nil)
    }
}
