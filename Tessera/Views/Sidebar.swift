import SwiftUI
import AppKit
import Combine

// MARK: - Sidebar

struct Sidebar: View {
    @ObservedObject var vm: ScanViewModel
    /// Injected by TesseraApp; drives the version/update row in the footer.
    @EnvironmentObject private var updater: UpdaterController

    @State private var volumes: [VolumeInfo] = []
    @State private var customFolders: [VolumeInfo] = []
    private var selectedVolumeURL: URL? {
        get { vm.selectedSourceURL }
        nonmutating set { vm.selectedSourceURL = newValue }
    }
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
        // A solid panel with sharp content on top. Flat design: one opaque
        // surface, hairline borders, no vibrancy.
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

            updateRow.padding(.vertical, 10)
        }
        .background(Theme.surface)
        .onAppear { reloadVolumes() }
        .onReceive(workspaceCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in reloadVolumes() }
        .onReceive(workspaceCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in reloadVolumes() }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if !vm.isDeleting, !vm.isScanning, let url = try? result.get() {
                let custom = VolumeInfo(folderURL: url)
                customFolders = [custom] + customFolders.filter { $0.url != url }
                selectedVolumeURL = url
                vm.selectedSourceURL = url
            }
        }
        .sheet(isPresented: $showConnectSheet) { connectSheet }
    }

    // MARK: Header

    private var sidebarHeader: some View {
        HStack {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tessera")
                    .font(.headline.weight(.semibold))
                Text("Sources")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                reloadVolumes()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.icon)
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
                Button {
                    guard !vm.isDeleting, !vm.isScanning else { return }
                    selectedVolumeURL = info.url
                    vm.selectedSourceURL = info.url
                    // If we've already scanned this source, switch to it instantly.
                    vm.showCachedScanIfAvailable(for: info.url)
                } label: {
                    VolumeCard(info: info,
                               isSelected: selectedVolumeURL == info.url,
                               isScanned: vm.scannedURL == info.url,
                               isCached: vm.scannedURL != info.url && vm.hasCachedScan(for: info.url))
                }
                .buttonStyle(.plain)
                .disabled(vm.isDeleting || vm.isScanning)
                .accessibilityAddTraits(selectedVolumeURL == info.url ? [.isSelected] : [])
                .accessibilityLabel(Text(info.name))
                .accessibilityValue(Text(sourceAccessibilityValue(info)))
                .accessibilityHint("Select or display this storage source")
            }
        }
    }

    private func sourceAccessibilityValue(_ info: VolumeInfo) -> String {
        if vm.scannedURL == info.url { return "Currently viewing" }
        if selectedVolumeURL == info.url { return "Selected" }
        if vm.hasCachedScan(for: info.url) { return "Previously scanned" }
        return "Not selected"
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
        .disabled(vm.isDeleting || vm.isScanning)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }

    // MARK: Version / updates
    //
    // Updates install themselves, so there was previously nothing in the window
    // saying which version was running, whether a check had happened, or that a
    // new build had just been installed — the only surface was a menu item. This
    // is the quiet in-app equivalent: always shows the version, doubles as a
    // manual "check now", and reports what the updater is doing.

    @ViewBuilder
    private var updateRow: some View {
        VStack(spacing: 6) {
            if let previous = updater.justUpdatedFrom {
                updatedNotice(from: previous)
            }
            Button {
                updater.checkForUpdates()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: updater.status.symbol)
                        .font(.caption.weight(.semibold))

                    Text("Version \(updater.currentVersion)")
                        .font(.caption)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    Text(updater.status.shortTitle)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(updateRowTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.interactive)
            .disabled(!updater.canCheckForUpdates || updater.status.isBusy)
            .help(updateRowHelp)
            .accessibilityLabel(Text("Tessera version \(updater.currentVersion)"))
            .accessibilityValue(Text(updater.status.shortTitle))
            .accessibilityHint("Check for updates now")
        }
        .padding(.horizontal, 10)
    }

    private var updateRowTint: Color {
        switch updater.status {
        case .readyToInstall, .downloading, .installing: return Theme.electricBlue
        case .failed: return Theme.danger
        default: return Color.secondary
        }
    }

    private var updateRowHelp: String {
        switch updater.status {
        case .readyToInstall:
            return "An update is downloaded and installs as soon as the app is idle."
        case .failed(let message):
            return "Last update check failed: \(message)"
        default:
            return "Tessera updates itself automatically. Click to check now."
        }
    }

    /// One-time acknowledgement that a silent update landed.
    @ViewBuilder
    private func updatedNotice(from previous: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.electricBlue)
            Text("Updated to \(updater.currentVersion)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.foreground)
            Text("from \(previous)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button {
                updater.acknowledgeUpdate()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.icon(size: 18))
            .help("Dismiss")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.electricBlue.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.electricBlue.opacity(0.28), lineWidth: 1))
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                Text("Examples")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.6)
                Text("smb://nas.local/Media\nnfs://10.0.0.5/export\nhttps://dav.example.com/files")
                    .font(.caption.monospaced())
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
                .disabled(connectAddress.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting || vm.isDeleting || vm.isScanning)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func connect() {
        let address = connectAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty, !isConnecting, !vm.isDeleting, !vm.isScanning else { return }
        isConnecting = true
        connectError = nil
        Task { @MainActor in
            do {
                let mountURL = try await NetworkShareMounter.mount(address)
                guard !vm.isDeleting, !vm.isScanning else {
                    isConnecting = false
                    showConnectSheet = false
                    return
                }
                reloadVolumes()
                selectedVolumeURL = mountURL
                vm.selectedSourceURL = mountURL
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
        guard !vm.isDeleting, !vm.isScanning else { return }
        if selectedVolumeURL == nil {
            selectedVolumeURL = defaultSelection
        }
        vm.selectedSourceURL = selectedVolumeURL
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
            HStack(spacing: 10) {
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
                if isScanned {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.electricBlue)
                        .accessibilityLabel("Currently viewing")
                } else if isCached {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.tint)
                } else if let total = info.totalBytes {
                    Text(Theme.format(total))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                } else if info.subtitle != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }

            if let total = info.totalBytes, total > 0 {
                capacityBar(total: total)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            if isSelected {
                shape.fill(Theme.selectionTint)
            } else {
                shape.fill(.clear)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                    // Flat track + solid fill. Turns red when the disk is nearly
                    // full — the one place color carries meaning here.
                    Capsule()
                        .fill(Theme.surface)
                        .frame(height: 5)
                    Capsule()
                        .fill(fraction > 0.9 ? Theme.danger : Theme.electricBlue)
                        .frame(width: max(5, geo.size.width * fraction), height: 5)
                }
            }
            .frame(height: 5)

            Text("\(usedStr) used of \(totalStr)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}
