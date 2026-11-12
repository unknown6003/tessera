# Rescue Standards review

Outcome: independent Standards pass at the fixed commits below. Proof: local diff, source and record inspection. Constraints: no children, source edits, commits, checkout changes, network, builds or tests. Only this report is written.

## Findings

No documented-standard breach retained. Two non-blocking judgement calls from the supplied smell baseline remain. Tooling-enforced issues are excluded.

1. **Possible Duplicated Code, P2.** `Tessera/Engine/TrashOperation.swift:430` and `Tessera/Engine/VerifiedTrashRemoval.swift:336` separately map the same Darwin metadata into `TrashFileState`: `device: UInt32(bitPattern: …st_dev), inode: UInt64(…st_ino)`, followed by mode, ownership, links, size, blocks, flags and all timestamps. Adding or correcting a captured field requires matching edits in the capture and removal paths. Put this conversion on `TrashFileState`, taking the volume identifier and root explicitly. Keep live volume discovery and descriptor verification with their present owners. This is an upkeep concern, not a demonstrated comparison failure.

2. **Possible Duplicated Code / Repeated Switches, P3.** `Tessera/Views/CleanupSuggestionsView.swift:221` and `Tessera/Views/RescueReviewView.swift:101` both switch on `workspace.handoff`. Both render waiting/deferred text, `Button("Don't check")`, failure text and `Button("Retry")`, including the same task and busy guard. Future handoff-state or retry changes require two matching UI edits. Share one small handoff-status view, with text size or wording supplied by the caller. Keep the two placements.

## Scope and limits

Read project AGENTS.md, shared engineering-rules, engineering-workflow, model-guide, code-review and unslop. Checked DESIGN.md, project.yml, Xcode source configuration, README/CI guidance and web formatter/linter scope. No nested instruction files were found. The web configs do not govern Swift.

All 49 changed paths are accounted for below. Research and prior review notes were inspected as records; external claims were not reverified. They are not new participant studies. Prototype HTML is synthetic. WebPs were checked only by type, hash and round-2.json media declarations. Both are 1100×700 WebP images, matching that manifest. No native proof follows.

Known runtime state: 1f44e66 compiled but Trash tests failed. The current descriptor helper awaits native proof. This pass supplies no runtime, release, performance or usability score.

Standards: 0 documented breaches; 2 smell judgements. The metadata conversion duplication has the greater upkeep cost.

## Pin and capture

Base: `65e272109ad906810ff3b8a3d01d217cd1fb1934`. Target and clean HEAD at pin: `b83612546f4d9bd35c227267c9539ce2338e7079`. Merge base equals the fixed base. No untracked files at pin.

Captured `git diff 65e272109ad906810ff3b8a3d01d217cd1fb1934..b83612546f4d9bd35c227267c9539ce2338e7079`: 652,690 bytes; SHA-256 `18fe9b30b695e99ca5bd966fa2bd36cbf2cf7699fc00fd74c4d0fec12de6e0d2`.

Commit log, `git log --oneline base..target`:

```text
b836125 Keep Rescue context across owner checks and handle review gaps
b2a8d19 Acquire tracked Trash entries before verified permanent removal
1f44e66 Fix nested Rescue selection closure and isolate Trash test adapters
b1b8a12 Recheck Trash fallback authority and report held cleanup outcomes
b9e2baa Build ranked Rescue reviews and track cleanup Trash operations
33a06f8 Record the agreed Rescue redesign and research evidence
```

## Changed-path accounting

All source/test paths received a Standards source pass. Markdown/JSON paths received record and instruction-scope inspection. HTML paths received synthetic-source inspection. WebPs received metadata-only inspection. No path was omitted.

```text
Tessera/Engine/CleanupSuggestions.swift
Tessera/Engine/DeletionService.swift
Tessera/Engine/TrashOperation.swift
Tessera/Engine/VerifiedTrashRemoval.swift
Tessera/ViewModel/ScanViewModel.swift
Tessera/Views/CleanupSuggestionsView.swift
Tessera/Views/CollectorDock.swift
Tessera/Views/ContentView.swift
Tessera/Views/RescueReviewView.swift
Tessera/Views/RescueWorkspaceModel.swift
Tessera/Views/TrashFinishReviewView.swift
TesseraTests/EngineTests.swift
TesseraTests/RescueWorkspaceTests.swift
TesseraTests/TrashOperationTests.swift
TesseraTests/VerifiedTrashRemovalTests.swift
docs/research/rescue-2026-11-11/STATUS.md
docs/research/rescue-2026-11-11/analytics-evidence.md
docs/research/rescue-2026-11-11/coverage-and-hogs.md
docs/research/rescue-2026-11-11/design-confirmation-response.json
docs/research/rescue-2026-11-11/design-confirmation.json
docs/research/rescue-2026-11-11/design-spec.md
docs/research/rescue-2026-11-11/design-tree.md
docs/research/rescue-2026-11-11/implementation-contract.md
docs/research/rescue-2026-11-11/prototype/layout-A.webp
docs/research/rescue-2026-11-11/prototype/layout-B.webp
docs/research/rescue-2026-11-11/prototype/rescue-flow-prototype.html
docs/research/rescue-2026-11-11/prototype/rescue-layout-prototype.html
docs/research/rescue-2026-11-11/reference-verification.md
docs/research/rescue-2026-11-11/research-code-audit.md
docs/research/rescue-2026-11-11/research-mac-cleaners.md
docs/research/rescue-2026-11-11/research-other-platforms.md
docs/research/rescue-2026-11-11/research-studies.md
docs/research/rescue-2026-11-11/research-summary.md
docs/research/rescue-2026-11-11/research-user-voice.md
docs/research/rescue-2026-11-11/round-1-response.json
docs/research/rescue-2026-11-11/round-1.json
docs/research/rescue-2026-11-11/round-2-response.json
docs/research/rescue-2026-11-11/round-2.json
docs/research/rescue-2026-11-11/round-3-response.json
docs/research/rescue-2026-11-11/round-3.json
docs/update/rescue-discovery.md
docs/update/rescue-redesign-ui.md
docs/update/rescue-review-triage.md
docs/update/rescue-risk-round2.md
docs/update/rescue-spec-review.md
docs/update/rescue-trash-integration.md
docs/update/rescue-trash-operation.md
docs/update/rescue-trash-risk-review.md
docs/update/verified-trash-removal.md
```

## WebP hashes

```text
003329c7f6c30bb484d0731a350ac0700c85f29b2bd6440c0ad2799420516bfa  docs/research/rescue-2026-11-11/prototype/layout-A.webp
b3b55450b139a47e9331c0ec254bbf38540f509a9d1ce30a7acd73632ac83dd3  docs/research/rescue-2026-11-11/prototype/layout-B.webp
```
