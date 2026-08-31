import Foundation
import AppKit

// MARK: - Rescue state

enum RescuePhase: String, Codable, Hashable, Sendable {
    case needsRescue = "needs_rescue"
    case scanning
    case diagnosing
    case planReady = "plan_ready"
    case reviewing
    case staged
    case confirmingTrash = "confirming_trash"
    case moving
    case verifying
    case result
    case remembering

    var title: String {
        switch self {
        case .needsRescue: return "Ready to scan"
        case .scanning: return "Scanning locally"
        case .diagnosing: return "Building diagnosis"
        case .planReady: return "Plan ready"
        case .reviewing: return "Review candidates"
        case .staged: return "Ready to move"
        case .confirmingTrash: return "Confirm Move to Trash"
        case .moving: return "Moving to Trash"
        case .verifying: return "Verifying space"
        case .result: return "Rescue result"
        case .remembering: return "Saved on this Mac"
        }
    }

    var symbol: String {
        switch self {
        case .needsRescue: return "lifepreserver"
        case .scanning, .diagnosing: return "arrow.triangle.2.circlepath"
        case .planReady, .reviewing: return "list.bullet.clipboard"
        case .staged: return "checkmark.circle"
        case .confirmingTrash: return "checkmark.shield"
        case .moving: return "trash"
        case .verifying: return "chart.bar.xaxis"
        case .result: return "flag.checkered"
        case .remembering: return "bookmark"
        }
    }
}

enum RescueGoal: String, Codable, CaseIterable, Hashable, Sendable {
    case update
    case install
    case export
    case build
    case normalWork = "normal_work"

    var title: String {
        switch self {
        case .update: return "Install an update"
        case .install: return "Install an app or tool"
        case .export: return "Export a project"
        case .build: return "Build a project"
        case .normalWork: return "Make room for normal work"
        }
    }

    /// A small working-space estimate. The user can still enter a larger target.
    var defaultBuffer: Int64 {
        switch self {
        case .update: return 4 * 1_000_000_000
        case .install: return 2 * 1_000_000_000
        case .export: return 8 * 1_000_000_000
        case .build: return 4 * 1_000_000_000
        case .normalWork: return 0
        }
    }
}

enum CleanupRisk: String, Codable, Hashable, Sendable {
    case safe
    case review
    case protected

    var title: String {
        switch self {
        case .safe: return "Safe to review"
        case .review: return "Review first"
        case .protected: return "Protected"
        }
    }
}

enum RescueAction: String, Codable, Hashable, Sendable {
    case stage
    case inspect
    case handoff
    case hold

    var title: String {
        switch self {
        case .stage: return "Can be staged"
        case .inspect: return "Inspect before staging"
        case .handoff: return "Use owner app"
        case .hold: return "Keep protected"
        }
    }
}

enum RescueActionError: LocalizedError, Sendable {
    case ownerActive(String)

    var errorDescription: String? {
        switch self {
        case .ownerActive(let message): return message
        }
    }
}

enum CleanupOwnerState: String, Codable, Hashable, Sendable {
    case stopped
    case active
    case unknown

    // ponytail: owner safety covers only the two Xcode-generated safe roots;
    // add owner adapters, lock checks, and open-handle checks before widening it.
    @MainActor
    static func current() -> CleanupOwnerState {
        let activeBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let xcodeBundleIDs = [
            "com.apple.dt.Xcode",
            "com.apple.dt.Xcode.BuildSystem",
            "com.apple.dt.Xcode.Previews",
        ]
        return xcodeBundleIDs.contains(where: activeBundleIDs.contains) ? .active : .stopped
    }
}

// MARK: - Cleanup classification model

/// How confidently a category can enter the default Rescue selection.
enum CleanupConfidence: String, Codable, Hashable, Sendable {
    /// Known generated output with a narrow rule and a captured scan identity.
    case safeRegenerable
    /// Plausibly reclaimable, but ownership or recovery needs review.
    case review
    /// The path is owner-managed, personal, or otherwise outside generic cleanup.
    case protected

    var title: String {
        switch self {
        case .safeRegenerable: return "High"
        case .review: return "Review"
        case .protected: return "Protected"
        }
    }

    var risk: CleanupRisk {
        switch self {
        case .safeRegenerable: return .safe
        case .review: return .review
        case .protected: return .protected
        }
    }
}

struct CleanupCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let symbol: String
    let confidence: CleanupConfidence
    let owner: String
    let sideEffect: String

    init(id: String, title: String, explanation: String, symbol: String,
         confidence: CleanupConfidence, owner: String = "Unknown owner",
         sideEffect: String = "Review the exact path before moving it.") {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.symbol = symbol
        self.confidence = confidence
        self.owner = owner
        self.sideEffect = sideEffect
    }
}

/// A single classification rule. Predicates only inspect the already-built tree.
struct CleanupRule: Sendable {
    let category: CleanupCategory
    let matches: @Sendable (_ lowerName: String, _ lowerPath: String) -> Bool
}

/// One explainable plan item. The node is kept so the existing collector can
/// stage it; the rest of the record is stable, local evidence for the UI and
/// the last-step safety check.
struct CleanupRecommendation: Identifiable, Sendable {
    let id: String
    let node: FileNode
    let category: CleanupCategory
    let path: String
    let owner: String
    let reason: String
    let risk: CleanupRisk
    let confidence: CleanupConfidence
    let sideEffect: String
    let action: RescueAction
    let logicalBytes: Int64?
    let physicalBytes: Int64
    let identity: ScanIdentity?
    let ownerState: CleanupOwnerState

    static func stableID(categoryID: String, path: String) -> String {
        "\(categoryID)::\(URL(fileURLWithPath: path).standardizedFileURL.path)"
    }

    init(node: FileNode, category: CleanupCategory,
         ownerState: CleanupOwnerState = .stopped,
         coverageComplete: Bool = true,
         hasProtectedDescendant: Bool = false,
         hasOpaqueDescendant: Bool = false) {
        let path = node.url.standardizedFileURL.path
        // A hand-built node has no identity proof. It can still be shown, but it
        // cannot enter the safe default or pass an action preflight.
        let effectiveConfidence: CleanupConfidence =
            category.confidence == .safeRegenerable
                && (!(node.scanIdentity?.hasStableObjectIdentifier ?? false)
                    || ownerState != .stopped
                    || !coverageComplete
                    || hasProtectedDescendant
                    || hasOpaqueDescendant)
                ? .review
                : category.confidence
        self.id = Self.stableID(categoryID: category.id, path: path)
        self.node = node
        self.category = category
        self.path = path
        self.owner = category.owner
        if effectiveConfidence == .review && category.confidence == .safeRegenerable {
            if ownerState == .active {
                self.reason = "\(category.explanation) The owner app is active, so it stays in review."
            } else if ownerState == .unknown {
                self.reason = "\(category.explanation) The owner state is unknown, so it stays in review."
            } else if !coverageComplete {
                self.reason = "\(category.explanation) The scan has coverage gaps, so it stays in review until a fresh scan completes."
            } else if hasProtectedDescendant {
                self.reason = "\(category.explanation) It contains protected owner-managed data, so review the exact contents first."
            } else if hasOpaqueDescendant {
                self.reason = "\(category.explanation) It contains unscanned or separately mounted data, so review the exact contents first."
            } else {
                self.reason = "\(category.explanation) This result has no stable scan identity, so it stays in review."
            }
        } else {
            self.reason = category.explanation
        }
        self.risk = effectiveConfidence.risk
        self.confidence = effectiveConfidence
        self.sideEffect = category.sideEffect
        self.action = effectiveConfidence == .safeRegenerable ? .stage
            : (effectiveConfidence == .protected ? .handoff : .inspect)
        self.logicalBytes = node.logicalSize
        self.physicalBytes = node.physicalSize
        self.identity = node.scanIdentity
        self.ownerState = category.confidence == .safeRegenerable ? ownerState : .unknown
    }

    var proof: [String] {
        var result = [
            "Rule: \(category.id)",
            "Rule version: \(CleanupClassifier.ruleVersion)",
            identity?.hasStableObjectIdentifier == true
                ? "Stable scan identity: captured" : "Stable scan identity: unavailable",
            "Owner state: \(ownerState.rawValue)",
            "Path checked: \(path)",
            "Measured allocated size: \(physicalBytes) bytes",
        ]
        if let logicalBytes {
            result.append("Measured logical size: \(logicalBytes) bytes")
        }
        return result
    }
}

// MARK: - Categories

enum CleanupCatalog {
    // Safe only for exact Xcode-generated locations. All other app and package
    // data stays in review until an owner-aware adapter can prove more.
    static let xcodeDerived = CleanupCategory(
        id: "xcode.deriveddata", title: "Xcode Derived Data",
        explanation: "Build intermediates Xcode can regenerate on the next build.",
        symbol: "hammer.fill", confidence: .safeRegenerable, owner: "Xcode",
        sideEffect: "The next Xcode build may take longer.")
    static let xcodeDeviceSupport = CleanupCategory(
        id: "xcode.devicesupport", title: "Xcode Device Support",
        explanation: "Device symbols Xcode can download again when needed.",
        symbol: "iphone", confidence: .safeRegenerable, owner: "Xcode",
        sideEffect: "Xcode may download device symbols again.")

    static let nodeModules = CleanupCategory(
        id: "dev.node_modules", title: "node_modules",
        explanation: "Project dependencies may be restorable, but local or offline packages can be unique.",
        symbol: "shippingbox.fill", confidence: .review, owner: "Package manager",
        sideEffect: "The project may need an online install and its lockfile or local source.")
    static let packageCache = CleanupCategory(
        id: "dev.packagecache", title: "Package Manager Caches",
        explanation: "Downloaded packages may be fetched again, but shared stores and offline sources need review.",
        symbol: "cube.box.fill", confidence: .review, owner: "Package manager",
        sideEffect: "Future builds may download packages again or lose offline recovery.")
    static let userCaches = CleanupCategory(
        id: "system.caches", title: "Application Caches",
        explanation: "An app cache may be rebuildable, but the exact owner and active state are not proven.",
        symbol: "externaldrive.badge.xmark", confidence: .review, owner: "Owning app",
        sideEffect: "The app may rebuild data or lose useful local working state.")
    static let adobeMediaCache = CleanupCategory(
        id: "adobe.mediacache", title: "Adobe Media Cache",
        explanation: "Generated media can be rebuilt, but its project scope and active state need review.",
        symbol: "film.stack", confidence: .review, owner: "Adobe app",
        sideEffect: "Adobe may rebuild previews and media cache during the next project.")
    static let adobeCameraRaw = CleanupCategory(
        id: "adobe.cameraraw", title: "Adobe Camera Raw Cache",
        explanation: "Preview data can be generated again, but the owner app may be using it now.",
        symbol: "camera.fill", confidence: .review, owner: "Adobe app",
        sideEffect: "Adobe may rebuild previews and use working space again.")
    static let browserCache = CleanupCategory(
        id: "browser.cache", title: "Browser Caches",
        explanation: "This exact cache may be rebuildable, but the profile also holds sessions and credentials.",
        symbol: "safari.fill", confidence: .review, owner: "Browser",
        sideEffect: "The browser may rebuild cache data. The profile must stay protected.")
    static let buildOutput = CleanupCategory(
        id: "dev.buildoutput", title: "Build Output Folders",
        explanation: "Build output is often regenerable, but a source folder can use the same name.",
        symbol: "wrench.and.screwdriver.fill", confidence: .review, owner: "Project owner",
        sideEffect: "The next build may take longer or fail if this is not output.")
    static let logs = CleanupCategory(
        id: "system.logs", title: "Logs",
        explanation: "Logs can be useful for debugging, so review the exact owner and age first.",
        symbol: "doc.text.fill", confidence: .review, owner: "System or owning app",
        sideEffect: "Recent diagnostic evidence may be lost.")
    static let installers = CleanupCategory(
        id: "user.installers", title: "Installers & Disk Images",
        explanation: "An installer may be downloaded again, but it can also be the only local copy.",
        symbol: "opticaldisc.fill", confidence: .review, owner: "User",
        sideEffect: "You may need to download or recreate the installer.")
    static let downloads = CleanupCategory(
        id: "user.downloads", title: "Downloads",
        explanation: "Downloads can contain anything. Review each exact item.",
        symbol: "arrow.down.circle.fill", confidence: .review, owner: "User",
        sideEffect: "The item may be the only local copy.")

    // Protected owner-managed roots. They are visible in the diagnosis, but they
    // never enter the generic collector.
    static let trash = CleanupCategory(
        id: "system.trash", title: "Trash",
        explanation: "Trash still occupies disk space until Finder empties it.",
        symbol: "trash.fill", confidence: .protected, owner: "Finder",
        sideEffect: "Empty Trash is a separate action and is not part of Rescue.")
    static let protectedBackup = CleanupCategory(
        id: "owner.backup", title: "Backups",
        explanation: "A backup is a recovery object, not a generic large folder.",
        symbol: "externaldrive.badge.timemachine", confidence: .protected, owner: "Time Machine or Finder",
        sideEffect: "Use the owner app after checking the restore target and verified copy.")
    static let protectedVirtualDisk = CleanupCategory(
        id: "owner.virtualdisk", title: "Virtual disks",
        explanation: "A disk image can contain live containers, snapshots, or guest state.",
        symbol: "rectangle.3.group", confidence: .protected, owner: "Docker or virtual machine app",
        sideEffect: "Use the owner app. Host and guest sizes can differ.")
    static let protectedCloud = CleanupCategory(
        id: "owner.cloud", title: "Cloud-managed storage",
        explanation: "A local copy and a remote item are different things.",
        symbol: "icloud.fill", confidence: .protected, owner: "Cloud provider",
        sideEffect: "Use a provider eviction or handoff. Generic Trash may change sync state.")
    static let protectedProfile = CleanupCategory(
        id: "owner.profile", title: "App profiles",
        explanation: "Profiles mix cache data with sessions, credentials, drafts, and history.",
        symbol: "person.crop.circle", confidence: .protected, owner: "Browser or editor",
        sideEffect: "Use an exact owner action with the app closed.")
    static let protectedCommunication = CleanupCategory(
        id: "owner.communication", title: "Communication data",
        explanation: "Messages, attachments, databases, drafts, and sync state share this root.",
        symbol: "message.fill", confidence: .protected, owner: "Messages or communication app",
        sideEffect: "Use the owner app after checking sync, account, and encryption state.")

    static let all: [CleanupCategory] = [
        xcodeDerived, xcodeDeviceSupport, nodeModules, packageCache, userCaches,
        adobeMediaCache, adobeCameraRaw, browserCache, buildOutput, logs,
        installers, downloads, trash, protectedBackup, protectedVirtualDisk,
        protectedCloud, protectedProfile, protectedCommunication,
    ]
}

// MARK: - Rules

enum CleanupClassifier {
    static let ruleVersion = "rescue-2026-08-31.1"

    static let rules: [CleanupRule] = [
        // Owner-managed roots must win before a child cache rule can run.
        CleanupRule(category: CleanupCatalog.protectedBackup) { n, p in
            p.contains("/library/application support/mobilesync/backup")
                || p.contains("/time machine/")
                || n.hasSuffix(".backupbundle")
                || n == "backups.backupdb"
                || (n == "backups" && p.hasPrefix("/volumes/"))
        },
        CleanupRule(category: CleanupCatalog.protectedVirtualDisk) { n, p in
            n == "docker.raw" || n == "docker.qcow2" || n.hasSuffix(".qcow2")
                || n.hasSuffix(".pvm") || n.hasSuffix(".utm") || n.hasSuffix(".vmdk")
                || p.hasSuffix("/.docker") || p.contains("/.docker/")
                || p.hasSuffix("/.parallels") || p.contains("/.parallels/")
        },
        CleanupRule(category: CleanupCatalog.protectedCloud) { _, p in
            p.hasSuffix("/library/cloudstorage") || p.contains("/library/cloudstorage/")
                || p.hasSuffix("/library/mobile documents") || p.contains("/library/mobile documents/")
        },
        CleanupRule(category: CleanupCatalog.protectedProfile) { _, p in
            p.contains("/library/application support/google/chrome")
                || p.contains("/library/application support/microsoft edge")
                || p.contains("/library/application support/brave-browser")
                || p.contains("/library/application support/firefox")
                || p.contains("/library/application support/com.microsoft.vscode")
        },
        CleanupRule(category: CleanupCatalog.protectedCommunication) { _, p in
            p.contains("/library/messages")
                || p.contains("/library/application support/discord")
                || p.contains("/library/application support/telegram")
                || p.contains("/library/application support/whatsapp")
                || p.contains("/library/application support/signal")
        },
        CleanupRule(category: CleanupCatalog.trash) { n, _ in n == ".trash" || n == ".trashes" },

        // Safe defaults use exact owner paths. The final action still checks the
        // scan identity and current permissions.
        CleanupRule(category: CleanupCatalog.xcodeDerived) { n, p in
            n == "deriveddata" && p.hasSuffix("/library/developer/xcode/deriveddata")
        },
        CleanupRule(category: CleanupCatalog.xcodeDeviceSupport) { n, p in
            n.hasSuffix("devicesupport") && p.hasSuffix("/library/developer/xcode/\(n)")
        },

        // Package, app, browser, and creator paths remain review-only until an
        // owner adapter can prove references, locks, and active state.
        CleanupRule(category: CleanupCatalog.nodeModules) { n, _ in n == "node_modules" },
        CleanupRule(category: CleanupCatalog.adobeMediaCache) { n, p in
            (n == "media cache files" || n == "media cache" || n == "peak files") && p.contains("/adobe")
        },
        CleanupRule(category: CleanupCatalog.adobeCameraRaw) { n, p in
            n == "cache" && (p.contains("/adobe/cameraraw") || p.contains("lightroom"))
        },
        CleanupRule(category: CleanupCatalog.packageCache) { n, p in
            (n == "homebrew" && p.contains("/caches/"))
                || n == "_cacache"
                || (n == "caches" && (p.contains("/.gradle") || p.contains("cocoapods")))
                || (n == "cache" && (p.contains("/.cache/yarn") || p.contains("/.cargo/registry")))
                || (n == "repos" && p.contains("cocoapods"))
        },
        CleanupRule(category: CleanupCatalog.browserCache) { n, p in
            (n == "cache" || n == "code cache" || n == "gpucache")
                && (p.contains("/google/chrome") || p.contains("/firefox/")
                    || p.contains("/com.apple.safari") || p.contains("/microsoft edge")
                    || p.contains("/brave-browser"))
        },
        CleanupRule(category: CleanupCatalog.userCaches) { n, p in
            n == "caches" && p.contains("/library/caches")
        },

        // Review-only paths.
        CleanupRule(category: CleanupCatalog.buildOutput) { n, p in
            (n == "build" || n == "target" || n == "dist" || n == ".next" || n == "out")
                && (p.contains("/developer/") || p.contains("/documents/") || p.contains("/projects/")
                    || p.contains("/code/") || p.contains("/src/"))
        },
        CleanupRule(category: CleanupCatalog.logs) { n, p in
            n == "logs" && p.contains("/library/logs")
        },
        CleanupRule(category: CleanupCatalog.installers) { n, _ in
            n.hasSuffix(".dmg") || n.hasSuffix(".pkg") || n.hasSuffix(".iso")
        },
        CleanupRule(category: CleanupCatalog.downloads) { n, p in
            n == "downloads" && p.contains("/users/")
        },
    ]

    /// Return the protected owner category for a path or any of its ancestors.
    /// Action paths can be minted outside the scanned tree by the app uninstaller,
    /// so the plan's protected recommendations are not enough as a safety gate.
    static func protectedCategory(for path: String) -> CleanupCategory? {
        var candidate = URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
        while true {
            let name = URL(fileURLWithPath: candidate).lastPathComponent.lowercased()
            if let rule = rules.first(where: {
                $0.category.confidence == .protected && $0.matches(name, candidate)
            }) {
                return rule.category
            }
            if candidate == "/" { return nil }
            let parent = URL(fileURLWithPath: candidate).deletingLastPathComponent().path
            if parent == candidate { return nil }
            candidate = parent
        }
    }

    /// Check only when a directory is about to be proposed as one unit. Walking
    /// every subtree here would defeat the scanner's cheap pre-order pass.
    static func hasProtectedDescendant(_ node: FileNode) -> Bool {
        guard node.isDirectory else { return false }
        let rootPath = node.url.standardizedFileURL.path
        var stack: [(FileNode, String)] = node.children.map { child in
            (child, rootPath == "/" ? "/\(child.name)" : rootPath + "/" + child.name)
        }
        while let (child, path) = stack.popLast() {
            guard !child.isSynthetic else { continue }
            if protectedCategory(for: path) != nil { return true }
            if child.isDirectory {
                stack.append(contentsOf: child.children.map { nested in
                    (nested, path == "/" ? "/\(nested.name)" : path + "/" + nested.name)
                })
            }
        }
        return false
    }

    /// An opaque child means the parent cannot be safely treated as one unit:
    /// the scan did not inspect that child's contents or it belongs to another
    /// mounted boundary.
    static func hasOpaqueDescendant(_ node: FileNode) -> Bool {
        guard node.isDirectory else { return false }
        var stack = node.children
        while let child = stack.popLast() {
            if child.isSynthetic { return true }
            if child.isDirectory { stack.append(contentsOf: child.children) }
        }
        return false
    }

    /// Classify the assembled tree with one iterative pre-order walk. A matched
    /// directory is kept as one explainable unit and its children are subsumed.
    static func classify(root: FileNode,
                         ownerState: CleanupOwnerState = .stopped,
                         coverageComplete: Bool? = nil) -> CleanupReport {
        var recommendations: [CleanupRecommendation] = []
        var stack: [(node: FileNode, lowerPath: String)] = []

        let hasCompleteCoverage = coverageComplete ?? root.scanCoverageGaps.isEmpty

        func append(_ category: CleanupCategory, _ node: FileNode) {
            recommendations.append(CleanupRecommendation(node: node, category: category,
                                                         ownerState: ownerState,
                                                         coverageComplete: hasCompleteCoverage,
                                                         hasProtectedDescendant: category.confidence == .safeRegenerable
                                                            && hasProtectedDescendant(node),
                                                         hasOpaqueDescendant: category.confidence == .safeRegenerable
                                                            && hasOpaqueDescendant(node)))
        }

        func consider(_ children: [FileNode], parentLowerPath: String) {
            for child in children where !child.isSynthetic {
                let lowerName = child.name.lowercased()
                let childPath = parentLowerPath == "/"
                    ? "/" + lowerName : parentLowerPath + "/" + lowerName
                if child.isDirectory {
                    stack.append((child, childPath))
                } else if lowerName.hasSuffix(".dmg") || lowerName.hasSuffix(".pkg")
                            || lowerName.hasSuffix(".iso") {
                    append(CleanupCatalog.installers, child)
                }
            }
        }

        consider(root.children, parentLowerPath: root.url.path.lowercased())
        while let (node, lowerPath) = stack.popLast() {
            if let category = rules.first(where: {
                $0.matches(node.name.lowercased(), lowerPath)
            })?.category {
                append(category, node)
                continue
            }
            // A package is one user-facing item. Do not surface a cache or
            // dependency-looking folder buried inside an app/bundle as if it
            // were an independent cleanup target.
            if node.kind == .package { continue }
            consider(node.children, parentLowerPath: lowerPath)
        }
        return CleanupReport(recommendations: recommendations)
    }
}

// MARK: - Report

struct CleanupReport: Sendable {
    struct Group: Identifiable, Sendable {
        let category: CleanupCategory
        let recommendations: [CleanupRecommendation]
        var id: String { "\(category.id)::\(risk.rawValue)" }
        var nodes: [FileNode] { recommendations.map(\.node) }
        var totalBytes: Int64 { recommendations.reduce(0) { $0 + $1.physicalBytes } }
        var risk: CleanupRisk { recommendations.first?.risk ?? category.confidence.risk }
    }

    let groups: [Group]
    let recommendations: [CleanupRecommendation]

    /// Kept for callers that construct reports directly in tests or small tools.
    init(matches: [(CleanupCategory, FileNode)]) {
        self.init(recommendations: matches.map {
            CleanupRecommendation(node: $0.1, category: $0.0)
        })
    }

    init(recommendations: [CleanupRecommendation]) {
        self.recommendations = recommendations
        var byCategory: [String: (CleanupCategory, [CleanupRecommendation])] = [:]
        for recommendation in recommendations where recommendation.physicalBytes > 0 {
            let key = "\(recommendation.category.id)::\(recommendation.risk.rawValue)"
            byCategory[key, default: (recommendation.category, [])]
                .1.append(recommendation)
        }
        groups = byCategory.values
            .map { entry in
                Group(category: entry.0,
                      recommendations: entry.1.sorted { $0.physicalBytes > $1.physicalBytes })
            }
            .sorted {
                if $0.risk != $1.risk {
                    return Self.riskOrder($0.risk) < Self.riskOrder($1.risk)
                }
                return $0.totalBytes > $1.totalBytes
            }
    }

    private static func riskOrder(_ risk: CleanupRisk) -> Int {
        switch risk {
        case .safe: return 0
        case .review: return 1
        case .protected: return 2
        }
    }

    var safeGroups: [Group] { groups.filter { $0.risk == .safe } }
    var reviewGroups: [Group] { groups.filter { $0.risk == .review } }
    var protectedGroups: [Group] { groups.filter { $0.risk == .protected } }
    var safeNodes: [FileNode] { safeGroups.flatMap(\.nodes) }
    var safeTotalBytes: Int64 { safeGroups.reduce(0) { $0 + $1.totalBytes } }
    var isEmpty: Bool { groups.isEmpty }

    var rankedRecommendations: [CleanupRecommendation] {
        recommendations.sorted {
            if $0.risk != $1.risk { return Self.riskOrder($0.risk) < Self.riskOrder($1.risk) }
            return $0.physicalBytes > $1.physicalBytes
        }
    }
}

// MARK: - Measurement and plan

struct RescueMeasurement: Codable, Equatable, Sendable {
    let volumePath: String
    let totalBytes: Int64?
    let availableBytes: Int64?
    let freeBytes: Int64?
    let logicalBytes: Int64
    let physicalBytes: Int64
    let measuredAt: Date

    var primaryBytes: Int64? { availableBytes ?? freeBytes }

    var primarySource: String {
        if availableBytes != nil { return "macOS available capacity" }
        if freeBytes != nil { return "macOS free capacity" }
        return "No volume capacity value"
    }

    static func capture(volumeURL: URL, root: FileNode, date: Date = Date()) -> RescueMeasurement {
        let values = volumeValues(for: volumeURL)
        return RescueMeasurement(
            volumePath: volumeURL.standardizedFileURL.path,
            totalBytes: values?.volumeTotalCapacity.map(Int64.init),
            availableBytes: values?.volumeAvailableCapacityForImportantUsage.map(Int64.init),
            freeBytes: values?.volumeAvailableCapacity.map(Int64.init),
            logicalBytes: logicalBytes(of: root),
            physicalBytes: physicalBytes(of: root),
            measuredAt: date
        )
    }

    /// Capacity-only sample for per-item verification. Tree totals are kept out
    /// of this hot path; the final result still stores a full before/after sample.
    static func captureCapacity(volumeURL: URL, date: Date = Date()) -> RescueMeasurement {
        let values = volumeValues(for: volumeURL)
        return RescueMeasurement(
            volumePath: volumeURL.standardizedFileURL.path,
            totalBytes: values?.volumeTotalCapacity.map(Int64.init),
            availableBytes: values?.volumeAvailableCapacityForImportantUsage.map(Int64.init),
            freeBytes: values?.volumeAvailableCapacity.map(Int64.init),
            logicalBytes: 0,
            physicalBytes: 0,
            measuredAt: date
        )
    }

    private static func volumeValues(for url: URL) -> URLResourceValues? {
        try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
    }

    private static func logicalBytes(of root: FileNode) -> Int64 {
        var total: Int64 = 0
        var stack = [root]
        while let node = stack.popLast() {
            if node.kind == .cloudOnlyStorage {
                total += node.logicalSize ?? 0
                continue
            }
            guard !node.isSynthetic else { continue }
            if node.isDirectory {
                stack.append(contentsOf: node.children)
            } else {
                total += node.logicalSize ?? node.physicalSize
            }
        }
        return total
    }

    private static func physicalBytes(of root: FileNode) -> Int64 {
        var total: Int64 = 0
        var stack = [root]
        while let node = stack.popLast() {
            guard !node.isSynthetic else { continue }
            if node.isDirectory {
                stack.append(contentsOf: node.children)
            } else {
                total += node.physicalSize
            }
        }
        return total
    }
}

struct RescueCoverage: Codable, Equatable, Sendable {
    enum State: String, Codable, Hashable, Sendable {
        case complete
        case partial
        case blocked
    }

    let state: State
    let notes: [String]

    static func inspect(root: FileNode, sourceIsReadable: Bool) -> RescueCoverage {
        var notes = root.scanCoverageGaps.map { "Could not inspect \($0)." }
        guard sourceIsReadable else {
            notes.insert("The source could not be read. No cleanup candidate is trusted.", at: 0)
            return RescueCoverage(state: .blocked,
                                  notes: notes)
        }

        var stack = [root]
        while let node = stack.popLast() {
            switch node.kind {
            case .hiddenSpace:
                notes.append("Some space is outside the file scan, such as snapshots or protected data.")
            case .cloudOnlyStorage:
                notes.append("Some provider items are online-only or were not opened during the scan.")
            case .crossVolume:
                notes.append("A mounted volume is shown as a separate boundary.")
            default:
                stack.append(contentsOf: node.children)
            }
        }
        let uniqueNotes = Array(Set(notes)).sorted()
        let visibleNotes = Array(uniqueNotes.prefix(8))
            + (uniqueNotes.count > 8 ? ["\(uniqueNotes.count - 8) more coverage gaps are held."] : [])
        return RescueCoverage(state: uniqueNotes.isEmpty ? .complete : .partial,
                              notes: visibleNotes)
    }

    var title: String {
        switch state {
        case .complete: return "Coverage complete"
        case .partial: return "Coverage is partial"
        case .blocked: return "Coverage blocked"
        }
    }
}

struct RescuePlan: Sendable {
    let sourcePath: String
    let generatedAt: Date
    let measurement: RescueMeasurement
    let coverage: RescueCoverage
    let recommendations: [CleanupRecommendation]
    let goal: RescueGoal
    let requiredSpace: Int64?
    let workingSpaceBuffer: Int64

    init(sourceURL: URL, report: CleanupReport, measurement: RescueMeasurement,
         coverage: RescueCoverage, goal: RescueGoal = .normalWork,
         requiredSpace: Int64? = nil) {
        self.sourcePath = sourceURL.standardizedFileURL.path
        self.generatedAt = measurement.measuredAt
        self.measurement = measurement
        self.coverage = coverage
        self.recommendations = report.rankedRecommendations
        self.goal = goal
        self.requiredSpace = requiredSpace
        self.workingSpaceBuffer = goal.defaultBuffer
    }

    var safeRecommendations: [CleanupRecommendation] {
        recommendations.filter { $0.risk == .safe }
    }

    var reviewRecommendations: [CleanupRecommendation] {
        recommendations.filter { $0.risk == .review }
    }

    var protectedRecommendations: [CleanupRecommendation] {
        recommendations.filter { $0.risk == .protected }
    }

    var targetSpace: Int64? {
        guard let requiredSpace, requiredSpace >= 0,
              requiredSpace <= Int64.max - workingSpaceBuffer else { return nil }
        return requiredSpace + workingSpaceBuffer
    }

    func changingGoal(to goal: RescueGoal, requiredSpace: Int64?) -> RescuePlan {
        RescuePlan(sourcePath: sourcePath, generatedAt: generatedAt, measurement: measurement,
                   coverage: coverage, recommendations: recommendations, goal: goal,
                   requiredSpace: requiredSpace)
    }

    private init(sourcePath: String, generatedAt: Date, measurement: RescueMeasurement,
                 coverage: RescueCoverage, recommendations: [CleanupRecommendation],
                 goal: RescueGoal, requiredSpace: Int64?) {
        self.sourcePath = sourcePath
        self.generatedAt = generatedAt
        self.measurement = measurement
        self.coverage = coverage
        self.recommendations = recommendations
        self.goal = goal
        self.requiredSpace = requiredSpace
        self.workingSpaceBuffer = goal.defaultBuffer
    }
}

/// The result vocabulary keeps a successful Trash move separate from verified
/// volume space. It is pure, so it can be tested without touching real files.
struct RescueVerification: Codable, Equatable, Sendable {
    let requestedBytes: Int64?
    let movedBytes: Int64
    let movedPaths: [String]?
    let failedBytes: Int64
    let failedPaths: [String]
    let heldBytes: Int64?
    let heldPaths: [String]?
    let measurementMismatchPaths: [String]?
    let before: RescueMeasurement?
    let after: RescueMeasurement?

    var verifiedReclaimedBytes: Int64? {
        guard let before = before?.primaryBytes, let after = after?.primaryBytes else { return nil }
        return max(0, after - before)
    }

    var targetReached: Bool {
        guard let requestedBytes, let available = after?.primaryBytes else { return false }
        return available >= requestedBytes
    }

    var hasMeasurementMismatch: Bool {
        if let measurementMismatchPaths, !measurementMismatchPaths.isEmpty { return true }
        guard let verifiedReclaimedBytes else { return movedBytes > 0 }
        return movedBytes != verifiedReclaimedBytes
    }

    var status: String {
        if failedBytes > 0 { return "Some items failed" }
        if movedBytes == 0, (heldBytes ?? 0) > 0 {
            return "Nothing moved; items held for review"
        }
        if hasMeasurementMismatch { return "Moved, but reclaimed space is not proven" }
        if after?.primaryBytes == nil {
            return requestedBytes != nil ? "Target could not be verified" : "Usable space change could not be verified"
        }
        if before?.primaryBytes == nil { return "Usable space change could not be verified" }
        if requestedBytes != nil && !targetReached { return "Target not reached" }
        return "Verified after measurement"
    }
}

// MARK: - Local rescue case

struct SavedRescueCase: Codable, Equatable, Sendable {
    let id: UUID
    let sourcePath: String
    let goal: RescueGoal
    let requiredSpace: Int64?
    let candidateIDs: [String]
    /// Scan identities are saved with the selection so a remounted or replaced
    /// path cannot look like the same candidate after a reopen.
    let candidateIdentities: [String: ScanIdentity]?
    let ruleVersion: String
    let savedAt: Date
    let phase: RescuePhase
    let measurement: RescueMeasurement?
    let coverage: RescueCoverage?
    let verification: RescueVerification?
    let errorMessage: String?
}

enum RescueCaseStore {
    private static let key = "tessera.rescue.case"

    static func load(defaults: UserDefaults = .standard) throws -> SavedRescueCase? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(SavedRescueCase.self, from: data)
    }

    static func save(_ rescueCase: SavedRescueCase, defaults: UserDefaults = .standard) throws {
        let data = try JSONEncoder().encode(rescueCase)
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
