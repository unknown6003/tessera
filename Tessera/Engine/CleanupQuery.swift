import Foundation

// MARK: - Natural-language cleanup query
//
// A natural-language goal ("free up 50 GB", "clear dev junk but keep my projects")
// becomes a structured CleanupQuery, which is then executed ENTIRELY ON-DEVICE
// against the already-classified cleanup report. Candidates are only ever drawn
// from the deterministic cleanup groups, so nothing outside known-reclaimable
// categories can be selected — and no file data is needed to run the query.
//
// PRIVACY: producing the query (see IntentPlanner) sends only the user's typed
// intent + the static category taxonomy + today's date. Executing it touches only
// in-memory nodes. Paths/sizes/contents never leave the Mac.

/// A structured, on-device-executable cleanup request.
struct CleanupQuery: Sendable, Equatable {
    /// CleanupCatalog category IDs to draw candidates from. Empty = "all safe".
    var categoryIDs: Set<String>
    /// Also allow review-tier categories (Downloads, installers, logs, builds).
    var includeReviewTier: Bool
    /// Only nodes not modified within this many days. Applies to files and folders
    /// alike (both carry mtime); nodes with unknown mtime (0) are excluded.
    var maxAgeDays: Int?
    /// Only nodes at least this large.
    var minSizeBytes: Int64?
    /// Stop selecting (largest-first) once cumulative size reaches this.
    var targetFreeBytes: Int64?
    /// Require the node's lowercased path to contain one of these.
    var locationHints: [String]
    /// Require the node's lowercased name to contain one of these.
    var nameHints: [String]
    /// One-line restatement of what this will stage, shown to the user.
    var summary: String

    static let empty = CleanupQuery(
        categoryIDs: [], includeReviewTier: false, maxAgeDays: nil,
        minSizeBytes: nil, targetFreeBytes: nil, locationHints: [],
        nameHints: [], summary: "")

    /// True if the query carries no actionable constraint at all.
    var isTrivial: Bool {
        categoryIDs.isEmpty && !includeReviewTier && maxAgeDays == nil
            && minSizeBytes == nil && targetFreeBytes == nil
            && locationHints.isEmpty && nameHints.isEmpty
    }
}

// MARK: - On-device executor

enum CleanupQueryEngine {
    /// Resolve a query into the nodes to stage — largest-first, capped at
    /// `targetFreeBytes` when set. `nowEpoch` is the current Unix time (seconds).
    static func execute(_ q: CleanupQuery, report: CleanupReport, nowEpoch: Int64) -> [FileNode] {
        // Candidate groups: named categories win regardless of tier; otherwise
        // default to safe-only unless the query opted into the review tier.
        let groups: [CleanupReport.Group]
        if q.categoryIDs.isEmpty {
            groups = q.includeReviewTier ? report.groups : report.safeGroups
        } else {
            groups = report.groups.filter { q.categoryIDs.contains($0.category.id) }
        }

        var nodes = groups.flatMap(\.nodes)

        if let minSize = q.minSizeBytes {
            nodes = nodes.filter { $0.size >= minSize }
        }
        if let maxAgeDays = q.maxAgeDays {
            // FileNode.modTime is epoch NANOSECONDS; nowEpoch is seconds.
            let cutoffNanos = (nowEpoch - Int64(maxAgeDays) * 86_400) * 1_000_000_000
            // modTime == 0 means "unknown age" — excluded under an age limit so we
            // never stage something that might be recent.
            nodes = nodes.filter { $0.modTime != 0 && $0.modTime <= cutoffNanos }
        }
        if !q.locationHints.isEmpty {
            // node.url is lazy/CFURL-built, but the candidate set is tiny (tens of
            // classified group nodes), so this is cheap.
            nodes = nodes.filter { node in
                let p = node.url.path.lowercased()
                return q.locationHints.contains { p.contains($0) }
            }
        }
        if !q.nameHints.isEmpty {
            nodes = nodes.filter { node in
                let n = node.name.lowercased()
                return q.nameHints.contains { n.contains($0) }
            }
        }

        var seen = Set<ObjectIdentifier>()
        nodes = nodes.filter { seen.insert($0.id).inserted }
            .sorted { $0.size > $1.size }

        guard let target = q.targetFreeBytes else { return nodes }
        var acc: Int64 = 0
        var picked: [FileNode] = []
        for n in nodes {
            picked.append(n)
            acc += n.size
            if acc >= target { break }
        }
        return picked
    }
}

// MARK: - Built-in keyword parser
//
// The always-available fallback. Handles the common phrasings; the on-device model
// in IntentPlanner takes over for anything nuanced once it's downloaded. Pure
// string work — runs locally, sends nothing.

enum CleanupQueryParser {
    /// Map a keyword bucket to the catalog category IDs it covers.
    private static let categoryKeywords: [(needles: [String], ids: [String], review: Bool)] = [
        (["cache", "caches"], [CleanupCatalog.userCaches.id, CleanupCatalog.browserCache.id,
                               CleanupCatalog.packageCache.id, CleanupCatalog.adobeMediaCache.id,
                               CleanupCatalog.adobeCameraRaw.id], false),
        (["browser", "chrome", "safari", "firefox"], [CleanupCatalog.browserCache.id], false),
        (["adobe", "premiere", "after effects", "lightroom"],
         [CleanupCatalog.adobeMediaCache.id, CleanupCatalog.adobeCameraRaw.id], false),
        (["xcode", "derived", "deriveddata"],
         [CleanupCatalog.xcodeDerived.id, CleanupCatalog.xcodeDeviceSupport.id], false),
        (["node_modules", "node modules", "dependencies", "npm", "package"],
         [CleanupCatalog.nodeModules.id, CleanupCatalog.packageCache.id], false),
        (["dev junk", "developer", "dev "],
         [CleanupCatalog.xcodeDerived.id, CleanupCatalog.xcodeDeviceSupport.id,
          CleanupCatalog.nodeModules.id, CleanupCatalog.packageCache.id,
          CleanupCatalog.buildOutput.id], true),
        (["build", "target", "dist"], [CleanupCatalog.buildOutput.id], true),
        (["log", "logs"], [CleanupCatalog.logs.id], true),
        (["installer", "installers", "dmg", "pkg", "iso", "disk image"],
         [CleanupCatalog.installers.id], true),
        (["download", "downloads"], [CleanupCatalog.downloads.id], true),
        (["trash"], [CleanupCatalog.trash.id], false),
    ]

    static func parse(_ raw: String) -> CleanupQuery {
        let s = raw.lowercased()
        var q = CleanupQuery.empty

        // "free up 50 gb" / "reclaim 500 mb" / "make room for 30gb"
        if let bytes = sizeBytes(in: s, after: ["free", "reclaim", "make room", "need", "want", "clear up"]) {
            q.targetFreeBytes = bytes
        }
        // "bigger than 1gb" / "larger than 500 mb" / "over 2 gb"
        if let bytes = sizeBytes(in: s, after: ["bigger than", "larger than", "over", "more than", "at least", "greater than"]) {
            q.minSizeBytes = bytes
        }
        // "older than 6 months" / "not touched in a year" / "unused for 3 weeks"
        if let days = ageDays(in: s) {
            q.maxAgeDays = days
        }

        var ids = Set<String>()
        var review = false
        for entry in categoryKeywords where entry.needles.contains(where: { s.contains($0) }) {
            ids.formUnion(entry.ids)
            if entry.review { review = true }
        }
        // "but keep my projects/code/downloads" — drop those from the selection.
        if let keepRange = s.range(of: "keep") ?? s.range(of: "except") ?? s.range(of: "not") {
            let tail = s[keepRange.lowerBound...]
            if tail.contains("project") || tail.contains("code") || tail.contains("source") {
                ids.remove(CleanupCatalog.buildOutput.id)
            }
            if tail.contains("download") { ids.remove(CleanupCatalog.downloads.id) }
        }

        q.categoryIDs = ids
        q.includeReviewTier = review
        q.summary = describe(q)
        return q
    }

    /// Build a human-readable restatement of the query for the result UI.
    static func describe(_ q: CleanupQuery) -> String {
        var parts: [String] = []
        if q.categoryIDs.isEmpty {
            parts.append(q.includeReviewTier ? "all reclaimable items" : "all safe items")
        } else {
            parts.append("\(q.categoryIDs.count) selected categor\(q.categoryIDs.count == 1 ? "y" : "ies")")
        }
        if let d = q.maxAgeDays { parts.append("older than \(humanDays(d))") }
        if let b = q.minSizeBytes { parts.append("over \(Theme.format(b))") }
        if let t = q.targetFreeBytes { parts.append("until \(Theme.format(t)) is freed") }
        return "Staging " + parts.joined(separator: ", ") + "."
    }

    // MARK: Number extraction

    private static func sizeBytes(in s: String, after triggers: [String]) -> Int64? {
        // Find a "<number> <unit>" pair appearing after any trigger word.
        for trigger in triggers {
            guard let r = s.range(of: trigger) else { continue }
            let tail = String(s[r.upperBound...])
            if let bytes = firstSizeToken(in: tail) { return bytes }
        }
        return nil
    }

    /// First "<number><unit>" in a string, e.g. "50 gb", "500mb", "2 tb".
    private static func firstSizeToken(in s: String) -> Int64? {
        let scanner = s
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(tb|gb|mb|kb|t|g|m|k)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: scanner, range: NSRange(scanner.startIndex..., in: scanner)),
              let numR = Range(m.range(at: 1), in: scanner),
              let unitR = Range(m.range(at: 2), in: scanner),
              let value = Double(scanner[numR]) else { return nil }
        let unit = String(scanner[unitR])
        let mult: Double
        switch unit.first {
        case "t": mult = 1024 * 1024 * 1024 * 1024
        case "g": mult = 1024 * 1024 * 1024
        case "m": mult = 1024 * 1024
        case "k": mult = 1024
        default:  mult = 1
        }
        return Int64(value * mult)
    }

    private static func ageDays(in s: String) -> Int? {
        // "a year" / "1 year" / "6 months" / "3 weeks" / "30 days"
        let pattern = #"(?:(\d+)|a|an)\s*(year|month|week|day)s?"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let unitR = Range(m.range(at: 2), in: s) else { return nil }
        let n: Int
        if let numR = Range(m.range(at: 1), in: s), let parsed = Int(s[numR]) { n = parsed } else { n = 1 }
        switch String(s[unitR]) {
        case "year":  return n * 365
        case "month": return n * 30
        case "week":  return n * 7
        default:      return n
        }
    }

    private static func humanDays(_ d: Int) -> String {
        if d % 365 == 0 { let y = d / 365; return "\(y) year\(y == 1 ? "" : "s")" }
        if d % 30 == 0 { let m = d / 30; return "\(m) month\(m == 1 ? "" : "s")" }
        if d % 7 == 0 { let w = d / 7; return "\(w) week\(w == 1 ? "" : "s")" }
        return "\(d) day\(d == 1 ? "" : "s")"
    }
}
