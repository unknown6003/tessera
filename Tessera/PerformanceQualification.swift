import SwiftUI
import AppKit

/// Agent/CI-only full pipeline trials. The 120-second goal never stops a scan.
@MainActor
enum PerformanceQualification {
    private struct Trial: Decodable {
        let id: String
        let path: String
        let expectedFiles: Int
        let expectedDirectories: Int
    }

    private struct Result: Encodable {
        let id: String
        let durationMS: Double
        let files: Int
        let directories: Int
        let providerReads: Int
        let coverageGaps: Int
        let sourceClass: String
        let longestHeartbeatMS: Double
        let heartbeatDelaysOver500MS: Int
        let outcome: String
        let countsMatch: Bool
        let exceeded120Seconds: Bool
    }

    static func run(vm: ScanViewModel, inputPath: String, outputPath: String) {
        Task { @MainActor in
            vm.dismissFDAOnboarding()
            var results: [Result] = []
            do {
                let trials = try JSONDecoder().decode([Trial].self, from: Data(contentsOf: URL(fileURLWithPath: inputPath)))
                guard !trials.isEmpty, trials.count <= 500 else { throw CocoaError(.fileReadCorruptFile) }
                for trial in trials {
                    let source = URL(fileURLWithPath: trial.path).standardizedFileURL
                    let env = ProcessInfo.processInfo.environment
                    let ciFixture = env["GITHUB_ACTIONS"] == "true"
                        && env["RUNNER_TEMP"].map {
                            source.path == $0 + "/tessera-benchmark"
                                || source.path.hasPrefix($0 + "/tessera-perf-fixtures/")
                        } == true
                    guard source.path.hasPrefix("/tmp/tessera-") || source.path.hasPrefix("/private/tmp/tessera-") || ciFixture,
                          !trial.id.isEmpty, trial.id.count <= 80,
                          trial.id.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-").contains($0) }) else {
                        throw CocoaError(.fileReadNoPermission)
                    }
                    // Ten minutes is a harness process-safety deadline. An over-goal
                    // result stays in the data and fails the goal; it is not discarded.
                    let started = ContinuousClock.now
                    let deadline = started + .seconds(600)
                    let heartbeat = Heartbeat()
                    heartbeat.start()
                    vm.startScan(volumeURL: source)
                    while vm.isScanning, .now < deadline {
                        try await Task.sleep(for: .milliseconds(20))
                    }
                    let timedOut = vm.isScanning
                    if timedOut { vm.cancelScan() }
                    if !timedOut, vm.errorMessage == nil {
                        // Give the published map a real render turn. Include this
                        // 100 ms settle period in the reported elapsed time.
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    heartbeat.stop()
                    let elapsed = started.duration(to: .now)
                    let milliseconds = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
                    let gaps = vm.rootNode?.scanCoverageGaps.count ?? -1
                    let matches = vm.progress.filesScanned == trial.expectedFiles
                        && vm.progress.dirsScanned == trial.expectedDirectories
                    let outcome = timedOut ? "harness_deadline" : vm.errorMessage != nil ? "failed"
                        : !matches ? "count_mismatch" : gaps != 0 ? "partial" : "complete"
                    results.append(Result(id: trial.id, durationMS: milliseconds,
                        files: vm.progress.filesScanned, directories: vm.progress.dirsScanned,
                        providerReads: vm.progress.providerReadAttempts, coverageGaps: gaps,
                        sourceClass: AnalyticsSource.classify(source).rawValue,
                        longestHeartbeatMS: heartbeat.longestMS,
                        heartbeatDelaysOver500MS: heartbeat.over500,
                        outcome: outcome, countsMatch: matches,
                        exceeded120Seconds: milliseconds > 120_000))
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    try encoder.encode(results).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
                    print("[PerformanceQualification] trial=\(trial.id) duration_ms=\(milliseconds) outcome=\(outcome)")
                }
            } catch {
                // Keep any completed trials. The runner must require the exact
                // expected sample count and reject a missing/truncated output.
                print("[PerformanceQualification] input or output failed")
            }
            DebugAutomation.cleanPreferences()
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private final class Heartbeat {
        private var timer: Timer?
        private var last = DispatchTime.now().uptimeNanoseconds
        private(set) var longestMS: Double = 0
        private(set) var over500 = 0

        func start() {
            last = DispatchTime.now().uptimeNanoseconds
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.record() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        func stop() { record(); timer?.invalidate(); timer = nil }

        private func record() {
            let now = DispatchTime.now().uptimeNanoseconds
            let milliseconds = Double(now &- last) / 1_000_000
            longestMS = max(longestMS, milliseconds)
            if milliseconds > 500 { over500 += 1 }
            last = now
        }
    }
}
