import Foundation

// MARK: - Large & Old Files finder
//
// A pure walk over the assembled tree that surfaces individual regular files
// matching size/age/kind filters — the long tail of big, stale files (old video
// exports, forgotten installers, stale archives) that the rule-based cleanup
// can't name. Like every other tool here it only *finds*; nothing is deleted,
// and a match becomes actionable only once the user stages it in the collector.
//
// `modTime` is epoch NANOSECONDS (0 = unknown). Age filtering compares against a
// nanosecond cutoff; files with an unknown modTime are excluded whenever an age
// filter is set, since we can't prove they're old enough.

enum LargeOldFiles {

    /// Filters that narrow the result set. All are optional; `nil` means "no
    /// constraint on this axis".
    struct Query: Sendable, Equatable {
        /// Minimum allocated size in bytes (inclusive).
        var minSizeBytes: Int64?
        /// Maximum age in days: a file qualifies only if it was last modified at
        /// least this many days ago. Files with `modTime == 0` are excluded when set.
        var maxAgeDays: Int?
        /// Restrict to a single content kind (image, video, …). `nil` = all kinds.
        var kind: FileKind?

        static let empty = Query()
    }

    /// Cap on returned matches so a huge tree can't flood the UI; the largest
    /// files are by far the interesting ones, so we sort first and then cap.
    static let resultCap = 500

    /// Walk `root`, collecting non-synthetic regular files that pass every set
    /// filter, sorted largest-first and capped at `limit`.
    ///
    /// Pure and unit-testable: `nowEpochSeconds` is injected (defaults to the
    /// current wall clock) so age filtering is deterministic in tests.
    static func find(root: FileNode,
                     query: Query,
                     nowEpochSeconds: Int64 = Int64(Date().timeIntervalSince1970),
                     limit: Int = resultCap) -> [FileNode] {
        // Age cutoff in nanoseconds: a file qualifies when modTime <= cutoffNanos.
        let cutoffNanos: Int64? = query.maxAgeDays.map { days in
            (nowEpochSeconds - Int64(days) * 86_400) * 1_000_000_000
        }
        let minSize = query.minSizeBytes
        let kindFilter = query.kind

        var matches: [FileNode] = []
        // Iterative pre-order walk; packages are leaves for this tool (the Finder
        // treats them as a single file, and FileKind classifies them as such).
        var stack: [FileNode] = root.children.reversed()
        while let node = stack.popLast() {
            if node.isSynthetic { continue }

            if node.isDirectory && node.kind != .package {
                stack.append(contentsOf: node.children)
                continue
            }

            // A regular file (or a package, treated as a file leaf).
            if let minSize, node.size < minSize { continue }
            if let cutoffNanos {
                // Unknown modTime can't satisfy an age limit.
                if node.modTime == 0 || node.modTime > cutoffNanos { continue }
            }
            if let kindFilter, FileKind.classify(node: node) != kindFilter { continue }

            matches.append(node)
        }

        matches.sort { $0.size > $1.size }
        if matches.count > limit { matches.removeLast(matches.count - limit) }
        return matches
    }
}
