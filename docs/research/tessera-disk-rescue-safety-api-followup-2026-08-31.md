# Safety API follow-up

Date: 2026-08-31

This lane adds 14 first-party Apple API and platform records. It does not add user-demand evidence. It defines what Tessera can measure and what those measurements cannot prove.

The structured records are in [tessera-disk-rescue-safety-api-ledger.jsonl](./tessera-disk-rescue-safety-api-ledger.jsonl).

## Findings

### One identifier is not enough

Apple exposes path, resource identifier, file-system identifier, content identifier, resource type, allocated size, total size, volume identifier, and volume capacity as separate values. Apple also says the internal file identifier is not stable across every file system or mount.

Tessera should capture a short-lived identity set at scan time, then compare the same set before staging and again before action. A matching path or inode alone is not proof that the candidate is still the same object.

### Running application state is partial evidence

`NSWorkspace.runningApplications` gives Tessera a current application inventory. Launch notifications alone omit background and `LSUIElement` apps. Neither method maps every helper process or open file to an owner.

Use the app inventory as one owner signal. Keep process, open-handle, lock, file-change, and owner-adapter checks.

### Coordination does not cover low-level writes

`NSFilePresenter` and `NSFileCoordinator` help participating apps coordinate changes. Apple says direct low-level file operations do not notify file presenters.

A coordinated Trash or owner action still needs an active-owner hold and post-action measurement. Coordination cannot turn a path rule into a safe rule.

### File events invalidate snapshots

FSEvents can report that a hierarchy changed. Events can also be coalesced. Apple's guide recommends monitoring before the scan and rescanning directories that change during it.

Saved cases and scan results need an invalidation model. An event is a reason to rescan, not proof of what changed or whether a candidate remains safe.

### Cloud state has more than two values

Apple exposes local download status, current-version state, upload completion, upload and download errors, unresolved conflicts, and owner actions for download or local eviction. Moving data into or out of iCloud is a coordinated write that can block.

Tessera must keep local materialization, current-version proof, upload proof, conflict state, eviction, download, relocation, Trash, and remote deletion as separate fields and actions.

### Capacity depends on the user's task

Apple separates capacity available for important user-requested work from capacity available for optional work. This supports the settled decision to ask for the user's immediate goal and working-space buffer.

The result should name the capacity source. It should not compare a candidate's logical size with an unrelated available-space value and call the difference verified reclaim.

## Implementation consequences

1. Add `scanIdentity`, `currentIdentity`, `volumeIdentity`, `resourceType`, `fileIdentifier`, `resourceIdentifier`, `contentIdentifier`, and `identityMatch` to recommendation evidence.
2. Add `scanStartedAt`, `scanCompletedAt`, `lastChangedAt`, `changeEventState`, and `requiresRescan` to a rescue case.
3. Add `ownerApplicationState`, `backgroundOwnerState`, `openHandleState`, and `coordinationCoverage` as separate checks.
4. Add iCloud and provider fields for local copy, current version, upload, download, conflict, error, and action scope.
5. Keep every download, eviction, move, sync, and owner repair action explicit. Scanning must not trigger one.
6. Treat Apple capacity values as named measurements with different meanings. Use the value that matches the immediate rescue goal.

## Counterexamples

- A stable path can point to a replaced file.
- A matching inode can be invalid after a remount.
- A file presenter can miss a direct low-level write.
- A launch notification can miss a background helper.
- An FSEvent can identify a changed directory without naming every changed child.
- A cloud file can exist remotely while upload failed, a conflict remains, or the local copy is not current.
- A large logical candidate can move to Trash without changing the capacity needed for the user's next task.

## Next system lane

The next pass should add first-party and source-level evidence for open-file discovery, APFS clone and compression allocation, volume UUID and mount changes, coordinated Trash result URLs, File Provider materialization and eviction, and required-reason API declarations for capacity checks.
