import SwiftUI

// MARK: - VolumeInfo

struct VolumeInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isRemovable: Bool
    let totalBytes: Int64?
    let availableBytes: Int64?

    var usedBytes: Int64? {
        guard let t = totalBytes, let a = availableBytes else { return nil }
        return max(0, t - a)
    }

    static func == (lhs: VolumeInfo, rhs: VolumeInfo) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    init(url: URL, name: String, isRemovable: Bool, totalBytes: Int64?, availableBytes: Int64? = nil) {
        self.url = url
        self.name = name
        self.isRemovable = isRemovable
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    init?(from url: URL) {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIsRemovableKey,
                                         .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let vals = try? url.resourceValues(forKeys: keys) else { return nil }
        self.url = url
        self.name = vals.volumeName ?? url.lastPathComponent
        self.isRemovable = vals.volumeIsRemovable ?? false
        self.totalBytes = vals.volumeTotalCapacity.map { Int64($0) }
        self.availableBytes = vals.volumeAvailableCapacity.map { Int64($0) }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @ObservedObject var vm: ScanViewModel

    @State private var volumes: [VolumeInfo] = []
    @State private var selectedVolumeURL: URL?
    @State private var showFolderPicker = false

    var body: some View {
        // One behind-window glass pane with sharp content layered on top — never
        // glass-on-glass. The old design stacked a `.glassEffect` carrier under
        // cards that were themselves glass, and an outer GlassEffectContainer
        // merged it all into a frosted smear that washed the sidebar out.
        VStack(spacing: 0) {
            // Header
            sidebarHeader

            // Volume list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(volumes) { info in
                        VolumeCard(
                            info: info,
                            isSelected: selectedVolumeURL == info.url
                        )
                        .onTapGesture { selectedVolumeURL = info.url }
                    }

                    // Choose Folder row
                    Button {
                        showFolderPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(.secondary)
                            Text("Choose Folder…")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }

            Divider()
                .opacity(0.3)

            // Scan footer
            scanFooter
        }
        .desktopGlassPanel(cornerRadius: 24, shadowRadius: 28, shadowY: 16)
        .onAppear { loadVolumes() }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() {
                let custom = VolumeInfo(url: url, name: url.lastPathComponent,
                                        isRemovable: false, totalBytes: nil)
                volumes = [custom] + volumes.filter { $0.url != url }
                selectedVolumeURL = url
            }
        }
    }

    // MARK: Header

    private var sidebarHeader: some View {
        HStack {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                // A tinted disc, NOT nested glass — glass-on-glass double-blurs
                // into an unreadable smear. The panel itself supplies the glass.
                .background(Circle().fill(.tint.opacity(0.16)))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text("Storage Optimizer")
                    .font(.headline.smallCaps())
                    .tracking(0.5)
                Text("Disk Space Visualizer")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: Scan footer

    @ViewBuilder
    private var scanFooter: some View {
        VStack(spacing: 8) {
            // Post-scan summary row
            if let root = vm.rootNode, !vm.isScanning {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(Theme.format(root.size))
                        .font(.caption.monospacedDigit().weight(.medium))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(vm.progress.filesScanned) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            if vm.isScanning {
                scanningProgress
            } else {
                Button {
                    if let url = selectedVolumeURL { vm.startScan(volumeURL: url) }
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(selectedVolumeURL == nil)
                .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 16)
        .padding(.top, vm.isScanning ? 8 : 4)
    }

    @ViewBuilder
    private var scanningProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Scanning…")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let fraction = vm.progress.fraction {
                    Text("\(Int(fraction * 100))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tint)
                } else {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if let fraction = vm.progress.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView(value: 0.0)
                    .progressViewStyle(.linear)
                    .opacity(0.3)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedProgress)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(vm.progress.currentPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Stop") { vm.cancelScan() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
    }

    private var formattedProgress: String {
        let files = vm.progress.filesScanned
        let bytes = Theme.format(vm.progress.bytesFound)
        return "\(files) items · \(bytes)"
    }

    // MARK: Volume loading

    private func loadVolumes() {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey,
                                       .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []
        volumes = urls.compactMap { VolumeInfo(from: $0) }
        if selectedVolumeURL == nil { selectedVolumeURL = volumes.first?.url }
    }
}

// MARK: - VolumeCard

private struct VolumeCard: View {
    let info: VolumeInfo
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: info.isRemovable ? "externaldrive" : "internaldrive")
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                Text(info.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if let total = info.totalBytes {
                    Text(Theme.format(total))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            if let total = info.totalBytes, total > 0 {
                capacityBar(total: total)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            // Selection is a tinted fill + accent border, NOT a nested glass
            // surface. The sidebar panel is already glass; layering glass on glass
            // double-blurs the card into the unreadable pink smear seen before.
            if isSelected {
                shape.fill(Theme.selectionTint)
                    .overlay(shape.strokeBorder(.tint.opacity(0.55), lineWidth: 1))
            } else {
                shape.fill(.white.opacity(0.05))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.smooth(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private func capacityBar(total: Int64) -> some View {
        let used = info.usedBytes ?? 0
        let fraction = total > 0 ? Double(used) / Double(total) : 0.0
        let usedStr = Theme.format(used)
        let totalStr = Theme.format(total)

        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.10))
                        .frame(height: 5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: fraction > 0.9
                                    ? [Color(hue: 0.02, saturation: 0.7, brightness: 1.0), .red]
                                    : [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, geo.size.width * fraction), height: 5)
                        .overlay(
                            Capsule()
                                .fill(.white.opacity(0.35))
                                .frame(height: 1.5)
                                .padding(.horizontal, 1)
                                .offset(y: -1),
                            alignment: .top
                        )
                        .frame(width: max(5, geo.size.width * fraction), alignment: .leading)
                }
            }
            .frame(height: 5)

            Text("\(usedStr) used of \(totalStr)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}
