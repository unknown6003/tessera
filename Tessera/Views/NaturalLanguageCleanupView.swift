import SwiftUI
import AppKit

/// Natural-language cleanup: type a goal ("free up 50 GB", "clear dev junk but
/// keep my projects") and the app turns it into a selection you can review. The
/// built-in keyword parser always works; the on-device model adds nuanced phrasing
/// when available. PRIVACY: everything runs locally — nothing leaves your Mac.
struct NaturalLanguageCleanupView: View {
    @ObservedObject var vm: ScanViewModel
    @FocusState private var focused: Bool

    private let examples = [
        "Free up 20 GB",
        "Clear all caches",
        "Dev junk but keep my projects",
        "Logs and build folders older than 3 months",
    ]

    var body: some View {
        if vm.cleanupReport != nil {
            VStack(alignment: .leading, spacing: 10) {
                // Badge the feature as AI only when the model is actually ready — it
                // falls back to the deterministic keyword parser otherwise, which
                // isn't an AI path and shouldn't be labelled as one.
                FeatureSectionLabel("Ask to Clean Up", ai: SmartCleanupClassifier.isAvailable)

                inputField

                if SmartCleanupClassifier.isAvailable {
                    Text("Describe what to clear in plain language. The on-device model reads only your words — never your files.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Type a goal like the examples below — matched on-device. (Apple Intelligence adds smarter phrasing when available.)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if vm.nlResult == nil && !vm.isPlanning {
                    exampleChips
                }

                if vm.isPlanning {
                    planningRow
                } else if let result = vm.nlResult {
                    resultView(result)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Input

    private var inputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle.magnifyingglass")
                .foregroundStyle(Theme.electricBlue)
            TextField("e.g. free up 20 GB of safe items", text: $vm.nlIntent)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { vm.runNaturalLanguageCleanup() }
            if !vm.nlIntent.isEmpty {
                Button {
                    vm.runNaturalLanguageCleanup()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.electricBlue)
                }
                .buttonStyle(.plain)
                .disabled(vm.isPlanning)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            let s = RoundedRectangle(cornerRadius: 12, style: .continuous)
            s.fill(.white.opacity(0.06))
                .overlay(s.strokeBorder(Theme.electricBlue.opacity(focused ? 0.6 : 0.25),
                                        lineWidth: focused ? 1.5 : 1))
        }
        .animation(.easeOut(duration: 0.15), value: focused)
    }

    private var exampleChips: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(examples, id: \.self) { example in
                Button {
                    vm.nlIntent = example
                    vm.runNaturalLanguageCleanup()
                } label: {
                    Text(example)
                        .font(.caption2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
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
    private func resultView(_ result: ScanViewModel.NLCleanupResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // What the planner decided to do.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: result.usedAI ? "wand.and.stars" : "text.magnifyingglass")
                    .font(.caption).foregroundStyle(Theme.electricBlue)
                Text(result.query.summary)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.isEmpty {
                Label("Nothing matched that — try different wording or a category like \"caches\".",
                      systemImage: "magnifyingglass")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                // Compact preview of the largest matches.
                ForEach(result.nodes.prefix(5)) { node in
                    HStack(spacing: 8) {
                        Image(systemName: Theme.icon(for: node))
                            .font(.caption).foregroundStyle(.tint).frame(width: 16)
                        Text(node.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(Theme.format(node.size))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([node.url])
                        } label: {
                            Image(systemName: "magnifyingglass").font(.caption2)
                        }
                        .buttonStyle(.plain).foregroundStyle(.tint)
                        .help("Reveal in Finder")
                    }
                }
                if result.nodes.count > 5 {
                    Text("+ \(result.nodes.count - 5) more")
                        .font(.caption2).foregroundStyle(.tertiary)
                }

                Button {
                    vm.stageNLResult()
                } label: {
                    Label(vm.nlResultAllStaged
                          ? "Added \(result.nodes.count) items to collector"
                          : "Add \(result.nodes.count) items · \(Theme.format(result.totalBytes))",
                          systemImage: vm.nlResultAllStaged ? "checkmark" : "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(vm.nlResultAllStaged)
            }

            Button("Clear") { vm.clearNLResult() }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}
