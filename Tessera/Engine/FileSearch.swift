import Foundation

// MARK: - Keyword file search
//
// Turns a free-text query ("videos over 1gb in downloads older than 6 months")
// into a structured filter and runs it over the already-scanned tree, returning
// the matching regular files. The built-in keyword parser (FileSearchParser)
// handles the common phrasings.
//
// Like every other tool here it only *finds*; nothing is deleted, and a match
// becomes actionable only once the user stages it in the collector.
//
// `modTime` is epoch NANOSECONDS (0 = unknown); age filtering compares against a
// nanosecond cutoff and excludes unknown-mtime files whenever an age filter is set.
//
// PRIVACY: everything runs locally — nothing about the user's files is sent.

enum FileSearch {

    /// The structured filter a query resolves to. All axes are optional; an unset
    /// axis imposes no constraint. Reuses FileKind and the same size/age semantics
    /// as LargeOldFiles.
    struct Filter: Sendable, Equatable {
        /// Substrings the file's lowercased *name* must contain (all must match).
        var nameContains: [String] = []
        /// Substrings the file's lowercased *path* must contain (any may match —
        /// these come from location words like "downloads"/"desktop").
        var pathContains: [String] = []
        /// Minimum allocated size in bytes (inclusive).
        var minSizeBytes: Int64?
        /// Maximum allocated size in bytes (inclusive).
        var maxSizeBytes: Int64?
        /// Maximum age in days: a file qualifies only if last modified at least this
        /// many days ago. Files with `modTime == 0` are excluded when set.
        var maxAgeDays: Int?
        /// Restrict to a single content kind (image, video, …). `nil` = all kinds.
        var kind: FileKind?

        static let empty = Filter()

        /// True when the filter carries no actionable constraint at all — running it
        /// would return the entire tree, which is never what the user meant.
        var isTrivial: Bool {
            nameContains.isEmpty && pathContains.isEmpty
                && minSizeBytes == nil && maxSizeBytes == nil
                && maxAgeDays == nil && kind == nil
        }
    }

    /// Cap on returned matches so a huge tree can't flood the UI; the largest files
    /// are the interesting ones, so we sort first and then cap.
    static let resultCap = 500

    // MARK: - Executor

    /// Walk `root`, collecting non-synthetic regular files that pass every set
    /// filter, sorted largest-first and capped at `limit`.
    ///
    /// Pure and unit-testable: `nowEpochSeconds` is injected (defaults to the
    /// current wall clock) so age filtering is deterministic in tests.
    static func find(root: FileNode,
                     filter: Filter,
                     nowEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970),
                     limit: Int = resultCap) -> [FileNode] {
        // A trivial filter would match everything — return nothing instead.
        guard !filter.isTrivial else { return [] }

        let cutoffNanos: Int64? = filter.maxAgeDays.map { days in
            (nowEpochSeconds - Int64(days) * 86_400) * 1_000_000_000
        }
        let needsPath = !filter.pathContains.isEmpty

        var matches: [FileNode] = []
        // Iterative pre-order walk; packages are leaves for this tool (the Finder
        // treats them as a single file, and FileKind classifies them as such).
        var stack: [FileNode] = root.children.reversed()
        while let node = stack.popLast() {
            if node.isSynthetic { continue }

            if node.isDirectory && node.kind != .package {
                stack.append(contentsOf: node.children)
                continue
            }

            // A regular file (or a package, treated as a file leaf).
            if let minSize = filter.minSizeBytes, node.size < minSize { continue }
            if let maxSize = filter.maxSizeBytes, node.size > maxSize { continue }
            if let cutoffNanos {
                // Unknown modTime can't satisfy an age limit.
                if node.modTime == 0 || node.modTime > cutoffNanos { continue }
            }
            if let kindFilter = filter.kind, FileKind.classify(node: node) != kindFilter { continue }

            if !filter.nameContains.isEmpty {
                let name = node.name.lowercased()
                if !filter.nameContains.allSatisfy({ name.contains($0) }) { continue }
            }
            if needsPath {
                // node.url is lazy/CFURL-built, so only resolve it once all the
                // cheap (in-memory) filters above have passed.
                let path = node.url.path.lowercased()
                if !filter.pathContains.contains(where: { path.contains($0) }) { continue }
            }

            matches.append(node)
        }

        matches.sort { $0.size > $1.size }
        if matches.count > limit { matches.removeLast(matches.count - limit) }
        return matches
    }
}

// MARK: - Built-in keyword parser
//
// The always-available fallback. Handles the common phrasings; the on-device
// model takes over for anything nuanced once it's downloaded. Pure string work —
// runs locally, sends nothing.

enum FileSearchParser {

    /// Parse a free-text query into a Filter.
    static func parse(_ raw: String) -> FileSearch.Filter {
        let s = raw.lowercased()
        var f = FileSearch.Filter.empty

        // Size: ">1gb" / "over 500 mb" / "larger than 2 gb" / "at least 100mb".
        if let bytes = sizeBytes(in: s, after: [">", "over", "bigger than", "larger than",
                                                "more than", "at least", "greater than", "above"]) {
            f.minSizeBytes = bytes
        }
        // Max size: "<100mb" / "under 1gb" / "smaller than 500 mb".
        if let bytes = sizeBytes(in: s, after: ["<", "under", "smaller than", "less than", "below"]) {
            f.maxSizeBytes = bytes
        }

        // Age: "older than 6 months" / "not touched in a year" / "30 days old".
        if let days = ageDays(in: s) {
            f.maxAgeDays = days
        }

        // Words consumed by the kind/location axes — kept out of the name needles
        // so e.g. "videos in desktop" doesn't search for a file named "desktop".
        var consumed = Set<String>()

        // Kind words. First match wins (kinds are mutually exclusive here).
        for (needles, kind) in kindKeywords where needles.contains(where: { s.contains($0) }) {
            f.kind = kind
            consumed.formUnion(needles)
            break
        }

        // Location words → a lowercased path fragment matched against node.url.path.
        var hints: [String] = []
        for (needles, hint) in locationKeywords where needles.contains(where: { s.contains($0) }) {
            hints.append(hint)
            consumed.formUnion(needles)
        }
        f.pathContains = hints

        // Name substrings: quoted phrases ("...") plus residual significant words
        // not consumed by the structured axes above.
        f.nameContains = nameNeedles(in: s, consumed: consumed)

        return f
    }

    /// Map a location word to the lowercased path fragment used for matching, or
    /// nil if it isn't a recognized location.
    static func locationHint(_ word: String) -> String? {
        for (needles, hint) in locationKeywords where needles.contains(word) {
            return hint
        }
        return nil
    }

    /// Build a human-readable restatement of the filter for the result UI.
    static func describe(_ f: FileSearch.Filter) -> String {
        if f.isTrivial { return "Type something to search for." }
        var parts: [String] = []
        if let k = f.kind { parts.append(k.title.lowercased()) }
        else { parts.append("files") }
        if !f.nameContains.isEmpty {
            parts.append("named \"" + f.nameContains.joined(separator: " ") + "\"")
        }
        if let b = f.minSizeBytes { parts.append("over \(Theme.format(b))") }
        if let b = f.maxSizeBytes { parts.append("under \(Theme.format(b))") }
        if let d = f.maxAgeDays { parts.append("older than \(humanDays(d))") }
        if !f.pathContains.isEmpty { parts.append("in \(locationName(f.pathContains))") }
        return "Searching for " + parts.joined(separator: ", ") + "."
    }

    // MARK: Keyword tables

    private static let kindKeywords: [(needles: [String], kind: FileKind)] = [
        (["photo", "photos", "image", "images", "picture", "pictures", "screenshot", "screenshots"], .image),
        (["video", "videos", "movie", "movies", "film", "footage", "clip", "clips"], .video),
        (["audio", "music", "song", "songs", "track", "tracks", "podcast"], .audio),
        (["pdf", "pdfs", "document", "documents", "doc", "docs", "spreadsheet", "presentation"], .document),
        (["archive", "archives", "zip", "zips", "tarball", "dmg", "disk image"], .archive),
        (["app", "apps", "application", "applications", "package", "bundle"], .app),
        (["code", "source", "source code", "script", "scripts"], .code),
    ]

    private static let locationKeywords: [(needles: [String], hint: String)] = [
        (["downloads", "download folder"], "/downloads/"),
        (["desktop"], "/desktop/"),
        (["documents", "document folder"], "/documents/"),
        (["movies", "movie folder"], "/movies/"),
        (["music folder", "in music"], "/music/"),
        (["pictures", "photos library", "photo library"], "/pictures/"),
        (["library"], "/library/"),
        (["applications folder", "in applications"], "/applications/"),
    ]

    /// Words ignored when extracting free-text name needles — structural/stop words
    /// already consumed by, or irrelevant to, the structured filter axes.
    private static let stopWords: Set<String> = [
        "find", "search", "show", "me", "all", "any", "the", "a", "an", "my", "and",
        "or", "with", "of", "in", "on", "for", "that", "are", "is", "to", "files",
        "file", "named", "called", "name", "containing", "contains", "than", "older",
        "newer", "bigger", "larger", "smaller", "over", "under", "above", "below",
        "more", "less", "least", "greater", "at", "not", "touched", "old", "from",
        "big", "huge", "small", "tiny", "stale", "unused", "ago", "days", "day",
        "weeks", "week", "months", "month", "years", "year",
    ]

    /// Extract name substrings: quoted phrases first (kept verbatim), then any
    /// remaining alphanumeric words that aren't stop words / units / pure numbers /
    /// already consumed by the kind & location axes.
    private static func nameNeedles(in s: String, consumed: Set<String> = []) -> [String] {
        var needles: [String] = []
        var residual = s
        // Individual words from the (possibly multi-word) consumed phrases.
        let consumedWords = Set(consumed.flatMap { $0.split(separator: " ").map(String.init) })

        // Quoted phrases: "annual report" → an exact-ish substring needle.
        if let re = try? NSRegularExpression(pattern: "\"([^\"]+)\"") {
            let ns = residual as NSString
            let matches = re.matches(in: residual, range: NSRange(location: 0, length: ns.length))
            for m in matches where m.numberOfRanges > 1 {
                let phrase = ns.substring(with: m.range(at: 1))
                    .trimmingCharacters(in: .whitespaces).lowercased()
                if !phrase.isEmpty { needles.append(phrase) }
            }
            // Strip quoted spans so their words aren't re-added below.
            residual = re.stringByReplacingMatches(
                in: residual, range: NSRange(location: 0, length: ns.length), withTemplate: " ")
        }

        // A bare "*.ext" or ".ext" token becomes an extension name needle.
        // Remaining words: split on non-alphanumerics, drop stop words, units,
        // pure numbers, and very short tokens.
        let tokens = residual.split { !$0.isLetter && !$0.isNumber && $0 != "." }
        for token in tokens {
            var t = String(token)
            if t.hasPrefix("*") { t.removeFirst() }
            if t.isEmpty { continue }
            if t.hasPrefix("."), t.count > 1 {        // ".pdf" → extension match
                needles.append(t)
                continue
            }
            if t.count < 3 { continue }                // skip noise like "gb", "ok"
            if stopWords.contains(t) { continue }
            if sizeUnits.contains(t) { continue }
            if consumedWords.contains(t) { continue }  // kind/location word
            if Double(t) != nil { continue }           // pure number
            needles.append(t)
        }

        // De-dup while preserving order.
        var seen = Set<String>()
        return needles.filter { seen.insert($0).inserted }
    }

    // MARK: Number extraction

    private static let sizeUnits: Set<String> = ["tb", "gb", "mb", "kb", "t", "g", "m", "k", "b", "bytes"]

    private static func sizeBytes(in s: String, after triggers: [String]) -> Int64? {
        for trigger in triggers {
            guard let r = s.range(of: trigger) else { continue }
            let tail = String(s[r.upperBound...])
            if let bytes = firstSizeToken(in: tail) { return bytes }
        }
        return nil
    }

    /// First "<number><unit>" in a string, e.g. "1gb", "500mb", "2 tb".
    private static func firstSizeToken(in s: String) -> Int64? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(tb|gb|mb|kb|t|g|m|k)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let numR = Range(m.range(at: 1), in: s),
              let unitR = Range(m.range(at: 2), in: s),
              let value = Double(s[numR]) else { return nil }
        let mult: Double
        switch String(s[unitR]).first {
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

    /// Human label for the matched location hint(s), e.g. "/downloads/" → "Downloads".
    private static func locationName(_ hints: [String]) -> String {
        hints.map { hint in
            let trimmed = hint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        }.joined(separator: " / ")
    }
}
