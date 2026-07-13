import SwiftUI
import AppKit

/// "Large & Old" lens — surfaces the long tail of big, stale files (old video
/// exports, forgotten installers, stale archives) that the rule-based cleanup
/// can't name. Pick a minimum size, an age window, and a kind; the results list
/// the matching files largest-first, each revealable in Finder and stageable into
/// the collector via the usual review flow. Pure on-device filtering; nothing is
/// deleted here.
struct LargeOldFilesView: View {
    @ObservedObject var vm: ScanViewModel

    // MARK: Filter pickers

    /// Minimum-size choices, in bytes.
    private enum MinSize: Int64, CaseIterable, Identifiable {
        case mb100 = 104_857_600        // 100 MB
        case mb500 = 524_288_000        // 500 MB
        case gb1   = 1_073_741_824      // 1 GB
        case gb5   = 5_368_709_120      // 5 GB
        var id: Int64 { rawValue }
        var label: String {
            switch self {
            case .mb100: return "100 MB"
            case .mb500: return "500 MB"
            case .gb1:   return "1 GB"
            case .gb5:   return "5 GB"
            }
        }
    }

    /// Age windows. `nil` days means "any age".
    private enum AgeWindow: Int, CaseIterable, Identifiable {
        case any = 0
        case d30 = 30
        case mo6 = 180
        case y1  = 365
        case y2  = 730
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .any: return "Any"
            case .d30: return "30d"
            case .mo6: return "6mo"
            case .y1:  return "1yr"
            case .y2:  return "2yr"
            }
        }
        var days: Int? { self == .any ? nil : rawValue }
    }

    @State private var minSize: MinSize = .gb1
    @State private var age: AgeWindow = .any
    /// `nil` = all kinds.
    @State private var kind: FileKind? = nil

    private var query: LargeOldFiles.Query {
        LargeOldFiles.Query(minSizeBytes: minSize.rawValue,
                            maxAgeDays: age.days,
                            kind: kind)
    }

    private var matches: [FileNode] {
        guard let root = vm.rootNode else { return [] }
        return LargeOldFiles.find(root: root, query: query)
    }

    var body: some View {
        if vm.rootNode != nil {
            VStack(alignment: .leading, spacing: 12) {
                FeatureSectionLabel("Large & Old Files")

                Text("Find big, stale files the rule-based cleanup can't name. Filter by size, age, and type, then review before staging.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                filters

                let rows = matches
                resultsHeader(count: rows.count)

                if rows.isEmpty {
                    Label("No files match these filters.", systemImage: "magnifyingglass")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(rows) { file in
                            fileRow(file)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Filters

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Min size").font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                Picker("", selection: $minSize) {
                    ForEach(MinSize.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            HStack(spacing: 8) {
                Text("Age").font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                Picker("", selection: $age) {
                    ForEach(AgeWindow.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            HStack(spacing: 8) {
                Text("Kind").font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
                Picker("", selection: $kind) {
                    Text("All").tag(FileKind?.none)
                    ForEach(FileKind.allCases) { k in
                        Text(k.title).tag(FileKind?.some(k))
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: Results header + "Add all"

    @ViewBuilder
    private func resultsHeader(count: Int) -> some View {
        let total = matches.reduce(Int64(0)) { $0 + $1.size }
        HStack(spacing: 8) {
            Text(count >= LargeOldFiles.resultCap
                 ? "\(count)+ files · \(Theme.format(total))"
                 : "\(count) file\(count == 1 ? "" : "s") · \(Theme.format(total))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Button {
                for file in matches where !vm.isCollected(file) { vm.addToCollector(file) }
            } label: {
                Label("Add all", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.flatProminent)
            .controlSize(.small)
            .disabled(matches.isEmpty || matches.allSatisfy { vm.isCollected($0) })
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
                HStack(spacing: 6) {
                    Text(displayPath(file))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    if let age = relativeAge(file) {
                        Text(age)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
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

    // MARK: Formatting

    private func displayPath(_ node: FileNode) -> String {
        let dir = node.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) { return "~" + dir.dropFirst(home.count) }
        return dir
    }

    /// "· 2yr ago" style relative age from the node's nanosecond modTime; nil when unknown.
    private func relativeAge(_ node: FileNode) -> String? {
        guard node.modTime > 0 else { return nil }
        let modSeconds = Double(node.modTime) / 1_000_000_000
        let date = Date(timeIntervalSince1970: modSeconds)
        return "· " + Self.ageFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static let ageFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
