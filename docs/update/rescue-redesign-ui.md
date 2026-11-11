# Rescue redesign, UI unit

Date: 11 November 2026. Branch `codex/rescue-redesign`, base `33a06f8`.
Writer scope: the four UI files below and this note. No commit.

Outcome: one ranked Rescue list, review in the main area, kept items, an additional-GB goal and owner return checks.
Proof so far: source review only. This Linux host has no Swift toolchain. Nothing here was compiled, run, captured or narrated by VoiceOver.
Constraints: no removal path, no analytics, 0.x.x, flat dark style with the cyan accent.

## Files

- `Tessera/Views/RescueWorkspaceModel.swift` (new). Coordinator, seams and value types.
- `Tessera/Views/RescueReviewView.swift` (new). The group review surface.
- `Tessera/Views/CleanupSuggestionsView.swift` (rewritten). Ranked list, header, goal, status, kept items, existing result card and Cleanup List footer.
- `TesseraTests/RescueWorkspaceTests.swift` (new). 11 tests through the coordinator.

`project.yml` globs `Tessera` and `TesseraTests`, so `xcodegen` picks up the new files. The checked-in `Tessera.xcodeproj` does not list them yet. The parent owns that step.

## Public interface

`CleanupSuggestionsView`

- `init(vm:onMoveToTrash:onFinishTrash:)`. Old calls with `vm:` and `onMoveToTrash:` still compile.
- `init(vm:workspace:onMoveToTrash:onFinishTrash:)`. Use this if ContentView owns the coordinator.
- `onFinishTrash` shows a flat "Finish these Trash items…" button in the existing result card. It shows only when the callback is set and the last result was a Trash move. The view never removes anything.

`RescueHost` (protocol, `@MainActor`). `ScanViewModel` conforms in an extension inside `RescueWorkspaceModel.swift`:

| Requirement | Live value |
| --- | --- |
| `rescueSelectedSource` | `selectedSourceURL?.standardizedFileURL` |
| `rescueReportSource` | `rescuePlan?.sourcePath` |
| `rescueRevision` | `treeRevision` |
| `rescueReport` | `cleanupReport` |
| `rescueIsScanning` | `isScanning` |
| `rescueIsBusy` | `isDeleting` |
| `rescueMeasuredAt` | `rescuePlan?.measurement.measuredAt` |
| `rescueStage(_:)` | `addToCollector(_:)` |
| `rescueStartScan(_:)` | `startScan(volumeURL:)` |
| `rescueRead(_:)` | `readTree { _, _ in work() }` |

`RescueWorkspaceModel` (`@MainActor`, `ObservableObject`)

- `init(host:opener:defaults:readCapacity:currentIdentity:observeApp:)` for tests.
- `convenience init(vm:)` subscribes to `vm.objectWillChange` and app activation notifications.
- `hostDidChange()` rebuilds rows only when revision, report source or measurement time changes. It closes a stale review and runs a deferred owner check.
- Rows: `rows`, `visibleRows`, `filter`, `searchText`, `count(for:)`, `route(for:)`.
- Review: `openReview(_:)`, `closeReview(notice:)`, `review`, `reviewItems`, `reviewNodes`, `selection`, `toggle(_:)`, `selectAllEligible()`, `clearSelection()`, `selectedBytes`, `canStage`, `stageSelection() async`, `detailItemID`, `returnGroupID`, `reviewNotice`.
- Kept items: `keep(_:)`, `canKeep(_:)`, `restore(_:)`, `isResolved(_:)`, `keptForCurrentSource`, `showsExcluded`. Stored as JSON under `rescue.keptItems.v1` in the injected `UserDefaults`.
- Goal: `setGoal(additionalGB:)`, `checkGoal()`, `clearGoal()`, `goal`. `RescueSpaceGoal.status` is `.unverified`, `.progress(change:remaining:)` or `.reached(change:)`.
- Owner: `openOwner(_:revealing:) async`, `cancelHandoff()`, `appDidResignActive()`, `appDidBecomeActive()`, `handoff`.

## Behavior

Ranking. Rows come from `report.groups`. Kept items are subtracted, then rows sort by allocated bytes, largest first. Ties keep the report's order. A protected group is one row in the same list, labelled "managed by its app". Filters are All, Files to review and Managed by apps.

Review. "Review files" or "Review options" opens the group in place of the list. Sorting and the eligibility walk run through `vm.readTree`, off the main thread. Rows use `WindowedRows` with a fixed 50 pt pitch. Details open in a pane under the list, so row height never changes. Nothing starts selected.

Staging. An item is held when it is protected, has no stable identity, sits under a protected path, contains protected data, or contains unscanned data. Staging checks scan revision and report source. It then checks each chosen object's current identity off the main thread, checks revision and source again, and calls `addToCollector` for unchanged objects only. Changed objects are held and counted in the notice.

Back. `closeReview` keeps filter and search. The list then focuses the opened group's action button and reveals that row with the existing `RevealOnAppear`.

Kept items. A Keep matches category, path, source path, volume and object identity (resource ID, or device and inode). A new object at the same path is not hidden. Items without a stable identity cannot be kept. Kept data never goes to analytics; this module sends no analytics.

Goal. The baseline is Free now (`volumeAvailableCapacity`) for the source's drive at the moment the goal is set. The goal compares later Free now readings on the same volume ID. A missing reading or another volume gives "Not verified". Staged and Trash bytes never enter it. The 75% target is no longer shown. `vm.rescueCapacityGoal` still exists in the VM but is unused here.

Owner return. `openOwner` opens the app by bundle ID, or reveals the item in Finder for Finder routes. A successful open arms one pending check. The check runs only after Tessera resigns and then regains active state, for the same selected source. While a scan or removal runs, the check waits and runs on the next `hostDidChange` after the lock clears. A source change drops it. A failed open shows the owner steps and reveals the item. It does not arm a check.

## Owner routes

From `coverage-and-hogs.md`. No route runs a destructive command.

| Category ID | Route |
| --- | --- |
| `owner.docker`, `owner.virtualdisk` with a Docker path | Docker, `com.docker.docker` |
| `owner.orbstack`, `owner.virtualdisk` with an OrbStack path | OrbStack, `dev.kdrag0n.MacVirt` |
| `owner.virtualdisk` with `.utm` | UTM, `com.utmapp.UTM` |
| `owner.simulators` | Xcode, `com.apple.dt.Xcode`, Settings > Components |
| `owner.photos` | Photos, `com.apple.Photos` |
| `owner.mail` | Mail, `com.apple.mail` |
| `owner.communication` under Library/Messages | Messages, `com.apple.MobileSMS` |
| `owner.snapshots` | Disk Utility, `com.apple.DiskUtility` |
| `owner.backup`, `owner.cloud`, `owner.profile`, `system.trash`, any unknown ID | Finder reveal plus plain steps |

The bundle IDs are from my knowledge, not checked on a Mac. A wrong ID falls back to the Finder reveal and the steps, so the row still works.

## Tests

`RescueWorkspaceTests`, 11 cases, Swift Testing, fakes for host, opener, capacity and identity:

1. Size ranking across risk tiers, filters and counts.
2. Keep, persistence across a new coordinator, replacement at the same path, other source, restore.
3. No Keep without a stable identity.
4. Review starts empty, holds the unidentified item, stages only the unchanged object, Back keeps the group.
5. Managed store items cannot be selected.
6. A revision change and a source change drop the review and stage nothing.
7. A busy scan blocks staging.
8. Goal change, loss, reached, other drive, unknown reading, staged bytes ignored.
9. Owner return runs once and only after leaving through this flow.
10. Owner return waits for the busy lock and drops a changed source.
11. A missing owner falls back to Finder, arms nothing, and an unknown ID keeps a Finder route.

None of these ran here.

## Limits for the parent

- ContentView wraps Rescue in a `ScrollView`. `WindowedRows` has its own scroll view, so the review list has a fixed height of up to 420 pt. For a full-height list, render `RescueReviewView` outside that outer `ScrollView` when `workspace.review != nil`, using the `workspace:` init.
- Back restores focus and reveals the row. It does not restore the exact pixel offset. Exact offset needs the parent's outer scroll view.
- With the default init, the coordinator lives as long as the Rescue view. Switching to Explore drops a pending owner check and the Back position. Kept items persist. Hoist the coordinator into ContentView to keep them.
- `rescueIsBusy` reads `isDeleting` only. `readTree` already refuses work during removal. Add the parent's Trash operation lock if it is separate.
- `hostDidChange` runs on every `objectWillChange` of the VM, deferred to the main run loop. It compares three scalars before any work.
- Rows mark a group managed when `group.risk == .protected`. Parent ordering of `report.groups` is respected as the tie order only.
- The coverage notice shows all `coverage.notes` in a disclosure. The engine caps them at 8.
- Native proof still needed: compile, the 11 tests, 820x600 and wide captures, keyboard path including Cmd-[ for Back, VoiceOver narration, Increase Contrast, 100,000-item review scroll.
