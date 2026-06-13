import SwiftUI

struct InspectorView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    private var inspectedNode: FileNode? {
        vm.hoveredNode ?? vm.selectedNode ?? vm.currentRoot
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                detailsSection
                collectorSection
            }
            .padding(14)
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Move \(vm.collector.count) Item\(vm.collector.count == 1 ? "" : "s") to Trash", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will free \(Theme.format(vm.collectorTotalSize)). Items can be restored from the Trash.")
        }
        .alert("Move to Trash Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Details")

            if let node = inspectedNode {
                nodeHeader(node)
                pathRow(node)
                if node.isDirectory && !node.sortedChildren.isEmpty {
                    topChildrenList(node)
                }
                actionButtons(node)
            } else {
                emptyDetailsPlaceholder
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func nodeHeader(_ node: FileNode) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(iconCircleColor(node))
                    .frame(width: 42, height: 42)
                Image(systemName: Theme.icon(for: node))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
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

    // MARK: - Collector Section

    private var collectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("Collector")
                if !vm.collector.isEmpty {
                    Text("· \(vm.collector.count) · \(Theme.format(vm.collectorTotalSize))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !vm.collector.isEmpty {
                    Button("Clear") { vm.clearCollector() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .font(.caption.weight(.medium))
                }
            }

            if vm.collector.isEmpty {
                Text("Right-click items in the chart to collect them.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.collector.enumerated()), id: \.element.id) { index, node in
                        if index > 0 {
                            Divider().opacity(0.4)
                        }
                        CollectorRow(node: node) {
                            vm.removeFromCollector(node)
                        }
                    }
                }

                if let errMsg = deleteError {
                    Text(errMsg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Move to Trash…", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
                .padding(.top, 6)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
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
        default:
            let hue = Theme.topHues[abs(node.name.hashValue) % Theme.topHues.count]
            return Theme.wedgeColor(hue: hue, depth: 0)
        }
    }

    private func performDelete() {
        deleteError = nil
        do {
            try vm.deleteCollector()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Collector Row

private struct CollectorRow: View {
    let node: FileNode
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: Theme.icon(for: node))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(Theme.format(node.size))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
    }
}
