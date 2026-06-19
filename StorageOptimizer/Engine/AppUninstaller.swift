import Foundation

// MARK: - App Uninstaller (on-device, conservative leftover association)
//
// Enumerates installed apps from /Applications and ~/Applications, then for each
// finds the support files macOS scatters across ~/Library and /Library — Caches,
// Application Support, Preferences, Containers, Group Containers, Logs, Saved
// Application State, HTTPStorages, WebKit, and LaunchAgents.
//
// Everything here runs entirely on-device; no file data leaves the Mac. The whole
// enumeration is `nonisolated` and meant to be driven from a detached task off the
// main actor (it does blocking filesystem I/O).
//
// SAFETY: the cardinal rule is "no false positives." A leftover is only associated
// when it matches by the app's bundle identifier (preferred) or by an EXACT folder
// /file name equal to the app's display name. We never substring-match, never match
// a generic name, and never reach inside a shared container. The user always
// reviews the staged set in the collector before anything is trashed.

/// A leftover support file/folder associated with an app, with its on-disk size.
struct AppLeftover: Identifiable, Sendable {
    let id = UUID()
    /// On-disk location of the leftover.
    let url: URL
    /// Allocated bytes the leftover occupies.
    let bytes: Int64
    /// Which support area it came from (Caches, Preferences, …) — for display.
    let category: String
    /// How it was matched — bundle id or exact name. Surfaced so the user can see
    /// why we believe it belongs to the app.
    let matchedBy: MatchReason

    enum MatchReason: String, Sendable {
        case bundleID = "Bundle ID"
        case exactName = "Exact name"
    }
}

/// An installed application bundle plus the leftover files associated with it.
struct InstalledApp: Identifiable, Sendable {
    let id = UUID()
    /// Display name (CFBundleDisplayName / CFBundleName, falling back to the file
    /// name without ".app").
    let name: String
    /// CFBundleIdentifier, when the Info.plist provides one (empty otherwise).
    let bundleID: String
    /// Location of the .app bundle.
    let appURL: URL
    /// Allocated bytes of the .app bundle itself.
    let appBytes: Int64
    /// Associated support files found across the standard Library locations.
    let leftovers: [AppLeftover]

    /// Bytes reclaimable by removing the bundle *and* all its leftovers.
    var totalBytes: Int64 { appBytes + leftovers.reduce(0) { $0 + $1.bytes } }
    /// Sum of just the leftover files.
    var leftoverBytes: Int64 { leftovers.reduce(0) { $0 + $1.bytes } }
    var leftoverCount: Int { leftovers.count }
}

enum AppUninstaller {

    // MARK: Discovery

    /// Enumerate installed apps and their leftovers. Blocking filesystem work —
    /// call from a detached task, never the main actor. Sorted largest-first by
    /// total reclaimable bytes.
    nonisolated static func scanInstalledApps() -> [InstalledApp] {
        let fm = FileManager.default
        let appDirs = applicationDirectories()
        var apps: [InstalledApp] = []

        for dir in appDirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]) else { continue }

            for appURL in entries where appURL.pathExtension == "app" {
                if let app = inspect(appURL: appURL) { apps.append(app) }
            }
        }
        return apps.sorted { $0.totalBytes > $1.totalBytes }
    }

    /// Top-level application directories we enumerate: /Applications and
    /// ~/Applications. (System apps under /System/Applications are SIP-protected
    /// and can't be removed, so they're intentionally excluded.)
    nonisolated static func applicationDirectories() -> [URL] {
        var dirs = [URL(fileURLWithPath: "/Applications", isDirectory: true)]
        let userApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        if FileManager.default.fileExists(atPath: userApps.path) { dirs.append(userApps) }
        return dirs
    }

    /// Read an app bundle's identity + size and gather its leftovers.
    nonisolated static func inspect(appURL: URL) -> InstalledApp? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: appURL.path, isDirectory: &isDir), isDir.boolValue else { return nil }

        let info = readInfoPlist(appURL: appURL)
        let bundleID = info.bundleID
        let name = info.displayName ?? appURL.deletingPathExtension().lastPathComponent
        let appBytes = directorySize(at: appURL)

        let leftovers = findLeftovers(bundleID: bundleID, appName: name, appURL: appURL)
        return InstalledApp(name: name, bundleID: bundleID, appURL: appURL,
                            appBytes: appBytes, leftovers: leftovers)
    }

    /// Pull CFBundleIdentifier + a display name from Contents/Info.plist.
    nonisolated static func readInfoPlist(appURL: URL) -> (bundleID: String, displayName: String?) {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any] else {
            return ("", nil)
        }
        let bundleID = (dict["CFBundleIdentifier"] as? String) ?? ""
        let display = (dict["CFBundleDisplayName"] as? String)
            ?? (dict["CFBundleName"] as? String)
        return (bundleID, display)
    }

    // MARK: Leftover association (the safety-critical part)

    /// The standard per-user and system-wide support locations an app's leftovers
    /// live in. The closure on each describes how to look inside it.
    private struct SupportLocation {
        let category: String
        let dir: URL
        /// How entries inside `dir` are matched. `.byNameOrBundleID` matches a
        /// folder named exactly the app name OR the bundle id. `.preferenceFile`
        /// matches `<bundleID>.plist` (and the `.lockfile` sibling cfprefsd makes).
        let mode: Mode
        enum Mode { case byNameOrBundleID, preferenceFile }
    }

    /// Build the list of locations to inspect, under both ~/Library and /Library.
    nonisolated static func supportLocations() -> [(category: String, dir: URL, mode: Int)] {
        // `mode`: 0 = name-or-bundleID folder, 1 = preference file. (Int so the
        // tuple stays trivially Sendable; mapped back internally.)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let userLib = home.appendingPathComponent("Library", isDirectory: true)
        let sysLib = URL(fileURLWithPath: "/Library", isDirectory: true)

        var locs: [(String, URL, Int)] = []
        func add(_ category: String, _ sub: String, _ mode: Int) {
            locs.append((category, userLib.appendingPathComponent(sub, isDirectory: true), mode))
            locs.append((category, sysLib.appendingPathComponent(sub, isDirectory: true), mode))
        }

        add("Caches", "Caches", 0)
        add("Application Support", "Application Support", 0)
        add("Preferences", "Preferences", 1)
        add("Containers", "Containers", 0)
        add("Group Containers", "Group Containers", 0)
        add("Logs", "Logs", 0)
        add("Saved Application State", "Saved Application State", 0)
        add("HTTPStorages", "HTTPStorages", 0)
        add("WebKit", "WebKit", 0)
        add("LaunchAgents", "LaunchAgents", 1)

        return locs
    }

    /// Find leftovers for a single app. Conservative by construction: an entry is
    /// associated ONLY when its name equals the bundle id, equals `<bundleID>.*`
    /// (a bundle-id-prefixed file/folder, e.g. `com.foo.Bar.savedState`), the
    /// preference file `<bundleID>.plist`, or — only when the bundle id is missing
    /// or as a name match — a folder whose name exactly equals the app name.
    ///
    /// `locations` defaults to the real `supportLocations()`; tests inject hermetic
    /// temp dirs so they never touch the user's real ~/Library.
    nonisolated static func findLeftovers(
        bundleID: String, appName: String, appURL: URL,
        locations: [(category: String, dir: URL, mode: Int)]? = nil
    ) -> [AppLeftover] {
        let fm = FileManager.default
        let trimmedID = bundleID.trimmingCharacters(in: .whitespaces)
        let hasBundleID = !trimmedID.isEmpty
        // Guard against pathological/generic app names that would over-match
        // (e.g. an app literally named "Logs" or "App"). Exact-name matching is
        // only used for names long enough to be specific.
        let nameMatchAllowed = appName.count >= 3 && !genericNames.contains(appName.lowercased())

        var results: [AppLeftover] = []
        // Dedup by resolved path — the same target can be reachable from multiple
        // criteria (bundle id and name) within one location.
        var seen = Set<String>()

        for loc in (locations ?? supportLocations()) {
            guard let entries = try? fm.contentsOfDirectory(
                at: loc.dir, includingPropertiesForKeys: nil,
                options: []) else { continue }

            for entry in entries {
                let entryName = entry.lastPathComponent
                guard let reason = matchReason(
                    entryName: entryName, bundleID: trimmedID, hasBundleID: hasBundleID,
                    appName: appName, nameMatchAllowed: nameMatchAllowed,
                    isPreferenceFile: loc.mode == 1) else { continue }

                let path = entry.standardizedFileURL.path
                // Never stage the app bundle itself via the leftover path.
                if path == appURL.standardizedFileURL.path { continue }
                if !seen.insert(path).inserted { continue }

                let bytes = directorySize(at: entry)
                guard bytes > 0 || fm.fileExists(atPath: entry.path) else { continue }
                results.append(AppLeftover(url: entry, bytes: bytes,
                                           category: loc.category, matchedBy: reason))
            }
        }
        return results.sorted { $0.bytes > $1.bytes }
    }

    /// The pure matching decision, factored out so it can be unit-tested without
    /// touching the filesystem. Returns the reason an entry belongs to the app, or
    /// nil if it doesn't qualify.
    nonisolated static func matchReason(entryName: String,
                                        bundleID: String,
                                        hasBundleID: Bool,
                                        appName: String,
                                        nameMatchAllowed: Bool,
                                        isPreferenceFile: Bool) -> AppLeftover.MatchReason? {
        if isPreferenceFile {
            // Preferences / LaunchAgents: only the bundle-id-named plist (and its
            // lockfile sibling). Exact-name matching is unsafe here because a
            // plist named "<App Name>.plist" is rare and ambiguous.
            guard hasBundleID else { return nil }
            if entryName == "\(bundleID).plist" { return .bundleID }
            if entryName == "\(bundleID).plist.lockfile" { return .bundleID }
            return nil
        }

        // Folder-style locations.
        if hasBundleID {
            // Exact bundle id, or a bundle-id-prefixed entry (the dot guards against
            // matching "com.foo.BarBaz" when the id is "com.foo.Bar").
            if entryName == bundleID { return .bundleID }
            if entryName.hasPrefix(bundleID + ".") { return .bundleID }
        }
        if nameMatchAllowed, entryName == appName { return .exactName }
        return nil
    }

    /// App/folder names too generic to safely match by name alone.
    nonisolated static let genericNames: Set<String> = [
        "app", "apps", "application", "applications", "logs", "log", "cache",
        "caches", "data", "support", "preferences", "containers", "temp", "tmp",
        "media", "files", "user", "users", "shared", "common", "default", "library",
    ]

    // MARK: - Orphaned leftovers (support files for removed apps)
    //
    // The inverse of leftover association: find support files whose owning bundle id
    // has NO currently-installed app. These are the residue removed apps leave behind
    // when the user deletes only the .app bundle. We are deliberately conservative —
    // an orphan is only reported when its folder/file name IS a confident reverse-DNS
    // bundle id (or a `<bundleID>.*` derivative) AND no installed app claims that id.
    // We never report exact-name folders (no bundle id ⇒ no confidence) and never
    // report Apple system bundles (com.apple.*), which the user can't safely remove.

    /// One orphaned support file/folder, with its derived bundle id and on-disk size.
    struct OrphanLeftover: Identifiable, Sendable {
        let id = UUID()
        let url: URL
        let bytes: Int64
        /// Which support area it came from (Caches, Containers, …) — for display.
        let category: String
        /// The reverse-DNS bundle id this entry's name resolves to.
        let bundleID: String
    }

    /// Orphans grouped by their owning (removed) bundle id, sized in aggregate.
    struct OrphanGroup: Identifiable, Sendable {
        let id = UUID()
        let bundleID: String
        let items: [OrphanLeftover]
        var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
        var itemCount: Int { items.count }
        /// A friendlier label: the last reverse-DNS label, capitalized (e.g.
        /// "com.acme.WidgetPro" → "WidgetPro"), falling back to the full id.
        var displayName: String {
            bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        }
    }

    /// Find support files left behind by apps that are no longer installed. Blocking
    /// filesystem work — call from a detached task, never the main actor. Groups are
    /// sorted largest-first by total reclaimable bytes.
    ///
    /// `installedBundleIDs` / `installedAppNames` and `locations` default to the live
    /// system; tests inject hermetic values so they never touch the real ~/Library.
    nonisolated static func orphanedLeftovers(
        installedBundleIDs: Set<String>? = nil,
        installedAppNames: Set<String>? = nil,
        locations: [(category: String, dir: URL, mode: Int)]? = nil
    ) -> [OrphanGroup] {
        let installedIDs: Set<String>
        if let injected = installedBundleIDs {
            installedIDs = injected
        } else {
            // Live discovery: read every installed bundle id (cheap — just plists).
            var ids = Set<String>()
            for dir in applicationDirectories() {
                guard let entries = try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]) else { continue }
                for appURL in entries where appURL.pathExtension == "app" {
                    let id = readInfoPlist(appURL: appURL).bundleID
                        .trimmingCharacters(in: .whitespaces)
                    if !id.isEmpty { ids.insert(id) }
                }
            }
            installedIDs = ids
        }

        let fm = FileManager.default
        var byID: [String: [OrphanLeftover]] = [:]
        var seen = Set<String>()

        for loc in (locations ?? supportLocations()) {
            // Preference plists are matched whole (the bundle id is the name minus
            // the .plist suffix); folder locations match the entry name directly.
            guard let entries = try? fm.contentsOfDirectory(
                at: loc.dir, includingPropertiesForKeys: nil, options: []) else { continue }

            for entry in entries {
                guard let id = orphanBundleID(
                    entryName: entry.lastPathComponent,
                    isPreferenceFile: loc.mode == 1,
                    installedBundleIDs: installedIDs) else { continue }

                let path = entry.standardizedFileURL.path
                if !seen.insert(path).inserted { continue }

                let bytes = directorySize(at: entry)
                guard bytes > 0 || fm.fileExists(atPath: entry.path) else { continue }
                byID[id, default: []].append(
                    OrphanLeftover(url: entry, bytes: bytes, category: loc.category, bundleID: id))
            }
        }

        return byID.map { id, items in
            OrphanGroup(bundleID: id, items: items.sorted { $0.bytes > $1.bytes })
        }
        .sorted { $0.totalBytes > $1.totalBytes }
    }

    /// The pure orphan decision, factored out for unit testing without touching the
    /// filesystem. Returns the bundle id an entry is an orphan of, or nil when the
    /// entry isn't a confident orphan (not bundle-id-shaped, an Apple system bundle,
    /// or still claimed by an installed app). Conservative by construction.
    nonisolated static func orphanBundleID(
        entryName: String,
        isPreferenceFile: Bool,
        installedBundleIDs: Set<String>
    ) -> String? {
        // Strip the preference suffixes so the remainder can be tested as a bundle id.
        var name = entryName
        if isPreferenceFile {
            if name.hasSuffix(".plist.lockfile") { name.removeLast(".plist.lockfile".count) }
            else if name.hasSuffix(".plist") { name.removeLast(".plist".count) }
            else { return nil }   // only bundle-id-named plists qualify
        }

        // Derive the candidate bundle id: either the whole name, or — for folder
        // entries like "com.foo.Bar.savedState" — the longest leading run of
        // reverse-DNS labels. We accept the entry only if SOME prefix is a valid id.
        guard let bundleID = leadingBundleID(in: name) else { return nil }

        // Never touch Apple system bundles — not safe to remove and not "leftovers".
        if bundleID == "com.apple" || bundleID.hasPrefix("com.apple.") { return nil }

        // Still installed? Not an orphan. Match the same dot-boundary semantics
        // leftover association uses: the derived id, an ancestor, or a descendant id
        // belonging to an installed app means the owner is present.
        for installed in installedBundleIDs {
            if installed == bundleID { return nil }
            if installed.hasPrefix(bundleID + ".") { return nil }
            if bundleID.hasPrefix(installed + ".") { return nil }
        }
        return bundleID
    }

    /// The canonical reverse-DNS bundle id at the start of `name`, or nil if `name`
    /// doesn't begin with one. The id is the FIRST three dot-separated labels (the
    /// near-universal `tld.org.App` shape), each a non-empty run of `[A-Za-z0-9-]`
    /// with at least one letter and not a generic word. Taking exactly three labels
    /// is deliberate: it canonicalizes both the bare bundle-id folder
    /// (`com.foo.Bar`) AND its derivatives (`com.foo.Bar.savedState`,
    /// `com.foo.Bar.binarycookies`) to the same owning id, so they group together —
    /// and there's no syntactic way to tell a deeper id apart from a suffix anyway.
    /// The "3 labels, each with a letter" shape is what makes this confident: random
    /// cache folders, UUIDs, and bare names never qualify.
    nonisolated static func leadingBundleID(in name: String) -> String? {
        let labels = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard labels.count >= 3 else { return nil }

        func isLabel(_ s: String) -> Bool {
            guard !s.isEmpty else { return false }
            var sawLetter = false
            for ch in s {
                if ch.isLetter { sawLetter = true; continue }
                if ch.isNumber || ch == "-" { continue }
                return false
            }
            return sawLetter
        }

        // The first three labels must all be valid reverse-DNS labels.
        let head = labels.prefix(3)
        guard head.allSatisfy(isLabel) else { return nil }

        let id = head.joined(separator: ".")
        // Reject ids that are entirely generic-word labels (e.g. "com.app.data").
        if head.allSatisfy({ genericNames.contains($0.lowercased()) }) { return nil }
        return id
    }

    // MARK: Size

    /// Allocated size of a file or directory subtree, summing `st_blocks * 512`
    /// (matching the scanner's notion of on-disk size). Symlinks are not followed.
    nonisolated static func directorySize(at url: URL) -> Int64 {
        var st = Darwin.stat()
        guard lstat(url.path, &st) == 0 else { return 0 }

        // Plain file (or symlink) — just its own allocation.
        if (st.st_mode & S_IFMT) != S_IFDIR {
            return Int64(st.st_blocks) * 512
        }

        var total: Int64 = Int64(st.st_blocks) * 512
        let fm = FileManager.default
        guard let en = fm.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [], errorHandler: { _, _ in true }) else { return total }

        while let child = en.nextObject() as? URL {
            var cst = Darwin.stat()
            if lstat(child.path, &cst) == 0 {
                total += Int64(cst.st_blocks) * 512
            }
        }
        return total
    }
}
