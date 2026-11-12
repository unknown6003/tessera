import Testing
import Foundation
import Darwin
@testable import Tessera

@Suite("Operation-scoped Trash", .serialized)
struct TrashOperationTests {
    /// Every move/remove stays below one owned disposable directory. This never
    /// invokes Finder Trash, including when run on macOS.
    final class Fixture: TrashFileSystem {
        let base: URL
        let source: URL
        let trash: URL
        var missingMetadata = false
        var omitDestination = false
        var failMove = false
        var failRemoval = false
        var removalFailureNames = Set<String>()
        var unknownRoot = false
        var removals: [URL] = []
        var afterListing: ((URL) throws -> Void)?
        var beforeState: ((URL) throws -> Void)?
        var removalCheckpoint: (VerifiedTrashRemoval.Checkpoint) throws -> Void = { _ in }
        let local = LocalTrashFileSystem()

        init() throws {
            let temporary = try #require(realpath(FileManager.default.temporaryDirectory.path, nil))
            defer { free(temporary) }
            base = URL(fileURLWithPath: String(cString: temporary))
                .appendingPathComponent(UUID().uuidString)
            source = base.appendingPathComponent("source")
            trash = base.appendingPathComponent(".Trash")
            for url in [source, trash] {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }

        func clean() { try? FileManager.default.removeItem(at: base) }

        func prepare(_ name: String = "disposable.bin", directory: Bool = false) throws -> DeletionService.PreparedRemoval {
            let url = source.appendingPathComponent(name)
            if directory {
                let nested = url.appendingPathComponent("nested/deep")
                try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
                try Data([1]).write(to: nested.appendingPathComponent("child"))
            } else { try Data([1]).write(to: url) }
            let identity = try #require(ScanIdentity.current(at: url))
            let node = FileNode(url: url, name: name, isDirectory: directory, size: 1, identity: identity)
            let result = DeletionService.prepare(node)
            try #require(result.check == .ready)
            return result
        }

        func moveToTrash(at url: URL) throws -> URL? {
            if failMove { throw CocoaError(.fileWriteNoPermission) }
            let destination = trash.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: destination)
            return omitDestination ? nil : destination
        }
        func trashDirectory(for url: URL) throws -> URL {
            if unknownRoot { throw TrashOperation.Hold.unavailable }
            return trash
        }
        func state(at url: URL) throws -> TrashFileState {
            try beforeState?(url)
            if missingMetadata { throw TrashOperation.Hold.unavailable }
            return try local.state(at: url)
        }
        func children(at url: URL) throws -> [URL] {
            let result = try local.children(at: url)
            try afterListing?(url)
            return result
        }
        func remove(at url: URL, expected: [String: TrashFileState]) throws {
            if failRemoval || removalFailureNames.contains(url.lastPathComponent) {
                throw CocoaError(.fileWriteNoPermission)
            }
            // This assertion also protects fixtures from an accidental broad cleanup.
            try #require(url.deletingLastPathComponent().path == trash.path)
            removals.append(url)
            try VerifiedTrashRemoval.remove(at: url, expected: expected, trashDirectory: trash,
                                             checkpoint: removalCheckpoint)
        }
    }

    private func moved(_ fixture: Fixture, _ operation: TrashOperation,
                       name: String = "disposable.bin", directory: Bool = false) throws -> TrashOperation.Item {
        let outcome = DeletionService.performTracked(try fixture.prepare(name, directory: directory), operation: operation)
        try #require(outcome.error == nil)
        try #require(outcome.trackingHold == nil)
        return try #require(outcome.item)
    }

    private func expectHeld(_ results: [TrashOperation.Result], id: UUID) {
        #expect(results.contains { result in
            if case .held(let item, _) = result { return item.id == id }
            return false
        })
    }

    @Test("Real temporary filesystem integration removes only the explicit safe subset")
    func subset() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f)
        let a = try moved(f, operation, name: "a")
        let b = try moved(f, operation, name: "b")
        let unrelated = f.trash.appendingPathComponent("unrelated")
        try Data([9]).write(to: unrelated)
        let review = operation.review(ownerState: .stopped)
        #expect(review.items.count == 2)
        #expect(review.items.allSatisfy { $0.hold == nil })
        let results = operation.finish(review, selecting: [a.id], ownerState: .stopped)
        #expect(results.count == 1)
        if let result = results.first, case .removed(let item) = result { #expect(item.id == a.id) }
        else { Issue.record("Expected the reviewed item to be removed") }
        #expect(f.removals == [a.trashURL])
        #expect(FileManager.default.fileExists(atPath: b.trashURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
        #expect(!FileManager.default.fileExists(atPath: a.originalURL.path))
    }

    @Test("A fresh review accepts only root metadata changes and freezes its ctime snapshot")
    func movedRootMetadata() throws {
        for changeAfterReview in [false, true] {
            let f = try Fixture()
            defer { f.clean() }
            let target = try f.prepare("metadata.bin")
            let destination = f.trash.appendingPathComponent("metadata.bin")
            let permissions = try #require(FileManager.default.attributesOfItem(atPath: target.url.path)[.posixPermissions] as? NSNumber)
            var rootReads = 0
            f.beforeState = { url in
                guard url.path == destination.path else { return }
                rootReads += 1
                if rootReads == 2 {
                    try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
                }
            }
            let operation = TrashOperation(fileSystem: f)
            let outcome = DeletionService.performTracked(target, operation: operation)
            try #require(outcome.error == nil)
            try #require(outcome.trackingHold == nil)
            let item = try #require(outcome.item)
            let review = operation.review(ownerState: .stopped)
            try #require(review.items.allSatisfy { $0.hold == nil })
            if changeAfterReview {
                try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: item.trashURL.path)
            }
            let results = operation.finish(review, selecting: [item.id], ownerState: .stopped)
            if changeAfterReview {
                expectHeld(results, id: item.id)
                #expect(f.removals.isEmpty)
            } else {
                #expect(results.contains { if case .removed(let removed) = $0 { return removed.id == item.id }; return false })
            }
        }
    }

    @Test("Fresh review still holds changed root contents, permissions and descendant metadata")
    func reviewMetadataBoundary() throws {
        for mutation in ["contents", "permissions", "descendant metadata"] {
            let f = try Fixture()
            defer { f.clean() }
            let operation = TrashOperation(fileSystem: f)
            let item = try moved(f, operation, name: "boundary", directory: mutation == "descendant metadata")
            if mutation == "contents" {
                try Data([3, 4]).write(to: item.trashURL)
            } else {
                let url = mutation == "permissions" ? item.trashURL : item.trashURL.appendingPathComponent("nested/deep/child")
                let permissions = try #require(FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)
                let value = mutation == "permissions" ? NSNumber(value: permissions.intValue ^ 0o002) : permissions
                try FileManager.default.setAttributes([.posixPermissions: value], ofItemAtPath: url.path)
            }
            let review = operation.review(ownerState: .stopped)
            #expect(review.items.first?.hold == .changed)
            expectHeld(operation.finish(review, selecting: [item.id], ownerState: .stopped), id: item.id)
            #expect(f.removals.isEmpty)
        }
    }

    @Test("Wrong-operation reviews and selections cannot authorize removal")
    func wrongOperation() throws {
        let f = try Fixture()
        defer { f.clean() }
        let first = TrashOperation(fileSystem: f)
        let second = TrashOperation(fileSystem: f)
        let a = try moved(f, first, name: "a")
        let b = try moved(f, second, name: "b")
        let review = first.review(ownerState: .stopped)
        let wrong = second.finish(review, selecting: [b.id], ownerState: .stopped)
        expectHeld(wrong, id: b.id)
        let mixed = first.finish(review, selecting: [a.id, b.id], ownerState: .stopped)
        expectHeld(mixed, id: a.id)
        #expect(mixed.contains { if case .rejected(let id, .wrongOperation) = $0 { return id == b.id }; return false })
        #expect(f.removals.isEmpty)
    }

    @Test("Changed, replaced, restored and missing files stay held after review")
    func changedFiles() throws {
        for mutation in ["changed", "replaced", "restored", "missing"] {
            let f = try Fixture()
            defer { f.clean() }
            let operation = TrashOperation(fileSystem: f)
            let item = try moved(f, operation)
            let review = operation.review(ownerState: .stopped)
            switch mutation {
            case "changed": try Data([2, 3]).write(to: item.trashURL)
            case "replaced":
                try FileManager.default.moveItem(at: item.trashURL, to: f.base.appendingPathComponent("old"))
                try Data([1]).write(to: item.trashURL)
            case "restored": try FileManager.default.moveItem(at: item.trashURL, to: item.originalURL)
            default: try FileManager.default.removeItem(at: item.trashURL)
            }
            let result = operation.finish(review, selecting: [item.id], ownerState: .stopped)
            expectHeld(result, id: item.id)
            #expect(f.removals.isEmpty)
            if mutation == "restored" { #expect(FileManager.default.fileExists(atPath: item.originalURL.path)) }
        }
    }

    @Test("Nested directory changes and new protected contents stay held")
    func directoryChanges() throws {
        for mutation in ["write", "add", "remove", "protected", "symlink"] {
            let f = try Fixture()
            defer { f.clean() }
            let operation = TrashOperation(fileSystem: f)
            let item = try moved(f, operation, name: "folder", directory: true)
            let review = operation.review(ownerState: .stopped)
            let child = item.trashURL.appendingPathComponent("nested/deep/child")
            switch mutation {
            case "write": try Data([2, 3]).write(to: child)
            case "add": try Data([2]).write(to: item.trashURL.appendingPathComponent("new"))
            case "remove": try FileManager.default.removeItem(at: child)
            case "protected": try Data([2]).write(to: item.trashURL.appendingPathComponent("new.qcow2"))
            default:
                try FileManager.default.removeItem(at: child)
                try FileManager.default.createSymbolicLink(at: child, withDestinationURL: f.source)
            }
            expectHeld(operation.finish(review, selecting: [item.id], ownerState: .stopped), id: item.id)
            #expect(f.removals.isEmpty)
        }
    }

    @Test("A Trash item link or changed Trash ancestor cannot redirect the action")
    func symlinkChanges() throws {
        for ancestor in [false, true] {
            let f = try Fixture()
            defer { f.clean() }
            let operation = TrashOperation(fileSystem: f)
            let item = try moved(f, operation)
            let review = operation.review(ownerState: .stopped)
            if ancestor {
                let relocated = f.base.appendingPathComponent("relocated")
                try FileManager.default.moveItem(at: f.trash, to: relocated)
                try FileManager.default.createSymbolicLink(at: f.trash, withDestinationURL: relocated)
            } else {
                try FileManager.default.moveItem(at: item.trashURL, to: f.base.appendingPathComponent("old"))
                try Data([7]).write(to: item.originalURL)
                try FileManager.default.createSymbolicLink(at: item.trashURL, withDestinationURL: item.originalURL)
            }
            expectHeld(operation.finish(review, selecting: [item.id], ownerState: .stopped), id: item.id)
            #expect(f.removals.isEmpty)
        }
    }

    @Test("Missing metadata and unknown Trash root fail closed")
    func missingMetadata() throws {
        for rootFault in [false, true] {
            let f = try Fixture()
            defer { f.clean() }
            let operation = TrashOperation(fileSystem: f)
            let item = try moved(f, operation)
            let review = operation.review(ownerState: .stopped)
            if rootFault { f.unknownRoot = true } else { f.missingMetadata = true }
            expectHeld(operation.finish(review, selecting: [item.id], ownerState: .stopped), id: item.id)
            #expect(f.removals.isEmpty)
        }
    }

    @Test("Owner state is checked again for captured Xcode contents")
    func ownerState() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f)
        let item = try moved(f, operation, name: "Library/Developer/Xcode/DerivedData", directory: true)
        let unknown = operation.review(ownerState: .unknown)
        #expect(unknown.items.first?.hold == .ownerUnverified)
        let stopped = operation.review(ownerState: .stopped)
        #expect(stopped.items.first?.hold == nil)
        expectHeld(operation.finish(stopped, selecting: [item.id], ownerState: .active), id: item.id)
        #expect(f.removals.isEmpty)
    }

    @Test("Missing actual destination reports a successful untracked move")
    func missingDestination() throws {
        let f = try Fixture()
        defer { f.clean() }
        f.omitDestination = true
        let operation = TrashOperation(fileSystem: f)
        let target = try f.prepare()
        let outcome = DeletionService.performTracked(target, operation: operation)
        #expect(outcome.error == nil)
        #expect(outcome.item == nil)
        #expect(outcome.trackingHold == .unavailable)
        #expect(!FileManager.default.fileExists(atPath: target.url.path))
        #expect(operation.review(ownerState: .stopped).items.isEmpty)
    }

    @Test("Review replacement, consumption and operation invalidation revoke authority")
    func staleReviews() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f)
        let item = try moved(f, operation)
        let old = operation.review(ownerState: .stopped)
        let current = operation.review(ownerState: .stopped)
        expectHeld(operation.finish(old, selecting: [item.id], ownerState: .stopped), id: item.id)
        _ = operation.finish(current, selecting: [], ownerState: .stopped)
        expectHeld(operation.finish(current, selecting: [item.id], ownerState: .stopped), id: item.id)
        let invalidated = operation.review(ownerState: .stopped)
        operation.invalidate()
        let result = operation.finish(invalidated, selecting: [item.id], ownerState: .stopped)
        #expect(result.contains { if case .rejected(let id, .staleReview) = $0 { return id == item.id }; return false })
        #expect(f.removals.isEmpty)
    }

    @Test("Cancellation holds items and a failed remove remains inspectable")
    func cancellationAndFailure() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f)
        let item = try moved(f, operation)
        let review = operation.review(ownerState: .stopped)
        expectHeld(operation.finish(review, selecting: [item.id], ownerState: .stopped,
                                    isCancelled: { true }), id: item.id)
        f.failRemoval = true
        let retry = operation.review(ownerState: .stopped)
        let result = operation.finish(retry, selecting: [item.id], ownerState: .stopped)
        #expect(result.contains { if case .failed(let failed, _) = $0 { return failed.id == item.id }; return false })
        #expect(operation.review(ownerState: .stopped).items.count == 1)
        #expect(f.removals.isEmpty)
    }

    @Test("A partial verified removal keeps its recovery path in later reviews")
    func partialRecovery() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f)
        let item = try moved(f, operation, name: "folder", directory: true)
        let review = operation.review(ownerState: .stopped)
        f.removalCheckpoint = { point in
            if case .didUnlink = point { throw CocoaError(.fileWriteNoPermission) }
        }
        let results = operation.finish(review, selecting: [item.id], ownerState: .stopped)
        var recovery: URL?
        if let result = results.first, case .failed(_, let error) = result {
            let failure = try #require(error as? VerifiedTrashRemoval.Failure)
            #expect(failure.removedEntryCount == 1)
            recovery = try #require(failure.recoveryURL)
        } else { Issue.record("Expected a partial failure") }
        let next = operation.review(ownerState: .stopped)
        #expect(next.items.first?.hold == .changed)
        #expect(next.items.first?.recoveryURL == recovery)
        #expect(FileManager.default.fileExists(atPath: try #require(recovery).appendingPathComponent("recovery.json").path))
    }

    @Test("Tracking limits preserve recoverable moves and cancellation blocks a move")
    func boundedCapture() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f, maximumEntries: 1)
        let target = try f.prepare("folder", directory: true)
        let outcome = DeletionService.performTracked(target, operation: operation)
        #expect(outcome.error == nil)
        #expect(outcome.item == nil)
        #expect(outcome.trackingHold == .incomplete)
        #expect(!FileManager.default.fileExists(atPath: target.url.path))
        #expect(FileManager.default.fileExists(atPath: f.trash.appendingPathComponent("folder").path))
        let cancelled = DeletionService.performTracked(try f.prepare("cancelled"), operation: operation,
                                                      isCancelled: { true })
        #expect(cancelled.error != nil)
    }

    @Test("An over-budget capture never moves a replacement source")
    func budgetReplacement() throws {
        let f = try Fixture()
        defer { f.clean() }
        let target = try f.prepare("folder", directory: true)
        f.afterListing = { url in
            guard url.resolvingSymlinksInPath().path == target.url.resolvingSymlinksInPath().path else { return }
            f.afterListing = nil
            try FileManager.default.moveItem(at: url, to: f.base.appendingPathComponent("saved"))
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try Data([7]).write(to: url.appendingPathComponent("unrelated"))
        }
        let result = DeletionService.performTracked(target, operation: TrashOperation(fileSystem: f, maximumEntries: 1))
        #expect(result.error != nil)
        #expect(FileManager.default.fileExists(atPath: target.url.appendingPathComponent("unrelated").path))
        #expect(!FileManager.default.fileExists(atPath: f.trash.appendingPathComponent("folder").path))
    }

    @Test("An over-budget package cannot move new protected descendants")
    func budgetPackageProtection() throws {
        let f = try Fixture()
        defer { f.clean() }
        let target = try f.prepare("Example.app", directory: true)
        f.afterListing = { url in
            guard url.standardizedFileURL.path == target.url.standardizedFileURL.path else { return }
            f.afterListing = nil
            try Data([9]).write(to: url.appendingPathComponent("nested/deep/keep.qcow2"))
        }
        let result = DeletionService.performTracked(target, operation: TrashOperation(fileSystem: f, maximumEntries: 1))
        #expect(result.error != nil)
        #expect(FileManager.default.fileExists(atPath: target.url.path))
    }

    @Test("Owner activity detected after validation holds permanent removal")
    func freshOwnerProbe() throws {
        let f = try Fixture()
        defer { f.clean() }
        let operation = TrashOperation(fileSystem: f)
        let item = try moved(f, operation, name: "Library/Developer/Xcode/DerivedData", directory: true)
        let review = operation.review(ownerState: .stopped)
        expectHeld(operation.finish(review, selecting: [item.id], ownerState: .stopped,
                                    ownerProbe: { .active }), id: item.id)
        #expect(f.removals.isEmpty)
    }

    @Test("Existing wrappers keep their source-compatible failure and permanent shapes")
    func wrappers() throws {
        let f = try Fixture()
        defer { f.clean() }
        let target = try f.prepare()
        #expect(DeletionService.perform(target, permanently: true) == nil)
        let missing = FileNode(url: target.url, name: "missing", isDirectory: false, size: 1)
        #expect(try DeletionService.trash([missing]).count == 1)
        #expect(try DeletionService.delete([missing]).count == 1)
    }
}

@Suite("Trash move safety gates", .serialized)
struct TrashMoveSafetyTests {
    @Test("Prepared coverage and protected gates still block tracked moves")
    func preflightGates() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let url = base.appendingPathComponent("disposable")
        try Data([1]).write(to: url)
        let identity = try #require(ScanIdentity.current(at: url))
        let node = FileNode(url: url, name: "disposable", isDirectory: false, size: 1, identity: identity)
        node.addScanCoverageGap(url.path)
        let target = DeletionService.prepare(node)
        #expect(target.check == .incompleteScan)
        let adapter = try TrashOperationTests.Fixture()
        defer { adapter.clean() }
        let outcome = DeletionService.performTracked(target, operation: TrashOperation(fileSystem: adapter))
        #expect(outcome.error != nil)
        #expect(outcome.item == nil)
        #expect(FileManager.default.fileExists(atPath: url.path))
        let protected = base.appendingPathComponent("keep.qcow2")
        try Data([2]).write(to: protected)
        let protectedIdentity = try #require(ScanIdentity.current(at: protected))
        // Even a hand-made ready record cannot bypass live path protection.
        let forged = DeletionService.PreparedRemoval(url: protected, identity: protectedIdentity,
                                                     check: .ready, ancestors: [])
        let blocked = DeletionService.performTracked(forged, operation: TrashOperation(fileSystem: adapter))
        #expect(blocked.error != nil)
        #expect(blocked.item == nil)
        #expect(FileManager.default.fileExists(atPath: protected.path))
    }
}
