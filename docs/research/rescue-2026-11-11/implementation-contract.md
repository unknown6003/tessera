# Rescue implementation contract

Outcome: implement the owner-confirmed design-spec.md, including ranked discovery, item review, owner return, exclusions, additional-GB goals and operation-scoped Trash finishing.
Proof: classifier and VM regressions, real Trash fixture checks, native UI/captures/VoiceOver, independent risk review, then both external CI lanes at the exact release commit.
Constraints: 0.x.x; no broad Trash emptying; no private-data analytics; no healthy scan cutoff at 120 seconds; no production app/user preference changes during qualification.

## Ownership for this unit

One feature uses the existing isolated conversation workspace and branch codex/rescue-redesign. No new fourth workspace.
- Parent: ScanViewModel.swift, ContentView.swift, CollectorDock.swift, integration and final review.
- Discovery writer: Engine/CleanupSuggestions.swift, EngineTests.swift, new Tests/RescueDiscoveryTests.swift, discovery implementation note. No parent/UI/Trash paths.
- UI writer: Views/CleanupSuggestionsView.swift, new Views/RescueWorkspaceModel.swift, new Views/RescueReviewView.swift as needed, Tests/RescueWorkspaceTests.swift, UI implementation note. No parent-owned paths.
- Trash writer: Engine/DeletionService.swift, new Engine/TrashOperation.swift, Tests/TrashOperationTests.swift, Trash implementation note. No parent-owned or UI paths.

## Shared interface facts

CleanupReport groups and rankedRecommendations will be ordered by descending physical bytes, stable path/category ties, without risk tiers leading. Protected rules retain precedence. Existing category IDs stay; new protected IDs may include owner.docker, owner.orbstack, owner.simulators, owner.photos, owner.media, owner.mail, owner.snapshots.

UI keeps CleanupSuggestionsView(vm:onMoveToTrash:) source-compatible. It may add onFinishTrash: (() -> Void)? = nil. Parent provides that action only while a current operation can be safely reviewed. The parent owns the permanent-removal presentation and VM integration.

WindowedRows is now module-internal in ContentView.swift for reuse. It takes children: [FileNode], pitch: CGFloat, folderID: ObjectIdentifier?, selectedIndex: Int?, and a row ViewBuilder closure. Its offset-based windowing must stay intact.

UI coordinator may observe the existing VM through public state/readTree/addToCollector/startScan, and own its local kept-item persistence, owner handoff, optional goal, and review snapshots. It must not add independent removal paths. New typed state can stay inside its own deep module.

The Trash module must preserve existing DeletionService.perform and wrappers. It adds a tracked result for successful Trash moves and a small operation review/finish interface. The parent integrates actual tracked results into VM state; no record can be minted from a guessed Trash path.

Writers do not commit or change checkouts. Parent integrates and commits serially after reviewing the combined diff. Native proof is required, not brace counting.
