import Foundation

/// A node in the on-disk file tree.
/// `size` is the on-disk allocated size (512-byte blocks × 512), aggregated for directories.
final class FileNode: Identifiable, @unchecked Sendable {

    /// What this node represents.
    enum Kind: Sendable {
        case regular
        /// A directory the Finder presents as a single file (.app, .framework, …).
        case package
        /// Synthetic node representing space the scan could not see
        /// (APFS snapshots, purgeable space, protected files). Not deletable.
        case hiddenSpace
        /// Synthetic aggregation node ("Other") used by the chart. Not deletable.
        case aggregate
        /// A cloud-provider folder (iCloud Drive, CloudStorage) left unscanned:
        /// its contents are online-only (dataless), occupy ~0 local disk, and each
        /// directory costs a slow first-touch provider enumeration. Treated as a
        /// boundary so scans stay fast. Not deletable.
        case cloudOnlyStorage
    }

    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let kind: Kind
    /// Allocated on-disk size in bytes. For directories this is the recursive total.
    private(set) var size: Int64
    private(set) var children: [FileNode]
    weak var parent: FileNode?

    init(url: URL, name: String, isDirectory: Bool, size: Int64,
         kind: Kind = .regular, children: [FileNode] = []) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.kind = kind
        self.size = size
        self.children = children
    }

    /// True for synthetic nodes that must never be trashed or revealed in Finder.
    var isSynthetic: Bool { kind == .hiddenSpace || kind == .aggregate || kind == .cloudOnlyStorage }

    /// Children sorted largest-first.
    var sortedChildren: [FileNode] { children.sorted { $0.size > $1.size } }

    /// Set children. Does not aggregate sizes — call `recomputeDirectorySizes()`
    /// on the root once the whole tree is assembled.
    func setChildren(_ newChildren: [FileNode]) {
        children = newChildren
        for child in newChildren { child.parent = self }
    }

    /// Used by the scanner to zero out duplicate hard links after the fact.
    func overrideSize(_ newSize: Int64) {
        size = newSize
    }

    /// Recompute aggregated sizes for every directory in the subtree, iteratively
    /// (children before parents) so deep trees cannot overflow the stack.
    func recomputeDirectorySizes() {
        var order: [FileNode] = []
        var stack: [FileNode] = [self]
        while let node = stack.popLast() {
            if node.isDirectory {
                order.append(node)
                stack.append(contentsOf: node.children)
            }
        }
        // Reverse pre-order ⇒ every child is visited before its parent.
        for node in order.reversed() {
            node.size = node.children.reduce(0) { $0 + $1.size }
        }
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
