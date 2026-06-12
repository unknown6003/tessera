import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ScanViewModel()

    var body: some View {
        NavigationSplitView {
            Sidebar(vm: vm)
                .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } content: {
            chartArea
                .navigationSplitViewColumnWidth(min: 420, ideal: 620)
        } detail: {
            InspectorView(vm: vm)
                .navigationSplitViewColumnWidth(min: 240, ideal: 270)
        }
        .navigationTitle("Storage Optimizer")
    }

    // MARK: - Chart area

    @ViewBuilder
    private var chartArea: some View {
        ZStack {
            // Main content
            if vm.needsFullDiskAccess {
                centeredCard { fullDiskAccessContent }
            } else if let error = vm.errorMessage {
                centeredCard { errorContent(error) }
            } else if vm.rootNode == nil && !vm.isScanning {
                centeredCard { emptyContent }
            } else {
                // Sunburst + breadcrumb overlay
                SunburstRepresentable(
                    root: vm.currentRoot,
                    highlightedNode: vm.hoveredNode,
                    onHover: { vm.hoveredNode = $0 },
                    onSelect: { vm.selectedNode = $0 },
                    onZoom: { node in
                        if let node { vm.zoomIn(to: node) } else { vm.zoomOut() }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contextMenu {
                    if let node = vm.hoveredNode {
                        Button("Add to Collector") { vm.addToCollector(node) }
                        Divider()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([node.url])
                        }
                    }
                }

                // Floating breadcrumb
                if let current = vm.currentRoot, vm.rootNode != nil {
                    VStack {
                        breadcrumb(for: current)
                        Spacer()
                    }
                }
            }
        }
        .background(.background)
    }

    // MARK: - Glass card wrapper

    private func centeredCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
                .padding(32)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Placeholder content

    private var emptyContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "internaldrive")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.secondary)
            Text("Select a volume and click Scan")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var fullDiskAccessContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text("Full Disk Access Required")
                    .font(.title2.weight(.semibold))
                Text("Grant Full Disk Access in System Settings,\nthen scan again.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Open System Settings") {
                vm.openFullDiskAccessSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.red)
            VStack(spacing: 6) {
                Text("Scan failed")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Breadcrumb

    private func breadcrumb(for node: FileNode) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    vm.zoomToRoot()
                } label: {
                    Image(systemName: "house.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .help("Zoom to root")

                let ancestors = ancestorChain(of: node)
                ForEach(ancestors) { ancestor in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button(ancestor.name) {
                        vm.currentRoot = ancestor
                        vm.selectedNode = ancestor
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                }

                if !ancestors.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(node.name)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func ancestorChain(of node: FileNode) -> [FileNode] {
        var chain: [FileNode] = []
        var cursor = node.parent
        while let c = cursor {
            chain.insert(c, at: 0)
            cursor = c.parent
        }
        return chain
    }
}
