import SwiftUI

struct InspectorView: View {
    @ObservedObject var vm: ScanViewModel

    private var inspectedNode: FileNode? {
        vm.hoveredNode ?? vm.selectedNode ?? vm.currentRoot
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
        // Full-height glass rail mirroring the sidebar — same behind-window panel
        // treatment, flush top and edges — so the left and right rails read as a
        // symmetric pair instead of a short inset card floating against the edge.
        .desktopGlassPanel(cornerRadius: 24, shadowRadius: 28, shadowY: 16)
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
                    if node.isDirectory && !node.sortedChildren.isEmpty {
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
            // Icon in a luminous glass badge tinted by the node's colour.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [iconCircleColor(node).opacity(0.95),
                                     iconCircleColor(node).opacity(0.45)],
                            center: .topLeading, startRadius: 2, endRadius: 46
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(Theme.glassHighlightStroke, lineWidth: 1)
                            .blendMode(.plusLighter)
                    )
                    .shadow(color: iconCircleColor(node).opacity(0.5), radius: 8)
                Image(systemName: Theme.icon(for: node))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Theme.format(node.size))
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.primary)

                if node.isDirectory {
                    Text("\(node.children.count) item\(node.children.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func pathRow(_ node: FileNode) -> some View {
        Text(node.url.path)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(2)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func topChildrenList(_ node: FileNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Largest Items")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            ForEach(node.sortedChildren.prefix(5)) { child in
                Button {
                    if child.isDirectory {
                        vm.zoomIn(to: child)
                    } else {
                        vm.selectedNode = child
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: Theme.icon(for: child))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(child.name)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Theme.format(child.size))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func actionButtons(_ node: FileNode) -> some View {
        HStack(spacing: 8) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            } label: {
                Label("Reveal", systemImage: "arrow.right.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.glass)
            .disabled(node.isSynthetic)

            Spacer()

            if !node.isSynthetic {
                let alreadyCollected = vm.collector.contains(where: { $0.id == node.id })
                Button {
                    vm.addToCollector(node)
                } label: {
                    Label("Collect", systemImage: alreadyCollected ? "checkmark.circle" : "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.glass)
                .disabled(alreadyCollected)
            }
        }
        .padding(.top, 4)
    }

    private var emptyDetailsPlaceholder: some View {
        Text("Nothing selected yet")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .kerning(0.8)
    }

    private func iconCircleColor(_ node: FileNode) -> Color {
        switch node.kind {
        case .hiddenSpace: return Theme.hiddenSpaceColor
        case .aggregate:   return Theme.aggregateColor
        case .cloudOnlyStorage: return Theme.cloudColor
        case .crossVolume: return Theme.crossVolumeColor
        default:
            let hue = Theme.topHues[abs(node.name.hashValue) % Theme.topHues.count]
            return Theme.wedgeColor(hue: hue, depth: 0)
        }
    }
}

