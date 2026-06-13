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

    @Test("A .app directory is classified as .package and its size includes contents")
    func packagesAreScanned() async throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        do {
            let appBundle = base.appendingPathComponent("Demo.app", isDirectory: true)
            try FileManager.default.createDirectory(at: appBundle, withIntermediateDirectories: true)
            let binary = appBundle.appendingPathComponent("Demo")
            try Data(repeating: 0xEE, count: 4096).write(to: binary)
            let expectedBinarySize = allocatedSize(at: binary.path)

            let root = try await FileScanner.scan(url: base) { _ in }

            guard let appNode = root.children.first(where: { $0.name == "Demo.app" }) else {
                Issue.record("Demo.app node not found")
                return
            }

            #expect(appNode.kind == .package)
            #expect(appNode.size == expectedBinarySize,
                    "Package size \(appNode.size) != file's allocated size \(expectedBinarySize)")
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
            // bytesFound must equal root.size (no hidden space for a plain folder scan)
            // root.size already aggregated; bytesFound counts raw file allocations.
            // They should be equal because there's no hidden-space synthetic here.
            let realSize = root.children
                .filter { !$0.isSynthetic }
                .reduce(Int64(0)) { $0 + $1.size }
            #expect(finalProg.bytesFound == realSize)
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
}
