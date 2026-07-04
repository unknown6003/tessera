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
        /// A dataless (online-only) directory left unscanned: its contents are not
        /// materialized, occupy ~0 local disk, and descending would force a slow
        /// provider round-trip. Boundary node; not deletable.
        case cloudOnlyStorage
        /// A separate volume mounted *inside* the scanned tree (e.g. an Xcode
        /// Simulator runtime/device under /Library/Developer/CoreSimulator). The
        /// scanner can't descend across the device boundary, so its size is read
        /// from the mounted filesystem (statfs) and shown as a labeled boundary
        /// node — turning otherwise-invisible "hidden" space into something the
        /// user can see and reclaim with the right tool. Not file-deletable.
        case crossVolume
    }

    let name: String
    let isDirectory: Bool
    private(set) var kind: Kind
    /// Modification time in epoch NANOSECONDS (tv_sec·1e9 + tv_nsec); 0 when
    /// unavailable. Used by incremental re-scan to detect unchanged subtrees (exact
    /// equality) and by age-based cleanup filters (older-than comparisons).
    let modTime: Int64
    /// Allocated on-disk size in bytes. For directories this is the recursive total.
    private(set) var size: Int64
    private(set) var children: [FileNode]
    weak var parent: FileNode?

    /// Set only on nodes that carry an explicit location — the scan root and the
    /// synthetic nodes (Hidden Space, "Other", a cloud boundary's own root). For
    /// the millions of ordinary children it stays nil and the `url` is derived
    /// lazily from the parent chain, so a scan never pays CFURL construction per
    /// entry.
    private let explicitURL: URL?

    /// Identity for SwiftUI diffing and dedup. Uses the object's pointer rather
    /// than a per-node `UUID()`: stable for the node's lifetime and free to
    /// produce, which matters when one scan mints millions of nodes.
    var id: ObjectIdentifier { ObjectIdentifier(self) }

    /// File-system location, reconstructed on demand by walking to the nearest
    /// ancestor that owns an explicit URL. Only a handful of nodes are ever asked
    /// for this (selection, reveal in Finder, delete, inspector), so the cost is
    /// kept off the scan's hot path.
    var url: URL {
        if let explicitURL { return explicitURL }
        if let parent { return parent.url.appendingPathComponent(name, isDirectory: isDirectory) }
        return URL(fileURLWithPath: name)
    }

    /// Hot-path initializer for scanned children: stores no URL — the location is
    /// derived from the parent chain only when actually needed.
    init(name: String, isDirectory: Bool, size: Int64, kind: Kind = .regular, modTime: Int64 = 0) {
        self.name = name
        self.isDirectory = isDirectory
        self.kind = kind
        self.size = size
        self.children = []
        self.explicitURL = nil
        self.modTime = modTime
    }

    /// Initializer for nodes that own an explicit location: the scan root and
    /// synthetic nodes (and the test fixtures). Rare, so its URL cost is
    /// irrelevant.
    init(url: URL, name: String, isDirectory: Bool, size: Int64,
         kind: Kind = .regular, children: [FileNode] = [], modTime: Int64 = 0) {
        self.explicitURL = url
        self.name = name
        self.isDirectory = isDirectory
        self.kind = kind
        self.size = size
        self.children = children
        self.modTime = modTime
    }

    /// True for synthetic nodes that must never be trashed or revealed in Finder.
    var isSynthetic: Bool { kind == .hiddenSpace || kind == .aggregate || kind == .cloudOnlyStorage || kind == .crossVolume }

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

    /// Turn this node (an empty mount-point directory the scan couldn't descend)
    /// into a labeled cross-mounted-volume boundary with its measured size, taken
    /// from the mount table. Called once during finalization, before size
    /// re-aggregation, so the size propagates up into ancestor totals.
    func reclassifyAsCrossVolume(size newSize: Int64) {
        kind = .crossVolume
        size = newSize
        children = []
    }

    /// Recompute aggregated sizes for every directory in the subtree, iteratively
    /// (children before parents) so deep trees cannot overflow the stack.
    func recomputeDirectorySizes() {
        var order: [FileNode] = []
        var stack: [FileNode] = [self]
        while let node = stack.popLast() {
            // Cross-mounted volumes carry a fixed size from the mount table and have
            // no scanned children — treat them as size-bearing leaves so the sum
            // doesn't reset them to zero (their size still rolls up into ancestors).
            if node.isDirectory, node.kind != .crossVolume {
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
