# Tessera disk-rescue ethnographic study

Status: living research record. The corpus now has 3,005 non-automated user and issue evidence URLs, plus 5,005 automated GitHub candidates held for manual coding. Separate authority lanes contain 30 Apple system facts and 426 owner or tool facts. The 88-record market signal set remains separate. All 58 corpus inputs contain 8,554 unique URLs with no exact or normalized duplicates. Rounds 2 through 6, 8, and 9 are settled. Rounds 7 and 10 are open. The old Round 11 form is retired and will be rewritten only after those open choices are settled.

Date: 2026-08-31

Repo baseline: main at e88d163 (v0.1.6, build 7), fast-forwarded from origin/main before this study.

## Executive summary

The hard part of a full disk is not finding large files. It is deciding what can leave without causing a new problem.

People reach for a cleaner when they have an urgent job: install an update, export a project, download a tool, or make the Mac usable again. They do not want a storage tour. They want a short plan that explains the cause, limits risk, gives them a reversible action, and proves the result.

The strongest product direction is a rescue workflow inside Tessera:

1. Start with a low-space problem or a clear Rescue space entry point.
2. Scan the selected volume and separate physical causes from macOS accounting noise.
3. Produce one ranked plan. Show every meaningful candidate, but preselect only high-confidence, rebuildable items.
4. Give each candidate a short reason, exact path, owner, risk, likely side effect, and expected reclaim.
5. Stage candidates for review. Use Move to Trash as the primary action.
6. Re-measure after the move. Explain what was reclaimed, what remains in Trash, and what could not be changed because of snapshots, open handles, sync, permissions, or app ownership.
7. Remember user choices locally at the category or source level, with expiry and an easy reset.

This matches the choices Ammar made in the first interview round:

| Decision | Selected direction |
| --- | --- |
| Entry point | Rescue first |
| Default selection | Safe-only |
| Scope | Rank all candidates, separated by risk |
| Execution | One clear Move to Trash confirmation, then verify |
| Recurrence | Remember now |

The last decision needs more detail. "Remember now" must not become silent cleaning, a daily nag, or a record of personal filenames.

## Research questions

- Why do people abandon existing disk tools even when those tools can scan the disk?
- What evidence makes a deletion feel safe enough to approve?
- Which storage problems are common enough for a first-class Tessera workflow?
- What should Tessera do when the cause is outside its safe control, such as iCloud, APFS snapshots, Docker, or an open file?
- What should a local memory and reminder model remember?

## Method and limits

The prior pass reviewed more than 40 public pages on 2026-08-30. The current study contains 3,005 non-automated user and issue evidence records, 5,005 automated GitHub candidates, 30 Apple system facts, 426 owner or tool facts, and 88 separate market signals. The latest follow-up covers issue pages 1 through 10 and adds 1,869 game-library candidates, 1,059 package-reclaim candidates, 1,187 app-profile candidates, and 890 communication candidates across 11 owner repositories. A read-only local probe adds one machine snapshot for Messages, Discord, Mail, and Notes. These additions sharpen payload-versus-personal-state boundaries, shared-store topology, offline rebuild risk, exact profile roles, credential dependencies, session recovery, active-writer risk, and scan invalidation. I compared the behavior described across source types:

A bulk Reddit JSON search returned HTTP 403 during this pass. I did not count that failed pull. The product-experience ledger contains only Reddit pages that were directly inspected through search and page access.

- Apple support and product documentation for storage semantics, Trash behavior, permissions, and hidden space.
- User-authored Reddit, Ask Different, and MacRumors discussions for real triggers, language, workarounds, fear, and failure reports.
- App Store reviews and version notes for recurring expectations around review, undo, progress, reminders, and safety defaults.
- Product discussion and launch threads as market signals. These are useful for seeing what builders think users need, but they are weak evidence of independent demand.
- Tessera's current source, design notes, and existing cleanup architecture.

This is online ethnography, not a representative survey. Public posts over-sample people with problems. Some recent product threads may be promotional or AI-assisted. I do not use those threads as proof of prevalence. User reports are strong evidence of confusion and desired outcomes, but not proof that a suggested shell command is safe. Apple documentation and local code are the authority for system behavior.

The most reliable conclusion is therefore about the shape of the job and the trust model, not about the exact percentage of users who have each storage cause.

## Corpus expansion round

The first structured collection pass made 26 bounded Ask Different API pulls across storage, disk space, System Data, caches, Trash, snapshots, iCloud, backups, Xcode, Docker, and related macOS tags.

- 1,860 raw question records.
- 1,618 unique question URLs after de-duplication.
- 840 records screened as core to the storage-rescue question using title-level storage and cleanup signals.
- 778 records kept as adjacent context because tags alone are not proof of direct relevance.
- 1,377 records have at least one answer.
- 1,340 records are marked answered by the API.

The machine-readable ledger is [tessera-disk-rescue-source-ledger.jsonl](./tessera-disk-rescue-source-ledger.jsonl). It stores URL, title, score, answer count, tags, creation date, evidence class, screening rule, question ID, and topic flags. It does not store full post bodies. The body sample index is [tessera-disk-rescue-askdifferent-content-sample.jsonl](./tessera-disk-rescue-askdifferent-content-sample.jsonl). The collection is a large baseline from one community, not a claim that 1,618 people were interviewed. The next passes must add other communities, reviews, issue trackers, and direct product evidence.

The issue-tracker ledger is [tessera-disk-rescue-github-issue-ledger.jsonl](./tessera-disk-rescue-github-issue-ledger.jsonl). The market-signal ledger is [tessera-disk-rescue-market-scan.jsonl](./tessera-disk-rescue-market-scan.jsonl). They are separate because an issue report, a maintainer report, and a repository description do not have the same evidence weight.

The new community ledger is [tessera-disk-rescue-community-source-ledger.jsonl](./tessera-disk-rescue-community-source-ledger.jsonl). It now contains 66 Apple Support Community pages and 36 MacRumors pages. Eighty-one are core first-person reports, nineteen are adjacent context, and two are marked unverified because they mix broad peer advice or a neighboring platform. The pages are source-diverse evidence, not 102 independent participants.

The product-experience ledger is [tessera-disk-rescue-product-experience-ledger.jsonl](./tessera-disk-rescue-product-experience-ledger.jsonl). It now contains 136 Reddit pages, 8 App Store review pages, and 3 App Store product pages. One hundred eighteen records are core, eighteen are adjacent, and eleven are market signals. The App Store and Reddit pages are not a survey and do not provide independent-user counts.

The system-facts ledger is [tessera-disk-rescue-system-facts-ledger.jsonl](./tessera-disk-rescue-system-facts-ledger.jsonl). It contains 8 Apple Support and 8 Apple Developer records. The new [safety API ledger](./tessera-disk-rescue-safety-api-ledger.jsonl) adds 14 Apple Developer records about file identity, capacity, running applications, coordination, FSEvents, and iCloud state. These are authority for macOS and Foundation behavior, not evidence that users behave in a certain way. They anchor the rules for System Data, Trash, APFS snapshots, permissions, File Provider state, and coordinated file operations.

The owner-documentation ledger is [tessera-disk-rescue-owner-documentation-ledger.jsonl](./tessera-disk-rescue-owner-documentation-ledger.jsonl). It contains 25 first-party product guides for DaVinci Resolve, Adobe Premiere, Final Cut Pro, Dropbox, OneDrive, Google Drive, iCloud Drive, iPhone backups, Time Machine, Docker, Parallels, and UTM. These guides define owner-app scopes, generated media, cache regeneration, local materialization, provider states, virtual-disk reclaim, restore paths, and remote-delete warnings. They are product facts, not independent user demand.

The creator-workspace ledger is [tessera-disk-rescue-creator-workspace-ledger.jsonl](./tessera-disk-rescue-creator-workspace-ledger.jsonl). It adds 54 unique URLs: 33 core user reports, 3 adjacent counterexamples, and 18 first-party owner facts across Logic Pro, Ableton Live, Unreal Engine, Blender, and Autodesk Fusion. This lane separates sound and sample libraries, project references, simulation bakes, derived caches, offline CAD state, relocation transactions, and working-space requirements. It does not treat a large creator folder as one cleanup class.

The AI-model-storage ledger is [tessera-disk-rescue-ai-model-storage-ledger.jsonl](./tessera-disk-rescue-ai-model-storage-ledger.jsonl), with field notes in [tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md](./tessera-disk-rescue-ai-model-storage-agent-lane-2026-08-31.md). It adds 54 unique URLs: 25 first-person reports and 29 owner facts across Ollama, Hugging Face, LM Studio, ComfyUI, and AUTOMATIC1111. It separates logical model identity, shared physical blobs, revisions, links, loaded state, partial transfers, external-volume configuration, staging space, and verified redownload cost. The local read-only probe found no large active model store at the common paths and kept the 279 MB historical Hugging Face cache already in Trash outside active-candidate counts and outside any permanent-deletion authority.

The professional sample-library ledger is [tessera-disk-rescue-sample-library-ledger.jsonl](./tessera-disk-rescue-sample-library-ledger.jsonl). It adds 79 unique URLs: 31 core reports, 4 adjacent counterexamples, and 44 first-party owner facts across Native Instruments, Spitfire Audio, Arturia, Toontrack, EastWest, UVI, IK Multimedia, and Steinberg. These records separate downloaded installers, installed samples, applications, plug-ins, owner indexes, licenses, presets, update locations, host-visible state, and device authorization. A large vendor folder is therefore not one cleanup object. The lane also shows why a copied library must pass owner registration, standalone load, and host or project tests before the old copy becomes reviewable.

The newer local-AI ledger is [tessera-disk-rescue-mlx-local-ai-ledger.jsonl](./tessera-disk-rescue-mlx-local-ai-ledger.jsonl), with field notes in [tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md](./tessera-disk-rescue-mlx-local-ai-agent-lane-2026-08-31.md). It adds 61 unique URLs: 33 first-person reports and 28 owner or implementation facts across MLX, MLX-LM, Hugging Face Datasets, Draw Things, DiffusionBee, and llama.cpp. It separates downloaded bases, adapters, resume checkpoints, local training data, fused or quantized derivatives, processed datasets, prompt caches, project history, generated outputs, active transfers, external roots, and runtime state. The strongest safety boundary is simple: preserve user-created source state until every derivative passes a real load and task test.

The game-library ledger is [tessera-disk-rescue-game-library-ledger.jsonl](./tessera-disk-rescue-game-library-ledger.jsonl), with field notes in [tessera-disk-rescue-game-library-agent-lane-2026-08-31.md](./tessera-disk-rescue-game-library-agent-lane-2026-08-31.md). It adds 156 unique URLs: 71 core reports, 30 adjacent counterexamples, and 55 owner facts across eleven launcher or runtime families. A game install can mix a redownloadable payload with local saves, worlds, screenshots, mods, launcher registration, cloud state, patch staging, and compatibility containers. A missing external volume means unavailable, not orphaned.

The package-cache ledger is [tessera-disk-rescue-package-cache-ledger.jsonl](./tessera-disk-rescue-package-cache-ledger.jsonl), with field notes in [tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md](./tessera-disk-rescue-package-cache-agent-lane-2026-08-31.md). It adds 224 unique URLs: 104 core reports, 54 adjacent counterexamples, and 66 owner facts across eleven package-manager families. Package storage includes shared stores, hardlinked or cloned project materializations, build output, installed environments, global tools, offline sources, lockfiles, configuration, credentials, and partial transfers. A path named `node_modules` or `cache` does not prove that every byte is safely replaceable.

The app-profile ledger is [tessera-disk-rescue-app-profile-ledger.jsonl](./tessera-disk-rescue-app-profile-ledger.jsonl), with field notes in [tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md](./tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md). It adds 183 unique URLs: 120 core reports, 5 adjacent counterexamples, and 58 owner facts across nine browser, editor, and communication-app families. Profiles place exact caches beside session restore, bookmarks, passwords and encryption state, cookies, offline site data, extensions, drafts, local history, and workspace databases. Tessera must classify the exact subpath and its dependencies, not the parent profile.

The GitHub follow-up ledgers add 5,005 automated candidates across issue pages 1 through 10: 1,869 game records, 1,059 package records, 1,187 app-profile records, and 890 communication records. They come from up to 1,000 issue records per repository, after pull-request, empty-body, keyword, and URL-deduplication filters. They are a discovery index, not manual ethnography. The page-1 lane notes are [game](./tessera-disk-rescue-game-followup-2026-08-31.md), [package](./tessera-disk-rescue-package-followup-2026-08-31.md), [app profile](./tessera-disk-rescue-profile-followup-2026-08-31.md), and [communication](./tessera-disk-rescue-communication-followup-2026-08-31.md). The next step is manual coding and older-history pagination, not a demand claim. Pages 5 through 10 used the local authenticated GitHub CLI without exposing its token.

The communication local probe is [tessera-disk-rescue-communication-local-probe-2026-08-31.md](./tessera-disk-rescue-communication-local-probe-2026-08-31.md). It measured aggregate allocation only. Messages used about 9.9 GB, with attachments at about 8.1 GB and caches at about 1.4 GB. Discord used about 989 MB, with its cache at about 741 MB. Messages, Discord, and WhatsApp were active. No message, mail, note, account, or attachment content was read, and no file was changed.

The [safety API follow-up](./tessera-disk-rescue-safety-api-followup-2026-08-31.md) adds a platform boundary: path, file identity, volume identity, resource type, logical size, allocated size, owner state, coordinated changes, FSEvents, and cloud status are separate signals. A scan result is therefore a time-bound claim that needs invalidation and last-step revalidation.

New cross-source evidence added after the first 40-page pass includes:

- A Nextcloud issue reports a File Provider temporary directory reaching about 79 GB while macOS labelled it System Data. The reporter preserved the old directory, renamed it, restarted the app, and verified virtual files, edits, saves, and sync before considering permanent deletion: [Nextcloud File Provider issue](https://github.com/nextcloud/desktop/issues/10306).
- A Mole issue reports root-owned files under /private/var/folders reaching about 221 GB and explains why an unprivileged scan can show almost nothing. It proposes an explicit deep mode with a documented permission boundary: [Mole hidden-space issue](https://github.com/tw93/Mole/issues/1253).
- New open-source cleaner projects repeat the same trust controls: allowlists, protected paths, plain explanations, rule provenance, Trash, audit logs, local-only processing, and a fail-closed response when ownership is unclear: [Purge](https://www.reddit.com/r/MacOS/comments/1vchqcf/purge_free_open_source_cache_cleaner_for_macos/), [Gargantua](https://www.reddit.com/r/MacOS/comments/1u4t8p6/gargantua_an_opensource_macos_cleaner_that/), and [mac-storage-cleaner](https://github.com/JubaKitiashvili/mac-storage-cleaner).
- Creator reports add a separate owner-context lane: Resolve cache can reach hundreds of GB or more, Final Cut libraries can balloon through render, proxy, optimized, or analysis files, and Lightroom users can confuse the local cache or library with remote originals. First-party guides confirm that some generated media can be regenerated while scope and external-media impact still matter: [Resolve cache thread](https://www.reddit.com/r/davinciresolve/comments/1sxncre/psa_to_clean_out_your_cache/), [Final Cut library thread](https://www.reddit.com/r/finalcutpro/comments/1uak0vv/help_short_film_editing_is_eating_my_storage/), [Lightroom cache thread](https://www.reddit.com/r/Lightroom/comments/1plqnlb/how_to_change_default_cache_folder_lightroom_cc/), [Apple Final Cut Pro render guide](https://support.apple.com/en-mide/guide/final-cut-pro/ver68a8c250/mac), and [Adobe media-cache guide](https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/manage-media-cache.html).
- Cloud reports add a provider-state lane: Dropbox and iCloud or Photos users see online-only labels, local bytes, hidden provider caches, delayed optimization, and fear of deleting remote data. First-party guides show that Dropbox and OneDrive have an eviction action, Google Drive separates streaming from mirroring, and iCloud Drive uses Remove Download. The action must therefore be provider-specific and measured: [Dropbox online-only guide](https://help.dropbox.com/sync/make-files-online-only), [OneDrive Files On-Demand guide](https://support.microsoft.com/en-US/onedrive/save-disk-space-with-onedrive-files-on-demand-for-mac), [Google Drive stream or mirror guide](https://support.google.com/drive/answer/13401938?hl=en), and [Apple iCloud Drive guide](https://support.apple.com/en-ie/guide/mac-help/mchl1a02d711/mac).
- Backup and virtual-disk reports add a recovery-identity lane: users ask about backups from an old Mac, a full Time Machine destination, a deleted Parallels VM that did not release host space, a guest disk that does not see its new capacity, and a VM volume or Docker image mixed with live runtime state. First-party guides make the owner boundary explicit: Finder manages device backups, Time Machine owns versioned history, Docker owns its disk image and prune scopes, and Parallels or UTM require shutdown, backup, snapshot, or guest checks before reclaim. Tessera should show restore target, owner, host-versus-guest state, logical-versus-physical size, and the exact owner action before it offers any change: [Apple device backup guide](https://support.apple.com/en-us/108809), [Apple Time Machine guide](https://support.apple.com/en-us/104984), [Docker Mac FAQ](https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/), [Parallels reclaim guide](https://kb.parallels.com/br/123553), and [UTM resize guide](https://docs.getutm.app/settings-qemu/drive/resize-and-compress/).
- The cleanup-trust pass adds a second layer of direct behavior. Users lose a native cleanup entry point after closing it, report that deleting or emptying Trash does not change the number they see, and ask for a simple review surface that keeps the original paths, explains duplicate matches, summarizes each Trash run, and supports undo or export. Separate update and install reports show that the finish line is often temporary working space, not a single file: [native cleanup discovery report](https://www.reddit.com/r/MacOS/comments/1esh1ip/apples_own_disk_storage_cleanup_app_where_did_it/), [cleanup result failure report](https://www.reddit.com/r/MacOS/comments/1es66yf/nothing-frees-up-storage-space/), [review-first cleanup discussion](https://www.reddit.com/r/MacOSApps/comments/1sews1e/i_built_a_mac_cleanup_app_for_people_who_want_to/), and [App Store install-space report](https://www.reddit.com/r/MacOS/comments/19egnz1/app_store_there_is_not_enough_disk_space/).
- The rescue-continuity pass adds direct counterexamples about the finish line and the user's willingness to trust automation. One user moves data to an external SSD but still cannot reconcile Disk Utility with Storage Settings. Others report that 32 GB or 50 GB free is not enough for an upgrade, that a failed update can leave snapshots or downloads behind, and that a full disk can block even the backup or installer step needed to recover it. A separate manual-maintenance discussion shows a user choosing exact paths and limited background activity after years of using cleaners: [measurement mismatch report](https://www.reddit.com/r/MacOS/comments/1qe6umz/why_is_the_available_space_in_disk_utility_and/), [Monterey update-space report](https://discussions.apple.com/thread/253869188), [M1 upgrade-space report](https://discussions.apple.com/thread/256240026), [snapshot and update report](https://discussions.apple.com/thread/254195248), [full-storage recovery report](https://discussions.apple.com/thread/256247093), [device-backup update report](https://discussions.apple.com/thread/7640010), and [manual-maintenance discussion](https://www.reddit.com/r/MacOS/comments/1gwbeag/after-years-of-cleanup-apps/).
- The new community pages add counterexamples to the recovery and permission lanes. Time Machine users disagree about automatic pruning and report old-history loss or an unusable Mac during a backup. Cloud users cannot tell whether a delete changes only local bytes or the remote item. Scanner users report that Full Disk Access still leaves protected containers or APFS snapshots out of view: [MacRumors full Time Machine disk](https://forums.macrumors.com/threads/how-does-time-machine-handle-a-full-disk.2468176/), [Apple Community iCloud local copy](https://discussions.apple.com/thread/253988410), [Apple Community Disk Inventory X](https://discussions.apple.com/thread/255710561), and [MacRumors DaisyDisk scan](https://forums.macrumors.com/threads/daisydisk-very-slow-to-scan-in-sonoma.2406837/).
- The rescue-failure-retry lane adds 21 directly inspected counterexamples after an attempted fix. MacRumors users report deleting 40 to 100 GB without a visible change, losing confidence in Storage Settings, or finding that a permission request is wider than the folders they expected. Reddit users report that an update, copy, backup, iCloud sync, or normal login can fail even when a different display says there is space; another user reports repeated cleanup ending in a machine that would not boot. These cases support a **post-failure state machine**: name the failed transaction, preserve the case, show the exact blocker, and offer the smallest next safe step or owner handoff. They do not support a universal command or a claim that a restart, snapshot removal, or cache deletion will solve the cause: [MacRumors measurement conflict](https://forums.macrumors.com/threads/sequoia-15.3.1-showing-incorrect-free-disk-space.2449198/page-2), [MacRumors backup failure](https://forums.macrumors.com/threads/time-machine-backup-filled-internal-disk.2412142/), [Reddit backup working-space report](https://www.reddit.com/r/MacOS/comments/1u1d0k5/time_machine_backup_failing_due_to_not_enough/), [Reddit iCloud recovery report](https://www.reddit.com/r/iCloud/comments/1ur3bxf/macos_storage_fixed/), and [Reddit boot failure after cleanup](https://www.reddit.com/r/MacOS/comments/1rpfzp2/system_data_going_crazy/).
- The developer-creator-state lane adds 44 directly inspected pages: ten Apple Support Community or MacRumors pages and 34 Reddit reports about Xcode, Docker, Unity, After Effects, Lightroom, Final Cut Pro, and Time Machine. These reports show a compound working set: source media or project state, generated output, owner cache, virtual-disk or backup state, and temporary room for the next transaction. They also show why generic path deletion fails as a mental model: Docker.raw can have a large logical size without the same physical reclaim, an external project can still need internal package or render space, and deleting a Lightroom library or active Final Cut output can change the working project rather than only remove junk. The product implication is an owner-aware working-set review with a goal, buffer, source or project identity, generated-media class, active-state check, logical-versus-physical measurement, and source-aware owner action: [Apple Community: Xcode update space](https://discussions.apple.com/thread/250263962), [Apple Community: APFS snapshot and no-space boot](https://discussions.apple.com/thread/255493617), [Reddit: Xcode storage breakdown](https://www.reddit.com/r/Xcode/comments/1ry2tnx/xcode-was-quietly-using-60gb-on-my-mac-this-is/), [Reddit: Docker.raw size mismatch](https://www.reddit.com/r/docker/comments/u7qke3/dockerraw-is-way-too-big/), [Reddit: Final Cut cache filling the disk](https://www.reddit.com/r/finalcutpro/comments/m1ff4u/help_fcpx_eating_up_my_entire_ssd_keeps_rendering/), [Reddit: Lightroom local library and edit loss](https://www.reddit.com/r/Lightroom/comments/qf1k6v/need_help_made_a_terrible_mistake_lightroom_cloud/), and [Reddit: Time Machine repeated failure](https://www.reddit.com/r/MacOS/comments/1p19sgl/why_is_time_machine_so_unreliable_now/).
- The independent developer-creator agent lane adds 47 new URLs: 41 first-person reports and 6 first-party Unity or Android guides. Xcode and Android reports make temporary directories, partial installers, and component counts part of the finish line. Docker reports separate guest content, raw-image allocation, relocation, and live workload failures. Unity and Adobe reports show project imports, asset caches, scratch disks, external volumes, and operation-time spikes. Time Machine reports show source-side staging pressure and old machine identities. The lane adds a stronger implementation rule: capture the failed workflow phase and owner before recommending cleanup, expose working-space requirements on every pressured volume, and keep relocation, compaction, recovery-history review, and generic Trash as separate actions. The full lane is [tessera-disk-rescue-agent-lane-2026-08-31.md](./tessera-disk-rescue-agent-lane-2026-08-31.md), with structured records in [tessera-disk-rescue-developer-creator-ledger.jsonl](./tessera-disk-rescue-developer-creator-ledger.jsonl). Representative sources include [Xcode install working-space report](https://developer.apple.com/forums/thread/660905), [Docker raw-image allocation report](https://forums.docker.com/t/docker-desktop-mac-ignoring-the-disk-usage-limit-i-specified-in-settings-resources/147964), [Unity cache documentation](https://docs.unity3d.com/Manual/upm-config-cache-as.html), [Adobe scratch-disk report](https://community.adobe.com/questions-712/photoshop-using-massive-amount-of-disk-space-when-opening-a-psd-and-then-scratch-disks-are-full-1129996), and [Time Machine source-space report](https://discussions.apple.com/thread/256167650).
- The creator-working-set lane adds 54 new URLs: 36 direct user reports and 18 first-party owner facts across Logic Pro, Ableton Live, Unreal Engine, Blender, and Autodesk Fusion. The lane shows that a move can succeed at the filesystem level and still fail in the owner app, that an external final location can still need internal download or unpack space, and that caches can be project state, rebuildable derived data, or a failed repair target. Tessera must show source and destination volume, owner-recognized location, per-phase working space, project references, availability and performance cost, and a post-move open test before the old copy becomes reviewable. Representative sources include [Logic library migration rules](https://support.apple.com/en-us/125036), [Ableton external storage rules](https://help.ableton.com/hc/en-us/articles/5809449695900-External-Storage-and-Backup), [Unreal DDC configuration](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine), [Blender bake behavior](https://docs.blender.org/manual/en/5.0/physics/baking.html), and [Fusion personalized-state recovery](https://forums.autodesk.com/t5/fusion-support-forum/a-software-problem-has-caused-fusion-360-to-close-unexpectedly/td-p/8252788).
- The AI-model-storage lane adds 54 new URLs: 25 direct reports and 29 owner facts across Ollama, Hugging Face, LM Studio, ComfyUI, and AUTOMATIC1111. The lane shows that logical model lists can hide partial transfers or shared blobs, that loaded and referenced models are different states, and that one external model store can reduce copies while increasing the blast radius across tools. Tessera needs owner inventory, physical reference graphs, per-volume staging budgets, link identity, loaded-state checks, exact revision or quantization, owner dry runs, and a real load test before source removal: [Ollama model inventory](https://docs.ollama.com/api/tags), [Hugging Face cache management](https://huggingface.co/docs/huggingface_hub/guides/manage-cache), [LM Studio model inventory](https://lmstudio.ai/docs/cli/local-models/ls), [ComfyUI model-path configuration](https://github.com/Comfy-Org/ComfyUI/blob/master/extra_model_paths.yaml.example), and [AUTOMATIC1111 path controls](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Command-Line-Arguments-and-Settings).

- The latest GitHub follow-up is intentionally split from the validated behavior corpus. It adds 5,005 automated candidates across Lutris, Proton, Prism Launcher, Poetry, pip, vcpkg, Signal Desktop, Element, Mattermost, Telegram Desktop, and Jitsi Electron, using issue pages 1 through 10. Game records emphasize launcher registration, prefixes, mods, external paths, and partial transfers. Package records emphasize shared dependencies, local sources, locks, and rebuilds. Profile and communication records emphasize databases, sessions, exports, encryption, attachments, and sync. The lane notes explain the noise and the manual-coding work still required: [game](./tessera-disk-rescue-game-followup-2026-08-31.md), [package](./tessera-disk-rescue-package-followup-2026-08-31.md), [profile](./tessera-disk-rescue-profile-followup-2026-08-31.md), and [communication](./tessera-disk-rescue-communication-followup-2026-08-31.md).

- The safety API lane adds 14 first-party Apple records. It confirms that file identity, volume identity, resource type, logical size, allocated size, owner inventory, file coordination, FSEvents, and cloud state are separate signals. FSEvents can coalesce changes, file presenters do not see every low-level write, and launch notifications can miss background apps. Tessera must invalidate stale scans and revalidate exact identity and owner state at the last safe step: [URLResourceKey](https://developer.apple.com/documentation/foundation/urlresourcekey), [runningApplications](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications), [NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter), and [File System Events](https://developer.apple.com/documentation/coreservices/file_system_events).

- The local communication probe found one important counterexample: the largest current Messages allocation is attachments, but the same root also contains caches, sync state, a live database, and drafts. Discord also mixes a large cache with local storage and session state. Messages, Discord, and WhatsApp were active. This is one machine snapshot, not demand evidence, but it makes the owner-state boundary concrete: [communication probe](./tessera-disk-rescue-communication-local-probe-2026-08-31.md).

These sources sharpen the design. Tessera must report when its view is incomplete because of permissions. It must show rule provenance and version. It must treat a safe action as a chain of evidence and checks, not a label.

### Content sample

Titles and tags show the shape of the corpus. They do not show how users describe the problem. I expanded the body pass to 278 unique questions selected from high-score, recent, and unanswered core records.

- 278 unique question bodies.
- 268 unique authors.
- 158 marked answered and 120 marked unanswered.
- 144 mention storage, space, or accounting language.
- 173 mention an app, owner, or data context such as iCloud, Xcode, Docker, backups, Photos, or containers.
- 121 mention recovery language such as Trash, snapshots, restore, or backup.
- 20 use direct uncertainty language such as "is it safe," "can I delete," or "I do not know."
- 167 mention workflow language such as Finder, Terminal, scanning, waiting, restarting, or a stuck tool.
- 30 mention permission language such as Full Disk Access, EPERM, root ownership, or sudo.

The keyword counts are exploratory screens, not prevalence estimates. The sample deliberately includes high-signal and unanswered records, so it cannot estimate the rate of any behavior. It does show why the title-only ledger needs a second layer: read the body and answer before changing a safety rule. An unanswered storage question is still a useful design test because the user may have a real problem with no trusted public resolution.

The full collection and sample manifest live in [tessera-disk-rescue-research-manifest.json](./tessera-disk-rescue-research-manifest.json).

### Issue-tracker expansion

The expanded structured pass now contains 403 unique GitHub issue or discussion URLs from 16 cleaner, storage, sync, and recovery repositories. Pull requests were excluded. The records split into 274 product issue reports, 63 sync-storage-adjacent reports, and 66 maintainer-generated upstream or compatibility signals. Four records have no body text. This is evidence about failure modes and product requests, not 403 independent participants.

The follow-up issue discovery pass is separate from that structured issue sample. It contains 5,005 candidate URLs from 11 owner repositories across issue pages 1 through 10. It fetched up to 1,000 issue records per repository, excluded pull requests and empty bodies, screened title and body text for storage or state terms, and removed URLs already present in the corpus. The result is intentionally marked `automated_candidate`; it is not manual coding and is not included in the 3,005 non-automated evidence count.

The issue repositories cover Mole, PureMac, MangoDisk, Burrow, ClearDisk, Purge, mac-cleaner-cli, mac-cleanup-go, dev-cleaner, MacSift, Spark Clean, LittleClean, Mac-Cleaner, CleanMyMac CLI, Nextcloud Desktop, and Pearcleaner. The separate market scan found 77 repository descriptions across the same problem space, with 14,576 stars at collection time. Those descriptions show what builders are converging on, but they do not prove user demand.

I read a stratified sample of 103 issue records across all 15 repositories. It contains 102 non-empty bodies and 23,134 whitespace-delimited words. The sample was capped per repository and weighted toward direct safety, space, cleanup, sync, and workflow signals. Keyword screens found:

- 32 records mention allowlists, protected paths, exclusions, or keeping data.
- 21 mention Trash, recovery, undo, restore, or rollback.
- 13 mention previews or dry runs.
- 30 mention progress, status, hanging, timeouts, cancellation, or completion.
- 38 mention safety, risk, warnings, or explanations.
- 38 mention a running process, lock, database, SQLite file, or FIFO.

These are exploratory counts from a deliberate sample. They are not prevalence estimates. The strongest new signals are:

- A cleanup action can create a larger incident when it changes live state. Mole reports a running SQLite cache deletion causing an Autodesk helper to write hidden, unlinked files until the disk filled. The scanner needed to check the owner process and verify the result after the action: [Mole live-cache issue](https://github.com/tw93/Mole/issues/1390).
- A path can be safe in one context and the only copy of important data in another. ClearDisk users reported local Claude CoWork sessions and unpushed DVC data being treated like disposable developer cache: [ClearDisk data-loss issue](https://github.com/bysiber/cleardisk/issues/27), [ClearDisk DVC request](https://github.com/bysiber/cleardisk/issues/18).
- App identity is not enough. Shared bundle IDs, app updates, symlinks, and project-owned stores can make a leftover look orphaned while it is still needed: [Mole shared-data issue](https://github.com/tw93/Mole/issues/1437), [Mole uninstaller issue](https://github.com/tw93/Mole/issues/1446), [Mole package-store issue](https://github.com/tw93/Mole/issues/1370).
- Permission failure is a user-facing result, not a scan detail. Users see EPERM, missing Full Disk Access entries, and incomplete results as a broken tool or a false promise: [mac-cleaner-cli permission issue](https://github.com/guhcostan/mac-cleaner-cli/issues/61), [PureMac Full Disk Access issue](https://github.com/momenbasel/PureMac/issues/75).
- Users want the result to be legible. They ask for default-off categories, visible paths, progress, space freed over time, consistent confirmation sheets, and sync warnings: [mac-cleaner-cli selection issue](https://github.com/guhcostan/mac-cleaner-cli/issues/19), [Purge sync warning request](https://github.com/jithin-sabu/purge-app/issues/25), [Purge confirmation request](https://github.com/jithin-sabu/purge-app/issues/41).

This pass strengthens the product direction. Rescue must inspect state and ownership before it labels an item safe. It must show incomplete coverage and failed items. It must explain when the owner app, sync system, or permission boundary controls the next step. A reversible Trash move is useful, but it is not enough when the file may be the only local copy.

### Apple Support and MacRumors comparison

The second community lane adds a different kind of evidence from GitHub issues. These users describe the moment when the Mac feels full, the words they see in Storage, and the steps that failed. The direct pages are indexed in the community ledger; full post bodies are not copied into the repo.

- **The measurement vocabulary itself breaks trust.** Users compare Free, Available, Finder totals, Storage Settings, Disk Utility, and a disk analyzer. A user may delete more than 10 GB and then see System Data rise, while another sees a snapshot hold space after the file disappears: [Apple Community: System Data at 114 GB](https://discussions.apple.com/thread/256303500), [Apple Community: MacBook Air M1 storage discrepancy](https://discussions.apple.com/thread/256250486), [MacRumors: deleting files not freeing HD space](https://forums.macrumors.com/threads/deleting-files-not-freeing-up-hd-space.1299910/). Tessera must name the measurement it is showing and separate moved, logical, physical, and verified space.
- **A fix can be real but incomplete.** One user removes local snapshots and still has a large unexplained System Data remainder. Another reports that a recurring cache returns every few weeks. A targeted Xcode cache removal can rebuild data, but a broad cache wipe has different risk: [Apple Community: System Data and Time Machine Snapshots](https://discussions.apple.com/thread/256213628), [Apple Community: Stop cache from building up](https://discussions.apple.com/thread/256143351), [Apple Community: Xcode cache](https://discussions.apple.com/thread/255415178). Tessera should show partial resolution and recurrence instead of closing the case after one action.
- **The safe unit is often smaller than the folder.** Xcode discussions move between DerivedData, simulator data, command-line tools, project files, and a failed built-in cleanup control. The user's goal is usually a targeted repair or reclaimed space, not deletion of every item owned by Xcode: [Apple Community: Xcode Loading... forever](https://discussions.apple.com/thread/253793548), [Apple Community: Cannot delete Xcode Caches](https://discussions.apple.com/thread/253810545), [Apple Community: Clean Xcode install](https://discussions.apple.com/thread/255469623). Tessera needs rule-level scope and owner-specific side effects.
- **Permission and ownership must be visible before action.** A MacRumors user cannot find the cleaner in Full Disk Access and does not know whether the app can remove everything. Apple Community users report root-only cache growth and ask whether developer tools are part of macOS. The product must say what it could inspect, what it could not, and who owns the next step: [MacRumors: new to macOS and deletion apps](https://forums.macrumors.com/threads/new-to-macos-asking-for-suggestion-for-deletion-app.2481200/), [Apple Community: Stop cache from building up](https://discussions.apple.com/thread/256143351), [Apple Community: Xcode command line tools](https://discussions.apple.com/thread/254132081).
- **Peer advice is a risky interface layer.** The communities contain useful explanations, generic cache commands, warnings against changing system folders, and answers that appear AI-assisted or are later challenged. This is evidence that users need help, but it is not evidence that a command is safe. Tessera should expose its own rule, evidence, and local check rather than quote an unverified recipe: [Apple Community: MacBook Pro System Data storage](https://discussions.apple.com/thread/256249040), [MacRumors: is it safe to remove this?](https://forums.macrumors.com/threads/is-it-safe-to-remove-this.1072138/).

This lane does not create a new broad pattern. It strengthens patterns 2, 3, 4, 5, 8, 13, 16, and 19 in the map below. Before the coverage pass, the map had 19 patterns. The main design change is a stricter result vocabulary: **identified**, **candidate**, **moved**, **verified reclaimed**, **held**, and **still unexplained** must never collapse into one green success state.

### Product experience pass

The next lane checks what happens when people use or pay for a cleanup tool. It now contains 136 direct Reddit reports, 8 App Store review pages, 3 product pages, and 8 maker or launch discussions. The market pages show what builders promise. They do not prove that the promise works.

- **Users copy advice before they understand the scope.** A recent System Data thread contains blanket cache commands beside replies that say to find the real owner first. The Xcode threads show why this matters: one developer reports that broad cache deletion made Xcode unusable, while another separates rebuildable DerivedData from archives and symbols: [Reddit: System Data full](https://www.reddit.com/r/MacOS/comments/1vsseqp/my_storage_is_full_and_i_have_150_gbs_of_system/), [Reddit: Xcode caches](https://www.reddit.com/r/Xcode/comments/ooqvtv/can_you_delete_xcode_caches/), [Reddit: DerivedData safety](https://www.reddit.com/r/Xcode/comments/1vldk61/deriveddata_whats_actually_safe_to_delete_and/). Tessera should turn a broad recipe into a narrow, owner-aware recommendation.
- **Permission is part of conversion.** Users ask whether to grant Full Disk Access, prefer narrower scope when possible, and say the reason in the macOS permission prompt affects their choice. A user also reports that a later OS update removed or changed access. Tessera should request the smallest useful scope, explain it before the system prompt, and recheck it on each scan: [Reddit: app permissions](https://www.reddit.com/r/macapps/comments/1sz4nkl/where-do-you-draw-the-line-with-app-permissions/), [Reddit: Pear Cleaner permission question](https://www.reddit.com/r/macapps/comments/1kyjo8q/pear_cleaner_asking_for_full_disk_access_safe_or_better_to_deny/), [Reddit: Full Disk Access after update](https://www.reddit.com/r/MacOS/comments/111mph7/on_1321_nothing_has_full_disk_access/).
- **People expect proof after an action.** An App Store reviewer says an uninstaller reported success but left the app and did not show what it removed. Another reports a cleaner that freezes while selecting a drive. These are close to Tessera's result problem: the user needs per-item status, measured change, and a clear failure reason: [App Store: App Cleaner](https://apps.apple.com/us/app/app-cleaner-app-uninstaller/id6748003724?mt=12&platform=mac&see-all=reviews), [App Store: MaCleaner Pro](https://apps.apple.com/us/app/macleaner-pro-disk-cleaner/id953795652?mt=12&platform=mac&see-all=reviews).
- **Undo matters when the tool touches many files.** A Folder Tidy reviewer describes a very large Downloads folder and values visible organization and undo before quitting. Disk cleanup is a different action, but the trust mechanism carries over: show the batch, keep the recovery boundary visible, and do not hide the next irreversible step: [App Store: Folder Tidy](https://apps.apple.com/us/app/folder-tidy/id486626129?mt=12&see-all=reviews&platform=mac).
- **Specialist tools earn repeat use when their scope is clear.** DevCleaner reviews describe periodic prompts, selective Xcode cleanup, and readable lists. Cleaner One reviews describe an urgent update problem solved after a short scan. GrandPerspective reviews value fast visual discovery but also mention refresh and hard-link limits: [DevCleaner reviews](https://apps.apple.com/us/app/devcleaner-for-xcode/id1388020431?mt=12&platform=mac&see-all=reviews), [Cleaner One reviews](https://apps.apple.com/us/app/cleaner-one-disk-clean/id1473079126?mt=12&platform=mac&see-all=reviews), [GrandPerspective reviews](https://apps.apple.com/us/app/grandperspective/id1111570163?mt=12&platform=mac&see-all=reviews). Tessera should remember a useful cause and show a focused plan, not become a generic scheduled cleaner.
- **Owner-managed paths look like ordinary files until the user needs them.** Docker users find a large disk image but need Docker's own cleanup model. Backup users want to know whether a copied backup is still the restore path. Photos and iCloud users want local bytes released without removing the remote library: [Docker disk image](https://www.reddit.com/r/docker/comments/m4i0fe), [iPhone backup](https://www.reddit.com/r/mac/comments/1jec2rn), [iCloud Photos](https://www.reddit.com/r/MacOS/comments/11o6kmt). Tessera should name the owner and offer a source-aware action or handoff. A generic Trash move is the wrong default.
- **Creator caches are project-linked working state.** Resolve and Final Cut users report caches or generated media larger than the source footage, repeated growth during active editing, and uncertainty about whether clearing it changes the project. Lightroom users report a local cache or library that fills the internal drive even when originals live elsewhere. The owner apps expose scoped cleanup and explain that generated data can return, but the user still needs active-project state, location, rebuild cost, and the exact generated-media class before acting: [Resolve cache growth](https://www.reddit.com/r/davinciresolve/comments/1lgim72/best-way-to-manage-media-cache/), [Final Cut repeated render growth](https://www.reddit.com/r/finalcutpro/comments/m1ff4u/help_fcpx_eating_up_my_entire_ssd_keeps_rendering/), [Lightroom local cache](https://www.reddit.com/r/Lightroom/comments/1gdsjud), [Resolve owner guide](https://documents.blackmagicdesign.com/UserManuals/DaVinci-Resolve-17-Colorist-Guide.pdf), and [Final Cut generated-media guide](https://support.apple.com/en-gb/guide/final-cut-pro/verb8e5f6fd/12.3/mac/15.6). Tessera should offer an owner-app action or a review-only handoff, plus prevention settings, rather than generic folder deletion.
- **Cloud state is a contract, not a size label.** Dropbox, OneDrive, Google Drive, and iCloud describe different local states and different meanings for an action. Direct reports add stale labels, hidden caches, logical-versus-physical confusion, delayed optimization, and fear of remote deletion. Tessera should show the provider, current sync state, logical and physical size when available, offline need, and exact owner action. A generic Move to Trash must not be the default for a provider-managed path: [Dropbox user report](https://www.reddit.com/r/dropbox/comments/1ttyksf/tech_help_files_labeled_online_only_still_taking/), [iCloud local-space report](https://www.reddit.com/r/iCloud/comments/le03jo), [Dropbox online-only guide](https://help.dropbox.com/sync/make-files-online-only), and [Google Drive stream or mirror guide](https://support.google.com/drive/answer/13401938?hl=en).
- **Backup and virtual-disk rescue crosses ownership boundaries.** Time Machine users distinguish local snapshots, backup destinations, old Mac identities, and restore history. VM users distinguish host file size, guest partition state, running memory or swap, snapshots, and the owner app's reclaim operation. Docker, Parallels, and UTM documentation all put cleanup behind owner controls or preconditions such as stopping the owner, backing up, trimming, or checking guest state. Tessera should classify these as recovery objects, not generic large files, and show the restore target, owner state, guest state, logical and physical size, backup-copy status, and owner action. It should offer a handoff or narrow source-aware action, never a default Trash move: [Time Machine old-Mac report](https://www.reddit.com/r/MacOS/comments/1kmddd8/how_to_delete_old_macs_time_machine_backup/), [Parallels deleted-VM report](https://www.reddit.com/r/mac/comments/lvspv8/macbook-air-m1-recover-free-space/), [VMware host-guest size report](https://www.reddit.com/r/vmware/comments/rg81wm/increasing_disk_size/), [Docker Mac FAQ](https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/), and [Parallels snapshots guide](https://kb.parallels.com/en/5691).
- **Market claims now converge on the same controls.** StorageRadar and DiskSpace advertise preview-first workflows, exact paths, dry runs, short undo, rescans, hard-link handling, and local processing. DrDisk adds scheduled cleanup and history. These claims match observed needs, but they remain market signals until user reports or local tests confirm them: [StorageRadar](https://apps.apple.com/us/app/storageradar-disk-space/id6759776887?mt=12), [DiskSpace](https://apps.apple.com/us/app/diskspace-cleaner-analyzer/id6759896440?mt=12), [DrDisk](https://apps.apple.com/us/app/drdisk/id6771003365?mt=12).
- **A rescue case must survive interruption.** One user finds a native cleanup surface during a full-disk warning, removes one obsolete file, closes the window, and cannot find the same review surface again. A separate cleanup-tool discussion asks for original paths, a per-run Trash summary, one-click undo, and an exportable log. This is not the same as recurring growth: recurrence is about the cause returning, while continuity is about the user losing the current case before they finish it: [native cleanup discovery report](https://www.reddit.com/r/MacOS/comments/1esh1ip/apples_own_disk_storage_cleanup_app_where_did_it/), [review-first cleanup discussion](https://www.reddit.com/r/MacOSApps/comments/1sews1e/i_built_a_mac_cleanup_app_for_people_who_want_to/).
- **The finish line is a temporary space budget.** Update and install reports show that the user may need space for an installer, an unpacked copy, a build, or a failed download. The visible free number can look large while the transaction still fails. Tessera should ask for the immediate goal, estimate the working-space buffer, and rank candidates by usable space now. It should not promise that recovering exactly the requested file size will complete the operation: [App Store install-space report](https://www.reddit.com/r/MacOS/comments/19egnz1/app_store_there_is_not_enough_disk_space/), [MacBook Air update-space report](https://discussions.apple.com/thread/256326703), and [macOS update blocked by System Storage](https://www.reddit.com/r/MacOS/comments/1sekndr/mac-unusable-due-to-system-storage/).
- **The displayed number is part of the failure.** A user can move or delete data and still see Disk Utility and Storage Settings disagree. Other users report that a large displayed free value does not satisfy an update or install. Tessera should name the measurement source, separate immediately free space from potentially reclaimable space, and state when the transaction target remains unproven: [Disk Utility versus Storage Settings](https://www.reddit.com/r/MacOS/comments/1qe6umz/why_is_the_available_space_in_disk_utility_and/), [Monterey update-space report](https://discussions.apple.com/thread/253869188), and [M1 upgrade-space report](https://discussions.apple.com/thread/256240026).
- **Some users prefer a narrow tool over a powerful one.** A long-time Mac user describes moving from cleaners to manual exact-path cleanup because they do not want hidden background activity or unclear deletion. Product makers make the same tradeoff in reverse by exposing allowlists, read-only analysis, risk labels, and dry runs. Tessera should make the narrow path fast and inspectable, not force every user into broad automation: [manual-maintenance discussion](https://www.reddit.com/r/MacOS/comments/1gwbeag/after-years-of-cleanup-apps/), [Purge launch](https://www.reddit.com/r/macapps/comments/1unih9f/os_purge_a_small_free_opensource_mac_cache/), and [StorageRadar launch](https://www.reddit.com/r/macapps/comments/1rmfq2h/macos_i_built_a_mac_storage_tool_for_people_who/).
- **A full disk can block the recovery path itself.** The update and reinstall reports describe a user who cannot download, expand, back up, or create a bootable installer once space is tight. Some replies jump to erase and reinstall while others point to snapshots, cloud caches, or an owner app. Tessera needs a recovery escalation state that explains what it cannot safely change and preserves the case for later, rather than escalating pressure into a raw delete: [full-storage recovery report](https://discussions.apple.com/thread/256247093), [snapshot and update report](https://discussions.apple.com/thread/254195248), and [device-backup update report](https://discussions.apple.com/thread/7640010).

This product pass adds the continuity and temporary-budget patterns, plus the creator-cache, cloud-provider, and backup or virtual-disk patterns. The rescue-continuity pass strengthens patterns 3, 8, 11, 15, 19, 24, and 25. The rescue-failure-retry pass strengthens patterns 3, 7, 8, 13, 16, 18, 19, 20, 24, and 25. The developer-creator-state pass strengthens patterns 2, 3, 4, 6, 8, 12, 16, 17, 18, 20, 21, 23, 24, and 25. The safety API lane adds pattern 33 about scan expiry and the communication probe adds pattern 34 about compound owner state. It adds a product rule: **a permission request, a cleanup action, and its result each need their own visible explanation**. A scan that cannot explain its access is not ready to recommend a move. A full disk also needs an escalation state for cases where the next safe step is backup, owner-app recovery, or a later retry. A working set must be modeled as a compound transaction rather than a folder list: source or project state, generated output, owner cache, recovery identity, and temporary working room can all affect the safe action. The owner-context coverage pass adds separate local-materialization, provider-state, and recovery-identity boundaries. The pattern map now has 34 patterns; the automated GitHub candidates remain a source queue until manually coded.

### Coverage and saturation audit

The independent developer-creator, creator-working-set, AI-model, professional-library, local-AI, game-library, package-cache, app-profile, safety API, and communication lanes change the shape of the study again. The 57 evidence and authority ledger inputs contain 8,477 records before the separate 77-record market scan. That is 3,005 non-automated user or issue evidence records, 5,005 automated GitHub candidates, 30 first-party system facts, 426 owner or tool facts, and 11 product or maker market signals inside the evidence and authority inputs. The separate GitHub market scan adds 77 repository records, giving 8,554 unique records across all 58 corpus inputs. This is a strong baseline, not a stopping point.

The coverage is broad but not balanced. The counts below are tagged-record counts, not people, usage rates, or prevalence estimates. One record can have more than one tag.

| Evidence tag | Tagged records | Cross-lane coverage | What is still weak |
| --- | ---: | --- | --- |
| Space accounting | 1,098 | Ask Different, GitHub issues, Apple Support Communities, MacRumors, Reddit, App Store, Apple Support, owner docs, developer lane | Direct observation of the same machine before and after a cleanup |
| Cloud or sync | 129 | GitHub issues, Apple Support Communities, Reddit, Apple Developer, owner docs, developer lane | App-specific state and offline needs across more providers |
| Cloud or backup | 608 | Ask Different, GitHub issues, community pages, Reddit, system facts, owner docs | Separate remote, local, backup, and restore identity before any action |
| Live state | 107 | GitHub issues, Apple Support Communities, MacRumors, Reddit, Apple Developer, owner docs, developer lane | Reliable owner-process and open-handle evidence in the user-facing flow |
| Permission boundary | 106 | GitHub issues, community pages, Reddit, Apple Support, and developer lane | More direct reports about consent, refusal, and recovery after access changes |
| Owner context | 108 | Apple Support Communities, Reddit, Apple Support, Apple Developer, owner docs, developer lane | Clearer creator, backup, cloud, developer, and virtual-disk cases |
| Local copy | 52 | Apple Support Communities, Reddit, Apple Developer, owner docs, developer lane | Clear status language for materialized, dataless, pending, and local-only data |
| Backup | 65 | Ask Different, Reddit, Apple Support, owner docs, developer lane | Restore target, device identity, verified copy, retention, and owner-managed deletion |
| Virtual disk | 32 | Reddit, owner docs, GitHub issues, and developer lane | Host versus guest state, sparse size, snapshots, active runtime, and safe reclaim |
| Creator data | 65 | Reddit, owner documentation, and developer lane | Project-linked caches, generated media, external scratch volumes, and rebuild cost |
| Developer data | 208 | Ask Different, GitHub issues, Reddit, Apple Developer, owner docs, and developer lane | Xcode, Docker, package, build, VM, and project state need owner-specific actions |
| Generated media | 26 | Reddit, owner documentation, and developer lane | Exact class, project scope, active state, and external-media impact |
| Project state | 33 | Reddit, GitHub issues, owner documentation, and developer lane | A source or project can remain valuable even when generated outputs are disposable |
| Rebuild cost | 39 | GitHub issues, Reddit, owner documentation, and developer lane | Rank by time and working-space impact. Byte size is incomplete. |
| Verification | 149 | Ask Different, GitHub issues, community pages, Reddit, owner docs, and developer lane | Prove the move, measurement, restore path, or owner action before calling it done |
| Workflow friction | 477 | Ask Different, GitHub issues, community pages, Reddit, owner docs, and developer lane | Keep rescue review short, resumable, and usable when the disk is already full |
| Uncertainty | 119 | Ask Different, community pages, Reddit, owner docs, and developer lane | Provider state, restore identity, guest state, remote-delete meaning, and delayed accounting |

The gap is not more generic System Data questions. The next useful sources are direct reports that show an owner app, a local-versus-remote state, an active process, a project or backup recovery decision, or a recurrence boundary. Search-result counts and product rating totals cannot fill that gap.

### System-facts lane

The first-party documents set hard boundaries for the implementation:

| Platform fact | Tessera consequence |
| --- | --- |
| Apple calls System Data a catch-all and says its contents are managed by macOS: [Storage guide](https://support.apple.com/en-us/102624), [Storage categories](https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac) | Do not offer System Data as a folder to delete. Explain the measured tree and its limits. |
| Free space and available space are different, and purgeable data can count as available: [Storage categories](https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac) | Label every number and report the measurement source. |
| Moving to Trash is not the same as freeing space: [Storage guide](https://support.apple.com/en-us/102624), [Delete files](https://support.apple.com/en-ie/guide/mac-help/mchlp1093/mac) | Keep Move to Trash and Empty Trash as separate actions and results. |
| Time Machine and APFS snapshots are read-only, time-based states with their own lifecycle and metadata: [Time Machine snapshots](https://support.apple.com/en-us/102154), [APFS snapshots](https://support.apple.com/en-mide/guide/disk-utility/dskuf82354dc/mac) | Show snapshot evidence as a protected system case, not as an ordinary file candidate. |
| macOS separates Files & Folders from Full Disk Access: [Privacy settings](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/26/mac), [Files and folders](https://support.apple.com/en-mide/guide/mac-help/mchld5a35146/mac) | Explain scope before consent and show incomplete coverage after refusal or revocation. |
| File Provider can keep dataless and materialized copies, track domains, and sync Trash: [File Provider](https://developer.apple.com/documentation/fileprovider), [Syncing](https://developer.apple.com/documentation/FileProvider/synchronizing-the-file-provider-extension), [Trash support](https://developer.apple.com/documentation/fileprovider/nsfileproviderdomain/supportssyncingtrash) | Do not treat a remote-backed path as ordinary local junk. Name the owner and state, then hand off or use a source-aware action. |
| Foundation can move an item to Trash, return its resulting URL, and coordinate changes with file presenters: [trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashItem%28at%3Aresultingitemurl%3A%29), [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) | Record the resulting path, use coordinated operations where applicable, and surface coordination failure. |
| Foundation exposes separate resource, file, content, volume, logical-size, allocated-size, and capacity values. File identifiers are not stable across every file system or mount: [URLResourceKey](https://developer.apple.com/documentation/foundation/urlresourcekey), [fileIdentifierKey](https://developer.apple.com/documentation/foundation/urlresourcekey/fileidentifierkey), [capacity](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity) | Capture a short-lived identity set and a named capacity source. Re-read it before staging and action. Never call logical size equal to verified reclaim. |
| `runningApplications` is broader than launch notifications, and file presenters do not receive every low-level write: [runningApplications](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications), [launch notification](https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification), [NSFilePresenter](https://developer.apple.com/documentation/foundation/nsfilepresenter) | Combine application inventory, helper-process and open-handle checks, and owner coordination. A missing notification or coordinator callback is not proof of an idle owner. |
| FSEvents can coalesce directory changes and needs a rescan of changed paths: [File System Events](https://developer.apple.com/documentation/coreservices/file_system_events), [FSEvents programming guide](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html) | Invalidate a saved scan when a watched directory changes. Rescan before review or action; the event says that something changed, not what is safe. |

The owner-documentation lane adds product-specific facts:

| Owner fact | Tessera consequence |
| --- | --- |
| Resolve can delete unused, all, or selected render cache and regenerate it, but its cache location is configurable: [Resolve guide](https://documents.blackmagicdesign.com/UserManuals/DaVinci-Resolve-17-Colorist-Guide.pdf) | Identify the project and cache class, show rebuild cost, and prefer the Resolve action or a handoff. |
| Premiere separates unused cache from all cache and requires projects to be closed for the broad action: [Premiere clear-cache guide](https://helpx.adobe.com/premiere/desktop/troubleshooting/media-issues/clear-media-cache-using-preferences.html) | Respect owner-app preconditions and never translate a broad owner action into a path-only delete. |
| Final Cut Pro scopes generated-file deletion to clips, projects, events, or libraries, and some commands also affect external media: [Final Cut Pro generated-media guide](https://support.apple.com/en-gb/guide/final-cut-pro/verb8e5f6fd/12.3/mac/15.6) | Show scope and external-media impact before staging. Keep original media protected. |
| Dropbox separates online-only placeholders from available-offline files, exposes a hard-drive-space tool, and warns that deleting an online-only item deletes it everywhere: [Dropbox online-only guide](https://help.dropbox.com/sync/make-files-online-only) | Detect the provider and offer Move to online-only as an eviction action. Never map a provider delete to generic Trash. Show logical and physical size when they differ. |
| OneDrive separates online-only, locally available, and always-available states. Free up space changes the local state, while deleting the item changes OneDrive across devices: [OneDrive Files On-Demand guide](https://support.microsoft.com/en-US/onedrive/save-disk-space-with-onedrive-files-on-demand-for-mac) | Show the state icon, provider action, offline consequence, and remote-delete meaning. Re-check the state after the action. |
| Google Drive separates streaming from mirroring, keeps streamed data in a local cache, and requires completed sync before a mode change or mirrored-folder removal: [Google Drive stream or mirror guide](https://support.google.com/drive/answer/13401938?hl=en) | Treat cache, mirrored folders, and streamed virtual files as different candidates. Require sync completion and use Google Drive as the owner handoff. |
| iCloud Drive exposes status indicators and Remove Download for releasing a local download while keeping the iCloud Drive item: [Apple iCloud Drive guide](https://support.apple.com/en-ie/guide/mac-help/mchl1a02d711/mac) | Prefer Remove Download or an Apple handoff when the user wants local relief. Keep personal iCloud data out of generic safe staging. |
| Apple manages local device backups through Finder's Manage Backups control, where a backup can be deleted, archived, or revealed: [Apple device backup guide](https://support.apple.com/en-us/108809) | Identify the device and restore role. Offer the owner action or a review handoff, never a generic path delete. |
| Time Machine keeps versioned history and automatically removes older backups when the destination is full, but its purpose is restore: [Apple Time Machine guide](https://support.apple.com/en-us/104984) | Show destination identity, history span, and restore risk. Treat old or foreign-device backups as an owner-managed decision. |
| Docker keeps containers and images inside an owner-managed disk image and separates prune scopes; changing its maximum size can delete the image: [Docker Mac FAQ](https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/), [Docker prune guide](https://docs.docker.com/engine/manage-resources/pruning/) | Show logical and physical size, running state, owner scope, and Docker's exact prune or settings action. Do not stage Docker.raw. |
| UTM requires a stopped guest and backup before its experimental reclaim or compression path, and attached drive deletion can delete data: [UTM resize guide](https://docs.getutm.app/settings-qemu/drive/resize-and-compress/), [UTM drive guide](https://docs.getutm.app/settings-apple/drive/) | Require owner handoff, backup proof, guest shutdown, and explicit drive identity before any source-aware reclaim. |
| Parallels manages snapshots, reclaim, archive, and guest storage as separate operations. Snapshots can block resize or compression, and reclaim must not be interrupted: [Parallels snapshots guide](https://kb.parallels.com/en/5691), [Parallels free-space guide](https://kb.parallels.com/br/123553) | Show VM owner, snapshot chain, host and guest state, backup status, and exact owner action. Keep VM bundles protected from generic Trash. |

### New pattern from the coverage pass

**20. Local materialization is a separate decision from deletion.** Users ask how to keep iCloud or Photos available without keeping every byte local. Developers find a Docker disk image and cannot tell whether its apparent size is logical or physical. Backup owners have copied data elsewhere but still fear losing the restore path. Apple documents that File Provider can hold dataless or materialized copies and may synchronize Trash. The product implication is a new classification: **source-managed local copy**. Tessera should show local state, owner, sync status, and recovery path, then offer a source-aware action or handoff. It should not move the path to Trash just because the remote source exists. Confidence: **medium-high**. Counterexamples include offline work, pending sync, Photos repair, and a local backup that is the only verified restore copy.

**21. Creator caches are project-linked working state, not generic junk.** Resolve, Final Cut Pro, Lightroom, and Blender reports describe generated media, render files, analysis files, or caches that can exceed source media, refill during active work, or live on an unexpected volume. First-party owner guides confirm that some generated media is rebuildable, but also define project, library, cache-location, and external-media scope. The product implication is a creator candidate with **project owner, generated-media class, cache location, active state, last-used signal, retention policy, rebuild cost, and source action**. Tessera should recommend a scoped owner-app purge or handoff, and show prevention controls such as a time or size guard where the owner supports them. It should not stage a whole library or package because its name resembles a cache. Confidence: **medium-high**. Counterexamples include an active render, required optimized or proxy media, an analysis file still needed for an open project, a cache on an external scratch volume, and an owner app whose installed version has different cleanup semantics.

**22. Provider state is a contract, not a size label.** Dropbox, OneDrive, Google Drive, and iCloud describe different local states and different meanings for an action. Direct reports add stale labels, hidden provider caches, logical-versus-physical confusion, delayed optimization, and fear of remote deletion. The product implication is a provider-aware candidate with **provider, sync state, logical size, physical size, offline need, action scope, and remote-delete semantics**. Tessera should offer the provider's eviction or handoff action only after checking current state and completed sync. It must not treat an online-only marker or a remote copy as proof that local bytes are gone or that generic deletion is safe. Confidence: **medium-high**. Counterexamples include provider-version changes, pending sync, offline work, files outside the provider root, and a local cache that is needed for unsynced edits.

**23. Recovery objects have identity and lifecycle.** Time Machine and device-backup users distinguish a current restore point from an old device's history, while VM users distinguish a host image from its guest volume, snapshots, runtime memory, and owner-managed reclaim path. Docker, Parallels, and UTM guides make the same boundary explicit: stopping the owner, backing up, checking snapshots or trim, and verifying the guest can be prerequisites. The product implication is a recovery-aware candidate with **recovery role, restore target, backup-copy status, last verified time, owner state, guest state, sparse or physical size, and owner action**. Tessera should classify these as protected or review-only, show host and guest measurements separately, and hand off to the owner app unless it can prove a narrow source-aware action. Confidence: **medium-high**. Counterexamples include a verified duplicate backup, an archived and unused VM, an owner UI that proves reclaimable blocks, and a stopped Docker image with separately backed-up volumes. Direct reports still conflict on safe Time Machine deletion, so forum commands remain untrusted evidence: [old Mac backup report](https://www.reddit.com/r/MacOS/comments/1kmddd8/how_to_delete_old_macs_time_machine_backup/), [Time Machine identity report](https://www.reddit.com/r/MacOS/comments/12m5zmh/doesnt_time_machine_automatically_clear_up_old/), [deleted VM report](https://www.reddit.com/r/mac/comments/lvspv8/macbook-air-m1-recover-free-space/), [Parallels resize report](https://www.reddit.com/r/mac/comments/rnnbc1/m1_macbook_pro_14_parallels_windows_11_hdd/), and [UTM reclaim guide](https://docs.getutm.app/settings-qemu/drive/resize-and-compress/).

## What people actually do

### The trigger is urgent and concrete

The common opening is "I need space now," often for an OS update or a new install. The user sees a red or nearly full storage indicator, opens Storage settings, and finds a large System Data bucket that does not tell them what to do. A recent low-space thread includes a user who says they need roughly 11 GB for an update and does not know what to remove: [MacBook Air low-space thread](https://www.reddit.com/r/MacOS/comments/1v5h166/macbook_air_m1_2020_256gb/).

GrandPerspective reviews show the same episodic pattern: people open a visual tool when a disk is almost full, then use the map to understand where the space went: [GrandPerspective reviews](https://apps.apple.com/us/app/grandperspective/id1111570163?mt=12&platform=mac&see-all=reviews).

This is a rescue job. Exploration is useful only after the immediate risk is under control.

### They look for a second opinion before they delete

Users often find a large folder, then stop. A cleanup discussion describes DaisyDisk as useful for locating files, but says the user still has to search the web to learn whether a file is safe. The author calls an AI explanation a "game changer": [DaisyDisk cleanup discussion](https://www.reddit.com/r/mac/comments/1348mv5/disk_cleanup_apps_to_use_and_which_to_avoid/).

The repeated question in System Data threads is some form of "can I delete this?" A long-running help thread includes people asking about caches, Application Support, Messages, iPhone backups, and files that Finder does not expose clearly: [System Data help thread](https://www.reddit.com/r/MacOS/comments/154rp99/how_to_do_i_clear_system_data_on_mac_os/).

The missing feature is a confidence explanation, not another folder visualizer.

The new developer and creator reports add an important detail: the user is often managing a **compound working set**, not one large folder. Source media or project state, generated output, owner cache, virtual-disk or backup state, and temporary room for the next update or export can all be part of the same urgent job. Moving the project to an external volume does not prove that the internal disk is safe to empty. Tessera must ask what the user is trying to finish, then show which candidate changes the working budget and which owner action is needed.

### They mix safe candidates with high-value data

The large item is often technically disposable but operationally important:

- Xcode runtimes, Device Support, DerivedData, archives, and simulator data.
- Docker's virtual disk, which may look large or sparse and needs Docker-aware handling.
- iPhone backups, which may be the only local restore point.
- iCloud or OneDrive local mirrors, which can refill or remain in a sync loop.
- App containers and Application Support, which may contain both cache and real local state.
- Video intermediates, render caches, downloaded media, and project files.

The Xcode discussion is useful because it separates the size problem from the safety problem: deleting runtimes or DerivedData may be acceptable, while simulator data can contain app state and archives may be needed for release work: [Xcode storage discussion](https://www.reddit.com/r/Xcode/comments/1ry2tnx/xcode_was_quietly_using_60gb_on_my_mac_this_is/).

Developer discussions show the same need for source-aware handling across Docker, Xcode, node modules, and Homebrew: [Docker storage discussion](https://www.reddit.com/r/mac/comments/1s2qj9e/psa-to-my-mac-devs-stop-docker-from-eating-your/).

### They try several tools and commands, then lose the thread

The public advice chain is usually:

1. Open System Settings and inspect the broad categories.
2. Search the web for System Data.
3. Install a visual disk tool.
4. Look inside ~/Library, caches, app containers, or developer folders.
5. Run a command or cleanup tool recommended by a stranger.
6. Empty Trash or restart.
7. Check storage again and become confused if the number did not move.

The guide at [Where's my disk space?](https://www.reddit.com/r/mac/comments/1c3ldoi/wheres_my_disk_space_what_is_taking_up_all_the/) documents the manual approach and the frustration caused by rough category totals. The thread also shows that users can find very large Outlook, iPhone, app, or media data but do not know which owner is safe to challenge.

This is a cognitive load problem. Users can perform the steps. They do not want to assemble the diagnosis themselves.

### They interpret "no free space" as a failed cleanup

Apple explains that moving an item to Trash does not free the storage until Trash is emptied: [Apple storage guidance](https://support.apple.com/en-us/102624). Users still report "I deleted 40 GB and nothing changed," especially when an open application, APFS snapshot, cloud sync process, or accounting delay holds the blocks: [Trash and snapshot discussion](https://www.reddit.com/r/MacOS/comments/160yq8o/deleting_and_emptying_trash_doesnt_free_up_space/).

The result is a broken mental model:

selected size -> "space should be free now" -> storage number unchanged -> "the tool lied"

Tessera must show the intermediate states. A successful Trash move is not the same as immediate available-space recovery.

### They return when the cause returns

Some users report that System Data grows again within a week after a cache clean. One asks whether to automate a nightly cleanup: [recurring System Data thread](https://www.reddit.com/r/MacOS/comments/1rj6xp9/system_data_is_expanded_to_over_half_of_storage/). Other reports describe a restart temporarily releasing tens of gigabytes, or a sync process filling the disk again: [Mac mini recurring-growth thread](https://www.reddit.com/r/macmini/comments/1u6bk4f/system_data_is_eating_up_my_storage/).

The useful intervention is root-cause memory, not nightly deletion. Tessera should remember that a user dismissed or approved a category, and it should explain when that category grows again. It should not erase on a schedule without a new review.

## Pattern synthesis

| Pattern | Evidence across sources | Interpretation | Tessera implication | Confidence |
| --- | --- | --- | --- | --- |
| 1. Full-disk work is a rescue job | Update/install stories, App Store reviews, Ammar's own abandonment of manual cleanup | The user has a goal and a time limit | Make Rescue the first path and show "space to recover" plus the next safe action | High |
| 2. Uncertainty is the main blocker | "Can I delete this?" appears across System Data, Application Support, Xcode, and backup threads | Discovery without interpretation leaves the risky decision to the user | Every candidate needs a plain reason, owner, path, side effect, and confidence | High |
| 3. System Data is both a label problem and an accounting problem | Apple describes it as a catch-all; users see totals shift after deletion, sync, restart, or snapshots | One number cannot explain physical storage state | Show Tessera's own measured tree and explain category mismatch, Trash, snapshots, sparse files, and delayed accounting | High |
| 4. Safety depends on context | Caches may be rebuildable; app containers may contain state; simulator data and backups may matter; Docker needs its owner app | A universal "junk" label is unsafe | Use risk tiers and source-aware rules. Unknown ownership never becomes safe by size alone | High |
| 5. Users want bounded automation | CleanMyMac users like a single flow, while other users distrust blind cleaners, subscriptions, or background helpers | Convenience is welcome when the boundary is visible | Preselect only high-confidence items. Keep review, exact paths, and one explicit commit action | High |
| 6. One scan must cover specialist pockets or explain the handoff | Xcode, Docker, Adobe, cloud sync, phone backups, and app leftovers recur in separate discussions | Generic folder analysis misses meaning | Add analyzers with an owner and a safe next action. When Tessera cannot act, say which app or system setting owns the fix | High |
| 7. Recovery is part of the feature | Apple Trash guidance, backup anxiety, and cautious App Store reviews | Users judge safety by how reversible the action feels | Trash first. Permanent deletion and Empty Trash stay separate, explicit, and exact | High |
| 8. Verification closes the trust loop | Reports of no space change after deletion, open Compressor handles, snapshots, and sync delays | A completion toast without a new measurement feels false | Re-scan exact candidates and volume state. Report requested, moved, reclaimed, held, and remaining | High |
| 9. Repeated growth needs explanation | Weekly regrowth reports and requests for automation | The user wants prevention, but may over-automate the symptom | Offer local threshold reminders and trend evidence. Never silently run cleanup in v1 | Medium-high |
| 10. Privacy and business model affect trust | DaisyDisk's local/no-telemetry position, subscription distrust, background-service concerns, and open-source cleaner interest | Storage inspection exposes personal filenames and habits | Keep scanning local, state the boundary, avoid telemetry and always-on helpers, and make licensing language quiet | Medium-high |
| 11. A ranked plan beats a tool drawer | Users bounce between Finder, Terminal, settings, and several utilities | The app should coordinate decisions, not expose six unrelated utilities | Rank by urgency, reclaim, confidence, and effort. Use tools as evidence sources inside the plan | Medium-high |
| 12. Safe must include the cost of rebuilding | DevCleaner reviews praise quick review, while developer reports note that cleanup can cause later downloads or rebuilds | Safe does not mean consequence-free | Show "you may need to download or rebuild this again" beside the reclaim number | Medium-high |
| 13. Permission boundaries change the diagnosis | Root-owned temp data can look like empty space to an unprivileged scanner; File Provider data can sit inside System Data | An incomplete scan can create false confidence | Show scan coverage, offer an explicit deep scan, and say what Tessera could not inspect | High |
| 14. Provenance makes automation easier to trust | New open-source cleaners expose named rules, protected roots, allowlists, and audit logs | Users need to inspect why a rule exists and what it cannot touch | Give every recommendation a rule ID, version, owner, and protected-path result | Medium-high |
| 15. Safe cleanup needs brakes | Trust-first tools use previews, explicit apply steps, Trash, logs, and batch limits | A large batch magnifies a classification mistake | Cap or split large actions and ask again when the scope changes | Medium-high |
| 16. Live state can turn cleanup into a disk emergency | Mole reports deleting an open SQLite cache caused a running helper to write hidden unlinked files until the volume filled; other issues mention locks, databases, and active apps | A path-only rule can create a new failure while trying to solve the old one | Check open handles, owner processes, locks, and post-action writers. Re-measure the volume after each batch | High |
| 17. Reversibility does not prove that data is disposable | ClearDisk reports local session loss; DVC requests distinguish pushed data from the only local copy; Mole requests backup before uninstall | Trash protects the path, but not the user's ability to recreate or recover the content | Show whether an item is a cache, source, local-only state, or owner-managed store. Require a stronger boundary for local-only data | High |
| 18. Ownership needs a visible handoff | Nextcloud File Provider temp chunks, iCloud metadata damage, app-owned stores, and custom project roots all depend on another app or workflow | Generic deletion cannot know the meaning of every folder | Attach an owner, last-known state, and next action. Prefer owner commands or a manual handoff when Tessera cannot prove safety | High |
| 19. A failed or partial action needs its own explanation | Issue reports describe EPERM, timeouts, stale items, wrong sizes, and failed deletes that remain in the UI | A single success or failure total hides what happened and makes the next decision harder | Keep requested, moved, failed, held, and verified space as separate states. Preserve exact paths and reasons | High |
| 20. Local materialization is not deletion | iCloud, Photos, Docker, and backup reports distinguish a remote copy, a local materialized copy, a sparse image, and the only verified restore copy. Apple documents dataless and materialized File Provider items and syncing Trash | A remote source does not prove that a local path can leave. Offline use, pending sync, and owner-app state change the decision | Show owner, local state, sync status, logical versus physical size, and recovery path. Use a source-aware action or handoff instead of generic Trash | Medium-high |
| 21. Creator caches are project-linked working state | Resolve, Final Cut Pro, Lightroom, and Blender users report generated media or caches larger than source media, recurrence during active work, and uncertainty about what a purge changes. Owner guides expose scoped deletion and regeneration rules | A cache path has project scope, active state, and rebuild cost. Whole-package deletion can remove needed media or break the workflow | Show project or library, generated-media class, cache location, active writer, rebuild cost, retention policy, and owner-app action. Hold active work and keep source media protected | Medium-high |
| 22. Provider state is a contract, not a size label | Dropbox and iCloud or Photos users report stale online-only or optimization state, hidden provider caches, and fear of remote deletion. Dropbox, OneDrive, Google Drive, and iCloud guides define different local states and actions | The same path can mean placeholder, local materialization, cache, mirror, or remote-owned data. A generic delete can have remote consequences | Show provider, sync state, logical and physical size, offline need, action scope, and remote-delete semantics. Prefer provider eviction or handoff and verify the post-action state | Medium-high |
| 23. Recovery objects have identity and lifecycle | Time Machine, device-backup, Docker, Parallels, UTM, and VMware reports distinguish restore history, host images, guest volumes, snapshots, and live runtime state | Old or large does not mean disposable. A recovery object can be the only verified copy or an active environment | Show recovery role, restore target, backup-copy status, owner and guest state, logical and physical size, and the owner action. Keep generic Trash unavailable | Medium-high |
| 24. The finish line is a temporary space budget | Update and install reports show that the user needs room for an installer, unpacked files, a build, or a failed download. One candidate's size does not describe this budget. | Recovering the requested file size may still leave the transaction unable to finish | Ask for the immediate goal, estimate a working-space buffer, rank by usable space now, and report whether the target was reached | High |
| 25. A rescue case must survive interruption | A native cleanup surface disappears after the user closes it. Product discussions ask for original paths, per-run summaries, undo, export, and resumable review | A one-shot scan makes the user reconstruct the diagnosis and may cause repeated unsafe exploration | Save the local case, scan coverage, selections, pending action, and result. Let the user resume or discard it. Never turn resumption into silent deletion | Medium-high |
| 26. Relocation creates an owned dependency | Logic and Ableton reports show libraries moved externally but later missing, duplicated, rejected, or redownloaded. Owner guides require supported locations, mounted volumes, project consolidation, permissions, and working space | A successful copy is not a complete relocation. The owner must recognize the destination, the volume must stay available, and the next transaction may still use the system disk | Show source and destination volumes, owner-recognized active location, transaction-phase space, availability and performance cost, and a functional open test before the old copy becomes reviewable | High |
| 27. AI-model storage is a reference graph | Ollama manifests and shared blobs, Hugging Face revisions and content-addressed blobs, LM Studio links, and ComfyUI or AUTOMATIC1111 shared roots make several logical models point to the same physical bytes. Partial transfers can sit outside owner inventory | Summing model paths overstates reclaim, while deleting one shared target can break several apps. Installed, loaded, referenced, partial, and historical are different use states | Build an owner-aware reference graph. Show logical, physical, shared, independently reclaimable, and working-space bytes; require owner inventory, loaded-state checks, dry run, and a real load test | High |
| 28. A professional library is a compound installed object | Native Access, Spitfire App, Arturia Software Center, Toontrack Product Manager, Opus, UVI Portal, IK Product Manager, and Steinberg Library Manager separate packages, content, plug-ins, owner metadata, licenses, updates, and host indexes. User reports show that one layer can work while another remains missing | Two folders with similar bytes can be different transaction stages. A copy can be physically complete but unusable, and a downloaded installer can be safely replaceable only after the working library is verified | Identify storage role, owner registration, device license, update target, and host visibility. Never merge package cleanup, content relocation, owner repair, and product removal into one action | High |
| 29. User-created AI state outranks downloaded weight by recovery value | MLX-LM ties a fine-tune to local data, adapters, checkpoints, and a base. Draw Things users report trained LoRAs without a working export. DiffusionBee separates history metadata from image files. llama.cpp prompt and slot state can be expensive or impossible to reproduce exactly | A small adapter, dataset, checkpoint, project, or generated output can hold the only useful work. A much larger fused, quantized, cached, or downloaded object can be replaceable, or can fail to reproduce the source behavior | Classify `user_created`, `derived_expensive`, `redownloadable_verified`, `runtime_active`, `partial_active`, and `unknown`. Protect user-created state by default and require load plus task proof before a derivative can replace its source | High |
| 30. Shared package storage is a dependency graph | npm, pnpm, Yarn, Cargo, CocoaPods, Conda, Gradle, Homebrew, SwiftPM, pip, and uv use different mixes of shared stores, project materializations, hardlinks or clones, environments, global tools, locks, configuration, credentials, and offline sources | Apparent size and reclaimable size can diverge. An owner cleanup can affect many projects, and a rebuild can fail offline or when a local dependency no longer exists | Show storage role, owner and version, configured roots, references, link topology, active locks, recovery source, offline need, exclusive reclaimable bytes, and owner dry-run result. Protect lockfiles, configuration, credentials, environments, and local source | High |
| 31. A game library splits payload from personal and compatibility state | Steam, Epic, GOG, itch.io, Minecraft launchers, Whisky, Heroic, PlayCover, and Battle.net separate game payloads from saves, worlds, screenshots, mods, cloud state, launcher records, patch staging, and compatibility containers | Removing one visible game folder can delete unique work or leave a launcher broken. A missing external volume can look stale while still holding the active library | Show launcher and game identity, payload versus save or mod state, cloud status, compatibility container, patch workspace, external-volume identity, and owner action. Require a real launch and save test before old bytes become reviewable | High |
| 32. An app profile is not a cache | Firefox, Chromium, Brave, Safari, VS Code, JetBrains, Zen, Slack, and Discord place exact caches beside sessions, bookmarks, passwords, cookies, offline data, extensions, drafts, local history, and workspace databases | A broad profile rule can erase identity, recovery, offline work, or an unsaved task while still appearing to target a cache | Classify exact subpaths and dependency groups. Show profile role, credential pairing, session recovery state, offline data, workspace state, owner action effect, and app-closed proof. Keep profiles and durable state out of safe cleanup | High |
| 33. A scan is a time-bound claim | Apple exposes separate identity, volume, owner, capacity, coordination, event, and cloud signals. FSEvents can coalesce changes, file presenters can miss low-level writes, launch notifications can miss background apps, and the local communication probe changed slightly across repeated reads while owners were active | A result can become stale while the user reviews it. A path match or one process signal cannot prove that the object and its owner state are unchanged | Store scan identity and coverage, invalidate on changes, rescan affected paths, and revalidate identity, owner, lock, sync, permission, and capacity immediately before staging and again before action | High |
| 34. Communication storage is compound owner state | Messages and Discord mix attachments or media with caches, sync state, databases, local storage, sessions, and drafts. Signal and Element reports add export, linked-device, backup, and encryption dependencies | A large attachment or cache can look disposable while the same root holds the only usable conversation or account recovery state | Keep communication roots protected until an owner adapter proves exact scope. Show attachment, cache, database, draft, session, credential, sync, offline, and remote-delete state, then hand off or use a coordinated owner action | Medium-high |

## Situational user segments

These are contexts, not fixed personas. One person can move between them in the same session.

| Context | Trigger | Main fear | What earns approval |
| --- | --- | --- | --- |
| Emergency rescuer | Update, install, export, or "Mac cannot work" warning | Wasting time or deleting the wrong thing | A short ranked plan, safe defaults, one confirmation, visible reclaimed space |
| Developer | Xcode, Docker, package managers, VMs, build outputs | Losing a project state or waiting hours to rebuild | Owner-aware categories, last-used evidence, rebuild cost, host and guest state, app-specific actions |
| Creator | Render intermediates, media caches, previews, libraries | Losing source media or an active project asset | File previews, project or library scope, generated-media class, rebuild cost, internal and external working-space impact, active-handle detection, exact paths |
| Render-heavy creator | A render, analysis pass, proxy build, or background task fills the disk during active work | Stopping the job, losing an in-progress result, or waiting for a full rebuild | Live-writer hold, owner-app pause or handoff, cache location, retention guard, and a small emergency plan |
| External-library creator | A sound, sample, asset, or project library no longer fits on the system disk | Breaking references, triggering a full redownload, losing a license or owner index, or slowing live work | Storage-role labels, owner-supported relocation, per-volume working-space budget, destination identity, registration and license checks, then standalone plus host or project tests before old bytes are reviewed |
| Local-AI builder | Models, revisions, checkpoints, adapters, datasets, projects, outputs, or partial downloads fill internal storage | Removing a shared blob, losing unique training state, trusting a broken derivative, or making a loaded workflow unavailable | Owner graph, recovery class, loaded and referenced state, exact revision and quantization, shared-byte accounting, resumable-transfer state, external-root availability, and load plus task proof before source review |
| Shared-store developer | Package stores, environments, and project dependencies consume space across many projects | Breaking offline builds, removing a global tool, or overstating reclaim because bytes are shared | Storage role, owner dry run, lock state, configured root, reference topology, exclusive reclaimable bytes, and a verified rebuild source |
| Game-library player or modder | A launcher library, modded instance, compatibility container, or external game volume fills the disk | Losing saves, worlds, mods, screenshots, cloud state, or launcher registration | Payload-versus-personal-state labels, volume identity, source-aware owner action, then a real launch and save test |
| Profile-heavy browser or IDE user | Browser, editor, or communication-app profiles become large | Losing sessions, passwords, drafts, extensions, offline data, local history, or workspace state | Exact subpath classification, credential and session dependencies, app-closed check, owner-action effect, and a restore manifest |
| Communication-heavy offline user | Messages, media, exports, or offline history consume local space | Losing conversation state, an attachment needed offline, an encryption key, or a pending sync | Protected root, exact attachment or cache role, active-writer hold, account and sync state, export or backup identity, and owner handoff |
| Cloud-heavy user | iCloud, OneDrive, Dropbox, Messages, Photos | Removing a local copy or triggering sync damage | Provider name, sync status, local-versus-cloud explanation, exact eviction action, and "manage in source app" handoff |
| Remote-library manager | Wants cloud or Photos access without a full local library | Losing offline access or confusing a synced copy with a remote-only item | Materialized or dataless state, logical and physical size, offline need, pending-sync warning, and recovery path |
| Sync-recovery user | An online-only label, storage number, or optimization result does not match local bytes | Deleting a remote item or making an unsynced change disappear | Provider-specific state, completed-sync check, local eviction versus delete language, and a measured post-action result |
| Virtual-disk operator | Docker, a VM, or a developer disk image grows during active work | Breaking containers, volumes, or an environment by deleting the image file | Logical and physical size, active-owner hold, owner-app cleanup, and a source-specific handoff |
| Backup-conscious user | iPhone backups, archives, snapshots | Losing the only recovery path | Backup age, device or app owner, restore target, verified copy, and explicit review state |
| Power user | Wants exact control and measurement | Tool hides or guesses too much | Full path, inode/link handling, exportable report, manual override |
| Capacity-constrained updater | An update, installer, backup, or recovery step fails despite an apparently large free-space value | Chasing the wrong number or making the next recovery step impossible | Measurement source, immediate goal, working-space buffer, and a named escalation path |
| Control-seeking minimalist | A periodic cleanup need or past cleaner experience makes broad automation feel risky | Background activity, unclear scope, or hidden deletion | Read-only analysis, exact paths, inspectable rules, Trash-first action, and a small review batch |

The rescue workflow should serve the first context in minutes, while exposing enough evidence for the other contexts when a candidate is ambiguous.

## Tessera baseline

Tessera already has the right safety primitives. The problem is that they are spread across tools instead of composed into a rescue plan.

### Existing strengths

- Tessera/Engine/CleanupSuggestions.swift classifies an already-built tree without performing I/O or deletion. It has a safeRegenerable tier and a review tier.
- The current rules cover Xcode data, node modules, package-manager caches, app caches, Adobe caches, browser caches, Trash, build output folders, logs, installers, and Downloads.
- Tessera/Engine/DeletionService.swift uses FileManager.trashItem for recoverable deletion and keeps permanent deletion as a separate API path that requires caller confirmation.
- Tessera/ViewModel/ScanViewModel.swift stages items in a collector, prevents ancestor and descendant double-counting, executes Trash or permanent deletion, and prunes only successful removals.
- Tessera/Views/CollectorDock.swift already says that items are not deleted until the user clicks Move to Trash. Permanent deletion is behind a separate overflow action.
- Tessera/Views/LargeOldFilesView.swift and FileSearchView.swift already provide useful evidence tools and stageable results.
- Tessera/Views/HiddenSpaceView.swift explains snapshots and protected files instead of treating all hidden space as junk.
- README.md states that scanning is local, there is no telemetry or file-related network call, and Full Disk Access is required for deeper inspection.

### Current friction to solve

DESIGN.md already records most of the observed friction:

- The Scan CTA is separated from the guidance that explains it.
- The sunburst is difficult to use as an accessibility surface.
- Cleanup suggestions disappear when the state is empty and have no clear loading model.
- The Cleanup List requires the user to discover stage/delete semantics.
- App Uninstaller says "Uninstall" even though the first step only stages items.
- Hidden Space and snapshot actions use terms that need more context.
- Large & Old, By Kind, and some search paths do synchronous work or recompute without enough progress feedback.

The study supports fixing the flow around these primitives before adding a broad set of new deletion rules.

The current read-only code audit is [tessera-disk-rescue-current-code-safety-audit-2026-08-31.md](./tessera-disk-rescue-current-code-safety-audit-2026-08-31.md). It found that `safeRegenerable` is still based on path and name rules, matched directories stop traversal, `node_modules` and top-level `Library/Caches` can be staged as broad units, staging does not re-check live state, and Trash execution uses stored URLs without a last-step identity or owner check. This is the implementation gap the new API and communication evidence now makes concrete. No new path rule should be added before the shared safety gate exists.

## Proposed product contract

### Recommendation object

Each rescue candidate should carry enough data to answer "what is this, why is it here, and what happens if I act?"

- Stable candidate ID.
- Human label and category.
- Exact path, with a Finder reveal action.
- Owning app or system service when known.
- Cloud or sync provider, domain, and current state when known.
- Logical size, estimated physical reclaim, and any hard-link or sparse-file caveat.
- Risk tier and confidence.
- Why Tessera found it.
- What returns after deletion: rebuild, re-download, re-index, or unknown.
- Last-used or last-modified evidence when meaningful.
- Active/open/sync state.
- Provider action scope, remote-delete semantics, and offline consequence when applicable.
- Proposed action: stage, review, hand off to owner, or block.
- Verification rule after the action.

### Risk tiers

| Tier | Meaning | Default |
| --- | --- | --- |
| Safe to rebuild | Known generated output or cache with a clear owner and low data-loss risk | Preselected |
| Review | App-managed or context-sensitive data. It may be useful, expensive to rebuild, or contain state | Visible, not preselected |
| Personal | Documents, media, backups, archives, project files, or user-created data | Visible only with strong context, never preselected |
| System-managed or blocked | Snapshots, protected paths, active files, unresolved sync state, or unknown ownership | Explain and hand off; no delete action |

"Safe" is a rule result, not a visual color. Size alone must never promote an item.

### Rescue sequence

1. **Start.** Open from a low-space warning, the empty state, or a visible Rescue action.
2. **Measure.** Scan the selected source with determinate progress and a live item count.
3. **Diagnose.** Explain the measured tree and the difference between logical size, available space, Trash, snapshots, and purgeable or sparse data.
4. **Rank.** Sort by urgent reclaim, confidence, effort, and likely side effect. Keep review candidates visible below safe candidates.
5. **Review.** Let the user select or deselect at category and exact-item level. Show a compact explanation first and deeper evidence on demand.
6. **Commit.** Use one clear Move to Trash action. The confirmation names the item count, total size, exact recovery boundary, and the fact that Trash still uses disk.
7. **Verify.** Re-measure the selected paths and available space. Check for open handles or known blockers where possible.
8. **Explain.** Show what moved, what was reclaimed, what is still held in Trash, and why any expected space did not appear.
9. **Remember.** Offer to remember the user's category-level choice or threshold preference. Never silently reuse a stale path decision.

### Recurrence and memory guardrails

The user selected "remember now," then chose a free-space threshold plus an optional schedule, a specific saved profile, a short reason with expandable proof, review-only owner handoff for unclear items, a separate Empty Trash step, and an optional preference-sync path for later. These are settled choices:

- Keep scanning, filenames, paths, trees, and file content local. Optional preference sync is future work, and its exact payload still needs its own review.
- Let a named profile remember user-approved category, owner, threshold, schedule, and dismissed-item rules. Revalidate every match against the current path and owner state.
- Record the choice, date, rule version, and an expiry or revalidation condition.
- Re-check the candidate before every later run. A remembered approval is not a deletion authorization.
- Show a small "using your saved profile" label with a reset action.
- Keep threshold and scheduled reminders disabled until the user enables them. A reminder can open a fresh review. It cannot clean in the background.
- Never run Move to Trash, Empty Trash, or permanent deletion from a reminder.

## What this rules out

- A single "clean everything" button with hidden defaults.
- Treating the System Data label as a list of files that can be deleted.
- Blind removal of all caches, Application Support, Containers, snapshots, or sync data.
- Automatically emptying Trash after a cleanup.
- Permanent deletion in the same confirmation as recoverable Trash movement.
- A visual sunburst as the whole solution.
- A background daemon that scans or cleans without a visible user action.
- Telemetry or cloud processing of filenames and storage trees.
- Calling a cleanup successful without measuring available-space change.
- Deleting a path only because its name resembles a cache or an app leftover.
- Treating a failed permission check, active process, or sync warning as an invisible implementation detail.

## Decision state

The canonical record is [tessera-disk-rescue-decision-ledger.json](./tessera-disk-rescue-decision-ledger.json). It records the original TempliLink slug, interaction ID, submitted time, and exact selected option IDs. This avoids reopening an answered form when the study moves to a new page slug.

### Settled rounds

| Round | Settled choices |
| --- | --- |
| 2. Memory and recurrence | Threshold plus optional schedule, a specific saved profile, compact expandable proof, review-only owner handoff, separate Empty Trash, and an optional preference-sync path for later |
| 3. Safety gates | Hard-hold active owners, archive or back up a possible only copy, and continue other items that still pass after one item fails verification |
| 4. Owner context | Owner handoff for remote-backed data, show local state and recovery path, and allow warned raw-path review for owner disk images |
| 5. Creator context | Source-aware purge, opt-in retention guard, and hard-hold active project state |
| 6. Cloud context | Source-aware eviction, provider-specific state, and logical plus physical size |
| 8. Goal and continuity | Ask for the immediate goal and buffer, then save a local resumable case |
| 9. Measurement and escalation | Name each measurement source, keep suggesting reviewed cleanup until the target is met, and start with narrow review |

### Current grilling frontier

Round 7 remains open for backups, snapshots, Docker images, and VM bundles:

1. Owner action only, or warned raw-path review when no safe owner action exists.
2. Require a verified recovery copy, or allow review with a missing-proof warning.
3. Show host plus guest or runtime state, or show the host file only.

Round 10 remains open for a failed cleanup, update, backup, sync, or owner action:

1. Pause and inspect, or retry the same plan.
2. Name the blocker and owner, or show one generic next step.
3. Do no background work, or allow an explicit local observer that the user can stop.

The recommended Round 7 choices are owner action or handoff, verified recovery proof, and host plus guest state. The recommended Round 10 choices are pause and inspect, name the blocker and owner, and no background work.

### Deferred Round 11

The old Round 11 form repeats settled choices about goal and buffer, active work, and source-aware owner handling. Its recovery-proof question depends on Round 7. Do not ask that form again. After Rounds 7 and 10 are settled, rewrite only the remaining owner-boundary question using the game-library, shared package-cache, and app-profile findings.

## Representative source ledger

The links below are representative. They are grouped by the behavior they help establish. Promotional product threads are marked as market signals, not core evidence.

### OS behavior and technical context

- [Apple: Free up storage space on Mac](https://support.apple.com/en-us/102624)
- [Apple: Find and delete files on your Mac](https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac)
- [Apple: Delete files and folders on Mac](https://support.apple.com/en-ie/guide/mac-help/mchlp1093/mac)
- [Apple: About Time Machine local snapshots](https://support.apple.com/en-us/102154)
- [Apple: View APFS snapshots in Disk Utility](https://support.apple.com/en-mide/guide/disk-utility/dskuf82354dc/mac)
- [Apple: Change Privacy and Security settings](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/26/mac/26)
- [Apple Developer: File Provider](https://developer.apple.com/documentation/fileprovider)
- [Apple Developer: Synchronizing the File Provider Extension](https://developer.apple.com/documentation/FileProvider/synchronizing-the-file-provider-extension)
- [Apple Developer: FileManager trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29?changes=_1)
- [Apple Developer: NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [DaisyDisk specifications and safety](https://web.daisydiskapp.com/specs/)
- [DaisyDisk user guide](https://daisydiskapp.com/guide/4/en/)
- [Ask Different: Is it safe to delete Library caches?](https://apple.stackexchange.com/questions/118941/is-it-safe-to-delete-library-caches)
- [Ask Different: Other data and cache cleanup](https://apple.stackexchange.com/questions/382937/other-data-on-apple-how-do-i-clean-cache-and-other-unused-data-on-mac)
- [Ask Different: 32 GB of user cache files](https://apple.stackexchange.com/questions/408954/delete-32gb-user-cache-files-or-no)
- [Ask Different: storage discrepancy](https://apple.stackexchange.com/questions/289170/discrepancy-in-hard-drive-space-can-i-delete-these-files)
- [Ask Different: reclaiming disk space](https://apple.stackexchange.com/questions/145268/reclaiming-disk-space-on-my-mac)
- [Ask Different: deleted files do not free space](https://apple.stackexchange.com/questions/362656/why-does-my-mac-not-have-free-space-even-after-i-delete-files/362658)

### User distress, uncertainty, and accounting mismatch

- [MacBook Air low-space and update problem](https://www.reddit.com/r/MacOS/comments/1v5h166/macbook_air_m1_2020_256gb/)
- [Where's my disk space?](https://www.reddit.com/r/mac/comments/1c3ldoi/wheres_my_disk_space_what_is_taking_up_all_the/)
- [How do I clear System Data?](https://www.reddit.com/r/MacOS/comments/154rp99/how_to_do_i_clear_system_data_on_mac_os/)
- [System Data taking over storage](https://www.reddit.com/r/mac/comments/1tag525/macos_taking_up_over_100gb_in_system_data_how_do/)
- [System Data and app support confusion](https://www.reddit.com/r/MacOS/comments/15p6fcf/why_is_system_data_taking_up_so_much_space_and_how/)
- [System Data grows over half the disk in a week](https://www.reddit.com/r/MacOS/comments/1rj6xp9/system_data_is_expanded_to_over_half_of_storage/)
- [System Data growing rapidly](https://www.reddit.com/r/mac/comments/1kmh6r9/macos_system_data_growing_rapidly_whats_going_on/)
- [System Data is eating storage on Mac mini](https://www.reddit.com/r/macmini/comments/1u6bk4f/system_data_is_eating_up_my_storage/)
- [System Data going crazy](https://www.reddit.com/r/MacOS/comments/1rpfzp2/system_data_going_crazy/)
- [Storage does not make sense](https://www.reddit.com/r/mac/comments/1s947g8/mac_storage_not_making_sense/)
- [Storage full but not actually full](https://www.reddit.com/r/MacOS/comments/1ep49sh/)
- [Deleted files and no free space](https://www.reddit.com/r/MacOS/comments/160yq8o/deleting_and_emptying_trash_doesnt_free_up_space/)
- [Deleted files do not free space](https://www.reddit.com/r/MacOS/comments/1hpapoj/space_not_freed_up_after_deleting_files/)
- [iCloud local storage problem](https://www.reddit.com/r/iCloud/comments/1ur3bxf/macos_storage_fixed/)

### App ownership and specialist causes

- [Xcode quietly using 60 GB](https://www.reddit.com/r/Xcode/comments/1ry2tnx/xcode_was_quietly_using_60gb_on_my_mac_this_is/)
- [Docker disk image and developer cleanup](https://www.reddit.com/r/mac/comments/1s2qj9e/psa-to-my-mac-devs-stop-docker-from-eating-your/)
- [How to delete an iPhone backup](https://www.reddit.com/r/mac/comments/1jec2rn/how_can_i_delete_an_iphone_backup_from_mac/)
- [Mac uninstaller and cleanup discussion](https://www.reddit.com/r/macapps/comments/1lf3f2i/mac_uninstaller_or_cleanup_tool_trying_to_clean/)
- [Xcode simulators and old runtimes](https://www.reddit.com/r/Xcode/comments/1du8m6s/how_do_i_remove_old_xcode_simulators_still_on_my/)

### Cloud and local-materialization behavior

- [Dropbox: Free up space with online-only files](https://help.dropbox.com/sync/make-files-online-only)
- [Microsoft: OneDrive Files On-Demand for Mac](https://support.microsoft.com/en-US/onedrive/save-disk-space-with-onedrive-files-on-demand-for-mac)
- [Google Drive: Stream and mirror files](https://support.google.com/drive/answer/13401938?hl=en)
- [Apple: Work with folders and files in iCloud Drive](https://support.apple.com/en-ie/guide/mac-help/mchl1a02d711/mac)
- [Dropbox user: online-only files still taking space](https://www.reddit.com/r/dropbox/comments/1ttyksf/tech_help_files_labeled_online_only_still_taking/)
- [Dropbox user: online-only icons but local space is gone](https://www.reddit.com/r/dropbox/comments/1l45nhw)
- [Dropbox user: hidden provider storage on Mac](https://www.reddit.com/r/mac/comments/1u3y41y/dropbox_taking_up_way_too_much_storage/)
- [iCloud user: moved documents did not change local space](https://www.reddit.com/r/iCloud/comments/le03jo)
- [iCloud user: local disk filled by iCloud documents](https://www.reddit.com/r/macmini/comments/1s808rf/m1_out_of_storage_due_to_icloud_need_advice/)
- [Apple Photos user: Optimize Storage did not free expected space](https://www.reddit.com/r/ApplePhotos/comments/1ripp3y/optimise_storage_not_really_doing_much/)

### Backups and virtual disks

- [Apple: Locate and manage device backups](https://support.apple.com/en-us/108809)
- [Apple: Back up your Mac with Time Machine](https://support.apple.com/en-us/104984)
- [Time Machine user: old Mac backup on a full destination](https://www.reddit.com/r/MacOS/comments/1kmddd8/how_to_delete_old_macs_time_machine_backup/)
- [Time Machine user: old backups and changed Mac identity](https://www.reddit.com/r/MacOS/comments/12m5zmh/doesnt_time_machine_automatically_clear_up_old/)
- [Time Machine user: full destination and mixed backup roles](https://www.reddit.com/r/MacOS/comments/1urpjun/what_is_supposed_to_happen_here/)
- [Docker: FAQs for Docker Desktop for Mac](https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/)
- [Docker: prune unused objects](https://docs.docker.com/engine/manage-resources/pruning/)
- [Parallels: free up disk space on Mac](https://kb.parallels.com/br/123553)
- [Parallels user: deleted VM did not release space](https://www.reddit.com/r/mac/comments/lvspv8/macbook-air-m1-recover-free-space/)
- [Parallels user: Windows 11 disk resize boundary](https://www.reddit.com/r/mac/comments/rnnbc1/m1_macbook_pro_14_parallels_windows_11_hdd/)
- [UTM: resize and compress a drive](https://docs.getutm.app/settings-qemu/drive/resize-and-compress/)
- [VMware user: host disk and guest partition mismatch](https://www.reddit.com/r/vmware/comments/rg81wm/increasing-disk_size/)

### Product expectations and trust signals

- [CleanMyMac Smart Care](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care)
- [CleanMyMac App Store reviews](https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12&see-all=reviews)
- [DevCleaner reviews](https://apps.apple.com/us/app/devcleaner-for-xcode/id1388020431?mt=12&platform=mac&see-all=reviews)
- [GrandPerspective reviews](https://apps.apple.com/us/app/grandperspective/id1111570163?mt=12&platform=mac&see-all=reviews)
- [DiskSpace release notes](https://apps.apple.com/us/app/diskspace-cleaner-analyzer/id6759896440?mt=12)
- [TriClean release notes](https://apps.apple.com/us/app/triclean-disk-cleaner-analyzer/id6758438961?mt=12)
- [Disk Cleanup release notes](https://apps.apple.com/us/app/disk-cleanup-storage-cleaner/id6782516789?mt=12)
- [Cleaner One reviews](https://apps.apple.com/us/app/cleaner-one-disk-clean/id1473079126?mt=12&platform=mac&see-all=reviews)
- [Open-source Mac Clean discussion](https://www.reddit.com/r/macapps/comments/1tx7nju/os_found_40gb_of_junk_i_couldnt_see_so_i_built/)
- [Trace storage inspector discussion](https://www.reddit.com/r/macapps/comments/1r6129o/i_built_a_macos_native_system_data_inspector/)
- [StorageRadar discussion](https://www.reddit.com/r/macapps/comments/1rmfq2h/macos_i_built_a_mac_storage_tool_for_people_who/)
- [LittleClean discussion](https://www.reddit.com/r/macapps/comments/1vm5ovg/os_littleclean_opensource_macos_cleaner_for_apps/)
- [PureMac comparison discussion](https://www.reddit.com/r/macapps/comments/1tokpo2/puremac_comparison_to_mole_onyx_cleanmymac/)
- [CleanMyMac subscription distrust](https://www.reddit.com/r/MacOS/comments/1pmm709/cleanmymac_liftime_subscription_is_a_scam/)
- [Background cleaner service concern](https://www.reddit.com/r/mac/comments/1c3fs21/clean_my_mac_removed_the_ability_to_cancel_their/)

## Handoff boundary

This file is the evidence record for the next interview. It is not an implementation request yet. After the user confirms the recurrence, memory, ambiguity, and Empty Trash boundaries, create the implementation handoff with:

- the settled user choices;
- the rescue state machine;
- the recommendation and risk models;
- exact Tessera files to change;
- safety invariants;
- test cases for Trash, verification, snapshots, active handles, sync, permissions, and stale remembered rules;
- acceptance criteria for the real macOS surface.

No Tessera source code was changed during this research round.
