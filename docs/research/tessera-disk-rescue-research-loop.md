# Tessera disk-rescue research loop

Status: active. This document defines how research continues while Tessera is designed and built.

Owner: the Tessera product and implementation agents, with Ammar as the decision maker.

Last updated: 2026-08-31

## Purpose

Tessera is solving a trust problem around a full Mac disk. Research must stay open while the product changes. A source count is a progress measure, not a completion condition.

The loop must keep answering four questions:

1. What job is the user trying to finish?
2. What makes the storage cause understandable?
3. What makes an action safe enough to approve?
4. How does Tessera prove the result and prevent the same problem from becoming a surprise?

## Current corpus

The first structured pull contains 1,618 unique Ask Different question URLs from 1,860 raw records. It used 26 bounded API pulls across storage, disk space, System Data, caches, Trash, snapshots, iCloud, backups, Xcode, Docker, and related macOS tags.

- 840 records are screened as core to the storage-rescue question using title-level storage and cleanup signals.
- 778 records are kept as adjacent context because tags alone are not proof of direct relevance.
- 1,377 records have at least one answer.
- 1,340 records are marked answered by the API.

The ledger is [tessera-disk-rescue-source-ledger.jsonl](./tessera-disk-rescue-source-ledger.jsonl). The study and its pattern map are in [tessera-disk-rescue-ethnographic-study.md](./tessera-disk-rescue-ethnographic-study.md).

A content sample now covers 278 unique question bodies from 268 authors. It combines high-score, recent, and unanswered records. The sample index is [tessera-disk-rescue-askdifferent-content-sample.jsonl](./tessera-disk-rescue-askdifferent-content-sample.jsonl). Keyword counts from that sample are recorded in [tessera-disk-rescue-research-manifest.json](./tessera-disk-rescue-research-manifest.json). They are prompts for deeper reading, not prevalence estimates.

The second structured pull and its follow-up add 403 unique GitHub issue or discussion URLs from 16 repositories. It contains 274 product issue reports, 63 sync-storage-adjacent reports, and 66 maintainer-generated signals. A 103-record body sample covers the original 15 repositories. The issue ledger is [tessera-disk-rescue-github-issue-ledger.jsonl](./tessera-disk-rescue-github-issue-ledger.jsonl). A separate 77-record repository discovery scan is kept as market signal in [tessera-disk-rescue-market-scan.jsonl](./tessera-disk-rescue-market-scan.jsonl).

The community comparison pass now contains 102 de-duplicated direct pages: 66 Apple Support Community pages and 36 MacRumors pages. The ledger is [tessera-disk-rescue-community-source-ledger.jsonl](./tessera-disk-rescue-community-source-ledger.jsonl). Eighty-one are core first-person reports, nineteen are adjacent context, and two are unverified because they mix broad peer advice or a neighboring platform.

The product-experience pass now contains 147 de-duplicated direct pages: 136 Reddit pages, 8 App Store review pages, and 3 App Store product pages. The ledger is [tessera-disk-rescue-product-experience-ledger.jsonl](./tessera-disk-rescue-product-experience-ledger.jsonl). One hundred and thirty-six are direct Reddit user reports and 11 are market signals. The creator-cache lane covers DaVinci Resolve, Final Cut Pro, Lightroom, Blender, and After Effects. The cloud-provider lane covers Dropbox and iCloud or Photos reports. The backup and virtual-disk lane covers device backups, Time Machine, Docker, Parallels, UTM, and VMware. The cleanup-trust lane adds emergency entry, result proof, scan continuity, and temporary working-space reports. The rescue-continuity lane adds conflicting measurements, update and backup working-space pressure, recovery escalation, exact-control preferences, and clearer maker boundaries. The rescue-failure-retry lane adds cases where the first cleanup or recovery attempt changes the state, fails to release space, or blocks the next safe transaction. The developer-creator-state lane adds Xcode, Docker, Unity, After Effects, Lightroom, Final Cut Pro, and Time Machine reports where project state, generated media, owner-managed disk images, and recovery identity change the safe action.

The current corpus contains 3,005 non-automated user and issue evidence records, 5,005 automated GitHub candidates, 30 first-party Apple system facts, 426 owner or implementation facts, and 88 market signals. The 57 evidence and authority ledger inputs contain 8,477 records before the separate 77-record market scan. All 58 corpus inputs contain 8,554 unique URLs with no exact or normalized duplicates. The 5,005 GitHub follow-up records are a discovery queue, not manually coded behavior evidence. The 2,000-source research gate is a checkpoint, not a stopping point. The next work is to manually code the candidate queue, paginate older history where a decision needs it, collect owner documentation and direct reports for communication apps, and keep splitting findings by trigger, owner, risk, permission boundary, recurrence, continuity, transaction budget, measurement source, recovery path, relocation state, reference graph, storage role, recovery class, and post-failure state.

This corpus is a large baseline from one main community plus smaller owner-context lanes. It is not one interview per record. The screening rule is deliberately conservative: tags provide context, but title-level storage and cleanup signals determine the core label. Continue adding Reddit, Apple Support Communities, MacRumors, App Store reviews, GitHub issues and discussions, developer forums, creator communities, and official Apple and owner-app documentation. Keep system and owner facts separate from observed behavior.

The rescue-continuity pass adds 15 directly inspected pages. Five Apple Support Community reports describe update, snapshot, backup, and recovery pressure. Five Reddit reports describe measurement mismatch, creator or media cleanup, manual exact-path work, orphaned app data, and a high-engagement System Data emergency. Five Reddit maker discussions are kept as market signals because they show proposed controls such as allowlists, read-only analysis, dry runs, risk labels, and Trash-first cleanup. This pass strengthens patterns about measurement source, transaction budgets, recovery escalation, and narrow control without adding a new pattern only to increase the count.

The rescue-failure-retry pass adds 21 directly inspected pages: eleven MacRumors pages and ten Reddit pages. The pages cover deletion that does not release measured space, backup or update operations that require internal working room, permission scope that users do not understand, cloud or Photos state that survives a restart, and escalation from cleanup into a factory reset or reinstall. The lane is deliberately mixed: direct reports are core or adjacent evidence, while conflicting peer advice stays visible as uncertainty. The next feature decisions should test whether Tessera preserves the failed case, names the exact blocker, and offers one safe next step without widening the delete scope.

The developer-creator-state pass adds 44 directly inspected pages: ten Apple Support Community or MacRumors pages and 34 Reddit reports. The reports cover Xcode, Docker, Unity, After Effects, Lightroom, Final Cut Pro, and Time Machine. They show that a rescue is often a compound transaction: source or project state, generated output, owner cache, virtual-disk or backup state, and temporary working room all compete for the same disk. The lane strengthens the rule that Tessera must use owner actions, distinguish logical from physical size, hold active work, show source or restore identity, and ask for the user's immediate goal before ranking candidates. The next feature decisions should test whether a user can understand that boundary without opening a second app.

The independent developer-creator agent lane adds 47 new URLs and is kept in [tessera-disk-rescue-developer-creator-ledger.jsonl](./tessera-disk-rescue-developer-creator-ledger.jsonl), with its field notes in [tessera-disk-rescue-agent-lane-2026-08-31.md](./tessera-disk-rescue-agent-lane-2026-08-31.md). It contains 41 first-person reports and 6 first-party Unity or Android guides. This lane adds workflow-phase, temporary-volume, live-writer, relocation, compaction, source-versus-project, and recovery-identity evidence. It is a separate authority and behavior lane, not an expansion of the Reddit or App Store counts.

The creator-working-set lane adds 54 new URLs in [tessera-disk-rescue-creator-workspace-ledger.jsonl](./tessera-disk-rescue-creator-workspace-ledger.jsonl): 36 user reports and 18 owner facts across Logic Pro, Ableton Live, Unreal Engine, Blender, and Autodesk Fusion. It adds owner-recognized library location, missing-volume behavior, partial downloads, project consolidation, derived-cache layers, simulation bakes, offline CAD state, external-volume performance, and per-volume transaction budgets. The key counterexample is that moving a library can leave the system drive under pressure or create a broken owner reference, so final location alone does not prove a safe reclaim.

The AI-model-storage lane adds 54 new URLs in [tessera-disk-rescue-ai-model-storage-ledger.jsonl](./tessera-disk-rescue-ai-model-storage-ledger.jsonl), with field notes in [tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md](./tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md). It contains 25 first-person reports and 29 owner facts across Ollama, Hugging Face, LM Studio, ComfyUI, and AUTOMATIC1111. It adds shared-blob and revision graphs, link identity, installed versus loaded versus referenced state, partial-transfer inventory gaps, per-volume staging, hot versus cold availability, and exact revision or quantization recovery. The local read-only probe found no large active store at the common paths, which is an important no-candidate counterexample.

The professional sample-library lane adds 79 new URLs in [tessera-disk-rescue-sample-library-ledger.jsonl](./tessera-disk-rescue-sample-library-ledger.jsonl). It contains 31 core reports, 4 adjacent counterexamples, and 44 owner facts across eight vendor families. It adds download-versus-install state, owner registration, license and device identity, update roots, multi-root libraries, active installer helpers, and standalone-versus-host validation. The main counterexample is a byte-complete copy that the owner or DAW cannot use. The old copy stays protected until registration, license, standalone, and host or project checks pass.

The newer local-AI lane adds 61 new URLs in [tessera-disk-rescue-mlx-local-ai-ledger.jsonl](./tessera-disk-rescue-mlx-local-ai-ledger.jsonl), with field notes in [tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md](./tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md). It contains 33 first-person reports and 28 owner or implementation facts across MLX, MLX-LM, Hugging Face Datasets, Draw Things, DiffusionBee, and llama.cpp. It adds user-created adapters, resume checkpoints, local datasets, projects, generated outputs, failed fused derivatives, processed caches, external roots, active transfers, and runtime state. The main counterexample is a large derivative that exists and loads poorly or loses the trained behavior while the much smaller adapter remains the only valid source.

The game-library lane adds 156 new URLs in [tessera-disk-rescue-game-library-ledger.jsonl](./tessera-disk-rescue-game-library-ledger.jsonl), with field notes in [tessera-disk-rescue-game-library-agent-lane-2026-08-31.md](./tessera-disk-rescue-game-library-agent-lane-2026-08-31.md). It contains 71 core reports, 30 adjacent counterexamples, and 55 owner facts across eleven launcher or runtime families. It separates payloads from saves, worlds, mods, screenshots, cloud state, launcher registration, patch staging, compatibility containers, and external-volume identity.

The package-cache lane adds 224 new URLs in [tessera-disk-rescue-package-cache-ledger.jsonl](./tessera-disk-rescue-package-cache-ledger.jsonl), with field notes in [tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md](./tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md). It contains 104 core reports, 54 adjacent counterexamples, and 66 owner facts across eleven package-manager families. It separates shared stores, project materializations, environments, global tools, build output, offline sources, lockfiles, configuration, credentials, active locks, and partial transfers.

The app-profile lane adds 183 new URLs in [tessera-disk-rescue-app-profile-ledger.jsonl](./tessera-disk-rescue-app-profile-ledger.jsonl), with field notes in [tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md](./tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md). It contains 120 core reports, 5 adjacent counterexamples, and 58 owner facts across nine browser, editor, and communication-app families. It separates exact caches from sessions, bookmarks, passwords, cookies, offline data, extensions, drafts, local history, and workspace databases.

The GitHub follow-up now covers issue pages 1 through 10 and adds 5,005 automated candidates across game, package, app-profile, and communication repositories: 1,869, 1,059, 1,187, and 890 records. Pages 2 through 10 add 443, 465, 469, 497, 456, 553, 520, 543, and 648 records. The reusable collector is [collect-tessera-github-followup.sh](./collect-tessera-github-followup.sh). The forty ledgers are grouped by page in the manifest. Every record is marked `automated_candidate`; the next loop must manually code the records, inspect false positives, and request older pages when recency bias could change a decision. Pages 5 through 10 used the local authenticated GitHub CLI without exposing its token. Page 11 and later remain open while the authenticated quota permits.

The safety-API lane adds 14 first-party Apple records in [tessera-disk-rescue-safety-api-ledger.jsonl](./tessera-disk-rescue-safety-api-ledger.jsonl), with notes in [the follow-up](./tessera-disk-rescue-safety-api-followup-2026-08-31.md). It separates file and volume identity, logical and allocated size, owner inventory, coordinated writes, change events, and cloud state. The local communication probe adds one read-only machine snapshot in [the probe report](./tessera-disk-rescue-communication-local-probe-2026-08-31.md). It measured aggregate allocation for Messages, Discord, Mail, and Notes roots while communication owners were active. It read no content and changed no files. These lanes refine safety and owner-state boundaries; they do not establish user prevalence.

## Loop for every product question

### 1. Name the decision

Write the decision as a user behavior, not a feature label. Good examples:

- Should a low-space alert open Rescue or the explorer?
- What may Tessera remember after a successful cleanup?
- What evidence should appear before Move to Trash?
- How should Tessera handle an item that an app is using?

### 2. Collect broadly

Search several source families. Do not stop at a round number such as 100, 200, or 1,000. Continue until the decision has coverage across contexts and new searches stop adding new causes, fears, or workarounds. Then keep the corpus open for counterexamples.

Use these source lanes:

- First-person support questions and replies.
- App Store reviews and version notes.
- Apple and third-party product documentation.
- Official Apple Support and Apple Developer documentation for platform facts. Do not combine these records with user prevalence.
- GitHub issues, discussions, and changelogs for storage tools and apps that create large data.
- Developer, creator, backup, and cloud-sync communities.
- Direct local evidence from Tessera and a real Mac.

Search with different words. Users may say disk full, storage almost full, System Data, Other, hidden space, cache, snapshots, backups, app leftovers, Docker disk, Xcode storage, or no space after deleting.

### 3. Triage and de-duplicate

Keep the URL once. Store the source type, title, date, score or review signal, tags, and the exact question or behavior it supports.

Classify evidence:

- Core: first-person storage problem, direct user behavior, official system rule, or direct issue report.
- Adjacent: a related Mac workflow that may change the design.
- Market signal: product launch, product marketing, or builder description. Useful for seeing proposed solutions, weak for proving user demand.
- Maintainer signal: an automated upstream watch, compatibility digest, or project-maintainer report. Useful for product risk and change tracking, weak for proving independent user demand.
- Unverified: commands, claims, or advice without enough evidence. Keep it for follow-up, not as a safety rule.

Do not treat many posts from one author as many users. Do not use search-result count as prevalence. Do not promote a repeated bad command into a product rule just because it appears often.

### 4. Extract observations

For each useful source, record:

- Trigger and desired outcome.
- User words and emotional signal.
- What they tried.
- Where they stopped or became uncertain.
- What they feared losing.
- What finally worked, if known.
- Whether the source is evidence about behavior, system facts, or a proposed solution.

Separate observation from interpretation. Example:

- Observation: a user finds a 79 GB File Provider temporary directory, preserves it, renames it, restarts the owner app, and tests sync.
- Interpretation: recoverability and functional verification are part of the deletion decision.

### 5. Update patterns

Add a pattern only when it connects evidence from different sources or explains a repeated behavior. Keep counterexamples. For each pattern record:

- The observed behavior.
- Supporting source types and links.
- The product risk.
- The Tessera response.
- Confidence.
- What evidence would change the conclusion.

The current study has 34 patterns. The creator-cache pass adds the project-linked working-state pattern, the cloud-provider pass adds the provider-state contract pattern, the backup or virtual-disk pass adds the recovery-identity pattern, and the cleanup-trust pass adds the temporary-budget and resumable-case patterns. The rescue-continuity pass strengthens the measurement-source, recovery-escalation, trust, and transaction-budget findings. The developer-creator-state pass strengthens the owner-context, generated-media, working-space, recovery-identity, and post-failure findings. The creator-working-set pass adds the owned-relocation dependency pattern. The first AI-model pass adds the owner reference-graph pattern. The sample-library pass adds the compound installed-object pattern. The newer local-AI pass adds the user-created recovery-value pattern. The latest lanes add the shared-package dependency graph, game payload-versus-personal-state, and app-profile boundary patterns. The safety API lane adds the time-bound scan claim, and the communication probe adds the compound owner-state pattern. New research should refine, split, merge, or reject the patterns. Do not add a new pattern only to increase the count.

### 6. Grill the frontier

After the evidence update, ask Ammar the decisions whose prerequisites are now settled. Give a recommended answer. Wait for his choices before treating the design as settled.

Questions about the user's preferences belong to Ammar. Facts about macOS, the local machine, and the code belong to the agent.

Record every submitted choice in [tessera-disk-rescue-decision-ledger.json](./tessera-disk-rescue-decision-ledger.json). TempliLink responses belong to the page slug that collected them. When a new slug replaces an old page, convert settled interactions to read-only summaries. Do not copy an answered form into the new page as if it were open again. Before publishing, compare the page's interaction IDs with the ledger's `current_frontier`.

### 7. Update the handoff

Before an implementation agent starts a feature, update the handoff with:

- the decision ledger and exact source response for each settled choice;
- settled decisions;
- open decisions;
- current evidence and counterexamples;
- exact Tessera files and boundaries;
- safety invariants;
- acceptance tests;
- research that must run again after the feature works.

### 8. Verify the real path

For each feature, test the closest user-facing path:

- low-space entry;
- scan progress and incomplete permissions;
- recommendation explanations;
- selection and staging;
- Move to Trash confirmation;
- result measurement;
- recovery or owner-app handoff;
- memory and reminder behavior.

Research is incomplete if it only passes a unit test while the real window still makes the user guess.

## Research gates

These are checkpoints, not stopping points:

- 250 sources: confirm that the source ledger and evidence classes work.
- 500 sources: compare at least three user contexts.
- 1,000 sources: test the pattern map against counterexamples.
- 2,000 sources: split findings by trigger, owner app, risk, and recovery path.
- Beyond 2,000: keep collecting when a feature decision, new macOS release, new app behavior, or new user segment adds uncertainty.

The loop can pause only when the current user decision is settled and no frontier question remains for that decision. The corpus itself stays open. The current frontier remains Round 7 recovery context and Round 10 post-failure behavior. After those choices are submitted, rewrite only the deferred owner-boundary question; do not reopen settled forms.

## Safety and privacy boundaries

- No file deletion, Trash move, Empty Trash, or permanent deletion during research.
- Do not upload filenames, paths, scan trees, or personal content.
- Treat public user posts as evidence, not permission to run their commands.
- Re-check current local paths and repo state before any later cleanup or code change.
- Keep Tessera's local-only and no-telemetry model unless Ammar explicitly changes it.
- Never let a remembered preference become a deletion authorization.

## Next research batch

The next batch should add and compare:

- Apple Support Communities threads about System Data, iCloud local copies, backups, and storage recommendations.
- MacRumors discussions about hidden space, snapshots, and cleanup tools.
- More Apple Support Community and MacRumors pages when a new macOS release or product decision creates a counterexample. Do not treat peer advice as system proof.
- Reddit and Mac App Store evidence about permission consent, progress, undo, pricing, and proof after cleanup. Keep product pages separate from user reports.
- More GitHub history for Mole, Nextcloud, Docker Desktop, Xcode tools, and open-source cleaners. Paginate older issues when a decision needs historical coverage. Do not treat automated maintainer digests as user reports.
- App Store reviews that mention reminders, undo, progress, subscriptions, background helpers, and accidental deletion.
- User reports from developers, creators, and cloud-heavy users.
- More creator reports for sample-library vendors, audio plug-ins, CAD asset libraries, motion tools, and multi-Mac library use. The first professional-library pass now covers eight vendor families; the next pass should add failed repairs, expired entitlements, offline rigs, interrupted copies, and real post-move DAW or project tests.
- More local-AI reports about failed exports, recovered checkpoints, corrupted derivatives, offline external roots, shared model copies, and post-cleanup load tests. The next pass should test the recovery classes across other training and image tools while keeping base weights, user fine-tunes, datasets, projects, generated output, runtime state, and rebuildable caches separate.
- Manually code the 5,005 automated GitHub follow-up candidates. Preserve the source queue and record false positives, duplicate behavior, maintainer-only text, and platform mismatch. Do not promote automated labels into behavior counts.
- Paginate older game, package, app-profile, and communication issue history beyond page 10 while authenticated access is available. Keep each page bounded and deduplicated.
- Game-library follow-up about cloud-save conflicts, lost launcher registration, modded installs, compatibility-container recovery, post-move launch and save tests, offline operation, and missing external volumes. Pages 1 through 10 exist; manual coding is still open.
- Package-cache follow-up about hardlink and APFS-clone allocation, offline rebuild failures, unpublished or local dependencies, owner dry-run and cleanup failures, active locks, and exclusive reclaimable bytes. Pages 1 through 10 exist; manual coding is still open.
- App-profile follow-up about post-cleanup recovery, active browser or IDE handles, encryption and key pairings, unsaved drafts, local history, offline site data, and owner reset effects. Pages 1 through 10 exist; manual coding is still open.
- Mail, Messages, Signal, Element, Discord, Telegram, WhatsApp, and other offline communication or media apps where exact caches sit beside irreplaceable local state. Add owner documentation and direct reports before proposing an adapter.
- Direct owner-context reports for iCloud, Photos, Docker or other virtual disks, iPhone backups, and File Provider sync state.
- Direct owner-context reports for Time Machine, old-device backups, Docker disk images, Parallels or UTM bundles, snapshots, guest partitions, and host-versus-guest size mismatches. Keep restore identity and runtime state separate from file size.
- Direct low-space reports about update or install working-space budgets, failed downloads, and emergency entry. Record the user's finish line and the extra temporary space needed.
- Direct cleanup-tool reports about interrupted scans, lost review state, resumability, saved plans, per-run logs, undo, and result proof. Keep continuity needs separate from recurring growth.
- First-party owner-app documentation for cache scope, generated-media deletion, retention controls, external-media impact, rebuild behavior, cloud state, eviction, streaming, mirroring, and remote-delete semantics. Keep version and platform visible.
- First-party backup and virtual-disk documentation for restore paths, snapshot retention, prune scopes, sparse images, shutdown requirements, trim or reclaim behavior, guest state, and destructive settings. Keep owner actions separate from generic Trash.
- Provider-specific reports and documentation for Dropbox, OneDrive, Google Drive, iCloud Drive, Nextcloud, and other File Provider clients. Record local eviction, cached bytes, completed sync, offline need, and remote-delete meaning as separate states.
- First-party platform changes that affect local copies, permissions, snapshots, Trash, storage accounting, file identity, volume identity, open writers, coordinated changes, and invalidation events. The current safety API lane is a baseline, not a complete platform audit.

Then update the pattern table and ask only the open decision frontier. The current questions concern recovery proof and owner action for backups or virtual disks, plus pause, blocker, and background-observer behavior after a failed rescue. Settled choices stay as read-only summaries on every new TempliLink page.

After each Tessera feature slice, repeat the loop with the feature's new uncertainty. Re-run the relevant source lanes, add counterexamples, inspect the real macOS path, and keep the handoff open until the user decision and the evidence agree.
