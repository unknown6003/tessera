import Foundation

// MARK: - Progress

/// Progress derived from directories scanned vs. directories discovered.
/// Unlike a bytes-vs-volume-used model, this ratio is guaranteed to reach 1.0:
/// every discovered directory is eventually scanned, so the bar can never
/// plateau on unreachable bytes (snapshots, purgeable space, protected files).
struct ScanProgress: Sendable {
    var filesScanned: Int = 0
    var bytesFound: Int64 = 0
    var dirsScanned: Int = 0
    var dirsDiscovered: Int = 1
    var currentPath: String = ""
    /// The volume's used-bytes figure, when scanning a whole volume (0 otherwise).
    /// Used as the denominator for an honest, bytes-based progress fraction.
    var volumeUsedTotal: Int64 = 0
    /// Set on the final tick so the bar reads exactly 100% regardless of metric.
    var isComplete: Bool = false

    /// 0…1 fraction of completion, or nil while the estimate is still too noisy.
    var fraction: Double? {
        if isComplete { return 1.0 }

        // Whole-volume scan: report bytes found against the volume's used bytes.
        // This is what the user compares against ("550 GB of 900 GB"), and unlike
        // a directory-count ratio it can never race ahead of the data actually
        // discovered. Capped just under 1.0 until the final tick, because a little
        // used space is unreachable (snapshots, purgeable, protected files) and is
        // reconciled as "Hidden Space" at the end.
        if volumeUsedTotal > 0 {
            return min(0.99, Double(bytesFound) / Double(volumeUsedTotal))
        }

        // Folder scan: no known byte total, so fall back to directories scanned
        // vs. discovered (guaranteed to reach 1.0 — every dir is eventually seen).
        if dirsScanned >= dirsDiscovered && dirsScanned > 0 { return 1.0 }
        guard dirsDiscovered >= 16 else { return nil }
        return min(1.0, Double(dirsScanned) / Double(dirsDiscovered))
    }
}

// MARK: - FileScanner

/// Parallel breadth-first directory scanner.
///
/// Correctness properties:
///  - never crosses filesystem/mount boundaries (kills network-mount hangs),
///    except the root→data firmlink pair when scanning "/"
///  - skips `/Volumes`, `/System/Volumes`, `/dev`, `/Network` so the data volume
///    is not scanned twice through firmlinks
///  - counts each hard-linked file once (per-link-count, so the dedup set stays tiny)
///  - cooperatively cancellable at directory granularity
///  - adds a synthetic "hidden space" node for bytes the scan cannot see
struct FileScanner: Sendable {

    // MARK: Tuning

    private static let progressInterval: Duration = .milliseconds(80)
    private static let hiddenSpaceThreshold: Int64 = 1 << 30  // 1 GiB

    /// Absolute paths never descended into (unless they are the scan root itself).
    private static let skippedPaths: Set<String> = [
        "/Volumes",         // other mounted volumes (incl. network mounts that can block forever)
        "/System/Volumes",  // data volume already reachable through firmlinks; VM/Preboot are hidden space
        "/dev",
        "/Network",
    ]

    /// A cloud-provider container whose subtree is online-only (dataless) content:
    /// iCloud Drive ("~/Library/Mobile Documents") and third-party FileProviders
    /// ("~/Library/CloudStorage"). Descending is the single biggest scan-time sink —
    /// every directory inside forces a slow first-touch provider enumeration — while
    /// the files are dataless and occupy ~0 local disk. We stop AT the container and
    /// represent it as one `.cloudOnlyStorage` boundary node instead of crawling it.
    /// (When such a container is itself the explicit scan root, we still descend, so
    /// a user can deliberately inspect it.)
    private static func isCloudBoundary(_ path: String) -> Bool {
        path.hasSuffix("/Library/Mobile Documents") || path.hasSuffix("/Library/CloudStorage")
    }

    // MARK: Public API

    static func scan(
        url: URL,
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> FileNode {
        let rootPath = url.path
        let allowedDevices = Self.allowedDevices(forRoot: rootPath)
        let volumeUsed = volumeUsedBytes(for: url)
        let isVolumeRoot = (try? url.resourceValues(forKeys: [.isVolumeKey]))?.isVolume ?? (rootPath == "/")

        let rootName = url.lastPathComponent.isEmpty ? rootPath : url.lastPathComponent
        let rootNode = FileNode(url: url, name: rootName, isDirectory: true, size: 0)

        var progress = ScanProgress(currentPath: rootPath)
        // Only use the volume-bytes denominator for a true volume scan; for a
        // folder we don't know its byte total up front, so leave it 0.
        progress.volumeUsedTotal = isVolumeRoot ? volumeUsed : 0
        var seenInodes = Set<DevIno>()
        var level: [DirWork] = [DirWork(path: rootPath, parentPath: "", node: rootNode)]
        let timeouts = TimeoutTracker()
        let clock = ContinuousClock()
        var lastReport = clock.now

        while !level.isEmpty {
            try Task.checkCancellation()

            let chunks = chunked(level)
            var next: [DirWork] = []

            try await withThrowingTaskGroup(of: ChunkResult.self) { group in
                for chunk in chunks {
                    group.addTask(priority: .userInitiated) {
                        await scanChunk(chunk, allowedDevices: allowedDevices, timeouts: timeouts)
                    }
                }
                for try await result in group {
                    try Task.checkCancellation()

                    progress.filesScanned += result.fileCount
                    progress.bytesFound += result.bytes
                    progress.dirsScanned += result.dirsScanned
                    progress.dirsDiscovered += result.nextDirs.count
                    progress.currentPath = result.lastPath

                    // Hard-link dedup: only files with linkCount > 1 reach this list,
                    // and the merge runs single-threaded, so a plain Set suffices.
                    for candidate in result.hardlinks {
                        let key = DevIno(device: candidate.device, inode: candidate.inode)
                        if !seenInodes.insert(key).inserted {
                            progress.bytesFound -= candidate.node.size
                            candidate.node.overrideSize(0)
                        }
                    }

                    next.append(contentsOf: result.nextDirs)

                    let now = clock.now
                    if now - lastReport >= progressInterval {
                        lastReport = now
                        onProgress(progress)
                    }
                }
            }
            level = next
        }

        rootNode.recomputeDirectorySizes()
        attachHiddenSpace(to: rootNode, volumeUsed: volumeUsed, isVolumeRoot: isVolumeRoot)

        progress.dirsScanned = progress.dirsDiscovered
        progress.isComplete = true
        onProgress(progress)
        return rootNode
    }

    // MARK: Work units

    private struct DirWork: Sendable {
        let path: String
        let parentPath: String
        let node: FileNode
    }

    /// Tracks directories whose enumeration timed out, keyed by parent path.
    /// Dead filesystems (stalled iCloud/FileProvider subtrees) usually kill a
    /// whole sibling group at once (e.g. the 256 fan-out dirs of .git/objects);
    /// after two timeouts under the same parent, the remaining siblings are
    /// skipped instantly instead of each leaking a hung thread and a deadline.
    /// A single dead directory does not penalize its healthy siblings.
    private final class TimeoutTracker: @unchecked Sendable {
        private let lock = NSLock()
        private var timeoutsByParent: [String: Int] = [:]

        func recordTimeout(parent: String) {
            lock.lock(); timeoutsByParent[parent, default: 0] += 1; lock.unlock()
        }
        func isQuarantined(parent: String) -> Bool {
            lock.lock(); defer { lock.unlock() }
            return timeoutsByParent[parent, default: 0] >= 2
        }
    }

    private struct HardlinkCandidate: Sendable {
        let device: UInt32
        let inode: UInt64
        let node: FileNode
    }

    /// (device, inode) identity — inode numbers are only unique within a device,
    /// so dedup must key on both to avoid collisions across volumes/firmlinks.
    private struct DevIno: Hashable {
        let device: UInt32
        let inode: UInt64
    }

    private struct ChunkResult: Sendable {
        var fileCount = 0
        var bytes: Int64 = 0
        var dirsScanned = 0
        var nextDirs: [DirWork] = []
        var hardlinks: [HardlinkCandidate] = []
        var lastPath = ""
    }

    /// Split a BFS level into chunks sized to keep all cores busy without
    /// flooding the task group near the root (where levels are tiny).
    /// A chunk reports progress only when *all* its directories finish, so the
    /// cap is kept modest: one slow directory then stalls the visible bar for at
    /// most a few-dozen siblings, not a hundred-plus.
    private static func chunked(_ level: [DirWork]) -> [[DirWork]] {
        let workers = max(2, ProcessInfo.processInfo.activeProcessorCount)
        let chunkSize = max(1, min(48, level.count / (workers * 4) + 1))
        return stride(from: 0, to: level.count, by: chunkSize).map {
            Array(level[$0 ..< min($0 + chunkSize, level.count)])
        }
    }

    // MARK: Per-chunk scan (runs on a worker; touches only its own nodes)

    private static func scanChunk(_ chunk: [DirWork], allowedDevices: Set<UInt32>,
                                  timeouts: TimeoutTracker) async -> ChunkResult {
        var result = ChunkResult()

        for work in chunk {
            if Task.isCancelled { break }

            // Sibling group already known dead — skip without spawning a thread.
            if timeouts.isQuarantined(parent: work.parentPath) {
                result.dirsScanned += 1
                result.lastPath = work.path
                continue
            }

            guard let entries = await BulkDirScanner.timedEntries(atPath: work.path) else {
                // Dead filesystem under this directory (e.g. stalled iCloud /
                // FileProvider mount) — skip it rather than hang the scan.
                timeouts.recordTimeout(parent: work.parentPath)
                result.dirsScanned += 1
                result.lastPath = work.path
                continue
            }
            var children: [FileNode] = []
            children.reserveCapacity(entries.count)

            for entry in entries {
                switch entry.type {
                case .symlink, .other:
                    continue

                case .directory:
                    let childPath = work.path.hasSuffix("/")
                        ? work.path + entry.name
                        : work.path + "/" + entry.name
                    // Stop at mount-point boundaries and hazardous well-known paths.
                    guard allowedDevices.contains(entry.device),
                          !skippedPaths.contains(childPath) else { continue }
                    let childURL = URL(fileURLWithPath: childPath, isDirectory: true)

                    // Cloud-provider container: record a boundary node and do NOT
                    // descend. Its online-only contents use ~0 local disk, and
                    // crawling them is the dominant scan-time sink.
                    if isCloudBoundary(childPath) {
                        let cloudNode = FileNode(url: childURL, name: entry.name,
                                                 isDirectory: true, size: 0, kind: .cloudOnlyStorage)
                        children.append(cloudNode)
                        continue
                    }

                    let kind: FileNode.Kind = BulkDirScanner.isPackageName(entry.name) ? .package : .regular
                    let childNode = FileNode(url: childURL, name: entry.name,
                                             isDirectory: true, size: 0, kind: kind)
                    children.append(childNode)
                    result.nextDirs.append(DirWork(path: childPath, parentPath: work.path, node: childNode))

                case .file:
                    let childURL = URL(fileURLWithPath: work.path).appendingPathComponent(entry.name)
                    let childNode = FileNode(url: childURL, name: entry.name,
                                             isDirectory: false, size: entry.allocatedSize)
                    children.append(childNode)
                    if entry.linkCount > 1, entry.inode > 0 {
                        result.hardlinks.append(HardlinkCandidate(device: entry.device, inode: entry.inode, node: childNode))
                    }
                    result.fileCount += 1
                    result.bytes += entry.allocatedSize
                }
            }

            work.node.setChildren(children)
            result.dirsScanned += 1
            result.lastPath = work.path
        }

        return result
    }

    // MARK: Device boundaries

    /// The devices a scan may traverse: the root's own device, plus — when scanning
    /// "/" — the data volume's device, because firmlinks (/Users, /Applications, …)
    /// legitimately cross onto it.
    private static func allowedDevices(forRoot rootPath: String) -> Set<UInt32> {
        var devices = Set<UInt32>()
        var sb = Darwin.stat()
        if Darwin.lstat(rootPath, &sb) == 0 {
            devices.insert(UInt32(bitPattern: sb.st_dev))
        }
        if rootPath == "/" {
            var dataSB = Darwin.stat()
            if Darwin.lstat("/System/Volumes/Data", &dataSB) == 0 {
                devices.insert(UInt32(bitPattern: dataSB.st_dev))
            }
        }
        return devices
    }

    // MARK: Hidden space

    /// Bytes the scan could not observe (APFS local snapshots, purgeable space,
    /// protected files). Shown as a dimmed, non-deletable wedge so the chart total
    /// matches what the Finder reports for the volume.
    private static func attachHiddenSpace(to root: FileNode, volumeUsed: Int64, isVolumeRoot: Bool) {
        guard isVolumeRoot, volumeUsed > 0 else { return }
        let hidden = volumeUsed - root.size
        guard hidden > hiddenSpaceThreshold else { return }
        let node = FileNode(url: root.url, name: "Hidden Space",
                            isDirectory: false, size: hidden, kind: .hiddenSpace)
        root.setChildren(root.children + [node])
        root.overrideSize(root.size + hidden)
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
