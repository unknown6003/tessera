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

    /// Validate and move scanned nodes one by one. A stale, missing, synthetic,
    /// or unreadable node is reported as a failed item and is never passed to
    /// FileManager. This is the last-step identity gate. The caller receives
    /// all failures, including an all-failed batch, so it can preserve a result.
    @discardableResult
    static func trash(_ nodes: [FileNode]) throws -> [DeletionError] {
        try execute(nodes) { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    }

    /// Permanent deletion has the same identity gate as the recoverable path.
    /// The caller still owns the separate explicit confirmation for this action.
    @discardableResult
    static func delete(_ nodes: [FileNode]) throws -> [DeletionError] {
        try execute(nodes) { try FileManager.default.removeItem(at: $0) }
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
            guard current.scanCoverageGaps.isEmpty else { return .incompleteScan }
            ancestor = current.parent
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let current = ScanIdentity.current(at: url) else { return .unreadable }
        guard identity.matches(current) else { return .identityChanged }
        guard FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) else {
            return .permissionDenied
        }
        return .ready
    }

    private static func execute(_ nodes: [FileNode], operation: (URL) throws -> Void) throws -> [DeletionError] {
        var failures: [DeletionError] = []
        for node in nodes {
            let url = node.url
            let check = preflight(node)
            guard check == .ready else {
                failures.append(DeletionError(url: url, underlying: PreflightError(result: check)))
                continue
            }
            // FileManager's Trash API is path-based. Keep the identity check
            // immediately adjacent to the operation; a descriptor-backed Trash
            // API would be needed to remove the remaining OS-level TOCTOU window.
            // ponytail: keep this path API until macOS exposes descriptor-backed Trash.
            do {
                try operation(url)
            } catch {
                failures.append(DeletionError(url: url, underlying: error))
            }
        }
        return failures
    }
}
