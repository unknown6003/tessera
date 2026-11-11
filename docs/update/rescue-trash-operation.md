# Operation-scoped Trash implementation

Outcome: one in-memory operation can track successful Trash destinations, review them, and permanently remove an explicit subset after a separate confirmation. Existing `DeletionService.perform(_:permanently:)`, `trash(_:)` and `delete(_:)` keep their signatures and behavior.

Proof available here: source inspection and `git diff --check` on Linux. No Swift compiler or Xcode is installed. The new native tests have not compiled or run. This is not native behavior, performance, release or design qualification.

Constraints: this writer changed only `DeletionService.swift`, new `TrashOperation.swift`, new `TrashOperationTests.swift`, and this note. No project, ViewModel, UI, catalog, release, preferences, keychain or analytics changes. No install, network action, commit or actual user Trash access.

## Parent interface

Keep one `TrashOperation` instance for one confirmed Move to Trash action. It is `@unchecked Sendable`; its lock serializes all state and filesystem work. Run its synchronous methods off MainActor. Do not invoke the operation again from an injected adapter or cancellation closure.

```swift
let operation = TrashOperation()
let outcome = DeletionService.performTracked(
    preparedRemoval,
    operation: operation,
    isCancelled: { Task.isCancelled }
)
```

`performTracked(_:operation:isCancelled:) -> TrashOperation.MoveOutcome` returns:

- `error: DeletionService.DeletionError?`. Nil means the source move succeeded. Prune the original tree only on that basis.
- `item: TrashOperation.Item?`. Present only when the actual move result passed manifest capture and identity checks. Do not build records from original paths or guessed Trash paths.
- `trackingHold: TrashOperation.Hold?`. A successful move may have no usable destination or manifest. Report the move as successful, hold the in-app permanent step for that item, and offer Finder guidance. Never retry removal against its original path.

A thrown capture or cancellation error before the move appears in `error.underlying` as `TrashOperation.Hold`. Ordinary filesystem errors also remain available as `underlying`. Existing prepared preflight failures keep their existing error form.

`Item` exposes immutable `id`, `operationID`, `originalURL`, `trashURL`, `identity` and `volumeIdentifier`. Its initializer is file-private. The operation retains the private manifest. Display records grant no deletion authority.

Immediately before presenting permanent-removal confirmation, get fresh owner state on MainActor, then call this off MainActor:

```swift
let review = operation.review(ownerState: ownerState, isCancelled: { Task.isCancelled })
```

`review(ownerState:isCancelled:) -> TrashOperation.Review` returns `operationID` and `[ReviewedItem]`. Each entry has `item`, `id` and optional `hold`. Display the exact current `trashURL` and scope. Only entries with nil `hold` may be selected. Nothing starts selected. This module does not present confirmation.

After explicit confirmation, refresh owner state and call off MainActor:

```swift
let results = operation.finish(
    review,
    selecting: selectedIDs,
    ownerState: ownerState,
    isCancelled: { Task.isCancelled }
)
```

`finish(_:selecting:ownerState:isCancelled:) -> [TrashOperation.Result]` consumes one review. Results are `.removed(Item)`, `.held(Item, Hold)`, `.failed(Item, Error)` or `.rejected(UUID, Hold)` for an unknown selection. A mixed selection containing an unknown ID holds the whole request. Wrong-operation and stale review requests cannot remove anything. An empty selection consumes a valid review without removing anything. A new review invalidates the old one. Reviews expire after five minutes. Failed and held items stay inspectable and need another review before retry. A removed item leaves the operation.

`Hold` cases are `cancelled`, `unavailable`, `changed`, `protectedContents`, `incomplete`, `ownerUnverified`, `wrongOperation`, and `staleReview`. Provide plain user text at the presentation layer. Do not log paths, identities, raw errors or manifests to analytics.

Call `operation.invalidate()` when the parent discards this operation, changes source, or invalidates its action context. Release it when done. There is no persistence or relaunch recovery. Cancel in the confirmation makes no finish call. The parent still owns its scan/source revision checks, busy lock, current owner check, second confirmation, Cancel focus, result counts and fresh capacity reading. Do not count moved bytes as recovered space.

Owner checks in this module hold Xcode paths or captured Xcode descendants unless the supplied state is `.stopped`. This matches the current owner adapter scope. It does not invent owner detection for other stores. Pass a freshly read `CleanupOwnerState.current()` at each review and finish, and retain all existing parent owner checks.

## Safety implementation

The only production destination source is `FileManager.trashItem(at:resultingItemURL:)`. The returned parent must equal the volume-appropriate public `FileManager.url(for: .trashDirectory, in: .userDomainMask, appropriateFor:create: false)` result. A destination equal to or below the original target is rejected. Missing destination, volume identity or root means no tracked authority. Cross-volume copies that lose identity are also untracked.

Before moving, capture live regular files and directories, inspect protected source paths and canonical source paths, reject opaque/dataless states, and compare against the prepared identity again. After moving, require the same relative manifest and object identities. Root ctime may change due to the move; descendants must match exactly. Capture post-move state as the permanent baseline.

The manifest has at most 10,000 entries per item and a five-second cooperative capture budget per pass. It includes every descendant, including package contents. It records device, inode, mode, owner, group, link count, size, allocated blocks, flags, nanosecond mtime, ctime, birth time, volume UUID and volume root. Symlinks, special files, multiply linked regular files, missing metadata, provider placeholders, cross-device descendants and unreadable directory listings are held. Directory state is checked again after enumeration. Entries are also checked at their original paths against current protection rules.

Before each permanent action, recheck the Trash root, all ancestor identities through `/`, volume, current scan identity, the complete descendant manifest, original-path protection rules and supplied owner state. Check protected destination ancestry too. The only Trash protection exemption is the proven Trash container and its immediate `.Trashes` container for per-volume Trash. A tracked child named `.Trash`, or another protected descendant or ancestor, remains blocked. No arbitrary caller URL enters `finish`.

## Required native checks and limits

Parent must add the two new Swift files to the application and test source lists in `Tessera.xcodeproj/project.pbxproj`, or regenerate that file through the project source generator. That path was outside this writer ownership.

Run `TrashOperationTests`, the existing removal and engine deletion tests, then native Debug and Release checks with the configured macOS SDK. The requested separate `DeletionRegressionTests` source does not exist at this base; deletion coverage is in `EngineTests.swift` and `RemovalRegressionTests.swift`.

New tests use only owned disposable temporary fixtures. Their adapter moves to a fixture-local `.Trash` directory and uses real lstat, volume metadata, bulk listings and FileManager removal. They never call Finder Trash. Tests cover explicit safe subsets, unrelated items, wrong operations, mixed selections, changed/replaced/restored/missing files, deep content changes, new protected contents, symlink items and ancestors, missing metadata/root/destination, stale and consumed reviews, invalidation, cancellation, remove failure, bounded capture, scan gaps, forged ready protected targets, and wrapper compatibility. This is temporary-filesystem integration, not Finder Trash integration. The five-minute expiry has no elapsed-time native test.

Before shipping, add an owned macOS Finder Trash integration check that moves one disposable fixture and cleans up only its exact tracked destination. Verify actual SDK bridging, resource-value names, APFS metadata stability after a move, package behavior and per-volume Trash discovery. No such check ran here. Filesystems without volume UUIDs or stable enough metadata fail closed; support is unproved outside the native fixture environment.

Public path-based FileManager removal has a TOCTOU gap. Another process can replace an ancestor, rewrite a file, or change directory contents after the final check and before or during `removeItem`. Cancellation cannot interrupt an active Foundation filesystem call or an in-progress recursive removal. The capture budget bounds stored state and cooperative traversal, not kernel I/O latency or the temporary full directory listing allocated by the existing bulk reader. Finish rechecks each item but is not atomic across a subset. A failed recursive remove can have removed part of a directory; its next review will hold the changed manifest. These are unresolved shipping risks, not native proof or a promise of race-free deletion. A separate native risk review must decide whether to ship this public-API path or hold directory finishing pending stronger removal mechanics.

A clean second source pass by this writer found and fixed three issues before handoff: cross-file access for the move entry point, missing per-ID rejection for foreign selections, and a canonical-path protection gap through a source ancestor alias. This was not independent review.
