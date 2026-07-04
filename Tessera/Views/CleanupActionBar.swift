import SwiftUI

/// Top action bar over the chart. Holds the scan-wide tools — Clean Up (rule-based
/// suggestions + on-device AI) and Find Duplicates — as buttons that open popovers,
/// so the inspector can stay focused on the selected item and these tools are one
/// click away instead of buried in a long sidebar scroll.
struct CleanupActionBar: View {
    @ObservedObject var vm: ScanViewModel
    @State private var showCleanup = false
    @State private var showDuplicates = false
    @State private var showByKind = false
    @State private var showLargeOld = false
    @State private var showSearch = false
    @State private var showApps = false

    var body: some View {
        // The bar holds six tools; at the window's minimum width the center column is
        // only ~300pt, so the buttons are kept at .regular size and wrapped in a
        // horizontal ScrollView that degrades gracefully (scroll) instead of clipping.
        // The staged total lives only in the collector dock header (its canonical
        // place) — duplicating it here was redundant.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                cleanupButton
                appsButton
                duplicatesButton
                byKindButton
                largeOldButton
                searchButton
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Clean Up

    private var cleanupButton: some View {
        Button { showCleanup.toggle() } label: {
            Label(cleanupTitle, systemImage: "sparkles")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .popover(isPresented: $showCleanup, arrowEdge: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AIModelStatusView()
                    NaturalLanguageCleanupView(vm: vm)
                    CleanupSuggestionsView(vm: vm)
                    SmartSuggestionsView(vm: vm)
                }
                .padding(16)
            }
            .frame(width: 380, height: 520)
        }
    }

    private var cleanupTitle: String {
        if let report = vm.cleanupReport, report.safeTotalBytes > 0 {
            return "Clean Up · \(Theme.format(report.safeTotalBytes))"
        }
        return "Clean Up"
    }

    // MARK: Apps (uninstaller)

    private var appsButton: some View {
        Button { showApps.toggle() } label: {
            Label("Apps", systemImage: "trash.square")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .popover(isPresented: $showApps, arrowEdge: .top) {
            ScrollView {
                AppUninstallerView(vm: vm).padding(16)
            }
            .frame(width: 420, height: 520)
        }
    }

    // MARK: Duplicates

    private var duplicatesButton: some View {
        Button { showDuplicates.toggle() } label: {
            Label(duplicatesTitle, systemImage: "doc.on.doc")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .popover(isPresented: $showDuplicates, arrowEdge: .top) {
            ScrollView {
                DuplicateFinderView(vm: vm).padding(16)
            }
            .frame(width: 400, height: 520)
        }
    }

    private var duplicatesTitle: String {
        if vm.didRunDuplicates, !vm.duplicateGroups.isEmpty {
            return "Duplicates · \(Theme.format(vm.duplicateReclaimableBytes))"
        }
        return "Find Duplicates"
    }

    // MARK: By Kind

    private var byKindButton: some View {
        Button { showByKind.toggle() } label: {
            Label("By Kind", systemImage: "square.grid.2x2.fill")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .popover(isPresented: $showByKind, arrowEdge: .top) {
            ScrollView {
                ByKindView(vm: vm).padding(16)
            }
            .frame(width: 400, height: 520)
        }
    }

    // MARK: Large & Old

    private var largeOldButton: some View {
        Button { showLargeOld.toggle() } label: {
            Label("Large & Old", systemImage: "clock.badge.exclamationmark")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .popover(isPresented: $showLargeOld, arrowEdge: .top) {
            ScrollView {
                LargeOldFilesView(vm: vm).padding(16)
            }
            .frame(width: 420, height: 520)
        }
    }

    // MARK: Search

    private var searchButton: some View {
        Button { showSearch.toggle() } label: {
            Label("Search", systemImage: "magnifyingglass")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .popover(isPresented: $showSearch, arrowEdge: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AIModelStatusView()
                    FileSearchView(vm: vm)
                }
                .padding(16)
            }
            .frame(width: 420, height: 520)
        }
    }
}
