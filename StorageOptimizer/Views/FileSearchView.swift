import SwiftUI
import AppKit

/// Natural-language file search — type a free-text query ("videos over 1gb in
/// downloads older than 6 months") and it's turned into a structured filter and
/// run over the scanned tree. The built-in keyword parser always works; the
/// on-device model adds nuanced phrasing when downloaded. Results list the
/// matching files largest-first, each revealable in Finder and stageable into the
/// collector via the usual review flow. Pure on-device search; nothing leaves your
/// Mac and nothing is deleted here.
struct FileSearchView: View {
    @ObservedObject var vm: ScanViewModel

    @State private var query: String = ""
    @State private var result: SearchResult?
    @State private var isSearching = false
    /// Bumped each time a search starts so a slow (AI) plan that finishes after a
    /// newer one is ignored — the last query the user ran wins.
    @State private var runToken = 0
    @FocusState private var focused: Bool

    /// One resolved search: the query, the filter it produced, the matching nodes,
    /// and whether the on-device model produced the filter.
    private struct SearchResult {
        let query: String
        let filter: FileSearch.Filter
        let nodes: [FileNode]
        let usedAI: Bool
        var isEmpty: Bool { nodes.isEmpty }
        var totalBytes: Int64 { nodes.reduce(0) { $0 + $1.size } }
    }

    private let examples = [
        "Videos over 1 GB",
        "PDFs in Downloads",
        "Photos older than 1 year",
        "screenshots smaller than 5 mb",
    ]

    var body: some View {
        if vm.rootNode != nil {
            VStack(alignment: .leading, spacing: 12) {
                // Only badge as AI when the model is ready; the keyword search path
                // (used when the model isn't downloaded) is deterministic, not AI.
                FeatureSectionLabel("Search Files", ai: LocalAI.isAvailable)

                Text("Describe what you're looking for — type, size, age, name, or location. The on-device model reads only your words; the keyword search always works.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                searchField

                if result == nil && !isSearching {
                    exampleChips
                }

                if isSearching {
                    planningRow
                } else if let result {
                    resultView(result)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Input

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption).foregroundStyle(.secondary)
            TextField("e.g. videos over 1gb older than 6 months", text: $query)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit(run)
            if !query.isEmpty {
                Button {
                    query = ""
                    result = nil
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button(action: run) {
                Image(systemName: "arrow.right.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.electricBlue)
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(focused ? Theme.electricBlue.opacity(0.6) : .white.opacity(0.12),
                                  lineWidth: focused ? 1.5 : 1))
        )
    }

    private var exampleChips: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(examples, id: \.self) { example in
                Button {
                    query = example
                    run()
                } label: {
                    Text(example)
                        .font(.caption2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.07)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Result

    private var planningRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).scaleEffect(0.8)
            Text("Working out what matches…")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func resultView(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: result.usedAI ? "wand.and.stars" : "text.magnifyingglass")
                    .font(.caption2).foregroundStyle(Theme.electricBlue)
                Text(FileSearchParser.describe(result.filter))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.isEmpty {
                Label("Nothing matched that — try different wording.", systemImage: "magnifyingglass")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                resultsHeader(result)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.nodes) { file in
                        fileRow(file)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resultsHeader(_ result: SearchResult) -> some View {
        let count = result.nodes.count
        HStack(spacing: 8) {
            Text(count >= FileSearch.resultCap
                 ? "\(count)+ files · \(Theme.format(result.totalBytes))"
                 : "\(count) file\(count == 1 ? "" : "s") · \(Theme.format(result.totalBytes))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Button {
                for file in result.nodes where !vm.isCollected(file) { vm.addToCollector(file) }
            } label: {
                Label("Add all", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            .disabled(result.nodes.allSatisfy { vm.isCollected($0) })
        }
    }

    // MARK: File row

    @ViewBuilder
    private func fileRow(_ file: FileNode) -> some View {
        let collected = vm.isCollected(file)
        HStack(spacing: 6) {
            Image(systemName: FileKind.classify(node: file).symbol)
                .font(.caption).foregroundStyle(Theme.electricBlue).frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1).truncationMode(.middle)
                Text(displayPath(file))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Text(Theme.format(file.size))
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.plain).foregroundStyle(.tint)
            .help("Reveal in Finder")

            Button {
                if collected { vm.removeFromCollector(file) } else { vm.addToCollector(file) }
            } label: {
                Image(systemName: collected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(collected ? AnyShapeStyle(Theme.electricBlue) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .help(collected ? "Remove from the collector" : "Add to the collector")
        }
    }

    // MARK: Actions

    /// Plan the current query (AI when available, keyword fallback otherwise) and
    /// run the resulting filter over the scanned tree, off the main actor.
    private func run() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let root = vm.rootNode else { return }
        runToken += 1
        let token = runToken
        isSearching = true
        result = nil
        let now = Int64(Date().timeIntervalSince1970)
        Task {
            let plan = await FileSearch.plan(query: trimmed)
            let nodes = await Task.detached(priority: .userInitiated) {
                FileSearch.find(root: root, filter: plan.filter, nowEpochSeconds: now)
            }.value
            // Ignore a stale plan superseded by a newer search.
            guard token == runToken else { return }
            result = SearchResult(query: trimmed, filter: plan.filter,
                                  nodes: nodes, usedAI: plan.usedAI)
            isSearching = false
        }
    }

    // MARK: Formatting

    private func displayPath(_ node: FileNode) -> String {
        let dir = node.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) { return "~" + dir.dropFirst(home.count) }
        return dir
    }
}
