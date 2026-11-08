import SwiftUI

/// Settings > Privacy. One switch, off until the user turns it on. The text
/// says what is sent and what is not, in plain words. The rating survey is a
/// fixed native control; it shows only when sharing is on and a survey is live.
struct AnalyticsSettingsView: View {
    @ObservedObject private var analytics = Analytics.shared
    @State private var sentRating: Int?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { analytics.isEnabled }, set: { analytics.setEnabled($0) })) {
                    Text("Share anonymous usage data")
                    Text("Off by default. Helps us make scans faster and fix broken steps.")
                }
                .disabled(!analytics.isConfigured)
                if !analytics.isConfigured {
                    Label("This build has no analytics key. Nothing is sent.", systemImage: "network.slash")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Anonymous analytics")
            }

            Section("What is sent") {
                LabeledContent("Sent", value: "Screen names, scan times, item counts, source type, cleanup results")
                LabeledContent("Never sent", value: "File names, paths, contents, searches, volume or account names")
                LabeledContent("Crash reports", value: "Code addresses only, no error text or paths")
            }
            .font(.callout)

            Section {
                Text("Turning sharing off stops new requests and clears the local queue and anonymous ID. Data already sent stays sent.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if analytics.isEnabled, analytics.surveyID != nil || sentRating != nil {
                Section("Quick rating") {
                    if let sentRating {
                        Label("Sent \(sentRating) of 5. Thank you.", systemImage: "checkmark")
                    } else {
                        Text("How easy was it to find what uses your disk space?")
                        Picker("Rating", selection: Binding<Int?>(get: { nil }, set: { rating in
                            guard let rating else { return }
                            analytics.submitRating(rating)
                            sentRating = rating
                        })) {
                            ForEach(1...5, id: \.self) { rating in
                                Text(String(rating)).tag(Int?.some(rating))
                                    .accessibilityLabel(Self.ratingLabel(rating))
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("1 is very hard, 5 is very easy. Only the number is sent.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Disk analysis runs on this Mac. Tessera has no account. Experiments can change layout only, never what a scan reads or what cleanup protects.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            analytics.start()
            analytics.screen(.settings)
            analytics.surveyShown()
        }
    }

    private static func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "1 of 5, very hard"
        case 5: return "5 of 5, very easy"
        default: return "\(rating) of 5"
        }
    }
}
