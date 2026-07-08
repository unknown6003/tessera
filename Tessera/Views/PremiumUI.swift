import SwiftUI

// MARK: - Shared inspector chrome
//
// Lightweight, shared bits for the inspector's feature sections.

/// Uppercased label heading a single feature section in the inspector.
struct FeatureSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .kerning(0.8)
    }
}
