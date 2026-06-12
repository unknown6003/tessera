import Foundation

// MARK: - Progress

struct ScanProgress: Sendable {
    var filesScanned: Int
    var bytesFound: Int64
    /// Non-zero when scanning a whole volume; zero = indeterminate (folder subtree).
    var totalBytes: Int64
    var currentPath: String

    /// 0…1 fraction of completion, or nil when the denominator is unknown.
    var fraction: Double? {
        guard totalBytes > 0 else { return nil }
        return min(1.0, Double(bytesFound) / Double(totalBytes))
    }
}

// MARK: - Internal per-directory result

private struct DirResult {
    let url: URL
    let fileChildren: [FileNode]
    let subdirURLs: [URL]
}

// MARK: - FileScanner

struct FileScanner: Sendable {

    // MARK: Public API

    static func scan(
        url: URL,
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> FileNode {
        let totalBytes = volumeUsedBytes(for: url)
        return try await Task.detached(priority: .userInitiated) {
            scanSync(rootURL: url, totalBytes: totalBytes, onProgress: onProgress)
        }.value
    }

    // MARK: Single-threaded BFS scan

    private static func scanSync(
        rootURL: URL,
        totalBytes: Int64,
        onProgress: @Sendable (ScanProgress) -> Void
    ) -> FileNode {
        var queue: [URL] = [rootURL]
        var results: [String: DirResult] = [:]
        var seenInodes = Set<UInt64>()
        var progress = ScanProgress(
            filesScanned: 0, bytesFound: 0,
            totalBytes: totalBytes, currentPath: rootURL.path
        )
        var dirCount = 0

        while !queue.isEmpty {
            let dirURL = queue.removeFirst()
            let entries = BulkDirScanner.entries(in: dirURL)
            var fileChildren: [FileNode] = []
            var subdirURLs: [URL] = []

            for entry in entries {
                switch entry.type {
                case .symlink, .other:
                    continue
                case .directory:
                    subdirURLs.append(dirURL.appendingPathComponent(entry.name, isDirectory: true))
                case .file:
                    var size = entry.allocatedSize
                    if entry.inode > 0 {
                        if seenInodes.contains(entry.inode) {
                            size = 0
                        } else {
                            seenInodes.insert(entry.inode)
                        }
                    }
                    let childURL = dirURL.appendingPathComponent(entry.name)
                    fileChildren.append(FileNode(url: childURL, name: entry.name, isDirectory: false, size: size))
                    progress.filesScanned += 1
                    progress.bytesFound += size
                }
            }

            queue.append(contentsOf: subdirURLs)
            results[dirURL.path] = DirResult(url: dirURL, fileChildren: fileChildren, subdirURLs: subdirURLs)
            progress.currentPath = dirURL.path
            dirCount += 1

            if dirCount % 200 == 0 {
                onProgress(progress)
            }
        }

        onProgress(progress)
        return assembleTree(rootURL: rootURL, results: results)
    }

    // MARK: Tree assembly (post-order DFS — children sized before parent)

    private static func assembleTree(rootURL: URL, results: [String: DirResult]) -> FileNode {
        func assemble(url: URL, name: String, parent: FileNode?) -> FileNode {
            guard let result = results[url.path] else {
                return FileNode(url: url, name: name, isDirectory: false, size: 0)
            }

            let node = FileNode(url: url, name: name, isDirectory: true, size: 0)
            node.parent = parent

            var children: [FileNode] = result.fileChildren
            for childURL in result.subdirURLs {
                let childNode = assemble(url: childURL, name: childURL.lastPathComponent, parent: node)
                children.append(childNode)
            }
            for child in children { child.parent = node }
            node.setChildren(children)

            return node
        }

        return assemble(url: rootURL, name: rootURL.lastPathComponent, parent: nil)
    }

    // MARK: Volume used bytes

    private static func volumeUsedBytes(for url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let vals = try? url.resourceValues(forKeys: keys),
              let total = vals.volumeTotalCapacity,
              let available = vals.volumeAvailableCapacity else { return 0 }
        return max(0, Int64(total) - Int64(available))
    }
}
