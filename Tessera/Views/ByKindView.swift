import SwiftUI
import AppKit

/// "By Kind" lens — a scan-wide breakdown of disk use by content type (images,
/// video, audio, …). Each kind shows its total size and file count with a
/// proportional bar; expanding a kind reveals its largest files, each revealable
/// in Finder and stageable into the collector via the usual review flow. Pure
/// on-device classification (filename extension only); nothing is deleted here.
struct ByKindView: View {
    @ObservedObject var vm: ScanViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How many largest-files to surface when a kind is expanded.
    private let largestN = 12

    @State private var expanded: FileKind?
    @State private var breakdown: [(kind: FileKind, bytes: Int64, count: Int)] = []
    @State private var largest: [FileNode] = []
    @State private var isLoading = false
    @State private var isLoadingLargest = false

    private struct LargestKey: Equatable {
        let tree: ScanTreeRevision
        let kind: FileKind?
    }

    private var totalBytes: Int64 { breakdown.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        if vm.rootNode != nil {
            VStack(alignment: .leading, spacing: 12) {
                FeatureSectionLabel("By Kind")

                let rows = breakdown
                if isLoading {
                    ProgressView("Reading file types…")
                } else if rows.isEmpty {
                    Label("No files to categorize yet.", systemImage: "square.grid.2x2")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Disk use grouped by file type. Tap a kind to see its largest files.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(rows, id: \.kind) { row in
                        kindRow(row)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: vm.treeRevision) { await loadBreakdown() }
            .task(id: LargestKey(tree: vm.treeRevision, kind: expanded)) { await loadLargest() }
        }
    }

    private func loadBreakdown() async {
        let revision = vm.treeRevision
        isLoading = true
        breakdown = []
        let rows = await vm.readTree { root, cancel in
            FileKind.breakdown(root: root, shouldStop: { cancel.isCancelled })
        }
        guard !Task.isCancelled, revision == vm.treeRevision else { return }
        breakdown = rows ?? []
        isLoading = false
    }

    private func loadLargest() async {
        largest = []
        guard let kind = expanded else { isLoadingLargest = false; return }
        let revision = vm.treeRevision
        let limit = largestN
        isLoadingLargest = true
        let files = await vm.readTree { root, cancel in
            FileKind.largestFiles(of: kind, in: root, limit: limit, shouldStop: { cancel.isCancelled })
        }
        guard !Task.isCancelled, revision == vm.treeRevision, expanded == kind else { return }
        largest = files ?? []
        isLoadingLargest = false
    }

    // MARK: Kind row

    @ViewBuilder
    private func kindRow(_ row: (kind: FileKind, bytes: Int64, count: Int)) -> some View {
        let fraction = totalBytes > 0 ? Double(row.bytes) / Double(totalBytes) : 0
        let isOpen = expanded == row.kind

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    expanded = isOpen ? nil : row.kind
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: row.kind.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.electricBlue)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(row.kind.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(Theme.format(row.bytes))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        bar(fraction: fraction)
                        Text("\(row.count) file\(row.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .tesseraButtonStyle(.interactive)

            if isOpen {
                largestFiles(for: row.kind)
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 2)
    }

    private func bar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Theme.electricBlue.opacity(0.85))
                    .frame(width: max(2, geo.size.width * fraction))
            }
        }
        .frame(height: 5)
    }

    // MARK: Largest files of a kind

    @ViewBuilder
    private func largestFiles(for kind: FileKind) -> some View {
        let files = largest

        if isLoadingLargest {
            ProgressView("Finding largest files…").controlSize(.small)
        } else if files.isEmpty {
            Text("No files of this kind.")
                .font(.caption).foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(files) { file in
                    fileRow(file)
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ file: FileNode) -> some View {
        let collected = vm.isCollected(file)
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1).truncationMode(.middle)
                Text(displayPath(file))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Text(Theme.format(file.size))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            } label: {
                Image(systemName: "magnifyingglass").font(.caption)
            }
            .tesseraButtonStyle(.interactive).foregroundStyle(.tint)
            .help("Reveal in Finder")

            Button {
                if collected { vm.removeFromCollector(file) } else { vm.addToCollector(file) }
            } label: {
                Image(systemName: collected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(collected ? AnyShapeStyle(Theme.electricBlue) : AnyShapeStyle(.secondary))
            }
            .tesseraButtonStyle(.interactive)
            .help(collected ? "Remove from the collector" : "Add to the collector")
        }
    }

    private func displayPath(_ node: FileNode) -> String {
        let dir = node.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) { return "~" + dir.dropFirst(home.count) }
        return dir
    }
}
