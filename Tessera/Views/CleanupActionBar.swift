import SwiftUI

/// The app-level task switcher. Rescue is the primary path; specialist tools
/// open in a roomy sheet instead of a cramped popover.
struct CleanupActionBar: View {
    @ObservedObject var vm: ScanViewModel
    var onRescue: () -> Void

    private enum Tool: String, Identifiable, CaseIterable {
        case apps, duplicates, byKind, largeOld, search

        var id: String { rawValue }

        var label: String {
            switch self {
            case .apps: return "Uninstall Apps"
            case .duplicates: return "Find Duplicates"
            case .byKind: return "Browse by Type"
            case .largeOld: return "Big & Old Files"
            case .search: return "Search Files"
            }
        }

        var symbol: String {
            switch self {
            case .apps: return "trash.square"
            case .duplicates: return "doc.on.doc"
            case .byKind: return "square.grid.2x2.fill"
            case .largeOld: return "clock.badge.exclamationmark"
            case .search: return "magnifyingglass"
            }
        }

        var description: String {
            switch self {
            case .apps: return "Remove apps and their matching leftovers."
            case .duplicates: return "Compare identical files before staging copies."
            case .byKind: return "See which file types use the most space."
            case .largeOld: return "Find large files you may no longer need."
            case .search: return "Search the current scan with plain words."
            }
        }

        var sheetWidth: CGFloat { 720 }
    }

    @State private var presentedTool: Tool?

    var body: some View {
        Menu {
            Section("Explore this scan") {
                ForEach(Tool.allCases) { tool in
                    Button { presentedTool = tool } label: {
                        Label(tool.label, systemImage: tool.symbol)
                    }
                }
            }
            Divider()
            Button("Open Rescue", action: onRescue)
        } label: {
            Label("Tools", systemImage: "wrench.and.screwdriver")
        }
        .help("Search, duplicates, apps, file types and old files")
        .disabled(vm.isScanning || vm.isDeleting || vm.rootNode == nil)
        .sheet(item: $presentedTool) { tool in
            toolSheet(tool)
        }
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
                Button("Done") { presentedTool = nil }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch tool {
                    case .apps: AppUninstallerView(vm: vm)
                    case .duplicates: DuplicateFinderView(vm: vm)
                    case .byKind: ByKindView(vm: vm)
                    case .largeOld: LargeOldFilesView(vm: vm)
                    case .search: FileSearchView(vm: vm)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(vm.isDeleting || vm.isScanning)
            }
        }
        .frame(width: tool.sheetWidth, height: 680)
        .background(Theme.bg)
    }
}
