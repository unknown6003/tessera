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

The Standards pass retained no documented-rule breaches and two duplication concerns. The stat-to-manifest conversion now has one initializer. Both owner status placements now use one view. These refactors need native compilation.

Group review now has a focused keyboard path for arrows, Home/End, Page Up/Down and Space. The existing offset-based row window reveals the focused item. The coordinator builds its ID-to-index table once per review/filter change, so focus lookup does not scan row IDs. Native 100,000-item latency, Tab/focus, VoiceOver and keyboard selection checks remain open.

The Mac relay returned HTTP 502 on the next diagnosis attempt. No diagnosis job started. Preserve the failed 1f44e66 evidence at `/Users/abdwy/.local/share/tessera-native-2f56c3f56c2b`. Before another full run, instrument a private copy to report the exact tracking hold and first rejecting guard, and prove whether the replacement hook runs. Check before/after stat fields, actual volume roots, APFS firmlink paths and URL comparison semantics. These are hypotheses, not established causes.

The staging audit found one more stale-state path: a generated Xcode group could be staged after Xcode started, although final removal would still hold it. Staging now checks current owner state before and after the identity worker. Active or unknown ownership closes that review without staging. A captured active/unknown owner also makes a generated item ineligible. Coordinator cases cover an already active owner, a stopped-to-active change between probes, and unknown state. These cases still need native execution.
