# Rescue spec review

Axis: Spec only. Base `65e272109ad906810ff3b8a3d01d217cd1fb1934`, target `b2a8d192c4b7d41e48ccbe230510322eac9208b6` (HEAD, clean, five commits). Spec: `docs/research/rescue-2026-11-11/design-spec.md` (confirmed `implement`, 2026-11-11T15:51Z) and `implementation-contract.md`. This was a source read only. No build or test ran, and this review proves no runtime behavior.

## Findings

1. **Missing: section for unmeasured rows.** Spec line 41: "put unmeasured findings in a labelled section after measured rows. Do not manufacture zero". `RescueWorkspaceModel.rebuildRows` sums `physicalBytes` (an `Int64`) and sorts every group into one list. No unknown state or section exists.
2. **Partial: failed owner launch has no Retry.** Spec line 86: "A failed launch or failed check explains the issue and offers Retry." `.failed` in `CleanupSuggestionsView.swift:232` shows only a label.
3. **Wrong path: an owner return removes the Finish step.** Spec lines 102 and 110 say to offer Finish as a separate step, and that lost tracking must give "a safe Finder route". `runOwnerReturnRefresh` calls `rescueStartScan`, and `startScan` calls `invalidateTrackedTrash()` (`ScanViewModel.swift:182`). Trigger: move items to Trash, open an owner, then return. The Finish step disappears. The only Finder route is the dock's "Show Trash", which shows only while the removal summary is undismissed (`CollectorDock.swift:131`).
4. **Partial: some held results cannot be inspected.** Spec line 108: "Keep failed items inspectable". In `finishTrackedTrash`, `.rejected` adds to `held` but adds no `trashFinishIssues` entry. If every non-removed item is `.rejected`, `TrashFinishReviewView.finish()` dismisses the sheet, and the held item is not shown.
5. **Unasked scope: per-item finishing.** Spec line 102 says "Finish these Trash items". `TrashFinishReviewView` adds checkboxes for each item, and nothing starts selected. The spec does not ask for a subset. If the agreed design is batch-only, this is a deviation.
6. **Needs a native check: Cancel as initial focus.** Spec line 105: "Cancel is the initial focus." The alert puts `.keyboardShortcut(.defaultAction)` on the Cancel role. Only a native capture can confirm the focus.

## Looks implemented (source only)

- Largest-first sort with stable ties. Kept items match by identity and source.
- The goal measures change in Free now from a same-volume baseline. Staged and Trash bytes are not counted.
- The owner return fires once, survives a switch between Explore and Rescue, waits while busy, and is dropped when the source changes.
- Revision, source and busy checks happen before and after staging.
- Finishing is limited to items from this operation and has a second confirmation. Held items have Finder routes.

Families: all 12 have a category, an owner route or a coverage note. Snapshots, purgeable space and unaccounted usage appear as coverage text, not as ranked rows.

Worst issue: finding 3.
