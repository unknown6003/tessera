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
        ZStack(alignment: .bottom) {
            // Glass panel container
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

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
        }
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
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
        .padding(.vertical, 9)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.clear)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        .fill(.quaternary)
                        .frame(height: 4)
                    Capsule()
                        .fill(fraction > 0.9 ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.accentColor))
                        .frame(width: max(4, geo.size.width * fraction), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(usedStr) used of \(totalStr)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}
