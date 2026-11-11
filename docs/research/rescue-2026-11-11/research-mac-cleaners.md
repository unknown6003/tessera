# Recovered mac cleaners

Recovered from the 10 November 2026 Opus research workflow.
Status: source verification pending. This report is research, not a product spec.
No interviews or new participant study took place. Public posts are qualitative evidence only.

I compared about 13 Mac disk cleaners and analyzers. Two designs come up again and again. Analyzers (DaisyDisk, GrandPerspective, OmniDiskSweeper, Disk Inventory X, Disk Drill Clean Up, CleanMyMac Space Lens) all sort largest first and put a map or a size-ranked list at the centre. Cleaners (CleanMyMac, Apple Storage settings, Mole, DevCleaner) open with a small set of tiles or categories. Each one shows a size and a Review action. Both families split items the same way. Regenerable junk can be preselected, but only with documented exceptions, such as the newest iOS backup or the newest Xcode device-support version. The user's own files (large and old files, duplicates, downloads) are never preselected. DaisyDisk's own guide says the user's own files, not system files, usually take the most space. Tessera's Rescue is built mostly around junk categories and a large set of state words, so this is the core gap behind "does not tackle the biggest space hogging things". Trust comes from four things: a path-level review list, Quick Look and Reveal in Finder, protected locations that cannot be selected, and the Trash. CleanMyMac (My Clutter) and DaisyDisk delete permanently, and reviewers name this as their main weakness. Nektony and Mole use the Trash, and Nektony adds a Removal History to undo deletions. One honesty point: cache space comes back. A competitor measured 11.3 GB of Smart Care junk and noted that most of it is rebuilt within days, so 'comes back' and 'freed for good' should be shown apart. Apple's Storage pane is criticised for System Data, which has no explanation and no Info button, and for using an Info icon that leads to actions. I could not verify Pretty Clean's or Sensei's layouts from primary sources.

## Findings

### CleanMyMac (2024+) Smart Care shows results as one tile per module. Every task is preselected by default, and each tile has a Review button and a checkbox in its top-left corner.

Evidence: MacPaw KB: 'By default, CleanMyMac selects all Smart Care tasks.' Cleanup 'automatically selects items for removal.' 'Click Review in a tile to adjust selections.' To skip a task, clear 'the checkmark in the top-left corner of each tile.' The tile figures are: space that can be safely freed (Cleanup), threats, maintenance tasks, app updates, and duplicates in Downloads. The KB describes no single overall big number.

Source: https://macpaw.com/support/cleanmymac/knowledgebase/smart-care

Implication: Copy the layout of a few tiles, each with one number and one Review action. Do not copy select-all: Tessera's Trash-first, review-first rule means only regenerable items should start checked.

### Macworld praises the tile redesign of CleanMyMac 5. It says older versions confused users by putting long lists of files on screen.

Evidence: Results now appear 'as a series of tiles that give you a quick summary of each scan'. Earlier versions would 'throw long lists of files and data onto the screen,' which 'could be confusing for many users.' The cons include 'Some technical knowledge still needed.' Review updated Oct 10, 2025.

Source: https://www.macworld.com/article/352922/cleanmymac-x-review-macos.html

Implication: Evidence for the owner's complaint. The first screen of Rescue should be a short summary, with the long path list one step down in Review. It should not be a list of groups with explanations.

### CleanMyMac System Junk uses a documented Smart Selection with exceptions inside each group. The Clean action affects only the category currently in view.

Evidence: Smart Selection picks all items in Broken Login Items, Broken Preferences, the log groups, System Cache and Language Files. Exceptions: iOS Device Backups 'all except the most recent backup'. Document Versions 'saved less than four hours apart, except the latest'. User Caches 'all except Gradle cache'. Xcode Junk 'all except module caches and archives'. 'CleanMyMac only removes items in the currently viewed category.' The tile offers 'Review' or 'Clean to delete all found system junk without reviewing.' (KB updated Oct 15, 2026)

Source: https://macpaw.com/support/cleanmymac/knowledgebase/system-junk

Implication: Tessera's engine should state its keep-newest exceptions per category and show them in the UI, for example 'Keeps your newest backup'. Scoping the action to the visible category is a simple guard against deleting items the user cannot see.

### CleanMyMac's cleanup list documents each junk category in one or two plain sentences, and marks the categories that need a review.

Evidence: Deleted Users: 'They aren't necessarily waste, so review them before removing.' Language Files: 'You can safely remove them.' Universal Binaries: 'after you update an app, the removed version can return.' The Xcode Junk subitems are Derived data, Module caches (not auto-selected), Device support files, iOS device logs, Archives (not auto-selected) and Simulators. The Xcode group appears only if Xcode is installed and the user has built an app. (Updated Oct 12, 2026)

Source: https://macpaw.com/support/cleanmymac/knowledgebase/system-junk-cleanup-list

Implication: Use a one-line 'what it is / what happens if removed / does it come back' for each category. Hide categories that do not apply, for example Xcode when Xcode is not installed.

### CleanMyMac's My Clutter (Large & Old, Duplicates, Downloads) never preselects files and deletes them permanently, bypassing the Trash.

Evidence: Large & Old: 'only files that take up at least 50 MB'. Groups are 'by kind, size, or access date'. The app 'doesn't select or delete files automatically'. 'Files are deleted permanently, bypassing the Trash.' Duplicates: groups show a thumbnail, a name, the number of copies and the combined size. Files must be over 100 KB. Photos library items go to Recently Deleted.

Source: https://macpaw.com/support/cleanmymac/knowledgebase/large-and-old ; https://macpaw.com/support/cleanmymac/knowledgebase/duplicate-files ; https://macpaw.com/support/cleanmymac/knowledgebase/downloads

Implication: Large user files are the biggest win, but they need the strictest review: nothing preselected, grouped by kind or age. Tessera can do better than CleanMyMac by keeping these in the Trash. Nektony's review contradicts MacPaw here ('Deleted items go to the Trash'). MacPaw's own documentation should be taken as correct.

### CleanMyMac Space Lens shows a size-sorted list beside a bubble map. A storage bar above it has Used, Free, Purgeable and Selected segments. System items cannot be selected. Removal goes through a 'Review and Remove' list that shows each path.

Evidence: 'a list of top-level folders and files sorted by size (largest first) alongside their bubbles.' 'The list and bubbles show only the heaviest items; click Other items...' The chart segments are Used, Free, Purgeable and Selected. Selected is 'space taken by the items you've selected; it'll be reclaimed after cleanup.' The review list shows each item's name with its path underneath, which reveals the item in Finder. Updated Aug 6, 2026. Map type: MacPaw and Macworld both say bubbles. A search snippet said treemap, which is unverified and probably wrong.

Source: https://macpaw.com/support/cleanmymac/knowledgebase/space-lens-results ; https://macpaw.com/support/cleanmymac/knowledgebase/space-lens-cleanup

Implication: A 'Selected' segment in the storage bar shows the user what they will gain at a glance. Rescue could reuse Explore's capacity bar with a cyan 'In Cleanup List' segment.

### The Safety Database is CleanMyMac's main trust claim: a remove-or-keep rule set checked on every scan, plus quitting running apps with the user's consent.

Evidence: 'an extensive remove-or-keep reference book built into CleanMyMac,' kept since 2008. It covers app-specific exceptions such as the Spotify offline library in caches. For Safari, Chrome, Electron and JetBrains it gives 'instructions to quit them with your consent and reopen them after cleanup.' (Updated Oct 26, 2026)

Source: https://macpaw.com/support/cleanmymac/knowledgebase/safety-database

Implication: Tessera already has an owner-active check (RescueActionError.ownerActive). Show it as a plain 'Quit Xcode first' line rather than a separate 'handoff' state.

### CleanMyMac explains items through right-click actions (Reveal in Finder, Get Info, Quick Look, Ignore). On macOS 26 it adds a per-item 'Smart Insights' button.

Evidence: 'click the Smart Insights icon next to that item to get more details.' This requires 'macOS Tahoe 26 or later' and Apple Intelligence.

Source: https://macpaw.com/support/cleanmymac/knowledgebase/system-junk

Implication: The baseline every competitor meets is Quick Look, Reveal and Ignore on every row. An on-device explanation is an optional extra.

### CleanMyMac sends the biggest non-junk wins to other modules: unused apps (not opened in 6 months), Large & Old Files, and 'Thin Time Machine snapshots' under Performance.

Evidence: The 'Free up even more space' KB lists three steps: Applications (apps unused for 'over six months'), My Clutter Large & Old Files, and Performance, where 'In the respective tile, click Run' for 'Thin Time Machine snapshots'. The Uninstaller groups are All, Unused, Suspicious, Selected, Stores, Vendors and Plugins, sortable 'by size, name, or the last opened date'.

Source: https://macpaw.com/support/cleanmymac/knowledgebase/free-up-more-space ; https://macpaw.com/support/cleanmymac/knowledgebase/uninstaller

Implication: Even CleanMyMac hides the big wins behind several modules. Rescue can lead with one ranked list across sources: unused apps with their data, large old files, iOS backups, Xcode, snapshots and purgeable space.

### A competitor's review warns that cache cleanup gains are temporary.

Evidence: Smart Care 'found 11.3 GB of junk'... 'What it is not is 11.3 GB of permanent savings.' Most of it is cache that apps rebuild. It also lists 'No top-level undo' as a con. Competitor review (Nektony), Oct 19, 2026, tested on 5.6.1.

Source: https://nektony.com/reviews/cleanmymac-review

Implication: Tag each group as 'Comes back' or 'Freed for good', and rank by lasting space, not raw bytes. This answers the owner's complaint that Rescue misses the real space hogs.

### DaisyDisk's main view is a sunburst map with a sidebar list. A Collector drop zone along the bottom keeps a running total and holds the Delete button. Delete gives a 5-second Cancel window, then deletes permanently.

Evidence: Collector is 'the special area at the bottom'. Items are added by drag, by context menu, or with ⌘⌫. 'the files remain intact until you click the Delete button'. Clicking the Collector opens a list that 'works just like the sidebar', with × to remove an entry. '5 seconds to change your mind and press Cancel.' Deleted items 'cannot be undeleted'. It refuses /System, /Library and the home folder itself.

Source: https://daisydiskapp.com/guide/4/en/DeletingFiles/

Implication: Tessera's Cleanup List already matches the Collector. Keep it as the single, clearly visible place where a deletion is staged. Moving items to the Trash is Tessera's advantage over DaisyDisk's permanent delete.

### DaisyDisk's safety advice is to delete only files you recognise, because your own files usually take more space than system files.

Evidence: 'only delete the files that you can recognize'. 'it is your own files that take up the most disk space, not the system files'. 'make sure your Time Machine is always up and running!'

Source: https://daisydiskapp.com/guide/4/en/WhatToDelete/ ; https://daisydiskapp.com/guide/4/en/LocatingSpaceWasters/

Implication: This directly supports re-centring Rescue on large user-owned items, such as videos, downloads, VMs, game libraries and old backups, presented for the user to recognise rather than to trust a rule.

### DaisyDisk makes unmeasured space visible as a 'hidden space' item. The item breaks down into purgeable space, other volumes and 'still hidden'. Purgeable space can be purged by dragging it to the Collector (not in the App Store edition).

Evidence: 'displays a special item hidden space of the corresponding size.' Purgeable space is 'mostly local snapshots of Time Machine, and also swap files, sleep images'. Purging takes '2-10 minutes', and '7-10 GB' remains. 'not available in the Mac App Store edition'. The disk overview gauge counts purgeable space as free by default. Holding ⌥ shows it as filled.

Source: https://daisydiskapp.com/guide/4/en/HiddenSpace/ ; https://daisydiskapp.com/guide/4/en/PurgeableSpace/ ; https://daisydiskapp.com/guide/4/en/DisksOverview/

Implication: Tessera's 'coverage gaps stay visible' rule fits this. Show one named row ('Hidden or purgeable · 42 GB · why') with a short explanation and a next step, not a separate panel.

### In Apple's System Settings > General > Storage, the order is: a stacked bar, then three Recommendations, then a category list with Info buttons. System Data has no Info button and cannot be managed.

Evidence: Eclectic Light (macOS 26.2): the view 'has three sections'. The recommendations are of 'limited usefulness'. Applications 'can be listed by size or date of last access'. Documents lists 'largest files, older downloads, unsupported 32-bit apps' and has a file browser. Developer cleans Xcode build and device-support files. System Data 'desperately needs further information, but doesn't have a button'. The ⓘ-as-action design is 'shoddy interface design'. Apple: 'You can't manage the contents of this category.'

Source: https://eclecticlight.co/2025/12/20/explainer-storage-settings/ ; https://support.apple.com/en-ng/guide/mac-help/change-storage-settings-mchl3d437fbc/26/mac/26

Implication: Users know this layout from macOS: a bar on top, then categories with sizes. Rescue can match it but should fix its two flaws: give every big row (System Data included) a 'why' line, and use a labelled Review button rather than an ⓘ icon.

### Apple's Storage recommendations are Store in iCloud, Optimize Storage (removes watched Apple TV content and keeps only recent mail attachments) and Empty Trash Automatically (after 30 days). macOS also clears safe caches on its own when space runs low.

Evidence: 'Automatically erase items that have been in the Trash for more than 30 days.' When space runs low, macOS removes caches and logs that are 'safe to delete', including temporary database files, interrupted downloads, staged updates and Safari website data.

Source: https://support.apple.com/guide/mac-help/optimize-storage-space-sysp4ee93ca4/mac ; https://support.apple.com/en-us/102624

Implication: Many cache categories are things macOS clears by itself, which is another reason to rank them below lasting wins. Tessera's Trash default means files stay in the Trash until it is emptied, so Rescue should show Trash size and an 'Empty Trash' handoff.

### Apple's Storage Developer category lets users delete Xcode Caches, Project Archives, and Project Build Data and Indexes. Third parties describe it as coarse.

Evidence: Users select each item and click 'Delete...'. A third-party guide says it 'does not break DerivedData out by project, it leaves DeviceSupport untouched, and it will not prune individual simulator devices.' (third-party, not Apple)

Source: https://support.macincloud.com/support/solutions/articles/8000116168-how-to-resolve-xcode-simulator-unable-to-boot-the-simulator-error ; https://dissectmac.com/blog/clean-xcode-derived-data

Implication: Developer caches are often among the biggest items on a dev Mac. A per-project DerivedData view and per-version DeviceSupport (keeping the newest) would beat Apple's own pane.

### Whether Storage-pane Delete is permanent is not documented by Apple.

Evidence: Apple says only: select a file and click Delete, or Show in Finder. I found no statement on the Trash.

Source: https://support.apple.com/guide/mac-help/find-and-delete-files-on-your-mac-syspf5a64aa6/mac

Implication: Unverified. Do not claim parity with Apple's behaviour. Tessera should say 'Moves to Trash' on the button itself.

### DevCleaner for Xcode preselects Device Support except the latest version of each OS, and sorts DerivedData by size.

Evidence: 'This section is selected by default, with exception of the latest version of each system.' Device Support is 'around 2-5GB per version'. App Store notes: 'sorts derived data by size'. The README warns it relies on 'undocumented features' and says to 'make backup'. Trash or permanent: not stated.

Source: https://github.com/vashpan/xcode-dev-cleaner ; https://apps.apple.com/us/app/devcleaner-for-xcode/id1388020431?mt=12

Implication: The 'keep the newest' rule is used in many tools and is easy to explain. Use it for Xcode DeviceSupport, simulators and iOS backups.

### Mole (tw93, GPL CLI plus a paid Mac app) uses ownership-based checking. Uncertain items are unchecked or hidden. Safety is rechecked at the moment of deletion. Uninstall goes to the Trash, while clean and purge delete permanently.

Evidence: 'Anything uncertain is unchecked by default.' If signals can't be read, the item 'doesn't show at all'. The test for each item: 'Who writes it? Who reads it after a reboot? If I get this wrong, how do I get it back?' Rechecking at delete time avoids 'a report claiming it freed 12GB when it didn't touch a byte.' The README says 'mo uninstall, mo analyze, and mo slim route deletions to Trash'. 'clean, purge, and installer delete permanently.' Summary output: 'Removed: 4.5GB · 97 items', 'Free space: 223.5GB (+4.5GB)'.

Source: https://tw93.fun/en/2026-08-16/mole-mac.html ; https://github.com/tw93/mole

Implication: Tessera already holds stale identities. Copy the result line that shows measured free space before and after. Base the default check state on how costly recovery is: regenerable items start checked, items that need a re-download start unchecked, and personal items are never checked.

### Mole's author lists layout lessons for calm cleanup screens, and records an accessibility complaint about a dark-only UI.

Evidence: 'The result page doesn't appear until the scan is done.' The completion screen 'reserves its space in advance so the window doesn't jump'. 'No new setting when a sensible default exists.' A low-vision user said 'it seems to hardcode dark mode'. The author learned that 'light mode is itself an accessibility need.'

Source: https://tw93.fun/en/2026-08-16/mole-mac.html

Implication: This matters for Tessera's dark and cyan theme. Rescue should respect light mode, Increase Contrast and Reduce Motion, and avoid layout jumps when the plan arrives.

### Nektony App Cleaner & Uninstaller moves removed files to the Trash, keeps a Removal History for undo, and puts leftovers of deleted apps behind an Apps/Remains switch.

Evidence: In version 10 and later, users flip the switch above the list 'from Apps to Remains', select items, click Remove, review the files, then confirm. Files 'go to the Trash first', and Removal History restores them to their original folders. Files that fail to delete are marked with '!'. A 'Detect apps moved to Trash' prompt offers to finish the uninstall.

Source: https://nektony.com/help/app-cleaner/getting-started ; https://nektony.com/how-to/delete-remains

Implication: A per-item failure marker and a restore-from-history action are cheap trust builders that Tessera's result phase could add, since items are already in the Trash.

### Disk Drill Clean Up lists items largest first with coloured size bars (red, yellow, green, white). It keeps a running total of checked items and offers both 'Move to Trash' and 'Delete permanently'.

Evidence: 'The largest folders/files are shown with a long red colored bar.' It has filters by type, keyword and minimum size ('Over: 0 KB'). System and Library folders on the internal drive cannot be checked. The page also says: 'erasing some of them may cause your Operating System to crash.'

Source: https://www.cleverfiles.com/help/how-do-i-use-the-disk-space-visualization-feature/

Implication: Inline size bars on each row make the ranking clear without a chart. Avoid red-for-big: in a cleanup UI, red reads as danger. Use the cyan accent at different intensities.

### OmniDiskSweeper is the minimal reference: Finder-style columns sorted largest to smallest, with Trash and Open actions.

Evidence: 'shows you the files on your drive, largest to smallest, and lets you quickly Trash or open them.' Third parties say it has no safety checks and no category batching, and needs sudo to see protected folders.

Source: https://www.omnigroup.com/more ; https://en.wikipedia.org/wiki/OmniDiskSweeper

Implication: The smallest useful design is 'sorted by size plus Move to Trash'. Rescue's added value over this should be ranking by lasting reclaimable space and explaining each item.

### GrandPerspective (3.8.1, 13 Sep 2026, macOS 14+) draws a treemap. Hovering shows name and size at the bottom of the window. It can colour by size, type or access time, and supports filters.

Evidence: 'The area of the rectangle is proportional to its size.' Hovering shows its 'name and size are then shown at the bottom'. It colours by 'name, extension, file type, ... modification time, or last access time'. It can 'Delete files and folders from the view'.

Source: https://grandperspectiv.sourceforge.net/HelpDocumentation/Views.html ; https://grandperspectiv.sourceforge.net/

Implication: Colouring by last access is a quick visual cue for old, large items. This belongs in Explore, not in Rescue.

### Disk Inventory X links three panes: folder tree, cushion treemap and a file-kind statistics list. Clicking a kind lists its files in a bottom drawer. The last release was 1.3 in 2019.

Evidence: 'The selection is synchronized in all views.' The kind list sorts by colour, size, file count and format.

Source: https://www.derlien.com/screenshots/index.html ; https://en.wikipedia.org/wiki/Disk_Inventory_X

Implication: A 'by kind' summary (Videos 120 GB, Disk images 40 GB, Archives 30 GB) is a quick way to surface large consumers. It could be one Rescue group source.

### I could not verify the Sensei and Pretty Clean cleanup layouts from primary sources.

Evidence: Cindori's page lists 'old caches, system logs, large downloads, and leftover installation files' and has a screenshot labelled 'Sensei Clean Scanner', but it does not describe the layout or Trash behaviour. Pretty Clean's site returned only a title. Softpedia lists v0.1.34 with a 'Developer Mode' for build caches. That listing is old, and the claims are unverified.

Source: https://cindori.com/sensei ; https://pretty-clean.github.io/ ; https://mac.softpedia.com/get/Utilities/Pretty-Clean.shtml

Implication: Do not base design decisions on these two.

### Tessera's current Rescue uses many state words: 11 phases, 5 goals, 3 risk levels, 4 action types and confidence levels. The competitors studied use at most two or three labels.

Evidence: RescuePhase (needsRescue…remembering), RescueGoal (update/install/export/build/normalWork), CleanupRisk (safe/review/protected), RescueAction (stage/inspect/handoff/hold) and CleanupConfidence in Tessera/Engine/CleanupSuggestions.swift:7-150. The view strings include 'Capacity goal', 'Owner handoff' and 'May change:'. CleanMyMac uses only a checked/unchecked state plus Review. DaisyDisk uses only the Collector.

Source: /var/lib/t3code/.t3/worktrees/tessera/codex-tessera-2/Tessera/Engine/CleanupSuggestions.swift:7-150 ; /var/lib/t3code/.t3/worktrees/tessera/codex-tessera-2/Tessera/Views/CleanupSuggestionsView.swift:118-350

Implication: Inference: this vocabulary is a likely cause of 'not easy to understand'. Collapse it to two user-facing states (Ready to add / Check first) plus Protected rows, and drop the goal stepper from the first screen.

## patterns

- Copy: one capacity bar at the top with a 'Selected / In Cleanup List' segment that grows as items are added (CleanMyMac Space Lens: Used/Free/Purgeable/Selected; DaisyDisk Collector running total).
- Copy: rank every group by bytes, largest first, with an inline size bar on each row (OmniDiskSweeper, Disk Drill, Space Lens list, DevCleaner DerivedData). Put small items into an 'Other items' row (Space Lens).
- Copy: tiles or rows with one number and one 'Review' button each, with the long path list one level down (CleanMyMac 5 tiles, praised by Macworld over the old long lists).
- Copy: split by recovery cost. Regenerable junk is preselected with stated exceptions (keep newest iOS backup, keep latest Xcode DeviceSupport per OS, keep module caches and archives). User files (large/old, duplicates, downloads) are never preselected (CleanMyMac Smart Selection vs My Clutter; DevCleaner; Mole).
- Copy: one plain sentence per category saying what it is, whether it comes back, and when to be careful (CleanMyMac system-junk-cleanup-list).
- Copy: a 'Comes back' vs 'Freed for good' tag. Caches regrow within days (Nektony measurement), and macOS clears many of them on its own when space runs low (Apple 102624).
- Copy: Quick Look, Reveal in Finder and Ignore on every row. The review sheet shows the name with the full path underneath (Space Lens Review and Remove, DaisyDisk, Disk Drill).
- Copy: protected locations cannot be checked at all (DaisyDisk refuses /System, /Library and ~; Disk Drill disables System/Library checkboxes; Space Lens blocks system items).
- Copy: a named 'Hidden / purgeable space' row with a breakdown (snapshots, other volumes, still hidden) and the next step (DaisyDisk). CleanMyMac sends this to a 'Thin Time Machine snapshots' task.
- Copy: limit Clean to the category in view so the user never deletes something off-screen (CleanMyMac).
- Copy: after removal, report measured free space before and after, and mark items that failed (Mole 'Free space: 223.5GB (+4.5GB)'; Nektony '!' markers). Offer restore from history, since items are in the Trash (Nektony Removal History).
- Copy: an uninstaller row shows the app's total footprint including support data, sortable by size and last opened, with an 'Unused 6+ months' group (CleanMyMac Uninstaller; Mole's example of 781 MB app + 7.67 GB support folder).
- Copy: a 'by kind' rollup (Videos, Disk images, Archives, VMs) as a quick way to find the biggest items (Disk Inventory X kind statistics; CleanMyMac Large & Old grouping by kind, size and access date).
- Avoid: permanent deletion as the default (CleanMyMac My Clutter, DaisyDisk). Reviewers name it as the main weakness.
- Avoid: an ⓘ icon that leads to actions, and a large unexplained remainder category (Apple Storage 'System Data', criticised by Eclectic Light).
- Avoid: select-all-by-default across tiles (CleanMyMac Smart Care) and 'Clean without reviewing' shortcuts for anything that is not regenerable.
- Avoid: red for 'largest' in size bars (Disk Drill). In a cleanup UI it reads as danger.
- Avoid: layout jumps when results arrive, and results shown before the scan is done. Respect Reduce Motion and light mode (Mole lessons).
- Avoid: many state names (phases, goals, actions, confidence) in the user-facing UI. The competitors studied use at most two or three labels.

## open questions

- Does Apple's Storage-pane 'Delete' move items to the Trash or delete them at once? Apple's docs do not say. It needs a hands-on check on macOS 26 and 27.
- Apple's help now defaults to macOS 27 (Golden Gate). Should Rescue's category names follow the macOS 27 Storage pane, or keep macOS 26 as the target?
- Does CleanMyMac's current Uninstaller and System Junk cleanup use the Trash or delete permanently? MacPaw's KB says permanent only for My Clutter, while Nektony's review says 'go to the Trash'. Unverified.
- Space Lens map type: MacPaw's KB (Aug 2026) and Macworld say bubbles. One search summary claimed version 5.1 moved to a treemap. Unverified, and probably wrong.
- Sensei and Pretty Clean cleanup screen layouts could not be verified from primary sources.
- Should Rescue offer 'Thin local snapshots' or a purgeable-space purge (DaisyDisk drags purgeable space to its Collector, CleanMyMac has a Performance task), given Tessera's held/protected rules and sandbox or App Store limits?
- Which large-consumer sources does Tessera's engine already measure (LargeOldFiles, DuplicateFinder, AppUninstaller, HiddenSpace)? Can they be merged into one ranked list on the first Rescue screen without a new scan?
- Should the capacity goal stepper and RescueGoal picker stay at all, or move behind an advanced control? No studied product asks for a goal before showing results.
