import Foundation

enum DeletionPreflight: Equatable, Sendable {
    case ready
    case synthetic
    case missingIdentity
    case missing
    case unreadable
    case identityChanged
    case protected
    case incompleteScan
    case permissionDenied

    var message: String {
        switch self {
        case .ready: return "Ready"
        case .synthetic: return "This is scan metadata, not a file."
        case .missingIdentity: return "This item has no scan identity. Scan it again before moving it."
        case .missing: return "The path no longer exists."
        case .unreadable: return "The path could not be read. Check its permissions and scan again."
        case .identityChanged: return "The path changed after the scan. Scan it again before moving it."
        case .protected: return "This owner-managed path is protected. Use its owner app instead."
        case .incompleteScan: return "The scan has coverage gaps. Scan this source again before moving the item."
        case .permissionDenied: return "The current permissions do not allow this item to move."
        }
    }
}

/// Removes files from disk, either recoverably (to the Trash) or permanently.
///
/// `trash(_:)` is the primary, recoverable path: items move to the Finder Trash
/// and can be restored, but they keep occupying the volume until the Trash is
/// emptied. `delete(_:)` reclaims space *now* but is irreversible, so its call
/// sites must confirm with the user first. Both mirror the same return shape so
/// callers can prune only what actually went away.
enum DeletionService {
    private struct PreflightError: LocalizedError {
        let result: DeletionPreflight
        var errorDescription: String? { result.message }
    }

    struct DeletionError: Error, LocalizedError {
        let url: URL
        let underlying: Error
        var errorDescription: String? {
            "Could not remove \"\(url.lastPathComponent)\": \(underlying.localizedDescription)"
        }
    }

    struct PreparedRemoval: Sendable {
        let url: URL
        let identity: ScanIdentity?
        let check: DeletionPreflight
    }

    static func prepare(_ node: FileNode) -> PreparedRemoval {
        PreparedRemoval(url: node.url, identity: node.scanIdentity, check: preflight(node))
    }

    /// The immutable target crosses back from validation before the final action.
    /// Callers can check owner state between these two steps.
    static func perform(_ target: PreparedRemoval, permanently: Bool) -> DeletionError? {
        guard target.check == .ready else {
            return DeletionError(url: target.url, underlying: PreflightError(result: target.check))
        }
        guard let expected = target.identity,
              let current = ScanIdentity.current(at: target.url), expected.matches(current) else {
            return DeletionError(url: target.url, underlying: PreflightError(result: .identityChanged))
        }
        do {
            if permanently { try FileManager.default.removeItem(at: target.url) }
            else { try FileManager.default.trashItem(at: target.url, resultingItemURL: nil) }
            return nil
        } catch {
            return DeletionError(url: target.url, underlying: error)
        }
    }

    @discardableResult
    static func trash(_ nodes: [FileNode]) throws -> [DeletionError] {
        nodes.compactMap { perform(prepare($0), permanently: false) }
    }

    @discardableResult
    static func delete(_ nodes: [FileNode]) throws -> [DeletionError] {
        nodes.compactMap { perform(prepare($0), permanently: true) }
    }

    static func preflight(_ node: FileNode) -> DeletionPreflight {
        guard !node.isSynthetic else { return .synthetic }
        guard let identity = node.scanIdentity else { return .missingIdentity }
        guard identity.hasStableObjectIdentifier else { return .missingIdentity }
        let url = node.url.standardizedFileURL
        guard CleanupClassifier.protectedCategory(for: url.path) == nil,
              !CleanupClassifier.hasProtectedDescendant(node) else { return .protected }
        guard !CleanupClassifier.hasOpaqueDescendant(node) else { return .incompleteScan }
        var ancestor: FileNode? = node
        while let current = ancestor {
            guard !current.scanCoverageGaps.contains(where: { gap in
                pathsOverlap(gap, url.path)
            }) else { return .incompleteScan }
            ancestor = current.parent
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let current = ScanIdentity.current(at: url) else { return .unreadable }
        guard identity.matches(current) else { return .identityChanged }
        guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) else {
            return .permissionDenied
        }
        if node.isDirectory, let issue = inspectLiveDescendants(at: url, device: identity.device) { return issue }
        return .ready
    }

    private static func pathsOverlap(_ first: String, _ second: String) -> Bool {
        first == second || first.hasPrefix(second == "/" ? "/" : second + "/")
            || second.hasPrefix(first == "/" ? "/" : first + "/")
    }

    /// Recheck actual descendants, including data created below an unchanged
    /// ancestor since scanning. Never follow symlinks or enter another device.
    private static func inspectLiveDescendants(at url: URL, device: UInt32?) -> DeletionPreflight? {
        let scratch = BulkScratch()
        var stack = [url.path]
        let deadline = ContinuousClock.now + .seconds(30)
        while let path = stack.popLast() {
            guard ContinuousClock.now < deadline else { return .incompleteScan }
            var stat = Darwin.stat()
            guard Darwin.lstat(path, &stat) == 0 else { return .unreadable }
            guard stat.st_mode & S_IFMT == S_IFDIR else { return .identityChanged }
            if let device, UInt32(bitPattern: stat.st_dev) != device { return .incompleteScan }
            guard let listing = BulkDirScanner.workerListing(atPath: path, scratch: scratch),
                  listing.unreadablePaths.isEmpty else { return .incompleteScan }
            for entry in listing.entries {
                let child = path == "/" ? "/" + entry.name : path + "/" + entry.name
                if CleanupClassifier.protectedCategory(atNormalizedPath: child.lowercased()) != nil {
                    return .protected
                }
                if entry.isDataless { return .incompleteScan }
                if entry.type == .directory { stack.append(child) }
            }
        }
        return nil
    }
}
