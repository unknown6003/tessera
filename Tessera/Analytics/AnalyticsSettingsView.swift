import SwiftUI

/// Settings > Privacy. Anonymous collection is part of normal runs and has no
/// switch. This pane states, in plain words, whether this run sends data and
/// exactly what it sends. The rating is optional, a fixed 1–5 control with no
/// free text.
struct AnalyticsSettingsView: View {
    @ObservedObject private var analytics = Analytics.shared
    @State private var sentRating: Int?

    var body: some View {
        Form {
            Section("Anonymous analytics") {
                Label(statusTitle, systemImage: statusSymbol)
                    .font(.headline)
                Text(statusDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("What is sent") {
                LabeledContent("Screens", value: "Fixed names, such as Explore, Rescue and Review")
                LabeledContent("Scans", value: "Phase times, file and folder counts, local, cloud or remote, coverage")
                LabeledContent("Cleanup", value: "Item, moved, held and failed counts, Trash or delete, duration")
                LabeledContent("Tools", value: "Which tool opened, such as Search or Duplicates")
                LabeledContent("Crashes", value: "Code addresses, app and macOS version")
                LabeledContent("ID", value: "A random ID made on this Mac")
            }
            .font(.callout)

            Section("Never sent") {
                Text("File and folder names, paths, file contents, search text, volume names, account names, hardware serials or error text. There is no screen recording and no session replay. Location lookup is off.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if analytics.isEnabled, analytics.surveyID != nil || sentRating != nil {
                Section("Optional rating") {
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
                        Text("1 is very hard, 5 is very easy. Skip it if you like. Only the number is sent.")
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

    private var statusTitle: String {
        if Analytics.isSuppressed { return "Not sending: automated run" }
        return analytics.isEnabled ? "On for every normal run" : "Not sending: no analytics key"
    }

    private var statusSymbol: String {
        analytics.isEnabled && !Analytics.isSuppressed ? "chart.bar.xaxis" : "network.slash"
    }

    private var statusDetail: String {
        if Analytics.isSuppressed { return "Tests and benchmarks never send analytics." }
        if analytics.isEnabled {
            return "Tessera sends anonymous usage and performance data to PostHog in the EU. It helps us make scans faster and find broken steps. There is no switch to turn it off."
        }
        return "This build has no analytics key, so it sends nothing."
    }

    private static func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "1 of 5, very hard"
        case 5: return "5 of 5, very easy"
        default: return "\(rating) of 5"
        }
    }
}
