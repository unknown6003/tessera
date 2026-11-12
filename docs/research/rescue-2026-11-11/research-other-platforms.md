# Recovered other platforms

Recovered from the 10 November 2026 Opus research workflow.
Status: source verification pending. This report is research, not a product spec.
No interviews or new participant study took place. Public posts are qualitative evidence only.

I studied about 15 storage tools outside the Mac-cleaner category. Most of them put one cleanup screen next to a usage breakdown. That screen is a short list of cards or sections, and each one says how much space it frees before you act (Files by Google 'Clean xx MB', Windows Cleanup recommendations, iOS recommendations, Docker's RECLAIMABLE column). The actions come in two kinds. Regenerable data gets a one-tap action with no list of items: Files by Google junk, Docker prune, Slack 'Clear Cache and Restart'. User content always opens a 'Select files' review: duplicates, large files, unused apps, Google One categories. Many tools also offer a way to free space without deleting, often ranked as the first choice: iOS Offload App, Dropbox 'Move to online-only', Windows 'Files synced to the cloud', Steam 'move to another drive', and WinDirStat's 'safer first action' table that sends you to the owner's tool. Staleness signals appear next to size: Steam 'last played', npkill last_mod, kondo --older 3M, unused apps. Risk markers sit on the row and do not change the order: npkill shows a warning marker on sensitive folders, and Files by Google puts an 'Original' badge on the kept duplicate. Few measured outcomes are published. Google said the average Files Go tester saved 1 GB in a month-long test, and a Google designer said users deleted more often to see the mascot's success animation. I found no published A/B data for Apple, Microsoft, Valve, Docker or Dropbox. The finding that matters most for Tessera is the sort order. CleanupPlan orders groups by risk first and size second (Tessera/Engine/CleanupSuggestions.swift:654-657), so a 40 GB virtual disk or backup marked 'review' sorts below a 300 MB 'safe' cache. In the references, size shows up front, and safety controls which action a row gets, not where the row sits.

## Findings

### In Files by Google, the Clean area is a stack of category cards. The junk card is a one-tap action, and its button shows the size it will free.

Evidence: 'On the "Junk files" card, tap Clean xx MB', then 'Clear' on a confirmation dialog. The page says junk is temporary app files and that 'App settings are not affected'. It also warns: 'If you clear junk files or delete files using Files by Google, the data will be permanently deleted.' Other cards in the same help set: duplicates, screenshots, downloaded files, large files, memes, WhatsApp media, unused apps, backed-up photos.

Source: https://support.google.com/files/answer/9713869?hl=en

Implication: Put the reclaimable size inside the primary button label, for example 'Move 4.2 GB to Trash'. Use one tap only for the safeRegenerable class. Tessera's rule that Move to Trash is the default is safer than Google's permanent delete for junk. Keep it.

### In Files by Google, the cards for user content (duplicates, large files) open a selection step and then move files to Trash. The original copy carries a badge.

Evidence: Duplicates: 'tap Select files' > select > 'Move x file(s) to Trash', confirmed twice. 'The original file is marked with an "Original" badge. We recommend that you keep the original file.' The large files card follows the same 'Select files' > 'Move x file(s) to Trash/Bin' flow.

Source: https://support.google.com/files/answer/9764075?hl=en ; https://support.google.com/files/answer/10434652?hl=en-gb

Implication: Tessera's duplicate review should mark one copy as 'Keep' (the original) and pre-select only the others. Large-file cards should open the existing Cleanup List review sheet. They should never act in one tap.

### Files by Google's 'Delete unused apps' card needs Usage Access permission. When that permission is missing, the app shows a 'Search for apps' prompt in its place.

Evidence: 'If you can't find the Delete unused apps card, scroll to the Free up more space card and tap Search for apps... turn Permit usage access on.' Then 'Select apps' > Uninstall.

Source: https://support.google.com/files/answer/9765112?hl=en-gb

Implication: When a signal needs a permission (for Tessera, Full Disk Access or app last-used dates), show a card that explains how to unlock it. This fits the rule that coverage gaps stay visible.

### Google's only published outcome figure for Files: the average user saved 1 GB during a month-long test.

Evidence: 'We've been testing Files Go for a month, and the average user is saving 1GB of space.' Categories named: 'unused apps, large files, duplicate files or low-resolution videos and memes'. No sample size or method is given.

Source: https://blog.google/innovation-and-ai/technology/next-billion-users/ready-set-files-go/

Implication: Google's headline metric is space actually freed per user. Tessera can track 'bytes verified freed per Rescue' in its anonymous analytics as the success metric.

### A Google designer reported that a success animation changed deletion behaviour.

Evidence: After each deletion 'the virtual critter waves back-and-forth in joy as confetti explodes behind it'. Kumar: 'People are deleting files more often to see this animation.' Also: '33 percent of smartphone users in India run out of data storage space every day.' This is a talk report, not a controlled study.

Source: https://www.tech.gov.sg/technews/product-design-lessons-from-google/

Implication: A clear, satisfying result state ('Freed 18.4 GB, verified') adds value. Keep it small and restrained to match Ammar's style. Treat the effect as anecdotal.

### iOS and iPadOS Storage shows recommendations above a per-app list. A recommendation is either an Enable toggle or a review screen. Each app row offers Offload (keep data) or Delete.

Evidence: 'Tap [device] Storage to see recommendations and a list of apps with their storage usage.' 'Tap Show All... then tap Enable to turn it on or tap the recommendation to review the contents that you can delete.' 'Offload the app. This frees up storage used by the app, but keeps its documents and data. Delete the app, which removes the app and its related data.' It also notes: 'Cached data and temporary data might not count as usage.'

Source: https://support.apple.com/en-us/108429

Implication: Every recommendation should end in one of two verbs: 'Turn on' (a recurring behaviour) or 'Review' (a list). For apps, split the binary from the data, the same way Offload works. Tessera's AppUninstaller could show 'App 1.2 GB / Data 14 GB' as separate reclaim options.

### The current iOS 27 user guide lists the main space users as categories with a matching action: Photos, Messages, Downloaded videos, Files, Apps. Offload Unused Apps is an automatic setting.

Evidence: 'Photos and videos: Back up... then remove them.' 'Messages: Delete conversations and attachments.' 'Downloaded videos: ...remove ones you've already watched.' 'When storage is low, iPhone can automatically remove unused apps while keeping your data... Tap Apps, tap App Store, then turn on Offload Unused Apps.' In my check, Apple's primary pages did not name 'Review Large Attachments' or show a per-recommendation savings figure. Both remain unverified from Apple sources. Swappa says each recommendation shows its savings.

Source: https://support.apple.com/guide/iphone/manage-storage-on-iphone-iph47c931112/ios ; https://swappa.com/blog/your-iphone-is-full-again-heres-how-to-get-that-storage-back/

Implication: Label groups by content type and the action the user would take ('Downloaded videos you already watched'), not by folder path.

### macOS's own Storage settings already purge safe caches and logs on their own, and offer three recommendations.

Evidence: 'Store in iCloud', 'Optimize Storage', 'Empty Trash automatically' ('erase items that have been in the Trash for more than 30 days'). 'When space is needed, macOS also clears caches and logs that are safe to delete... temporary database files, interrupted downloads, staged macOS and app updates, Safari website data.'

Source: https://support.apple.com/guide/mac-help/optimize-storage-space-sysp4ee93ca4/mac

Implication: Generic caches can be partly purgeable, and macOS may reclaim them anyway, so Tessera should not lead with them. Lead with items macOS will not touch: DerivedData, simulator runtimes, Docker disks, old downloads, large media, iOS backups. Say 'macOS can clear this itself' where that applies.

### Windows 11 Cleanup recommendations uses four fixed sections. Each section shows the savings and has its own 'Clean up' button.

Evidence: 'Start > Settings > System > Storage > Cleanup recommendations'. 'Review each of the categories, including Temporary files, Large or unused files, Files synced to the cloud, and Unused apps'. 'Windows will suggest files for you and show the amount of space you'll save'. 'After you've selected items to remove, select the Clean up button for each section.' It warns that removing a previous Windows install 'can't be undone'.

Source: https://support.microsoft.com/en-us/windows/experience/storage-filemanagement/free-up-drive-space-in-windows

Implication: Use a small fixed set of sections named for the user's intent, each with its own commit button, instead of a single global commit. Pureinfotech says Windows only suggests and 'cannot make the decision to delete files and programs for you'. I did not find Microsoft's ordering logic inside each section (unverified).

### Windows Storage Sense is an opt-in automation with per-category age thresholds. It treats Downloads and cloud files carefully.

Evidence: 'Storage Sense is off by default.' With defaults 'it will run when your device is low on disk space'. Settings: 'Delete files in my Downloads folder if they haven't been opened for more than:', 'Content will become online-only if not opened for more than:'. Since 22H2 the default for OneDrive cloud files is 'online-only if not opened for more than 30 days'. 'Downloads and cloud files will not be touched unless you set up Storage Sense to do so.' 'Any file marked as Always keep on this device is exempted.'

Source: https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5

Implication: Use age as a filter on Downloads and installers ('not opened in 90 days'), off by default. Give the user a way to mark a path 'always keep', which feeds Tessera's existing hold or remember mechanism.

### Google One's storage manager has two sections, 'Clean up suggested items' and 'Clean up by service', plus a cleanup target that appears only when the account is over quota. On mobile it uses swipe triage.

Evidence: Desktop: Storage > 'Clean up space' > 'Clean up suggested items' or 'Clean up by service'. 'At the top right, click Sort'. Permanent delete needs consent: 'read the consent wording... check the box... click Permanently delete'. Android: 'The cleanup target only appears if you're over your storage quota.' 'To mark an item for deletion: Swipe right. To keep an item: Swipe left.' Then 'Review' > Delete.

Source: https://support.google.com/googleone/answer/9776477?hl=en&co=GENIE.Platform%3DDesktop ; https://support.google.com/googleone/answer/9776477?hl=en&co=GENIE.Platform%3DAndroid

Implication: Tessera already has RescueGoal ('Install an update' and others). Turn it into a visible target bar ('Need 12 GB, staged 8.4 GB') that fills as the user adds items to the Cleanup List. A keep/remove triage with keyboard keys (for example K and R) fits large-file review on desktop.

### Gmail and Google storage cleanup works through size and age search filters, and storage figures can lag after deletion.

Evidence: 'has:attachment larger:10M', 'older_than:2y has:attachment'. 'Empty the trash and spam folders. This is the quickest way to recover space'. 'Allow up to 48–72 hours for your storage to update'.

Source: https://support.google.com/mail/answer/6374270?hl=en

Implication: Offer size and age chips ('> 1 GB', 'older than 1 year') on Tessera's large-file list. Count the Trash as a cleanup target of its own, because moving to Trash frees nothing until the Trash is emptied. Show Trash size after the move.

### In OneDrive and Dropbox, the cleanup view is a list of largest files sorted by size. Dropbox adds a non-destructive action and confirms how much space was freed.

Evidence: OneDrive: 'Manage storage... opens a largest files page that shows a list of all files in your OneDrive, sorted by size.' 'you must permanently delete these items in the Recycle Bin to free up space'. Dropbox: 'Manage hard drive space... view and sort files by size and the date they were last modified... Click Move to online-only. A confirmation message will appear indicating the amount of hard drive storage you've freed up.'

Source: https://support.microsoft.com/en-us/onedrive/manage-your-onedrive-for-work-or-school-storage ; https://help.dropbox.com/sync/make-files-online-only

Implication: For files in iCloud Drive, Dropbox or OneDrive folders on the Mac, the better rescue is 'Remove download', not delete. Tessera's owner.cloud group should hand off or offer eviction, and should say that space is freed without data loss.

### Steam's storage manager has one bar per drive split by content type, and below it a multi-select list with size and last played. The actions are Uninstall and Move.

Evidence: Valve's 9 Sept 2021 notes: 'Updated Steam library folder UI for easy content management across multiple drives'. KeenGamer: 'how much storage space your Steam content is using on each drive out of the total available' and 'breakdown... Games vs DLC vs Workshop content'. Each item shows size and 'when you last played it'. 'select multiple items... uninstall or move them to a different drive.'

Source: https://store.steampowered.com/oldnews/88497 ; https://www.keengamer.com/articles/news/valve-overhauls-steam-downloads-and-storage-manager/

Implication: Putting size and 'last used' side by side is the most useful pair of facts for apps, games, simulator runtimes and VMs. 'Move to external drive' is a valid rescue verb for large media and VM images.

### Docker separates TOTAL size from RECLAIMABLE size. Its cleanup lists what it will remove and leaves volumes out by default for safety.

Evidence: docker system df columns: 'TYPE TOTAL ACTIVE SIZE RECLAIMABLE', example 'Images 5 2 16.43 MB 11.63 MB (70%)'. Prune prompt lists 'all stopped containers... all dangling images... unused build cache' then 'Are you sure you want to continue? [y/N]'. Volumes are skipped by default 'to prevent important data from being deleted'. Output ends with 'Total reclaimed space: 13.5 MB'. The Disk Usage extension offers 'an easy one-click experience to reclaim space'.

Source: https://docs.docker.com/reference/cli/docker/system/df/ ; https://docs.docker.com/reference/cli/docker/system/prune/ ; https://hub.docker.com/extensions/docker/disk-usage-extension

Implication: Show reclaimable bytes, not folder size. A 64 GB Docker.raw is not 64 GB reclaimable. Tessera should hand off to Docker ('docker system df' shows X reclaimable) rather than stage the disk image. A Rancher Desktop issue (third-party) says pruning does not shrink the VM file on the host: https://github.com/rancher-sandbox/rancher-desktop/issues/2398.

### npkill lists node_modules folders by size and age and marks sensitive folders with a warning marker. It supports a dry run and an option to exclude sensitive folders.

Evidence: '-s, --sort... size, path or age'. Shows 'the last time you modified a file in the workspace (last_mod column)'. 'NPKILL will highlight them by displaying a ⚠️ to be careful.' '-x, --exclude-sensitive', '--dry-run', '--older-than'. Known bug: 'Sometimes, size calculations are higher than they should be.'

Source: https://github.com/voidcosmos/npkill

Implication: For dev artifacts, show project name, artifact size and last modified on one row. Flag folders that an installed app depends on (for example Electron apps under /Applications) instead of hiding them.

### kondo finds projects by marker file, then targets the known artifact folders for that project type. It asks per project (yes/no/all/quit) and ends with a byte total.

Evidence: lib.rs maps marker to folders, for example Cargo.toml→target; package.json→node_modules,.angular; Package.swift→.build,.swiftpm; Podfile→Pods; pubspec.yaml→build,.dart_tool. main.rs prompt: 'delete above artifact directories? ([y]es, [n]o, [a]ll, [q]uit)'. Summary: 'Projects cleaned: {}/{}, Bytes deleted: {} / {}'. The README offers 'kondo --older 3M' and warns it is 'essentially rm -rf with a prompt'.

Source: https://github.com/tbillington/kondo ; https://raw.githubusercontent.com/tbillington/kondo/master/kondo-lib/src/lib.rs ; https://raw.githubusercontent.com/tbillington/kondo/master/kondo/src/main.rs

Implication: Tessera's dev.buildoutput and dev.node_modules rules can use the same marker-file mapping, which has fewer false positives than matching the folder name 'build'. Group by project, filter to stale projects (no change in 3+ months), and report the result as cleaned/total.

### Xcode manages simulator runtimes in its own settings pane, which shows sizes. simctl has deletion filters based on age and state.

Evidence: Third-party guides say Xcode > Settings > Components (earlier 'Platforms') lists runtimes with size and a delete option, and that 'Starting with Xcode 14, that panel also shows when you last used the runtime' (unverified from Apple). 'xcrun simctl runtime delete' with '--notUsedSinceDays 365', '--dry-run' (unverified from Apple). A forum thread reports an orphaned runtime under /System/Library/AssetsV2 that is SIP-protected and missing from the GUI.

Source: https://cleanwithcrumb.com/blog/how-to-delete-unavailable-simulators-in-xcode-and-recover-gbs-2026/ ; https://developer.apple.com/forums/thread/812992 ; https://developer.apple.com/forums/thread/773153

Implication: Simulator runtimes (5–8 GB each, per third-party estimates) are among the biggest developer hogs. Tessera should present them as a handoff with the exact command or settings pane, not stage the files. Files under /Library/Developer/CoreSimulator and AssetsV2 should stay protected.

### WinDirStat publishes a table that maps each kind of space hog to its 'safer first action', mostly the owning tool. Its Delete key goes to the Recycle Bin, and permanent delete is a separate shortcut.

Evidence: 'Installed applications are large → Use Launch Program & Features'. 'Virtual disks are large → Clean space inside the VM first, then use Optimize VHD Files'. 'Recycle Bin is large → Use Empty Recycle Bin'. 'Delete (to Recycle Bin) | Delete' vs 'Delete Permanently | Shift+Delete'. 'Do not use WinDirStat as a substitute for an uninstaller'. Confirmation prompts can be configured per destructive action.

Source: https://github.com/windirstat/windirstat/wiki/Cleaning-Up

Implication: This matches Tessera's RescueAction.handoff ('Use owner app'). Give each handoff group a specific next step (button or command) so the biggest items stay actionable even when Tessera will not delete them itself.

### WizTree, WinDirStat and TreeSize are analyzers first. Their cleanup surface is a 'Largest Files' list or tab, a duplicates view and a treemap. None of them publishes a recommendation engine.

Evidence: WizTree: 'Find the largest files on your hard drive', 'Find duplicate files', correctly handles hard links. WinDirStat 2.2 changelog 'added the Largest Files tab'. The wiki says the tab is for 'quickly inspecting the largest individual files'. TreeSize: 'Filter for Top Largest Files and Identify Space Hogs', with mass delete and move. The product page describes no automated recommendations.

Source: https://www.diskanalyzer.com/ ; https://github.com/windirstat/windirstat/blob/master/CHANGELOG.md ; https://github.com/windirstat/windirstat/wiki/Reading-Results ; https://www.jam-software.com/treesize

Implication: Even pure analyzers added a flat 'largest files' list because tree navigation hides big leaves. Rescue should include a flat 'Largest items on this Mac' card that crosses all categories, not only categorized suggestions.

### Chrome lists every site's stored data with a 'sort by data stored' option and a total-with-clear-all control. Slack offers a single cache reset.

Evidence: The Chromium all_sites.html defines sort methods MostVisited, Storage and Name, and a 'Clear all storage' element showing totalUsage_. Chrome Help: 'View permissions and data stored across sites'. Slack: Help > Troubleshooting > 'Clear Cache and Restart'. Slack files 'must be deleted individually', and space can take 'up to 48 hours' to return.

Source: https://chromium.googlesource.com/chromium/src/+/d1a55d521ccd806e01f08e5e1f9a6f11df83cbb3/chrome/browser/resources/settings/site_settings/all_sites.html ; https://support.google.com/chrome/answer/114662?hl=en&co=GENIE.Platform%3DDesktop ; https://slack.com/help/articles/205138367-Troubleshoot-connection-issues

Implication: App-owned caches (browser, Slack, Electron) are best handed to the app's own reset. Tessera's browser.cache and owner.communication groups should name the in-app control and check that the app is closed (Tessera already tracks CleanupOwnerState).

### Android's built-in Settings > Storage > Free up space works the same as Files by Google: category lists with 'Select files' and 'Move files to Trash', plus an opt-in Smart Storage automation. It separates Clear cache from Clear storage.

Evidence: 'Scroll to the category you want... Tap Select files... You can also select all files in the list... tap Move files to Trash.' Smart Storage clears 'backed-up photos and videos when your device's storage is almost full'. 'Clear cache: Deletes temporary data. Some apps may be slow the next time.' 'Clear storage: Permanently deletes all app data.'

Source: https://support.google.com/android/answer/7431795?hl=en ; https://support.google.com/files/answer/10862356?hl=en

Implication: Write each side effect as one plain sentence, the way Tessera's sideEffect strings already do ('Some apps may be slow the next time'). Put that sentence on the card itself, not only in a detail sheet.

### Tessera's Rescue sorts by safety before size, which is the opposite of the size-first habit seen in the references.

Evidence: CleanupPlan.init sorts groups with 'if $0.risk != $1.risk { return riskOrder... } return $0.totalBytes > $1.totalBytes'. rankedRecommendations sorts the same way. So every 'safe' group sorts above every 'review' group, whatever its size.

Source: Tessera/Engine/CleanupSuggestions.swift:654-657, 676-681

Implication: This explains the complaint 'does not tackle the biggest space hogging things'. The references keep a size-first view (largest files, Docker RECLAIMABLE, Steam size column) and express safety through the action type (one-tap, review, move, handoff). Add a size-sorted 'Biggest wins' row on top, where each item shows its action badge.

## patterns

- One headline number, then cards: the total you can free now, followed by 4–6 intent-named cards (Junk, Duplicates, Large files, Unused apps, Old downloads). Each card shows its own size. Sources: Files by Google, Windows Cleanup recommendations, iOS Storage.
- Size in the button: 'Clean xx MB' (Files by Google) and 'Move 4.2 GB to Trash'. The user sees the payoff before acting.
- Two-tier actions by data class: one tap for regenerable data (junk, build cache, app cache reset), and 'Select files' review for user content (large files, duplicates, apps). Never one tap on user content.
- Show what is reclaimable, not total size. Docker's TOTAL / ACTIVE / SIZE / RECLAIMABLE (70%) columns are the model for VM disks, caches and anything with in-use parts.
- Free space without deleting, offered first: Offload app (keep data), Move to online-only or Remove download, Move to another drive (Steam), Files synced to the cloud (Windows).
- Hand off to the owner, with an exact next step: WinDirStat's 'safer first action' table, Xcode Components or simctl for runtimes, Docker prune for Docker.raw, the app's cache reset for Slack or Chrome.
- Size and last used side by side on every row: Steam size + last played, npkill size + last_mod, Dropbox size + last modified, kondo --older 3M filter.
- Goal or target bar: Google One shows a cleanup target when over quota. Tessera can fill a 'Need 12 GB' bar as items are staged, using its existing RescueGoal.
- Keep/remove triage for long lists: Google One's swipe right (delete) and swipe left (keep), adapted to keyboard keys on desktop.
- Inline risk markers instead of hiding items: npkill's warning marker on folders apps depend on, and the 'Original' badge on the duplicate copy to keep.
- Post-action receipt: Docker 'Total reclaimed space', Dropbox's freed-space confirmation, kondo 'Projects cleaned: x/y, Bytes deleted'. Add delay or Trash caveats (Google 48–72 h, OneDrive recycle bin must be emptied).
- Automation as an opt-in toggle in the same surface: iOS 'Enable', Windows Storage Sense (off by default, age thresholds, 'Always keep' exemption), Android Smart Storage, macOS 'Empty Trash automatically'.
- Flat 'Largest files' list next to categories: WinDirStat added this tab in 2.2, and WizTree, TreeSize and OneDrive all lead with it.
- Avoid: permanent delete hidden behind a friendly 'Clean' button (Files by Google junk). Google One requires a consent checkbox for permanent delete. Tessera's Trash-first default is stricter. Keep it.
- Avoid: sorting safe-but-small above large-but-review items. No reference sorts by risk before size.

## open questions

- How does Files by Google order its Clean cards: by size, by fixed priority, or adaptively? Unverified; I found no published spec.
- Does iOS show a per-recommendation savings figure, and how are the recommendations ordered? Only third-party sources say yes. Apple's primary pages do not say.
- How does Windows order items inside each Cleanup recommendations section, and which build introduced the feature? Unverified.
- Do any of these vendors publish A/B or retention data on cleanup UI? I found only Google's 1 GB per month and the mascot anecdote.
- Is the Xcode Components 'last used' column and the simctl --notUsedSinceDays filter present in the Xcode version Tessera targets? Third-party sources only.
- Should Tessera compute Docker-style reclaimable space (for example by calling 'docker system df') or only hand off? That needs a decision on running owner CLIs.
- Should 'Biggest wins' include handoff items (VM disks, runtimes, iOS backups) that Tessera cannot stage itself, or only items it can stage?
