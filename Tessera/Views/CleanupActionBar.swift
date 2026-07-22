import SwiftUI

/// Scan-wide tools shown above the chart. At wide sizes every tool is visible;
/// when the center column narrows, the secondary actions move into an explicit
/// overflow menu instead of silently scrolling out of reach.
struct CleanupActionBar: View {
    @ObservedObject var vm: ScanViewModel

    private enum Tool: String, Identifiable, CaseIterable {
        case cleanup, apps, duplicates, byKind, largeOld, search

        var id: String { rawValue }

        var label: String {
            switch self {
            case .cleanup:    return "Clean Up"
            case .apps:       return "Uninstall Apps"
            case .duplicates: return "Find Duplicates"
            case .byKind:     return "Browse by Type"
            case .largeOld:   return "Big & Old Files"
            case .search:     return "Search Files"
            }
        }

        var symbol: String {
            switch self {
            case .cleanup:    return "sparkles"
            case .apps:       return "trash.square"
            case .duplicates: return "doc.on.doc"
            case .byKind:     return "square.grid.2x2.fill"
            case .largeOld:   return "clock.badge.exclamationmark"
            case .search:     return "magnifyingglass"
            }
        }

        var popoverWidth: CGFloat {
            switch self {
            case .cleanup: return 380
            case .apps, .largeOld, .search: return 420
            case .duplicates, .byKind: return 400
            }
        }
    }

    @State private var presentedTool: Tool?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedToolbar
            compactToolbar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popover(item: $presentedTool, arrowEdge: .top) { tool in
            toolPopover(tool)
        }
    }

    /// Natural-width row used only when all six controls genuinely fit.
    private var expandedToolbar: some View {
        HStack(spacing: 10) {
            ForEach(Tool.allCases) { tool in
                toolButton(tool)
            }
        }
        .padding(.horizontal, 4)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// The primary action stays one click away; every secondary action is named in
    /// a conventional menu that works with mouse, keyboard, and VoiceOver.
    private var compactToolbar: some View {
        HStack(spacing: 8) {
            toolButton(.cleanup)

            Menu {
                ForEach(Tool.allCases.filter { $0 != .cleanup }) { tool in
                    Button {
                        presentedTool = tool
                    } label: {
                        Label(title(for: tool), systemImage: tool.symbol)
                    }
                }
            } label: {
                Label("More Tools", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.flat)
            .controlSize(.regular)
            .help("Open all scan tools")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func toolButton(_ tool: Tool) -> some View {
        Button {
            presentedTool = tool
        } label: {
            Label(title(for: tool), systemImage: tool.symbol)
        }
        .buttonStyle(.flat)
        .controlSize(.regular)
        .help(tool.label)
    }

    private func title(for tool: Tool) -> String {
        switch tool {
        case .cleanup:
            if let report = vm.cleanupReport, report.safeTotalBytes > 0 {
                return "Clean Up · \(Theme.format(report.safeTotalBytes))"
            }
        case .duplicates:
            if vm.didRunDuplicates, !vm.duplicateGroups.isEmpty {
                return "Duplicates · \(Theme.format(vm.duplicateReclaimableBytes))"
            }
        case .apps, .byKind, .largeOld, .search:
            break
        }
        return tool.label
    }

    @ViewBuilder
    private func toolPopover(_ tool: Tool) -> some View {
        ScrollView {
            Group {
                switch tool {
                case .cleanup:    CleanupSuggestionsView(vm: vm)
                case .apps:       AppUninstallerView(vm: vm)
                case .duplicates: DuplicateFinderView(vm: vm)
                case .byKind:     ByKindView(vm: vm)
                case .largeOld:   LargeOldFilesView(vm: vm)
                case .search:     FileSearchView(vm: vm)
                }
            }
            .padding(16)
        }
        .frame(width: tool.popoverWidth, height: 520)
    }
}
