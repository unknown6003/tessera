import SwiftUI
import AppKit
import Combine

// MARK: - Sidebar

struct Sidebar: View {
    @ObservedObject var vm: ScanViewModel
    /// Display names for the window header, keyed by source URL.
    @Binding var sourceNames: [URL: String]
    /// Called when the source list gains keyboard focus (click or Tab).
    var onKeyboardFocus: () -> Void = {}
    /// Injected by TesseraApp; drives the version/update row in the footer.
    @EnvironmentObject private var updater: UpdaterController

    @State private var volumes: [VolumeInfo] = []
    @State private var customFolders: [VolumeInfo] = []
    @State private var isReloadingSources = false
    @State private var reloadSourcesAgain = false
    private var selectedVolumeURL: URL? {
        get { vm.selectedSourceURL }
        nonmutating set { vm.selectedSourceURL = newValue }
    }
    @State private var showFolderPicker = false
    /// The source list is one keyboard stop: ↑↓ move the selection, Return
    /// scans a source that is not on screen.
    @FocusState private var sourcesFocused: Bool

    // Connect-to-server sheet
    @State private var showConnectSheet = false
    @State private var connectAddress = ""
    @State private var connectError: String?
    @State private var isConnecting = false

    private let workspaceCenter = NSWorkspace.shared.notificationCenter

    private var allSources: [VolumeInfo] { volumes + customFolders }

    /// Chosen folders survive relaunch. Local preferences only (the app is not
    /// sandboxed, so a plain path is enough); never sent anywhere.
    private static let customFoldersKey = "Tessera.customFolderPaths"
    private static let customFoldersLimit = 12

    private func loadCustomFolders() {
        guard customFolders.isEmpty else { return }
        let paths = DebugAutomation.defaults.stringArray(forKey: Self.customFoldersKey) ?? []
        customFolders = paths.prefix(Self.customFoldersLimit).compactMap { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return nil }
            return VolumeInfo(folderURL: URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    private func saveCustomFolders() {
        let paths = customFolders.prefix(Self.customFoldersLimit).map(\.url.path)
        DebugAutomation.defaults.set(Array(paths), forKey: Self.customFoldersKey)
    }

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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(sections, id: \.kind) { section in
                                sectionView(title: section.kind.sectionTitle, items: section.items)
                            }
                        }
                        .focusable(!vm.isDeleting && !vm.isScanning)
                        .focused($sourcesFocused)
                        .focusEffectDisabled()
                        // With no listed source selected, ring the whole list
                        // so its focus is still visible.
                        .overlay {
                            if sourcesFocused && !orderedSources.contains(where: { $0.url == selectedVolumeURL }) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .inset(by: -4)
                                    .strokeBorder(Theme.electricBlue, lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                        }
                        .onKeyPress(keys: [.upArrow, .downArrow, .return]) { press in
                            guard press.modifiers.isDisjoint(with: [.command, .option, .control]) else { return .ignored }
                            return handleSourceKey(press.key) ? .handled : .ignored
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Sources")
                        .accessibilityHint("Use the up and down arrow keys to choose a source. Return scans it.")
                        addSourceRows
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
                .onChange(of: vm.selectedSourceURL) { _, url in
                    if let url { proxy.scrollTo(url) }
                }
            }

            Divider()
                .opacity(0.3)

            updateRow.padding(.vertical, 10)
        }
        .background(Theme.surface)
        .onAppear {
            loadCustomFolders()
            reloadVolumes()
        }
        .onChange(of: customFolders.map(\.url)) { _, _ in saveCustomFolders() }
        // Observe names as well as URLs: a source can be renamed in place.
        .onChange(of: sourceNameLookup, initial: true) { _, names in sourceNames = names }
        .onChange(of: sourcesFocused) { _, focused in if focused { onKeyboardFocus() } }
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
                    .foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            Button {
                reloadVolumes()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .tesseraButtonStyle(.icon)
            .help("Refresh sources")
            .disabled(isReloadingSources)
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
                    sourcesFocused = true
                    selectSource(info)
                } label: {
                    VolumeCard(info: info,
                               isSelected: selectedVolumeURL == info.url,
                               isScanned: vm.scannedURL == info.url,
                               isCached: vm.scannedURL != info.url && vm.hasCachedScan(for: info.url))
                }
                .buttonStyle(.plain)
                // The list is one Tab stop and arrow keys move the selection,
                // so a row is not a Tab stop of its own. The selection fill
                // marks the row; a 1 pt ring marks list focus.
                .focusable(false)
                .focusEffectDisabled()
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.electricBlue, lineWidth: 1)
                        .opacity(sourcesFocused && selectedVolumeURL == info.url ? 1 : 0)
                        .allowsHitTesting(false)
                )
                .id(info.url)
                // Busy: the action is off, the text stays readable. `selectSource`
                // and the key handler also refuse while scanning or removing.
                .allowsHitTesting(!sourcesBusy)
                .accessibilityAddTraits(selectedVolumeURL == info.url ? [.isSelected] : [])
                .accessibilityLabel(Text(sourceAccessibilityLabel(info)))
                .accessibilityValue(Text(sourceAccessibilityValue(info)))
                .accessibilityHint(sourcesBusy ? "Unavailable while a scan or cleanup runs"
                                               : "Select or display this storage source")
            }
        }
    }

    private var sourcesBusy: Bool { vm.isDeleting || vm.isScanning }

    private func selectSource(_ info: VolumeInfo) {
        guard !vm.isDeleting, !vm.isScanning else { return }
        selectedVolumeURL = info.url
        vm.selectedSourceURL = info.url
        // If we've already scanned this source, switch to it instantly.
        vm.showCachedScanIfAvailable(for: info.url)
    }

    /// URL to display name for every listed source, under both its URL and its
    /// standardized URL. Built from data already in memory; no file I/O.
    /// Later entries win on a repeated key, so duplicates cannot trap.
    private var sourceNameLookup: [URL: String] {
        Dictionary(allSources.flatMap { source in
            [(source.url, source.name), (source.url.standardizedFileURL, source.name)]
        }, uniquingKeysWith: { _, latest in latest })
    }

    /// Sources in on-screen order, across sections.
    private var orderedSources: [VolumeInfo] { sections.flatMap(\.items) }

    private func handleSourceKey(_ key: KeyEquivalent) -> Bool {
        guard !vm.isDeleting, !vm.isScanning else { return false }
        let sources = orderedSources
        guard !sources.isEmpty else { return false }
        let index = sources.firstIndex { $0.url == selectedVolumeURL }
        switch key {
        case .downArrow:
            selectSource(sources[min(sources.count - 1, (index ?? -1) + 1)])
        case .upArrow:
            selectSource(sources[max(0, (index ?? sources.count) - 1)])
        case .return:
            // ⌘R rescans the source on screen. Return only scans a new one.
            guard let index, vm.scannedURL != sources[index].url else { return false }
            vm.startScan(volumeURL: sources[index].url)
        default:
            return false
        }
        return true
    }

    /// Sources that share a name ("Nextcloud" for each account) add their
    /// abbreviated path so VoiceOver can tell them apart.
    private func sourceAccessibilityLabel(_ info: VolumeInfo) -> String {
        let sharesName = allSources.contains { $0.url != info.url && $0.name == info.name }
        guard sharesName else { return info.name }
        return "\(info.name), \((info.url.path as NSString).abbreviatingWithTildeInPath)"
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
        Button {
            guard !sourcesBusy else { return }
            action()
        } label: {
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
        .tesseraButtonStyle(.interactive)
        .allowsHitTesting(!sourcesBusy)
        .accessibilityHint(sourcesBusy ? "Unavailable while a scan or cleanup runs" : "")
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

                    // One short label that fits the 210 pt sidebar: the version
                    // at rest, the update state while one is in progress. The
                    // full action name is in the tooltip and the app menu.
                    Text(updateRowTitle)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(updateRowTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .tesseraButtonStyle(.interactive)
            .disabled(!updater.canCheckForUpdates || updater.status.isBusy)
            .help(updateRowHelp)
            .accessibilityLabel(Text("Tessera version \(updater.currentVersion)"))
            .accessibilityValue(Text(updater.status.shortTitle))
            .accessibilityHint("Check for updates now")
        }
        .padding(.horizontal, 10)
    }

    private var updateRowTitle: String {
        switch updater.status {
        case .idle, .upToDate: return "Version \(updater.currentVersion)"
        case .failed: return "Update check failed"
        default: return updater.status.shortTitle
        }
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
            .tesseraButtonStyle(.icon(size: 18))
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
        guard !isReloadingSources else {
            reloadSourcesAgain = true
            return
        }
        isReloadingSources = true
        let checkedFolders = customFolders.map(\.url)
        let checkedFolderIDs = Set(customFolders.map(\.id))
        Task { @MainActor in
            let snapshot = await StorageSourceDiscovery.discover(checkingFolders: checkedFolders)
            volumes = snapshot.sources
            // Keep folders added while this request was reading metadata.
            customFolders.removeAll { checkedFolderIDs.contains($0.id) && !snapshot.existingFolders.contains($0.url) }
            if !vm.isDeleting, !vm.isScanning, selectedVolumeURL == nil {
                selectedVolumeURL = defaultSelection
            }
            isReloadingSources = false
            if reloadSourcesAgain {
                reloadSourcesAgain = false
                reloadVolumes()
            }
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
            HStack(spacing: 10) {
                Image(systemName: info.kind.symbolName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                        .help(info.name)
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
                } else if info.totalBytes == nil, info.subtitle != nil {
                    // The capacity line below already shows the total.
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.mutedForeground)
                        .accessibilityHidden(true)
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

            // Muted, not tertiary: 7:1 on the sidebar surface (tertiary was 2.2:1).
            Text("\(usedStr) used of \(totalStr)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.mutedForeground)
        }
    }
}
