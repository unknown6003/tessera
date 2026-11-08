import Foundation
import Testing
@testable import Tessera

@Suite("Analytics privacy and consent")
struct AnalyticsTests {
    @Test("Late progress cannot replace final scan telemetry")
    func finalTelemetryWins() {
        let telemetry = ScanTelemetry()
        telemetry.observe(ScanProgress(filesScanned: 8, dirsScanned: 3, providerReadAttempts: 2, isComplete: true))
        telemetry.observe(ScanProgress(filesScanned: 7, dirsScanned: 3))
        #expect(telemetry.progressSnapshot.isComplete)
        #expect(telemetry.progressSnapshot.filesScanned == 8)
        #expect(telemetry.progressSnapshot.providerReadAttempts == 2)
    }

    @Test("Source telemetry uses cached mounts and distinguishes cloud paths")
    func cachedSourceMetadata() {
        let local = AnalyticsSource.inspect(FileManager.default.temporaryDirectory)
        #expect(local.source == .localUnknown)
        #expect(local.scope == "folder")
        let cloud = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage/OfflineProvider")
        #expect(AnalyticsSource.inspect(cloud).source == .cloud)
    }

    @Test("A new consent period removes only Tessera's pending native crash")
    func discardOptedOutCrash() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tessera-crash-consent-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let report = root.appendingPathComponent("com.plausiblelabs.crashreporter.data/com.abdwy.Tessera/live_report.plcrash")
        let other = root.appendingPathComponent("com.plausiblelabs.crashreporter.data/other.app/live_report.plcrash")
        for url in [report, other] {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("owned opted-out report".utf8).write(to: url)
        }
        try AnalyticsCrashStorage.purge(cacheRoot: root, bundleIdentifier: "com.abdwy.Tessera")
        #expect(!FileManager.default.fileExists(atPath: report.path))
        #expect(FileManager.default.fileExists(atPath: other.path))
        try AnalyticsCrashStorage.purge(cacheRoot: root, bundleIdentifier: "com.abdwy.Tessera")
    }

    @Test("Both SDK hosts inherit the consent generation without network traffic")
    func consentHeaderAcrossHosts() async throws {
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

    @Test("Revoking consent rejects old and future requests until a new run is enabled")
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
