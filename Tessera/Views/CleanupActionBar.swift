import SwiftUI

/// The app-level task switcher. Rescue is the primary path; the other views are
/// named tools that open in a roomy sheet instead of a cramped popover.
struct CleanupActionBar: View {
    @ObservedObject var vm: ScanViewModel
    var onTrashAll: () -> Void

    private enum Tool: String, Identifiable, CaseIterable {
        case rescue, apps, duplicates, byKind, largeOld, search

        var id: String { rawValue }

        var label: String {
            switch self {
            case .rescue: return "Rescue"
            case .apps: return "Uninstall Apps"
            case .duplicates: return "Find Duplicates"
            case .byKind: return "Browse by Type"
            case .largeOld: return "Big & Old Files"
            case .search: return "Search Files"
            }
        }

        var symbol: String {
            switch self {
            case .rescue: return "lifepreserver.fill"
            case .apps: return "trash.square"
            case .duplicates: return "doc.on.doc"
            case .byKind: return "square.grid.2x2.fill"
            case .largeOld: return "clock.badge.exclamationmark"
            case .search: return "magnifyingglass"
            }
        }

        var description: String {
            switch self {
            case .rescue: return "A short, safe plan for making room."
            case .apps: return "Remove apps and their matching leftovers."
            case .duplicates: return "Compare identical files before staging copies."
            case .byKind: return "See which file types use the most space."
            case .largeOld: return "Find large files you may no longer need."
            case .search: return "Search the current scan with plain words."
            }
        }

        var sheetWidth: CGFloat { self == .rescue ? 780 : 720 }
    }

    @State private var presentedTool: Tool?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                presentedTool = .rescue
            } label: {
                Label(rescueTitle, systemImage: Tool.rescue.symbol)
            }
            .buttonStyle(.flatProminent)
            .controlSize(.regular)
            .help("Build a safe plan to make room")

            Menu {
                Section("Tools") {
                    ForEach(Tool.allCases.filter { $0 != .rescue }) { tool in
                        Button {
                            presentedTool = tool
                        } label: {
                            Label(tool.label, systemImage: tool.symbol)
                        }
                    }
                }
            } label: {
                Label("Tools", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.flat)
            .controlSize(.regular)
            .help("Open another way to explore this scan")

            Spacer(minLength: 0)

            if !vm.collector.isEmpty {
                Label("\(vm.collector.count) ready for review · \(Theme.format(vm.collectorTotalSize))",
                      systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $presentedTool) { tool in
            toolSheet(tool)
        }
    }

    private var rescueTitle: String {
        guard let plan = vm.rescuePlan, !plan.safeRecommendations.isEmpty else { return "Rescue" }
        let bytes = plan.safeRecommendations.reduce(0) { $0 + $1.physicalBytes }
        return "Rescue · \(Theme.format(bytes))"
    }

    @ViewBuilder
    private func toolSheet(_ tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tool.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(Theme.selectionTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.label)
                        .font(.title3.weight(.semibold))
                    Text(tool.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch tool {
                    case .rescue: CleanupSuggestionsView(vm: vm, onMoveToTrash: onTrashAll)
                    case .apps: AppUninstallerView(vm: vm)
                    case .duplicates: DuplicateFinderView(vm: vm)
                    case .byKind: ByKindView(vm: vm)
                    case .largeOld: LargeOldFilesView(vm: vm)
                    case .search: FileSearchView(vm: vm)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: tool.sheetWidth, height: 680)
        .background(Theme.bg)
    }
}
