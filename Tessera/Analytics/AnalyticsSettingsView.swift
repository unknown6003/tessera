import SwiftUI

struct AnalyticsSettingsView: View {
    @ObservedObject private var analytics = Analytics.shared
    @State private var submitted = false

    var body: some View {
        Form {
            Section("Anonymous analytics") {
                Toggle("Share anonymous usage and performance data", isOn: Binding(
                    get: { analytics.isEnabled }, set: { analytics.setEnabled($0) }))
                    .disabled(!analytics.isConfigured)
                Text("Help improve scan speed and find broken flows. Sharing is off until you turn it on.")
                Text("We send fixed screen names, scan times, counts, source type and cleanup outcomes. We never send file names, paths, contents, searches or account names. Crash reports omit error text and file paths. PostHog receives the connection; location enrichment is off.")
                    .font(.callout).foregroundStyle(.secondary)
                if !analytics.isConfigured {
                    Label("Analytics is not configured in this build. No data is sent.", systemImage: "network.slash")
                }
                Text("Turning sharing off cancels analytics requests and clears its local queue and anonymous ID. It cannot recall data already sent.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if analytics.isEnabled, analytics.surveyID != nil {
                Section("Help improve Tessera") {
                    Text("How easy was it to find what uses your disk space?")
                    HStack {
                        ForEach(1...5, id: \.self) { rating in
                            Button(String(rating)) {
                                analytics.submitRating(rating)
                                submitted = true
                            }
                            .accessibilityLabel("\(rating) of 5, \(rating == 1 ? "very hard" : rating == 5 ? "very easy" : "neutral")")
                        }
                    }
                    Text("1 = very hard. 5 = very easy. Only your rating is sent.").font(.callout).foregroundStyle(.secondary)
                }
            }
            if submitted { Label("Rating sent. Thank you.", systemImage: "checkmark") }
            Section("Privacy") {
                Text("Disk analysis runs on your Mac. There is no account and no screen recording. Feature experiments can change presentation only; they cannot change scan depth or cleanup protection.")
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { analytics.start(); analytics.screen(.settings) }
    }
}
