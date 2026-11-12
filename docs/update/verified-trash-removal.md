# Verified Trash removal helper

11 November 2026. Implementation handoff for the parent on `codex/rescue-redesign`.

Outcome: acquire and check the exact operation-owned Trash tree before permanent removal. Keep a changed object or partial remainder inspectable.
Proof: disposable-directory tests through the helper, with deterministic acquisition and leaf swaps. Native execution is still required.
Constraints: only the new helper, tests and this note are owned here. No caller integration, project-file edits, commits, network, installs or releases.

## Integration interface

```swift
try VerifiedTrashRemoval.remove(at: item.trashURL, expected: record.manifest)
```

The root manifest key is `""`. Every other key is a relative descendant path. The manifest includes the root and has at most 10,000 entries. Depth is capped at 128 components. All entries must be usable regular files or directories, owned by the current user, on the recorded volume and device, with no file flags. Regular files must have one link. Invalid names, missing parents, unsupported metadata, remote mounts, and unreadable directories hold the operation.

The interface is visible inside the Tessera module. It cannot have Swift `public` access while `TrashFileState` is internal. It uses public macOS system calls. No private Apple interface is used.

The parent must pass its existing private manifest. Do not build a fresh manifest to retry a failure. Keep the operation, owner, protection, revision and explicit-selection checks in the caller. Replace the local adapter's path-recursive removal with this interface only after native qualification. Existing production callers remain unchanged in this work unit.

Catch `VerifiedTrashRemoval.Failure`. Its fields are:

- `reason`: `invalidManifest`, `unsupported`, `changed`, `system(errno)` or `interrupted`.
- `recoveryURL`: the staging folder to reveal in Finder. It is nil if staging has not started or has already been removed.
- `removedEntryCount`: completed successful unlinks, including directories. It is neither bytes recovered nor a success count for selected items.

A failure can leave the original item in place, hold it in staging, or leave part of it in staging. Keep that detail in the parent result. Offer Finder reveal for a non-nil recovery URL and the original Trash item otherwise. Do not close the result and discard the failure. The helper never launches Finder.

The internal overload takes `trashDirectory` and a per-call checkpoint closure for tests. Production uses the two-argument interface, which asks FileManager for the correct Trash directory with `appropriateFor`. Tests use an owned temporary `.Trash` and never invoke real Finder Trash.

## Removal and recovery

The helper opens every ancestor from `/` using `openat`, `O_DIRECTORY` and `O_NOFOLLOW`. It checks the Trash parent device, ownership, mode and local mount flag. Parent volume UUID and volume root must match the recorded volume. Resource lookup is read-only; destructive work uses descriptors.

It creates a random 0700 staging folder in that parent. Before acquisition, it writes a 0600 `recovery.json` with the original Trash URL, recorded device and inode, and every relative path's deterministic staging slot. It flushes the file with `fsync` and `F_FULLFSYNC`, then syncs staging and parent descriptors. Failure to flush stops acquisition. The record is local, private recovery data. It must never enter analytics.

The journal is an inspect-only map. It records neither new authority nor a promise to restore. `item` is the first acquired root. `entry-N` maps to the journal entry with that slot. A slot can be absent because it has not been used or because its unlink completed. Inspect the actual remainder. No automatic restore or deletion resume is implemented.

Acquisition uses descriptor-relative `renameatx_np` with `RENAME_EXCL`. It never overwrites a staging entry. The root receives an exact stat check before acquisition and a `sameMovedObject` check afterward because rename changes ctime. The acquired root and the FULL expected manifest must pass before the first unlink. A root replacement acquired by rename is held with the journal.

The deletion walk uses opened directory descriptors. Each remaining name is moved into its own staging slot before its final identity and metadata check. A leaf replacement therefore remains in its slot. Files must still match their recorded stat state, allowing the rename ctime change. Directories retain their recorded identity and fixed metadata. Our own child renames change directory size, times and link count, so those directory fields are not reused after child removal. A directory must be empty after acquisition before `unlinkat(..., AT_REMOVEDIR)`.

All deletion uses descriptor-relative `unlinkat`. There is no recursive full-path fallback. Changes, unreadable entries, extra contents, I/O errors and injected interruptions stop work. The journal and remainder stay in staging. Sync failures after an unlink report the completed unlink count. The old manifest is never replaced with a snapshot of the remainder.

After full success, the helper checks that only its journal remains, removes the journal and empty staging folder through descriptors, and syncs the Trash parent. A cleanup failure after all target entries were removed can leave an empty folder without a journal. A final parent-sync failure can report a nil recovery URL because staging is already gone. These are cleanup/durability failures, not evidence that the removed tree can be recovered.

## Safety limits

POSIX has no atomic recursive compare-and-delete transaction. The final `fstatat` and `unlinkat` still have a name race. There is also an interval between each stat check and the next operation. This helper reduces accidental namespace races and holds the deterministic replacements in the test seams. It cannot exclude hostile mutation by another process with the same UID or writes through existing open handles. Mode 0700 does not exclude that process. Such a process can also move staging or an ancestor and make the reported recovery path stale.

The manifest is stat metadata, not a byte hash or a complete ACL/xattr history. Root and leaf rename checks cannot compare the old ctime after rename. External changes that leave all compared fields unchanged can escape detection. Remote mounts, flagged files, links, special objects, excessive depth/count and unavailable volume metadata are held. Unsupported durability operations hold acquisition. Route unsupported trees to Finder; do not add weaker fallbacks.

Crash recovery depends on filesystem and device durability behavior. The journal is flushed before any object is acquired. Per-entry moves and unlinks sync the affected directories. This is source intent, not power-loss proof. There is no recovery discovery UI in this slice. The parent must surface held folder locations and must not restore deletion authority across launch.

## Verification and remaining proof

Added 12 native fixture tests for exact file/nested-tree deletion, unrelated sibling survival, root replacement, leaf replacement and slot mapping, acquired-slot replacement, changed/new full manifests, leaf and ancestor symlinks, partial failure, journal-before-acquisition survival, exclusive collision, late new directory contents, and unsupported hard links. Parameterized loops cover multiple cases within two tests. All mutations and cleanup remain under disposable owned directories. Checkpoint failures exercise real filesystem work up to that point; they are not real permission or device failures.

This Linux host has no Swift or Darwin SDK. Only source checks ran here. No build, native test, syscall behavior, power-loss test or product success is claimed. The Xcode project is outside this slice's ownership; the parent must include these sources in app and test targets if its project setup does not discover them.

Before enabling the caller, compile under the app's Swift 6/macOS deployment target and run `VerifiedTrashRemovalTests` plus `TrashOperationTests`. Check Darwin imports, `renameatx_np` flag behavior, `fdopendir` ownership, and directory `fsync`/file `F_FULLFSYNC` on real APFS and each supported local filesystem. Prove the production Trash-directory lookup on the startup and an external local volume with disposable fixtures. Test real permissions/flags and interrupted cleanup, not only checkpoint throws. Run crash-boundary probes around journal flush, rename, unlink and cleanup. Test parent propagation of partial counts and Finder recovery URL, owner revalidation and capacity measurement. Keep finishing disabled until the parent accepts this proof and the stated concurrency limits.

A separate second source pass found two main issues and fixed them: root ctime was not checked before acquisition, and cleanup could discard the journal despite an unexpected staging entry. The helper now checks exact root state before acquisition and requires staging to contain only the journal before cleanup. Local-mount checks and typed lookup failures were also added. Cleanup retains and checks the original journal descriptor so a replacement journal name is held. This was a self-review, not an independent risk review. Parent review is still required.

No external API source was fetched under the no-network constraint. The parent risk report links Apple's rename and unlink source manuals. Native SDK compilation and runtime tests remain the authority for this implementation.
