import Testing
import Foundation
@testable import StorageOptimizer

// MARK: - Helpers

private func allocatedSize(at path: String) -> Int64 {
    var sb = Darwin.stat()
    guard Darwin.lstat(path, &sb) == 0 else { return 0 }
    return Int64(sb.st_blocks) * 512
}

/// Create a unique temp directory; callers remove it in a defer.
private func makeTempDir() throws -> URL {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base
}

/// Total bytes of all non-synthetic file nodes in a subtree.
private func sumRealBytes(_ node: FileNode) -> Int64 {
    guard !node.isSynthetic else { return 0 }
    if node.isDirectory {
        return node.children.reduce(0) { $0 + sumRealBytes($1) }
    }
    return node.size
}

/// True if any node in the subtree is a synthetic hidden-space node.
private func hasHiddenSpace(_ node: FileNode) -> Bool {
    node.children.contains(where: { $0.kind == .hiddenSpace || hasHiddenSpace($0) })
}

@Suite("Engine Tests")
struct EngineTests {

    // MARK: 1 — correctSizes

    @Test("Each FileNode size equals lstat-derived allocated size; parents aggregate exactly")
    func correctSizes() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            // Build: base/a/file1.txt  base/a/b/file2.txt
            let aDir = base.appendingPathComponent("a", isDirectory: true)
            let bDir = aDir.appendingPathComponent("b", isDirectory: true)
            try FileManager.default.createDirectory(at: aDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: bDir, withIntermediateDirectories: true)

            let file1 = aDir.appendingPathComponent("file1.txt")
            let file2 = bDir.appendingPathComponent("file2.txt")
            try Data(repeating: 0xAB, count: 4096).write(to: file1)
            try Data(repeating: 0xCD, count: 8192).write(to: file2)

            let expectedFile1 = allocatedSize(at: file1.path)
            let expectedFile2 = allocatedSize(at: file2.path)
            #expect(expectedFile1 > 0)
            #expect(expectedFile2 > 0)

            let root = try await FileScanner.scan(url: base) { _ in }

            // Find a/ node
            guard let aNode = root.children.first(where: { $0.name == "a" }) else {
                Issue.record("Missing 'a' directory node")
                return
            }
            // Find b/ inside a/
            guard let bNode = aNode.children.first(where: { $0.name == "b" }) else {
                Issue.record("Missing 'b' directory node inside 'a'")
                return
            }
            // Find files
            guard let f1 = aNode.children.first(where: { $0.name == "file1.txt" }),
                  let f2 = bNode.children.first(where: { $0.name == "file2.txt" }) else {
                Issue.record("Missing file nodes")
                return
            }

            #expect(f1.size == expectedFile1)
            #expect(f2.size == expectedFile2)
            // b/ aggregates file2
            #expect(bNode.size == expectedFile2)
            // a/ aggregates file1 + b/
            #expect(aNode.size == expectedFile1 + expectedFile2)
        }
    }

    @Test("Scanner records per-file modification time in nanoseconds (enables age filters)")
    func fileModTime() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("doc.txt")
        try Data(repeating: 0x01, count: 1024).write(to: file)

        var sb = Darwin.stat()
        #expect(Darwin.lstat(file.path, &sb) == 0)
        let expectedSec = Int64(sb.st_mtimespec.tv_sec)

        let root = try await FileScanner.scan(url: base) { _ in }
        guard let node = root.children.first(where: { $0.name == "doc.txt" }) else {
            Issue.record("missing file node"); return
        }
        #expect(node.modTime > 0)                              // was always 0 before
        #expect(node.modTime / 1_000_000_000 == expectedSec)  // ns → s matches lstat
    }

    // MARK: 2 — hardlinksCountedOnce

    @Test("Hard-linked file allocation is counted exactly once")
    func hardlinksCountedOnce() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            let dirA = base.appendingPathComponent("dirA", isDirectory: true)
            let dirB = base.appendingPathComponent("dirB", isDirectory: true)
            try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)

            let original = dirA.appendingPathComponent("bigfile.dat")
            // 1 MB of data
            try Data(repeating: 0xFF, count: 1 << 20).write(to: original)
            let expectedSize = allocatedSize(at: original.path)

            let link = dirB.appendingPathComponent("hardlink.dat")
            try FileManager.default.linkItem(at: original, to: link)

            let root = try await FileScanner.scan(url: base) { _ in }

            let total = sumRealBytes(root)
            #expect(total == expectedSize,
                    "Expected \(expectedSize) bytes (one copy), got \(total)")
        }
    }

    // MARK: 3 — symlinksSkipped

    @Test("Symlinks contribute 0 bytes and produce no FileNode")
    func symlinksSkipped() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            // Create a big target outside the scan dir
            let outsideDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: outsideDir) }

            let bigFile = outsideDir.appendingPathComponent("big.dat")
            try Data(repeating: 0xBB, count: 1 << 20).write(to: bigFile)

            // Symlink inside scan root pointing to the big file
            let link = base.appendingPathComponent("link_to_big")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bigFile)

            let root = try await FileScanner.scan(url: base) { _ in }

            // No child should be a symlink or have the symlink's name
            let symNode = root.children.first(where: { $0.name == "link_to_big" })
            #expect(symNode == nil, "Symlink should produce no FileNode")

            #expect(sumRealBytes(root) == 0)
        }
    }

    // MARK: 4 — packagesAreScanned

    @Test("A .app directory is classified as .package and its size includes all nested contents")
    func packagesAreScanned() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            let appBundle = base.appendingPathComponent("Demo.app", isDirectory: true)
            let resDir = appBundle.appendingPathComponent("Resources", isDirectory: true)
            try FileManager.default.createDirectory(at: resDir, withIntermediateDirectories: true)

            // Two files at different depths inside the bundle
            let binary = appBundle.appendingPathComponent("Demo")
            try Data(repeating: 0xEE, count: 4096).write(to: binary)
            let asset = resDir.appendingPathComponent("asset.bin")
            try Data(repeating: 0xAA, count: 8192).write(to: asset)

            let expectedBinarySize = allocatedSize(at: binary.path)
            let expectedAssetSize  = allocatedSize(at: asset.path)
            let expectedTotal = expectedBinarySize + expectedAssetSize

            let root = try await FileScanner.scan(url: base) { _ in }

            guard let appNode = root.children.first(where: { $0.name == "Demo.app" }) else {
                Issue.record("Demo.app node not found")
                return
            }

            #expect(appNode.kind == .package)
            #expect(appNode.size == expectedTotal,
                    "Package size \(appNode.size) != sum of both files \(expectedTotal)")
        }
    }

    // MARK: 5 — progressCompletes

    @Test("Final ScanProgress has fraction == 1.0 and bytesFound == root.size")
    func progressCompletes() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            // Create 120 small dirs each containing one tiny file
            for i in 0..<120 {
                let d = base.appendingPathComponent("d\(i)", isDirectory: true)
                try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
                try Data(repeating: UInt8(i & 0xFF), count: 512)
                    .write(to: d.appendingPathComponent("f.dat"))
            }

            // Thread-safe accumulator
            final class Box: @unchecked Sendable {
                var last = ScanProgress()
                let lock = NSLock()
                func update(_ p: ScanProgress) { lock.withLock { last = p } }
                func read() -> ScanProgress { lock.withLock { last } }
            }
            let box = Box()

            let root = try await FileScanner.scan(url: base) { p in
                box.update(p)
            }

            let finalProg = box.read()

            // fraction must be 1.0 at end
            if let frac = finalProg.fraction {
                #expect(frac == 1.0, "Expected fraction 1.0, got \(frac)")
            }
            // bytesFound must equal the real (non-synthetic) byte total
            #expect(finalProg.bytesFound == sumRealBytes(root),
                    "bytesFound \(finalProg.bytesFound) != sumRealBytes \(sumRealBytes(root))")
            // root.size must match sumRealBytes (no hidden space for a plain folder scan)
            #expect(root.size == sumRealBytes(root),
                    "root.size \(root.size) != sumRealBytes \(sumRealBytes(root))")
        }
    }

    // MARK: 6 — noHiddenSpaceForFolders

    @Test("Scanning a plain folder produces no .hiddenSpace child")
    func noHiddenSpaceForFolders() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            let sub = base.appendingPathComponent("sub", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            try Data(repeating: 0x01, count: 1024).write(to: sub.appendingPathComponent("f.bin"))

            let root = try await FileScanner.scan(url: base) { _ in }

            #expect(!hasHiddenSpace(root))
        }
    }

    // MARK: 6b — materialized cloud content is scanned

    @Test("Materialized files under a CloudStorage-named path ARE scanned and counted")
    func cloudStorageMaterializedFilesAreScanned() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }

        // Mimic ~/Library/CloudStorage/<provider>/<deep file> with REAL local
        // (materialized) files — no dataless seam — and a normal sibling.
        // Datalessness, not the path name, is now the signal, so these are scanned.
        let fm = FileManager.default
        let cloudRoot = base.appendingPathComponent("Library/CloudStorage", isDirectory: true)
        let providerDeep = cloudRoot.appendingPathComponent("Nextcloud-acct/music/album", isDirectory: true)
        try fm.createDirectory(at: providerDeep, withIntermediateDirectories: true)
        let track = providerDeep.appendingPathComponent("track.flac")
        try Data(repeating: 0x01, count: 8192).write(to: track)

        let normal = base.appendingPathComponent("Library/Application Support/app", isDirectory: true)
        try fm.createDirectory(at: normal, withIntermediateDirectories: true)
        try Data(repeating: 0x02, count: 4096).write(to: normal.appendingPathComponent("data.bin"))

        let root = try await FileScanner.scan(url: base) { _ in }

        func find(_ node: FileNode, named name: String) -> FileNode? {
            if node.name == name { return node }
            for c in node.children { if let hit = find(c, named: name) { return hit } }
            return nil
        }
        // The CloudStorage container is now descended (it's materialized).
        let cloud = find(root, named: "CloudStorage")
        #expect(cloud != nil)
        #expect(cloud?.kind != .cloudOnlyStorage)
        #expect(cloud?.children.isEmpty == false)            // descended now
        // The deep materialized file is found and counted.
        let trackNode = find(root, named: "track.flac")
        #expect(trackNode != nil)
        #expect(trackNode?.size == allocatedSize(at: track.path))
        // The normal sibling is still scanned.
        #expect(find(root, named: "data.bin") != nil)
        #expect(sumRealBytes(root) > 0)
    }

    // MARK: 6c — dataless (online-only) items via the test seam

    @Test("Dataless files are excluded; a dataless directory becomes a .cloudOnlyStorage boundary")
    func datalessItemsAreHandled() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }

        let fm = FileManager.default

        // Materialized (kept) file + dataless (online-only) file as siblings.
        let keptFile = base.appendingPathComponent("kept.bin")
        try Data(repeating: 0xAA, count: 8192).write(to: keptFile)
        let onlineFile = base.appendingPathComponent("ghost.online")     // marked dataless
        try Data(repeating: 0xBB, count: 8192).write(to: onlineFile)

        // Materialized directory (descended) with a real file inside.
        let keptDir = base.appendingPathComponent("kept.dir", isDirectory: true)
        try fm.createDirectory(at: keptDir, withIntermediateDirectories: true)
        let inner = keptDir.appendingPathComponent("inner.bin")
        try Data(repeating: 0xCC, count: 4096).write(to: inner)

        // Dataless directory placeholder (must NOT be descended). It has a real
        // file inside on disk to prove its contents are NOT counted (descending it
        // is exactly what the boundary node avoids).
        let onlineDir = base.appendingPathComponent("cloudfolder.online", isDirectory: true)
        try fm.createDirectory(at: onlineDir, withIntermediateDirectories: true)
        try Data(repeating: 0xDD, count: 16384).write(to: onlineDir.appendingPathComponent("hidden.bin"))

        // The seam matches a single suffix; both the online file and the online
        // directory end in ".online", so one seam covers both.
        BulkDirScanner._testDatalessSuffix = ".online"
        defer { BulkDirScanner._testDatalessSuffix = nil }

        let expectedKeptFile = allocatedSize(at: keptFile.path)
        let expectedInner = allocatedSize(at: inner.path)

        let root = try await FileScanner.scan(url: base) { _ in }

        func find(_ node: FileNode, named name: String) -> FileNode? {
            if node.name == name { return node }
            for c in node.children { if let hit = find(c, named: name) { return hit } }
            return nil
        }

        // Dataless file excluded entirely (no node).
        #expect(find(root, named: "ghost.online") == nil)

        // Dataless directory → boundary node, size 0, NOT descended.
        let onlineDirNode = find(root, named: "cloudfolder.online")
        #expect(onlineDirNode != nil)
        #expect(onlineDirNode?.kind == .cloudOnlyStorage)
        #expect(onlineDirNode?.size == 0)
        #expect(onlineDirNode?.children.isEmpty == true)
        #expect(find(root, named: "hidden.bin") == nil)   // contents not scanned

        // Materialized file counted.
        let kept = find(root, named: "kept.bin")
        #expect(kept != nil)
        #expect(kept?.size == expectedKeptFile)

        // Materialized directory descended and its inner file counted.
        let innerNode = find(root, named: "inner.bin")
        #expect(innerNode != nil)
        #expect(innerNode?.size == expectedInner)

        // Sum of real bytes excludes the dataless file & the dataless dir contents.
        #expect(sumRealBytes(root) == expectedKeptFile + expectedInner)
    }

    // MARK: 7 — cancellation

    @Test("Cancelling a large scan throws CancellationError or completes without other errors")
    func cancellation() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            // Create ~2000 dirs
            for i in 0..<2000 {
                let d = base.appendingPathComponent("d\(i)", isDirectory: true)
                try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            }

            let task = Task<FileNode, Error> {
                try await FileScanner.scan(url: base) { _ in }
            }
            // Cancel almost immediately
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            task.cancel()

            do {
                _ = try await task.value
                // Completed before cancellation took effect — that's fine
            } catch is CancellationError {
                // Expected path
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: 8 — emptyDirectory

    @Test("Scanning an empty directory returns a node with size 0 and no children",
          .timeLimit(.minutes(1)))
    func emptyDirectory() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            let root = try await FileScanner.scan(url: base) { _ in }
            #expect(root.isDirectory)
            // Filter out any synthetic nodes
            let realChildren = root.children.filter { !$0.isSynthetic }
            #expect(realChildren.isEmpty)
            // Size is 0 (no real files)
            let realSize = root.children.filter { !$0.isSynthetic }.reduce(Int64(0)) { $0 + $1.size }
            #expect(realSize == 0)
        }
    }

    // MARK: 9 — bulkScannerFallbackParity

    @Test("BulkDirScanner.entries names/types/sizes match FileManager + lstat ground truth")
    func bulkScannerFallbackParity() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            // Create a mixed fixture: files and a subdirectory
            try Data(repeating: 0xAA, count: 2048).write(to: base.appendingPathComponent("a.bin"))
            try Data(repeating: 0xBB, count: 4096).write(to: base.appendingPathComponent("b.bin"))
            let sub = base.appendingPathComponent("sub", isDirectory: true)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            // symlink — both impls should see it as symlink / skip
            let syml = base.appendingPathComponent("link")
            try FileManager.default.createSymbolicLink(
                at: syml, withDestinationURL: base.appendingPathComponent("a.bin"))

            // Ground truth via FileManager + lstat
            let fmNames = try FileManager.default.contentsOfDirectory(atPath: base.path)
            var groundTruth: [String: (type: EntryInfo.EntryType, alloc: Int64)] = [:]
            for name in fmNames {
                let fullPath = base.path + "/" + name
                var sb = Darwin.stat()
                guard Darwin.lstat(fullPath, &sb) == 0 else { continue }
                let mode = sb.st_mode & S_IFMT
                let t: EntryInfo.EntryType
                if mode == S_IFLNK      { t = .symlink }
                else if mode == S_IFDIR { t = .directory }
                else if mode == S_IFREG { t = .file }
                else                    { t = .other }
                groundTruth[name] = (t, Int64(sb.st_blocks) * 512)
            }

            let bulk = BulkDirScanner.entries(atPath: base.path)

            // Every bulk entry must appear in ground truth with matching type and alloc size
            for entry in bulk {
                guard let gt = groundTruth[entry.name] else {
                    Issue.record("BulkDirScanner returned entry '\(entry.name)' not in ground truth")
                    continue
                }
                #expect(entry.type == gt.type,
                        "Type mismatch for '\(entry.name)': bulk=\(entry.type) gt=\(gt.type)")
                if entry.type == .file {
                    #expect(entry.allocatedSize == gt.alloc,
                            "AllocSize mismatch for '\(entry.name)': bulk=\(entry.allocatedSize) gt=\(gt.alloc)")
                }
            }

            // Every ground-truth entry must appear in bulk output
            for name in groundTruth.keys {
                let found = bulk.contains(where: { $0.name == name })
                #expect(found, "Ground-truth entry '\(name)' missing from BulkDirScanner output")
            }
        }
    }

    // MARK: 10 — timedEntriesTimesOut

    @Test("BulkDirScanner.timedEntries returns nil for a stalled directory and non-nil for a normal one")
    func timedEntriesTimesOut() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }

        // A file so the directory is not empty
        try Data(repeating: 0x01, count: 512).write(to: base.appendingPathComponent("file.dat"))

        // Point the delay at the last path component of our temp dir
        let suffix = base.lastPathComponent
        BulkDirScanner._testDelay = (pathSuffix: suffix, seconds: 1.0)
        defer { BulkDirScanner._testDelay = nil }

        let start = ContinuousClock.now
        let result = await BulkDirScanner.timedEntries(atPath: base.path, timeoutSeconds: 0.2)
        let elapsed = ContinuousClock.now - start

        #expect(result == nil, "Expected nil (timeout) for delayed directory")
        #expect(elapsed < .seconds(1.5), "timedEntries should return well before the 1s delay fires")

        // A separate, non-delayed directory should return a real listing
        let other = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: other) }
        try Data(repeating: 0x02, count: 512).write(to: other.appendingPathComponent("f.dat"))
        let normalResult = await BulkDirScanner.timedEntries(atPath: other.path, timeoutSeconds: 5)
        #expect(normalResult != nil, "Non-delayed path should return entries")
    }

    // MARK: 11 — scanSkipsTimedOutDirectory

    @Test("FileScanner.scan completes when one sibling directory stalls and marks it as childless")
    func scanSkipsTimedOutDirectory() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }

        // Three sibling dirs: alpha, slowdir, gamma
        let alpha   = base.appendingPathComponent("alpha",   isDirectory: true)
        let slowdir = base.appendingPathComponent("slowdir", isDirectory: true)
        let gamma   = base.appendingPathComponent("gamma",   isDirectory: true)
        for dir in [alpha, slowdir, gamma] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let alphaFile   = alpha.appendingPathComponent("a.dat")
        let slowFile    = slowdir.appendingPathComponent("s.dat")
        let gammaFile   = gamma.appendingPathComponent("g.dat")
        try Data(repeating: 0xAA, count: 4096).write(to: alphaFile)
        try Data(repeating: 0xBB, count: 4096).write(to: slowFile)
        try Data(repeating: 0xCC, count: 4096).write(to: gammaFile)

        let expectedAlpha = allocatedSize(at: alphaFile.path)
        let expectedGamma = allocatedSize(at: gammaFile.path)

        BulkDirScanner._testDelay = (pathSuffix: "slowdir", seconds: 1.5)
        BulkDirScanner._timeoutSecondsOverride = 0.3
        defer {
            BulkDirScanner._testDelay = nil
            BulkDirScanner._timeoutSecondsOverride = nil
        }

        final class ProgressBox: @unchecked Sendable {
            var last = ScanProgress()
            let lock = NSLock()
            func update(_ p: ScanProgress) { lock.withLock { last = p } }
            func read() -> ScanProgress { lock.withLock { last } }
        }
        let box = ProgressBox()

        let root = try await FileScanner.scan(url: base) { p in box.update(p) }

        // alpha and gamma must have the right sizes
        guard let alphaNode = root.children.first(where: { $0.name == "alpha" }) else {
            Issue.record("alpha node missing"); return
        }
        guard let gammaNode = root.children.first(where: { $0.name == "gamma" }) else {
            Issue.record("gamma node missing"); return
        }
        guard let slowNode = root.children.first(where: { $0.name == "slowdir" }) else {
            Issue.record("slowdir node missing"); return
        }

        #expect(alphaNode.size == expectedAlpha,
                "alpha size \(alphaNode.size) != expected \(expectedAlpha)")
        #expect(gammaNode.size == expectedGamma,
                "gamma size \(gammaNode.size) != expected \(expectedGamma)")
        // slowdir timed out — its entries were never enumerated
        #expect(slowNode.children.isEmpty, "slowdir should have no children after timeout")

        // Progress fraction must reach 1.0
        let finalProg = box.read()
        if let frac = finalProg.fraction {
            #expect(frac == 1.0, "Final fraction should be 1.0, got \(frac)")
        }
    }

    // MARK: 12 — hardlinksAcrossLevels

    @Test("Hard-linked file is counted once when link is one BFS level deeper than original")
    func hardlinksAcrossLevels() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }

        // base/a/file.dat  (original)
        // base/a/b/link.dat  (hard link — one BFS level deeper than the original)
        let aDir = base.appendingPathComponent("a", isDirectory: true)
        let bDir = aDir.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: bDir, withIntermediateDirectories: true)

        let original = aDir.appendingPathComponent("file.dat")
        try Data(repeating: 0xDE, count: 1 << 20).write(to: original)
        let expectedSize = allocatedSize(at: original.path)

        let link = bDir.appendingPathComponent("link.dat")
        try FileManager.default.linkItem(at: original, to: link)

        let root = try await FileScanner.scan(url: base) { _ in }

        let total = sumRealBytes(root)
        #expect(total == expectedSize,
                "Expected \(expectedSize) bytes (one allocation), got \(total)")
    }

    @Test("CleanupClassifier: safe vs review tiers, nested matches subsumed, synthetic skipped")
    func cleanupClassification() {
        let home = URL(fileURLWithPath: "/Users/test")
        let root = FileNode(url: home, name: "test", isDirectory: true, size: 0)

        let proj = FileNode(name: "proj", isDirectory: true, size: 0)
        let nm = FileNode(name: "node_modules", isDirectory: true, size: 100)
        let nmNested = FileNode(name: "node_modules", isDirectory: true, size: 30) // nested → subsumed
        nm.setChildren([nmNested])
        proj.setChildren([nm])

        let downloads = FileNode(name: "Downloads", isDirectory: true, size: 200)
        let hidden = FileNode(url: home, name: "Hidden Space", isDirectory: false, size: 999, kind: .hiddenSpace)
        root.setChildren([proj, downloads, hidden])

        let report = CleanupClassifier.classify(root: root)

        // node_modules → safe, counted once (nested instance subsumed, not double-counted)
        let nmGroup = report.safeGroups.first { $0.category.id == "dev.node_modules" }
        #expect(nmGroup?.nodes.count == 1)
        #expect(nmGroup?.totalBytes == 100)
        #expect(report.safeTotalBytes == 100)

        // Downloads → review tier, never swept into the safe (one-button) set
        #expect(report.reviewGroups.contains { $0.category.id == "user.downloads" })
        #expect(report.safeNodes.allSatisfy { $0.name.lowercased() != "downloads" })

        // synthetic nodes are never classified
        #expect(report.groups.allSatisfy { g in g.nodes.allSatisfy { !$0.isSynthetic } })
    }

    @Test("Incremental re-scan: unchanged subtree reused (same total), change detected")
    func incrementalRescan() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let sub = base.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(count: 1_000_000).write(to: sub.appendingPathComponent("a.bin"))

        let full = try await FileScanner.scan(url: base) { _ in }
        let incremental = try await FileScanner.scan(url: base, cache: full) { _ in }
        #expect(incremental.size == full.size)   // unchanged → reuse → identical total

        // Add a file to sub: its modtime changes, so it must be re-scanned.
        try await Task.sleep(for: .milliseconds(20))
        try Data(count: 2_000_000).write(to: sub.appendingPathComponent("b.bin"))
        let afterChange = try await FileScanner.scan(url: base, cache: incremental) { _ in }
        let freshFull = try await FileScanner.scan(url: base) { _ in }
        #expect(afterChange.size == freshFull.size, "incremental must match a full re-scan after a change")
        #expect(afterChange.size > full.size)
    }

    // MARK: Natural-language cleanup

    @Test("CleanupQueryParser extracts size target, min size, age, and categories")
    func nlParser() {
        let gib: Int64 = 1 << 30
        let q = CleanupQueryParser.parse("free up 50 GB of caches bigger than 1gb older than 6 months")
        #expect(q.targetFreeBytes == 50 * gib)
        #expect(q.minSizeBytes == gib)
        #expect(q.maxAgeDays == 180)
        #expect(q.categoryIDs.contains(CleanupCatalog.userCaches.id))

        // "keep my projects" removes build output from a dev-junk sweep.
        let dev = CleanupQueryParser.parse("clear dev junk but keep my projects")
        #expect(dev.categoryIDs.contains(CleanupCatalog.nodeModules.id))
        #expect(!dev.categoryIDs.contains(CleanupCatalog.buildOutput.id))

        // "6 months" must not be misread as a size in megabytes.
        let age = CleanupQueryParser.parse("anything older than a year")
        #expect(age.maxAgeDays == 365)
        #expect(age.minSizeBytes == nil)
        #expect(age.targetFreeBytes == nil)
    }

    @Test("CleanupQueryEngine filters by size/age and caps at the free target, largest-first")
    func nlEngine() {
        let cache = CleanupCatalog.userCaches
        let big = FileNode(name: "BigCache", isDirectory: true, size: 5_000_000_000)
        let small = FileNode(name: "SmallCache", isDirectory: true, size: 100)
        let report = CleanupReport(matches: [(cache, big), (cache, small)])

        var q = CleanupQuery.empty
        q.categoryIDs = [cache.id]
        q.minSizeBytes = 1000
        let bySize = CleanupQueryEngine.execute(q, report: report, nowEpoch: 1_000_000)
        #expect(bySize.count == 1)            // SmallCache (100 B) filtered out
        #expect(bySize.first === big)

        var capped = CleanupQuery.empty
        capped.categoryIDs = [cache.id]
        capped.targetFreeBytes = 1            // tiny target → only the largest node
        let byTarget = CleanupQueryEngine.execute(capped, report: report, nowEpoch: 1)
        #expect(byTarget.count == 1)
        #expect(byTarget.first === big)       // largest-first

        // Age filter: modTime is epoch NANOSECONDS, nowEpoch is seconds. Nodes with
        // modTime 0 (unknown) never match an age limit.
        let ns: Int64 = 1_000_000_000
        let oldFile = FileNode(name: "old", isDirectory: false, size: 1000, modTime: 100 * ns)
        let newFile = FileNode(name: "new", isDirectory: false, size: 1000, modTime: 1_000_000 * ns)
        let unknown = FileNode(name: "unknown", isDirectory: false, size: 1000, modTime: 0)
        let ageReport = CleanupReport(matches: [(cache, oldFile), (cache, newFile), (cache, unknown)])
        var ageQ = CleanupQuery.empty
        ageQ.categoryIDs = [cache.id]
        ageQ.maxAgeDays = 1                   // cutoff = (now - 86_400) seconds
        let byAge = CleanupQueryEngine.execute(ageQ, report: ageReport, nowEpoch: 1_000_000)
        #expect(byAge.count == 1)
        #expect(byAge.first === oldFile)
    }

    @Test("LocalAI.extractJSONObject pulls the JSON out of prose/fenced model output")
    func jsonExtraction() {
        let wrapped = "Sure! Here you go:\n```json\n{\"a\": 1, \"b\": \"x}y\"}\n```\nhope that helps"
        #expect(LocalAI.extractJSONObject(wrapped) == "{\"a\": 1, \"b\": \"x}y\"}")
        #expect(LocalAI.extractJSONObject("no json here") == nil)
    }

    @Test("IntentPlanner.parse maps model JSON (MB→bytes) and falls back when trivial")
    func intentParse() {
        let gib: Int64 = 1 << 30
        let text = "```json\n{\"categoryIDs\":[\"system.caches\"],\"includeReviewTier\":false,\"maxAgeDays\":0,\"minSizeMB\":0,\"targetFreeMB\":1024,\"summary\":\"Free 1 GB of caches.\"}\n```"
        let q = IntentPlanner.parse(text, fallback: .empty)
        #expect(q?.categoryIDs == ["system.caches"])
        #expect(q?.targetFreeBytes == gib)
        #expect(q?.maxAgeDays == nil)            // 0 → nil
        #expect(q?.summary == "Free 1 GB of caches.")

        // A trivial model result defers to a non-trivial keyword fallback.
        var fallback = CleanupQuery.empty
        fallback.categoryIDs = ["system.logs"]
        let trivial = IntentPlanner.parse("{\"categoryIDs\":[],\"includeReviewTier\":false,\"maxAgeDays\":0,\"minSizeMB\":0,\"targetFreeMB\":0,\"summary\":\"\"}", fallback: fallback)
        #expect(trivial?.categoryIDs == ["system.logs"])
    }

    @Test("SmartCleanupClassifier.parse reads verdict JSON")
    func smartParse() {
        let text = "{\"verdicts\":[{\"index\":0,\"safeToDelete\":true,\"category\":\"cache\",\"confidence\":88}]}"
        let verdicts = SmartCleanupClassifier.parse(text)
        #expect(verdicts?.count == 1)
        #expect(verdicts?.first?.safeToDelete == true)
        #expect(verdicts?.first?.category == "cache")

        // Malformed / missing JSON → nil, never a crash.
        #expect(SmartCleanupClassifier.parse("not json at all") == nil)
        #expect(SmartCleanupClassifier.parse("{\"other\":1}") == nil)
    }

    @Test("SmartCleanupClassifier.candidates: size floor, deny-list, already-matched, synthetic, take-as-unit, cap")
    func smartCandidates() {
        let big: Int64 = 300 * 1024 * 1024      // above the default 200 MB floor
        let small: Int64 = 1024                  // below the floor

        let root = FileNode(url: URL(fileURLWithPath: "/Users/x"), name: "x", isDirectory: true, size: 0)

        // A big unmatched, non-sensitive directory → a candidate, taken as a unit.
        let mystery = FileNode(name: "MysteryBlob", isDirectory: true, size: big)
        let mysteryInner = FileNode(name: "InnerBlob", isDirectory: true, size: big) // must NOT also surface
        mystery.setChildren([mysteryInner])

        // A sensitive (deny-listed) big directory → never a candidate, never descended.
        let documents = FileNode(name: "Documents", isDirectory: true, size: big)
        let docInner = FileNode(name: "HugeUnknownThing", isDirectory: true, size: big) // hidden by deny-list
        documents.setChildren([docInner])

        // An already-classified big directory is skipped, but we still descend into it
        // to surface a big unmatched child within.
        let matchedDir = FileNode(name: "Caches", isDirectory: true, size: big)
        let buriedBig = FileNode(name: "BuriedBlob", isDirectory: true, size: big)
        matchedDir.setChildren([buriedBig])

        // A small directory is below the floor (not a candidate) but is descended.
        let smallWrap = FileNode(name: "smallwrap", isDirectory: true, size: small)
        let deepBig = FileNode(name: "DeepBlob", isDirectory: true, size: big)
        smallWrap.setChildren([deepBig])

        // A file (not a directory) and a synthetic node are never candidates.
        let bigFile = FileNode(name: "movie.mov", isDirectory: false, size: big)
        let hidden = FileNode(url: URL(fileURLWithPath: "/Users/x"), name: "Hidden Space",
                              isDirectory: true, size: big, kind: .hiddenSpace)

        root.setChildren([mystery, documents, matchedDir, smallWrap, bigFile, hidden])

        let result = SmartCleanupClassifier.candidates(
            root: root, excluding: [ObjectIdentifier(matchedDir)])
        let names = Set(result.map(\.name))

        #expect(names.contains("MysteryBlob"))
        #expect(!names.contains("InnerBlob"))            // parent taken as a unit, not descended
        #expect(!names.contains("Documents"))            // deny-listed
        #expect(!names.contains("HugeUnknownThing"))     // deny-listed dir not descended
        #expect(!names.contains("Caches"))               // already matched (excluded)
        #expect(names.contains("BuriedBlob"))            // descended into the matched dir
        #expect(names.contains("DeepBlob"))              // descended through the small wrapper
        #expect(!names.contains("smallwrap"))            // below the size floor
        #expect(!names.contains("movie.mov"))            // a file, not a directory
        #expect(!names.contains("Hidden Space"))         // synthetic

        // Sorted largest-first, capped by limit.
        let capped = SmartCleanupClassifier.candidates(root: root, excluding: [], limit: 1)
        #expect(capped.count == 1)
        // With the matched dir no longer excluded, the biggest unit wins (all equal size
        // here, so just assert the cap holds and only one item comes back).
        #expect(capped.allSatisfy { $0.size == big })
    }

    // MARK: Duplicate finder

    @Test("DuplicateFinder groups identical-content files and ignores unique ones")
    func dupeFinder() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let twoMB: Int64 = 2 * 1024 * 1024
        let dataA = Data(repeating: 0xAB, count: Int(twoMB))
        let dataB = Data(repeating: 0xCD, count: Int(twoMB))   // same size, different content
        try dataA.write(to: dir.appendingPathComponent("one.bin"))
        try dataA.write(to: dir.appendingPathComponent("two.bin"))
        try dataB.write(to: dir.appendingPathComponent("unique.bin"))

        let root = FileNode(url: dir, name: dir.lastPathComponent, isDirectory: true, size: 0)
        root.setChildren(["one.bin", "two.bin", "unique.bin"].map { name in
            FileNode(url: dir.appendingPathComponent(name), name: name, isDirectory: false, size: twoMB)
        })

        let groups = DuplicateFinder.find(root: root, minSize: 1) { _ in }
        #expect(groups.count == 1)            // unique.bin not grouped despite same size
        #expect(groups.first?.count == 2)
        #expect(groups.first?.reclaimableBytes == twoMB)
    }

    @Test("DuplicateFinder does NOT group large files that match only on sampled windows")
    func dupeFinderSampledCollisionRejected() throws {
        // Delete-safety regression: large files are fingerprinted from sampled regions
        // (256 KB head + 256 KB tail + 4 interior 128 KB samples). Two genuinely
        // different files that happen to match in those windows must still be split by
        // the mandatory byte-for-byte verification, so a real file is never offered for
        // permanent deletion as a "duplicate" of something it isn't.
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fiveMB = 5 * 1024 * 1024
        var base = Data(repeating: 0x7E, count: fiveMB)
        // True duplicate of `base`.
        let twin = base
        // Differ by a single byte at offset 300_000 — past the 256 KB head, before the
        // first interior sample (~1.19 MB), and far from the tail, so it lands in an
        // UNSAMPLED gap: identical sampled signature, different real content.
        base[300_000] = 0x01

        try base.write(to: dir.appendingPathComponent("a.bin"))
        try twin.write(to: dir.appendingPathComponent("b.bin"))   // duplicate of base-before-flip
        try twin.write(to: dir.appendingPathComponent("c.bin"))   // genuine dup of b.bin

        // a.bin differs from b.bin/c.bin only in the unsampled gap; b.bin and c.bin are
        // byte-identical. Correct result: ONE group of {b,c}, with a.bin excluded.
        let size = Int64(fiveMB)
        let root = FileNode(url: dir, name: dir.lastPathComponent, isDirectory: true, size: 0)
        root.setChildren(["a.bin", "b.bin", "c.bin"].map { name in
            FileNode(url: dir.appendingPathComponent(name), name: name, isDirectory: false, size: size)
        })

        let groups = DuplicateFinder.find(root: root, minSize: 1) { _ in }
        #expect(groups.count == 1)
        #expect(groups.first?.count == 2)     // only b.bin + c.bin, never a.bin
        let names = Set((groups.first?.files ?? []).map(\.name))
        #expect(names == ["b.bin", "c.bin"])
    }

    // MARK: File-kind classification

    @Test("FileKind.classify maps extensions and packages; breakdown aggregates regular files by kind")
    func fileKindClassifyAndBreakdown() {
        // classify(extension:) — case- and dot-insensitive, unknown → .other.
        #expect(FileKind.classify(extension: "JPG") == .image)
        #expect(FileKind.classify(extension: ".mp4") == .video)
        #expect(FileKind.classify(extension: "flac") == .audio)
        #expect(FileKind.classify(extension: "pdf") == .document)
        #expect(FileKind.classify(extension: "zip") == .archive)
        #expect(FileKind.classify(extension: "swift") == .code)
        #expect(FileKind.classify(extension: "qwertyz") == .other)
        #expect(FileKind.classify(extension: "") == .other)

        // classify(node:) — a package is .app regardless of its name's extension.
        let bundle = FileNode(name: "Demo.app", isDirectory: true, size: 500, kind: .package)
        #expect(FileKind.classify(node: bundle) == .app)
        let movie = FileNode(name: "clip.mov", isDirectory: false, size: 10)
        #expect(FileKind.classify(node: movie) == .video)

        // breakdown over an in-memory tree.
        let root = FileNode(url: URL(fileURLWithPath: "/tmp/t"), name: "t", isDirectory: true, size: 0)
        let sub = FileNode(name: "sub", isDirectory: true, size: 0)
        let img1 = FileNode(name: "a.png", isDirectory: false, size: 300)
        let img2 = FileNode(name: "b.jpg", isDirectory: false, size: 200)   // images: 500 B / 2
        let vid  = FileNode(name: "c.mov", isDirectory: false, size: 1000)  // video:  1000 B / 1
        let app  = FileNode(name: "Tool.app", isDirectory: true, size: 700, kind: .package) // app: 700 B / 1
        let inApp = FileNode(name: "binary", isDirectory: false, size: 700) // must NOT be counted (package not descended)
        app.setChildren([inApp])
        let hidden = FileNode(url: URL(fileURLWithPath: "/tmp/t"), name: "Hidden Space",
                              isDirectory: false, size: 9999, kind: .hiddenSpace) // synthetic → skipped
        sub.setChildren([img2, vid])
        root.setChildren([img1, sub, app, hidden])

        let result = FileKind.breakdown(root: root)
        let byKind = Dictionary(uniqueKeysWithValues: result.map { ($0.kind, ($0.bytes, $0.count)) })

        #expect(byKind[.image]?.0 == 500)
        #expect(byKind[.image]?.1 == 2)
        #expect(byKind[.video]?.0 == 1000)
        #expect(byKind[.video]?.1 == 1)
        #expect(byKind[.app]?.0 == 700)
        #expect(byKind[.app]?.1 == 1)               // package counted once, contents not descended
        #expect(byKind[.other] == nil)              // hidden space (synthetic) never tallied

        // Sorted bytes-descending: video (1000) > app (700) > images (500).
        #expect(result.map(\.kind) == [.video, .app, .image])

        // largestFiles surfaces the biggest of a kind, bytes-descending.
        let topImages = FileKind.largestFiles(of: .image, in: root, limit: 5)
        #expect(topImages.count == 2)
        #expect(topImages.first === img1)           // 300 B before 200 B
    }

    // MARK: Large & Old files

    @Test("LargeOldFiles.find filters by size, age (nanoseconds), and kind; sorts largest-first; caps")
    func largeOldFiles() {
        let ns: Int64 = 1_000_000_000
        let now: Int64 = 1_000_000                            // epoch seconds

        // Build a small tree mixing sizes, ages, kinds, and a synthetic node.
        let root = FileNode(url: URL(fileURLWithPath: "/tmp/t"), name: "t", isDirectory: true, size: 0)
        let sub = FileNode(name: "sub", isDirectory: true, size: 0)

        // Big + old video (modified 100s epoch → very old relative to now=1e6 s).
        let bigOldVideo = FileNode(name: "export.mov", isDirectory: false, size: 5_000_000_000, modTime: 100 * ns)
        // Big + recent image (modified at now → not old).
        let bigNewImage = FileNode(name: "shot.png", isDirectory: false, size: 4_000_000_000, modTime: now * ns)
        // Small + old document (below the size floor).
        let smallOldDoc = FileNode(name: "notes.pdf", isDirectory: false, size: 100, modTime: 100 * ns)
        // Big + unknown modTime (must be excluded once an age filter is set).
        let bigUnknown = FileNode(name: "blob.bin", isDirectory: false, size: 6_000_000_000, modTime: 0)
        // Synthetic hidden-space node — never surfaced.
        let hidden = FileNode(url: URL(fileURLWithPath: "/tmp/t"), name: "Hidden Space",
                              isDirectory: false, size: 9_000_000_000, kind: .hiddenSpace)

        sub.setChildren([bigNewImage, smallOldDoc])
        root.setChildren([bigOldVideo, sub, bigUnknown, hidden])

        // Size only: 1 GB floor → the three big nodes (not the 100 B doc, not synthetic),
        // largest-first.
        var q = LargeOldFiles.Query.empty
        q.minSizeBytes = 1_073_741_824
        let bySize = LargeOldFiles.find(root: root, query: q, nowEpochSeconds: now)
        #expect(bySize.map(\.name) == ["blob.bin", "export.mov", "shot.png"])
        #expect(!bySize.contains { $0.isSynthetic })

        // + age: older than 1 day. modTime is NANOSECONDS, now is seconds.
        // Only export.mov (100s) qualifies; shot.png is recent and blob.bin is unknown.
        q.maxAgeDays = 1
        let byAge = LargeOldFiles.find(root: root, query: q, nowEpochSeconds: now)
        #expect(byAge.map(\.name) == ["export.mov"])

        // + kind: an image filter at the same size floor (no age) → only shot.png.
        var qk = LargeOldFiles.Query.empty
        qk.minSizeBytes = 1_073_741_824
        qk.kind = .image
        let byKind = LargeOldFiles.find(root: root, query: qk, nowEpochSeconds: now)
        #expect(byKind.map(\.name) == ["shot.png"])

        // Cap: with no filters, a limit of 2 returns the two largest only.
        let capped = LargeOldFiles.find(root: root, query: .empty, nowEpochSeconds: now, limit: 2)
        #expect(capped.map(\.name) == ["blob.bin", "export.mov"])
    }

    // MARK: Natural-language file search

    @Test("FileSearchParser extracts size, age, kind, location, and name needles")
    func fileSearchParser() {
        let gib: Int64 = 1 << 30
        let mib: Int64 = 1 << 20

        // Kind + min size + age + location together.
        let q = FileSearchParser.parse("videos over 1gb in downloads older than 6 months")
        #expect(q.kind == .video)
        #expect(q.minSizeBytes == gib)
        #expect(q.maxAgeDays == 180)
        #expect(q.pathContains == ["/downloads/"])

        // ">" / "<" shorthand and max-size axis.
        let bounded = FileSearchParser.parse("photos >100mb <2gb")
        #expect(bounded.kind == .image)
        #expect(bounded.minSizeBytes == 100 * mib)
        #expect(bounded.maxSizeBytes == 2 * gib)

        // Quoted phrase becomes a name needle; structural words don't leak in.
        let named = FileSearchParser.parse("find files named \"annual report\" on the desktop")
        #expect(named.nameContains == ["annual report"])
        #expect(named.pathContains == ["/desktop/"])
        #expect(named.kind == nil)

        // A bare extension token becomes a ".ext" name needle.
        let ext = FileSearchParser.parse("anything .sketch")
        #expect(ext.nameContains.contains(".sketch"))

        // Empty / purely structural query → trivial filter.
        #expect(FileSearchParser.parse("").isTrivial)
    }

    @Test("FileSearch.find filters by name, path, size, age (ns), and kind; sorts largest-first; caps")
    func fileSearchExecutor() {
        let ns: Int64 = 1_000_000_000
        let now: Int64 = 1_000_000                       // epoch seconds

        let root = FileNode(url: URL(fileURLWithPath: "/Users/x"), name: "x", isDirectory: true, size: 0)
        let downloads = FileNode(url: URL(fileURLWithPath: "/Users/x/Downloads"),
                                 name: "Downloads", isDirectory: true, size: 0)
        let docs = FileNode(url: URL(fileURLWithPath: "/Users/x/Documents"),
                            name: "Documents", isDirectory: true, size: 0)

        let bigOldVideo = FileNode(name: "export.mov", isDirectory: false, size: 5_000_000_000, modTime: 100 * ns)
        let bigNewVideo = FileNode(name: "clip.mov", isDirectory: false, size: 4_000_000_000, modTime: now * ns)
        let smallPdf    = FileNode(name: "report.pdf", isDirectory: false, size: 1000, modTime: 100 * ns)
        let bigPdfDocs  = FileNode(name: "thesis.pdf", isDirectory: false, size: 2_000_000_000, modTime: 100 * ns)
        let hidden = FileNode(url: URL(fileURLWithPath: "/Users/x"), name: "Hidden Space",
                              isDirectory: false, size: 9_000_000_000, kind: .hiddenSpace)

        downloads.setChildren([bigOldVideo, bigNewVideo, smallPdf])
        docs.setChildren([bigPdfDocs])
        root.setChildren([downloads, docs, hidden])

        // Kind = video, min size 1 GB → both videos, largest-first; no synthetic.
        var f = FileSearch.Filter.empty
        f.kind = .video
        f.minSizeBytes = 1_073_741_824
        let videos = FileSearch.find(root: root, filter: f, nowEpochSeconds: now)
        #expect(videos.map(\.name) == ["export.mov", "clip.mov"])
        #expect(!videos.contains { $0.isSynthetic })

        // + age older than 1 day (modTime ns vs now seconds) → only export.mov.
        f.maxAgeDays = 1
        let oldVideos = FileSearch.find(root: root, filter: f, nowEpochSeconds: now)
        #expect(oldVideos.map(\.name) == ["export.mov"])

        // Path hint = /downloads/ + kind document → only the small Downloads pdf.
        var byPath = FileSearch.Filter.empty
        byPath.kind = .document
        byPath.pathContains = ["/downloads/"]
        let inDownloads = FileSearch.find(root: root, filter: byPath, nowEpochSeconds: now)
        #expect(inDownloads.map(\.name) == ["report.pdf"])

        // Name needle ".pdf" → both PDFs anywhere, largest-first.
        var byName = FileSearch.Filter.empty
        byName.nameContains = [".pdf"]
        let pdfs = FileSearch.find(root: root, filter: byName, nowEpochSeconds: now)
        #expect(pdfs.map(\.name) == ["thesis.pdf", "report.pdf"])

        // maxSize axis: under 1 MB → only the small pdf.
        var bySize = FileSearch.Filter.empty
        bySize.maxSizeBytes = 1_048_576
        let small = FileSearch.find(root: root, filter: bySize, nowEpochSeconds: now)
        #expect(small.map(\.name) == ["report.pdf"])

        // A trivial filter matches nothing (never the whole tree).
        #expect(FileSearch.find(root: root, filter: .empty, nowEpochSeconds: now).isEmpty)

        // Cap: kind=video (size floor, no age) with limit 1 → the single largest video.
        var capFilter = FileSearch.Filter.empty
        capFilter.kind = .video
        capFilter.minSizeBytes = 1_073_741_824
        let capped = FileSearch.find(root: root, filter: capFilter, nowEpochSeconds: now, limit: 1)
        #expect(capped.map(\.name) == ["export.mov"])
    }

    @Test("FileSearch.parse maps model JSON (MB→bytes, location, kind) and falls back when trivial")
    func fileSearchPlanParse() {
        let mib: Int64 = 1 << 20
        let gib: Int64 = 1 << 30
        let text = "```json\n{\"nameContains\":[\"invoice\"],\"location\":\"downloads\",\"kind\":\"document\",\"minSizeMB\":100,\"maxSizeMB\":0,\"maxAgeDays\":90}\n```"
        let f = FileSearch.parse(text, fallback: .empty)
        #expect(f?.nameContains == ["invoice"])
        #expect(f?.pathContains == ["/downloads/"])
        #expect(f?.kind == .document)
        #expect(f?.minSizeBytes == 100 * mib)
        #expect(f?.maxSizeBytes == nil)              // 0 → nil
        #expect(f?.maxAgeDays == 90)

        // A trivial model result defers to a non-trivial keyword fallback.
        var fallback = FileSearch.Filter.empty
        fallback.minSizeBytes = gib
        let trivial = FileSearch.parse("{\"nameContains\":[],\"location\":\"\",\"kind\":\"\",\"minSizeMB\":0,\"maxSizeMB\":0,\"maxAgeDays\":0}", fallback: fallback)
        #expect(trivial?.minSizeBytes == gib)

        // Trivial model output with a trivial fallback → nil (nothing to run).
        #expect(FileSearch.parse("{\"kind\":\"\"}", fallback: .empty) == nil)
    }

    @Test("DuplicateTriage keeps the most permanent copy; token helpers classify correctly")
    func dupeTriage() {
        func file(_ path: String) -> FileNode {
            FileNode(url: URL(fileURLWithPath: path),
                     name: (path as NSString).lastPathComponent, isDirectory: false, size: 100)
        }
        let keep = DuplicateTriage.recommendKeeper([
            file("/Users/x/Downloads/photo.jpg"),
            file("/Users/x/Documents/photo.jpg"),
        ])
        #expect(keep.index == 1)              // Documents beats Downloads

        #expect(DuplicateTriage.locationClass("/users/x/downloads/a") == "downloads")
        #expect(DuplicateTriage.locationClass("/users/x/.trash/a") == "trash")
        #expect(DuplicateTriage.hasCopyMarker("photo copy.jpg"))
        #expect(DuplicateTriage.hasCopyMarker("photo (2).jpg"))
        #expect(!DuplicateTriage.hasCopyMarker("photo.jpg"))
    }

    // MARK: App Uninstaller — leftover association

    @Test("AppUninstaller.matchReason: bundle-id, bundle-id-prefix, exact-name, and preference-file rules")
    func appUninstallerMatchRules() {
        let bundleID = "com.acme.WidgetPro"
        let appName = "Widget Pro"

        // Folder locations: exact bundle id matches by bundle id.
        #expect(AppUninstaller.matchReason(
            entryName: bundleID, bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: false) == .bundleID)

        // A bundle-id-prefixed entry (e.g. saved state) matches by bundle id …
        #expect(AppUninstaller.matchReason(
            entryName: "\(bundleID).savedState", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: false) == .bundleID)

        // … but a DIFFERENT app sharing the id as a prefix without the dot boundary
        // must NOT match (com.acme.WidgetProMax is a different app).
        #expect(AppUninstaller.matchReason(
            entryName: "com.acme.WidgetProMax", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: false) == nil)

        // Exact folder name equal to the app name matches by name (only when allowed).
        #expect(AppUninstaller.matchReason(
            entryName: appName, bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: false) == .exactName)

        // A near-name (substring / different case) must NOT match — no false positives.
        #expect(AppUninstaller.matchReason(
            entryName: "Widget Pro Helper", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: false) == nil)
        #expect(AppUninstaller.matchReason(
            entryName: "widget pro", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: false) == nil)

        // When name matching is disallowed (generic/short name), only bundle id works.
        #expect(AppUninstaller.matchReason(
            entryName: appName, bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: false, isPreferenceFile: false) == nil)

        // Preference files: only "<bundleID>.plist" and its lockfile match.
        #expect(AppUninstaller.matchReason(
            entryName: "\(bundleID).plist", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: true) == .bundleID)
        #expect(AppUninstaller.matchReason(
            entryName: "\(bundleID).plist.lockfile", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: true) == .bundleID)
        // A name-based plist must NOT match in a preference location.
        #expect(AppUninstaller.matchReason(
            entryName: "\(appName).plist", bundleID: bundleID, hasBundleID: true,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: true) == nil)

        // Without a bundle id, preference matching is impossible.
        #expect(AppUninstaller.matchReason(
            entryName: "Something.plist", bundleID: "", hasBundleID: false,
            appName: appName, nameMatchAllowed: true, isPreferenceFile: true) == nil)
    }

    @Test("AppUninstaller.inspect reads bundle id/name, sizes the bundle, and associates only matching leftovers")
    func appUninstallerLeftoverAssociation() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let fm = FileManager.default

        // Build a fake home with the standard Library support areas.
        let home = base.appendingPathComponent("home", isDirectory: true)
        let userLib = home.appendingPathComponent("Library", isDirectory: true)
        let caches = userLib.appendingPathComponent("Caches", isDirectory: true)
        let appSupport = userLib.appendingPathComponent("Application Support", isDirectory: true)
        let prefs = userLib.appendingPathComponent("Preferences", isDirectory: true)
        for d in [caches, appSupport, prefs] {
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
        }

        // Build the .app bundle with an Info.plist.
        let appsDir = base.appendingPathComponent("Applications", isDirectory: true)
        let appURL = appsDir.appendingPathComponent("Widget Pro.app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let bundleID = "com.acme.WidgetPro"
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": "Widget Pro",
            "CFBundleDisplayName": "Widget Pro",
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        // A byte or two inside the bundle so it has a non-zero size.
        try Data(repeating: 0xEE, count: 4096).write(to: contents.appendingPathComponent("MacOS-binary"))

        // Real leftovers (should be found):
        //  - Caches/<bundleID>/         (bundle id folder)
        let cacheLeft = caches.appendingPathComponent(bundleID, isDirectory: true)
        try fm.createDirectory(at: cacheLeft, withIntermediateDirectories: true)
        try Data(repeating: 0x01, count: 8192).write(to: cacheLeft.appendingPathComponent("c.bin"))
        //  - Application Support/Widget Pro/  (exact name folder)
        let supportLeft = appSupport.appendingPathComponent("Widget Pro", isDirectory: true)
        try fm.createDirectory(at: supportLeft, withIntermediateDirectories: true)
        try Data(repeating: 0x02, count: 4096).write(to: supportLeft.appendingPathComponent("s.bin"))
        //  - Preferences/<bundleID>.plist  (preference file)
        let prefLeft = prefs.appendingPathComponent("\(bundleID).plist")
        try Data(repeating: 0x03, count: 1024).write(to: prefLeft)

        // Decoys (must NOT be associated):
        //  - Caches/com.other.App/      (different bundle id)
        let decoyCache = caches.appendingPathComponent("com.other.App", isDirectory: true)
        try fm.createDirectory(at: decoyCache, withIntermediateDirectories: true)
        try Data(repeating: 0x09, count: 16384).write(to: decoyCache.appendingPathComponent("x.bin"))
        //  - Application Support/Widget Pro Helper/  (substring of name, not exact)
        let decoySupport = appSupport.appendingPathComponent("Widget Pro Helper", isDirectory: true)
        try fm.createDirectory(at: decoySupport, withIntermediateDirectories: true)
        try Data(repeating: 0x0A, count: 16384).write(to: decoySupport.appendingPathComponent("y.bin"))
        //  - Preferences/Widget Pro.plist  (name-based plist — unsafe, must skip)
        try Data(repeating: 0x0B, count: 2048).write(to: prefs.appendingPathComponent("Widget Pro.plist"))

        // Drive findLeftovers against our fake locations directly (so the test is
        // hermetic and doesn't touch the real ~/Library).
        let locations: [(category: String, dir: URL, mode: Int)] = [
            ("Caches", caches, 0),
            ("Application Support", appSupport, 0),
            ("Preferences", prefs, 1),
        ]
        let leftovers = AppUninstaller.findLeftovers(
            bundleID: bundleID, appName: "Widget Pro", appURL: appURL, locations: locations)

        let names = Set(leftovers.map { $0.url.lastPathComponent })
        #expect(names.contains(bundleID))                 // cache folder by bundle id
        #expect(names.contains("Widget Pro"))             // app support folder by exact name
        #expect(names.contains("\(bundleID).plist"))      // preference file by bundle id
        #expect(leftovers.count == 3)                     // exactly the three real leftovers

        // Decoys excluded.
        #expect(!names.contains("com.other.App"))
        #expect(!names.contains("Widget Pro Helper"))
        #expect(!names.contains("Widget Pro.plist"))

        // Reasons are reported correctly.
        let byName = Dictionary(uniqueKeysWithValues: leftovers.map { ($0.url.lastPathComponent, $0) })
        #expect(byName[bundleID]?.matchedBy == .bundleID)
        #expect(byName["Widget Pro"]?.matchedBy == .exactName)
        #expect(byName["\(bundleID).plist"]?.matchedBy == .bundleID)

        // inspect() reads identity + sizes the bundle (> 0 from the 4 KB binary).
        let app = try #require(AppUninstaller.inspect(appURL: appURL))
        #expect(app.bundleID == bundleID)
        #expect(app.name == "Widget Pro")
        #expect(app.appBytes > 0)
    }

    // MARK: App Uninstaller — orphaned leftovers (removed apps)

    @Test("AppUninstaller.orphanBundleID: bundle-id-shaped names of removed apps qualify; Apple/installed/non-id excluded")
    func appUninstallerOrphanRules() {
        let installed: Set<String> = ["com.acme.WidgetPro", "com.foo.Bar"]

        // A bundle-id folder for a removed app → orphan of that id.
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.removed.GhostApp", isPreferenceFile: false,
            installedBundleIDs: installed) == "com.removed.GhostApp")

        // A bundle-id-prefixed derivative (saved state, etc.) → orphan of the base id.
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.removed.GhostApp.savedState", isPreferenceFile: false,
            installedBundleIDs: installed) == "com.removed.GhostApp")

        // The matching preference plist (and its lockfile) → orphan of the id.
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.removed.GhostApp.plist", isPreferenceFile: true,
            installedBundleIDs: installed) == "com.removed.GhostApp")
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.removed.GhostApp.plist.lockfile", isPreferenceFile: true,
            installedBundleIDs: installed) == "com.removed.GhostApp")

        // Still installed → never an orphan (exact, ancestor, and descendant ids).
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.acme.WidgetPro", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.acme.WidgetPro.HelperData", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)        // descendant of installed id
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.acme", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)        // too few labels / ancestor

        // Apple system bundles are never reported.
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.apple.Safari", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)

        // Non-bundle-id names (UUIDs, bare folder names, two-label ids) don't qualify.
        #expect(AppUninstaller.orphanBundleID(
            entryName: "RandomCacheFolder", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)
        #expect(AppUninstaller.orphanBundleID(
            entryName: "com.removed", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)        // only two labels
        #expect(AppUninstaller.orphanBundleID(
            entryName: "1234-ABCD-5678", isPreferenceFile: false,
            installedBundleIDs: installed) == nil)
        // A name-based plist (no bundle-id suffix shape) doesn't qualify in prefs.
        #expect(AppUninstaller.orphanBundleID(
            entryName: "Widget Pro.plist", isPreferenceFile: true,
            installedBundleIDs: installed) == nil)        // "Widget Pro" isn't an id
    }

    @Test("AppUninstaller.orphanedLeftovers groups removed-app support files, skips installed/Apple/non-id")
    func appUninstallerOrphanScan() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let fm = FileManager.default

        let lib = base.appendingPathComponent("Library", isDirectory: true)
        let caches = lib.appendingPathComponent("Caches", isDirectory: true)
        let appSupport = lib.appendingPathComponent("Application Support", isDirectory: true)
        let prefs = lib.appendingPathComponent("Preferences", isDirectory: true)
        for d in [caches, appSupport, prefs] {
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
        }

        // Orphan: removed app, files in two areas + a preference plist (one group).
        let ghostID = "com.removed.GhostApp"
        let ghostCache = caches.appendingPathComponent(ghostID, isDirectory: true)
        try fm.createDirectory(at: ghostCache, withIntermediateDirectories: true)
        try Data(repeating: 0x01, count: 32768).write(to: ghostCache.appendingPathComponent("c.bin"))
        let ghostSupport = appSupport.appendingPathComponent(ghostID, isDirectory: true)
        try fm.createDirectory(at: ghostSupport, withIntermediateDirectories: true)
        try Data(repeating: 0x02, count: 8192).write(to: ghostSupport.appendingPathComponent("s.bin"))
        try Data(repeating: 0x03, count: 1024).write(to: prefs.appendingPathComponent("\(ghostID).plist"))

        // A second, smaller orphan group (sorting check).
        let oldID = "com.gone.OldTool"
        let oldCache = caches.appendingPathComponent(oldID, isDirectory: true)
        try fm.createDirectory(at: oldCache, withIntermediateDirectories: true)
        try Data(repeating: 0x04, count: 4096).write(to: oldCache.appendingPathComponent("o.bin"))

        // Decoys that must NOT be reported:
        //  - an installed app's cache
        let installedCache = caches.appendingPathComponent("com.acme.WidgetPro", isDirectory: true)
        try fm.createDirectory(at: installedCache, withIntermediateDirectories: true)
        try Data(repeating: 0x09, count: 65536).write(to: installedCache.appendingPathComponent("x.bin"))
        //  - an Apple system bundle
        let appleCache = caches.appendingPathComponent("com.apple.Safari", isDirectory: true)
        try fm.createDirectory(at: appleCache, withIntermediateDirectories: true)
        try Data(repeating: 0x0A, count: 65536).write(to: appleCache.appendingPathComponent("a.bin"))
        //  - a non-bundle-id folder name
        let randomCache = caches.appendingPathComponent("SomeRandomCache", isDirectory: true)
        try fm.createDirectory(at: randomCache, withIntermediateDirectories: true)
        try Data(repeating: 0x0B, count: 65536).write(to: randomCache.appendingPathComponent("r.bin"))

        let locations: [(category: String, dir: URL, mode: Int)] = [
            ("Caches", caches, 0),
            ("Application Support", appSupport, 0),
            ("Preferences", prefs, 1),
        ]
        let groups = AppUninstaller.orphanedLeftovers(
            installedBundleIDs: ["com.acme.WidgetPro"],
            installedAppNames: [],
            locations: locations)

        // Exactly the two orphan groups, largest-first.
        #expect(groups.count == 2)
        #expect(groups.map(\.bundleID) == [ghostID, oldID])
        #expect(groups.first?.displayName == "GhostApp")

        // Ghost group gathered all three of its support files.
        let ghost = try #require(groups.first { $0.bundleID == ghostID })
        #expect(ghost.itemCount == 3)
        let ghostNames = Set(ghost.items.map { $0.url.lastPathComponent })
        #expect(ghostNames == [ghostID, "\(ghostID).plist"])   // folder appears twice (caches + support)
        #expect(ghost.totalBytes > 0)

        // None of the decoys leaked into any group.
        let allIDs = Set(groups.map(\.bundleID))
        #expect(!allIDs.contains("com.acme.WidgetPro"))
        #expect(!allIDs.contains("com.apple.Safari"))
        #expect(!allIDs.contains("SomeRandomCache"))
        let allURLs = groups.flatMap { $0.items.map { $0.url.lastPathComponent } }
        #expect(!allURLs.contains("SomeRandomCache"))
        #expect(!allURLs.contains("com.apple.Safari"))
    }

    // MARK: 26 — safe-delete (Move to Trash)

    @Test("DeletionService.trash moves a file off its original location, reporting no failures")
    func trashRemovesFromOrigin() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("expendable.bin")
        try Data(count: 4096).write(to: file)
        #expect(FileManager.default.fileExists(atPath: file.path))

        let failures = try DeletionService.trash([file])
        #expect(failures.isEmpty)
        // Recoverable from the Finder Trash, but no longer at the original path.
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
}
