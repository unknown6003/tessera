# Rescue review triage

11 November 2026. Source fixes await native checks.

- Risk round 2: accepted the package descendant gap. Revalidation now includes packages, and a disposable fixture adds a protected disk below an unchanged package root during an over-budget capture.
- Spec 1: added a labelled Not measured section after measured groups. Coverage findings and snapshot guidance have no invented byte total.
- Spec 2: added Retry for a failed owner launch, retaining its route and source. A source change drops that retry. The new test retries after the owner becomes available.
- Spec 3: a same-source rescan now revokes the old review token but retains the operation's exact Trash records. Opening a new review after that scan gets a new source/revision snapshot and live validation. A different source still drops removal authority. A persistent session-level Show Trash route no longer depends on the result message being visible.
- Spec 4: rejected IDs now leave an explicit held issue without inventing a filesystem location. The sheet stays open when issues remain.
- Spec 5: not retained as a defect. Section 6 limits finishing to this operation's items and requires a current review. It does not require removing every item in the batch. An explicit subset stays within that boundary and avoids broadening removal authority.
- Spec 6: retained as a native check. The alert makes Cancel the default; source alone cannot prove initial focus.

Primary review also found that Back discarded explicit file choices. Choices now survive Back for the same group, source and scan revision. A new revision starts empty. Both paths have coordinator tests, still awaiting macOS execution.

The 1f44e66 native run compiled but failed 11 tests with 13 issues, chiefly at the shared tracked-move helper. No checks were weakened. A focused native diagnosis must identify which tracking guard rejects the disposable filesystem and whether the replacement hook actually runs. The result does not qualify the current descriptor-based helper, which was added later.
