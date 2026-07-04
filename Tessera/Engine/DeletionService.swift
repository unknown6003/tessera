import Foundation

/// Removes files from disk, either recoverably (to the Trash) or permanently.
///
/// `trash(_:)` is the primary, recoverable path: items move to the Finder Trash
/// and can be restored, but they keep occupying the volume until the Trash is
/// emptied. `delete(_:)` reclaims space *now* but is irreversible, so its call
/// sites must confirm with the user first. Both mirror the same return shape so
/// callers can prune only what actually went away.
enum DeletionService {
    struct DeletionError: Error, LocalizedError {
        let url: URL
        let underlying: Error
        var errorDescription: String? {
            "Could not remove \"\(url.lastPathComponent)\": \(underlying.localizedDescription)"
        }
    }

    /// Move all `urls` to the Trash (recoverable). Returns the list of URLs that
    /// failed so the caller can prune only what actually went away. Throws only
    /// when *every* move failed (and the set was non-empty), so a total failure
    /// surfaces as a single hard error.
    @discardableResult
    static func trash(_ urls: [URL]) throws -> [DeletionError] {
        var failures: [DeletionError] = []
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                failures.append(DeletionError(url: url, underlying: error))
            }
        }
        if failures.count == urls.count && !urls.isEmpty {
            throw failures.first!
        }
        return failures
    }

    /// Permanently delete all `urls`. Returns the list of URLs that failed so the
    /// caller can prune only what actually went away. Throws only when *every*
    /// deletion failed (and the set was non-empty), so a total failure surfaces
    /// as a single hard error.
    @discardableResult
    static func delete(_ urls: [URL]) throws -> [DeletionError] {
        var failures: [DeletionError] = []
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                failures.append(DeletionError(url: url, underlying: error))
            }
        }
        if failures.count == urls.count && !urls.isEmpty {
            throw failures.first!
        }
        return failures
    }
}
