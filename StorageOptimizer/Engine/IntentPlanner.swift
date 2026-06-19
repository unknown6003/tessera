import Foundation

// MARK: - Natural-language intent planner (on-device)
//
// Turns a free-text cleanup goal into a structured CleanupQuery. The built-in
// keyword parser (CleanupQueryParser) is the always-available fallback; when the
// on-device MLX model is downloaded it handles nuanced phrasing the keywords can't.
// PRIVACY: everything runs locally — only the query is built; nothing is sent.

enum IntentPlanner {
    struct Plan: Sendable {
        let query: CleanupQuery
        /// True when the on-device model produced this query (vs the keyword parser).
        let usedAI: Bool
    }

    static func plan(intent: String, todayEpoch: Int64) async -> Plan {
        let local = CleanupQueryParser.parse(intent)

        let catalog = CleanupCatalog.all.map {
            "\($0.id) [\($0.confidence == .safeRegenerable ? "safe" : "review")] — \($0.title)"
        }.joined(separator: "\n")

        let instructions = """
        You convert a macOS user's plain-language disk-cleanup goal into a JSON filter. \
        Choose category ids ONLY from the provided catalog. Reply with ONLY a JSON object, \
        no prose, of exactly this shape:
        {"categoryIDs":[string],"includeReviewTier":bool,"maxAgeDays":int,"minSizeMB":int,"targetFreeMB":int,"summary":string}
        Use 0 for any numeric field that doesn't apply. Set includeReviewTier true only if \
        the user clearly wants riskier items (Downloads, installers, logs, build output). \
        Be conservative.
        """
        let prompt = "Catalog (id [tier] — title):\n\(catalog)\n\nUser goal: \(intent)"

        guard let text = await LocalAI.generateText(instructions: instructions, prompt: prompt),
              let query = parse(text, fallback: local) else {
            return Plan(query: local, usedAI: false)
        }
        return Plan(query: query, usedAI: true)
    }

    /// Parse the model's JSON into a CleanupQuery. Pure — unit-testable.
    static func parse(_ text: String, fallback: CleanupQuery) -> CleanupQuery? {
        guard let json = LocalAI.extractJSONObject(text),
              let data = json.data(using: .utf8),
              let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }

        var q = CleanupQuery.empty
        q.categoryIDs = Set(wire.categoryIDs ?? [])
        q.includeReviewTier = wire.includeReviewTier ?? false
        q.maxAgeDays = (wire.maxAgeDays ?? 0) > 0 ? wire.maxAgeDays : nil
        q.minSizeBytes = (wire.minSizeMB ?? 0) > 0 ? Int64(wire.minSizeMB!) * 1024 * 1024 : nil
        q.targetFreeBytes = (wire.targetFreeMB ?? 0) > 0 ? Int64(wire.targetFreeMB!) * 1024 * 1024 : nil
        let summary = (wire.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        q.summary = summary.isEmpty ? CleanupQueryParser.describe(q) : summary
        // If the model returned nothing actionable, prefer a non-trivial keyword parse.
        if q.isTrivial && !fallback.isTrivial { return fallback }
        return q
    }

    private struct Wire: Decodable {
        let categoryIDs: [String]?
        let includeReviewTier: Bool?
        let maxAgeDays: Int?
        let minSizeMB: Int?
        let targetFreeMB: Int?
        let summary: String?
    }
}
