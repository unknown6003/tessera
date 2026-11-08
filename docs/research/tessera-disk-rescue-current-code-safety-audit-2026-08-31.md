# Current cleanup safety audit

Date: 2026-08-31

Scope: read-only review of the Tessera cleanup suggestion, staging, Trash, and permanent-delete path at `e88d163d770afa14d5177562053341585a68692f`.

No Tessera source changed during this audit.

## User path today

1. `ScanViewModel` scans a volume and builds a `FileNode` tree.
2. `CleanupClassifier` classifies that in-memory tree from lowercased names and paths only.
3. `CleanupSuggestionsView` shows `safeRegenerable` and review groups.
4. `Add all safe` calls `stageSafeCleanup`, which adds every node in `report.safeNodes` to the collector.
5. The user reviews the collector and confirms Move to Trash or a separate permanent-delete action.
6. `DeletionService` calls `FileManager.trashItem` or `FileManager.removeItem` for each stored URL.

## Proven gaps

| Gap | Current proof | Product risk |
| --- | --- | --- |
| Safe confidence comes from path only | `CleanupSuggestions.swift:3-8`, `93-141` | A matching name can cross owner, active-state, recovery, sync, and offline boundaries. |
| A matched directory stops traversal | `CleanupSuggestions.swift:148-174` | Tessera treats the whole subtree as one unit and cannot protect a durable child after the parent matches. |
| `node_modules` is always safe | `CleanupSuggestions.swift:46-50`, `96` | Local dependencies, workspaces, offline sources, global links, active tools, and unique generated state can invalidate the rebuild promise. |
| Package stores are one safe class | `CleanupSuggestions.swift:49-51`, `108-115` | Shared stores, build caches, environments, global tools, indexes, and package sources have different reclaim and recovery behavior. |
| Browser caches have no owner-state gate | `CleanupSuggestions.swift:61-63`, `117-121` | An open browser can write while Tessera stages or moves the path. A widened rule can reach profile state. |
| The top-level `Library/Caches` tree is safe | `CleanupSuggestions.swift:52-54`, `123-126` | One button can stage a large multi-owner tree without per-owner checks or batch limits. |
| One button stages every safe match | `CleanupSuggestionsView.swift:17-39`, `ScanViewModel.swift:330-341` | A single classification error expands to the full safe total. |
| Staging does not reclassify or inspect live state | `ScanViewModel.swift:338-345` | A path can change between scan and staging. Running owners, locks, sync, and mounted-volume state are not checked. |
| Trash execution uses stored URLs directly | `ScanViewModel.swift:519-545`, `DeletionService.swift:19-40` | There is no last-step device, inode, type, owner, open-handle, sync, or rule-version check. |
| Results record failures, not verified reclaim | `DeletionService.swift:19-63`, `ScanViewModel.swift:554-590` | A successful Trash move is not the same as free space. Partial results cannot explain held bytes, Trash occupancy, snapshots, or delayed accounting. |

## Existing strengths

- Scanning does not delete or move data.
- Suggestions do not auto-stage after a scan.
- Review-tier groups never enter `Add all safe`.
- Move to Trash and permanent deletion use separate methods and controls.
- The removal path keeps failed URLs visible and prunes only successful paths.
- The collector suppresses ancestor and descendant double counting.

These strengths are useful, but they do not prove that the current safe tier is safe enough for a rescue workflow.

## Required first implementation slice

Do not add more path rules first. Build the safety gate that every rule must pass:

1. Give each recommendation a rule ID, rule version, exact scan identity, owner, storage role, and current risk.
2. Separate detection from action eligibility. A path match can create a candidate, but it cannot grant safe staging.
3. Revalidate exact path, type, device and inode identity, owner state, open handles, locks, sync, mounted-volume identity, recovery source, and rule version before staging and again before action.
4. Split a matched parent when protected or unknown child roles exist.
5. Replace `Add all safe` with a bounded plan that shows every candidate and preselects only items that pass the current gates.
6. Record requested, moved, failed, held, still in Trash, and verified free-space change separately.
7. Keep permanent deletion outside the rescue slice until the recoverable path passes real macOS tests.

## Test cases the current suite lacks

- A `node_modules` tree with a local file dependency or unique unpublished package.
- A package store with hardlinks or APFS clones where apparent bytes exceed exclusive reclaim.
- A cache whose owner is running and writing.
- A path replaced between scan and confirmation with a new device, inode, type, or mount identity.
- A matched parent that contains protected durable state.
- A partial Trash batch with one held item and no immediate free-space change.
- A provider or owner action that bypasses Trash.
- A saved plan resumed after owner, sync, path, permission, or rule-version state changes.
