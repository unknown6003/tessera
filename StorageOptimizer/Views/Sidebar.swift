import SwiftUI
import AppKit

struct Sidebar: View {
    @ObservedObject var vm: ScanViewModel

    @State private var volumes: [VolumeInfo] = []
    @State private var selectedVolumeURL: URL?
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedVolumeURL) {
                Section("Volumes") {
                    ForEach(volumes) { info in
                        VolumeRow(info: info)
                            .tag(info.url)
                    }
                }

                Section {
                    Button {
                        showFolderPicker = true
                    } label: {
                        Label("Choose Folder…", systemImage: "folder")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)

            Divider()
            scanFooter
        }
        .onAppear { loadVolumes() }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() {
                let custom = VolumeInfo(url: url, name: url.lastPathComponent, isRemovable: false, totalBytes: nil)
                volumes = [custom] + volumes.filter { $0.url != url }
                selectedVolumeURL = url
            }
        }
    }

    // MARK: - Scan footer

    @ViewBuilder
    private var scanFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            if vm.isScanning {
                scanningProgress
            } else {
                Button {
                    if let url = selectedVolumeURL { vm.startScan(volumeURL: url) }
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedVolumeURL == nil)
            }
        }
        .padding(14)
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
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let fraction = vm.progress.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            HStack {
                Text(formattedProgress)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Stop") { vm.cancelScan() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
    }

    private var formattedProgress: String {
        let files = vm.progress.filesScanned
        let found = ByteCountFormatter.string(fromByteCount: vm.progress.bytesFound, countStyle: .file)
        return "\(files) items · \(found)"
    }

    // MARK: - Volume loading

    private func loadVolumes() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey,
                                       .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        let urls = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        volumes = urls.compactMap { VolumeInfo(from: $0) }
        if selectedVolumeURL == nil { selectedVolumeURL = volumes.first?.url }
    }
}

// MARK: - Volume model

struct VolumeInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isRemovable: Bool
    let totalBytes: Int64?

    static func == (lhs: VolumeInfo, rhs: VolumeInfo) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    init(url: URL, name: String, isRemovable: Bool, totalBytes: Int64?) {
        self.url = url; self.name = name; self.isRemovable = isRemovable; self.totalBytes = totalBytes
    }

    init?(from url: URL) {
        guard let vals = try? url.resourceValues(forKeys: [.volumeNameKey, .volumeIsRemovableKey,
                                                            .volumeTotalCapacityKey]) else { return nil }
        self.url = url
        self.name = vals.volumeName ?? url.lastPathComponent
        self.isRemovable = vals.volumeIsRemovable ?? false
        self.totalBytes = vals.volumeTotalCapacity.map { Int64($0) }
    }
}

// MARK: - Volume row

private struct VolumeRow: View {
    let info: VolumeInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(info.name, systemImage: info.isRemovable ? "externaldrive" : "internaldrive")
                .font(.body)
            if let total = info.totalBytes {
                Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 22)
            }
        }
        .padding(.vertical, 2)
    }
}
