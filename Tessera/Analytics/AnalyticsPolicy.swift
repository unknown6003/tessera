import Foundation
import CoreFoundation
import Darwin

enum AnalyticsEvent: String, CaseIterable, Sendable {
    case appOpened = "tessera app opened"
    case appClosed = "tessera app closed"
    case scanStarted = "tessera scan started"
    case scanPhaseFinished = "tessera scan phase finished"
    case scanCompleted = "tessera scan completed"
    case scanCancelled = "tessera scan cancelled"
    case scanFailed = "tessera scan failed"
    case cleanupStaged = "tessera cleanup staged"
    case cleanupReviewOpened = "tessera cleanup review opened"
    case cleanupStarted = "tessera cleanup started"
    case cleanupCompleted = "tessera cleanup completed"
    case toolOpened = "tessera tool opened"
    case toolCompleted = "tessera tool completed"
    case permissionPrompted = "tessera permission prompted"
    case permissionDismissed = "tessera permission dismissed"
    case updateCompleted = "tessera update completed"
}

enum AnalyticsScreen: String, CaseIterable, Sendable {
    case explore, rescue, review, settings, search, duplicates, bigOld, byKind, uninstaller, hiddenSpace
}

enum AnalyticsUpdateOutcome: String, Sendable {
    case installed, installing, held, upToDate = "up_to_date", failed
}

enum AnalyticsSource: String, Sendable {
    case localInternal = "local_internal"
    case localExternal = "local_external"
    case localUnknown = "local_unknown"
    case cloud, remote, unknown

    static func classify(_ url: URL) -> Self {
        inspect(url).source
    }

    /// Read the cached kernel mount table. Analytics must not add a blocking
    /// metadata preflight before a scan, especially on disconnected shares.
    static func inspect(_ url: URL) -> (source: Self, scope: String) {
        let path = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let providerRoots = [home + "/Library/CloudStorage", home + "/Library/Mobile Documents"]
        if providerRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return (.cloud, "folder") }
        let count = getfsstat(nil, 0, MNT_NOWAIT)
        guard count > 0, count <= 4096 else { return (.unknown, "unknown") }
        var mounts = Array<statfs>(repeating: statfs(), count: Int(count))
        let capacityBytes = Int32(mounts.count * MemoryLayout<statfs>.stride)
        let filled = mounts.withUnsafeMutableBufferPointer { getfsstat($0.baseAddress, capacityBytes, MNT_NOWAIT) }
        guard filled > 0 else { return (.unknown, "unknown") }
        var match: (path: String, local: Bool)?
        for var mount in mounts.prefix(min(Int(filled), mounts.count)) {
            let mountPath = withUnsafeBytes(of: &mount.f_mntonname) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            guard mountPath == "/" || path == mountPath || path.hasPrefix(mountPath + "/"),
                  mountPath.count > (match?.path.count ?? 0) else { continue }
            match = (mountPath, mount.f_flags & UInt32(MNT_LOCAL) != 0)
        }
        guard let match else { return (.unknown, "unknown") }
        // A cached mount table proves locality, not whether a disk is internal.
        return (match.local ? .localUnknown : .remote, path == match.path ? "volume" : "folder")
    }
}

enum AnalyticsPolicy {
    static let flagKeys: Set<String> = ["tessera-compact-legend", "tessera-feedback-survey"]
    static let variants: Set<String> = ["control", "compact", "expanded", "enabled", "disabled"]
    static let failureCodes: Set<String> = ["unavailable", "busy", "permission", "changed", "held", "io", "unknown"]
    private static let eventNames = Set(AnalyticsEvent.allCases.map(\.rawValue))
    private static let numericKeys: Set<String> = [
        "duration_ms", "enumeration_ms", "diagnosis_ms", "files", "directories", "coverage_gaps",
        "items", "moved", "held", "failed", "bytes_bucket", "schema_version", "sample_count", "provider_reads",
        "$feature_flag_id", "$feature_flag_version", "$feature_flag_evaluated_at"
    ]
    private static let categories: [String: Set<String>] = [
        "source_class": ["local_internal", "local_external", "local_unknown", "cloud", "remote", "unknown"],
        "scope": ["volume", "folder", "unknown"],
        "coverage": ["complete", "partial", "blocked", "unknown"],
        "phase": ["enumeration", "diagnosis", "publication"],
        "method": ["trash", "permanent"],
        "outcome": ["complete", "partial", "held", "failed", "cancelled", "superseded", "installed", "installing", "up_to_date"],
        "cache_state": ["fresh_metadata", "cached_display"],
        "tool": Set(AnalyticsScreen.allCases.map(\.rawValue)),
        "$screen_name": Set(AnalyticsScreen.allCases.map(\.rawValue)),
        "error_code": failureCodes,
        "$feature_flag": flagKeys,
        "$feature_flag_response": variants,
        "$feature_flag_payload": [],
        "$lib": ["posthog-ios"],
        "$os_name": ["macOS"],
        "$exception_level": ["fatal", "error"],
        "$exception_source": ["ios.crash_reporter", "tessera"]
    ]

    /// Rebuild the payload from known fields. Nested or future SDK context is dropped.
    static func sanitize(event: String, properties: [String: Any]) -> [String: Any]? {
        guard eventNames.contains(event) || ["$screen", "$feature_flag_called", "$exception", "survey shown", "survey sent", "survey dismissed"].contains(event) else { return nil }
        var result: [String: Any] = ["$geoip_disable": true, "$is_identified": false,
                                     "$process_person_profile": false, "application": "Tessera"]
        for (key, value) in properties {
            if let allowed = categories[key], let text = value as? String, allowed.contains(text) {
                result[key] = text
            } else if key == "$feature_flag_response", let flag = value as? Bool {
                result[key] = flag
            } else if numericKeys.contains(key), let number = value as? NSNumber,
                      CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                      number.doubleValue >= 0, number.doubleValue <= 1_000_000_000_000 {
                result[key] = number
            } else if ["$app_version", "$app_build", "$lib_version", "$os_version"].contains(key),
                      let text = value as? String, validVersion(text) {
                result[key] = text
            } else if ["$session_id", "$survey_id", "$survey_submission_id", "$feature_flag_request_id"].contains(key),
                      let text = value as? String, UUID(uuidString: text) != nil {
                result[key] = text
            } else if key.hasPrefix("$feature/"), flagKeys.contains(String(key.dropFirst(9))) {
                if let variant = value as? String, variants.contains(variant) { result[key] = variant }
                else if let enabled = value as? Bool { result[key] = enabled }
            } else if key == "$active_feature_flags", let keys = value as? [String] {
                result[key] = keys.filter { flagKeys.contains($0) }
            } else if ["$survey_completed", "$feature_flag_has_experiment"].contains(key), let value = value as? Bool {
                result[key] = value
            } else if key.hasPrefix("$survey_response_"), UUID(uuidString: String(key.dropFirst(17))) != nil,
                      let rating = value as? Int, (1...5).contains(rating) {
                result[key] = rating
            } else if key == "$survey_response", let rating = value as? Int, (1...5).contains(rating) {
                result[key] = rating
            }
        }
        if event == "$exception" {
            result["$exception_list"] = sanitizedExceptions(properties["$exception_list"])
            result["$debug_images"] = sanitizedImages(properties["$debug_images"])
        }
        return result
    }

    static func byteBucket(_ bytes: Int64) -> Int {
        guard bytes > 0 else { return 0 }
        return Int(floor(log2(Double(bytes))))
    }

    private static func validVersion(_ text: String) -> Bool {
        text.count <= 32 && !text.isEmpty && text.unicodeScalars.allSatisfy { (48...57).contains($0.value) || $0.value == 46 }
    }

    private static func address(_ value: Any?) -> String? {
        guard let text = value as? String, text.hasPrefix("0x"), (3...18).contains(text.count),
              UInt64(text.dropFirst(2), radix: 16) != nil else { return nil }
        return text
    }

    private static func sanitizedExceptions(_ value: Any?) -> [[String: Any]] {
        let types: Set<String> = ["SIGABRT", "SIGBUS", "SIGSEGV", "SIGILL", "SIGTRAP", "SIGFPE", "EXC_BAD_ACCESS", "EXC_CRASH", "EXC_BAD_INSTRUCTION", "NSException"]
        return ((value as? [[String: Any]]) ?? []).prefix(4).map { exception in
            let type = exception["type"] as? String ?? ""
            let rawFrames = (exception["stacktrace"] as? [String: Any])?["frames"] as? [[String: Any]] ?? []
            let frames: [[String: Any]] = rawFrames.suffix(128).map { frame in
                var safe: [String: Any] = ["platform": "apple", "in_app": frame["in_app"] as? Bool ?? false]
                for key in ["instruction_addr", "image_addr", "symbol_addr"] {
                    if let value = address(frame[key]) { safe[key] = value }
                }
                // Symbolication uses addresses and image UUIDs. Raw symbol and path text is unnecessary.
                return safe
            }
            return ["type": types.contains(type) ? type : "NativeFailure", "value": "Native failure",
                    "stacktrace": ["type": "raw", "frames": frames],
                    "mechanism": ["type": "generic", "handled": false]]
        }
    }

    private static func sanitizedImages(_ value: Any?) -> [[String: Any]] {
        ((value as? [[String: Any]]) ?? []).prefix(128).compactMap { image in
            guard let id = image["debug_id"] as? String, UUID(uuidString: id) != nil,
                  let loadAddress = address(image["image_addr"]) else { return nil }
            var safe: [String: Any] = ["type": "macho", "debug_id": id, "image_addr": loadAddress]
            if let size = image["image_size"] as? NSNumber, size.int64Value >= 0 { safe["image_size"] = size }
            if let base = address(image["image_vmaddr"]) { safe["image_vmaddr"] = base }
            if let arch = image["arch"] as? String, ["arm64", "arm64e", "x86_64"].contains(arch) { safe["arch"] = arch }
            return safe
        }
    }
}
