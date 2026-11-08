import SwiftUI

struct InspectorView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var largestRows: [FileNode] = []

    private var inspectedNode: FileNode? {
        vm.selectedNode
    }

    var body: some View {
        // The inspector is now focused purely on the selected item. Cleanup and the
        // duplicate finder live in the top action bar (see CleanupActionBar).
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                detailsSection
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .disabled(vm.isDeleting || vm.isScanning)
        .onChange(of: inspectedNode?.id, initial: true) { _, _ in refreshLargestRows() }
        .onChange(of: vm.chartRevision) { _, _ in refreshLargestRows() }
    }

    private func refreshLargestRows() {
        largestRows = inspectedNode?.largestChildren(limit: 5) ?? []
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Details")

            if let node = inspectedNode {
                nodeHeader(node)
                if node.kind == .hiddenSpace {
                    HiddenSpaceView(vm: vm, hiddenBytes: node.size)
                } else {
                    pathRow(node)
                    if node.isDirectory && !node.children.isEmpty {
                        topChildrenList(node)
                    }
                    actionButtons(node)
                }
            } else {
                emptyDetailsPlaceholder
            }
        }
    }

    @ViewBuilder
    private func nodeHeader(_ node: FileNode) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Flat icon badge: a solid disc in the node's colour, hairline edge.
            ZStack {
                Circle()
                    .fill(iconCircleColor(node))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                Image(systemName: Theme.icon(for: node))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink(on: iconCircleColor(node)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Theme.format(node.size))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)

                if node.isDirectory {
                    Text(Theme.itemCount(node.children.count))
                        .font(.caption)
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
        }
    }

    @ViewBuilder
    private func pathRow(_ node: FileNode) -> some View {
        Text(node.url.path)
            .font(.caption.monospaced())
            .foregroundStyle(Theme.mutedForeground)
            .lineLimit(3)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func topChildrenList(_ node: FileNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Largest Items")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            ForEach(largestRows) { child in
                Button {
                    vm.selectedNode = child
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: Theme.icon(for: child))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(child.name)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Theme.format(child.size))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Theme.mutedForeground)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.interactive)
                .contentShape(Rectangle())
            }
        }
        .padding(.top, 4)
    }

    /// The one place for selection actions while Details is open. Primary
    /// action on top at full width; Finder actions below it.
    @ViewBuilder
    private func actionButtons(_ node: FileNode) -> some View {
        if !node.isSynthetic {
            VStack(alignment: .leading, spacing: 8) {
                if vm.isCollected(node) {
                    Label("In Cleanup List", systemImage: "checkmark")
                        .font(.callout)
                        .foregroundStyle(Theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    Button {
                        vm.addToCollector(node)
                    } label: {
                        Label("Add to Cleanup List", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.flat)
                    .help("Add to Cleanup List (⌘⌫)")
                }
                HStack(spacing: 16) {
                    if node.isDirectory && node.id != vm.currentRoot?.id {
                        Button("Open on Map") { vm.zoomIn(to: node) }
                            .help("Open this folder on the map (⌘↓)")
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([node.url])
                    }
                }
                .buttonStyle(.interactive)
                .font(.callout)
                .foregroundStyle(Theme.electricBlue)
            }
            .padding(.top, 4)
        }
    }

    private var emptyDetailsPlaceholder: some View {
        Text("Nothing selected yet")
            .font(.subheadline)
            .foregroundStyle(Theme.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func iconCircleColor(_ node: FileNode) -> Color {
        switch node.kind {
        case .hiddenSpace: return Theme.hiddenSpaceColor
        case .aggregate:   return Theme.aggregateColor
        case .cloudOnlyStorage: return Theme.cloudColor
        case .crossVolume: return Theme.crossVolumeColor
        default:
            // A stable neutral. A per-name colour cannot match the map, because
            // map colours follow rank inside the folder on screen.
            return Theme.elevated
        }
    }
}
