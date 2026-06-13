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

        let coordinator = ScanCoordinator(
            rootNode: rootNode,
            rootWork: DirWork(path: rootPath, node: rootNode),
            allowedDevices: allowedDevices,
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
        private var seenInodes = Set<DevIno>()
        private var progress: ScanProgress

        // Watchdog stall detection (guarded by `cond`).
        private var lastDirsScanned = 0
        private var lastAdvanceAt = DispatchTime.now()

        // Immutable config.
        private let rootNode: FileNode
        private let allowedDevices: Set<UInt32>
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
             volumeUsed: Int64, isVolumeRoot: Bool, progress: ScanProgress,
             onProgress: @escaping @Sendable (ScanProgress) -> Void) {
            self.rootNode = rootNode
            self.allowedDevices = allowedDevices
            self.volumeUsed = volumeUsed
            self.isVolumeRoot = isVolumeRoot
            self.onProgress = onProgress
            self.progress = progress
            self.queue = [rootWork]
            self.workerCount = min(max(ProcessInfo.processInfo.activeProcessorCount, 4), 12)
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
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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

                let result = enumerate(work)

                cond.lock()
                merge(result, for: work)
                activeWorkers -= 1
                cond.unlock()
            }
        }

        /// Enumerate one directory off-lock (the slow part). Returns nil children
        /// if the directory blew its deadline (treated as childless but counted).
        private func enumerate(_ work: DirWork) -> DirResult {
            var result = DirResult()
            guard let entries = BulkDirScanner.workerEntries(atPath: work.path) else {
                // Dead/stalled directory — skip its contents, still counts as scanned.
                return result
            }
            result.children.reserveCapacity(entries.count)

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

                    // Dataless (online-only) directory placeholder: descending would
                    // force a slow provider round-trip, and its contents occupy ~0
                    // local disk. The dataless flag came from the PARENT enumeration,
                    // so we decide WITHOUT opening the child → no hang. Represent it
                    // as a boundary node and do NOT enqueue.
                    if entry.isDataless {
                        let cloudNode = FileNode(url: childURL, name: entry.name,
                                                 isDirectory: true, size: 0, kind: .cloudOnlyStorage)
                        result.children.append(cloudNode)
                        continue
                    }

                    let kind: FileNode.Kind = BulkDirScanner.isPackageName(entry.name) ? .package : .regular
                    let childNode = FileNode(url: childURL, name: entry.name,
                                             isDirectory: true, size: 0, kind: kind)
                    result.children.append(childNode)
                    result.subdirs.append(DirWork(path: childPath, node: childNode))

                case .file:
                    // Dataless (online-only) file: not materialized, ~0 local disk.
                    // Skip entirely — no node, no bytes, not counted.
                    if entry.isDataless { continue }
                    let childURL = URL(fileURLWithPath: work.path).appendingPathComponent(entry.name)
                    let childNode = FileNode(url: childURL, name: entry.name,
                                             isDirectory: false, size: entry.allocatedSize)
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

        /// Merge one directory's result under the lock: attach children, enqueue
        /// subdirs, update pending and progress, and dedup hard links.
        /// Caller holds `cond`.
        private func merge(_ result: DirResult, for work: DirWork) {
            work.node.setChildren(result.children)

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

            // Throttled progress emission.
            let now = DispatchTime.now()
            if now.uptimeNanoseconds &- lastReport.uptimeNanoseconds >= Self.progressIntervalNanos {
                lastReport = now
                let snapshot = progress
                onProgress(snapshot)
            }
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
            guard stalled, pending > 0, queue.isEmpty else {
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
