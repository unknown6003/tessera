# Tessera disk rescue implementation handoff

Status: ready for a separate agent to build the read-only rescue slice. Destructive owner actions remain gated on open Rounds 7 and 10, plus a narrow owner-boundary rewrite after those choices are settled.

Owner: the next Tessera implementation agent. Ammar is the decision maker.

Last checked: 2026-08-31.

## Read first

The checkout is `/Users/abdwy/development/tessera`.

- Branch: `main`.
- `HEAD` and `origin/main`: `e88d163d770afa14d5177562053341585a68692f`.
- The checkout was fetched from GitHub and is up to date.
- Current research files are untracked under `docs/research/`.
- No Tessera source code changed during the research pass.
- No user files were deleted, moved to Trash, or emptied.

Read these files before planning code:

1. [tessera-disk-rescue-ethnographic-study.md](./tessera-disk-rescue-ethnographic-study.md)
2. [tessera-disk-rescue-research-loop.md](./tessera-disk-rescue-research-loop.md)
3. [tessera-disk-rescue-research-manifest.json](./tessera-disk-rescue-research-manifest.json)
4. [tessera-disk-rescue-source-ledger.jsonl](./tessera-disk-rescue-source-ledger.jsonl)
5. [tessera-disk-rescue-github-issue-ledger.jsonl](./tessera-disk-rescue-github-issue-ledger.jsonl)
6. [tessera-disk-rescue-market-scan.jsonl](./tessera-disk-rescue-market-scan.jsonl)
7. [tessera-disk-rescue-community-source-ledger.jsonl](./tessera-disk-rescue-community-source-ledger.jsonl)
8. [tessera-disk-rescue-product-experience-ledger.jsonl](./tessera-disk-rescue-product-experience-ledger.jsonl)
9. [tessera-disk-rescue-system-facts-ledger.jsonl](./tessera-disk-rescue-system-facts-ledger.jsonl)
10. [tessera-disk-rescue-owner-documentation-ledger.jsonl](./tessera-disk-rescue-owner-documentation-ledger.jsonl)
11. [tessera-disk-rescue-agent-lane-2026-08-31.md](./tessera-disk-rescue-agent-lane-2026-08-31.md)
12. [tessera-disk-rescue-developer-creator-ledger.jsonl](./tessera-disk-rescue-developer-creator-ledger.jsonl)
13. [tessera-disk-rescue-creator-workspace-ledger.jsonl](./tessera-disk-rescue-creator-workspace-ledger.jsonl)
14. [tessera-disk-rescue-ai-model-storage-ledger.jsonl](./tessera-disk-rescue-ai-model-storage-ledger.jsonl)
15. [tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md](./tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md)
16. [tessera-disk-rescue-sample-library-ledger.jsonl](./tessera-disk-rescue-sample-library-ledger.jsonl)
17. [tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md](./tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md)
18. [tessera-disk-rescue-mlx-local-ai-ledger.jsonl](./tessera-disk-rescue-mlx-local-ai-ledger.jsonl)
19. [tessera-disk-rescue-decision-ledger.json](./tessera-disk-rescue-decision-ledger.json)
20. [validate-tessera-disk-rescue-corpus.sh](./validate-tessera-disk-rescue-corpus.sh)
21. [tessera-disk-rescue-game-library-agent-lane-2026-08-31.md](./tessera-disk-rescue-game-library-agent-lane-2026-08-31.md)
22. [tessera-disk-rescue-game-library-ledger.jsonl](./tessera-disk-rescue-game-library-ledger.jsonl)
23. [tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md](./tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md)
24. [tessera-disk-rescue-package-cache-ledger.jsonl](./tessera-disk-rescue-package-cache-ledger.jsonl)
25. [tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md](./tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md)
26. [tessera-disk-rescue-app-profile-ledger.jsonl](./tessera-disk-rescue-app-profile-ledger.jsonl)
27. [tessera-disk-rescue-safety-api-followup-2026-08-31.md](./tessera-disk-rescue-safety-api-followup-2026-08-31.md)
28. [tessera-disk-rescue-safety-api-ledger.jsonl](./tessera-disk-rescue-safety-api-ledger.jsonl)
29. [tessera-disk-rescue-communication-local-probe-2026-08-31.md](./tessera-disk-rescue-communication-local-probe-2026-08-31.md)
30. [tessera-disk-rescue-game-followup-2026-08-31.md](./tessera-disk-rescue-game-followup-2026-08-31.md)
31. [tessera-disk-rescue-package-followup-2026-08-31.md](./tessera-disk-rescue-package-followup-2026-08-31.md)
32. [tessera-disk-rescue-profile-followup-2026-08-31.md](./tessera-disk-rescue-profile-followup-2026-08-31.md)
33. [tessera-disk-rescue-communication-followup-2026-08-31.md](./tessera-disk-rescue-communication-followup-2026-08-31.md)
34. [tessera-disk-rescue-game-followup-ledger.jsonl](./tessera-disk-rescue-game-followup-ledger.jsonl)
35. [tessera-disk-rescue-package-followup-ledger.jsonl](./tessera-disk-rescue-package-followup-ledger.jsonl)
36. [tessera-disk-rescue-profile-followup-ledger.jsonl](./tessera-disk-rescue-profile-followup-ledger.jsonl)
37. [tessera-disk-rescue-communication-followup-ledger.jsonl](./tessera-disk-rescue-communication-followup-ledger.jsonl)
38. [collect-tessera-github-followup.sh](./collect-tessera-github-followup.sh)
39. [summarize-tessera-disk-rescue-corpus.sh](./summarize-tessera-disk-rescue-corpus.sh)
40. [tessera-disk-rescue-game-followup-page2-ledger.jsonl](./tessera-disk-rescue-game-followup-page2-ledger.jsonl)
41. [tessera-disk-rescue-package-followup-page2-ledger.jsonl](./tessera-disk-rescue-package-followup-page2-ledger.jsonl)
42. [tessera-disk-rescue-profile-followup-page2-ledger.jsonl](./tessera-disk-rescue-profile-followup-page2-ledger.jsonl)
43. [tessera-disk-rescue-communication-followup-page2-ledger.jsonl](./tessera-disk-rescue-communication-followup-page2-ledger.jsonl)
44. [tessera-disk-rescue-game-followup-page3-ledger.jsonl](./tessera-disk-rescue-game-followup-page3-ledger.jsonl)
45. [tessera-disk-rescue-package-followup-page3-ledger.jsonl](./tessera-disk-rescue-package-followup-page3-ledger.jsonl)
46. [tessera-disk-rescue-profile-followup-page3-ledger.jsonl](./tessera-disk-rescue-profile-followup-page3-ledger.jsonl)
47. [tessera-disk-rescue-communication-followup-page3-ledger.jsonl](./tessera-disk-rescue-communication-followup-page3-ledger.jsonl)
48. [tessera-disk-rescue-game-followup-page4-ledger.jsonl](./tessera-disk-rescue-game-followup-page4-ledger.jsonl)
49. [tessera-disk-rescue-package-followup-page4-ledger.jsonl](./tessera-disk-rescue-package-followup-page4-ledger.jsonl)
50. [tessera-disk-rescue-profile-followup-page4-ledger.jsonl](./tessera-disk-rescue-profile-followup-page4-ledger.jsonl)
51. [tessera-disk-rescue-communication-followup-page4-ledger.jsonl](./tessera-disk-rescue-communication-followup-page4-ledger.jsonl)
52. [tessera-disk-rescue-game-followup-page5-ledger.jsonl](./tessera-disk-rescue-game-followup-page5-ledger.jsonl)
53. [tessera-disk-rescue-package-followup-page5-ledger.jsonl](./tessera-disk-rescue-package-followup-page5-ledger.jsonl)
54. [tessera-disk-rescue-profile-followup-page5-ledger.jsonl](./tessera-disk-rescue-profile-followup-page5-ledger.jsonl)
55. [tessera-disk-rescue-communication-followup-page5-ledger.jsonl](./tessera-disk-rescue-communication-followup-page5-ledger.jsonl)
56. [tessera-disk-rescue-game-followup-page6-ledger.jsonl](./tessera-disk-rescue-game-followup-page6-ledger.jsonl)
57. [tessera-disk-rescue-package-followup-page6-ledger.jsonl](./tessera-disk-rescue-package-followup-page6-ledger.jsonl)
58. [tessera-disk-rescue-profile-followup-page6-ledger.jsonl](./tessera-disk-rescue-profile-followup-page6-ledger.jsonl)
59. [tessera-disk-rescue-communication-followup-page6-ledger.jsonl](./tessera-disk-rescue-communication-followup-page6-ledger.jsonl)
60. [tessera-disk-rescue-game-followup-page7-ledger.jsonl](./tessera-disk-rescue-game-followup-page7-ledger.jsonl)
61. [tessera-disk-rescue-package-followup-page7-ledger.jsonl](./tessera-disk-rescue-package-followup-page7-ledger.jsonl)
62. [tessera-disk-rescue-profile-followup-page7-ledger.jsonl](./tessera-disk-rescue-profile-followup-page7-ledger.jsonl)
63. [tessera-disk-rescue-communication-followup-page7-ledger.jsonl](./tessera-disk-rescue-communication-followup-page7-ledger.jsonl)
64. [tessera-disk-rescue-game-followup-page8-ledger.jsonl](./tessera-disk-rescue-game-followup-page8-ledger.jsonl)
65. [tessera-disk-rescue-package-followup-page8-ledger.jsonl](./tessera-disk-rescue-package-followup-page8-ledger.jsonl)
66. [tessera-disk-rescue-profile-followup-page8-ledger.jsonl](./tessera-disk-rescue-profile-followup-page8-ledger.jsonl)
67. [tessera-disk-rescue-communication-followup-page8-ledger.jsonl](./tessera-disk-rescue-communication-followup-page8-ledger.jsonl)
68. [tessera-disk-rescue-game-followup-page9-ledger.jsonl](./tessera-disk-rescue-game-followup-page9-ledger.jsonl)
69. [tessera-disk-rescue-package-followup-page9-ledger.jsonl](./tessera-disk-rescue-package-followup-page9-ledger.jsonl)
70. [tessera-disk-rescue-profile-followup-page9-ledger.jsonl](./tessera-disk-rescue-profile-followup-page9-ledger.jsonl)
71. [tessera-disk-rescue-communication-followup-page9-ledger.jsonl](./tessera-disk-rescue-communication-followup-page9-ledger.jsonl)
72. [tessera-disk-rescue-game-followup-page10-ledger.jsonl](./tessera-disk-rescue-game-followup-page10-ledger.jsonl)
73. [tessera-disk-rescue-package-followup-page10-ledger.jsonl](./tessera-disk-rescue-package-followup-page10-ledger.jsonl)
74. [tessera-disk-rescue-profile-followup-page10-ledger.jsonl](./tessera-disk-rescue-profile-followup-page10-ledger.jsonl)
75. [tessera-disk-rescue-communication-followup-page10-ledger.jsonl](./tessera-disk-rescue-communication-followup-page10-ledger.jsonl)

The evidence loop is still open. The count is a checkpoint, not permission to stop researching. The forty follow-up ledgers are automated candidates and need manual coding before they affect a safety rule or demand claim.

## Development readiness

An implementation agent may start now on the read-only vertical slice:

1. Trace the existing scan and suggestion flow.
2. Add a Rescue entry and the `needs_rescue` through `plan_ready` states.
3. Show named measurement sources, coverage gaps, ranked candidates, exact paths, owners, reasons, risk, and side effects.
4. Save and reopen a local rescue case without uploading paths or filenames.
5. Keep all risky, owner-managed, active, unclear, backup, virtual-disk, cloud, profile, and communication items review-only or protected.
6. Add tests for classification, stale identity, permission gaps, measurement mismatch, and no-mutation behavior.

Do not implement raw backup, VM, profile, communication, or permanent-delete actions in this slice. Round 7 decides backup and virtual-disk owner action, recovery proof, and host plus guest evidence. Round 10 decides pause behavior, blocker explanation, and background work after failure. The agent can use hard holds and owner handoffs until those answers arrive.

## Mission

Make Tessera useful when the Mac is nearly full and the user cannot decide what may leave safely.

The first experience should produce a short, ranked rescue plan. It should explain the cause, show the risk, keep the action recoverable, and prove what changed. The user should not need to move between a storage map, Finder, Terminal, System Settings, and several web searches to finish one job.

The product is a local macOS app. Scanning, filenames, paths, trees, and file content stay local. Ammar chose an optional preference-sync path for later. That choice does not authorize cloud processing or syncing personal file data, and the exact future sync payload still needs its own review.

## Settled user choices

These choices came from the first TempliLink interview and are ready to guide the design:

| Decision | User choice | Implementation meaning |
| --- | --- | --- |
| Entry point | Rescue first | Lead with the low-space job, not the tool drawer or chart. |
| Default staging | Safe only | Preselect only high-confidence rebuildable items. |
| Candidate scope | Rank all | Show safe, review, and protected results in one plan with clear separation. |
| Execution | Confirm Trash and verify | Use Move to Trash as the main action, then measure the result. |
| Recurrence | Remember now | Save useful context locally, then re-check it before every later run. |

"Remember now" is not a deletion authorization. A saved choice must never bypass a fresh scan, current ownership check, or visible review.

## Canonical decision state

Use [tessera-disk-rescue-decision-ledger.json](./tessera-disk-rescue-decision-ledger.json) as the authority for submitted choices. It records the page slug, interaction ID, submitted time, and selected option IDs. Rounds 2 through 6, 8, and 9 are settled. Rounds 7 and 10 remain open. The old Round 11 form is deferred for rewrite.

### Settled recurrence and review choices

| Decision | User choice | Implementation meaning |
| --- | --- | --- |
| Reminder surface | Threshold plus optional schedule | Keep both disabled until the user enables them. A reminder opens review and never cleans in the background. |
| Memory scope | Specific saved profile | Store user-approved rules with version and revalidation data. Never treat a saved profile as deletion authority. |
| Evidence depth | Short reason with expandable proof | The rescue view stays readable while exact evidence remains close. |
| Active or unclear items | Review-only handoff | Keep them visible, never preselect them, name the owner, and offer the owner app. |
| Empty Trash | Separate step | Moving to Trash and freeing volume space are different decisions. |
| Preference privacy | Local default with optional sync later | Keep file data local. Define and review a narrow preference payload before any future sync work. |

The `r21` through `r26` TempliLink pages are superseded because each fresh page carries the current corpus and decision frontier. Do not use them for new decisions. The current page is [tessera-disk-rescue-study-corpus-r27](https://templink.bdwy.xyz/tessera-disk-rescue-study-corpus-r27). It shows the development gate, settled rounds, and only the current frontier.

### Settled safety decisions

Round 3 was submitted on `tessera-disk-rescue-study-corpus-r12`.

| Decision | User choice | Implementation meaning |
| --- | --- | --- |
| Active owner state | Hard hold and handoff | An open handle or running owner can turn cleanup into a larger incident. |
| Possible only local copy | Archive or back up first | Trash restores a path but cannot recreate lost session or project state. |
| Verification mismatch | Continue other items that still pass | Stop the mismatched item. Re-check every remaining item independently and do not widen the batch. |

These choices are settled. Do not add a manual override until its scope, warning, and audit record have their own decision.

### Settled creator-context decisions

Round 5 was submitted on `tessera-disk-rescue-study-corpus-r14`.

| Decision | User choice | Why it matters |
| --- | --- | --- |
| Creator cache action | Source-aware purge or owner handoff | A cache path can be tied to an active project, external media, or an owner-app precondition. |
| Cache retention | Opt-in time or size guard | Users want prevention after repeated growth, but silent deletion is not acceptable. |
| Active project state | Hard hold during render or analysis | A live writer can refill the disk or make a rebuild expensive while the user is working. |

These choices are settled. A saved creator preference must never stage a changed project, library, or cache path without a fresh owner and state check.

### Settled cloud-context decisions

Round 6 was submitted on `tessera-disk-rescue-study-corpus-r14`.

| Decision | User choice | Why it matters |
| --- | --- | --- |
| Provider-backed action | Source-aware eviction or owner handoff | Dropbox, OneDrive, Google Drive, and iCloud use different local states and remote-delete semantics. |
| Cloud state detail | Provider-specific state | Online-only, locally available, mirrored, streamed, materialized, and Remove Download are not interchangeable. |
| Online-only size | Show logical and physical values | Finder or provider accounting can show a large logical value while local reclaim is small, or hide a provider cache outside the visible path. |

These choices are settled. A cloud preference must never authorize a remote delete or bypass a completed-sync and current-state check.

### Open Round 7: backup and virtual-disk decisions

The backup and virtual-disk pass adds the first current decision gate. The recommendations below remain open.

| Decision | Recommended default | Why it matters |
| --- | --- | --- |
| Backup or VM action | Owner-app handoff | Time Machine, device backups, Docker, Parallels, and UTM each own a different restore or reclaim operation. |
| Recovery proof | Require a verified copy or restore point | A Trash move cannot recreate a lost backup, VM state, guest partition, or persistent volume. |
| Disk-image evidence | Show host plus guest or runtime state | Logical size, physical size, snapshots, memory, and guest partitions can disagree with the host file size. |

The current TempliLink page asks these three questions. A backup or virtual-disk preference must never authorize raw bundle deletion or bypass shutdown, snapshot, backup, owner, or guest-state checks.

### Settled rescue continuity and transaction-budget decisions

Round 8 was submitted on `tessera-disk-rescue-study-corpus-r17`.

| Decision | User choice | Why it matters |
| --- | --- | --- |
| Rescue finish line | Ask for the immediate goal and calculate a temporary-space buffer | An update, install, export, or build may need more working space than the size of one item. |
| Interrupted rescue | Save a local resumable case | The user may close the app, lose the entry point, or need to return after an owner action. |

These choices are settled. A saved rescue case must never move files by itself. It may preserve scan coverage, selections, and explanations, but it must re-check every path and state before any later action.

### Settled measurement and recovery decisions

Round 9 was submitted on `tessera-disk-rescue-study-corpus-r17`.

| Decision | User choice | Why it matters |
| --- | --- | --- |
| Measurement display | Name each measurement source | Free, Available, logical size, physical size, and an owner-app value can answer different questions. |
| Missed target | Keep suggesting reviewed cleanup | Continue until the target is met, but preserve the risk tiers, exact review, and confirmation boundary. |
| First review scope | Narrow review | Exact paths, inspectable rules, small batches, and Trash-first action make the safe boundary easy to check. |

These choices are settled. A measurement mismatch must remain visible, and a missed target must not turn into permission for unreviewed or broader deletion.

### Open Round 10: post-failure retry decisions

The rescue-failure-retry pass adds the second current decision gate. The recommendations below remain open.

| Decision | Recommended default | Why it matters |
| --- | --- | --- |
| After a failed transaction | Pause and inspect | A retry can repeat the same blocker or make a live sync, backup, or owner process worse. |
| Blocker explanation | Show blocker and owner | The next safe step depends on whether the cause is measurement, permission, sync, backup, or an owner app. |
| Background work after failure | No background work | People distrust hidden activity after a cleanup failure; an observer must be explicit, local, and easy to stop. |

The current TempliLink page asks these three questions. Tessera must preserve the failed transaction, last measurement, exact paths, and error reason without silently retrying or widening the batch.

### Deferred Round 11 rewrite

The old Round 11 form must not return. Its goal-and-buffer choice was settled in Round 8. Its active-work choice was settled in Rounds 3 and 5. Its recovery-proof choice depends on open Round 7. After Rounds 7 and 10 are settled, rewrite only the remaining owner-boundary question using the game-library, package-cache, and app-profile findings.

Tessera should show logical and physical size separately, preserve source or project identity, and never treat an external project location as proof that internal working space is disposable.

The new Logic, Ableton, Unreal, Blender, and Fusion evidence sharpens this gate. A supported relocation must record the source and destination volumes, the owner-recognized active location, temporary working space on every involved volume, missing-volume behavior, and a functional owner-level open test. The old copy must remain protected until those checks pass. These are implementation facts under the settled owner-action and working-set choices, not a new user decision.

The AI-model evidence sharpens the same gate again. An AI model can be installed, loaded, referenced, shared, partially downloaded, historical, or already in Trash. Tessera must use the owner inventory and current process state, build a physical reference graph, and show independently reclaimable bytes instead of summing model names or paths. A relocation needs the exact revision or digest, quantization, link type, temporary path, destination identity, rollback, owner restart, model discovery, and one real load test. These are implementation facts under the settled active-state, owner-action, and working-set choices.

The professional-library evidence makes the owner-action boundary stricter. Download packages, installed samples, applications, plug-ins, owner metadata, licenses, indexes, and update roots are separate objects. A copied library stays protected until the owner registers it, the license or device state passes, the standalone product loads, and the user's DAW or a representative project opens. Package cleanup, content relocation, owner repair, and product removal must remain separate actions.

The newer local-AI evidence makes the recovery-history boundary stricter. Adapters, checkpoints, local datasets, projects, and generated outputs are user-created source state. Fused, converted, quantized, or cached derivatives may be large and still fail to reproduce that source. Tessera should classify recovery value before size and hold source state until a real load plus task test proves the derivative. These are implementation facts under settled safety choices.

## Evidence snapshot

The current corpus contains 3,005 non-automated user and issue evidence URLs, 5,005 automated GitHub candidates, 30 Apple system facts, 426 owner or implementation facts, and 88 market signals. All 58 corpus inputs contain 8,554 unique URLs with no exact or normalized duplicates.

- 1,618 Ask Different questions from 1,860 raw API records.
- 403 GitHub issue or discussion records from 16 repositories.
- 274 GitHub product issue reports.
- 63 sync-storage-adjacent reports.
- 66 maintainer-generated upstream or compatibility signals.
- 77 GitHub repository descriptions kept as market signals, not user evidence.
- 278 Ask Different question bodies sampled across 268 authors.
- 103 GitHub issue records sampled across all 15 repositories.
- 66 Apple Support Community pages and 36 MacRumors pages in the direct community lane.
- 81 community records marked core, 19 adjacent, and 2 unverified.
- 136 Reddit pages, 8 Mac App Store review pages, and 3 App Store product pages in the product-experience lane.
- 118 product-experience records marked core, 18 adjacent, and 11 market signals. The three App Store product pages and eight maker or launch discussions remain market signals.
- 47 independent developer-creator lane records: 41 first-person reports and 6 first-party Unity or Android documentation records.
- 54 creator-working-set lane records: 33 core reports, 3 adjacent counterexamples, and 18 owner facts across Logic Pro, Ableton Live, Unreal Engine, Blender, and Autodesk Fusion.
- 54 AI-model-storage lane records: 25 first-person reports and 29 owner facts across Ollama, Hugging Face, LM Studio, ComfyUI, and AUTOMATIC1111.
- 79 professional sample-library records: 31 core reports, 4 adjacent counterexamples, and 44 owner facts across eight vendor families.
- 61 newer local-AI records: 33 first-person reports and 28 owner or implementation facts across MLX, MLX-LM, Hugging Face Datasets, Draw Things, DiffusionBee, and llama.cpp.
- 156 game-library records: 71 core reports, 30 adjacent counterexamples, and 55 owner facts across eleven launcher or runtime families.
- 224 package-cache records: 104 core reports, 54 adjacent counterexamples, and 66 owner facts across eleven package-manager families.
- 183 app-profile records: 120 core reports, 5 adjacent counterexamples, and 58 owner facts across nine browser, editor, and communication-app families.
- 5,005 automated GitHub follow-up candidates across issue pages 1 through 10: 1,869 game, 1,059 package, 1,187 app-profile, and 890 communication records across 11 repositories. The records are marked `automated_candidate` and are not manually coded behavior evidence.
- 14 Apple Developer records in the separate safety-API lane, in addition to the original system-facts ledger.
- 30 Apple Support and Apple Developer records in the complete system-facts set.
- 426 owner or implementation facts across all authority lanes.
- 8,477 records across the 57 evidence and authority ledger inputs before the separate market scan.
- 8,554 unique records across all 58 corpus inputs after adding the 77-record GitHub market scan.

The two most important limits are simple:

1. A source URL is not an independent participant.
2. Repeated product claims are not proof of safe behavior.

Research must keep adding sources and counterexamples when a feature decision is unclear. Paginate older issue history when the decision needs historical coverage. Keep automated maintainer digests separate from first-person reports.

The community lane adds a measurement and language check. Users report that Free, Available, Storage Settings, Finder, Disk Utility, and disk analyzers disagree. They may delete data, empty Trash, or remove snapshots and still see no immediate change. The implementation must therefore name the measured quantity and report **moved**, **verified reclaimed**, **held**, and **still unexplained** as separate outcomes. Do not use peer-forum commands as safety rules. The community ledger is [tessera-disk-rescue-community-source-ledger.jsonl](./tessera-disk-rescue-community-source-ledger.jsonl).

The product-experience lane adds a second trust test. Users report broad cleanup rules breaking Xcode, cleaners asking for permissions without enough scope explanation, success messages that leave files behind, freezes during drive selection, and paywalls before users can verify value. The creator-cache lane adds direct reports from Resolve, Final Cut Pro, Lightroom, Blender, and After Effects about generated media larger than source media, repeated growth during active work, external scratch volumes, and uncertainty about what a purge changes. The cloud-provider lane adds 13 direct reports about online-only labels, hidden provider caches, delayed optimization, logical-versus-physical size, and fear of deleting remote data. The backup and virtual-disk lane adds 12 direct reports about old-device backups, full Time Machine destinations, deleted VMs that do not release host space, guest capacity mismatches, and live VM runtime state. The cleanup-trust lane adds 10 direct reports about emergency entry, temporary install space, rescan and result failure, cleanup-tool trust, and interrupted review state, plus 3 market-signal discussions. The rescue-continuity lane adds 10 direct reports about measurement conflicts, update and backup working-space pressure, recovery escalation, and exact-control preferences, plus 5 market-signal discussions. The rescue-failure-retry lane adds 10 direct reports about cleanup that does not release measured space, failed backup or update transactions, confusing permission scope, cloud and Photos state, and escalation toward reinstall or factory reset. The developer-creator-state lane adds 34 direct reports about Xcode, Docker, Unity, After Effects, Lightroom, Final Cut Pro, and Time Machine, including external-project versus internal-working-space conflicts, logical versus physical Docker disk size, active generated media, owner-managed state, and backup identity. Review pages for DevCleaner, Cleaner One, and GrandPerspective add repeat-use evidence: periodic prompts, selective owner cleanup, emergency update recovery, visual discovery, and refresh limits. App Store product pages claim preview-first flows, short undo, rescans, exact paths, and local processing. Treat those pages as market signals. For Tessera, the implementation requirement is concrete: explain the permission request before it appears, keep progress cancelable, show per-item action results, identify project scope and rebuild cost, identify provider state and remote-delete scope, identify restore target and host or guest state, ask for the transaction goal and buffer, preserve an interrupted case locally, preserve a recovery escalation state, preserve a failed transaction without silently retrying, and never claim reclaimed space without a new measurement. The product ledger is [tessera-disk-rescue-product-experience-ledger.jsonl](./tessera-disk-rescue-product-experience-ledger.jsonl).

The system-facts lane is the platform guardrail. Apple describes System Data as a catch-all, separates free from available space, and says Trash does not free space until it is emptied. Apple also documents local snapshots, Full Disk Access, File Provider materialized versus dataless copies, syncing Trash, resulting Trash URLs, and coordinated writes. The full source list is [tessera-disk-rescue-system-facts-ledger.jsonl](./tessera-disk-rescue-system-facts-ledger.jsonl). These documents define behavior and API constraints, not user demand.

The owner-documentation lane is the product guardrail. Resolve, Premiere, and Final Cut Pro document scoped generated-media cleanup, regeneration, cache locations, closed-project preconditions, and external-media impact. Dropbox, OneDrive, Google Drive, and iCloud Drive document local states, eviction actions, streaming or mirroring, sync preconditions, and remote-delete boundaries. Apple, Docker, Parallels, and UTM document backup identity, versioned history, prune scope, sparse images, snapshot chains, shutdown requirements, guest state, and reclaim limits. The full source list is [tessera-disk-rescue-owner-documentation-ledger.jsonl](./tessera-disk-rescue-owner-documentation-ledger.jsonl). These documents define owner-app behavior and version-sensitive constraints, not user demand.

The independent developer-creator lane is the latest research addition. It keeps 41 first-person reports from Apple Developer Forums, Stack Overflow, Docker Community Forums, Reddit r/Unity3D, Adobe Community, and Apple Support Communities separate from 6 first-party Unity and Android guides. The lane shows temporary-volume failures, partial installers, active writers, host-versus-guest allocation, external-project limits, scratch-disk spikes, and Time Machine source-side staging. The structured records are in [tessera-disk-rescue-developer-creator-ledger.jsonl](./tessera-disk-rescue-developer-creator-ledger.jsonl); the field notes are in [tessera-disk-rescue-agent-lane-2026-08-31.md](./tessera-disk-rescue-agent-lane-2026-08-31.md). These sources support owner-aware working-set review, not generic cache deletion.

The creator-working-set lane adds 36 direct reports and 18 owner facts across Logic Pro, Ableton Live, Unreal Engine, Blender, and Autodesk Fusion. It shows that sound libraries, Packs, project references, Derived Data Cache, simulation bakes, and offline CAD data can be large for different reasons. Relocation can fail after the bytes move, an external destination can still require system-drive working space, and a cache repair can fail because the cause is not storage. The structured records are in [tessera-disk-rescue-creator-workspace-ledger.jsonl](./tessera-disk-rescue-creator-workspace-ledger.jsonl). These sources require an owner-recognized location, per-volume transaction budget, performance and availability warning, and post-move functional verification.

The AI-model-storage lane adds 25 direct reports and 29 owner facts across Ollama, Hugging Face, LM Studio, ComfyUI, and AUTOMATIC1111. Logical model lists can hide partial transfers, several model names can share one blob, several apps can point to one model file, and an external final path can still stage bytes internally. Loaded, installed, referenced, historical, and partial are different states. The structured records are in [tessera-disk-rescue-ai-model-storage-ledger.jsonl](./tessera-disk-rescue-ai-model-storage-ledger.jsonl), with full notes in [tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md](./tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md). The local read-only probe found no large active model store at common paths, so the adapter must be able to return no material candidates.

The professional sample-library lane adds 31 direct reports, 4 adjacent counterexamples, and 44 owner facts across Native Instruments, Spitfire Audio, Arturia, Toontrack, EastWest, UVI, IK Multimedia, and Steinberg. It shows that downloaded packages, installed samples, applications, plug-ins, presets, indexes, licenses, updates, and host-visible state are separate storage roles. A package can be replaceable after a verified install, while an apparently identical library copy can be unusable until the owner registers it and the license, standalone app, and DAW or project all pass. The structured records are in [tessera-disk-rescue-sample-library-ledger.jsonl](./tessera-disk-rescue-sample-library-ledger.jsonl). Tessera must never offer a whole-vendor-folder cleanup or treat package bytes as a verified working copy.

The newer local-AI lane adds 33 direct reports and 28 owner or implementation facts across MLX, MLX-LM, Hugging Face Datasets, Draw Things, DiffusionBee, and llama.cpp. It shows that user-created adapters, resume checkpoints, local datasets, projects, and outputs can be smaller but harder to recover than downloaded base models. It also shows fused models that lose trained behavior, conversions that look complete but fail to load, history records that leave output files behind, external roots that become unregistered, and prompt caches whose identity includes the selected adapter. The structured records are in [tessera-disk-rescue-mlx-local-ai-ledger.jsonl](./tessera-disk-rescue-mlx-local-ai-ledger.jsonl), with full notes in [tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md](./tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md). Protect user-created source state by default. A derivative cannot replace it until a real load and task test pass.

The game-library lane adds 71 core reports, 30 adjacent counterexamples, and 55 owner facts. Game folders mix redownloadable payloads with saves, worlds, screenshots, mods, cloud state, launcher registration, patch staging, and compatibility containers. The structured records are in [tessera-disk-rescue-game-library-ledger.jsonl](./tessera-disk-rescue-game-library-ledger.jsonl), with full notes in [tessera-disk-rescue-game-library-agent-lane-2026-08-31.md](./tessera-disk-rescue-game-library-agent-lane-2026-08-31.md). Use owner actions only until launcher identity, personal state, external-volume state, and a post-action launch plus save test are available.

The package-cache lane adds 104 core reports, 54 adjacent counterexamples, and 66 owner facts. Package storage is a dependency graph that can include shared stores, project materializations, environments, global tools, build output, offline sources, lockfiles, configuration, credentials, active locks, and partial transfers. The structured records are in [tessera-disk-rescue-package-cache-ledger.jsonl](./tessera-disk-rescue-package-cache-ledger.jsonl), with full notes in [tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md](./tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md). A path name or owner promise is insufficient without the current store role, references, recovery source, and exclusive reclaim estimate.

The app-profile lane adds 120 core reports, 5 adjacent counterexamples, and 58 owner facts. Browser, editor, and communication-app profiles place exact caches beside sessions, bookmarks, passwords, cookies, offline data, extensions, drafts, local history, and workspace databases. The structured records are in [tessera-disk-rescue-app-profile-ledger.jsonl](./tessera-disk-rescue-app-profile-ledger.jsonl), with full notes in [tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md](./tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md). Keep profile roots protected. Add only exact subpath rules with dependency, owner-action, and app-closed proof.

The GitHub follow-up adds 5,005 automated candidates across issue pages 1 through 10 in forty ledgers: [game page 1](./tessera-disk-rescue-game-followup-ledger.jsonl), [package page 1](./tessera-disk-rescue-package-followup-ledger.jsonl), [profile page 1](./tessera-disk-rescue-profile-followup-ledger.jsonl), [communication page 1](./tessera-disk-rescue-communication-followup-ledger.jsonl), plus the page-2 through page-10 ledgers listed above. The lane notes are [game](./tessera-disk-rescue-game-followup-2026-08-31.md), [package](./tessera-disk-rescue-package-followup-2026-08-31.md), [profile](./tessera-disk-rescue-profile-followup-2026-08-31.md), and [communication](./tessera-disk-rescue-communication-followup-2026-08-31.md). They are a source queue, not a manually coded sample. Do not add a feature or change a risk label from these records alone. Pages 5 through 10 used the local authenticated GitHub CLI without exposing its token. Continue with page 11 and later when the next loop needs more history.

The safety API lane adds 14 Apple records in [tessera-disk-rescue-safety-api-ledger.jsonl](./tessera-disk-rescue-safety-api-ledger.jsonl), with findings in [tessera-disk-rescue-safety-api-followup-2026-08-31.md](./tessera-disk-rescue-safety-api-followup-2026-08-31.md). The API evidence requires separate scan identity, volume identity, resource type, logical size, allocated size, owner inventory, open-handle state, file coordination, change-event invalidation, and named capacity source. FSEvents and file presenters are invalidation aids, not proof that a candidate is unchanged or safe.

The local communication probe is in [tessera-disk-rescue-communication-local-probe-2026-08-31.md](./tessera-disk-rescue-communication-local-probe-2026-08-31.md). It found Messages at about 9.9 GB, including about 8.1 GB of attachments and 1.4 GB of caches, and Discord at about 989 MB, including about 741 MB of cache. Messages, Discord, and WhatsApp were active. It is one read-only machine snapshot. It does not authorize a communication cleanup rule.

## Strong findings to preserve

1. A full disk is usually an urgent job. The user wants space for an update, install, export, or normal work.
2. The hard question is "can I delete this?" A large path is not a safety explanation.
3. System Data is a label and an accounting problem. Trash, snapshots, sparse files, cloud providers, open handles, and delayed accounting can make the number disagree with the user's action.
4. Ownership changes meaning. Xcode, Docker, sync providers, app containers, package stores, backups, and project folders need different rules.
5. A path can look disposable while holding the only local copy of important state.
6. A running process can make cleanup dangerous. Deleting an open database can trigger a larger disk emergency through hidden unlinked files.
7. Permissions are part of the result. A partial scan must say what it could not inspect.
8. Users want visible brakes: review, default-off risky groups, exact paths, allowlists, Trash, logs, and a second check when scope changes.
9. A failed or partial action needs its own explanation. One success total is not enough.
10. Users want prevention, but prevention means remembering the cause and showing it again. It does not mean silent scheduled deletion.
11. A storage number needs a name and a source. A user can see System Data rise after deleting data or can see Free and Available disagree; an unchanged chart is not enough to call the action a failure.
12. A successful local fix can be incomplete or temporary. Snapshot removal, cache cleanup, restart, or built-in Xcode cleanup may change one cause while leaving another or allowing recurrence.
13. Permission wording changes whether people will use the tool. Ask for the smallest useful scope, explain it before the system prompt, and recheck it after updates.
14. Users judge cleanup by proof. Per-item results, cancelable progress, measured change, and recovery details matter as much as the scan.
15. A remote copy does not make local bytes disposable. iCloud, Photos, Docker, and backup reports show that local materialization, pending sync, sparse disk images, and restore copies need an owner-aware decision.
16. Creator cache cleanup is a project decision. Resolve, Final Cut Pro, Lightroom, and Blender reports show that generated media can exceed source media, recur during active work, and live outside the obvious project path. Owner documentation confirms regeneration but also adds project scope, cache location, and external-media impact. Tessera needs a source-aware action, rebuild-cost warning, and retention guard.
17. Provider state is a contract, not a size label. Dropbox, OneDrive, Google Drive, and iCloud reports and guides distinguish local eviction, mirroring, streaming, cached bytes, and remote deletion. Tessera needs provider-specific state, completed-sync checks, and an action that states whether it changes only local materialization or the remote item.
18. Recovery objects have identity and lifecycle. Backups, snapshots, Docker images, and VM bundles can be current, obsolete, duplicated, active, sparse, or the only verified restore path. Tessera needs restore target, backup-copy status, owner state, guest state, logical and physical size, and source-aware recovery actions.
19. The displayed number is part of the failure. Users can move data and still see different values in Disk Utility, Storage Settings, or an update dialog. Tessera must name each measurement source and avoid calling a mismatch a successful reclaim.
20. The recovery path can be blocked by the full disk. Updates, backups, downloads, and bootable installers may all need temporary space, so a rescue plan needs escalation and a saved case when the immediate target cannot be reached safely.
21. Narrow control can be more valuable than broad automation. Some users leave cleaners because they cannot see the scope or do not want background activity, while newer tools earn interest by exposing allowlists, read-only analysis, dry runs, and Trash-first actions. Tessera should make exact review fast and inspectable.
22. Relocation is an owned transaction. A copied library, cache, or project is not safe to reclaim until the owner recognizes the new location, references resolve, the destination is available, and the user can complete the next task.
23. AI-model storage is a reference graph. Tessera must separate logical identity, physical allocation, shared references, loaded state, partial transfers, and operation-time working space before it states what one model can reclaim.
24. A professional library is a compound installed object. Package, content, plug-in, metadata, license, update, and host state need separate owner checks.
25. User-created AI state outranks downloaded weight by recovery value. Protect adapters, checkpoints, datasets, projects, and outputs until a verified derivative passes the user's real task.
26. Shared package storage is a dependency graph. Storage role, owner version, configured roots, reference topology, locks, offline recovery, and exclusive reclaim matter more than the folder name.
27. A game library splits payload from personal and compatibility state. Saves, mods, cloud state, launcher registration, and containers stay protected until an owner-level launch and save test passes.
28. An app profile is not a cache. Exact caches can be reviewable, while session, credential, offline, draft, history, and workspace state stay protected.
29. A scan is a time-bound claim. File identity, volume identity, owner inventory, capacity, FSEvents, coordination, and cloud state are separate signals. Tessera must invalidate stale results and revalidate at the last safe step.
30. Communication storage is compound owner state. Messages, attachments, caches, sync data, databases, drafts, sessions, and encryption state need separate roles and owner actions. A running app can change the result while it is under review.

## Current source risks

`Tessera/Engine/CleanupSuggestions.swift` currently marks every folder named `node_modules` as `safeRegenerable` and says that `npm install` restores it. The new package evidence does not support that path-only promise. Local or unpublished dependencies, offline use, workspace topology, active processes, and unique generated state can break the rebuild.

The same file treats several package-store and browser-cache path patterns as safely regenerable. Keep exact browser cache subpaths separate from the parent profile. Do not widen `Cache`, `Code Cache`, or `GPUCache` matches into session, site data, credentials, extensions, drafts, history, or workspace databases.

The communication probe does not justify a Messages, Mail, Discord, Telegram, Signal, WhatsApp, or Notes rule. Those roots mix large attachments or caches with live databases, sync state, drafts, sessions, and encryption or account state. Keep them protected until an owner adapter proves exact scope, current state, and a coordinated action.

Do not add raw game-library deletion rules. Launcher and runtime adapters must first separate payload, personal state, registration, cloud state, patch staging, compatibility containers, and missing external volumes. A missing volume is unavailable, not orphaned.

Representative issue reports:

- [Mole live-cache failure](https://github.com/tw93/Mole/issues/1390)
- [Mole hidden root-owned space](https://github.com/tw93/Mole/issues/1253)
- [Mole shared app data](https://github.com/tw93/Mole/issues/1437)
- [ClearDisk local session loss](https://github.com/bysiber/cleardisk/issues/27)
- [PureMac iCloud metadata failure](https://github.com/momenbasel/PureMac/issues/142)
- [mac-cleaner-cli permission failures](https://github.com/guhcostan/mac-cleaner-cli/issues/61)
- [Nextcloud File Provider transfer chunks](https://github.com/nextcloud/desktop/issues/10306)
- [Nextcloud sync data-loss report](https://github.com/nextcloud/desktop/issues/10521)

Platform references:

- [Apple storage categories and free space](https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac)
- [Apple Time Machine local snapshots](https://support.apple.com/en-us/102154)
- [Apple APFS snapshots](https://support.apple.com/en-mide/guide/disk-utility/dskuf82354dc/mac)
- [Apple privacy permissions](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/26/mac/26)
- [Apple Developer File Provider synchronization](https://developer.apple.com/documentation/FileProvider/synchronizing-the-file-provider-extension)
- [Apple Developer FileManager Trash operation](https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29?changes=_1)
- [Apple Developer coordinated file access](https://developer.apple.com/documentation/foundation/nsfilecoordinator)

## Proposed rescue flow

Keep the flow visible in the window. The names below are state names, not final UI copy.

1. `needs_rescue`
   - Show why the user is here: low available space or a user-selected Rescue entry.
   - Ask for the target volume if more than one volume is mounted.
   - Show a safe estimate only after measurement starts.

2. `scanning`
   - Scan off the main thread.
   - Show determinate progress where possible.
   - Publish coverage as it changes: complete, partial, or blocked.
   - Explain Full Disk Access and unreadable roots in the same place as the result.

3. `diagnosing`
   - Separate physical file usage from accounting-only causes.
   - Identify owner app, sync provider, process, lock, permission boundary, and rule source when known.
   - Keep snapshots, Trash, sparse files, and unlinked open files as distinct explanations.

4. `plan_ready`
   - Produce one ranked plan.
   - Show all meaningful candidates, grouped by risk and owner.
   - Preselect only safe, rebuildable, current, unclaimed items.

5. `reviewing`
   - Each row shows plain reason, exact path, owner, size, confidence, side effect, and next action.
   - Review-only items stay visible but cannot enter the safe default.
   - Provide Finder reveal and owner-app handoff where useful.

6. `staged`
   - The user can add or remove exact candidates.
   - The list says that nothing has moved yet.
   - A remembered preference can inform the list but cannot silently stage a changed path or changed risk.

7. `confirming_trash`
   - Use one clear confirmation for Move to Trash.
   - Show item count, requested size, risk mix, and the fact that Trash still occupies volume space until emptied.
   - Keep permanent deletion out of this dialog.

8. `moving`
   - Move items one by one or in small bounded batches.
   - Re-check the path and safety conditions at the last step.
   - Record success, failure, skip, and changed-path outcomes separately.

9. `verifying`
   - Re-measure available space and the selected paths.
   - Check for open handles and active writers when the result does not match the request.
   - Distinguish moved to Trash from physically reclaimed space.

10. `result`
    - Show requested, moved, failed, held, verified, and still in Trash as separate values.
    - Explain the next owner app or system setting for held items.
    - Offer a separate Empty Trash action only after Ammar confirms that boundary.

11. `remembering`
    - Offer to save a category or source preference only after the result is visible.
    - Store rule version, date, scope, and revalidation condition.
    - Never store or sync filenames, paths, scan trees, or personal content unless the user later chooses a different privacy rule.

## Candidate model

The implementation agent should deepen the current cleanup suggestion model instead of adding a second unrelated classification system.

Each recommendation needs enough data to explain and re-check itself:

```text
Recommendation
  id: stable rule-and-path identity
  path: exact current path
  displayName: human name
  scanIdentity: path, volume, resource, file, content, type, and scan-time metadata set
  volumeIdentity: volume identifier, device, mount, and current capacity source
  resourceIdentifier: resource identifier when available
  fileIdentifier: short-lived file identifier when available
  contentIdentifier: content identifier when available
  resourceType: file, directory, package, sparse image, snapshot, or unknown
  identityMatch: scan identity matches the current object, mismatched, or unknown
  owner: app, service, system, user, or unknown
  ownerApplicationState: stopped, active, synchronizing, reclaiming, or unknown
  backgroundOwnerState: no-known-helper, active-helper, unknown, or not-checked
  openHandleState: no-known-handle, open, unknown, or not-checked
  lockState: unlocked, owner-locked, process-open, transfer-active, or unknown
  coordinationCoverage: coordinated, not-coordinated, unsupported, or unknown
  changeEventState: unchanged, changed, coalesced-change, event-gap, or unknown
  requiresRescan: true or false
  category: cache, build output, log, installer, backup, sync data, and so on
  storageRole: download-package, installed-content, global-store, project-materialization, build-output, environment, global-tool, launcher-payload, save-state, mod-state, profile-cache, profile-session, site-data, workspace-state, application, plugin, owner-metadata, license-state, index, update-payload, user-created-data, or unknown
  project: project, library, event, timeline, or owner context when known
  generatedMediaClass: render, proxy, optimized, analysis, cache, or unknown
  cacheLocation: exact configured or inferred owner location when known
  configuredRoot: exact owner-configured store, library, profile, or external root when known
  referenceTopology: owners, projects, links, clones, or hardlinks that depend on the physical bytes
  exclusiveReclaimableBytes: allocated bytes proven to leave after the proposed owner action
  recoverySource: exact registry, package source, installer, remote revision, backup, or local source needed to restore the item
  offlineRequirement: required-offline, network-recoverable, local-source-required, or unknown
  provider: cloud or sync provider when known
  syncState: synced, pending, offline-only, online-only, materialized, or unknown
  actionScope: provider action scope and remote-delete semantics when known
  size: measured logical size
  physicalSize: measured physical size when available
  sparseState: sparse, expanded, unknown, or not-applicable
  localState: materialized, dataless, pending, local-only, or unknown
  sourceAction: owner-app action, evict, handoff, or none
  recoveryRole: source, backup, snapshot, archive, runtime, or unknown
  restoreTarget: device, volume, guest, project, or unknown
  backupCopyStatus: verified, unverified, missing, stale, or unknown
  lastVerifiedAt: latest local proof of restore or owner state when known
  ownerState: stopped, active, synchronizing, reclaiming, or unknown
  ownerRegistration: registered, missing, stale, unsupported, or unknown
  ownerActionEffect: exact owner action and the state or scope it changes
  communicationRole: attachment, cache, message-store, draft, export, session, credential, or unknown
  remoteAuthority: local-only, owner-server, shared-provider, or unknown
  retentionState: retained, expiring, owner-configured, pending-sync, or unknown
  activeWriter: process, owner helper, sync service, or unknown
  entitlementState: active, missing, expired, device-mismatch, support-required, or unknown
  validationState: unread, owner-visible, standalone-tested, host-tested, project-tested, or failed
  guestState: running, shut down, partition-mismatch, or unknown
  launcherRegistration: registered, missing, stale, external-volume-missing, or unknown
  compatibilityContainer: owner, path, runtime state, and dependency identity when present
  saveSyncState: local-only, synced, pending, conflict, disabled, unsupported, or unknown
  profileRole: cache, session, credential, cookie, site-data, offline-data, extension, draft, local-history, workspace-database, or unknown
  credentialDependency: paired keychain, encryption key, account, profile ID, or none when known
  sessionRecoveryState: clean, resumable, unsaved-work-present, failed, or unknown
  logicalArtifactID: owner model name or artifact identity when known
  revisionOrDigest: exact revision, digest, or checkpoint identity when known
  modelFormat: GGUF, safetensors, checkpoint, manifest, blob, or unknown
  quantization: exact quantization when known
  transferState: complete, active, resumable-partial, stale-partial-suspected, or unknown
  useState: loaded-now, installed-not-loaded, referenced-not-loaded, historical-or-trashed, or unknown
  referenceCount: known logical owners of the same physical artifact
  sharedPhysicalBytes: allocated bytes still referenced elsewhere
  independentlyReclaimableBytes: bytes the current owner action or reference graph can prove will leave
  operationWorkingSpace: temporary bytes needed for download, import, move, or rebuild when known
  recoveryIdentity: exact owner source, revision, authorization need, and companion files when known
  recoveryClass: user-created, derived-expensive, redownloadable-verified, redownloadable-unverified, runtime-active, partial-active, partial-stale, or unknown
  sourceDependencies: base, adapter, dataset, checkpoint, VAE, projector, shard set, prompt state, project, output, or other required nodes
  derivativeProof: untested, file-verified, load-tested, task-tested, failed, or not-applicable
  rescueGoal: update, install, export, build, normal-work, or unknown
  requiredSpace: target usable space for the current goal when known
  workingSpaceBuffer: extra temporary space expected for the current goal when known
  measurementSource: free, available, physical, logical, or owner-reported value and its source
  caseID: stable local rescue-case identity
  caseState: new, paused, stale, resumed, completed, or discarded
  caseSavedAt: local time the rescue case was last saved
  recoveryEscalation: none, owner-handoff, backup-needed, target-not-reached, or blocked
  retentionPolicy: owner time or size policy when known, otherwise none
  risk: safe, review, or protected
  confidence: high, medium, or low
  reason: short plain explanation
  evidence: rule ID, rule version, owner check, last-used signal, and path checks
  sideEffect: rebuild, re-download, sign-in, sync change, or unknown
  action: stage, handoff, inspect, or hold
  state: current, changed, moved, failed, held, or verified
```

Use `safe` only when Tessera can prove all of the following for the current scan:

- The rule recognizes the exact path. A name fragment is insufficient.
- The scan identity still matches the current path, volume, type, and resource. A missing or unstable identifier lowers confidence.
- The contents are rebuildable or disposable under the owner rule.
- No active owner process, lock, or open handle makes the action unsafe.
- No change event or incomplete coverage requires a rescan.
- The path is outside protected user data and backup-only state.
- A sync or cloud provider is not waiting on the path.
- The current permissions and scan coverage are sufficient.
- The expected side effect is shown in plain words.

Use `review` when the item may be useful to remove but Tessera cannot prove the full chain. Use `protected` when the path is user data, a backup or archive, a system root, an active owner state, or a path that a safety rule explicitly excludes.

For AI-model storage, add one owner-aware adapter lane for Ollama, Hugging Face Hub, LM Studio, ComfyUI, and AUTOMATIC1111. Generic file discovery is a fallback only. Each adapter must read live configuration and installed-version behavior, then return logical model identity, physical artifacts, reference edges, loaded state, partial-transfer state, configured roots, temporary roots, and supported owner actions. The row must show five byte values when available: logical model size, physical allocated bytes, shared bytes, independently reclaimable bytes, and operation-time working space. If the methods disagree, show the disagreement.

The first AI-model actions are `Open in owner`, `Verify`, `Resume download` when the owner recognizes it, `Remove with owner` with a preview, `Relocate` as a verified transaction, and `Keep`. Do not add raw blob deletion. Relocation is copy or link, verify, owner switch, restart with consent, model discovery, one real load, rollback capture, then a separate source-removal review.

Extend that adapter lane to MLX and MLX-LM, Draw Things, DiffusionBee, llama.cpp, and local Hugging Face Datasets state. Return user-created versus downloaded state, adapter and base dependencies, training and resume checkpoints, local dataset paths, processed dataset caches, fused or quantized derivatives, project and generated-output references, prompt or slot caches, external-root state, and semantic derivative proof. File existence, a successful save, or a successful API response does not prove that the derivative preserves the user's work. Keep source adapters, checkpoints, datasets, and projects protected until a load and representative task pass.

For professional sample libraries, add owner adapters before adding any package cleanup or relocation action. The first adapter set should cover Native Access and Kontakt, Spitfire App, Arturia Software Center, Toontrack Product Manager, Opus or EastWest Installation Center, UVI Portal or Falcon, IK Product Manager or SampleTank, and Steinberg Library Manager. Each adapter must identify package versus installed content, active owner roots, owner registration, license or device state, update target, helper processes, and supported repair, locate, forget, remove, or redownload actions. A relocation finishes only after the owner sees the new path, the standalone product loads, and the user's DAW or a representative project opens. Source removal remains a separate review.

For package storage, add owner adapters before changing the current `node_modules` or package-cache confidence. Cover npm, pnpm, Yarn, Cargo, CocoaPods, Conda, Gradle, Homebrew, SwiftPM, pip, and uv. Each adapter must return storage role, configured roots, owner version, project references, link or clone topology, active locks, offline recovery source, owner dry-run result, supported cleanup action, and exclusive reclaimable bytes. Lockfiles, configuration, credentials, installed environments, global tools, unpublished dependencies, and local source stay protected. An owner cleanup that bypasses Trash must state that boundary before execution.

For game libraries, start with read-only launcher adapters. Return launcher and game identity, payload paths, save and mod paths, cloud state, registration state, patch workspace, compatibility container, external-volume identity, and owner-supported move, uninstall, verify, or repair actions. A missing external volume is unavailable, not orphaned. Do not offer raw deletion. A relocation or removal finishes only after the launcher sees the new state and a representative game launch plus save test passes.

For browser, editor, and communication-app storage, keep profile roots protected. Add only exact subpath rules for proven caches. Return profile role, credential or encryption dependency, session recovery state, offline site data, extension state, drafts, local history, workspace databases, current process handles, and owner reset effect. The app must be closed or the owner action must safely coordinate the change. A generic browser-cache rule must never expand into profile cleanup.

For Messages, Mail, Discord, Telegram, Signal, WhatsApp, Notes, and Photos, begin with aggregate read-only inventory and owner handoff. Return `communicationRole`, attachment or media state, message-store state, draft state, export or backup identity, account and encryption pairing, `syncStatus`, `remoteAuthority`, `retentionState`, and `activeWriter`. A large attachment is not enough to offer a generic Trash move. The owner must define whether the action removes a local copy, changes retention, affects a remote item, or leaves the conversation database usable.

For every candidate and saved rescue case, add a last-step invalidation gate. Watch relevant directories where practical, mark `requiresRescan` after an FSEvent or owner change, refresh running application and helper state, re-read identity and capacity, then require a fresh review when any value changes. FSEvents, launch notifications, and file coordination are supporting signals only.

## Exact Tessera files to inspect

Start by tracing the existing flow. Keep each new rule in the smallest module that owns it.

| Area | Current file | Expected responsibility |
| --- | --- | --- |
| Classification | `Tessera/Engine/CleanupSuggestions.swift` | Add rule IDs, owners, risk reasons, and safe versus review output. Keep it pure where possible. |
| Scan coordination | `Tessera/ViewModel/ScanViewModel.swift` | Add rescue phases, coverage, ranking, staging, revalidation, and result accounting. |
| File removal | `Tessera/Engine/DeletionService.swift` | Keep Trash and permanent deletion separate. Add per-item outcomes and last-step checks. |
| Main rescue window | `Tessera/Views/ContentView.swift` | Compose the rescue entry, plan, confirmation, progress, and result states. |
| Suggestions | `Tessera/Views/CleanupSuggestionsView.swift` | Show ranked candidates, reasons, risk, owner, and proof. |
| Cleanup action bar | `Tessera/Views/CleanupActionBar.swift` | Make Rescue the first path. Keep specialist tools available as evidence sources. |
| Staging list | `Tessera/Views/CollectorDock.swift` | Make staged state and the Trash boundary clear. |
| Large and old | `Tessera/Views/LargeOldFilesView.swift` | Reuse candidate rows and explicit selection rules. |
| Search | `Tessera/Views/FileSearchView.swift` | Keep natural-language search from bypassing risk and owner checks. |
| App removal | `Tessera/Views/AppUninstallerView.swift` | Explain stage versus uninstall and shared app data. |
| Hidden space | `Tessera/Views/HiddenSpaceView.swift` | Show snapshots, permissions, and owner handoffs as separate cases. |
| Sources | `Tessera/Views/StorageSources.swift` | Show mounted volume identity and scan coverage. |
| App lifecycle | `Tessera/TesseraApp.swift` | Add menu or entry routing only after the rescue window is coherent. |
| Tests | `TesseraTests/EngineTests.swift` | Pure rules, sizes, risk, and candidate state. |
| Tests | `TesseraTests/ViewModelTests.swift` | Scan phases, staging, revalidation, deletion outcomes, and memory expiry. |
| Tests | `TesseraTests/LayoutTests.swift` | Window size, control visibility, and layout invariants. |

Read `DESIGN.md` before changing layout. It already records the current three-column constraints, keyboard focus work, chart limitations, Cleanup List wording, and the Full Disk Access onboarding model.

## Safety invariants

These are hard requirements for the implementation and review:

1. A scan never deletes or moves a file.
2. Safe defaults contain only high-confidence current candidates.
3. Exact-path checks run again immediately before a move.
4. Unknown ownership stays review-only or protected.
5. Active processes, locks, open handles, and sync activity can hold a candidate.
6. Trash movement and permanent deletion use different actions and confirmations.
7. Empty Trash never runs from a reminder or saved preference.
8. A saved preference never authorizes a deletion by itself.
9. Permission gaps appear in the result and lower confidence.
10. A failed item stays visible with its exact reason.
11. The result separates logical size, physical size, moved size, and verified free space.
12. Tests use temporary fixtures and never mutate the user's real files.
13. Scanning, filenames, paths, trees, and file content remain local. A future optional preference sync needs a separate, narrow payload review and never authorizes cloud processing of file data.
14. Large action batches have a bounded scope and a second confirmation when risk changes.
15. A remote-backed path never qualifies for generic Trash only because a remote copy exists. It needs current owner, sync, local-state, and recovery checks.
16. A creator cache never qualifies for safe staging only because its name contains cache, render, proxy, optimized, or analysis. Tessera must identify the owner, project scope, active writer, generated-media class, and owner-app cleanup semantics.
17. An online-only marker or remote copy never proves that local bytes are zero or that deletion is safe. Tessera must identify the provider, current sync state, logical and physical size, offline consequence, and remote-delete semantics before offering an action.
18. A backup, snapshot, disk image, or VM bundle never qualifies for generic Trash because it is old or large. Tessera must identify its restore target, owner state, guest state, backup-copy status, and source-aware reclaim semantics before offering any action.
19. A saved rescue case never authorizes a later move. It may preserve a local plan and evidence, but every path, rule version, permission, owner, and state must pass a fresh check before resumption.
20. A rescue target must include transaction overhead when known. Tessera must show the user's immediate goal, required usable space, working-space buffer, and whether the target was reached.
21. A measurement mismatch cannot be reported as reclaim proof. Tessera must name the measurement source and report target-not-reached or still-unexplained when the values do not support the claim.
22. A blocked recovery path must remain safe. Tessera must preserve the local case and explain the next owner, backup, or system step without escalating to raw deletion.
23. A failed transaction must not silently repeat. Tessera must preserve the last measurement, exact scope, owner or permission blocker, and user-visible error, then require a fresh decision before retrying or changing the batch.
24. A compound working-set candidate must show source or project identity, generated-media class, owner state, and temporary-space effect. An external project location never proves that internal working space is safe to reclaim.
25. Owner-managed generated media, virtual disks, and recovery history must use a source-aware action or handoff. Tessera must not stage a raw path because its name or logical size looks disposable.
26. A relocation never makes the source reviewable from copy completion alone. Tessera must verify destination identity, owner-recognized active location, required references, available working space, and one owner-level open or use check.
27. AI-model blobs, manifests, revisions, links, locks, partial transfers, and metadata never qualify for raw safe staging. Tessera must use live owner inventory or a read-only fallback graph, show loaded and referenced state, and compute independently reclaimable allocated bytes.
28. A scan never unloads a model, stops a model server, resumes a transfer, changes a model root, or edits `HF_HOME` as a side effect. Credentials, exact user fine-tunes, generated output, and unknown model revisions remain protected.
29. `node_modules` and package stores never qualify as safe from a path name alone. Tessera must prove the storage role, recreation source, owner state, reference topology, and exclusive reclaim for the current item.
30. A package owner cleanup that bypasses Trash must state that effect before execution. Lockfiles, credentials, configuration, environments, global tools, and local or unpublished dependencies remain protected.
31. Game payloads never absorb saves, worlds, mods, screenshots, launcher registration, cloud conflicts, or compatibility containers into one action. A missing external volume is unavailable, not orphaned.
32. Browser, editor, and communication-app profile roots remain protected. Only exact cache subpaths with dependency and app-closed proof can enter review.
33. A candidate whose path, volume, type, resource, file, content, owner, or capacity identity changed since the scan must be held and rescanned. A matching path alone is not identity proof.
34. FSEvents, launch notifications, file presenters, and running-application inventory cannot prove that no helper or low-level writer is active. Use them as invalidation and owner signals, then check handles and owner state.
35. Messages, Mail, Discord, Telegram, Signal, WhatsApp, Notes, and Photos roots never enter generic safe staging. Attachments, caches, databases, drafts, sessions, encryption state, and sync state require an owner-defined scope and action.

## Required tests

Add or update tests before claiming the feature works.

### Classification

- A known DerivedData or package cache is safe only when the exact rule matches.
- An app container with unknown ownership is review-only.
- A backup, archive, source file, project store, or protected root is not safe by size alone.
- A path with a shared bundle ID remains protected when another installed app owns the same data.
- A symlink or hard link cannot widen the deletion scope.
- Sparse files report logical and physical size separately.
- A sound, sample, asset, model, or project library remains protected after a raw filesystem copy until its owner reports the destination as active.
- Shared model blobs, hard links, symbolic links, APFS clones, and full copies produce different independently reclaimable byte values.
- A partial model transfer absent from the owner's installed list remains visible as resumable, stale-suspected, active, or unknown, never as an automatic orphan.
- A folder named `node_modules` is not safe without a verified recreation source, owner state, and proof that it holds no unique local state.
- Shared package stores, project materializations, hardlinks, APFS clones, and full copies produce different exclusive reclaim values.
- Package lockfiles, configuration, credentials, environments, global tools, local source, and unpublished dependencies remain protected.
- A game install keeps payload, saves, worlds, mods, screenshots, launcher metadata, cloud state, and compatibility containers as separate roles.
- A browser or IDE profile root remains protected even when it contains child folders named Cache, Code Cache, or GPUCache.
- A candidate whose path is replaced, remounted, renamed, or changes type between scan and action is held by the identity gate.
- A coalesced file event invalidates the affected saved case and causes a narrow rescan before review or action.
- A background or `LSUIElement` owner that is not visible in the main window still holds its candidate when process or handle checks show activity.
- A file presenter or coordinator that receives no event does not override a low-level writer or open-handle hold.
- A Messages or Discord root keeps attachments, caches, databases, sync state, sessions, and drafts as separate roles; no parent-root rule enters safe staging.

### State and permissions

- A root-owned path is reported as unreadable instead of absent.
- Full Disk Access changes coverage after a new scan, not in the middle of a stale result.
- A running process or open handle holds the candidate.
- A lock or owner command that cannot prove safe pruning fails closed.
- A missing, renamed, slow, or read-only external destination blocks relocation cleanup and preserves the source.
- A relocation plan budgets download, unpack, validation, and final bytes on the volumes that each phase uses.
- Loaded-model inventory is refreshed immediately before an owner remove or relocation action.
- A missing model store returns no material candidates instead of manufacturing a generic cache recommendation.
- A sync provider with pending work becomes review-only and gets an owner handoff.
- A remote-backed item with a materialized local copy shows its owner and local state instead of entering generic safe staging.
- A dataless or pending File Provider item cannot be moved to Trash by a generic rule.
- A sparse Docker disk image reports logical and physical size separately and offers Docker as the owner handoff.
- A Final Cut Pro, Resolve, Premiere, or Lightroom generated-media path shows its project or library scope, cache location, owner action, and rebuild cost.
- An active render, proxy build, analysis pass, or background task holds its generated media until the owner state is stopped or clearly safe.
- A creator cache that recurs after cleanup shows the cause and an opt-in retention or size guard instead of silently deleting it.
- Dropbox online-only and OneDrive online-only items use a provider eviction action, show the local result, and remain protected from generic delete.
- Google Drive streaming and mirroring report different local ownership and require completed sync before a mode change or mirrored-folder removal.
- iCloud Drive offers Remove Download as a local-relief action and keeps it distinct from deleting the iCloud item.
- Logical provider size and physical local size can differ without claiming that the full logical value is reclaimable.
- Pending sync, unsynced edits, offline-needed state, or an unknown provider state holds the item and offers an owner handoff.
- A device backup shows its device or restore target, backup age, and verified-copy status before any review action.
- A Time Machine destination separates local snapshots, destination history, old device identities, and the source volume that may also need staging space.
- Docker.raw remains owner-managed; containers, images, build cache, and volumes use separate prune or backup scopes, and changing the image limit warns about data loss.
- A Parallels or UTM bundle shows snapshot, shutdown, backup, guest, and reclaim preconditions. An interrupted or experimental reclaim is never reported as verified without a new measurement.
- A host image size and guest volume size can disagree. Tessera reports both and does not claim that host expansion or compression changed guest capacity.
- An update, install, export, or build goal stores its required usable space and working-space buffer separately from candidate reclaim size.
- A paused or stale rescue case can reopen with its plan and explanations, but changed paths, permissions, owners, or rule versions become held or review-only.
- Xcode DerivedData, simulator data, runtimes, archives, and device support remain separate candidates with owner and rebuild-cost evidence.
- Docker logical size and physical size remain separate, and Docker.raw never enters generic Trash staging.
- Final Cut Pro, After Effects, Lightroom, or Unity work shows source or project identity, generated-media class, active state, internal or external cache location, and owner action.
- An external project or media volume that still needs internal package, render, analysis, or temporary space is not reported as fully relocated.
- Time Machine history and device backups show source or restore identity, verified-copy status, destination state, and the owner-managed action before any reclaim review.
- An active package-manager lock, install, build, environment, or transfer holds the affected store and project materialization.
- An offline rebuild or missing local package source holds the candidate even when the package manager calls another layer a cache.
- A missing external game volume preserves launcher registration and library identity instead of creating an orphan candidate.
- A game-library relocation passes owner registration, one real launch, and one representative save test before old bytes become reviewable.
- An open browser, IDE, or communication app holds profile changes unless the owner action can coordinate them safely.
- Password and encryption pairings, session restore, drafts, offline site data, local history, and workspace databases remain dependency groups, not cache candidates.

### Execution and verification

- Move to Trash records one outcome per item.
- A changed or missing path is skipped and stays in the result.
- A permission failure remains visible and is not counted as moved.
- A partial batch does not report the requested size as reclaimed.
- A successful Trash move is distinct from verified volume free space.
- A result with no immediate free-space change explains Trash, snapshots, open handles, sparse accounting, or delayed measurement when evidence supports it.
- Owner-app cleanup records the requested scope and distinguishes a source-aware purge from a generic filesystem move.
- Package-manager cleanup records its owner version, dry-run or preview, exact scope, Trash behavior, and measured exclusive reclaim.
- Game launcher removal or relocation records payload and personal-state outcomes separately and verifies launcher visibility plus launch and save state.
- App-profile cleanup records exact subpaths and proves that session, credential, offline, draft, history, and workspace state did not change.
- Permanent deletion requires its own explicit action and never hides behind Move to Trash.
- A rescue case saves and restores locally without uploading filenames, paths, trees, or personal content.
- Resuming a case re-runs scan coverage and last-step checks; a stale result cannot silently stage an item.
- Report whether required usable space was reached. Candidate bytes are not the target.
- Disk Utility, Storage Settings, and owner-reported space values remain labeled by source when they disagree.
- A missed target enters a named recovery escalation state, saves the case locally, and offers the correct owner or backup handoff.
- A failed move, backup, update, copy, or owner action pauses the case, records the exact blocker, and does not silently retry or widen the staged scope.
- A failed case can resume with its evidence and measurements, but a changed owner, permission, sync state, or target requires a fresh review.
- A repeated read of a live communication root can change allocation without changing the product's role model; the result names the measurement time and owner state.

### Memory and recurrence

- A saved category choice is re-checked against the new path, rule version, owner, and risk.
- A changed rule or expired preference becomes review-only.
- A reminder never stages or moves an item.
- Reset removes saved preference data without touching files.
- No filename, path, tree, or scan history leaves the Mac under the local-only rule.

### User-facing path

Run the actual macOS window after unit tests. Verify:

- Rescue is easy to find from the empty and low-space states.
- The scan has a visible phase and a truthful coverage state.
- A candidate row explains why it is present before the user opens a detail view.
- Safe and review items are visually distinct.
- Move to Trash is the clear primary action.
- Empty Trash and permanent deletion are visibly separate.
- Failed and held items remain understandable after the batch ends.
- Keyboard focus, VoiceOver labels, and menu commands still work.
- The window works at the existing minimum width and at a smaller supported width.

## Research gate after each feature slice

Before expanding a feature, run the living loop again:

1. Name the user decision in plain words.
2. Search first-person reports, official system documentation, issue trackers, reviews, and the local Tessera path.
3. De-duplicate URLs and authors where possible.
4. Add counterexamples and keep source quality visible.
5. Update the pattern map and this handoff.
6. Ask Ammar the next frontier questions.
7. Build in an isolated Tessera space only after the boundary is shared.
8. Test the real macOS path.
9. Record what the feature changed and what new evidence it created.

Do not use a source count as the stopping rule. Pause a product question only when its current decision has coverage across contexts, source families, and counterexamples. Reopen it when a new macOS release, owner app, safety incident, or user segment changes the evidence.

## Handoff exit criteria

This document becomes implementation-ready only when:

- Ammar has answered open Round 7 about backup and virtual-disk owner action, recovery proof, and host plus guest state.
- Ammar has answered open Round 10 about pause behavior, blocker explanation, and background work after a failed transaction.
- The remaining owner-boundary question has been rewritten after those answers. It must not repeat the settled goal, active-state, cloud, or recovery choices.
- The current TempliLink page shows settled rounds as read-only summaries and only the open decision frontier as forms.
- The exact choices and exceptions are recorded above.
- The implementation agent has mapped each changed behavior to a Tessera file and test.
- The next research pass covers any new decision that the feature introduces.
- The real window passes the user-facing checks above.

Until then, this is a research handoff, not permission to modify source code or user data.
