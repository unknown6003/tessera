import Foundation

// MARK: - On-device AI facade
//
// All AI runs LOCALLY via the MLX model (see MLXModelManager) — nothing is sent
// over the network for inference. When the model isn't downloaded/ready, callers
// fall back to deterministic logic, so the app stays fully functional.

enum LocalAI {
    /// Whether the on-device model is downloaded and ready.
    @MainActor static var isAvailable: Bool { MLXModelManager.shared.isReady }

    /// One-shot text generation. Returns nil if the model isn't ready or fails.
    static func generateText(instructions: String, prompt: String) async -> String? {
        await MLXModelManager.shared.generate(instructions: instructions, prompt: prompt)
    }

    /// Extract the first balanced top-level JSON object from model output (models
    /// sometimes wrap JSON in prose or ``` fences). Returns the raw object string.
    static func extractJSONObject(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var idx = start
        while idx < text.endIndex {
            let ch = text[idx]
            if inString {
                if escaped { escaped = false }
                else if ch == "\\" { escaped = true }
                else if ch == "\"" { inString = false }
            } else {
                if ch == "\"" { inString = true }
                else if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(text[start ... idx]) }
                }
            }
            idx = text.index(after: idx)
        }
        return nil
    }
}
