import SwiftUI

struct InspectorView: View {
    @ObservedObject var vm: ScanViewModel
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Selected / hovered item card
                selectedDetailCard

                // Collector
                collectorCard
            }
            .padding(14)
        }
        .background(.background)
        .alert("Move to Trash?", isPresented: $showDeleteConfirm) {
            Button("Move to Trash", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let size = ByteCountFormatter.string(fromByteCount: vm.collectorTotalSize, countStyle: .file)
            Text("Move \(vm.collector.count) item(s) totalling \(size) to the Trash?\nThis can be undone from the Trash.")
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Selected item card

    @ViewBuilder
    private var selectedDetailCard: some View {
        let node = vm.selectedNode ?? vm.hoveredNode
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspector")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            if let node {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.title)
                            .foregroundStyle(node.isDirectory ? Color.accentColor : .secondary)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(node.name)
                                .font(.headline)
                                .lineLimit(2)
                            Text(ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(node.url.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                        .truncationMode(.middle)

                    HStack(spacing: 8) {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([node.url])
                        } label: {
                            Label("Reveal", systemImage: "arrow.right.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button {
                            vm.addToCollector(node)
                        } label: {
                            Label("Collect", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(vm.collector.contains(where: { $0.id == node.id }))
                    }
                }
            } else {
                Text("Select or hover a segment\nto inspect it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Collector card

    private var collectorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Collector")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !vm.collector.isEmpty {
                    Button("Clear All") { vm.clearCollector() }
                        .buttonStyle(.plain)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 8)

            if vm.collector.isEmpty {
                Text("Right-click a segment to add it here for deletion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.collector.enumerated()), id: \.element.id) { index, node in
                        if index > 0 { Divider() }
                        CollectorRow(node: node) { vm.removeFromCollector(node) }
                    }
                }

                Divider().padding(.vertical, 10)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vm.collector.count) item\(vm.collector.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                        Text(ByteCountFormatter.string(fromByteCount: vm.collectorTotalSize, countStyle: .file) + " to free")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(.red)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Delete

    private func performDelete() {
        do {
            try vm.deleteCollector()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Collector row

private struct CollectorRow: View {
    let node: FileNode
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(node.isDirectory ? Color.accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
    }
}
