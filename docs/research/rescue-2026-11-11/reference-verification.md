# Rescue reference verification

Checked on 11 November 2026. This is a bounded source check of the four recovered reports. It is research for the next discussion with Ammar. It is not a Rescue specification or approval to build it.

Outcome: check 12 decisive claims and four public threads against opened sources. Proof: the exact source links, sections, methods, and limits below. Constraints: one report file, no product edits, no checkout changes, no commits, no external writes, no children, and a 15 minute limit.

The recovered Opus reports remain unverified except where this report checks a claim. Codex performed this check. This is not independent model-family review. No interviews, recruited usability sessions, or Tessera user study took place. Public-post desk research is not recruited usability research.

Vendor pages establish documented behavior. They do not establish user success or safety in every case. Paper results apply to their study samples and tasks. Design implications below are inferences, not observed Tessera outcomes.

## Twelve claim checks

### 1. CleanMyMac uses a summary before detailed review, but review is optional

Observed support: MacPaw's Smart Care page, updated 15 October 2026, describes a scan, module result tiles, a Review action within each tile, then Run. It lists Cleanup, Protection, Performance, Applications, and My Clutter in that scan sequence. All Smart Care tasks start selected. Cleanup selects removal candidates, while My Clutter scans Downloads for duplicates. [Smart Care, sections Run Smart Care and Review results](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care).

Limit: the listed scan sequence is not proof of an adaptive ranking algorithm or a global size order. Module-task selection is not proof that every personal file starts checked. The page describes vendor behavior, with no participant study.

Design inference: a short summary with access to details is a valid reference pattern. It does not settle Rescue's row order, preselection, or required review policy.

### 2. CleanMyMac's junk review has category scope and specific selection exceptions

Observed support: the System Junk page, updated 15 October 2026, gives this path: Cleanup scan, summary, Review All Junk or the System Junk tile's Review, Cleanup Manager, selection, Clean Up, then results. A tile also offers Clean without review. Inside the manager, size and name sort both support either direction. Smart Selection excludes Gradle cache from User Caches, module caches and archives from Xcode Junk, and the newest iOS backup. The removal action applies only to the category in view. [Remove system junk, steps 2–5](https://macpaw.com/support/cleanmymac/knowledgebase/system-junk).

Limit: applying Smart Selection is a documented bulk command. This page alone does not establish the initial check state of each subgroup or the default sort direction. It does not establish whether every junk deletion uses Trash.

Design inference: show exactly which items a batch affects. Derive exceptions from the data type and recovery cost. A broad label such as cache is not enough evidence of safety.

### 3. CleanMyMac's large-file review and Space Lens have different ordering rules

Observed support: My Clutter's Large & Old Files page, updated 1 October 2026, says files must occupy at least 50 MB. It offers groups by kind, size, or access date and sorts by size, name, or date in either direction. It does not select files automatically. Removal bypasses Trash. [Deal with large and old files, opening text and steps 3–5](https://macpaw.com/support/cleanmymac/knowledgebase/large-and-old).

Space Lens documentation, updated 6 August 2026, explicitly describes top-level files and folders in descending size order, beside bubbles. It folds lighter items into Other items and blocks selection of required system items. [Explore scan results, opening text and Select items](https://macpaw.com/support/cleanmymac/knowledgebase/space-lens-results).

Limit: neither page proves that all cleanup recommendations use size-first order. No installed-app capture was taken.

Design inference: distinguish storage size ranking from cleanup recommendation ranking. Personal-file review with no initial selections is a documented reference. Choosing it for Rescue still needs a product decision.

### 4. DaisyDisk sorts its map by size and stages deletion in a Collector

Observed support: the undated version 4 guide says map segments are sorted by size. The sidebar follows the pointed folder, and users drill into the hierarchy. It does not describe a flat global ranking of safe cleanup suggestions. [Understanding the disk map](https://daisydiskapp.com/guide/4/en/UnderstandingSunburst/).

The Collector holds staged items at the bottom. Users can expand it, preview items, and remove entries. Files remain intact until Delete. A five-second cancellation window precedes permanent removal. Whole roots such as `/System`, `/Library`, and the current home folder are rejected. [Deleting files, The Collector and What can you delete?](https://daisydiskapp.com/guide/4/en/DeletingFiles/).

Limit: this is current accessible documentation checked in 2026, not a dated release test. Rejecting a whole root does not mean every child within it is blocked. Permanent deletion can still leave bytes held by snapshots, as the same guide explains.

Design inference: a visible staging list is a useful model. Its presence does not prove informed consent, immediate recovery of space, or undo after permanent deletion.

### 5. Apple's three Storage recommendations are verified; their universal visual order is not

Observed support: Apple's current guide lists Store in iCloud, Optimize Storage, and Empty Trash automatically. Optimize Storage removes watched Apple TV content and keeps recent mail attachments when space is needed. Automatic Trash removal applies after more than 30 days. The page also says macOS clears certain safe caches and logs when space is needed. [Optimize storage space on your Mac, recommendation table and following paragraph](https://support.apple.com/guide/mac-help/optimize-storage-space-sysp4ee93ca4/mac).

Method and year: opened the primary HTML in 2026 through a bounded Python HTTP read after the web reader returned HTTP 429. The response contained the actual recommendation table. No app session or user sample was involved.

Limit: the table's document order does not prove every Mac shows exactly three cards in that screen order. Cloud use can require paid capacity. This is not evidence that all third-party caches clear themselves or that manual cache clearing never helps.

Design inference: distinguish short-term cache relief from removal of unwanted stored content. Do not promise how long the gain lasts without measurement.

### 6. Moving to Trash is not the same as freeing storage

Observed support: Apple states that moving a file to Trash does not make its storage available until Trash is emptied. It also describes safe-mode cache relief as temporary because caches form again. [Free up storage space on Mac, Move or delete files and Temporarily free up more storage space](https://support.apple.com/en-us/102624).

Apple's Storage guide distinguishes physically free space from available space, which also includes purgeable caches. It describes System Data as a changing category managed by macOS. [Find and delete files on your Mac, System Data and final storage explanation](https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac).

Method and year: both primary pages opened as HTML through bounded Python HTTP reads in 2026 after web-reader HTTP 429 failures.

Limit: these pages do not establish whether the Storage pane's Delete button uses Trash. They also do not provide an algorithm for attributing an observed free-space change to a particular deletion.

Design inference: label staged bytes, bytes moved to Trash, and measured free-space change separately. A post-action free-space change is an observation, not exact causal attribution.

### 7. Docker disk capacity, host usage, and reclaimable data are separate quantities

Observed support: Docker's current Mac FAQ says Desktop stores Linux data in a disk image. Settings shows its maximum size and actual consumption. Its example has a 64 GB maximum but 2,333,548 KB of actual host usage. That 64 GB is an example, not evidence of today's universal default. The FAQ directs users to Docker Settings to move the image. Reducing its maximum deletes the current image and loses containers and images. [Docker Desktop for Mac FAQ, Where does Docker Desktop store Linux containers and images?](https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/).

Method and year: primary documentation opened in 2026; no Docker workload was run.

Limit: allocated host bytes still do not tell us which Docker objects are expendable or how much a chosen cleanup will return. The FAQ warns that host reclamation can take minutes.

Design inference: never call the apparent disk image size recoverable space. Explain Docker ownership and leave the image intact during ordinary file cleanup.

### 8. Docker's reclaimable estimate is not permission to prune

Observed support: `docker system df` reports daemon disk use with separate size and reclaimable columns. Verbose output separates shared and unique image bytes. [docker system df, Examples](https://docs.docker.com/reference/cli/docker/system/df/).

The default prune example removes stopped containers, unused networks, dangling images, and unused build cache. It prompts for confirmation. Volumes are excluded by default to protect data. `--volumes` includes unused anonymous volumes, while `-a` expands image removal. The command reports reclaimed space afterward. [docker system prune, Options and Examples](https://docs.docker.com/reference/cli/docker/system/prune/).

Method and year: both live primary references opened in 2026. No CLI execution or disk measurement.

Limit: the reference's broad introductory wording must be read with its flags and default example. Unused objects may still matter to a developer. A daemon result is not proof of an equal immediate increase in host free space.

Design inference: present an owner-reported estimate with its source. Keep inspection separate from destructive owner actions. No research result here authorizes running prune.

### 9. GrayArea supports easier demotion, not a claim that Trash increases recovered bytes

Observed support: Bergman et al., CHI 2009, tested 96 volunteer Windows XP users in a remote, counterbalanced within-subject task using simulated views of their own folders. Actions did not alter real files. Only 78 action logs arrived. Table 2 reports standard keep/delete shares of 80%/20%, versus 67%/10%/23% for keep/delete/demote. Of all 96 participants, 81% said demotion was easier than deletion. [GrayArea paper, Method and Results, PDF pages 6–8](https://cutrell.org/papers/CHI09-BergmanEtal-GrayArea.pdf).

Correction: the recovered report calls the main study a lab study. The paper describes a downloaded application and web questionnaire. Its 13-point clutter reduction includes demotion and is not storage recovery. The 96-person sample is not the denominator for logged actions.

Limit: simulated Windows folder management in 2009 differs from destructive cleanup on current Macs. GrayArea retains files; it is not Trash.

Design inference: test reversible choices for confidence, but measure successful storage recovery separately from decluttering.

### 10. Concrete cloud files prompted deletion preferences, but the study did not prove a UI causes more deletion

Observed support: Khan et al., CHI 2018, recruited 100 North American adults through Mechanical Turk. Each reviewed ten files selected through stratified categories in their own Dropbox or Google Drive. Overall, 83% wanted at least one shown file deleted. Participants chose delete for 35% of reviewed files. Only 32% agreed abstract automatic deletion would help. [Forgotten But Not Gone, Methodology, Table 1, and File Management, PDF pages 3–8](https://www.blaseur.com/papers/chi18retrospectivecloud.pdf).

Limit: the sample required willingness to grant account access. Files were not a representative random sample of whole accounts. These were stated preferences, not a field trial of deletion behavior or disk-space recovery. The abstract question concerned automatic deletion; it was not a controlled comparison with a manual review UI.

Design inference: show identifiable candidates and support review. The paper does not justify excluding personal files, automatic selection, or a claim that this design makes 83% of Tessera users delete files.

### 11. File age alone is not a deletion safety rule

Observed support: Khan et al., USENIX Security 2021, used 17 formative interviews and an online study of 108 long-term cloud users, producing 3,525 file labels. A two-step model using predicted usefulness and sensitivity reached 79% file-management accuracy. For actual keep labels, 9% were wrongly predicted as delete. Modification-date heuristics were weaker for usefulness prediction. The authors advise seeking user confirmation rather than making retention decisions automatically. [Helping Users Automatically Find and Manage Sensitive, Expendable Files in Cloud Storage, sections 6, 7.4, Table 7, and Discussion](https://www.usenix.org/system/files/sec21-khan-mohammad.pdf).

Limit: the model used rich features, including content analysis. This is cloud-file classification, not a local Mac safety validator. Overall accuracy hides harmful errors. Modification time and last access time are different signals.

Design inference: age can help users inspect a candidate. Age does not prove low value, replaceability, or permission to delete. These results give no safe age threshold for Rescue.

### 12. Defaults influence choice, but there is no measured Rescue effect

Observed support: Jachimowicz et al., published 2019, searched literature through May 2017. The methods count 58 datasets from 55 studies in 35 articles, with pooled n = 73,675. The abstract calls these 58 default studies. The pooled effect was d = 0.68, 95% confidence interval 0.53–0.83. The binary subset had an absolute average uptake difference of 27.24 percentage points. Effects varied substantially. [When and why defaults influence decisions, Data collection, Overall effect size, and General discussion](https://www.cambridge.org/core/journals/behavioural-public-policy/article/when-and-why-defaults-influence-decisions/67AF6972CFB52698A60B6BD94B70C2C0).

Correction: the binary result is an absolute difference, not a general 27% relative increase. It is not a deletion-rate forecast.

Limit: the pooled domains and choices differ from file cleanup. Neither effect size establishes a safe preselection policy for caches or personal data.

Design inference: treat a checked box as a strong product recommendation. A policy to leave personal or uncertain items unchecked is defensible, but its safety and usability still need direct tests.

## Four public-thread checks

These threads were selected from the recovered report to cover distinct concerns. This is a purposive check, not a representative sample. Posts establish that someone reported an experience or opinion. They do not verify the diagnosis, app fault, frequency, or loss amount. Reply counts, reaction votes, and repeated quotations are not participant counts.

| Opened thread and evidence year | Actual support and short excerpt | Limit and design inference |
| --- | --- | --- |
| [MacRumors, How do I Remove Purgeable Files](https://forums.macrumors.com/threads/how-do-i-remove-purgeable-files.2410959/), November 2023, swandy, posts 1 and 10 | The poster reports over 120 GB purgeable and a Diablo 4 install blocked through CrossOver/Battle.net. Excerpt: "insufficient hard drive space to install Diablo 4". Replies disagree about Optimize Storage. | No reproduction or verified cause. Use this as a scenario for testing whether Rescue explains free versus available space. It does not prove a current Battle.net defect. |
| [Apple Developer Forums, FYI: Xcode and Disk Space](https://developer.apple.com/forums/thread/773153), January 2025, CPSoftware and replies | The opening post reports old simulators consuming storage. Excerpt: "Xcode doesn't delete old or unused Simulators". Replies suggest different deletion paths. | These are community posts, not Apple engineering guidance. No before/after audit validates the stated gain. Test owner-managed developer storage as a distinct case; do not copy destructive forum commands. |
| [Hacker News, Cowork VM bundle discussion](https://news.ycombinator.com/item?id=47218288), 2026, quinncom, divan, and vachina | Posters report an unexpected VM image and concern about limited disk space. Excerpt from vachina: "macOS presents your storage as a black box". An Anthropic employee also explains the VM's purpose. | The post date is shown as eight months before this check. No disk captures were validated. Owner and purpose labels are worth testing. This thread cannot rank VM problems against other storage problems. |
| [MacRumors, Is CleanMyMac actually legit or snake oil?](https://forums.macrumors.com/threads/is-cleanmymac-actually-legit-or-snake-oil.2476091/), January–February 2026 | thebart reports a proposed deletion involving a music collection and Spotify cache. Excerpt: "it proposed to delete stuff that clearly shouldn't be deleted". Other posters defend usefulness or convenience. | No file list, product build, or reproduction establishes a misclassification. It was a reported proposal, not established data loss. Test explanations and exclusion controls; do not label the vendor unsafe from this anecdote. |

Apple Support Communities thread [255806791](https://discussions.apple.com/thread/255806791) was also attempted. The web reader returned HTTP 429. A direct HTTP read redirected to human verification. Its contents were not verified and are not included as a fifth checked thread.

## Claims to hold back

The four checked threads do not establish the most common space consumer, a typical Messages size, the top recommended cleaner, or the main cause of distrust. The recovered user-voice report has no auditable unique-poster count. Do not use its count or its frequency language.

The sources do not establish a universal risk-before-size or size-before-risk rule. CleanMyMac has module tiles and several optional sorts. DaisyDisk ranks storage within a hierarchy. The recovered studies report also proposes safety tiers, while the other-platform report argues against them. Those are competing design inferences.

No evidence checked here establishes permanent savings. Caches can regrow; downloads and media can return; snapshots can retain blocks. Replace "freed for good" with a factual statement about what was removed and what can happen next.

The paper figures for corporate Windows disk composition, the 2025 deletion-tactics paper, digital-hoarding prevalence, and the claimed comparison advantage of bars over sunbursts were outside this check. They remain unverified here.

No installed CleanMyMac or DaisyDisk build was tested. No Tessera source behavior, deletion recovery, APFS shared-block accounting, or current Mac storage distribution was checked. These require app tests, code inspection, or a defined scan sample. Vendor help pages cannot settle them.

## Decisions ready for Ammar's next discussion

These are decision topics with a recommended starting position. They are not decisions already made, input requests, or an implementation specification. Each can be discussed before choosing a screen layout, category list, scanner, or automation mechanism.

1. **Define Rescue's outcome.** My pick is storage recovered for the user's next task, with understanding of large consumers as a supporting outcome. The alternative is broad file decluttering. Ask which outcome should win when an action tidies files but frees no space.

2. **Set the meaning of space numbers.** My pick is to keep candidate size, staged bytes, Trash bytes, owner estimates, and observed free-space change distinct. Ask whether Ammar accepts a result that clearly reports movement to Trash while showing no immediate gain. This accounting choice stands apart from layout.

3. **Set the consent rule for personal files.** My pick is no preselection for personal or uncertain data. Ask whether convenience ever justifies a checked personal file. Resolve the principle before trying to define a supposedly safe age or file type.

4. **Set the boundary for owner-managed data.** My pick is visible ownership and a route to the owning tool for VM images and similar stores. Ask whether discovery and explanation are enough value when Tessera cannot perform the cleanup. This does not choose whether to call an owner CLI.

5. **Set the recovery promise.** My pick is reversible file removal where supported, with any permanent deletion treated as a separate choice. Ask what recovery Ammar expects and when he expects space to become usable. Do not promise both immediate recovery of all bytes and full restoration without checking the storage behavior.

6. **Set the proof required before implementation.** My pick is to grill these principles with Ammar, then test task comprehension and risky selection on a small prototype with recruited people. Ask whether that is the required next evidence step. Agent review and public posts cannot show that people understand Rescue or recover space safely.
