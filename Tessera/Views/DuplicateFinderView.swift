import SwiftUI
import AppKit

/// On-device duplicate finder. Detection never sends file data anywhere; the
/// keeper for each set is chosen by a local heuristic, and every copy can be
/// revealed in Finder before anything is staged for deletion.
struct DuplicateFinderView: View {
    @ObservedObject var vm: ScanViewModel

    private let maxGroupsShown = 20

    var body: some View {
        if vm.rootNode != nil {
            VStack(alignment: .leading, spacing: 10) {
                FeatureSectionLabel("Duplicate Finder")

                if vm.isFindingDuplicates {
                    findingRow
                } else if !vm.didRunDuplicates {
                    idleRow
                } else if vm.duplicateGroups.isEmpty {
                    Label("No duplicate files found.", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    resultsHeader
                    ForEach(vm.duplicateGroups.prefix(maxGroupsShown)) { group in
                        groupRow(group)
                    }
                    if vm.duplicateGroups.count > maxGroupsShown {
                        Text("+ \(vm.duplicateGroups.count - maxGroupsShown) more groups")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var idleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find files with identical content across the scan and reclaim the redundant copies.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                vm.findDuplicates()
            } label: {
                Label("Find Duplicates", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.flat)
            .controlSize(.large)
        }
    }

    private var findingRow: some View {
        HStack(spacing: 8) {
            ProgressView(value: vm.duplicateProgress.fraction)
                .frame(maxWidth: .infinity)
            Text("\(Int(vm.duplicateProgress.fraction * 100))%")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Button("Stop") { vm.cancelDuplicates() }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    private var resultsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(vm.duplicateGroups.count) duplicate set\(vm.duplicateGroups.count == 1 ? "" : "s") · \(Theme.format(vm.duplicateReclaimableBytes)) reclaimable")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    vm.stageAllDuplicates()
                } label: {
                    Label(vm.allDuplicatesStaged ? "All copies added" : "Add all redundant copies",
                          systemImage: vm.allDuplicatesStaged ? "checkmark" : "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.flatProminent)
                .controlSize(.regular)
                .disabled(vm.allDuplicatesStaged)

                Button("Rescan") { vm.findDuplicates() }
                    .buttonStyle(.flat)
                    .controlSize(.regular)
            }
        }
    }

    @ViewBuilder
    private func groupRow(_ group: DuplicateGroup) -> some View {
        let staged = vm.isDuplicateGroupStaged(group)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: Theme.icon(for: group.files[group.keepIndex]))
                    .font(.caption).foregroundStyle(.tint).frame(width: 16)
                Text("\(group.count) copies · \(Theme.format(group.perFileBytes)) each")
                    .font(.caption.weight(.medium)).lineLimit(1)
                Spacer(minLength: 6)
                Text(Theme.format(group.reclaimableBytes))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.electricBlue)
                Button {
                    vm.toggleDuplicateGroup(group)
                } label: {
                    Image(systemName: staged ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(staged ? AnyShapeStyle(Theme.electricBlue) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .help(staged ? "Remove these copies from the collector" : "Add the redundant copies to the collector")
            }

            // Keeper + reason.
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9)).foregroundStyle(.green)
                Text("Keep")
                    .font(.caption2).foregroundStyle(.tertiary)
                Text(group.files[group.keepIndex].name)
                    .font(.caption2.weight(.medium)).lineLimit(1)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([group.files[group.keepIndex].url])
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 9))
                }
                .buttonStyle(.plain).foregroundStyle(.green)
                .help("Reveal the kept copy in Finder")
                Spacer(minLength: 0)
            }
            Text(group.keepReason)
                .font(.caption2).foregroundStyle(.tertiary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)

            // The redundant copies that would be removed — each revealable in Finder.
            ForEach(Array(group.removableFiles.prefix(4).enumerated()), id: \.offset) { _, file in
                HStack(spacing: 4) {
                    Text(sourcePath(file))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 2)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .help("Reveal this copy in Finder")
                }
            }
            if group.removableFiles.count > 4 {
                Text("+ \(group.removableFiles.count - 4) more")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourcePath(_ node: FileNode) -> String {
        let dir = node.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) { return "~" + dir.dropFirst(home.count) + "/" + node.name }
        return dir + "/" + node.name
    }
}
