import SwiftUI

// MARK: - Shared inspector chrome
//
// Lightweight, shared bits for the inspector's feature sections. All features are
// free; AI ones run on-device and carry the "AI" badge purely for transparency.

/// Gradient "AI" pill marking features powered by the on-device model.
struct AIBadge: View {
    var body: some View {
        Text("AI")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Theme.aiGradient))
            .help("Runs on-device — nothing leaves your Mac")
    }
}

/// Download / status control for the on-device AI model. The model is large, so
/// downloading is an explicit choice; until it's ready, AI features fall back to
/// their deterministic logic.
struct AIModelStatusView: View {
    @ObservedObject private var manager = MLXModelManager.shared

    var body: some View {
        switch manager.state {
        case .notLoaded:
            VStack(alignment: .leading, spacing: 4) {
                Button { manager.beginLoad() } label: {
                    Label(String(format: "Download AI model · ~%.1f GB", manager.approxDownloadGB),
                          systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                Text("Optional. Adds smarter, fully on-device understanding. Cleanup works without it.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .loading(let p):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ProgressView(value: p).frame(maxWidth: .infinity)
                    Text("\(Int(p * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Text("Downloading the on-device model…").font(.caption2).foregroundStyle(.tertiary)
            }

        case .ready:
            Label("On-device AI ready", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.medium)).foregroundStyle(.green)

        case .failed(let msg):
            VStack(alignment: .leading, spacing: 4) {
                Button { manager.beginLoad() } label: {
                    Label("Retry AI model download", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass).controlSize(.small)
                Text(msg).font(.caption2).foregroundStyle(.orange).lineLimit(3)
            }

        case .unsupported(let msg):
            Text(msg).font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Uppercased label heading a single feature section in the inspector.
struct FeatureSectionLabel: View {
    let text: String
    var ai: Bool = false
    init(_ text: String, ai: Bool = false) { self.text = text; self.ai = ai }
    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)
            if ai { AIBadge() }
        }
    }
}
