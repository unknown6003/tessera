import Foundation
import CryptoKit

// MARK: - Duplicate finder (on-device, parallel)
//
// Finds duplicate files in the scanned tree, entirely on-device — no file data
// leaves the Mac. Two things keep it near scan speed: only files that share an
// exact size with another file are read at all, and each is reduced to a bounded
// content fingerprint (full hash for small files; size + sampled regions for large
// ones, so a 10 GB file costs ~4 MB of reads, not 10 GB). Fingerprinting runs
// across a pool of dedicated threads so read latency overlaps.

struct DuplicateGroup: Identifiable, Sendable {
    /// Stable identity for the group (size + content hash).
    let id: String
    /// The identical-content files (always ≥ 2).
    let files: [FileNode]
    /// Size of each file (they're identical, so all the same).
    let perFileBytes: Int64
    /// Index into `files` of the copy triage recommends keeping.
    var keepIndex: Int
    /// Short, human-readable reason for the keeper choice.
    var keepReason: String

    var count: Int { files.count }
    /// Bytes freed if every copy but the keeper is removed.
    var reclaimableBytes: Int64 { perFileBytes * Int64(max(0, files.count - 1)) }
    /// Files to delete (everything except the keeper).
    var removableFiles: [FileNode] {
        files.enumerated().filter { $0.offset != keepIndex }.map(\.element)
    }
}

struct DuplicateProgress: Sendable {
    var filesHashed: Int = 0
    var totalToHash: Int = 0
    var fraction: Double { totalToHash > 0 ? Double(filesHashed) / Double(totalToHash) : 0 }
}

/// Cancellation token usable from plain threads (the dedicated hashing threads run
/// outside any Swift `Task`, so `Task.isCancelled` doesn't reach them).
final class DuplicateCancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

enum DuplicateFinder {
    /// Default floor — skip files smaller than this (dedup of tiny files isn't worth
    /// the I/O and rarely reclaims meaningful space).
    static let defaultMinSize: Int64 = 1 * 1024 * 1024

    /// Flatten a tree into the list of non-synthetic files at/above `minSize`. This
    /// is the ONLY step that walks `FileNode.children`, so callers can run it on the
    /// owning actor (the main actor, for the live scan tree) to take an immutable
    /// snapshot before handing the flat list to `find(files:)` on a background thread
    /// — closing the data race where the main actor could mutate `children` (via the
    /// collector delete flow) while a background pass traversed the same arrays.
    static func collectFiles(root: FileNode, minSize: Int64 = defaultMinSize) -> [FileNode] {
        var files: [FileNode] = []
        var stack = root.children
        while let node = stack.popLast() {
            if node.isSynthetic { continue }
            if node.isDirectory {
                stack.append(contentsOf: node.children)
            } else if node.size >= minSize {
                files.append(node)
            }
        }
        return files
    }

    /// Scan the tree for exact-content duplicates. Walks the tree on the calling
    /// thread to collect candidates, so prefer `find(files:)` with a snapshot taken
    /// on the tree's owning actor when the tree may be mutated concurrently.
    static func find(root: FileNode,
                     minSize: Int64 = defaultMinSize,
                     cancel: DuplicateCancelToken = DuplicateCancelToken(),
                     progress: @escaping @Sendable (DuplicateProgress) -> Void) -> [DuplicateGroup] {
        find(files: collectFiles(root: root, minSize: minSize), cancel: cancel, progress: progress)
    }

    /// Scan a pre-collected, snapshot list of candidate files for exact-content
    /// duplicates. Runs synchronously on the calling (background) thread,
    /// parallelizing the file reads across a worker pool. The list must not be
    /// mutated concurrently; it is read-only here.
    static func find(files allFiles: [FileNode],
                     cancel: DuplicateCancelToken = DuplicateCancelToken(),
                     progress: @escaping @Sendable (DuplicateProgress) -> Void) -> [DuplicateGroup] {
        // 1. Bucket candidate files by exact size. Only sizes shared by ≥ 2 files
        //    can contain duplicates, so everything else is skipped without a read.
        var bySize: [Int64: [FileNode]] = [:]
        for node in allFiles {
            if cancel.isCancelled { return [] }
            bySize[node.size, default: []].append(node)
        }
        let candidates = bySize.values.filter { $0.count > 1 }.flatMap { $0 }
        let total = candidates.count
        progress(DuplicateProgress(filesHashed: 0, totalToHash: total))
        guard total > 0 else { return [] }

        let workers = workerCount()

        // 2. Parallel content fingerprint → group by (size, signature). One read per
        //    candidate, bounded: small files are hashed in full (exact), large files
        //    are fingerprinted from sampled regions so a 10 GB file costs ~1 MB of
        //    reads instead of 10 GB. This is what keeps dedup near scan speed. Note
        //    the sampled signature is only a candidate filter for large files — it is
        //    verified byte-for-byte in step 3 before any group is surfaced.
        let sigs = parallelHashes(candidates, workers: workers, cancel: cancel) { node in
            signature(of: node, size: node.size)
        } onProgress: { done in
            progress(DuplicateProgress(filesHashed: min(done, total), totalToHash: total))
        }
        if cancel.isCancelled { return [] }

        var bySignature: [String: [FileNode]] = [:]
        for node in candidates {
            if let sig = sigs[ObjectIdentifier(node)] {
                bySignature["\(node.size)|\(sig)", default: []].append(node)
            }
        }

        var groups: [DuplicateGroup] = []
        for (key, files) in bySignature where files.count > 1 {
            // Small files were hashed in full, so their signature is definitive and
            // the group is exact. Large files were only sampled, so the group is just
            // a candidate set — re-read every member in full and split it into truly
            // byte-for-byte-identical subgroups before any of them can be staged or
            // deleted. This is the safety gate: a sampled-only match never reaches the
            // collector.
            let verified = files[0].size <= exactThreshold
                ? [files]
                : verifyExactGroups(files, cancel: cancel)
            if cancel.isCancelled { return [] }
            for (idx, subgroup) in verified.enumerated() where subgroup.count > 1 {
                let (keepIndex, reason) = DuplicateTriage.recommendKeeper(subgroup)
                let subKey = verified.count > 1 ? "\(key)#\(idx)" : key
                groups.append(DuplicateGroup(id: subKey, files: subgroup, perFileBytes: subgroup[0].size,
                                             keepIndex: keepIndex, keepReason: reason))
            }
        }
        progress(DuplicateProgress(filesHashed: total, totalToHash: total))
        return groups.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    // MARK: Exact verification

    /// Split a set of large files that share a *sampled* signature into subgroups
    /// that are identical byte-for-byte. The sampled signature can collide for
    /// genuinely different files, so this full re-read is mandatory before any large
    /// duplicate is offered for permanent deletion.
    ///
    /// Files are compared pairwise against an established "representative" per
    /// subgroup using a streamed full read (no whole-file buffering). The candidate
    /// sets here are tiny (only files that already matched on exact size *and* the
    /// sampled windows), so this is cheap in practice while being correct.
    private static func verifyExactGroups(_ files: [FileNode],
                                          cancel: DuplicateCancelToken) -> [[FileNode]] {
        var subgroups: [[FileNode]] = []
        for file in files {
            if cancel.isCancelled { return [] }
            if let idx = subgroups.firstIndex(where: { contentsEqual(file.url, $0[0].url, cancel: cancel) }) {
                subgroups[idx].append(file)
            } else {
                subgroups.append([file])
            }
        }
        return subgroups
    }

    /// True iff the two files are byte-for-byte identical, compared by streaming both
    /// in fixed-size chunks (so a huge pair never has to be held in memory at once).
    /// Any read error or cancellation yields `false` — when we can't prove equality
    /// we must not treat the files as duplicates.
    private static func contentsEqual(_ lhs: URL, _ rhs: URL, cancel: DuplicateCancelToken) -> Bool {
        guard let a = try? FileHandle(forReadingFrom: lhs),
              let b = try? FileHandle(forReadingFrom: rhs) else { return false }
        defer { try? a.close(); try? b.close() }
        let chunk = 1 << 20 // 1 MB
        // `read(upToCount:)` returns nil OR empty Data at EOF; normalize both to empty
        // so "both reached EOF together" reads as equal, not as an error.
        func next(_ h: FileHandle) -> Data? {
            do { return try h.read(upToCount: chunk) ?? Data() }
            catch { return nil }   // genuine read error → can't prove equality
        }
        while !cancel.isCancelled {
            guard let da = next(a), let db = next(b) else { return false }
            if da != db { return false }
            if da.isEmpty { return true } // both reached EOF together with all bytes equal
        }
        return false
    }

    // MARK: Parallel map

    private static func workerCount() -> Int {
        if let s = ProcessInfo.processInfo.environment["SO_DUPE_WORKERS"], let n = Int(s), n > 0 { return n }
        // Hashing is read-latency bound, so oversubscribe the cores to overlap I/O.
        let cores = ProcessInfo.processInfo.activeProcessorCount
        return min(max(cores * 2, 8), 32)
    }

    /// Hash `items` across `workers` dedicated threads, claiming work in batches to
    /// keep lock traffic low. Returns file → hash for the files that hashed. Blocks
    /// until done; must be called off the main thread and off the cooperative pool.
    /// Shared, lock-guarded state for the worker threads (a reference type so it's
    /// safely captured by the concurrent closures).
    private final class HashState: @unchecked Sendable {
        let lock = NSLock()
        var nextIndex = 0
        var processed = 0
        var merged: [ObjectIdentifier: String] = [:]
    }

    private static func parallelHashes(
        _ items: [FileNode], workers: Int, cancel: DuplicateCancelToken,
        _ hash: @escaping @Sendable (FileNode) -> String?,
        onProgress: @escaping @Sendable (Int) -> Void
    ) -> [ObjectIdentifier: String] {
        guard !items.isEmpty else { return [:] }
        let state = HashState()
        let batch = 16
        let group = DispatchGroup()

        for _ in 0 ..< min(workers, items.count) {
            group.enter()
            Thread.detachNewThread {
                var local: [ObjectIdentifier: String] = [:]
                while !cancel.isCancelled {
                    state.lock.lock()
                    let start = state.nextIndex
                    state.nextIndex = min(state.nextIndex + batch, items.count)
                    let end = state.nextIndex
                    state.lock.unlock()
                    if start >= end { break }

                    for i in start ..< end {
                        if cancel.isCancelled { break }
                        if let h = hash(items[i]) { local[ObjectIdentifier(items[i])] = h }
                    }
                    state.lock.lock(); state.processed += (end - start); let done = state.processed; state.lock.unlock()
                    onProgress(done)
                }
                state.lock.lock(); state.merged.merge(local) { a, _ in a }; state.lock.unlock()
                group.leave()
            }
        }
        group.wait()
        return state.merged
    }

    // MARK: Hashing

    /// Files at or below this size are hashed in FULL (exact, and cheap to read).
    private static let exactThreshold: Int64 = 1 * 1024 * 1024
    private static let edgeChunk = 256 * 1024     // 256 KB head + 256 KB tail
    private static let midSamples = 4             // evenly-spaced interior samples
    private static let midChunk = 128 * 1024

    /// Content fingerprint of a file. ≤ exactThreshold → full SHA-256 (definitive).
    /// Larger → size + 256 KB head + 256 KB tail + 4 interior 128 KB samples (≤ ~1 MB
    /// read regardless of file size). This is only a *cheap candidate filter*: two
    /// genuinely different large files can share these sampled windows (common for
    /// video/disk-image/VM/zero-padded files differing only in unsampled bytes), so a
    /// sampled match is NEVER trusted on its own. Before any large-file group is
    /// surfaced for staging/deletion, `verifyExactGroups` re-reads the candidates in
    /// full, byte-for-byte, and splits apart any that aren't truly identical.
    private static func signature(of node: FileNode, size: Int64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: node.url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        withUnsafeBytes(of: size.littleEndian) { hasher.update(data: Data($0)) }

        if size <= exactThreshold {
            while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            hasher.update(data: Data([0x46]))   // 'F' — tag: full/exact
            return hex(hasher.finalize())
        }

        if let head = try? handle.read(upToCount: edgeChunk) { hasher.update(data: head) }
        let interior = size - Int64(2 * edgeChunk)
        if interior > 0 {
            for i in 1 ... midSamples {
                let offset = UInt64(Int64(edgeChunk) + interior * Int64(i) / Int64(midSamples + 1))
                if (try? handle.seek(toOffset: offset)) != nil,
                   let chunk = try? handle.read(upToCount: midChunk) {
                    hasher.update(data: chunk)
                }
            }
        }
        if (try? handle.seek(toOffset: UInt64(size - Int64(edgeChunk)))) != nil,
           let tail = try? handle.read(upToCount: edgeChunk) {
            hasher.update(data: tail)
        }
        hasher.update(data: Data([0x53]))       // 'S' — tag: sampled
        return hex(hasher.finalize())
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Triage (which copy to keep) — on-device heuristic

enum DuplicateTriage {
    /// Rank the copies and pick the "best original" to keep — preferring permanent
    /// locations over Downloads/Desktop/Trash and un-marked names over "copy"/"(1)".
    static func recommendKeeper(_ files: [FileNode]) -> (index: Int, reason: String) {
        guard !files.isEmpty else { return (0, "") }
        var best = 0
        var bestScore = Int.min
        for (i, f) in files.enumerated() {
            let s = score(f)
            if s > bestScore { bestScore = s; best = i }
        }
        return (best, reason(for: files[best], among: files))
    }

    private static func score(_ node: FileNode) -> Int {
        var s = 0
        switch locationClass(node.url.path.lowercased()) {
        case "trash":               s -= 1000
        case "downloads":           s -= 40
        case "desktop":             s -= 30
        case "caches", "library":   s -= 25
        case "documents":           s += 30
        case "pictures", "movies", "music": s += 20
        case "cloud":               s += 10
        default: break
        }
        if hasCopyMarker(node.name.lowercased()) { s -= 25 }
        s -= node.url.pathComponents.count   // shallower path = more canonical
        return s
    }

    private static func reason(for keeper: FileNode, among files: [FileNode]) -> String {
        let otherLocs = Set(files.filter { $0.id != keeper.id }
            .map { locationClass($0.url.path.lowercased()) })
        if otherLocs.contains("trash") { return "Other copies are in the Trash." }
        if otherLocs.contains("downloads") { return "Other copies are in Downloads." }
        if otherLocs.contains("desktop") { return "Other copies are on the Desktop." }
        switch locationClass(keeper.url.path.lowercased()) {
        case "documents": return "Keeping the copy in Documents."
        case "pictures":  return "Keeping the copy in Pictures."
        default:          return "Keeping the most permanently-located copy."
        }
    }

    static func locationClass(_ lowerPath: String) -> String {
        if lowerPath.contains("/.trash") { return "trash" }
        if lowerPath.contains("/downloads/") { return "downloads" }
        if lowerPath.contains("/desktop/") { return "desktop" }
        if lowerPath.contains("/documents/") { return "documents" }
        if lowerPath.contains("/pictures/") { return "pictures" }
        if lowerPath.contains("/movies/") { return "movies" }
        if lowerPath.contains("/music/") { return "music" }
        if lowerPath.contains("/caches/") { return "caches" }
        if lowerPath.contains("/library/") { return "library" }
        if lowerPath.contains("/cloudstorage/") || lowerPath.contains("/mobile documents/") { return "cloud" }
        if lowerPath.contains("/volumes/") { return "external" }
        return "other"
    }

    static func hasCopyMarker(_ lowerName: String) -> Bool {
        lowerName.contains("copy") || lowerName.contains("duplicate")
            || lowerName.range(of: #"\(\d+\)"#, options: .regularExpression) != nil
    }
}
