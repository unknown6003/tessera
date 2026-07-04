import SwiftUI
import AppKit

/// On-device AI suggestions for the largest folders the built-in rules didn't
/// recognize. Review-only — never auto-staged. Shows only while the model is
/// working or once it has produced suggestions; otherwise it stays hidden.
struct SmartSuggestionsView: View {
    @ObservedObject var vm: ScanViewModel

    private var hasAnything: Bool {
        !vm.smartSuggestions.isEmpty || vm.isClassifyingSmart
    }

    var body: some View {
        if hasAnything {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    FeatureSectionLabel("Smart Suggestions", ai: true)
                    if vm.isClassifyingSmart {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                    }
                }

                if vm.isClassifyingSmart {
                    Text("The on-device model is reviewing the largest unrecognized folders. Nothing leaves your Mac.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !vm.smartSuggestions.isEmpty {
                    Text("Review each before adding — these are the model's guesses, not verified rules.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(vm.smartSuggestions) { result in
                    suggestionRow(result)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func suggestionRow(_ result: SmartCleanupClassifier.Result) -> some View {
        let added = vm.isCollected(result.node)
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.electricBlue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.node.name)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Text("\(result.category) · \(result.confidence)% confident")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(Theme.format(result.node.size))
                .font(.caption.monospacedDigit().weight(.semibold))
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([result.node.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.glass).controlSize(.small)
            .help("Reveal in Finder")
            Button {
                if added { vm.removeFromCollector(result.node) } else { vm.addToCollector(result.node) }
            } label: {
                Label(added ? "Added" : "Add", systemImage: added ? "checkmark" : "plus")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .tint(added ? Theme.electricBlue : nil)
        }
        .padding(.vertical, 2)
    }
}
