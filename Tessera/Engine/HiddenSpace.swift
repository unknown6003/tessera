import Foundation

// MARK: - Hidden space analysis
//
// "Hidden Space" is the gap between what the volume reports as used and what the
// scan could actually see. It's not one thing — it's mostly: APFS local Time
// Machine snapshots (deletable), purgeable caches (system-managed), and, when Full
// Disk Access isn't granted, protected files the scan couldn't read. This breaks it
// down so the user can read it, clear the reclaimable parts, and choose what to keep.

struct LocalSnapshot: Identifiable, Sendable, Equatable {
    /// Full snapshot name, e.g. com.apple.TimeMachine.2026-06-19-120000.local
    let name: String
    let date: Date?
    var id: String { name }

    /// The date token tmutil expects for deletion, e.g. 2026-06-19-120000.
    var dateToken: String? {
        // Pull the YYYY-MM-DD-HHMMSS run out of the name.
        guard let r = name.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) else { return nil }
        return String(name[r])
    }
}

struct HiddenSpaceReport: Sendable {
    var hiddenBytes: Int64
    var purgeableBytes: Int64
    var snapshots: [LocalSnapshot]
    var hasFullDiskAccess: Bool

    /// Whatever's left after purgeable — other system data / protected files.
    var otherBytes: Int64 { max(0, hiddenBytes - purgeableBytes) }
}

enum HiddenSpaceAnalyzer {
    static func analyze(volumeURL: URL, hiddenBytes: Int64) -> HiddenSpaceReport {
        HiddenSpaceReport(
            hiddenBytes: hiddenBytes,
            purgeableBytes: purgeableBytes(volumeURL),
            snapshots: listSnapshots(volumeURL: volumeURL),
            hasFullDiskAccess: ScanViewModel.hasFullDiskAccess())
    }

    /// Space the OS can reclaim on demand (caches, evictable files): the difference
    /// between "available for important usage" and plain available capacity.
    static func purgeableBytes(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let v = try? url.resourceValues(forKeys: keys) else { return 0 }
        let available = Int64(v.volumeAvailableCapacity ?? 0)
        let important = v.volumeAvailableCapacityForImportantUsage ?? 0
        return max(0, important - available)
    }

    /// APFS local Time Machine snapshots on the volume (newest first).
    static func listSnapshots(volumeURL: URL) -> [LocalSnapshot] {
        guard let out = runTool("/usr/bin/tmutil", ["listlocalsnapshots", volumeURL.path]) else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd-HHmmss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let snaps: [LocalSnapshot] = out.split(separator: "\n").compactMap { line in
            let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.contains("com.apple.TimeMachine") else { return nil }
            var date: Date?
            if let r = name.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) {
                date = fmt.date(from: String(name[r]))
            }
            return LocalSnapshot(name: name, date: date)
        }
        return snaps.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// Delete a single local snapshot. Returns true on success. (Some macOS versions
    /// require admin for this; a false result surfaces a "couldn't delete" message.)
    @discardableResult
    static func deleteSnapshot(_ snap: LocalSnapshot) -> Bool {
        guard let token = snap.dateToken else { return false }
        return runTool("/usr/bin/tmutil", ["deletelocalsnapshots", token]) != nil
    }

    // MARK: Process helper

    private static func runTool(_ path: String, _ args: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
