import Foundation

/// The small identity record captured during a scan. A path is only a location;
/// the volume, resource, type, and change metadata make it possible to reject a
/// stale result before an action uses it.
struct ScanIdentity: Codable, Equatable, Sendable {
    enum ResourceType: String, Codable, Hashable, Sendable {
        case file
        case directory
        case package
        case unknown

        var isDirectory: Bool {
            self == .directory || self == .package
        }
    }

    /// Present for roots and hand-built records. Scanned children derive their
    /// location from the FileNode parent chain to avoid storing a full path per
    /// entry in a potentially million-node tree.
    let path: String?
    let volumeIdentifier: String?
    let resourceIdentifier: String?
    let device: UInt32?
    let inode: UInt64?
    let resourceType: ResourceType
    let logicalSize: Int64?
    let allocatedSize: Int64?
    let modificationTime: Int64?

    /// A path-only record is not enough to authorize a filesystem action.
    var hasStableObjectIdentifier: Bool {
        resourceType != .unknown
            && (volumeIdentifier != nil || device != nil)
            && (resourceIdentifier != nil || (device != nil && inode != nil))
    }

    init(path: String? = nil,
         volumeIdentifier: String? = nil,
         resourceIdentifier: String? = nil,
         device: UInt32? = nil,
         inode: UInt64? = nil,
         resourceType: ResourceType = .unknown,
         logicalSize: Int64? = nil,
         allocatedSize: Int64? = nil,
         modificationTime: Int64? = nil) {
        self.path = path.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        self.volumeIdentifier = volumeIdentifier
        self.resourceIdentifier = resourceIdentifier
        self.device = device
        self.inode = inode
        self.resourceType = resourceType
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.modificationTime = modificationTime
    }

    /// Capture the current object without following a symlink.
    static func current(at url: URL) -> ScanIdentity? {
        let path = url.standardizedFileURL.path
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType else { return nil }

        let isDirectory = type == .typeDirectory
        let resourceType: ResourceType = isDirectory
            ? (BulkDirScanner.isPackageName(path) ? .package : .directory)
            : .file
        let values = try? url.resourceValues(forKeys: [
            .fileResourceIdentifierKey,
            .volumeIdentifierKey,
            .fileSizeKey,
            .fileAllocatedSizeKey,
            .contentModificationDateKey,
        ])
        let modificationTime = values?.contentModificationDate.map {
            Int64(($0.timeIntervalSince1970 * 1_000_000_000).rounded())
        }
        let fileID = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        let device = (attributes[.systemNumber] as? NSNumber)?.uint32Value
        return ScanIdentity(
            path: path,
            volumeIdentifier: values?.volumeIdentifier.map { String(describing: $0) },
            resourceIdentifier: values?.fileResourceIdentifier.map { String(describing: $0) },
            device: device,
            inode: fileID,
            resourceType: resourceType,
            logicalSize: isDirectory ? nil : values?.fileSize.map(Int64.init),
            allocatedSize: values?.fileAllocatedSize.map(Int64.init),
            modificationTime: modificationTime
        )
    }

    /// Identity match used at the last safe step. Directory size may change as
    /// children change, so directory checks rely on identity, type, and mtime.
    func matches(_ current: ScanIdentity) -> Bool {
        if let path {
            guard let currentPath = current.path, path == currentPath else { return false }
        }
        guard resourceType == current.resourceType else { return false }
        if let volumeIdentifier, current.volumeIdentifier != volumeIdentifier { return false }
        if let resourceIdentifier, current.resourceIdentifier != resourceIdentifier { return false }
        if let device, current.device != device { return false }
        if let inode, current.inode != inode { return false }
        // Foundation exposes dates through a Double, while the scanner gets the
        // filesystem nanoseconds directly. Allow the conversion noise, but still
        // reject a real mtime change.
        if let modificationTime {
            guard let currentTime = current.modificationTime,
                  abs(modificationTime - currentTime) <= 1_000_000 else { return false }
        }
        if !resourceType.isDirectory,
           let logicalSize {
            guard current.logicalSize == logicalSize else { return false }
        }
        if !resourceType.isDirectory,
           let allocatedSize {
            guard current.allocatedSize == allocatedSize else { return false }
        }
        return true
    }
}

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
    /// Identity captured at scan time. Hand-built presentation fixtures may leave
    /// this nil; action paths must then fail closed.
    private(set) var scanIdentity: ScanIdentity?
    /// Directories the scanner could not enumerate. Stored on the root so a
    /// partial scan remains visible without inventing a zero-byte file node.
    private(set) var scanCoverageGaps: [String] = []
    /// Logical file size. Hard-linked duplicates are set to zero when their
    /// allocated size is deduplicated from the chart.
    private(set) var logicalSize: Int64?

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
    init(name: String, isDirectory: Bool, size: Int64, kind: Kind = .regular, modTime: Int64 = 0,
         identity: ScanIdentity? = nil) {
        self.name = name
        self.isDirectory = isDirectory
        self.kind = kind
        self.size = size
        self.children = []
        self.explicitURL = nil
        self.modTime = modTime
        self.scanIdentity = identity
        self.logicalSize = identity?.logicalSize
    }

    /// Initializer for nodes that own an explicit location: the scan root and
    /// synthetic nodes (and the test fixtures). Rare, so its URL cost is
    /// irrelevant.
    init(url: URL, name: String, isDirectory: Bool, size: Int64,
         kind: Kind = .regular, children: [FileNode] = [], modTime: Int64 = 0,
         identity: ScanIdentity? = nil) {
        self.explicitURL = url
        self.name = name
        self.isDirectory = isDirectory
        self.kind = kind
        self.size = size
        self.children = children
        self.modTime = modTime
        self.scanIdentity = identity
        self.logicalSize = identity?.logicalSize
        for child in children { child.parent = self }
    }

    /// True for synthetic nodes that must never be trashed or revealed in Finder.
    var isSynthetic: Bool { kind == .hiddenSpace || kind == .aggregate || kind == .cloudOnlyStorage || kind == .crossVolume }

    /// Children sorted largest-first.
    var sortedChildren: [FileNode] { children.sorted { $0.size > $1.size } }

    /// Allocated size shown by the scan. Directory sizes are aggregated from
    /// children and are therefore not taken from the identity record.
    var physicalSize: Int64 { size }

    /// Set children. Does not aggregate sizes — call `recomputeDirectorySizes()`
    /// on the root once the whole tree is assembled.
    func setChildren(_ newChildren: [FileNode]) {
        children = newChildren
        for child in newChildren { child.parent = self }
    }

    func addScanCoverageGap(_ path: String) {
        scanCoverageGaps.append(URL(fileURLWithPath: path).standardizedFileURL.path)
    }

    func setScanCoverageGaps(_ paths: [String]) {
        var seen = Set<String>()
        scanCoverageGaps = paths.compactMap { path in
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            return seen.insert(normalized).inserted ? normalized : nil
        }
    }

    /// Used by the scanner to zero out duplicate hard links after the fact.
    func overrideSize(_ newSize: Int64) {
        size = newSize
        if !isDirectory && newSize == 0 { logicalSize = 0 }
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
