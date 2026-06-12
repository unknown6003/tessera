import Foundation

enum TrashService {
    struct TrashError: Error, LocalizedError {
        let url: URL
        let underlying: Error
        var errorDescription: String? {
            "Could not move \"\(url.lastPathComponent)\" to the Trash: \(underlying.localizedDescription)"
        }
    }

    /// Move all `urls` to the Trash. Returns the list of URLs that failed.
    @discardableResult
    static func trash(_ urls: [URL]) throws -> [TrashError] {
        var failures: [TrashError] = []
        for url in urls {
            do {
                var resultURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
            } catch {
                failures.append(TrashError(url: url, underlying: error))
            }
        }
        if failures.count == urls.count && !urls.isEmpty {
            throw failures.first!
        }
        return failures
    }
}
