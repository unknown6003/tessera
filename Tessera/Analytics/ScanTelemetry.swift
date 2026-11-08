import Foundation

/// One small progress snapshot per scan, independent of UI callback delivery order.
final class ScanTelemetry: @unchecked Sendable {
    private let lock = NSLock()
    private var latest = ScanProgress()
    private let started = DispatchTime.now().uptimeNanoseconds
    private var enumerationMS: Double = 0
    private var diagnosisMS: Double = 0
    var source: AnalyticsSource = .unknown
    var scope = "unknown"

    func observe(_ progress: ScanProgress) {
        lock.withLock {
            guard !latest.isComplete else { return }
            if progress.isComplete || (progress.dirsScanned >= latest.dirsScanned && progress.filesScanned >= latest.filesScanned) {
                latest = progress
            }
        }
    }

    var durationMS: Double { Double(DispatchTime.now().uptimeNanoseconds &- started) / 1_000_000 }
    var progressSnapshot: ScanProgress { lock.withLock { latest } }

    func finishEnumeration() { enumerationMS = durationMS }
    func finishDiagnosis() { diagnosisMS = max(0, durationMS - enumerationMS) }

    func properties(outcome: String, gaps: Int? = nil) -> [String: AnalyticsValue] {
        let progress = lock.withLock { latest }
        var properties: [String: AnalyticsValue] = [
            "source_class": .text(source.rawValue), "scope": .text(scope),
            "outcome": .text(outcome), "cache_state": .text("fresh_metadata"),
            "duration_ms": .decimal(durationMS), "enumeration_ms": .decimal(enumerationMS),
            "diagnosis_ms": .decimal(diagnosisMS), "files": .integer(progress.filesScanned),
            "directories": .integer(progress.dirsScanned), "schema_version": .integer(1)
        ]
        properties["provider_reads"] = .integer(progress.providerReadAttempts)
        if let gaps {
            properties["coverage"] = .text(gaps == 0 ? "complete" : "partial")
            properties["coverage_gaps"] = .integer(gaps)
        } else { properties["coverage"] = .text("unknown") }
        return properties
    }
}
