# Tessera major update

Outcome: replace the app shell and remove the long scan tail, slow cleanup and UI stalls.
Proof: native Release measurements, full tests, wide/deep tree fixtures and app screenshots.
Constraints: preserve the saved Rescue work; keep exact-path identity checks and Trash by default. Do not claim a complete two-minute scan for an arbitrary device or volume.

## Restored state

- Main: e88d163, clean. No local stash or other live worktree.
- Preserved rescue branch: origin/codex/tessera-disk-rescue, f28bc07, version 0.1.9.
- The saved branch descends from main. It includes Rescue, identity checks, cloud coverage boundaries, source research and nine reference screenshots.
- This update starts from f28bc07 in a separate worktree. Main and both saved remote branches stay intact.
- Copy-on-write probe failed on this host. Use Git worktrees, at most three live spaces.

## Ownership

The primary agent owns scanner, model, cleanup and integration changes. A separate UI writer owned views and TesseraApp in a tool-prepared checkout. Integration was serial. Scanner, saved-work, design and review agents had read-only scopes. Native verification uses the linked Mac, with bounded commands and no user-file deletion.

## Source findings to verify

- BulkDirScanner rereads folders at 8,192 entries with FileManager and per-entry lstat.
- Scan progress caps discovered bytes at 99 percent even when the remaining tree is unknown.
- The watchdog excludes stalled workers while directories remain queued.
- Directory mtime does not prove a whole subtree is unchanged. Disable subtree reuse until a valid change journal exists.
- Cleanup runs synchronous file operations on the main actor and saved Rescue performs capacity and persistence work per item.

## Release gate

Do not publish a major release before native Release build, correctness tests, full-scan measurements and real app visual checks pass. Keep failure and incomplete coverage visible.
