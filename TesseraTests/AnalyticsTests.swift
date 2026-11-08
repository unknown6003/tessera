import Foundation
import Testing
@testable import Tessera

@Suite("Analytics privacy and consent")
struct AnalyticsTests {
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
