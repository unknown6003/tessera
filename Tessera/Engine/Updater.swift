import Foundation
import Combine
#if canImport(Sparkle)
import Sparkle
#endif

// MARK: - Auto-update (Sparkle OTA, fully automatic)
//
// The app is distributed directly (outside the Mac App Store — its full-disk
// scanning and `tmutil` use are incompatible with the App Sandbox), so updates
// are delivered over-the-air via Sparkle.
//
// This is a HANDS-OFF updater: it checks on a schedule, downloads in the
// background, installs, and relaunches the app on its own. The user is never
// prompted and never has to click anything. That is implemented with a custom
// `SPUUserDriver` (`SilentUserDriver` below) whose only job is to auto-approve
// every decision Sparkle would normally raise a dialog for.
//
// Safety, in layers:
//  • Sparkle verifies every downloaded update's EdDSA signature against
//    `SUPublicEDKey` (Info.plist) before installing, so a tampered or unsigned
//    build can never be installed — the private key never leaves the release Mac.
//  • The auto-relaunch is POSTPONED while the app is mid-scan or while the user
//    has files staged in the Cleanup List, so an update can never yank the app
//    out from under work in progress or silently discard a staged list. Once the
//    app goes idle, the queued install proceeds.
//
// The update check is the ONLY network traffic the app performs on its own.
// No user data is ever sent.

/// What the updater is currently doing — surfaced in the app menu.
enum UpdateStatus: Equatable {
    case idle
    case checking
    case downloading(percent: Double?)
    case installing
    case upToDate
    case failed(String)

    /// Menu-item text for the "Check for Updates" command.
    var menuTitle: String {
        switch self {
        case .idle:                  return "Check for Updates Now"
        case .checking:              return "Checking for Updates…"
        case .downloading(let pct):
            if let pct { return "Downloading Update… \(Int(pct * 100))%" }
            return "Downloading Update…"
        case .installing:            return "Installing Update…"
        case .upToDate:              return "Tessera is Up to Date"
        case .failed:                return "Check for Updates Now"
        }
    }

    /// True while an update session is in flight (menu item disabled).
    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing: return true
        case .idle, .upToDate, .failed:            return false
        }
    }
}

@MainActor
final class UpdaterController: ObservableObject {
    /// Whether a manual check can run right now. Drives the menu item.
    @Published var canCheckForUpdates = false
    /// What the updater is doing, for the menu item's title.
    @Published var status: UpdateStatus = .idle

    /// Set by the UI: true while a scan is running or files are staged in the
    /// Cleanup List. While true, a downloaded update is held back rather than
    /// relaunching the app underneath the user. Flipping it back to false
    /// releases any queued install.
    var isBusy: Bool = false {
        didSet {
            guard oldValue != isBusy, !isBusy else { return }
            #if canImport(Sparkle)
            driver?.installIfQueued()
            #endif
        }
    }

    #if canImport(Sparkle)
    // Sparkle is only started once a REAL EdDSA public key is present. With a
    // placeholder key Sparkle fatals during init ("public key is not valid"),
    // which would crash launch — so dev/unconfigured builds skip it and the menu
    // item stays disabled until SUPublicEDKey is set (see RELEASING.md).
    private let updater: SPUUpdater?
    private let driver: SilentUserDriver?

    init() {
        guard Self.hasValidPublicKey else {
            updater = nil
            driver = nil
            return
        }

        let driver = SilentUserDriver()
        // Sparkle's own scheduling drives the checks. The automatic-check and
        // automatic-download defaults come from Info.plist (SUEnableAutomaticChecks,
        // SUAutomaticallyUpdate, SUScheduledCheckInterval) rather than being forced
        // here — Sparkle persists those in user defaults, and setting them on every
        // launch would override a user's later preference.
        let updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: driver,
            delegate: nil
        )
        self.updater = updater
        self.driver = driver

        driver.shouldPostponeInstall = { [weak self] in self?.isBusy ?? false }
        driver.onStatusChange = { [weak self] status in self?.status = status }

        do {
            try updater.start()
        } catch {
            // A failed start is not fatal: the app runs, it just won't self-update.
            status = .failed(error.localizedDescription)
            return
        }

        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// User-initiated check ("Check for Updates Now"). Same silent path — it
    /// just skips the wait for the next scheduled check.
    func checkForUpdates() {
        updater?.checkForUpdates()
    }

    /// True only when Info.plist carries a real (non-placeholder) EdDSA public key.
    private static var hasValidPublicKey: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else { return false }
        return !key.isEmpty && !key.hasPrefix("REPLACE_WITH_")
    }
    #else
    // Sparkle not available in this build configuration — no update checks run.
    init() {}
    func checkForUpdates() {}
    #endif
}

#if canImport(Sparkle)

// MARK: - Silent user driver
//
// Sparkle calls into an `SPUUserDriver` at every point it would normally show UI.
// This driver shows none: it answers "yes, install" to each decision and reports
// progress back for the menu item. The one exception is the final relaunch, which
// is held while `shouldPostponeInstall()` is true (scan running / cleanup list
// staged) and released the moment the app goes idle.
//
// Every method below is pinned to its exact Objective-C selector so conformance
// is matched by selector, not by a Swift name spelling.

@MainActor
final class SilentUserDriver: NSObject, SPUUserDriver {
    /// Set by UpdaterController — true while it's unsafe to relaunch.
    var shouldPostponeInstall: () -> Bool = { false }
    var onStatusChange: (UpdateStatus) -> Void = { _ in }

    /// A completed download waiting for the app to go idle before it relaunches.
    private var queuedInstall: ((SPUUserUpdateChoice) -> Void)?
    /// Total bytes, for turning byte counts into a percentage.
    private var expectedLength: UInt64 = 0
    private var receivedLength: UInt64 = 0

    /// Called when the app goes idle: run a relaunch that was held back.
    func installIfQueued() {
        guard let reply = queuedInstall else { return }
        queuedInstall = nil
        onStatusChange(.installing)
        reply(.install)
    }

    // MARK: Permission & checking

    // Never ask. Automatic checks are on by default (SUEnableAutomaticChecks in
    // Info.plist normally means this is never even called).
    @objc(showUpdatePermissionRequest:reply:)
    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    @objc(showUserInitiatedUpdateCheckWithCancellation:)
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        onStatusChange(.checking)
    }

    // MARK: The update itself — always install

    @objc(showUpdateFoundWithAppcastItem:state:reply:)
    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        onStatusChange(.downloading(percent: nil))
        reply(.install)
    }

    @objc(showUpdateReleaseNotesWithDownloadData:)
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    @objc(showUpdateReleaseNotesFailedToDownloadWithError:)
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    @objc(showUpdateNotFoundWithError:acknowledgement:)
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        onStatusChange(.upToDate)
        acknowledgement()
    }

    @objc(showUpdaterError:acknowledgement:)
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        queuedInstall = nil
        onStatusChange(.failed(error.localizedDescription))
        acknowledgement()
    }

    // MARK: Download / extract progress

    @objc(showDownloadInitiatedWithCancellation:)
    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        expectedLength = 0
        receivedLength = 0
        onStatusChange(.downloading(percent: nil))
    }

    @objc(showDownloadDidReceiveExpectedContentLength:)
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        expectedLength = expectedContentLength
        receivedLength = 0
    }

    @objc(showDownloadDidReceiveDataOfLength:)
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedLength += length
        guard expectedLength > 0 else { return }
        let pct = min(1.0, Double(receivedLength) / Double(expectedLength))
        onStatusChange(.downloading(percent: pct))
    }

    @objc(showDownloadDidStartExtractingUpdate)
    func showDownloadDidStartExtractingUpdate() {
        onStatusChange(.installing)
    }

    @objc(showExtractionReceivedProgress:)
    func showExtractionReceivedProgress(_ progress: Double) {
        onStatusChange(.installing)
    }

    // MARK: Install & relaunch — the only place we ever wait

    @objc(showReadyToInstallAndRelaunch:)
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // Never relaunch out from under a running scan or a staged Cleanup List.
        // Hold the update; UpdaterController releases it via installIfQueued()
        // as soon as the app is idle. It also lands on next launch regardless,
        // because Sparkle installs a downloaded update on quit.
        if shouldPostponeInstall() {
            queuedInstall = reply
            return
        }
        onStatusChange(.installing)
        reply(.install)
    }

    @objc(showInstallingUpdateWithApplicationTerminated:retryTerminatingApplication:)
    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        onStatusChange(.installing)
    }

    @objc(showUpdateInstalledAndRelaunched:acknowledgement:)
    func showUpdateInstalledAndRelaunched(
        _ relaunched: Bool,
        acknowledgement: @escaping () -> Void
    ) {
        onStatusChange(.idle)
        acknowledgement()
    }

    @objc(showUpdateInFocus)
    func showUpdateInFocus() {}

    @objc(dismissUpdateInstallation)
    func dismissUpdateInstallation() {
        onStatusChange(.idle)
    }
}

#endif
