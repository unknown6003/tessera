import Foundation

enum FileScannerError: LocalizedError {
    case sourceUnavailable(URL)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable(let url):
            let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            return "The selected source “\(name)” is no longer available. Reconnect it or choose another source, then try again."
        }
    }
}

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

    private static let hiddenSpaceThreshold: Int64 = 1 << 30  // 1 GiB

    /// Absolute paths never descended into (unless they are the scan root itself).
    private static let skippedPaths: Set<String> = [
        "/Volumes",         // other mounted volumes (incl. network mounts that can block forever)
        "/System/Volumes",  // data volume already reachable through firmlinks; VM/Preboot are hidden space
        "/dev",
        "/Network",
    ]

    // MARK: Public API

    static func scan(
        url: URL,
        cache: FileNode? = nil,
        onProgress: @Sendable @escaping (ScanProgress) -> Void
    ) async throws -> FileNode {
        let rootPath = url.path
        // Incremental re-scan: a directory whose modtime is unchanged since the
        // cached scan has the same listing, so we reuse its whole cached subtree
        // (and skip every getattrlistbulk inside it). Built only when a cache for
        // the same root is supplied.
        let cacheMap = cache.map { buildCacheMap($0) }
        let allowedDevices = Self.allowedDevices(forRoot: rootPath)
        // A removed folder, disconnected share, or unmounted disk cannot produce a
        // trustworthy scan. Previously an lstat failure left this set empty and the
        // scanner published an empty tree, which looked like a permissions problem.
        guard !allowedDevices.isEmpty else {
            throw FileScannerError.sourceUnavailable(url)
        }
        let volumeUsed = volumeUsedBytes(for: url)
        let isVolumeRoot = (try? url.resourceValues(forKeys: [.isVolumeKey]))?.isVolume ?? (rootPath == "/")

        let rootName = url.lastPathComponent.isEmpty ? rootPath : url.lastPathComponent
        let rootNode = FileNode(url: url, name: rootName, isDirectory: true, size: 0)

        var progress = ScanProgress(currentPath: rootPath)
        // Only use the volume-bytes denominator for a true volume scan; for a
        // folder we don't know its byte total up front, so leave it 0.
        progress.volumeUsedTotal = isVolumeRoot ? volumeUsed : 0

        let coordinator = ScanCoordinator(
            rootNode: rootNode,
            rootWork: DirWork(path: rootPath, node: rootNode),
            allowedDevices: allowedDevices,
            cacheMap: cacheMap,
            volumeUsed: volumeUsed,
            isVolumeRoot: isVolumeRoot,
            progress: progress,
            onProgress: onProgress
        )

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<FileNode, Error>) in
                coordinator.start(continuation: cont)
            }
        } onCancel: {
            coordinator.cancel()
        }
    }

    // MARK: Work units

    private struct DirWork: Sendable {
        let path: String
        let node: FileNode
    }

    private struct HardlinkCandidate {
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

    /// Per-directory enumeration result, computed on a worker before the worker
    /// takes the shared lock to merge it.
    private struct DirResult {
        var children: [FileNode] = []
        var subdirs: [DirWork] = []
        var fileCount = 0
        var bytes: Int64 = 0
        var hardlinks: [HardlinkCandidate] = []
        /// Count of cached subtrees reused unchanged (incremental re-scan).
        var reusedDirs = 0
    }

    // MARK: Per-directory node construction (shared hot path)

    /// Turn one directory's raw listing into child nodes + sub-work. This is the
    /// per-entry hot path the entire scan multiplies over (millions of entries),
    /// so it is the single most important thing to keep cheap. The parallel pool
    /// and the single-threaded `scanSerial` driver both call it, so any speedup
    /// here lifts both.
    private static func buildResult(forEntries entries: [EntryInfo], parentPath: String,
                                    allowedDevices: Set<UInt32>,
                                    cacheMap: [String: FileNode]? = nil) -> DirResult {
        var result = DirResult()
        result.children.reserveCapacity(entries.count)
        let parentHasSlash = parentPath.hasSuffix("/")

        for entry in entries {
            switch entry.type {
            case .symlink, .other:
                continue

            case .directory:
                let childPath = parentHasSlash ? parentPath + entry.name
                                               : parentPath + "/" + entry.name

                // Hazardous well-known mounts (other volumes, network shares, /dev)
                // and any entry on a different device are not descended. A volume
                // mounted INSIDE the tree (e.g. a Simulator runtime under
                // /Library/Developer/CoreSimulator) is reported by its parent with
                // the parent's device, so it survives this guard as an empty node —
                // it's later reclassified and sized from the mount table by
                // `attachCrossMounts`, turning otherwise-invisible "hidden" space
                // into something the user can see and reclaim.
                if skippedPaths.contains(childPath) { continue }
                guard allowedDevices.contains(entry.device) else { continue }

                // Dataless (online-only) directory placeholder: descending would
                // force a slow provider round-trip, and its contents occupy ~0
                // local disk. The dataless flag came from the PARENT enumeration,
                // so we decide WITHOUT opening the child → no hang. Represent it
                // as a boundary node and do NOT enqueue.
                if entry.isDataless {
                    let cloudNode = FileNode(name: entry.name,
                                             isDirectory: true, size: 0, kind: .cloudOnlyStorage)
                    result.children.append(cloudNode)
                    continue
                }

                let kind: FileNode.Kind = BulkDirScanner.isPackageName(entry.name) ? .package : .regular

                // Incremental re-scan: if the cached scan has this directory with the
                // same (non-zero) modtime, its listing is unchanged — reuse the whole
                // cached subtree (size + children) and DON'T descend, skipping every
                // getattrlistbulk inside it.
                if let cached = cacheMap?[childPath],
                   cached.modTime != 0, cached.modTime == entry.modTime,
                   cached.isDirectory, cached.kind == kind {
                    result.children.append(cached)
                    result.reusedDirs += 1
                    continue
                }

                let childNode = FileNode(name: entry.name, isDirectory: true, size: 0,
                                         kind: kind, modTime: entry.modTime)
                result.children.append(childNode)
                result.subdirs.append(DirWork(path: childPath, node: childNode))

            case .file:
                // Dataless (online-only) file: not materialized, ~0 local disk.
                // Skip entirely — no node, no bytes, not counted.
                if entry.isDataless { continue }
                // Carry the file's mtime (already read by the bulk syscall — no extra
                // cost) so age-based cleanup ("older than 6 months") works per file.
                let childNode = FileNode(name: entry.name, isDirectory: false,
                                         size: entry.allocatedSize, modTime: entry.modTime)
                result.children.append(childNode)
                if entry.linkCount > 1, entry.inode > 0 {
                    result.hardlinks.append(HardlinkCandidate(device: entry.device, inode: entry.inode, node: childNode))
                }
                result.fileCount += 1
                result.bytes += entry.allocatedSize
            }
        }
        return result
    }

    /// Build a path → directory-node map from a prior scan tree, for incremental
    /// re-scan lookups. Paths are built by cheap string concatenation (not the
    /// CFURL-based `node.url`). Synthetic nodes (hidden space, cross-volume, cloud)
    /// are excluded so they're always re-evaluated.
    static func buildCacheMap(_ root: FileNode) -> [String: FileNode] {
        var map: [String: FileNode] = [:]
        var stack: [(node: FileNode, path: String)] = [(root, root.url.path)]
        while let (node, path) = stack.popLast() {
            guard node.isDirectory, !node.isSynthetic else { continue }
            map[path] = node
            for child in node.children where child.isDirectory && !child.isSynthetic {
                stack.append((child, path + "/" + child.name))
            }
        }
        return map
    }

    // MARK: Single-threaded driver (benchmark baseline + per-worker unit)

    struct SerialScanStats {
        var dirs = 0
        var files = 0
        var bytes: Int64 = 0
        /// Time enumerating directories (getattrlistbulk syscall + decode).
        var enumerateNanos: UInt64 = 0
        /// Time building child FileNodes from each listing (pure CPU).
        var buildNanos: UInt64 = 0
        /// Time aggregating directory sizes over the finished tree.
        var recomputeNanos: UInt64 = 0
        /// Per-syscall split (from the C bridge's opt-in timing).
        var openNanos: UInt64 = 0
        var bulkNanos: UInt64 = 0
        var closeNanos: UInt64 = 0
        /// Thread CPU time consumed across the enumerate loop. Compared to wall
        /// time it reveals CPU-bound (≈ wall) vs I/O-blocked (≪ wall).
        var cpuNanos: UInt64 = 0
    }

    /// Single-threaded depth-first scan: no locks, no dispatch, no watchdog.
    /// This is the unit the parallel pool multiplies, and the baseline we tune
    /// to drive per-entry CPU cost to the floor before relying on parallelism.
    @discardableResult
    static func scanSerial(url: URL) -> (root: FileNode, stats: SerialScanStats) {
        let rootPath = url.path
        let allowedDevices = Self.allowedDevices(forRoot: rootPath)
        let rootName = url.lastPathComponent.isEmpty ? rootPath : url.lastPathComponent
        let root = FileNode(url: url, name: rootName, isDirectory: true, size: 0)

        var stack: [DirWork] = [DirWork(path: rootPath, node: root)]
        var stats = SerialScanStats()
        let scratch = BulkScratch()

        // Single-threaded, so the C bridge's global syscall timers are race-free.
        br_set_timing(1)
        var cpu0 = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu0)

        while let work = stack.popLast() {
            let t0 = DispatchTime.now().uptimeNanoseconds
            guard let entries = BulkDirScanner.workerEntries(atPath: work.path, scratch: scratch) else { continue }
            let t1 = DispatchTime.now().uptimeNanoseconds
            let result = buildResult(forEntries: entries, parentPath: work.path,
                                     allowedDevices: allowedDevices)
            let t2 = DispatchTime.now().uptimeNanoseconds
            work.node.setChildren(result.children)
            stack.append(contentsOf: result.subdirs)
            stats.dirs += 1
            stats.files += result.fileCount
            stats.bytes += result.bytes
            stats.enumerateNanos &+= t1 &- t0
            stats.buildNanos &+= t2 &- t1
        }

        let tr = DispatchTime.now().uptimeNanoseconds
        root.recomputeDirectorySizes()
        stats.recomputeNanos = DispatchTime.now().uptimeNanoseconds &- tr

        var cpu1 = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu1)
        stats.cpuNanos = UInt64(max(0, (cpu1.tv_sec - cpu0.tv_sec) * 1_000_000_000 + (cpu1.tv_nsec - cpu0.tv_nsec)))

        stats.openNanos = br_get_open_ns()
        stats.bulkNanos = br_get_bulk_ns()
        stats.closeNanos = br_get_close_ns()
        br_set_timing(0)
        return (root, stats)
    }

    // MARK: Coordinator — bounded pool of dedicated worker threads over a shared queue

    /// Drives the scan on a fixed pool of long-lived worker threads (NEVER the
    /// Swift cooperative pool — blocking enumeration syscalls run here). Workers
    /// pop directories from a shared, lock-protected queue and push discovered
    /// subdirectories back continuously; there is no per-level barrier, so one
    /// stuck directory occupies one worker while the rest keep progressing.
    ///
    /// Termination is tracked by `pending` (directories discovered but not yet
    /// completed): starts at 1 (the root); each completion does
    /// `pending += childDirCount; pending -= 1`. When `pending` hits 0 the whole
    /// tree is done. A watchdog force-finishes if progress stalls on an
    /// uninterruptible syscall, so the scan ALWAYS terminates.
    private final class ScanCoordinator: @unchecked Sendable {
        private let cond = NSCondition()

        // Shared mutable state — guarded by `cond`.
        private var queue: [DirWork] = []
        private var pending = 1            // the root
        private var cancelled = false
        private var finished = false       // continuation resumed (single-resume guard)
        private var activeWorkers = 0      // workers currently inside a directory
        /// Workers authorized to attach an enumeration result. The watchdog may
        /// only publish the tree when this is zero, otherwise SwiftUI could receive
        /// a tree while a late worker is mutating it.
        private var commitsInProgress = 0
        private var seenInodes = Set<DevIno>()
        private var progress: ScanProgress

        // Watchdog stall detection (guarded by `cond`).
        private var lastDirsScanned = 0
        private var lastAdvanceAt = DispatchTime.now()

        // Immutable config.
        private let rootNode: FileNode
        private let allowedDevices: Set<UInt32>
        private let cacheMap: [String: FileNode]?
        private let volumeUsed: Int64
        private let isVolumeRoot: Bool
        private let onProgress: @Sendable (ScanProgress) -> Void
        private let workerCount: Int

        // Progress throttling (guarded by `cond`).
        private var lastReport = DispatchTime.now()
        private static let progressIntervalNanos: UInt64 = 80_000_000   // 80 ms
        private static let stallTimeoutSeconds: Double = 60

        private var continuation: CheckedContinuation<FileNode, Error>?
        private var watchdog: DispatchSourceTimer?

        init(rootNode: FileNode, rootWork: DirWork, allowedDevices: Set<UInt32>,
             cacheMap: [String: FileNode]?,
             volumeUsed: Int64, isVolumeRoot: Bool, progress: ScanProgress,
             onProgress: @escaping @Sendable (ScanProgress) -> Void) {
            self.rootNode = rootNode
            self.allowedDevices = allowedDevices
            self.cacheMap = cacheMap
            self.volumeUsed = volumeUsed
            self.isVolumeRoot = isVolumeRoot
            self.onProgress = onProgress
            self.progress = progress
            self.queue = [rootWork]
            if let override = ProcessInfo.processInfo.environment["SO_SCAN_WORKERS"],
               let n = Int(override), n > 0 {
                self.workerCount = n
            } else {
                // getattrlistbulk dominates the scan (~71% of single-thread time).
                // Some parallelism hides per-read SSD latency, but oversubscribing
                // this sustained, user-initiated work competes with SwiftUI and makes
                // the window appear hung. One worker per active core (capped at 12)
                // keeps interaction responsive while still parallelizing metadata I/O.
                // Override with SO_SCAN_WORKERS.
                let cores = ProcessInfo.processInfo.activeProcessorCount
                self.workerCount = min(max(cores, 4), 12)
            }
        }

        // MARK: Lifecycle

        func start(continuation cont: CheckedContinuation<FileNode, Error>) {
            cond.lock()
            continuation = cont
            // If cancellation already fired before we stored the continuation,
            // resume immediately.
            if cancelled {
                cond.unlock()
                resumeThrowing(CancellationError())
                return
            }
            cond.unlock()

            startWatchdog()
            for _ in 0 ..< workerCount {
                // Utility QoS lets AppKit's main-thread resize/hover/scroll work
                // preempt the sustained disk scan.
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    self?.workerLoop()
                }
            }
        }

        func cancel() {
            cond.lock()
            cancelled = true
            cond.broadcast()
            cond.unlock()
        }

        // MARK: Worker loop

        private func workerLoop() {
            // One reusable buffer set per worker, for its whole lifetime.
            let scratch = BulkScratch()
            while true {
                cond.lock()
                // Wait for work, cancellation, or completion.
                while queue.isEmpty, pending > 0, !cancelled, !finished {
                    cond.wait()
                }
                if cancelled {
                    cond.unlock()
                    // First worker to observe cancellation resumes the continuation;
                    // the single-resume guard makes redundant calls harmless.
                    resumeThrowing(CancellationError())
                    return
                }
                if finished {
                    cond.unlock()
                    return
                }
                if queue.isEmpty {
                    // pending == 0 → tree complete. Wake siblings and exit.
                    cond.unlock()
                    maybeFinishNormally()
                    return
                }
                let work = queue.removeLast()
                activeWorkers += 1
                cond.unlock()

                // Drain per directory. Each worker runs the whole scan inside a
                // single libdispatch block, whose autorelease pool empties only when
                // the block returns — i.e. at scan end. `buildResult` → `isPackageName`
                // bridges an NSString (`.pathExtension`) per directory entry, so
                // without an inner pool those temporaries accumulate across every entry
                // for the entire scan. Pooling per directory keeps scan memory flat.
                let result = autoreleasepool { enumerate(work, scratch: scratch) }

                // Reserve the right to mutate before touching the tree. A watchdog
                // timeout can happen while this worker is still enumerating; a
                // result returning after publication must be discarded.
                cond.lock()
                guard !cancelled, !finished else {
                    activeWorkers -= 1
                    cond.unlock()
                    if cancelled { resumeThrowing(CancellationError()) }
                    return
                }
                commitsInProgress += 1
                cond.unlock()

                // This node remains private until merge. The reservation prevents
                // watchdog publication during parent wiring without putting this
                // potentially large loop under the shared queue lock.
                work.node.setChildren(result.children)

                cond.lock()
                commitsInProgress -= 1
                if cancelled {
                    activeWorkers -= 1
                    cond.broadcast()
                    cond.unlock()
                    resumeThrowing(CancellationError())
                    return
                }
                // Defensive invariant: the watchdog cannot set `finished` while a
                // commit is reserved, but never merge into an abandoned tree.
                if finished {
                    activeWorkers -= 1
                    cond.unlock()
                    return
                }
                let progressToEmit = merge(result, for: work)
                activeWorkers -= 1
                cond.unlock()
                // Emit progress only after releasing the lock: `onProgress` is caller-
                // supplied, so invoking it under `cond` would risk deadlock/priority
                // inversion if it ever did real work or re-entered the coordinator.
                if let progressToEmit { onProgress(progressToEmit) }
            }
        }

        /// Enumerate one directory off-lock (the slow part). Returns an empty
        /// result if the directory blew its deadline (treated as childless but
        /// counted). The per-entry node construction is shared with the
        /// single-threaded driver via `FileScanner.buildResult`.
        private func enumerate(_ work: DirWork, scratch: BulkScratch) -> DirResult {
            guard let entries = BulkDirScanner.workerEntries(atPath: work.path, scratch: scratch) else {
                // Dead/stalled directory — skip its contents, still counts as scanned.
                return DirResult()
            }
            return FileScanner.buildResult(forEntries: entries, parentPath: work.path,
                                           allowedDevices: allowedDevices, cacheMap: cacheMap)
        }

        /// Merge one directory's result under the lock: attach children, enqueue
        /// subdirs, update pending and progress, and dedup hard links.
        /// Caller holds `cond`. Returns a progress snapshot to emit *after* the caller
        /// releases the lock (nil when this tick is throttled), so `onProgress` never
        /// runs under `cond`.
        private func merge(_ result: DirResult, for work: DirWork) -> ScanProgress? {
            // Children were already wired to `work.node` off-lock by the caller.

            // Enqueue discovered subdirectories and adjust the pending counter:
            // +childDirCount for what we discovered, -1 for the directory we finished.
            queue.append(contentsOf: result.subdirs)
            pending += result.subdirs.count
            pending -= 1

            progress.filesScanned += result.fileCount
            progress.bytesFound += result.bytes
            progress.dirsScanned += 1
            progress.dirsDiscovered += result.subdirs.count
            progress.currentPath = work.path

            // Hard-link dedup against the shared set (under the lock).
            for candidate in result.hardlinks {
                let key = DevIno(device: candidate.device, inode: candidate.inode)
                if !seenInodes.insert(key).inserted {
                    progress.bytesFound -= candidate.node.size
                    candidate.node.overrideSize(0)
                }
            }

            // Wake workers: either there is fresh work, or the tree just completed.
            if !result.subdirs.isEmpty || pending == 0 {
                cond.broadcast()
            }

            // Throttled progress emission — hand the snapshot back to the caller,
            // which emits it after unlocking.
            let now = DispatchTime.now()
            if now.uptimeNanoseconds &- lastReport.uptimeNanoseconds >= Self.progressIntervalNanos {
                lastReport = now
                return progress
            }
            return nil
        }

        // MARK: Completion

        /// Normal completion: pending hit 0. Finalize and resume once.
        private func maybeFinishNormally() {
            cond.lock()
            // Wake any siblings still parked in their wait loop so they exit.
            cond.broadcast()
            if finished || cancelled {
                cond.unlock()
                if cancelled { resumeThrowing(CancellationError()) }
                return
            }
            finished = true
            cond.unlock()
            finalizeAndResume()
        }

        /// Finalize the tree and resume the continuation with the root node.
        /// Runs exactly once (guarded by `finished`).
        private func finalizeAndResume() {
            watchdog?.cancel()
            watchdog = nil

            // Size cross-mounted volumes (Simulator runtimes, disk images, …) from
            // the mount table before re-aggregating, so their bytes flow up into
            // ancestor totals and out of the opaque "Hidden Space" wedge.
            FileScanner.attachCrossMounts(to: rootNode, rootPath: rootNode.url.path)
            rootNode.recomputeDirectorySizes()
            FileScanner.attachHiddenSpace(to: rootNode, volumeUsed: volumeUsed, isVolumeRoot: isVolumeRoot)

            cond.lock()
            progress.dirsScanned = progress.dirsDiscovered
            progress.isComplete = true
            let snapshot = progress
            let cont = continuation
            continuation = nil
            cond.unlock()

            onProgress(snapshot)
            cont?.resume(returning: rootNode)
        }

        private func resumeThrowing(_ error: Error) {
            watchdog?.cancel()
            watchdog = nil
            cond.lock()
            let cont = continuation
            continuation = nil
            cond.unlock()
            cont?.resume(throwing: error)
        }

        // MARK: Watchdog

        /// Guarantees termination even if a worker is stuck in an uninterruptible
        /// syscall. If progress hasn't advanced for ~60s while the queue is empty
        /// (all remaining pending dirs are stuck in-flight), force completion with
        /// whatever has been scanned and abandon the stuck worker threads.
        private func startWatchdog() {
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + 5, repeating: 5)
            timer.setEventHandler { [weak self] in self?.watchdogTick() }
            watchdog = timer
            timer.resume()
        }

        private func watchdogTick() {
            cond.lock()

            if finished || cancelled {
                cond.unlock()
                if cancelled { resumeThrowing(CancellationError()) }
                return
            }

            // Progress advanced since last tick → reset the stall clock.
            if progress.dirsScanned != lastDirsScanned {
                lastDirsScanned = progress.dirsScanned
                lastAdvanceAt = DispatchTime.now()
                cond.unlock()
                return
            }

            // No advance. Only force-finish if there is no queued work left to do —
            // i.e. the remaining `pending` dirs are all stuck in-flight in workers.
            let stalledNanos = DispatchTime.now().uptimeNanoseconds &- lastAdvanceAt.uptimeNanoseconds
            let stalled = Double(stalledNanos) / 1_000_000_000 >= Self.stallTimeoutSeconds
            guard stalled, pending > 0, queue.isEmpty, commitsInProgress == 0 else {
                cond.unlock()
                return
            }

            finished = true
            cond.broadcast()   // release idle workers (stuck ones are abandoned)
            cond.unlock()
            finalizeAndResume()
        }
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
        // Cross-mounted volumes (Simulator runtimes, mounted images, …) live on
        // OTHER devices, so their bytes are NOT part of this volume's used total.
        // Exclude them before computing what the scan couldn't see on this volume,
        // otherwise hidden space would be undercounted by their size.
        let crossVolumeBytes = totalCrossVolumeBytes(root)
        let scannedOnVolume = max(0, root.size - crossVolumeBytes)
        let hidden = volumeUsed - scannedOnVolume
        guard hidden > hiddenSpaceThreshold else { return }
        let node = FileNode(url: root.url, name: "Hidden Space",
                            isDirectory: false, size: hidden, kind: .hiddenSpace)
        root.setChildren(root.children + [node])
        root.overrideSize(root.size + hidden)
    }

    /// Total size of every cross-mounted-volume node in the tree. These occupy
    /// space on other devices/containers, so they must be excluded from this
    /// volume's hidden-space reconciliation.
    private static func totalCrossVolumeBytes(_ root: FileNode) -> Int64 {
        var total: Int64 = 0
        var stack: [FileNode] = [root]
        while let node = stack.popLast() {
            if node.kind == .crossVolume { total += node.size; continue }
            stack.append(contentsOf: node.children)
        }
        return total
    }

    // MARK: Volume used bytes

    private static func volumeUsedBytes(for url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let vals = try? url.resourceValues(forKeys: keys),
              let total = vals.volumeTotalCapacity,
              let available = vals.volumeAvailableCapacity else { return 0 }
        return max(0, Int64(total) - Int64(available))
    }

    // MARK: Cross-mounted volumes

    /// Map of mount-point path → used bytes for every separate volume mounted
    /// strictly inside `rootPath` (Simulator runtimes, disk images, …), read from
    /// the kernel mount table. Excludes the scan's own volume and the hazardous
    /// system mount trees we never surface. Source of truth for cross-mount sizes:
    /// `getattrlistbulk` reports a mount point with its PARENT's device, so the
    /// boundary can't be detected from directory listings — the mount table can.
    private static func crossMounts(under rootPath: String) -> [String: Int64] {
        var out: [String: Int64] = [:]
        var buf: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&buf, MNT_NOWAIT)
        guard count > 0, let mnts = buf else { return out }
        // Prefix that a child mount path must start with ("/" stays "/").
        let prefix = rootPath == "/" ? "/" : (rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
        for i in 0 ..< Int(count) {
            let m = mnts[i]
            let mountPath = withUnsafeBytes(of: m.f_mntonname) { raw -> String in
                String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
            }
            guard mountPath.hasPrefix(prefix), mountPath != rootPath else { continue }
            if skippedPaths.contains(where: { mountPath == $0 || mountPath.hasPrefix($0 + "/") }) { continue }
            let used = (Int64(m.f_blocks) - Int64(m.f_bfree)) * Int64(m.f_bsize)
            out[mountPath] = max(0, used)
        }
        return out
    }

    /// Find each cross-mounted volume's (empty) placeholder node in the tree and
    /// reclassify it as a sized `.crossVolume` boundary, so the space shows up
    /// instead of vanishing into "Hidden Space". Must run BEFORE size
    /// re-aggregation so the sizes flow up into ancestor totals.
    private static func attachCrossMounts(to root: FileNode, rootPath: String) {
        let mounts = crossMounts(under: rootPath)
        guard !mounts.isEmpty else { return }
        let prefix = rootPath == "/" ? "/" : (rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
        for (mountPath, used) in mounts {
            let relative = String(mountPath.dropFirst(prefix.count))
            let components = relative.split(separator: "/").map(String.init)
            guard !components.isEmpty else { continue }
            var node: FileNode? = root
            for name in components {
                node = node?.children.first { $0.name == name }
                if node == nil { break }
            }
            node?.reclassifyAsCrossVolume(size: used)
        }
    }
}
