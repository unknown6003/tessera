import Foundation
import Darwin

/// In-memory authority for one recoverable move operation. Call synchronous I/O
/// off MainActor. Dropping this object drops all authority to finish its items.
final class TrashOperation: @unchecked Sendable {
    struct Item: Identifiable, Equatable, Sendable {
        let id: UUID
        let operationID: UUID
        let originalURL: URL
        let trashURL: URL
        let identity: ScanIdentity
        let volumeIdentifier: String
        fileprivate init(id: UUID, operationID: UUID, originalURL: URL, trashURL: URL,
                         identity: ScanIdentity, volumeIdentifier: String) {
            self.id = id
            self.operationID = operationID
            self.originalURL = originalURL
            self.trashURL = trashURL
            self.identity = identity
            self.volumeIdentifier = volumeIdentifier
        }
    }

    enum Hold: String, Error, Sendable {
        case cancelled, unavailable, changed, protectedContents, incomplete, ownerUnverified
        case wrongOperation, staleReview
    }

    struct MoveOutcome: Sendable {
        let error: DeletionService.DeletionError?
        let item: Item?
        /// A nil error still means the move succeeded when tracking is held.
        let trackingHold: Hold?
    }

    struct ReviewedItem: Identifiable, Sendable {
        let item: Item
        let hold: Hold?
        let recoveryURL: URL?
        var id: UUID { item.id }
    }

    struct Review: Sendable {
        let operationID: UUID
        let items: [ReviewedItem]
        fileprivate let token: UUID
        fileprivate init(operationID: UUID, items: [ReviewedItem], token: UUID) {
            self.operationID = operationID
            self.items = items
            self.token = token
        }
    }

    enum Result: Sendable {
        case removed(Item)
        case held(Item, Hold)
        case failed(Item, Error)
        case rejected(UUID, Hold)
    }

    let id = UUID()
    private let lock = NSLock()
    private let fileSystem: any TrashFileSystem
    private var records: [UUID: Record] = [:]
    private var order: [UUID] = []
    private var recoveryFailures: [UUID: VerifiedTrashRemoval.Failure] = [:]
    private var pendingReview: Review?
    private var reviewedAt: ContinuousClock.Instant?
    private let maximumEntries: Int
    private let reviewLifetime: Duration = .seconds(300)

    init() {
        fileSystem = LocalTrashFileSystem()
        maximumEntries = 10_000
    }

    /// Internal test seam. Injected adapters must be trusted, like FileManager.
    init(fileSystem: any TrashFileSystem, maximumEntries: Int = 10_000) {
        self.fileSystem = fileSystem
        self.maximumEntries = max(1, maximumEntries)
    }

    private struct Record {
        let item: Item
        let manifest: [String: TrashFileState]
        let ancestors: [String: TrashFileState]
        let trashRoot: URL
        let volumeRoot: URL
        let requiresStoppedOwner: Bool
    }

    func move(_ target: DeletionService.PreparedRemoval,
                          isCancelled: () -> Bool) -> MoveOutcome {
        lock.withLock {
            pendingReview = nil
            reviewedAt = nil
            var captured: Record?
            var trackingHold: Hold?
            let error = DeletionService.perform(target, permanently: false) { source in
                if isCancelled() { throw Hold.cancelled }
                // A forged PreparedRemoval cannot skip the live protected-path gate.
                guard target.check == .ready,
                      target.identity?.hasStableObjectIdentifier == true,
                      CleanupClassifier.protectedCategory(for: source.path) == nil else {
                    throw Hold.protectedContents
                }
                let canonicalSource = try source.canonicalFileURL()
                let before: [String: TrashFileState]
                do {
                    before = try capture(at: canonicalSource, original: source,
                                         trashRoot: nil, isCancelled: isCancelled)
                } catch Hold.incomplete {
                    // Tracking has a tighter work budget than the existing live
                    // move preflight. A large safe folder can still enter Trash;
                    // only in-app permanent finishing is unavailable for it.
                    if isCancelled() { throw Hold.cancelled }
                    guard DeletionService.revalidate(target) == .ready else { throw Hold.changed }
                    _ = try fileSystem.moveToTrash(at: source)
                    trackingHold = .incomplete
                    return
                }
                guard let current = ScanIdentity.current(at: source),
                      target.identity?.matches(current) == true,
                      before[""]?.device == current.device,
                      before[""]?.inode == current.inode else { throw Hold.changed }
                if isCancelled() { throw Hold.cancelled }
                // Only the adapter's actual move result may enter the manifest.
                guard let destination = try fileSystem.moveToTrash(at: source) else {
                    trackingHold = .unavailable
                    return
                }
                do {
                    guard destination.isFileURL else { throw Hold.unavailable }
                    let trashRoot = try fileSystem.trashDirectory(for: destination).canonicalFileURL()
                    // Resolve the parent once, then forbid any future ancestor changes.
                    let trashURL = try destination.deletingLastPathComponent().canonicalFileURL()
                        .appendingPathComponent(destination.lastPathComponent)
                    guard trashURL.deletingLastPathComponent() == trashRoot,
                          trashURL != canonicalSource,
                          !trashURL.path.hasPrefix(canonicalSource.path + "/") else { throw Hold.unavailable }
                    try waitForMovedRoot(at: trashURL, expected: before[""], isCancelled: isCancelled)
                    let after = try capture(at: trashURL, original: source,
                                            trashRoot: trashRoot, isCancelled: isCancelled)
                    guard Set(before.keys) == Set(after.keys), before.allSatisfy({ key, value in
                        guard let moved = after[key] else { return false }
                        return key.isEmpty ? value.sameMovedObject(as: moved) : value == moved
                    }), let state = after[""], let identity = ScanIdentity.current(at: trashURL),
                          identity.hasStableObjectIdentifier else { throw Hold.changed }
                    let ancestors = try captureAncestors(of: trashURL)
                    let volumeRoot = state.volumeRoot
                    guard ancestors[volumeRoot.path] != nil else { throw Hold.unavailable }
                    let item = Item(id: UUID(), operationID: id, originalURL: source,
                                    trashURL: trashURL, identity: identity,
                                    volumeIdentifier: state.volumeIdentifier)
                    let requiresStoppedOwner = before.keys.contains { relative in
                        [source, canonicalSource].contains { base in
                            let path = (relative.isEmpty ? base : base.appendingPathComponent(relative)).path.lowercased()
                            return path.contains("/library/developer/xcode/") || path.hasSuffix("/library/developer/xcode")
                        }
                    }
                    captured = Record(item: item, manifest: after, ancestors: ancestors,
                                      trashRoot: trashRoot, volumeRoot: volumeRoot,
                                      requiresStoppedOwner: requiresStoppedOwner)
                } catch {
                    trackingHold = (error as? Hold) ?? .unavailable
                }
            }
            if error == nil, let captured {
                records[captured.item.id] = captured
                order.append(captured.item.id)
            }
            return MoveOutcome(error: error, item: error == nil ? captured?.item : nil,
                               trackingHold: trackingHold)
        }
    }

    /// Refresh immediately before presenting the second confirmation. Nothing is
    /// selected by this interface. A new review invalidates every older review.
    func review(ownerState: CleanupOwnerState,
                isCancelled: () -> Bool = { false }) -> Review {
        lock.withLock {
            let items = order.compactMap { records[$0] }.map { record in
                ReviewedItem(item: record.item,
                             hold: recoveryFailures[record.item.id] == nil
                                ? validate(record, ownerState: ownerState, isCancelled: isCancelled) : .changed,
                             recoveryURL: recoveryFailures[record.item.id]?.recoveryURL)
            }
            let review = Review(operationID: id, items: items, token: UUID())
            pendingReview = review
            reviewedAt = .now
            return review
        }
    }

    /// Consume exactly one immutable review and an explicit selection. Never
    /// accept a caller URL or item record as deletion authority. Recheck owner
    /// state at the call site as well as the source/scan busy lock.
    func finish(_ review: Review, selecting itemIDs: Set<UUID>, ownerState: CleanupOwnerState,
                ownerProbe: (@Sendable () -> CleanupOwnerState)? = nil,
                isCancelled: () -> Bool = { false }) -> [Result] {
        lock.withLock {
            let selected = order.compactMap { records[$0] }.filter { itemIDs.contains($0.item.id) }
            let unknown = itemIDs.subtracting(Set(selected.map { $0.item.id }))
                .sorted { $0.uuidString < $1.uuidString }
            guard review.operationID == id else {
                return selected.map { .held($0.item, .wrongOperation) }
                    + unknown.map { .rejected($0, .wrongOperation) }
            }
            guard let pending = pendingReview, pending.token == review.token,
                  let reviewedAt, ContinuousClock.now - reviewedAt <= reviewLifetime else {
                return selected.map { .held($0.item, .staleReview) }
                    + unknown.map { .rejected($0, .staleReview) }
            }
            pendingReview = nil
            self.reviewedAt = nil
            // Unknown selections hold the whole request. There is no partial
            // interpretation of a selection from another operation.
            guard itemIDs.isSubset(of: Set(pending.items.map(\.id))) else {
                return selected.map { .held($0.item, .wrongOperation) }
                    + unknown.map { .rejected($0, .wrongOperation) }
            }
            return selected.map { record in
                if let priorHold = pending.items.first(where: { $0.id == record.item.id })?.hold {
                    return .held(record.item, priorHold)
                }
                if let hold = validate(record, ownerState: ownerState, isCancelled: isCancelled) {
                    return .held(record.item, hold)
                }
                if isCancelled() { return .held(record.item, .cancelled) }
                if record.requiresStoppedOwner, let ownerProbe, ownerProbe() != .stopped {
                    return .held(record.item, .ownerUnverified)
                }
                do {
                    try fileSystem.remove(at: record.item.trashURL, expected: record.manifest)
                    records.removeValue(forKey: record.item.id)
                    return .removed(record.item)
                } catch {
                    if let recovery = error as? VerifiedTrashRemoval.Failure {
                        recoveryFailures[record.item.id] = recovery
                    }
                    return .failed(record.item, error)
                }
            }
        }
    }

    func revokeReview() {
        lock.withLock {
            pendingReview = nil
            reviewedAt = nil
        }
    }

    func invalidate() {
        lock.withLock {
            records.removeAll()
            recoveryFailures.removeAll()
            order.removeAll()
            pendingReview = nil
            reviewedAt = nil
        }
    }

    private func validate(_ record: Record, ownerState: CleanupOwnerState,
                          isCancelled: () -> Bool) -> Hold? {
        do {
            if isCancelled() { throw Hold.cancelled }
            if record.requiresStoppedOwner && ownerState != .stopped { throw Hold.ownerUnverified }
            guard record.item.operationID == id,
                  record.item.trashURL.deletingLastPathComponent() == record.trashRoot,
                  CleanupClassifier.protectedCategory(for: record.item.originalURL.path) == nil else {
                throw Hold.protectedContents
            }
            let root = try fileSystem.trashDirectory(for: record.item.trashURL).canonicalFileURL()
            guard root == record.trashRoot else { throw Hold.changed }
            let ancestors = try captureAncestors(of: record.item.trashURL)
            guard Set(ancestors.keys) == Set(record.ancestors.keys),
                  ancestors.allSatisfy({ path, state in
                      record.ancestors[path]?.sameAncestor(as: state) == true
                  }) else { throw Hold.changed }
            let current = try capture(at: record.item.trashURL, original: record.item.originalURL,
                                      trashRoot: record.trashRoot, isCancelled: isCancelled)
            guard current == record.manifest,
                  current[""]?.volumeRoot == record.volumeRoot,
                  let identity = ScanIdentity.current(at: record.item.trashURL),
                  record.item.identity.matches(identity) else { throw Hold.changed }
            return nil
        } catch { return (error as? Hold) ?? .unavailable }
    }

    private func captureAncestors(of url: URL) throws -> [String: TrashFileState] {
        var cursor = url.deletingLastPathComponent()
        var result: [String: TrashFileState] = [:]
        while true {
            guard result.count < 256 else { throw Hold.incomplete }
            let state = try fileSystem.state(at: cursor)
            guard state.isDirectory, state.isUsable else { throw Hold.unavailable }
            result[cursor.path] = state
            if cursor.path == "/" { return result }
            cursor.deleteLastPathComponent()
        }
    }

    // FileManager may return before macOS finishes updating the moved root's
    // metadata. Capture only after a short stable interval; later validation
    // still compares every field, including ctime.
    private func waitForMovedRoot(at url: URL, expected: TrashFileState?,
                                  isCancelled: () -> Bool) throws {
        guard let expected else { throw Hold.incomplete }
        let clock = ContinuousClock()
        let deadline = clock.now + .milliseconds(250)
        var previous: TrashFileState?
        var stableSince = clock.now
        while clock.now < deadline {
            if isCancelled() { throw Hold.cancelled }
            let current = try fileSystem.state(at: url)
            guard current.isUsable, expected.sameMovedObject(as: current) else { throw Hold.changed }
            if current != previous {
                previous = current
                stableSince = clock.now
            } else if clock.now - stableSince >= .milliseconds(20) {
                return
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        throw Hold.changed
    }

    private func capture(at root: URL, original: URL, trashRoot: URL?,
                         isCancelled: () -> Bool) throws -> [String: TrashFileState] {
        let deadline = ContinuousClock.now + .seconds(5)
        var stack: [(URL, String)] = [(root, "")]
        var result: [String: TrashFileState] = [:]
        var volume: String?
        var device: UInt32?
        while let (url, relative) = stack.popLast() {
            if isCancelled() { throw Hold.cancelled }
            guard ContinuousClock.now < deadline, result.count < maximumEntries else { throw Hold.incomplete }
            let source = relative.isEmpty ? original : original.appendingPathComponent(relative)
            guard CleanupClassifier.protectedCategory(for: source.path) == nil else { throw Hold.protectedContents }
            // Exempt only the proven Trash ancestors, never the tracked object
            // or its descendants. A nested .Trash or protected name stays held.
            try checkProtectedLocation(url, trashRoot: trashRoot)
            let state = try fileSystem.state(at: url)
            guard state.isUsable else { throw Hold.incomplete }
            guard volume == nil || volume == state.volumeIdentifier,
                  device == nil || device == state.device else { throw Hold.incomplete }
            volume = state.volumeIdentifier
            device = state.device
            result[relative] = state
            if state.isDirectory {
                let children = try fileSystem.children(at: url)
                guard children.count <= maximumEntries - result.count - stack.count else { throw Hold.incomplete }
                for child in children {
                    let name = child.lastPathComponent
                    guard !name.isEmpty, name != ".", name != "..",
                          child.deletingLastPathComponent().path == url.path else { throw Hold.incomplete }
                    stack.append((child, relative.isEmpty ? name : relative + "/" + name))
                }
                // Detect mutation during enumeration, including empty folders.
                guard try fileSystem.state(at: url) == state else { throw Hold.changed }
            }
        }
        return result
    }

    private func checkProtectedLocation(_ url: URL, trashRoot: URL?) throws {
        var cursor = url
        while true {
            if let category = CleanupClassifier.protectedCategory(atNormalizedPath: cursor.path.lowercased()) {
                let isTrashContainer = category.id == "system.trash" && trashRoot.map { root in
                    cursor == root || (cursor == root.deletingLastPathComponent()
                        && cursor.lastPathComponent.lowercased() == ".trashes")
                } == true
                guard isTrashContainer else { throw Hold.protectedContents }
            }
            if cursor.path == "/" { return }
            cursor.deleteLastPathComponent()
        }
    }
}

/// This seam varies only filesystem access. All authorization stays in the operation.
protocol TrashFileSystem {
    func moveToTrash(at url: URL) throws -> URL?
    func trashDirectory(for url: URL) throws -> URL
    func state(at url: URL) throws -> TrashFileState
    func children(at url: URL) throws -> [URL]
    func remove(at url: URL, expected: [String: TrashFileState]) throws
}

struct TrashFileState: Equatable, Sendable {
    let device: UInt32
    let inode: UInt64
    let mode: UInt16
    let owner: UInt32
    let group: UInt32
    let links: UInt16
    let size: Int64
    let blocks: Int64
    let flags: UInt32
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
    let changedSeconds: Int64
    let changedNanoseconds: Int64
    let bornSeconds: Int64
    let bornNanoseconds: Int64
    let volumeIdentifier: String
    let volumeRoot: URL

    var isDirectory: Bool { mode & UInt16(S_IFMT) == UInt16(S_IFDIR) }
    var isUsable: Bool {
        (isDirectory || mode & UInt16(S_IFMT) == UInt16(S_IFREG))
            && flags & 0x40000000 == 0 && !volumeIdentifier.isEmpty
            && volumeRoot.isFileURL && device != 0 && inode != 0
            && (isDirectory || links == 1)
    }

    func sameAncestor(as other: Self) -> Bool {
        device == other.device && inode == other.inode && mode == other.mode
            && owner == other.owner && group == other.group && flags == other.flags
            && bornSeconds == other.bornSeconds && bornNanoseconds == other.bornNanoseconds
            && volumeIdentifier == other.volumeIdentifier && volumeRoot == other.volumeRoot
    }

    func sameMovedObject(as other: Self) -> Bool {
        sameAncestor(as: other) && links == other.links && size == other.size && blocks == other.blocks
            && modifiedSeconds == other.modifiedSeconds && modifiedNanoseconds == other.modifiedNanoseconds
    }
}

extension TrashFileState {
    init(stat value: Darwin.stat, volumeIdentifier: String, volumeRoot: URL) {
        self.init(device: UInt32(bitPattern: value.st_dev), inode: UInt64(value.st_ino),
                  mode: value.st_mode, owner: value.st_uid, group: value.st_gid,
                  links: value.st_nlink, size: value.st_size, blocks: value.st_blocks,
                  flags: value.st_flags,
                  modifiedSeconds: Int64(value.st_mtimespec.tv_sec),
                  modifiedNanoseconds: Int64(value.st_mtimespec.tv_nsec),
                  changedSeconds: Int64(value.st_ctimespec.tv_sec),
                  changedNanoseconds: Int64(value.st_ctimespec.tv_nsec),
                  bornSeconds: Int64(value.st_birthtimespec.tv_sec),
                  bornNanoseconds: Int64(value.st_birthtimespec.tv_nsec),
                  volumeIdentifier: volumeIdentifier, volumeRoot: volumeRoot)
    }
}

struct LocalTrashFileSystem: TrashFileSystem {
    func moveToTrash(at url: URL) throws -> URL? {
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }

    func trashDirectory(for url: URL) throws -> URL {
        try FileManager.default.url(for: .trashDirectory, in: .userDomainMask,
                                    appropriateFor: url, create: false)
    }

    func state(at url: URL) throws -> TrashFileState {
        var info = Darwin.stat()
        guard Darwin.lstat(url.path, &info) == 0 else { throw TrashOperation.Hold.unavailable }
        // Do not ask URL resource APIs about a link or a cloud placeholder.
        guard info.st_mode & S_IFMT == S_IFDIR || info.st_mode & S_IFMT == S_IFREG,
              info.st_flags & 0x40000000 == 0 else { throw TrashOperation.Hold.incomplete }
        let values = try url.resourceValues(forKeys: [.volumeUUIDStringKey, .volumeURLKey])
        guard let volume = values.volumeUUIDString, !volume.isEmpty,
              let root = values.volume, root.isFileURL else { throw TrashOperation.Hold.unavailable }
        return TrashFileState(stat: info, volumeIdentifier: volume,
                              volumeRoot: root.resolvingSymlinksInPath().standardizedFileURL)
    }

    func children(at url: URL) throws -> [URL] {
        guard let listing = BulkDirScanner.workerListing(atPath: url.path, scratch: BulkScratch()),
              listing.unreadablePaths.isEmpty else { throw TrashOperation.Hold.incomplete }
        return listing.entries.map { url.appendingPathComponent($0.name) }
    }

    func remove(at url: URL, expected: [String: TrashFileState]) throws {
        try VerifiedTrashRemoval.remove(at: url, expected: expected)
    }
}

private extension URL {
    // Foundation can shorten /private/var to /var, whose symlink the ancestor
    // guard rejects. Keep the physical path returned by realpath.
    func canonicalFileURL() throws -> URL {
        guard let resolved = Darwin.realpath(path, nil) else {
            throw TrashOperation.Hold.unavailable
        }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
    }
}
