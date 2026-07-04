import Foundation

// MARK: - Per-folder AI explainer
//
// Given a selected directory, ask the on-device model what the folder is, what
// likely created it, whether it's safe to delete, and what would break if it's
// removed — answered in a couple of plain sentences for the inspector.
//
// PRIVACY: the model runs ENTIRELY ON-DEVICE (see MLXModelManager). The only
// thing handed to it is the folder's name and its home-abbreviated path (the
// literal home directory is replaced with "~"); no file contents, sizes, or
// other user data ever leave the Mac. Returns nil when the model isn't ready or
// produces nothing usable, so the caller can show a friendly fallback.

enum FolderExplainer {
    /// Generate a short, human-readable explanation of `node` using the on-device
    /// model. `node` is expected to be a real (non-synthetic) directory.
    static func explain(node: FileNode) async -> String? {
        // Abbreviate the home directory to "~" so the prompt stays compact and the
        // username isn't spelled out in full.
        let path = abbreviatedPath(for: node)

        let instructions = """
        You are a macOS storage assistant. The user selected a folder on their Mac. \
        In 2 to 4 short, plain-English sentences, explain: what this folder is, what \
        app or process most likely created it, whether it is safe to delete, and what \
        would break if it were removed. Be concrete and cautious — if you are unsure, \
        say so. Do not use markdown, bullet points, or headings; reply with prose only.
        """

        let prompt = """
        Folder name: \(node.name)
        Path: \(path)
        """

        guard let raw = await LocalAI.generateText(instructions: instructions, prompt: prompt) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The node's filesystem path with the user's home directory collapsed to "~".
    private static func abbreviatedPath(for node: FileNode) -> String {
        let full = node.url.path
        let home = NSHomeDirectory()
        if full == home { return "~" }
        if full.hasPrefix(home + "/") {
            return "~" + full.dropFirst(home.count)
        }
        return full
    }
}
