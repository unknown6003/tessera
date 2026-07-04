import Foundation

// MARK: - Cleanup classification model
//
// After a scan, the assembled tree is classified — pure CPU over data already in
// hand (no `stat`, no filesystem touch). Rules match on path/name only and never
// trigger a deletion: the most a suggestion can do is fill the existing collector,
// which the user then reviews and deletes manually behind the usual confirmation.

/// How aggressively a category may be acted on.
enum CleanupConfidence: Sendable {
    /// Regenerated automatically, holds no user-authored data — the only tier the
    /// one-button "add safe items" action stages.
    case safeRegenerable
    /// Plausibly reclaimable but possibly personal (Downloads, installers, logs).
    /// Surfaced for opt-in only; never bulk-staged.
    case review
}

struct CleanupCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let symbol: String
    let confidence: CleanupConfidence
}

/// A single classification rule. Predicates get the node's lowercased name and its
/// lowercased absolute path — both cheap, because the classifier builds the path by
/// string concatenation as it walks (never the CFURL-based `node.url`).
struct CleanupRule: Sendable {
    let category: CleanupCategory
    let matches: @Sendable (_ lowerName: String, _ lowerPath: String) -> Bool
}

// MARK: - Categories

enum CleanupCatalog {
    // Safe — regenerable, no user data.
    static let xcodeDerived = CleanupCategory(id: "xcode.deriveddata", title: "Xcode Derived Data",
        explanation: "Build intermediates Xcode regenerates on the next build.",
        symbol: "hammer.fill", confidence: .safeRegenerable)
    static let xcodeDeviceSupport = CleanupCategory(id: "xcode.devicesupport", title: "Xcode Device Support",
        explanation: "Per-OS symbol caches re-downloaded when you reconnect a device.",
        symbol: "iphone", confidence: .safeRegenerable)
    static let nodeModules = CleanupCategory(id: "dev.node_modules", title: "node_modules",
        explanation: "JavaScript dependencies restored by `npm install`.",
        symbol: "shippingbox.fill", confidence: .safeRegenerable)
    static let packageCache = CleanupCategory(id: "dev.packagecache", title: "Package Manager Caches",
        explanation: "Homebrew / npm / pip / Gradle / CocoaPods / Cargo download caches, re-fetched on demand.",
        symbol: "cube.box.fill", confidence: .safeRegenerable)
    static let userCaches = CleanupCategory(id: "system.caches", title: "Application Caches",
        explanation: "App caches in Library/Caches, rebuilt as apps run.",
        symbol: "externaldrive.badge.xmark", confidence: .safeRegenerable)
    static let adobeMediaCache = CleanupCategory(id: "adobe.mediacache", title: "Adobe Media Cache",
        explanation: "Premiere / After Effects media cache & peak files — regenerated, and these grow fast.",
        symbol: "film.stack", confidence: .safeRegenerable)
    static let adobeCameraRaw = CleanupCategory(id: "adobe.cameraraw", title: "Adobe Camera Raw Cache",
        explanation: "Camera Raw / Lightroom preview cache, regenerated on demand.",
        symbol: "camera.fill", confidence: .safeRegenerable)
    static let browserCache = CleanupCategory(id: "browser.cache", title: "Browser Caches",
        explanation: "Chrome / Safari / Firefox / Edge web caches, rebuilt as you browse.",
        symbol: "safari.fill", confidence: .safeRegenerable)
    static let trash = CleanupCategory(id: "system.trash", title: "Trash",
        explanation: "Items you already moved to the Trash.",
        symbol: "trash.fill", confidence: .safeRegenerable)

    // Review — opt-in only.
    static let buildOutput = CleanupCategory(id: "dev.buildoutput", title: "Build Output Folders",
        explanation: "build / target / dist folders — usually regenerable, but verify they aren't source.",
        symbol: "wrench.and.screwdriver.fill", confidence: .review)
    static let logs = CleanupCategory(id: "system.logs", title: "Logs",
        explanation: "Diagnostic logs — safe to clear but occasionally useful for debugging.",
        symbol: "doc.text.fill", confidence: .review)
    static let installers = CleanupCategory(id: "user.installers", title: "Installers & Disk Images",
        explanation: ".dmg / .pkg / .iso files — usually re-downloadable once installed.",
        symbol: "opticaldisc.fill", confidence: .review)
    static let downloads = CleanupCategory(id: "user.downloads", title: "Downloads",
        explanation: "Your Downloads folder — review before clearing; it may hold things you want.",
        symbol: "arrow.down.circle.fill", confidence: .review)

    /// Every category — the taxonomy the natural-language planner chooses from.
    /// (Only id/title/explanation/tier are ever sent; no user data.)
    static let all: [CleanupCategory] = [
        xcodeDerived, xcodeDeviceSupport, nodeModules, packageCache, userCaches,
        adobeMediaCache, adobeCameraRaw, browserCache, trash,
        buildOutput, logs, installers, downloads,
    ]
}

// MARK: - Rules

enum CleanupClassifier {
    static let rules: [CleanupRule] = [
        // ---- Safe ----
        CleanupRule(category: CleanupCatalog.nodeModules) { n, _ in n == "node_modules" },
        CleanupRule(category: CleanupCatalog.xcodeDerived) { n, _ in n == "deriveddata" },
        CleanupRule(category: CleanupCatalog.xcodeDeviceSupport) { n, p in
            n.hasSuffix("devicesupport") && p.contains("/developer/xcode/") },

        // Adobe (called out by the user — these balloon). Name-gated so a non-Adobe
        // directory costs only cheap name comparisons, never a path scan.
        CleanupRule(category: CleanupCatalog.adobeMediaCache) { n, p in
            (n == "media cache files" || n == "media cache" || n == "peak files") && p.contains("/adobe") },
        CleanupRule(category: CleanupCatalog.adobeCameraRaw) { n, p in
            n == "cache" && (p.contains("/adobe/cameraraw") || p.contains("lightroom")) },

        // Package-manager caches (match the cache dir, not the whole tool home).
        // Name-gated for the same reason.
        CleanupRule(category: CleanupCatalog.packageCache) { n, p in
            (n == "homebrew" && p.contains("/caches/"))
            || n == "_cacache"
            || (n == "caches" && (p.contains("/.gradle") || p.contains("cocoapods")))
            || (n == "cache" && (p.contains("/.cache/yarn") || p.contains("/.cargo/registry")))
            || (n == "repos" && p.contains("cocoapods")) },

        // Browser caches.
        CleanupRule(category: CleanupCatalog.browserCache) { n, p in
            (n == "cache" || n == "code cache" || n == "gpucache")
            && (p.contains("/google/chrome") || p.contains("/firefox/") || p.contains("/com.apple.safari")
                || p.contains("/microsoft edge") || p.contains("/brave-browser")) },

        // Generic application caches (~/Library/Caches, /Library/Caches). Checked
        // after the more specific cache rules above so they win attribution.
        CleanupRule(category: CleanupCatalog.userCaches) { n, p in
            n == "caches" && p.contains("/library/caches") },

        CleanupRule(category: CleanupCatalog.trash) { n, _ in n == ".trash" || n == ".trashes" },

        // ---- Review ----
        CleanupRule(category: CleanupCatalog.buildOutput) { n, p in
            (n == "build" || n == "target" || n == "dist" || n == ".next" || n == "out")
            && (p.contains("/developer/") || p.contains("/documents/") || p.contains("/projects/")
                || p.contains("/code/") || p.contains("/src/")) },
        CleanupRule(category: CleanupCatalog.logs) { n, p in
            n == "logs" && p.contains("/library/logs") },
        CleanupRule(category: CleanupCatalog.installers) { n, _ in
            n.hasSuffix(".dmg") || n.hasSuffix(".pkg") || n.hasSuffix(".iso") },
        CleanupRule(category: CleanupCatalog.downloads) { n, p in
            n == "downloads" && p.contains("/users/") },
    ]

    /// Classify the assembled tree into a report. One iterative pre-order walk; the
    /// lowercased absolute path is built by cheap string concatenation as we descend
    /// (never the CFURL-based `node.url`, which is far too slow at this scale). A
    /// matched directory is taken as a whole unit and not descended, so nested
    /// matches are subsumed — mirroring the collector's supersede rule.
    static func classify(root: FileNode) -> CleanupReport {
        var matches: [(CleanupCategory, FileNode)] = []
        // Only directories carry a path and go through the rule sweep; files (the
        // large majority of nodes) only ever match the installer name-suffix rule,
        // so they're checked inline without building a path or touching the stack.
        var stack: [(node: FileNode, lowerPath: String)] = []

        func consider(_ children: [FileNode], parentLowerPath: String) {
            for child in children where !child.isSynthetic {
                let lname = child.name.lowercased()
                if child.isDirectory {
                    stack.append((child, parentLowerPath + "/" + lname))
                } else if lname.hasSuffix(".dmg") || lname.hasSuffix(".pkg") || lname.hasSuffix(".iso") {
                    matches.append((CleanupCatalog.installers, child))
                }
            }
        }

        consider(root.children, parentLowerPath: root.url.path.lowercased())  // one CFURL call
        while let (node, lowerPath) = stack.popLast() {
            if let category = rules.first(where: { $0.matches(node.name.lowercased(), lowerPath) })?.category {
                matches.append((category, node))
                continue // whole subtree is the unit; don't descend
            }
            consider(node.children, parentLowerPath: lowerPath)
        }
        return CleanupReport(matches: matches)
    }
}

// MARK: - Report

struct CleanupReport: Sendable {
    struct Group: Identifiable, Sendable {
        let category: CleanupCategory
        let nodes: [FileNode]
        var id: String { category.id }
        var totalBytes: Int64 { nodes.reduce(0) { $0 + $1.size } }
    }

    let groups: [Group]

    init(matches: [(CleanupCategory, FileNode)]) {
        var byCategory: [String: (CleanupCategory, [FileNode])] = [:]
        for (category, node) in matches where node.size > 0 {
            byCategory[category.id, default: (category, [])].1.append(node)
        }
        groups = byCategory.values
            .map { Group(category: $0.0, nodes: $0.1.sorted { $0.size > $1.size }) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }

    var safeGroups: [Group] { groups.filter { $0.category.confidence == .safeRegenerable } }
    var reviewGroups: [Group] { groups.filter { $0.category.confidence == .review } }
    var safeNodes: [FileNode] { safeGroups.flatMap(\.nodes) }
    var safeTotalBytes: Int64 { safeNodes.reduce(0) { $0 + $1.size } }
    var isEmpty: Bool { groups.isEmpty }
}
