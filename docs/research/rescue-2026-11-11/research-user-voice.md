# Recovered user voice

Recovered from the 10 November 2026 Opus research workflow.
Status: source verification pending. This report is research, not a product spec.
No interviews or new participant study took place. Public posts are qualitative evidence only.

Reddit was not reachable. The search tool refuses reddit.com, so this research uses Apple Support Communities, MacRumors, Apple Developer Forums, Hacker News, Trustpilot, Mac App Store pages, vendor docs and blog reviews. It is qualitative: about 20 threads and pages, roughly 150 distinct posters, and most of the sizes come from people who had a serious problem. Users hire a disk tool for one main job, which is to answer "where did my space go, and what can I safely remove to get it back." They want this before an update, an install or a game download fails. The biggest surprise consumers are almost never generic "junk." They are a few huge, opaque items: local APFS snapshots (Time Machine and third-party backup apps, often 100 to 400+ GB), runaway system or app caches (mediaanalysisd, Safari CloudKit, Podcasts, Spotlight), Messages attachments (20 to 188 GB), developer stores (Xcode simulators and runtimes, Docker or Podman VMs), and local iCloud or AI model data. All of them show up inside the catch-all "System Data" or purgeable figure, so the macOS numbers do not add up, and users say Mac storage is "a black box." Trust is low. Forum regulars call CleanMyMac-style cleaners scams or malware because of fake alerts, big "junk" totals that are mostly caches that come back, deleted logs and project files, and subscription pressure. Users praise DaisyDisk for its visual map, its "hidden space" breakdown and the fact that it "does not delete anything on its own." For Tessera Rescue, the lesson is to put the few biggest items first, explain each one in plain words with its real recoverable size, put snapshots and other hidden space at the top instead of in a footnote, send owner-managed data to the right owner action, and never inflate a junk total.

## Findings

### The main job is to find where the space went when the disk is unexpectedly full and the macOS numbers do not explain it.

Evidence: "can't find what is hold 660 GB of data" and "nothing anywhere adds up to 661GB of data" (lwilliams, Feb 2026, 8 posters); "The lack of extra storage space does not add up literally and figuratively" (ResoluteOne, Apr 2026, 8 posters); "macOS presents your storage as a black box" (vachina, HN, ~186 comments)

Source: https://forums.macrumors.com/threads/system-data-huge-700gb-help.2477125/ ; https://forums.macrumors.com/threads/storage-capacity-keeps-shrinking-on-my-m2-mini-even-after-deleting-at-least-100-gigabytes-off-my-drive-ideas.2481527/ ; https://news.ycombinator.com/item?id=47218288

Implication: Rescue should start with one sentence that answers "where did my space go": the top 3 to 5 consumers ranked by recoverable bytes. A list of categories or a staged workflow is not that answer.

### A second job is to make room for one concrete task, usually an OS update, an app or game install, or a project export. Users often report the blocker first.

Evidence: "I kept being told that I had insufficient hard drive space to install Diablo 4" (swandy, 11 posters); "I could not upgrade to 15.2 prior to clearing this cache because, no free space..." (mart62); Apple says Safe Mode cache clearing "can help when installing a macOS update"

Source: https://forums.macrumors.com/threads/how-do-i-remove-purgeable-files.2410959/ ; https://discussions.apple.com/thread/255806791 ; https://support.apple.com/en-us/102624

Implication: Tessera already has goals for update, install, export and build (CleanupSuggestions.swift:52-75). Show progress toward that goal in GB in the header, for example "Need 12 GB for the update, 31 GB found." Do not hide it behind a capacity-percent stepper.

### The consumer users report most often is local APFS snapshots. They are often hundreds of GB, and those from third-party backup apps do not purge on their own.

Evidence: Carbon Copy Cloner snapshot "occupying 416GB" (JethLaq); ChronoSync snapshot about 120GB (BerndXL); "'snapshots' are supposedly using up 188.1 GB of hidden space" (ResoluteOne); stuck com.apple.asr snapshots "eating up 400GB"; CCC snapshots of 168GB; "~300GB of my 512GB disk, just labeled the generic 'System Data'" from a bad Time Machine backup (geooff_, HN). DaisyDisk docs: third-party snapshots "are not counted toward the purgeable space, but toward the still hidden space."

Source: https://discussions.apple.com/thread/255806791 ; https://forums.macrumors.com/threads/storage-capacity-keeps-shrinking-on-my-m2-mini-even-after-deleting-at-least-100-gigabytes-off-my-drive-ideas.2481527/ ; https://forums.macrumors.com/threads/help-for-system-data-enormous-sizes-on-macbook-pros-cleaning-app-questions.2477050/page-2 ; https://news.ycombinator.com/item?id=47218288 ; https://daisydiskapp.com/guide/4/en/Snapshots/

Implication: HiddenSpace.swift only lists Time Machine snapshots (tmutil listlocalsnapshots) and shows snapshot space as a coverage note (CleanupSuggestions.swift:795). Rescue should show snapshots as a top-ranked suggestion with the owner (Time Machine, CCC, ChronoSync, asr) and the private size. Third-party snapshots should hand off to the owner app.

### Users do not understand that deleting files does not free space while a snapshot still holds them. This is the most common reason the numbers do not add up after a cleanup.

Evidence: "When you deleted tens of gigs of files, TM created tens of gigs of snapshots" (Alameda, Apr 2026); "There should be an extra 103.7 GB of storage space" (ResoluteOne); "I saw these huge system snapshots containing the files I had deleted, and kicker was, there was no way to delete them!" (prmph, HN); disagreement in one thread: "Snapshots don't take up space, really" (SDAVE), answered by "they keep deleted files from being 'erased'" (Ben J.)

Source: https://forums.macrumors.com/threads/storage-capacity-keeps-shrinking-on-my-m2-mini-even-after-deleting-at-least-100-gigabytes-off-my-drive-ideas.2481527/ ; https://news.ycombinator.com/item?id=47218288 ; https://forums.macrumors.com/threads/system-data-huge-700gb-help.2477125/

Implication: After a Move to Trash, the verification step should say when freed bytes are lower than expected because a snapshot or the Trash still holds them, and should name the next action. Users read a silent shortfall as "the app lied."

### Runaway caches from Apple or third-party apps are the second most common hidden consumer, and they often sit inside System Data.

Evidence: mediaanalysisd cache: "an endless list of these 64MB files" (mart62), hundreds of GB; Safari CloudKit cache "153gb on my machine" (HN 46763592); "Apple Podcasts app decided to download 120GB of podcasts" (MarleTangible, HN) and ~250GB of Podcasts cache (HN 47237939); Spotlight index "120GB of system data shrank to just 35GB" (vijayhardaha); After Effects "kept creating multiple huge caches" (Apple Community 255965741)

Source: https://discussions.apple.com/thread/255806791 ; https://news.ycombinator.com/item?id=46763592 ; https://news.ycombinator.com/item?id=47218288 ; https://news.ycombinator.com/item?id=47237939 ; https://discussions.apple.com/thread/255965741

Implication: Rank cache folders by size, not as a single "Application Caches" lump. One outlier folder over a few GB (Podcasts, Safari CloudKit, mediaanalysisd, Adobe) is a different story from many small caches that come back. Label the outliers with the owning app name.

### Messages attachments are a large and confusing consumer on Macs, typically 20 to 190 GB. Turning on Messages in iCloud does not shrink the local copy.

Evidence: "Messages is taking up Seventy Gigabytes on my M2 Mac Mini's SSD, compared to 1.4GB on my iPhone" (obesechess); "My Local Messages storage (on the Studio) is ~188GB" (splifingate); "This freed up 73GB of space in two minutes"; "turning on iMessage in iCloud DOES NOT in fact free up space" (6 posters); "Apple is just using up 100GB on my machine, just because I enable iMessage syncing" (dewey, HN)

Source: https://forums.macrumors.com/threads/help-messages-take-up-too-much-space-store-in-icloud-only.2445412/ ; https://news.ycombinator.com/item?id=47218288 ; https://discussions.apple.com/thread/256223471

Implication: Tessera holds Messages as protected "Communication data" (CleanupSuggestions.swift ~405). That is right for safety, but Rescue should still rank it by size and give the owner path in plain words (System Settings > General > Storage > Messages), not hide it.

### Developer stores are very large on developer Macs. Xcode simulators and runtimes are the biggest part, then Docker or Podman VM disks. Each node_modules is smaller (about 0.2 to 2 GB) but there are many.

Evidence: "~/Library/Developer may quietly grow to 50, 100, or even 150 GB"; one scan found "98 GB in CoreSimulator, 107 GB in AssetsV2, and 125 GB across 19 simulator runtimes"; "Xcode doesn't delete old or unused Simulators" (CPSoftware, Jan 2025); "the Podman virtual machine on my MacBook had eaten up more 100GB!" (prmph, HN); node_modules "1.9GB" and "1 GB of node_modules and the actual source code is well under a megabyte" (HN)

Source: https://jonathanspooner.com/posts/reclaim-100-gb-from-xcode-the-cleanup-script-i-wish-i-d-written-years-ago ; https://developer.apple.com/forums/thread/773153 ; https://news.ycombinator.com/item?id=47218288 ; https://news.ycombinator.com/item?id=30919487 ; https://news.ycombinator.com/item?id=29525519

Implication: The catalog covers DerivedData, DeviceSupport and node_modules, but I found no CoreSimulator or simulator-runtime category in CleanupSuggestions.swift. Add simulator devices and runtimes with an owner handoff (xcrun simctl delete unavailable, or Xcode Settings > Platforms). Sum node_modules across projects into one line with a count.

### Docker.raw sizes mislead users and tools. The file shows its maximum size (64 GB by default), not what it actually uses. Deleting it in Finder destroys all images and containers.

Evidence: Docker FAQ: "many tools report the maximum file size, not the actual file size"; example "the actual size of the disk is 2333548 KB, whereas the maximum size of the disk is 64 GB"; lowering the limit means "all containers and images are lost"

Source: https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/

Implication: For virtual disks, Rescue must show allocated bytes (it should already use allocated size), say "managed by Docker", and point to docker system prune or Docker Settings. A Trash action is wrong here, so the protected and handoff treatment is correct.

### Users regularly find large personal files they forgot, such as AI models, phone backups, video work files and local cloud copies. These are often the easiest big wins.

Evidence: "I removed 89GB of Diffusionbee AI app model downloads" and "I had 70GB Samsung Switch mobile data backup on internal disk" (eva2000, 7 posters); "a distilled version of deepseek-r1 that was another 230GB" plus ~350GB of local iCloud data (hard_knee); Apple's own list includes "Delete old iPhone/iPad backups" and "Clear the Downloads folder"

Source: https://forums.macrumors.com/threads/tips-for-managing-disk-space-whats-your-method.2469006/ ; https://discussions.apple.com/thread/255806791 ; https://support.apple.com/en-us/102624

Implication: Add or raise suggestions for very large single files and folders the user owns, such as model folders (.gguf, .safetensors, ~/.ollama, HuggingFace cache), MobileSync backups and big videos, shown by size and last-opened date. LargeOldFiles.swift may already cover part of this; the gap is putting them at the top with a clear owner.

### Purgeable space confuses users. They think it should count as free, but some installers and apps treat it as used, and macOS does not always purge it in time.

Evidence: "I have like 450GB of purgeable space on a 1TB drive" (jclin10); "Battlenet was seeing them as occupied space" (swandy); "MacOS is *terrible* at purging purgeable space" (maxoakland); snapshots "are supposed to be deleted if space is needed by something else, but this doesn't always happen" (Mike Boreham)

Source: https://forums.macrumors.com/threads/how-do-i-remove-purgeable-files.2410959/ ; https://forums.macrumors.com/threads/tips-for-managing-disk-space-whats-your-method.2469006/

Implication: Show two numbers: free now, and free after macOS purges. Explain the gap in one line, and offer the snapshot action as the way to make purgeable space really free.

### Apple calls System Data a catch-all. The built-in Storage tools help with ordinary large files but not with System Data.

Evidence: Apple: System Data is "a general category" for files "that don't belong to any more specific category" (formerly "Other"); Apple recommendations: Store in iCloud, Optimize Storage, Empty Trash automatically; Review Files lists files over about 50MB, and one user found it "not as helpful as I'd hoped" because it showed one 12 GB movie

Source: https://support.apple.com/en-us/102624 ; https://support.apple.com/guide/mac-help/optimize-storage-space-sysp4ee93ca4/mac ; https://discussions.apple.com/thread/254596814

Implication: Tessera's edge is to break "System Data" into named parts: snapshots, caches by owner, VM disks, Messages, simulators. Use the same words as the macOS Storage panel so users can match the two.

### Distrust of cleaner apps is strong and specific: fake alerts, junk totals that come back, deleting the wrong things, and subscription pressure.

Evidence: "will give you fake alerts that require a paid subscription to remove" (Mac Jim ID, 39 replies, 104 me-too); "it proposed to delete stuff that clearly shouldn't be deleted, so I noped out. Like somehow it thought my entire music collection is a Spotify's cache" (thebart, Jan 2026, 14 posters); "There is no point in emptying caches to save space, as the OS will just fill them again" (benwiggy); "push you into subscribing to services"; Trustpilot 1 star: "deletes important stuff too" (broken Logic Pro project, Oct 2026)

Source: https://discussions.apple.com/thread/255249088 ; https://forums.macrumors.com/threads/is-cleanmymac-actually-legit-or-snake-oil.2476091/ ; https://ie.trustpilot.com/review/cleanmymac.com

Implication: Never show one big "junk found" total. Do not group caches that come back with space that stays free. Say "comes back after use" on regenerable caches. Show no alerts or red badges for normal states.

### Reviewers say the big "System Junk" numbers are mostly caches that come back. Cleaning logs and caches gives a short-lived gain and removes diagnostic data.

Evidence: Nektony review: caches "rebuild as you use them, so part of that space comes back within days"; Studio N: System Junk clean wipes logs and error reports and freed about 1 GB on an old Mac; TidBITS: macOS rebuilds caches automatically; MacRumors: "do not delete log files either - Mac does it fine"

Source: https://nektony.com/reviews/cleanmymac-review ; https://studioncreations.com/blog/running-cleanmymac-system-junk-scanner-is-a-bad-idea/ ; https://tidbits.com/2015/08/28/save-space-and-uninstall-apps-with-cleanmymac-3/ ; https://forums.macrumors.com/threads/is-cleanmymac-actually-legit-or-snake-oil.2476091/

Implication: Rank Logs and small Application Caches low or fold them away. Rank by bytes that stay free, so items that come back rank below snapshots, VMs, simulators and large user files. The Nektony review is from a competitor, so read it with that bias.

### Most fear comes from not knowing what an item is. Users want a plain explanation before they delete anything.

Evidence: "Admittedly, I was afraid to delete some things because they were not explained well" (CleanMyMac App Store review, Alecfalicki); common forum rule: don't delete anything whose purpose you don't understand; "Couldn't First Aid cause an unbootable computer?" (lwilliams)

Source: https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12&see-all=reviews ; https://forums.macrumors.com/threads/system-data-huge-700gb-help.2477125/

Implication: Each Rescue row needs three short lines: what it is, what happens if you remove it ("Xcode rebuilds it on next build, slower first build"), and who owns it. The current "May change:" side-effect line is the right idea and should be on every row.

### Users reported real loss from cleaners: support files, Downloads, offline cloud copies and Photos libraries were removed, some with no Put Back.

Evidence: A MacRumors user clicked "Review to Clean up" and lost about 500GB of offline Proton Drive data stored in ~/Library/Cloud Storage; CCleaner emptied Downloads and the files were not in Trash; a user deleted Downloads while using DaisyDisk; cleaners deleting files inside the Photos library can break it (Apple Community replies). The original MacRumors page returned 403, so this is from a search summary and is unverified.

Source: https://forums.macrumors.com/threads/new-to-macos-asking-for-suggestion-for-deletion-app.2481200/page-2 ; https://discussions.apple.com/thread/3868210 ; https://discussions.apple.com/thread/253972039

Implication: Keep Move to Trash as the default. Never offer whole Downloads, Cloud Storage, or package bundles such as Photos Library as a single deletable item. Owner-managed roots stay held. The search summary supports this, but I could not read the full thread.

### DaisyDisk is the tool users recommend most. They praise its visual map, its hidden space breakdown, and that it never deletes anything on its own.

Evidence: "DaisyDisk makes the best stab at breaking down 'System' and purgeable data" (gilby101); "Daisydisk has probably the best representation of file usage that I have seen to date" (HN); App Store: "DaisyDisk does not delete anything on its own. (Thank you!)" and "not in a hard-to-read file list"; DaisyDisk shows a "hidden space" item split into Purgeable, Other volumes and Still hidden

Source: https://forums.macrumors.com/threads/tips-for-managing-disk-space-whats-your-method.2469006/ ; https://news.ycombinator.com/item?id=18064268 ; https://apps.apple.com/us/app/daisydisk/id411643860 ; https://daisydiskapp.com/guide/4/en/HiddenSpace/

Implication: Tessera's sunburst and Cleanup List already follow this model. Rescue should copy the explicit "hidden space" item with its parts and sizes, and keep the "nothing moves until you confirm" promise visible.

### Some users find radial charts hard to compare and prefer a sorted list or bars for ranking.

Evidence: DaisyDisk App Store review (P Riehl, rating dropped from 5 to 2): "the human brain is better equipped to compare the size of bars oriented in one direction to 'pie slices'"; HN users praise ncdu's sorted list, which lets them "directly delete files with a single button"

Source: https://apps.apple.com/us/app/daisydisk/id411643860 ; https://news.ycombinator.com/item?id=18064268

Implication: Keep the sunburst in Explore. Rescue should be a ranked list with horizontal size bars on one shared scale, so the biggest win is obvious in under a second.

### The paywall on hidden space and purge is a known complaint. The App Store sandbox also limits what a disk tool can see.

Evidence: DaisyDisk: "The free trial can only detect hidden space and purgeable space"; the purge feature "is not available in the Mac App Store edition"; "as an app store app, it couldn't request the appropriate permissions" (MWJump); "Because App Store apps must be sandboxed" (nottorp)

Source: https://daisydiskapp.com/guide/full-vs-trial ; https://daisydiskapp.com/guide/4/en/PurgeableSpace/ ; https://apps.apple.com/us/app/daisydisk/id411643860 ; https://forums.macrumors.com/threads/how-do-i-remove-purgeable-files.2410959/

Implication: If Tessera lacks Full Disk Access, say exactly which big areas it cannot see and how many GB that leaves unexplained, with one button to grant access. This turns a coverage gap into an action.

### Messages on cleaner trust are mixed. Trustpilot is positive overall but has many invited reviews. Independent forums are much more negative.

Evidence: Trustpilot: 4.7, 3,384 reviews, 83% 5-star, many labeled "Invited" and complaints mostly "Unprompted"; the Apple Community thread has 104 me-too votes against it; MacRumors 2026: "Its legit. Is it necessary? And at that price?"

Source: https://ie.trustpilot.com/review/cleanmymac.com ; https://discussions.apple.com/thread/255249088 ; https://forums.macrumors.com/threads/is-cleanmymac-actually-legit-or-snake-oil.2476091/

Implication: Do not count on star ratings for trust. Earn it on the screen through exact sizes, exact paths, a reason why each item is safe, and no upsell or alarm language.

## patterns

- Copy: a top-of-panel answer to "where did my space go": the 3 to 5 biggest recoverable items ranked by bytes, each with a one-line plain name ("Time Machine snapshots", "Xcode simulators", "Messages attachments").
- Copy: DaisyDisk's explicit "hidden space" item split into Purgeable, Snapshots (by owner app), Other volumes and Still hidden, each with a size. Users call this the best breakdown of System Data.
- Copy: one shared-scale horizontal bar per row in Rescue. Bars beat pie slices for comparing sizes, and the biggest win must be obvious.
- Copy: a three-part row text: what it is / what happens if removed ("rebuilt on next build", "comes back after use") / who owns it. Fear comes mainly from items that are "not explained well."
- Copy: a goal-based header in GB ("Need 12 GB for the update, 31 GB found safely"), tied to the existing RescueGoal values.
- Copy: name the owner action for data an app manages: Messages > System Settings Storage, Docker > docker system prune or Settings, simulators > xcrun simctl or Xcode Platforms, third-party snapshots > the backup app. Do not offer Trash for these.
- Copy: "Nothing moves until you confirm" stays visible. App Store reviewers thank DaisyDisk for never deleting on its own.
- Copy: a post-cleanup check that explains any shortfall ("9 GB still held by a snapshot" or "in Trash") instead of a silent number.
- Copy: ask for Full Disk Access with a specific reason ("about 140 GB is outside what Tessera can read").
- Avoid: one big "junk found" total that mixes caches that come back with space that stays free. Users and reviewers call these numbers meaningless or fake.
- Avoid: red alert badges, "issues found" or "threats" language for normal disk states. Users read this as scareware.
- Avoid: preselected or one-click "Clean" of logs and caches. It deletes diagnostic data for about 1 GB of gain that soon comes back.
- Avoid: whole-folder actions on Downloads, ~/Library/Cloud Storage, Photos Library or Messages roots. These are the reported loss cases.
- Avoid: hiding snapshots or purgeable space in a footnote or coverage note. In this sample they are the most common cause of 100+ GB losses.
- Avoid: showing Docker.raw or sparse VM files at their apparent maximum size. Use allocated bytes and say "managed by Docker."
- Avoid: paywalling or hiding the hidden-space breakdown. Users name this as a DaisyDisk friction point.

## open questions

- Reddit (r/mac, r/MacOS, r/macapps, r/iOSProgramming, r/webdev) could not be searched because the tool refuses reddit.com. Should someone collect a manual sample from Reddit to check this ranking?
- Does Tessera's HiddenSpace list third-party snapshots (CCC, ChronoSync, com.apple.asr), or only Time Machine snapshots? tmutil listlocalsnapshots may miss some of them. Is diskutil apfs listSnapshots needed?
- Does CleanupSuggestions.swift have any category for CoreSimulator devices, simulator runtimes (AssetsV2), Podcasts cache, Safari CloudKit cache, MobileSync backups or local AI models? A grep found none.
- Does LargeOldFiles.swift already put very large single user files (models, phone backups, videos) into Rescue, or only into Explore?
- Should Rescue be able to trigger a purge or a snapshot delete (it needs admin, and HiddenSpace.deleteSnapshot exists), or only hand off to Disk Utility?
- The MacRumors thread with the 500GB Proton Drive loss returned 403. That quote comes from a search summary and is unverified.
- This sample favors extreme cases: people post when they have lost 100+ GB. How common are snapshot or System Data problems among typical users? There is no quantitative data here.
