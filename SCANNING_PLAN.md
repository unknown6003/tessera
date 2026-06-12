# Storage Optimizer — Fast Scanner Design

## Problem

The current `FileScanner` is single-threaded and makes two round-trips per entry:

1. `FileManager.contentsOfDirectory` → one `getdirentries` + `stat` per entry  
2. Separate `url.resourceValues(forKeys:)` call per entry (for package detection)

On a 500 GB volume with ~1 million files this is painfully slow: each syscall has
kernel overhead, and doing them serially leaves ~15 of 16 CPU cores idle.

## Target: ≥ 10× speedup

Two orthogonal improvements, each delivering a multiplier:

| Technique | Mechanism | Typical gain |
|---|---|---|
| `getattrlistbulk` | Read all entries + attrs in one syscall | 4–8× |
| Parallel traversal | N workers across CPU cores | ~N× (bounded by I/O) |
| Combined | Both together | 10–25× on SSD |

---

## Technique 1: `getattrlistbulk(2)`

`getattrlistbulk` is a Darwin-specific syscall that fills a caller-supplied buffer
with attribute records for *all* directory entries in one call. Each record contains:

- Entry name (`ATTR_CMN_NAME`)
- Object type: VREG / VDIR / VLNK / VBLK / … (`ATTR_CMN_OBJTYPE`)
- Inode number (`ATTR_CMN_FILEID`) — for hard-link dedup
- Link count (`ATTR_CMN_NLINKS`) — skip inode tracking when nlinks == 1
- Allocated on-disk size for files (`ATTR_FILE_ALLOCSIZE`)
- `ATTR_CMN_FLAGS` bit `UF_HIDDEN` + `SF_IMMUTABLE` for hidden/system nodes
- `ATTR_CMN_RETURNED_ATTRS` — which attrs were actually returned (defensive)

This replaces the per-entry `stat` + `getdirentries` with a single kernel call.

### Buffer size

256 KB is a good balance (usually covers 500–2000 entries at once).

### Returned-attrs guard

Not all attributes are available on all volumes (e.g. network mounts). Check the
`ATTR_CMN_RETURNED_ATTRS` bitmap before reading each field.

### Package detection

`ATTR_CMN_OBJTYPE == VDIR` but the entry has a known-package extension (`.app`,
`.bundle`, `.framework`, `.plugin`, `.kext`, `.docx`, etc.): treat as opaque file,
do not descend. This is faster and equally correct vs the per-URL resource values
call we used before.

---

## Technique 2: Parallel traversal

A **bounded work queue** pattern:

```
┌───────────────────────────────────────────────┐
│ Global directory queue (lock-protected)       │
│   [dir₀, dir₁, dir₂, …]                      │
└────────────┬──────────────────────────────────┘
             │ pop
      ┌──────▼──────┐  ┌─────────────┐  ┌─────────────┐
      │  Worker 0   │  │  Worker 1   │  │  Worker N-1 │
      │ bulk-read   │  │ bulk-read   │  │ bulk-read   │
      │ push subdirs│  │ push subdirs│  │ push subdirs│
      └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
             │ results        │                 │
             └────────────────┴─────────────────┘
                              │
                       assemble tree
```

Workers run on `DispatchQueue.global(qos: .userInitiated)` via
`DispatchGroup` + semaphore for bounded concurrency. Each worker:

1. Pops a directory URL from the shared queue (locked)
2. `open(O_RDONLY | O_DIRECTORY | O_SYMLINK)` the directory
3. Calls `fgetattrlistbulk` in a loop until it returns 0
4. For each entry:
   - `VLNK` → skip
   - `VDIR` and not a package → push child URL to the shared queue
   - `VDIR` and package, `VREG`, `VBLK`, etc. → record size, inode
5. Emits a `DirResult(url, children)` to a results channel
6. Closes the fd

A coordinator collects `DirResult`s and builds the `FileNode` tree bottom-up once
all workers are done (or incrementally with a parent-map).

### Worker count

`min(ProcessInfo.processInfo.activeProcessorCount, 8)` — more than 8 is usually
I/O-bound on spinning disks; SSDs can go higher. 4 is safe on any Mac.

### Hard-link dedup across workers

Shared `Set<InodeID>` guarded by an `os_unfair_lock` (or `NSLock`). Only checked
for entries where `nlinks > 1`.

---

## Implementation files

| File | Role |
|---|---|
| `Engine/BulkDirScanner.swift` | `getattrlistbulk` reader; C-interop buffer parsing; per-fd bulk walk. Returns `[EntryInfo]`. |
| `Engine/FileScanner.swift` | Public `scan()` API; orchestrates the work queue, workers, result assembly, progress callbacks, tree construction. |

`Model/FileNode.swift` and `ViewModel/ScanViewModel.swift` are **unchanged** (public API is identical).

---

## Fallback

If `getattrlistbulk` returns a negative errno on a given fd (rare: network FS,
certain FUSE mounts), `BulkDirScanner` falls back to `FileManager.contentsOfDirectory`
for that directory only, ensuring the scan always completes.

---

## Verification

```bash
# Time before/after
time du -sh /Users  # reference ground truth
```

Run a scan of `/Users` in the app, compare total sizes and timing:
- Sizes should match `du -sh --apparent-size /path` to within 1–2% (hard-link and
  package boundary differences are expected).
- A full Macintosh HD scan should complete in < 60 s on a modern SSD Mac (vs several
  minutes for the single-threaded baseline).

Also verify:
- Hard links not double-counted: `cp -l file hardlink && scan parent dir`
- Symlinks skipped: `ln -s /etc symlink && scan parent dir`  
- Permission-denied dirs skipped gracefully without aborting the scan
