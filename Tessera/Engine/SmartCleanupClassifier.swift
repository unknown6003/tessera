import Foundation

// MARK: - Smart cleanup classification (on-device)
//
// Judges the largest directories the deterministic rules didn't recognize, using
// the on-device MLX model. Review-only — its picks are SUGGESTIONS the user adds
// manually, never auto-staged. PRIVACY: runs entirely on-device; nothing is sent,
// and sensitive folders (denyNames) are never even shown to it.

enum SmartCleanupClassifier {
    struct Result: Identifiable, Sendable {
        let node: FileNode
        let safeToDelete: Bool
        let category: String
        let confidence: Int
        var id: ObjectIdentifier { ObjectIdentifier(node) }
    }

    /// True when the on-device model is downloaded and ready.
    @MainActor static var isAvailable: Bool { LocalAI.isAvailable }

    /// Directories that are NEVER candidates and never shown to the model.
    private static let denyNames: Set<String> = [
        "mobile documents", "cloudstorage", "messages", "mail", "containers",
        "group containers", "preferences", "keychains", "photos", "photos library",
        "calendars", "documents", "desktop", "movies", "music", "pictures",
        "safari", "syncedpreferences", "accounts", "icloud drive", "library", "keychain",
    ]

    /// Pick the largest directories the rules didn't already classify, excluding
    /// sensitive folders — the candidates handed to the model.
    static func candidates(root: FileNode, excluding matched: Set<ObjectIdentifier>,
                           minBytes: Int64 = 200 * 1024 * 1024, limit: Int = 12) -> [FileNode] {
        var found: [FileNode] = []
        var stack = root.children
        while let node = stack.popLast() {
            guard node.isDirectory, !node.isSynthetic else { continue }
            if denyNames.contains(node.name.lowercased()) { continue }
            if !matched.contains(ObjectIdentifier(node)), node.size >= minBytes {
                found.append(node)
                continue  // take the big dir as a unit; don't descend into it
            }
            stack.append(contentsOf: node.children)
        }
        return Array(found.sorted { $0.size > $1.size }.prefix(limit))
    }

    /// Classify candidate directories with the on-device model. Returns [] when the
    /// model isn't ready or on any failure.
    static func classify(candidates: [FileNode]) async -> [Result] {
        guard !candidates.isEmpty else { return [] }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let listing = candidates.enumerated().map { i, node -> String in
            var p = node.url.path
            if p.hasPrefix(home) { p = "~" + p.dropFirst(home.count) }
            return "\(i): \(p)"
        }.joined(separator: "\n")

        let instructions = """
        You classify macOS folder PATHS for safe disk cleanup, judging only from the \
        path text. SAFE to delete: caches, temporary files, logs, and auto-regenerated \
        build outputs. NOT safe: documents, projects, downloads, app data, and anything \
        user-created. Be conservative. Reply with ONLY a JSON object of this exact shape, \
        one entry per folder index:
        {"verdicts":[{"index":int,"safeToDelete":bool,"category":string,"confidence":int}]}
        """
        let prompt = "Classify each folder:\n\(listing)"

        guard let text = await LocalAI.generateText(instructions: instructions, prompt: prompt),
              let verdicts = parse(text) else { return [] }

        var results: [Result] = []
        var seen = Set<Int>()
        for v in verdicts where v.index >= 0 && v.index < candidates.count && seen.insert(v.index).inserted {
            results.append(Result(node: candidates[v.index], safeToDelete: v.safeToDelete,
                                  category: v.category, confidence: max(0, min(100, v.confidence))))
        }
        return results
    }

    struct Verdict: Decodable, Sendable {
        let index: Int
        let safeToDelete: Bool
        let category: String
        let confidence: Int
    }

    /// Parse the model's JSON verdicts. Pure — unit-testable.
    static func parse(_ text: String) -> [Verdict]? {
        guard let json = LocalAI.extractJSONObject(text),
              let data = json.data(using: .utf8) else { return nil }
        struct Wire: Decodable { let verdicts: [Verdict] }
        return (try? JSONDecoder().decode(Wire.self, from: data))?.verdicts
    }
}
