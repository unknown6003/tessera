import SwiftUI

// MARK: - Shared inspector chrome
//
// Lightweight, shared bits for the inspector's feature sections.

/// Calm, readable heading shared by the tool sheets.
struct FeatureSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }
}
