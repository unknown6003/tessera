import SwiftUI
import AppKit
import Combine

// MARK: - Sidebar

struct Sidebar: View {
    @ObservedObject var vm: ScanViewModel

    @State private var volumes: [VolumeInfo] = []
    @State private var customFolders: [VolumeInfo] = []
    @State private var selectedVolumeURL: URL?
    @State private var showFolderPicker = false

    // Connect-to-server sheet
    @State private var showConnectSheet = false
    @State private var connectAddress = ""
    @State private var connectError: String?
    @State private var isConnecting = false

    private let workspaceCenter = NSWorkspace.shared.notificationCenter

    private var allSources: [VolumeInfo] { volumes + customFolders }

    /// Sources grouped into ordered sections for display.
    private var sections: [(kind: StorageSourceKind, items: [VolumeInfo])] {
        let groups = Dictionary(grouping: allSources, by: \.kind)
        return StorageSourceKind.allCases
            .sorted { $0.sortRank < $1.sortRank }
            .compactMap { kind in
                guard let items = groups[kind], !items.isEmpty else { return nil }
                return (kind, items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            }
    }

    var body: some View {
        // One behind-window glass pane with sharp content layered on top — never
        // glass-on-glass. The old design stacked a `.glassEffect` carrier under
        // cards that were themselves glass, and an outer GlassEffectContainer
        // merged it all into a frosted smear that washed the sidebar out.
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(sections, id: \.kind) { section in
                        sectionView(title: section.kind.sectionTitle, items: section.items)
                    }
                    addSourceRows
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }

            Divider()
                .opacity(0.3)

            scanFooter
        }
        .desktopGlassPanel(cornerRadius: 24, shadowRadius: 28, shadowY: 16)
        .onAppear { reloadVolumes() }
        .onReceive(workspaceCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in reloadVolumes() }
        .onReceive(workspaceCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in reloadVolumes() }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if let url = try? result.get() {
                let custom = VolumeInfo(folderURL: url)
                customFolders = [custom] + customFolders.filter { $0.url != url }
                selectedVolumeURL = url
            }
        }
        .sheet(isPresented: $showConnectSheet) { connectSheet }
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
            Button {
                reloadVolumes()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh sources")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Sections

    @ViewBuilder
    private func sectionView(title: String, items: [VolumeInfo]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            ForEach(items) { info in
                VolumeCard(info: info,
                           isSelected: selectedVolumeURL == info.url,
                           isScanned: vm.scannedURL == info.url,
                           isCached: vm.scannedURL != info.url && vm.hasCachedScan(for: info.url))
                    .onTapGesture {
                        selectedVolumeURL = info.url
                        // If we've already scanned this source, switch to it instantly.
                        vm.showCachedScanIfAvailable(for: info.url)
                    }
            }
        }
    }

    private var addSourceRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Add")
            addRow(icon: "folder.badge.plus", title: "Choose Folder…") { showFolderPicker = true }
            addRow(icon: "network", title: "Connect to Server…") {
                connectError = nil
                showConnectSheet = true
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func addRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .kerning(0.8)
            .padding(.horizontal, 6)
    }

    // MARK: Scan footer

    @ViewBuilder
    private var scanFooter: some View {
        VStack(spacing: 8) {
            if vm.isScanning {
                scanningProgress
            } else {
                if let root = vm.rootNode {
                    viewingSummary(root: root)
                }
                if showSwitchNotice {
                    switchNotice
                }
                scanButton
            }
        }
        .padding(.bottom, 16)
        .padding(.top, vm.isScanning ? 8 : 4)
    }

    /// What's currently displayed in the chart — names the scanned disk so the
    /// sidebar selection and the on-screen tree can't drift silently.
    @ViewBuilder
    private func viewingSummary(root: FileNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.fill")
                .foregroundStyle(.green)
                .font(.caption2)
            Text("Viewing \(name(for: vm.scannedURL) ?? root.name)")
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(Theme.format(root.size)) · \(vm.progress.filesScanned) items")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    /// True when the highlighted source isn't the one currently displayed, so the
    /// user can scan it or jump back to what's on screen.
    private var showSwitchNotice: Bool {
        guard let selected = selectedVolumeURL, vm.scannedURL != nil else { return false }
        return selected != vm.scannedURL
    }

    private var switchNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.swap")
                .font(.caption)
                .foregroundStyle(.tint)
            Text("\(name(for: selectedVolumeURL) ?? "This source") isn't scanned yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Back") {
                selectedVolumeURL = vm.scannedURL
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .help("Re-select \(name(for: vm.scannedURL) ?? "the scanned disk") (the one currently displayed)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            let s = RoundedRectangle(cornerRadius: 12, style: .continuous)
            s.fill(.tint.opacity(0.10))
                .overlay(s.strokeBorder(.tint.opacity(0.30), lineWidth: 1))
        }
        .padding(.horizontal, 14)
    }

    private var scanButton: some View {
        Button {
            if let url = selectedVolumeURL { vm.startScan(volumeURL: url) }
        } label: {
            Label(scanButtonTitle, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(selectedVolumeURL == nil)
        .padding(.horizontal, 14)
    }

    /// "Rescan X" when the selection is already on screen, "Scan X" otherwise.
    private var scanButtonTitle: String {
        guard let name = name(for: selectedVolumeURL) else { return "Scan" }
        return selectedVolumeURL == vm.scannedURL ? "Rescan \(name)" : "Scan \(name)"
    }

    /// Friendly name for a source URL, resolved from the discovered sources.
    private func name(for url: URL?) -> String? {
        guard let url else { return nil }
        return allSources.first { $0.url == url }?.name
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

    // MARK: Connect-to-server sheet

    private var connectSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect to Server")
                        .font(.title3.weight(.semibold))
                    Text("Mount an SMB, NFS, AFP or WebDAV share, then scan it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("smb://server/share", text: $connectAddress)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onSubmit(connect)

            if let connectError {
                Label(connectError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("EXAMPLES")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.6)
                Text("smb://nas.local/Media\nnfs://10.0.0.5/export\nhttps://dav.example.com/files")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Spacer()
                Button("Cancel") { showConnectSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button(action: connect) {
                    if isConnecting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(connectAddress.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func connect() {
        let address = connectAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !isConnecting else { return }
        isConnecting = true
        connectError = nil
        Task { @MainActor in
            do {
                let mountURL = try await NetworkShareMounter.mount(address)
                reloadVolumes()
                selectedVolumeURL = mountURL
                connectAddress = ""
                isConnecting = false
                showConnectSheet = false
            } catch {
                connectError = error.localizedDescription
                isConnecting = false
            }
        }
    }

    // MARK: Source loading

    private func reloadVolumes() {
        volumes = StorageSourceDiscovery.discover()
        customFolders = customFolders.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        if selectedVolumeURL == nil || !allSources.contains(where: { $0.url == selectedVolumeURL }) {
            selectedVolumeURL = defaultSelection
        }
    }

    private var defaultSelection: URL? {
        allSources
            .sorted { $0.kind.sortRank < $1.kind.sortRank }
            .first?.url
    }
}

// MARK: - VolumeCard

private struct VolumeCard: View {
    let info: VolumeInfo
    let isSelected: Bool
    /// This source's scan results are the ones currently on screen.
    let isScanned: Bool
    /// A completed scan for this source is cached and can be shown instantly.
    let isCached: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: info.kind.symbolName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let subtitle = info.subtitle, info.totalBytes == nil {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
                if isScanned {
                    viewingPill
                } else if isCached {
                    cachedPill
                } else if let total = info.totalBytes {
                    Text(Theme.format(total))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                } else if info.subtitle != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
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
            // double-blurs the card into the unreadable smear seen before.
            if isSelected {
                shape.fill(Theme.selectionTint)
                    .overlay(shape.strokeBorder(.tint.opacity(0.55), lineWidth: 1))
            } else {
                shape.fill(.white.opacity(0.05))
            }
        }
        // The scanned source gets a persistent green ring so it stays identifiable
        // even when the highlight (next-scan target) moves to a different card.
        .overlay {
            if isScanned {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.green.opacity(0.55), lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.smooth(duration: 0.2), value: isSelected)
        .animation(.smooth(duration: 0.2), value: isScanned)
    }

    /// Green "Viewing" badge marking the source whose tree is on screen.
    private var viewingPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "eye.fill")
                .font(.system(size: 8, weight: .bold))
            Text("Viewing")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(.green.opacity(0.16)))
    }

    /// "Cached" badge — tap to switch to this source's results instantly.
    private var cachedPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 8, weight: .bold))
            Text("Cached")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(.tint.opacity(0.14)))
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
                                    : [Theme.electricBlue.opacity(0.95), Theme.electricBlue.opacity(0.55)],
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
