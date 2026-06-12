import Foundation

/// A node in the on-disk file tree.
/// `size` is the on-disk allocated size (512-byte blocks × 512), aggregated for directories.
final class FileNode: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    /// Allocated on-disk size in bytes. For directories this is the recursive total.
    private(set) var size: Int64
    private(set) var children: [FileNode]
    weak var parent: FileNode?

    init(url: URL, name: String, isDirectory: Bool, size: Int64, children: [FileNode] = []) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
    }

    /// Children sorted largest-first.
    var sortedChildren: [FileNode] { children.sorted { $0.size > $1.size } }

    /// Set children and recompute the aggregated directory size (called once by the scanner after tree assembly).
    func setChildren(_ newChildren: [FileNode]) {
        children = newChildren
        size = newChildren.reduce(0) { $0 + $1.size }
    }

    /// Remove a child node (after deletion). Propagates size reduction up the tree.
    func remove(_ node: FileNode) {
        let delta = node.size
        children.removeAll { $0.id == node.id }
        propagateSizeChange(-delta)
    }

    private func propagateSizeChange(_ delta: Int64) {
        size += delta
        parent?.propagateSizeChange(delta)
    }
}
