import Foundation
import Combine
@preconcurrency import PostHog

enum AnalyticsValue: Sendable {
    case text(String), integer(Int), decimal(Double), boolean(Bool)

    var raw: Any {
        switch self {
        case .text(let value): return value
        case .integer(let value): return value
        case .decimal(let value): return value
        case .boolean(let value): return value
        }
    }
}

struct AnalyticsConfiguration: Sendable {
    let projectToken: String
    let host: String

    static func load(bundle: Bundle = .main) -> Self? {
        guard let token = bundle.object(forInfoDictionaryKey: "PostHogProjectToken") as? String,
              token.hasPrefix("phc_"), token.count < 200,
              token.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "_" }),
              let host = bundle.object(forInfoDictionaryKey: "PostHogHost") as? String,
              ["https://eu.i.posthog.com", "https://us.i.posthog.com"].contains(host) else { return nil }
        return Self(projectToken: token, host: host)
    }

    var allowedHosts: Set<String> {
        host.contains("eu.i.") ? ["eu.i.posthog.com", "eu-assets.i.posthog.com"] : ["us.i.posthog.com", "us-assets.i.posthog.com"]
    }
}

struct AnalyticsFlagSnapshot: Sendable {
    var compactLegend = false
    var surveyID: UUID?
    var surveyQuestionID: UUID?
}

enum AnalyticsCrashStorage {
    /// Discard reports from builds before the current anonymous payload policy.
    static func purge(cacheRoot: URL, bundleIdentifier: String) throws {
        guard bundleIdentifier == "com.abdwy.Tessera" else { throw CocoaError(.fileWriteNoPermission) }
        let report = cacheRoot.appendingPathComponent("com.plausiblelabs.crashreporter.data")
            .appendingPathComponent(bundleIdentifier).appendingPathComponent("live_report.plcrash")
        do { try FileManager.default.removeItem(at: report) }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return }
    }
}

private actor AnalyticsBackend {
    private var sdk: PostHogSDK?
    private var configuration: AnalyticsConfiguration?

    func start(_ configuration: AnalyticsConfiguration, generation: UInt64, initializeStorage: Bool) -> Bool {
        guard AnalyticsNetworkGate.shared.allows(generation) else { return false }
        if sdk != nil { stop(eraseStorage: false) }
        if initializeStorage {
            do { try purgeStorage(configuration) }
            catch { return false } // Reject reports from before the current payload policy.
        }
        self.configuration = configuration
        let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host)
        config.personProfiles = .never
        config.setDefaultPersonProperties = false
        config.disableGeoIp = true
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.enableSwizzling = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.errorTrackingConfig.autoCapture = true
        config.errorTrackingConfig.exceptionSteps.enabled = false
        config.maxQueueSize = 500
        config.flushAt = 20
        config.flushIntervalSeconds = 30
        config.maxRetries = 3
        config.logs.rateCapMaxLogs = 30
        config.logs.rateCapWindowSeconds = 60
        config.logs.serviceName = "Tessera"
        config.requestHeaders = [AnalyticsTransport.generationHeader: String(generation)]
        config.urlSessionConfiguration = AnalyticsTransport.sdkSessionConfiguration(generation: generation)
        config.setBeforeSend { event in
            guard AnalyticsNetworkGate.shared.allows(generation), UUID(uuidString: event.distinctId) != nil,
                  let safe = AnalyticsPolicy.sanitize(event: event.event, properties: event.properties) else { return nil }
            event.properties = safe
            return event
        }
        config.logs.setBeforeSend { record in
            guard AnalyticsNetworkGate.shared.allows(generation),
                  ["scan_complete", "scan_failure", "cleanup_complete"].contains(record.body),
                  let safe = AnalyticsPolicy.sanitize(event: AnalyticsEvent.scanCompleted.rawValue, properties: record.attributes) else { return nil }
            record.attributes = safe
            record.screenName = nil
            record.traceId = nil
            record.spanId = nil
            record.featureFlagKeys = []
            if let id = record.distinctId, UUID(uuidString: id) == nil { record.distinctId = nil }
            return record
        }
        let sdk = PostHogSDK.with(config)
        // Normal runs collect anonymous data. Ignore an SDK opt-out bit left by
        // a previous build or an internal shutdown.
        sdk.optIn()
        self.sdk = sdk
        return true
    }

    func stop(eraseStorage: Bool) {
        sdk?.optOut()
        sdk?.close()
        sdk = nil
        if eraseStorage, let configuration = configuration ?? AnalyticsConfiguration.load() { try? purgeStorage(configuration) }
        configuration = nil
    }

    func capture(_ event: String, values: [String: AnalyticsValue]) {
        guard let sdk,
              let properties = AnalyticsPolicy.sanitize(event: event, properties: values.mapValues(\.raw)) else { return }
        sdk.capture(event, properties: properties)
        switch event {
        case AnalyticsEvent.scanCompleted.rawValue:
            sdk.captureLog("scan_complete", level: .info, attributes: properties)
        case AnalyticsEvent.scanFailed.rawValue:
            sdk.captureLog("scan_failure", level: .error, attributes: properties)
        case AnalyticsEvent.cleanupCompleted.rawValue:
            sdk.captureLog("cleanup_complete", level: .info, attributes: properties)
        default: break
        }
    }

    func flags() async -> AnalyticsFlagSnapshot {
        guard let sdk else { return .init() }
        // The SDK owns a bounded, cached reload. Do not wait for it on the UI thread.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sdk.reloadFeatureFlags { continuation.resume() }
        }
        var snapshot = AnalyticsFlagSnapshot()
        if let flag = sdk.getFeatureFlagResult("tessera-compact-legend") {
            snapshot.compactLegend = flag.enabled && flag.variant == "compact"
        }
        if let flag = sdk.getFeatureFlagResult("tessera-feedback-survey"), flag.enabled,
           let payload = flag.payload as? [String: Any], let id = payload["survey_id"] as? String,
           let questionID = payload["question_id"] as? String {
            snapshot.surveyID = UUID(uuidString: id)
            snapshot.surveyQuestionID = UUID(uuidString: questionID)
        }
        return snapshot
    }

    func flush() { sdk?.flush() }

    private func purgeStorage(_ configuration: AnalyticsConfiguration) throws {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let bundle = Bundle.main.bundleIdentifier, bundle == "com.abdwy.Tessera" else { throw CocoaError(.fileWriteNoPermission) }
        // Delete only this project's SDK subtree. Other app support files are unrelated.
        let directory = base.appendingPathComponent(bundle).appendingPathComponent(configuration.projectToken)
        do { try FileManager.default.removeItem(at: directory) }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { }
        try AnalyticsCrashStorage.purge(cacheRoot: cache, bundleIdentifier: bundle)
    }
}

@MainActor
final class Analytics: ObservableObject {
    static let shared = Analytics()
    @Published private(set) var isEnabled = false
    @Published private(set) var isConfigured = false
    @Published private(set) var compactLegend = false
    @Published private(set) var surveyID: UUID?
    private var surveyQuestionID: UUID?
    private let defaults: UserDefaults
    private let backend = AnalyticsBackend()
    private var generation: UInt64 = 0
    private var started = false
    private var lastScreen: AnalyticsScreen?
    private var setupTask: Task<Void, Never>?
    private var pendingUpdateOutcome: AnalyticsUpdateOutcome?
    private static let storagePolicyKey = "TesseraAnalyticsAnonymousStoragePolicyV1"

    static var isSuppressed: Bool {
        !AnalyticsRunPolicy.collects(environment: ProcessInfo.processInfo.environment)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start() {
        guard !started, !Self.isSuppressed else { return }
        started = true
        isConfigured = AnalyticsConfiguration.load() != nil
        isEnabled = isConfigured
        configure()
    }

    private func configure() {
        generation &+= 1
        let revision = generation
        setupTask?.cancel()
        compactLegend = false
        surveyID = nil
        surveyQuestionID = nil
        lastScreen = nil
        let configuration = isEnabled && !Self.isSuppressed ? AnalyticsConfiguration.load() : nil
        let initializeStorage = !defaults.bool(forKey: Self.storagePolicyKey)
        AnalyticsNetworkGate.shared.configure(generation: revision, hosts: configuration?.allowedHosts ?? [])
        setupTask = Task {
            await backend.stop(eraseStorage: configuration == nil)
            guard !Task.isCancelled, let configuration else { return }
            let didStart = await backend.start(configuration, generation: revision, initializeStorage: initializeStorage)
            guard !Task.isCancelled, generation == revision else { return }
            guard didStart else { return }
            defaults.set(true, forKey: Self.storagePolicyKey)
            await backend.capture(AnalyticsEvent.appOpened.rawValue, values: [:])
            if let outcome = pendingUpdateOutcome {
                pendingUpdateOutcome = nil
                await backend.capture(AnalyticsEvent.updateCompleted.rawValue, values: ["outcome": .text(outcome.rawValue)])
            }
            let flags = await backend.flags()
            guard !Task.isCancelled, generation == revision else { return }
            compactLegend = flags.compactLegend
            surveyID = flags.surveyID
            surveyQuestionID = flags.surveyQuestionID
        }
    }

    func capture(_ event: AnalyticsEvent, values: [String: AnalyticsValue] = [:]) {
        guard started, isEnabled, isConfigured, !Self.isSuppressed else { return }
        let revision = generation
        let ready = setupTask
        Task {
            await ready?.value
            guard generation == revision, AnalyticsNetworkGate.shared.allows(revision) else { return }
            await backend.capture(event.rawValue, values: values)
        }
    }

    func screen(_ screen: AnalyticsScreen) {
        guard lastScreen != screen, started, isEnabled, isConfigured, !Self.isSuppressed else { return }
        lastScreen = screen
        let revision = generation
        let ready = setupTask
        Task {
            await ready?.value
            guard generation == revision, AnalyticsNetworkGate.shared.allows(revision) else { return }
            await backend.capture("$screen", values: ["$screen_name": .text(screen.rawValue)])
        }
    }

    func recordUpdate(_ outcome: AnalyticsUpdateOutcome) {
        guard !Self.isSuppressed else { return }
        if !started { pendingUpdateOutcome = outcome; return }
        capture(.updateCompleted, values: ["outcome": .text(outcome.rawValue)])
    }

    func submitRating(_ rating: Int) {
        guard (1...5).contains(rating), let surveyID, let surveyQuestionID, isEnabled, !Self.isSuppressed else { return }
        let values: [String: AnalyticsValue] = ["$survey_id": .text(surveyID.uuidString),
            "$survey_submission_id": .text(UUID().uuidString), "$survey_response": .integer(rating),
            "$survey_response_\(surveyQuestionID.uuidString)": .integer(rating), "$survey_completed": .boolean(true)]
        Task { await backend.capture("survey sent", values: values); await backend.flush() }
        self.surveyID = nil
    }

    func surveyShown() {
        guard let surveyID, isEnabled, !Self.isSuppressed else { return }
        Task { await backend.capture("survey shown", values: ["$survey_id": .text(surveyID.uuidString)]) }
    }

    func flush() { Task { await backend.flush() } }
}
