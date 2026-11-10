import Foundation
import Testing
@preconcurrency import PostHog
@testable import Tessera

@Suite("Anonymous analytics policy")
struct AnalyticsTests {
    @Test("Normal builds collect without a user preference or environment opt-out")
    func normalCollectionPolicy() {
        #expect(AppRunPolicy.allowsExternalServices(environment: [:]))
        #expect(AppRunPolicy.allowsExternalServices(environment: ["TESSERA_DISABLE_ANALYTICS": "1"]))
        #expect(!AppRunPolicy.allowsExternalServices(environment: ["SO_BENCH": "/owned/fixture"]))
        #expect(!AppRunPolicy.allowsExternalServices(environment: ["SO_AUTOSCAN": "/owned/fixture"]))
        #expect(!AppRunPolicy.allowsExternalServices(environment: ["XCTestConfigurationFilePath": "/test/config"]))
    }

    @Test("XCTest never starts Sparkle or writes update preferences")
    @MainActor
    func updaterStaysInactiveInTests() {
        let defaults = UserDefaults.standard
        let version = defaults.string(forKey: "TesseraLastRunVersion")
        let lastCheck = defaults.object(forKey: "SULastCheckTime") as? Date
        let updater = UpdaterController()
        #expect(!updater.canCheckForUpdates)
        #expect(updater.justUpdatedFrom == nil && updater.lastCheckedAt == nil)
        #expect(defaults.string(forKey: "TesseraLastRunVersion") == version)
        #expect(defaults.object(forKey: "SULastCheckTime") as? Date == lastCheck)
    }

    @Test("The app build has its own valid public ingest configuration")
    func configuredBuild() throws {
        let configuration = try #require(AnalyticsConfiguration.load())
        #expect(configuration.host == "https://eu.i.posthog.com")
        #expect(configuration.projectToken.count > 20)
    }

    @Test("The configured SDK sends only allowed events and logs through an intercepted transport")
    func sdkWirePayload() async throws {
        let token = "phc_owned_probe_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let configuration = AnalyticsConfiguration(projectToken: token, host: "https://eu.i.posthog.com")
        AnalyticsNetworkGate.shared.configure(generation: 91, hosts: configuration.allowedHosts)
        let config = AnalyticsSDKConfiguration.make(configuration, generation: 91)
        #expect(config.errorTrackingConfig.autoCapture)
        #expect(config.personProfiles == .never)
        #expect(config.disableGeoIp && !config.captureApplicationLifecycleEvents && !config.captureScreenViews)
        // No crash handler or external request runs in this test process.
        config.errorTrackingConfig.autoCapture = false
        config.urlSessionConfiguration?.protocolClasses = [AnalyticsWireProbe.self]
        config.compression = .none
        AnalyticsWireProbe.requests.clear()
        let sdk = PostHogSDK.with(config)
        sdk.optIn()
        defer {
            sdk.close()
            AnalyticsNetworkGate.shared.configure(generation: 92, hosts: [])
            if let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
               let bundle = Bundle.main.bundleIdentifier {
                try? FileManager.default.removeItem(at: base.appendingPathComponent(bundle).appendingPathComponent(token))
            }
        }
        let sentinel = "owned_sensitive_sentinel"
        sdk.capture(AnalyticsEvent.scanCompleted.rawValue, properties: ["source_class": "local_unknown",
            "coverage": "complete", "duration_ms": 121000, "path": sentinel, "$set": ["name": sentinel]])
        sdk.capture(sentinel, properties: [:])
        sdk.captureLog("scan_complete", level: .info, attributes: ["duration_ms": 121000, "path": sentinel])
        let surveyID = UUID(uuidString: "01a1bcba-0111-0000-f2f4-c69e43fff048")!
        let questionID = UUID(uuidString: "01a1bcba-0111-0000-f2f4-c69e43fff049")!
        sdk.capture("survey shown", properties: AnalyticsSurvey.shown(surveyID: surveyID).mapValues(\.raw))
        sdk.capture("survey sent", properties: AnalyticsSurvey.rating(surveyID: surveyID, questionID: questionID, rating: 4).mapValues(\.raw))
        sdk.flush()
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline && !(AnalyticsWireProbe.requests.hasEventAndLog
            && AnalyticsWireProbe.requests.hasEvents(["survey shown", "survey sent"])) {
            try await Task.sleep(for: .milliseconds(50))
        }
        let bodies = AnalyticsWireProbe.requests.snapshot
        #expect(AnalyticsWireProbe.requests.hasEventAndLog)
        for body in bodies {
            let text = String(decoding: body, as: UTF8.self)
            #expect(!text.contains(sentinel))
        }
        let batches = bodies.compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .flatMap { $0["batch"] as? [[String: Any]] ?? [] }
        let event = try #require(batches.first { $0["event"] as? String == AnalyticsEvent.scanCompleted.rawValue })
        let properties = try #require(event["properties"] as? [String: Any])
        #expect(properties["duration_ms"] as? Int == 121000)
        #expect(properties["application"] as? String == "Tessera")
        #expect(properties["$process_person_profile"] as? Bool == false)
        #expect(UUID(uuidString: event["distinct_id"] as? String ?? "") != nil)
        for name in ["survey shown", "survey sent"] {
            let survey = try #require(batches.first { $0["event"] as? String == name })
            let values = try #require(survey["properties"] as? [String: Any])
            #expect(values["$survey_id"] as? String == "01a1bcba-0111-0000-f2f4-c69e43fff048")
            if name == "survey sent" {
                #expect(values["$survey_response_01a1bcba-0111-0000-f2f4-c69e43fff049"] as? Int == 4)
                #expect(values["$survey_response_01A1BCBA-0111-0000-F2F4-C69E43FFF049"] == nil)
                #expect(UUID(uuidString: values["$survey_submission_id"] as? String ?? "") != nil)
            }
        }
    }

    @Test("Late progress cannot replace final scan telemetry")
    func finalTelemetryWins() {
        let telemetry = ScanTelemetry()
        telemetry.observe(ScanProgress(filesScanned: 8, dirsScanned: 3, providerReadAttempts: 2, isComplete: true))
        telemetry.observe(ScanProgress(filesScanned: 7, dirsScanned: 3))
        #expect(telemetry.progressSnapshot.isComplete)
        #expect(telemetry.progressSnapshot.filesScanned == 8)
        #expect(telemetry.progressSnapshot.providerReadAttempts == 2)
    }

    @Test("Telemetry reports the computed coverage even when enumeration has no gaps")
    func computedCoverageTelemetry() throws {
        let telemetry = ScanTelemetry()
        let root = FileNode(url: URL(fileURLWithPath: "/owned-fixture"), name: "fixture", isDirectory: true, size: 0)
        for kind in [FileNode.Kind.hiddenSpace, .cloudOnlyStorage, .crossVolume] {
            root.setChildren([FileNode(name: "boundary", isDirectory: true, size: 1, kind: kind)])
            let coverage = RescueCoverage.inspect(root: root, sourceIsReadable: true)
            #expect(coverage.state == .partial && root.scanCoverageGaps.isEmpty)
            let values = telemetry.properties(outcome: "partial", coverage: coverage.state, gaps: 0)
            let safe = try #require(AnalyticsPolicy.sanitize(event: AnalyticsEvent.scanCompleted.rawValue, properties: values.mapValues(\.raw)))
            #expect(safe["coverage"] as? String == "partial")
            #expect(safe["coverage_gaps"] as? Int == 0)
        }
        root.setChildren([])
        for readable in [false, true] {
            let coverage = RescueCoverage.inspect(root: root, sourceIsReadable: readable)
            let values = telemetry.properties(outcome: "complete", coverage: coverage.state, gaps: 0)
            let safe = try #require(AnalyticsPolicy.sanitize(event: AnalyticsEvent.scanCompleted.rawValue, properties: values.mapValues(\.raw)))
            #expect(safe["coverage"] as? String == (readable ? "complete" : "blocked"))
        }
        #expect(telemetry.properties(outcome: "complete", gaps: 0)["coverage"]?.raw as? String == "unknown")
    }

    @Test("Source telemetry uses cached mounts and distinguishes cloud paths")
    func cachedSourceMetadata() {
        let local = AnalyticsSource.inspect(FileManager.default.temporaryDirectory)
        #expect(local.source == .localUnknown)
        #expect(local.scope == "folder")
        let cloud = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage/OfflineProvider")
        #expect(AnalyticsSource.inspect(cloud).source == .cloud)
    }

    @Test("Storage migration removes only Tessera's pending native crash")
    func discardHistoricalCrash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tessera-crash-migration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let report = root.appendingPathComponent("com.plausiblelabs.crashreporter.data/com.abdwy.Tessera/live_report.plcrash")
        let other = root.appendingPathComponent("com.plausiblelabs.crashreporter.data/other.app/live_report.plcrash")
        for url in [report, other] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("owned historical report".utf8).write(to: url)
        }
        try AnalyticsCrashStorage.purge(cacheRoot: root, bundleIdentifier: "com.abdwy.Tessera")
        #expect(!FileManager.default.fileExists(atPath: report.path))
        #expect(FileManager.default.fileExists(atPath: other.path))
        try AnalyticsCrashStorage.purge(cacheRoot: root, bundleIdentifier: "com.abdwy.Tessera")
    }

    @Test("Both SDK hosts inherit the run generation without network traffic")
    func runHeaderAcrossHosts() async throws {
        let config = AnalyticsTransport.sdkSessionConfiguration(generation: 73)
        config.protocolClasses = [AnalyticsHeaderProbe.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for host in ["eu.i.posthog.com", "eu-assets.i.posthog.com", "us.i.posthog.com", "us-assets.i.posthog.com"] {
            let (data, _) = try await session.data(from: #require(URL(string: "https://\(host)/test")))
            #expect(String(decoding: data, as: UTF8.self) == "73")
        }
    }

    @Test("Payloads drop private fields, arbitrary values and future SDK context")
    func strictPayloadBoundary() throws {
        let secret = "/Users/person/Private/secret.pdf"
        let properties: [String: Any] = ["path": secret, "name": "person", "error_code": secret,
            "source_class": "local_internal", "coverage": "partial", "coverage_gaps": 3,
            "duration_ms": 121_000, "$set": ["email": "private@example.test"],
            "$device_name": secret, "$current_url": secret, "$screen_name": secret,
            "$geoip_disable": false, "$is_identified": true, "$process_person_profile": true,
            "files": Double.infinity, "directories": -1, "$app_version": "0.2.0"]
        let safe = try #require(AnalyticsPolicy.sanitize(event: AnalyticsEvent.scanCompleted.rawValue, properties: properties))
        let json = String(decoding: try JSONSerialization.data(withJSONObject: safe), as: UTF8.self)
        #expect(!json.contains("Private"))
        #expect(!json.contains("/Users/"))
        #expect(!json.contains("example.test"))
        #expect(safe["source_class"] as? String == "local_internal")
        #expect(safe["duration_ms"] as? Int == 121_000, "Scans over 120 seconds stay measurable")
        #expect(safe["$geoip_disable"] as? Bool == true)
        #expect(safe["$is_identified"] as? Bool == false)
        #expect(safe["$process_person_profile"] as? Bool == false)
        #expect(safe["files"] == nil && safe["directories"] == nil)
        #expect(AnalyticsPolicy.sanitize(event: secret, properties: [:]) == nil)
    }

    @Test("Crash symbolication keeps addresses and UUIDs while dropping messages and paths")
    func sanitizedCrash() throws {
        let id = UUID().uuidString
        let secret = "/Users/private/file.pdf"
        let properties: [String: Any] = ["$exception_list": [["type": secret, "value": secret,
            "stacktrace": ["frames": [["instruction_addr": "0x0000000000000010", "image_addr": "0x10",
                "module": secret, "function": secret, "package": secret, "filename": secret, "in_app": true]]]]],
            "$debug_images": [["debug_id": id, "image_addr": "0x10", "code_file": secret, "arch": "arm64"]],
            "$exception_steps": [["message": secret]]]
        let safe = try #require(AnalyticsPolicy.sanitize(event: "$exception", properties: properties))
        let json = String(decoding: try JSONSerialization.data(withJSONObject: safe), as: UTF8.self)
        #expect(!json.contains("private"))
        #expect(json.contains(id))
        #expect(json.contains("0x0000000000000010"))
        #expect(json.contains("NativeFailure"))
        #expect(safe["$exception_steps"] == nil)
    }

    @Test("Feature flag and survey values have finite allowlists")
    func safeFlagsAndSurveys() throws {
        let safe = try #require(AnalyticsPolicy.sanitize(event: "$feature_flag_called", properties: [
            "$feature_flag": "tessera-compact-legend", "$feature_flag_response": "compact",
            "$feature_flag_payload": "/Users/private"]))
        #expect(safe["$feature_flag"] as? String == "tessera-compact-legend")
        #expect(safe["$feature_flag_payload"] == nil)
        let survey = try #require(AnalyticsPolicy.sanitize(event: "survey sent", properties: [
            "$survey_id": UUID().uuidString, "$survey_response": "private answer"]))
        #expect(survey["$survey_response"] == nil)
    }

    @Test("Stopping a run rejects stale requests until the next valid run")
    func networkGate() {
        let gate = AnalyticsNetworkGate()
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let id = UUID()
        gate.configure(generation: 1, hosts: ["eu.i.posthog.com"])
        #expect(gate.register(session, id: id, generation: 1, host: "eu.i.posthog.com"))
        #expect(!gate.register(session, id: UUID(), generation: 1, host: "attacker.example"))
        gate.configure(generation: 2, hosts: [])
        #expect(!gate.allows(1) && !gate.allows(2))
        #expect(!gate.register(session, id: id, generation: 1, host: "eu.i.posthog.com"))
        gate.configure(generation: 3, hosts: ["eu.i.posthog.com"])
        #expect(!gate.allows(1) && gate.allows(3))
    }
}

/// Replies inside URLSession. No DNS lookup or live PostHog project is used.
private final class AnalyticsHeaderProbe: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        client?.urlProtocol(self, didReceive: URLResponse(url: url, mimeType: "text/plain", expectedContentLength: -1, textEncodingName: "utf-8"), cacheStoragePolicy: .notAllowed)
        let value = request.value(forHTTPHeaderField: AnalyticsTransport.generationHeader) ?? "missing"
        client?.urlProtocol(self, didLoad: Data(value.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// Intercepts the real SDK before DNS or HTTP. It never forwards a request.
private final class AnalyticsWireProbe: URLProtocol, @unchecked Sendable {
    static let requests = AnalyticsWireRequests()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable && body.count < 1_000_000 {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        Self.requests.append(body, path: url.path)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let reply = url.path.hasPrefix("/flags")
            ? "{\"flags\":{},\"errorsWhileComputingFlags\":false}"
            : "{\"status\":1}"
        client?.urlProtocol(self, didLoad: Data(reply.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class AnalyticsWireRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var bodies: [Data] = []
    private var paths: Set<String> = []
    var snapshot: [Data] { lock.withLock { bodies } }
    var hasEventAndLog: Bool { lock.withLock { paths.contains("/batch") && paths.contains("/i/v1/logs") } }
    func hasEvents(_ expected: Set<String>) -> Bool {
        let events = snapshot.compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .flatMap { $0["batch"] as? [[String: Any]] ?? [] }.compactMap { $0["event"] as? String }
        return expected.isSubset(of: Set(events))
    }
    func clear() { lock.withLock { bodies.removeAll(); paths.removeAll() } }
    func append(_ body: Data, path: String) { lock.withLock { bodies.append(body); paths.insert(path) } }
}
