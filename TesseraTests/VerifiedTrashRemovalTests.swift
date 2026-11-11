import Foundation
import Darwin
import Testing
@testable import Tessera

@Suite("Verified descriptor Trash removal", .serialized)
struct VerifiedTrashRemovalTests {
    private final class Fixture {
        let base: URL
        let trash: URL
        let target: URL
        let local = LocalTrashFileSystem()

        init(directory: Bool = true) throws {
            base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                .resolvingSymlinksInPath()
            trash = base.appendingPathComponent(".Trash")
            target = trash.appendingPathComponent("reviewed")
            try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
            if directory {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
                try Data([1]).write(to: target.appendingPathComponent("a"))
                try Data([2]).write(to: target.appendingPathComponent("b"))
            } else { try Data([1]).write(to: target) }
        }

        func clean() { try? FileManager.default.removeItem(at: base) }

        func manifest() throws -> [String: TrashFileState] {
            var result: [String: TrashFileState] = [:]
            func visit(_ url: URL, _ key: String) throws {
                let state = try local.state(at: url)
                result[key] = state
                if state.isDirectory {
                    for child in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                        try visit(child, key.isEmpty ? child.lastPathComponent : key + "/" + child.lastPathComponent)
                    }
                }
            }
            try visit(target, "")
            return result
        }

        func run(_ manifest: [String: TrashFileState],
                 hook: @escaping (VerifiedTrashRemoval.Checkpoint) throws -> Void = { _ in }) throws {
            try VerifiedTrashRemoval.remove(at: target, expected: manifest, trashDirectory: trash, checkpoint: hook)
        }

        func held(_ manifest: [String: TrashFileState],
                  hook: @escaping (VerifiedTrashRemoval.Checkpoint) throws -> Void = { _ in }) throws -> VerifiedTrashRemoval.Failure {
            do {
                try run(manifest, hook: hook)
                Issue.record("Expected an inspectable hold")
                throw CocoaError(.fileReadUnknown)
            } catch let failure as VerifiedTrashRemoval.Failure { return failure }
        }

        func journal(_ failure: VerifiedTrashRemoval.Failure) throws -> [String: Any] {
            let folder = try #require(failure.recoveryURL)
            let data = try Data(contentsOf: folder.appendingPathComponent("recovery.json"))
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
    }

    @Test("Exact file and nested tree removal clean up the journal and staging")
    func exactRemoval() throws {
        for directory in [false, true] {
            let f = try Fixture(directory: directory)
            defer { f.clean() }
            if directory {
                let nested = f.target.appendingPathComponent("nested/deep")
                try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
                try Data([3]).write(to: nested.appendingPathComponent("leaf"))
            }
            let unrelated = f.trash.appendingPathComponent("unrelated")
            try Data([9]).write(to: unrelated)
            try f.run(f.manifest())
            #expect(!FileManager.default.fileExists(atPath: f.target.path))
            #expect(try Data(contentsOf: unrelated) == Data([9]))
            #expect(try FileManager.default.contentsOfDirectory(atPath: f.trash.path) == ["unrelated"])
        }
    }

    @Test("Root replacement acquired by rename is held without removing either tree")
    func rootReplacement() throws {
        let f = try Fixture()
        defer { f.clean() }
        let manifest = try f.manifest()
        let saved = f.trash.appendingPathComponent("saved")
        let failure = try f.held(manifest) { point in
            if case .beforeAcquisition = point {
                try FileManager.default.moveItem(at: f.target, to: saved)
                try FileManager.default.createDirectory(at: f.target, withIntermediateDirectories: false)
                try Data([9]).write(to: f.target.appendingPathComponent("unrelated"))
            }
        }
        #expect(failure.removedEntryCount == 0)
        let held = try #require(failure.recoveryURL).appendingPathComponent("item/unrelated")
        #expect(try Data(contentsOf: held) == Data([9]))
        #expect(try Data(contentsOf: saved.appendingPathComponent("a")) == Data([1]))
        #expect(try f.journal(failure)["expectedEntryCount"] as? Int == 3)
    }

    @Test("Leaf replacement at the final acquisition is held in a mapped slot")
    func leafReplacement() throws {
        let f = try Fixture()
        defer { f.clean() }
        let manifest = try f.manifest()
        let saved = f.base.appendingPathComponent("saved-leaf")
        var item: URL?
        let failure = try f.held(manifest) { point in
            switch point {
            case .acquired(let url): item = url
            case .beforeEntry("a"):
                let a = try #require(item).appendingPathComponent("a")
                try FileManager.default.moveItem(at: a, to: saved)
                try Data([9, 9]).write(to: a)
            default: break
            }
        }
        #expect(failure.removedEntryCount == 0)
        #expect(try Data(contentsOf: saved) == Data([1]))
        let journal = try f.journal(failure)
        let entries = try #require(journal["entries"] as? [[String: Any]])
        let record = try #require(entries.first { $0["relativePath"] as? String == "a" })
        let slot = try #require(record["slot"] as? String)
        let held = try #require(failure.recoveryURL).appendingPathComponent(slot)
        #expect(try Data(contentsOf: held) == Data([9, 9]))
        #expect(try Data(contentsOf: #require(item).appendingPathComponent("b")) == Data([2]))
    }

    @Test("Changed and new descendants stop before the first unlink")
    func fullManifestCheck() throws {
        for addNew in [false, true] {
            let f = try Fixture()
            defer { f.clean() }
            let manifest = try f.manifest()
            let failure = try f.held(manifest) { point in
                if case .acquired(let item) = point {
                    try Data([8, 8, 8]).write(to: item.appendingPathComponent(addNew ? "new" : "b"))
                }
            }
            #expect(failure.removedEntryCount == 0)
            let item = try #require(failure.recoveryURL).appendingPathComponent("item")
            #expect(try Data(contentsOf: item.appendingPathComponent("a")) == Data([1]))
            #expect(try Data(contentsOf: item.appendingPathComponent(addNew ? "new" : "b")) == Data([8, 8, 8]))
            _ = try f.journal(failure)
        }
    }

    @Test("Symlink acquired at a leaf is never followed")
    func leafSymlink() throws {
        let f = try Fixture()
        defer { f.clean() }
        let manifest = try f.manifest()
        let outside = f.base.appendingPathComponent("outside")
        try Data([7]).write(to: outside)
        var item: URL?
        let failure = try f.held(manifest) { point in
            switch point {
            case .acquired(let url): item = url
            case .beforeEntry("a"):
                let a = try #require(item).appendingPathComponent("a")
                try FileManager.default.moveItem(at: a, to: f.base.appendingPathComponent("saved"))
                try FileManager.default.createSymbolicLink(at: a, withDestinationURL: outside)
            default: break
            }
        }
        #expect(failure.removedEntryCount == 0)
        #expect(try Data(contentsOf: outside) == Data([7]))
        _ = try f.journal(failure)
    }

    @Test("An ancestor symlink is rejected before staging or acquisition")
    func ancestorSymlink() throws {
        let f = try Fixture()
        defer { f.clean() }
        let manifest = try f.manifest()
        let alias = f.base.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: f.trash)
        do {
            try VerifiedTrashRemoval.remove(at: alias.appendingPathComponent("reviewed"), expected: manifest,
                                            trashDirectory: alias, checkpoint: { _ in })
            Issue.record("Expected nofollow to reject the ancestor")
        } catch let failure as VerifiedTrashRemoval.Failure {
            #expect(failure.recoveryURL == nil)
            #expect(failure.removedEntryCount == 0)
        }
        #expect(try Data(contentsOf: f.target.appendingPathComponent("a")) == Data([1]))
    }

    @Test("Partial failure retains remaining objects and the original recovery map")
    func partialFailure() throws {
        let f = try Fixture()
        defer { f.clean() }
        let failure = try f.held(f.manifest()) { point in
            if case .didUnlink("a") = point { throw CocoaError(.fileWriteNoPermission) }
        }
        #expect(failure.removedEntryCount == 1)
        let item = try #require(failure.recoveryURL).appendingPathComponent("item")
        #expect(!FileManager.default.fileExists(atPath: item.appendingPathComponent("a").path))
        #expect(try Data(contentsOf: item.appendingPathComponent("b")) == Data([2]))
        #expect(try f.journal(failure)["expectedEntryCount"] as? Int == 3)
    }

    @Test("Journal exists before acquisition and survives an interruption")
    func journalBeforeAcquisition() throws {
        let f = try Fixture(directory: false)
        defer { f.clean() }
        let failure = try f.held(f.manifest()) { point in
            if case .beforeAcquisition = point { throw CocoaError(.userCancelled) }
        }
        #expect(failure.removedEntryCount == 0)
        #expect(try Data(contentsOf: f.target) == Data([1]))
        let journal = try f.journal(failure)
        #expect(journal["originalTrashURL"] as? String == f.target.absoluteString)
    }

    @Test("Exclusive acquisition never overwrites a staging collision")
    func exclusiveAcquisition() throws {
        let f = try Fixture(directory: false)
        defer { f.clean() }
        let failure = try f.held(f.manifest()) { point in
            if case .beforeAcquisition = point {
                let stage = try #require(FileManager.default.contentsOfDirectory(at: f.trash, includingPropertiesForKeys: nil)
                    .first { $0.lastPathComponent.hasPrefix(".tessera-removal-") })
                try Data([9]).write(to: stage.appendingPathComponent("item"))
            }
        }
        #expect(failure.removedEntryCount == 0)
        #expect(try Data(contentsOf: f.target) == Data([1]))
        #expect(try Data(contentsOf: #require(failure.recoveryURL).appendingPathComponent("item")) == Data([9]))
        _ = try f.journal(failure)
    }
    @Test("New content at directory removal remains held after acquisition")
    func lateNewContent() throws {
        let f = try Fixture()
        defer { f.clean() }
        let manifest = try f.manifest()
        var item: URL?
        let failure = try f.held(manifest) { point in
            switch point {
            case .acquired(let url): item = url
            case .beforeEntry(""):
                try Data([9]).write(to: #require(item).appendingPathComponent("new"))
            default: break
            }
        }
        #expect(failure.removedEntryCount == 2)
        let held = try #require(failure.recoveryURL).appendingPathComponent("entry-0/new")
        #expect(try Data(contentsOf: held) == Data([9]))
        _ = try f.journal(failure)
    }

    @Test("Manifest hard links never gain removal authority")
    func unsupportedManifest() throws {
        let f = try Fixture(directory: false)
        defer { f.clean() }
        let link = f.base.appendingPathComponent("other-link")
        try FileManager.default.linkItem(at: f.target, to: link)
        let failure = try f.held(f.manifest())
        #expect(failure.reason == .unsupported)
        #expect(failure.removedEntryCount == 0)
        #expect(failure.recoveryURL == nil)
        #expect(try Data(contentsOf: link) == Data([1]))
        #expect(try Data(contentsOf: f.target) == Data([1]))
    }

    @Test("Replacement inside an acquired leaf slot remains recoverable")
    func acquiredSlotReplacement() throws {
        let f = try Fixture(directory: false)
        defer { f.clean() }
        let saved = f.base.appendingPathComponent("saved-acquired-file")
        var acquiredSlot: URL?
        let failure = try f.held(f.manifest()) { point in
            if case .acquiredEntry("", let slot) = point {
                acquiredSlot = slot
                try FileManager.default.moveItem(at: slot, to: saved)
                try Data([9, 9]).write(to: slot)
            }
        }
        #expect(failure.removedEntryCount == 0)
        #expect(try Data(contentsOf: saved) == Data([1]))
        #expect(try Data(contentsOf: #require(acquiredSlot)) == Data([9, 9]))
        _ = try f.journal(failure)
    }

}
