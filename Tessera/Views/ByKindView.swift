import SwiftUI
import AppKit

/// "By Kind" lens — a scan-wide breakdown of disk use by content type (images,
/// video, audio, …). Each kind shows its total size and file count with a
/// proportional bar; expanding a kind reveals its largest files, each revealable
/// in Finder and stageable into the collector via the usual review flow. Pure
/// on-device classification (filename extension only); nothing is deleted here.
struct ByKindView: View {
    @ObservedObject var vm: ScanViewModel

    /// How many largest-files to surface when a kind is expanded.
    private let largestN = 12

    @State private var expanded: FileKind?

    private var breakdown: [(kind: FileKind, bytes: Int64, count: Int)] {
        guard let root = vm.rootNode else { return [] }
        return FileKind.breakdown(root: root)
    }

    private var totalBytes: Int64 { breakdown.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        if vm.rootNode != nil {
            VStack(alignment: .leading, spacing: 12) {
                FeatureSectionLabel("By Kind")

                let rows = breakdown
                if rows.isEmpty {
                    Label("No files to categorize yet.", systemImage: "square.grid.2x2")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Disk use grouped by file type. Tap a kind to see its largest files.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(rows, id: \.kind) { row in
                        kindRow(row)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Kind row

    @ViewBuilder
    private func kindRow(_ row: (kind: FileKind, bytes: Int64, count: Int)) -> some View {
        let fraction = totalBytes > 0 ? Double(row.bytes) / Double(totalBytes) : 0
        let isOpen = expanded == row.kind

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
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
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

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
        let files = vm.rootNode.map { FileKind.largestFiles(of: kind, in: $0, limit: largestN) } ?? []

        if files.isEmpty {
            Text("No files of this kind.")
                .font(.caption2).foregroundStyle(.tertiary)
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

    private func displayPath(_ node: FileNode) -> String {
        let dir = node.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) { return "~" + dir.dropFirst(home.count) }
        return dir
    }
}
