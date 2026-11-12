# Trash risk review

11 November 2026. Separate source review of completed Trash and parent integration paths on `codex/rescue-redesign`, HEAD `33a06f8edf9d471434a81cda9254c56500c9bd0e`, plus scoped working changes and the three new Trash source/test files. Findings refer to the working files. No implementation edits, commits, checkout changes or child agents.

Outcome: check destructive authority against design-spec section 6 and the parent integration note. Proof: source paths and fixture assertions. Constraints: bounded 12-minute pass, no native Swift toolchain, no inspection of ongoing UI/discovery work beyond classifier public gates. Read project/global rules, engineering workflow, model guide, code-review, high-risk and unslop instructions. Standards and full Spec reviews belong to the parent; this report covers Risk only.

## Findings

### R1, P1: final validation does not bind removal to the checked object

`Tessera/Engine/TrashOperation.swift:217–230, 430`.

Trigger: after `validate` returns, another process running as the user renames the reviewed `~/.Trash/a` to `saved` and renames an unrelated directory to `~/.Trash/a`. `removeItem` then recursively removes that unrelated directory. No symlink traversal is needed. A descendant can also be replaced after its last check. Impact: irreversible deletion outside the reviewed object set.

Evidence: the adapter receives only `record.item.trashURL`; the lock excludes Tessera callers, not filesystem writers. Existing replacement tests mutate before `finish`, so they do not cover this interval. Prove with a disposable adapter that swaps the directory inside `remove` before calling the local adapter.

Remedy: until a stronger implementation has native proof, disable in-app finishing and offer Finder. A public-API hardening approach is to open and verify directory descriptors without following links, move the entry into a same-volume private staging directory with exclusive descriptor-relative rename, then verify the acquired object's identity and manifest before any unlink. A replacement acquired by the rename must remain recoverable and must never be deleted. Walk through verified descriptors and use relative `unlinkat`, never a recursive path-based fallback. Preserve a recovery record for crashes and failed restores. [Apple's rename API](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/man/man2/rename.2) supports descriptor-relative and exclusive rename; [unlinkat](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/man/man2/unlink.2) anchors removal to a directory descriptor.

Limits: `fstatat` followed by `unlinkat` still has a leaf-name race. Private staging reduces accidental namespace changes but does not exclude a hostile same-user process or writes through existing open descriptors. These APIs do not supply an atomic recursive compare-and-delete transaction. Do not claim arbitrary mutable trees are solved by this approach. Hold unsupported cases and use Finder.

### R2, P1: the capture-limit fallback skips the later identity check

`TrashOperation.swift:108–124`; `DeletionService.swift:97–110`.

Trigger: while listing a folder with more than 10,000 entries, another process renames the original away and puts a replacement at its source path. The returned listing exceeds the capture budget, throwing `.incomplete`. The catch moves the replacement immediately. Impact: an unreviewed object enters Trash; new protected contents can move too. This is recoverable but violates source authority.

Evidence: the normal branch checks `target.identity` again at line 120. The fallback bypasses it and the ancestor checks, which last ran before capture. The budget fixture proves a successful untracked move only; it does not mutate the source in this gap.

Remedy: keep the approved untracked-move policy, but rerun prepared-target identity, ancestor and live protection/coverage checks before the fallback. A budget failure must not authorize a changed source. Test a replacement injected during the over-budget listing. This narrows the added gap; it does not remove the ordinary path-based move race.

### R3, P2: owner state can stay stale for the whole finish batch

`Tessera/ViewModel/ScanViewModel.swift:1114–1116`; `TrashOperation.swift:217–249`.

Trigger: Xcode is stopped when finishing begins, then starts while an earlier selected directory is being checked or removed. A later Xcode record still receives `.stopped`. Impact: deletion proceeds despite the owner becoming active.

Evidence: the view model reads owner state once. Every per-record validation compares against that same value; each capture can take five seconds. The owner test supplies `.active` before the call and misses a mid-batch transition.

Remedy: supply a fresh owner-state probe per relevant item after expensive checks and before removal. Add a fixture that switches owner state between two records. A last check still cannot prevent an owner launch immediately afterward; document that limit.

### R4, P2: partial recursive failure loses useful recovery detail

`TrashOperation.swift:225–230`; `ScanViewModel.swift:1122–1135`; `Tessera/Views/TrashFinishReviewView.swift:32–36, 79–80`.

Trigger: recursive removal deletes one child, then fails on another due to permissions, flags or I/O. Impact: the UI reports one failed item, discards the error, and closes. The retained manifest no longer matches, so the next review holds the remainder as changed. It displays only the obsolete original path and offers no reveal action for the remainder.

Evidence: failures retain the old record; integration reduces `.failed` to a count. The failure fixture throws before removing any child, so it proves retention only for a no-change failure.

Remedy: preserve per-item failure and partial-progress state. Keep the remaining Trash location inspectable with a Finder reveal action. Do not silently grant new authority by replacing the old manifest. Test an adapter that removes one owned child and then throws, plus a native failure fixture.

### R5, P2: permanent finishing never measures capacity again

`ScanViewModel.swift:1132–1143`.

Trigger: any successful permanent finish. Impact: capacity and goal evidence remain from before finishing, contrary to design-spec section 6's required new measurement.

Evidence: this method publishes counts and analytics, then returns. Its comment delegates measurement to a future scan, but it schedules no scan or capacity read. The sheet only dismisses. Recoverable removal already takes before/after measurements.

Remedy: perform and publish a same-source, same-volume capacity reading after finish, including partial failure. Keep a failed read unverified. Do not infer reclaimed capacity from allocated bytes.

## Checked boundaries and limits

- Records come only from the adapter's actual move destination. The production adapter uses `trashItem` and `appropriateFor` Trash lookup. Unknown destinations never gain finish authority. No Empty Trash fallback exists.
- Operation ID, private review token, expiry, stored review contents and explicit IDs prevent caller URL authority, mixed-operation selection and replay. The review starts empty; the second alert assigns Return to Cancel in source. Native focus remains unproved.
- Source/root/revision checks and scan/removal/tree-reader guards exist at entry. Rescan, cached-source switch and new cleanup invalidate the prior operation. No source-lock bypass was retained from the scoped source read. The lock is released while the sheet is open; later mutations must cause finish to reject the snapshot.
- Protection checks include descendants and original/current locations, with only known Trash ancestors exempted. Stable pre-call replacement, restore and ancestor changes are held. The fallback adds no finish record, and successful untracked moves are pruned. Integration drops `trackingHold`, so it does not explain which moved items lack finish support.
- Existing `trash`, `delete` and `perform` wrappers retain their signatures and result shape. Their direct permanent path remains path-based. The new batch capability does not make those wrappers operation-scoped.
- Engine cancellation checks exist, but both integration calls omit the cancellation closure. The GCD bridge ignores task cancellation, and the sheet disables Cancel while working. Thus engine cancellation fixtures do not prove app cancellation. A running `removeItem` cannot be rolled back or interrupted safely; wire a token to stop later work if cancellation is required.
- All Trash tests use a temporary adapter and explicitly avoid Finder Trash. No tests or native builds were run here. No runtime success is claimed.

Outstanding native proof: macOS build and Trash suites; disposable real Finder Trash fixtures on the startup and an external volume, including name collisions and actual returned destinations; deterministic replacement at the final removal boundary; fallback source/ancestor replacement and protected-descendant mutation; owner transition during a batch; partial recursive failure and inspectable remainder; task cancellation between items; fresh capacity success/failure; keyboard and VoiceOver through both confirmations with Cancel initially focused; both external CI lanes on the exact clean release commit.
