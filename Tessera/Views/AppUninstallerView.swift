import SwiftUI
import AppKit

/// App Uninstaller — the flagship cleanup lens. Lists installed apps largest-first
/// (bundle size plus the support files macOS scatters across ~/Library and
/// /Library), and lets the user fully remove an app: the bundle and every
/// associated leftover are staged into the collector for review, then trashed
/// through the existing confirmation flow. Nothing is deleted here. Leftover
/// association is deliberately conservative (bundle-id or exact-name only) so the
/// app never stages a file that doesn't belong to the selected app. Everything
/// runs on-device — no file data leaves the Mac.
struct AppUninstallerView: View {
    @ObservedObject var vm: ScanViewModel

    @State private var apps: [InstalledApp] = []
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var selectedID: InstalledApp.ID?

    @State private var orphans: [AppUninstaller.OrphanGroup] = []

    private var selectedApp: InstalledApp? {
        apps.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureSectionLabel("App Uninstaller")

            Text("Remove an app together with the caches, preferences, containers, and logs it leaves behind. Everything is staged for your review before it goes to the Trash.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let app = selectedApp {
                detail(app)
            } else if isLoading {
                loadingRow
            } else if didLoad && apps.isEmpty && orphans.isEmpty {
                Label("No removable apps found in /Applications or ~/Applications.",
                      systemImage: "app.dashed")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
            } else if !didLoad {
                idleRow
            } else {
                appList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { if !didLoad { await load() } }
    }

    // MARK: Loading

    private var idleRow: some View {
        Button { Task { await load() } } label: {
            Label("Scan installed apps", systemImage: "app.badge")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.flat)
        .controlSize(.large)
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Scanning installed apps…").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func load() async {
        isLoading = true
        let result = await Task.detached(priority: .userInitiated) {
            (apps: AppUninstaller.scanInstalledApps(),
             orphans: AppUninstaller.orphanedLeftovers())
        }.value
        apps = result.apps
        orphans = result.orphans
        isLoading = false
        didLoad = true
    }

    // MARK: App list

    private var appList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(apps.count) app\(apps.count == 1 ? "" : "s") · \(Theme.format(apps.reduce(Int64(0)) { $0 + $1.totalBytes }))")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
                .help("Rescan installed apps")
            }

            ForEach(apps) { app in
                appRow(app)
            }

            if !orphans.isEmpty {
                orphansSection
            }
        }
    }

    // MARK: Leftovers from removed apps (orphans)

    private var orphanTotalBytes: Int64 {
        orphans.reduce(Int64(0)) { $0 + $1.totalBytes }
    }

    private var orphansSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 4)

            HStack(spacing: 6) {
                FeatureSectionLabel("Leftovers from removed apps")
                Spacer(minLength: 4)
                Button {
                    for group in orphans { vm.stageOrphanGroup(group) }
                } label: {
                    Text("Add all").font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.flat)
                .controlSize(.small)
                .disabled(orphans.allSatisfy { vm.isOrphanGroupStaged($0) })
            }

            Text("Support files whose app is no longer installed. Each is a confident bundle-id match — review in the collector before trashing.")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(orphans.count) group\(orphans.count == 1 ? "" : "s") · \(Theme.format(orphanTotalBytes))")
                .font(.caption2).foregroundStyle(.secondary)

            ForEach(orphans) { group in
                orphanRow(group)
            }
        }
    }

    @ViewBuilder
    private func orphanRow(_ group: AppUninstaller.OrphanGroup) -> some View {
        let staged = vm.isOrphanGroupStaged(group)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 11)).foregroundStyle(Theme.electricBlue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.displayName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1).truncationMode(.middle)
                    Text("\(group.bundleID) · \(group.itemCount) item\(group.itemCount == 1 ? "" : "s")")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 4)
                Text(Theme.format(group.totalBytes))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting(group.items.map(\.url))
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
                .help("Reveal in Finder")
                Button {
                    vm.stageOrphanGroup(group)
                } label: {
                    Image(systemName: staged ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(staged ? Theme.electricBlue : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(staged)
                .help(staged ? "Staged in collector" : "Add to collector")
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func appRow(_ app: InstalledApp) -> some View {
        let staged = vm.isAppStaged(app)
        Button { selectedID = app.id } label: {
            HStack(spacing: 8) {
                appIcon(app.appURL)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1).truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(Theme.format(app.appBytes) + " app")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        if app.leftoverCount > 0 {
                            Text("+ \(app.leftoverCount) leftover\(app.leftoverCount == 1 ? "" : "s") · \(Theme.format(app.leftoverBytes))")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.electricBlue)
                        }
                    }
                }
                Spacer(minLength: 4)
                if staged {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(Theme.electricBlue)
                }
                Text(Theme.format(app.totalBytes))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    // MARK: Detail (selected app)

    @ViewBuilder
    private func detail(_ app: InstalledApp) -> some View {
        let staged = vm.isAppStaged(app)
        VStack(alignment: .leading, spacing: 10) {
            // Back + header.
            Button { selectedID = nil } label: {
                Label("All apps", systemImage: "chevron.left")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(.tint)

            HStack(spacing: 8) {
                appIcon(app.appURL, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name).font(.callout.weight(.semibold)).lineLimit(1)
                    if !app.bundleID.isEmpty {
                        Text(app.bundleID)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                }
                Spacer(minLength: 4)
                Text(Theme.format(app.totalBytes))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Theme.electricBlue)
            }

            // Uninstall action — stages bundle + all leftovers into the collector.
            Button {
                vm.stageAppForUninstall(app)
            } label: {
                Label(staged ? "Staged for removal" : "Uninstall (stage \(app.leftoverCount + 1) item\(app.leftoverCount == 0 ? "" : "s"))",
                      systemImage: staged ? "checkmark" : "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.flatProminent)
            .controlSize(.large)
            .disabled(staged)

            Text("Review staged items in the collector, then move them to the Trash.")
                .font(.system(size: 9)).foregroundStyle(.tertiary)

            Divider()

            // The app bundle row.
            targetRow(url: app.appURL, name: app.appURL.lastPathComponent,
                      bytes: app.appBytes, badge: "App bundle", tint: .primary)

            // Each leftover.
            if app.leftovers.isEmpty {
                Label("No leftover files found.", systemImage: "checkmark.circle")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Leftovers")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.top, 2)
                ForEach(app.leftovers) { leftover in
                    targetRow(url: leftover.url, name: leftover.url.lastPathComponent,
                              bytes: leftover.bytes,
                              badge: leftover.category, tint: Theme.electricBlue,
                              reason: leftover.matchedBy.rawValue)
                }
            }
        }
    }

    @ViewBuilder
    private func targetRow(url: URL, name: String, bytes: Int64,
                           badge: String, tint: Color, reason: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(badge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(tint.opacity(0.12)))
                Text(name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                Text(Theme.format(bytes))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
                .help("Reveal in Finder")
            }
            HStack(spacing: 4) {
                Text(displayPath(url))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
                if let reason {
                    Text("· \(reason)")
                        .font(.system(size: 9)).foregroundStyle(.quaternary)
                }
            }
        }
        .padding(.vertical, 1)
    }

    // MARK: Helpers

    private func displayPath(_ url: URL) -> String {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    @ViewBuilder
    private func appIcon(_ url: URL, size: CGFloat = 18) -> some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable().interpolation(.high)
            .frame(width: size, height: size)
    }
}
