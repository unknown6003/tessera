import Foundation
import Combine
#if canImport(Sparkle)
import Sparkle
#endif

// MARK: - Auto-update (Sparkle OTA)
//
// The app is distributed directly (outside the Mac App Store — its full-disk
// scanning and `tmutil` use are incompatible with the App Sandbox), so updates are
// delivered over-the-air via Sparkle. Sparkle reads the appcast at `SUFeedURL`
// (Info.plist) and verifies every update's EdDSA signature against `SUPublicEDKey`
// before installing — so a tampered or unsigned build can never be installed.
//
// This is the ONLY auto-update mechanism and the only network traffic the app
// performs on its own. No user data is ever sent.

@MainActor
final class UpdaterController: ObservableObject {
    /// Whether a manual "Check for Updates…" can run right now (false briefly at
    /// launch and while a check is already in flight). Drives the menu item.
    @Published var canCheckForUpdates = false

    #if canImport(Sparkle)
    // Optional: Sparkle is only started once a REAL EdDSA public key is present.
    // With the placeholder key, Sparkle fatals during init ("public key is not
    // valid"), which would crash launch — so dev/unconfigured builds skip it and
    // the menu item stays disabled until SUPublicEDKey is set (see RELEASING.md).
    private let controller: SPUStandardUpdaterController?

    init() {
        guard Self.hasValidPublicKey else {
            controller = nil
            return
        }
        // startingUpdater: true begins Sparkle's scheduled background checks (it
        // asks the user's permission on first launch, per Sparkle's defaults).
        let c = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller = c
        c.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// User-initiated update check (shows Sparkle's UI).
    func checkForUpdates() {
        controller?.updater.checkForUpdates()
    }

    /// True only when Info.plist carries a real (non-placeholder) EdDSA public key.
    private static var hasValidPublicKey: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else { return false }
        return !key.isEmpty && !key.hasPrefix("REPLACE_WITH_")
    }
    #else
    // Sparkle not available in this build configuration — the menu item stays
    // disabled and no update checks run.
    init() {}
    func checkForUpdates() {}
    #endif
}
