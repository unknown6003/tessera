# Recovered code audit

Recovered from the 10 November 2026 Opus research workflow.
Status: source verification pending. This report is research, not a product spec.
No interviews or new participant study took place. Public posts are qualitative evidence only.

I read the code only and changed nothing. Rescue is one long scrolling page. The order is: a title block, a capacity card, a coverage card, three risk sections (Safe to review, Review first, Protected), and then a block of numbers and settings at the bottom. Groups are sorted by risk tier first and by size second (CleanupSuggestions.swift:654-659). A small safe Xcode group therefore always sits above a 40 GB Downloads folder or a 100 GB VM, which explains much of "does not tackle the biggest space hogging things". The engine has 18 categories built from name and path rules. Once a folder matches a rule, its contents are not looked at, so ~/Library/Caches and ~/Downloads each show up as one large blob. The Homebrew, browser, Yarn, pip and CocoaPods rules therefore never fire on a normal home or whole-disk scan. Only directories are tested against the rules, so Docker.raw, .qcow2 and .vmdk disk files are never shown even though the rules name them. Any coverage gap turns every "safe" item into "review", and that includes the Hidden Space wedge that every whole-disk scan with more than 1 GiB unseen gets. On most real scans the safe tier and its "Add all safe" button probably never appear (inferred from the code, not tested on a Mac). Many big consumers are not detected at all: Xcode Archives and simulators, Photos, Mail, Music, Steam, Final Cut and Logic libraries, pnpm/Maven/conda/Go/AI-model stores, .zip/.xip installers and unused apps. APFS snapshots and purgeable space can be reached only through Explore's Hidden Space wedge. The default action, Move to Trash, frees no space until Trash is emptied, and Rescue has no Empty Trash step. The verify step also compares bytes for exact equality, so it will almost always end on "Removed, but reclaimed space is not proven". The scanner already stores allocated and logical sizes, modification time, kind, inode/device identity and cloud and mount boundaries for every item. Splitting the cache blobs, matching big files by name and adding age would cost almost nothing. Unused-app dates, simulators, snapshot sizes, Photos/Mail/Messages and iOS backups need Spotlight, simctl, tmutil or Full Disk Access.

## Findings

### Rescue page order, top to bottom (plan present): header -> saved-case banner -> capacity card -> result/error card -> coverage card -> 'Suggested cleanup' header -> Safe / Review / Protected sections -> secondary figures + goal stepper + definitions -> optional review footer.

Evidence: planView: planHeader(45), savedCaseRow(46-50), measurementCard(51), verificationCard/resultErrorCard(53-57), coverageCard(59), candidatesHeader(62), candidateSection x3 (64-104), emptyCandidates(106), measurementDetails(111); body adds reviewFooter only when the dock is hidden (28-30; ContentView.swift:452 passes nil when dockIsVisible).

Source: Tessera/Views/CleanupSuggestionsView.swift:43-113

Implication: Before the first group the user has to read 4 blocks: title, capacity, coverage and the list header. The one control the user can change (the goal stepper) and the definitions of the figures sit at the very bottom, under all the groups.

### Header copy: 'Rescue space', the monospaced source path, 'File analysis runs on this Mac. Review the paths before anything moves.', a one-line summary '<X> safe to review · N groups to check first', and a phase badge from the internal state machine.

Evidence: Text("Rescue space") 118; Text(plan.sourcePath) 120; privacy line 127; resultSummary 143-154 counts review *groups* not bytes; phaseBadge 156-160 uses RescuePhase.title: 'Ready to scan','Building diagnosis','Plan ready','Review candidates','Ready to move','Confirm Move to Trash','Removing items','Verifying space','Rescue result','Saved on this Mac' (CleanupSuggestions.swift:20-33).

Source: Tessera/Views/CleanupSuggestionsView.swift:115-168

Implication: The headline never says how much the user could free in total. The safe figure is often empty (see the coverage finding), and the review figure is a group count, not a size. The phase badge shows state-machine jargon ('Review candidates', 'Plan ready') that means nothing to a user.

### Capacity card: big number '<available>' labelled 'Available for use' (or 'Free now'), right-aligned target '<bytes>' + 'more space needed to reach 75% used' or 'On target' + '75% used limit met', a progress bar, caption 'Goal: under 75% used'. The bar's value is available/total, i.e. the FREE share, while the caption speaks of USED share.

Evidence: primaryLabel 794-796; targetTitle 880-885; targetLabel 887-895; capacityFraction returns Double(primary)/Double(total) 904-908 and feeds ProgressView 219-223; caption 228. RescuePlan.targetSpace = total*(1-capacityGoal) (CleanupSuggestions.swift:864-869); default goal 0.75, range 0.50-0.95 (821-822).

Source: Tessera/Views/CleanupSuggestionsView.swift:170-237

Implication: On a full disk the bar is almost empty, the opposite of Finder's 'used' bars. It has no goal marker and is not linked to the suggestions. Nothing says 'adding these gets you to X%'. The 75% goal is an arbitrary default.

### Bottom block: 'Free now', 'Logical', 'Physical' metrics; 'Capacity goal' / 'Keep used space under' / 'Adjust with the stepper.' with a 5% stepper; 'Measured locally · macOS available capacity'; definitions 'Available for use counts space macOS can reclaim by removing caches and other purgeable files…' and 'Capacity figures cover the whole drive that holds this source. Logical and physical totals cover only the scanned source.'

Evidence: measurementDetails 239-269; capacityGoalControl 271-302; capacityNotes 799-820; metric labels 244-245.

Source: Tessera/Views/CleanupSuggestionsView.swift:239-302

Implication: 'Logical' and 'Physical' are file-system jargon with no action attached. The drive-versus-folder note admits the figures mix two scopes. When a folder is scanned, the target is for the whole drive but the suggestions cover only that folder.

### Coverage card: 'Coverage complete' / 'Coverage is partial' / 'Coverage blocked' with up to 8 notes such as 'Could not inspect <path>.', 'Some space is outside the file scan, such as snapshots or protected data.', 'Some provider items are online-only or were not opened during the scan.', 'A mounted volume is shown as a separate boundary.', '<n> more coverage gaps are held.'

Evidence: RescueCoverage.inspect notes and titles; card render 304-338 in the view.

Source: Tessera/Engine/CleanupSuggestions.swift:783-817

Implication: The card sits above the suggestions and can add up to 9 lines of raw paths and jargon ('boundary', 'held'). It also has no action: no 'Grant Full Disk Access' button and no link to Hidden Space.

### Suggested cleanup header and sections: 'Suggested cleanup' + item count + 'Add only what you want to the Cleanup List. Tessera never removes a file from this screen.'; 'Safe to review' (subtitle 'Known generated files. They can be rebuilt, but the next build may take longer.', button 'Add all safe · <size>' / 'Added to review'); 'Review first' ('These may be useful, shared, active, or tied to an owner app. Nothing is added automatically.'); 'Protected' ('Tessera will not stage these. Use the owner app or keep them in place.').

Evidence: candidatesHeader 340-354; sections 64-104. The count uses report.recommendations.count, which includes zero-byte items that groups drop (CleanupSuggestions.swift:644).

Source: Tessera/Views/CleanupSuggestionsView.swift:61-104

Implication: 'Safe to review' mixes two ideas. The item count can differ from the rows shown. The subtitle 'Nothing is added automatically' sits next to a per-group 'Add' button that adds every item in that group with one click.

### Group row: chevron, SF symbol, category title, '<n> items · <category explanation>', size, risk tag, and 'Add'/'Added' (or the text 'Owner handoff' for Protected). Expanded item row: circle toggle, name, risk capsule, size, one-line reason, and a 'Details' disclosure with path, '<x> allocated · <y> logical', 'owner · confidence · action', 'May change: …', and proof lines.

Evidence: groupRow 395-477; recommendationRow 479-564; proof strings 'Rule: xcode.deriveddata', 'Rule version: rescue-2026-08-31.1', 'Stable scan identity: captured', 'Owner state: stopped', 'Measured allocated size: N bytes' (CleanupSuggestions.swift:292-306); action titles 'Can be staged','Inspect before staging','Use owner app','Keep protected' (100-107); confidence titles 'High','Review','Protected' (151-156).

Source: Tessera/Views/CleanupSuggestionsView.swift:395-564

Implication: The risk is shown three times (section heading, group tag, item capsule). Proof lines are raw engineering output with byte counts. No row shows age or last-modified date, though modTime exists. 'Owner handoff' looks like an action but is plain text with no button.

### The reason a safe item was moved down to review is appended to the end of the reason text, but the row cuts that text to one line.

Evidence: Demotion text appended: '…The scan has coverage gaps, so it stays in review until a fresh scan completes.' etc. (CleanupSuggestions.swift:264-277); row shows Text(recommendation.reason).lineLimit(1).truncationMode(.tail) (CleanupSuggestionsView.swift:523-528). The group row shows category.explanation, not the reason (427).

Source: Tessera/Views/CleanupSuggestionsView.swift:523-528

Implication: Xcode Derived Data can sit under 'Review first' with the text 'Build intermediates Xcode can regenerate…' and no visible reason why it is not safe.

### Any coverage gap moves every safeRegenerable item down to review. On a whole-disk ('/') scan, the Hidden Space node is added whenever more than 1 GiB is unseen, and that alone makes coverage 'partial'. The safe tier and 'Add all safe' then disappear.

Evidence: CleanupRecommendation init demotes when !coverageComplete (250-258); classify called with coverageComplete: coverage.state == .complete (ScanViewModel.swift:246-248); inspect marks .hiddenSpace, .cloudOnlyStorage, .crossVolume and any scanCoverageGaps as partial (783-808); attachHiddenSpace adds the node on volume-root scans when hidden > 1 GiB (FileScanner.swift:62, 787-799).

Source: Tessera/Engine/CleanupSuggestions.swift:250-258

Implication: Inferred from code, needs a check on a real Mac: on typical Macs with snapshots/purgeable space, iCloud online-only folders, Simulator mounts, or no FDA, Rescue will likely show zero safe items. The one-click path does not exist in practice.

### Groups are ordered by risk tier (safe < review < protected) and only then by total bytes. Items follow the same order.

Evidence: groups.sorted { risk order first, then totalBytes desc } (654-659); rankedRecommendations same (677-682); riskOrder safe=0, review=1, protected=2 (662-668).

Source: Tessera/Engine/CleanupSuggestions.swift:654-682

Implication: A large consumer in Review or Protected always ranks below a small safe group. This is the direct cause of 'does not tackle the biggest space hogging things'. Size never leads the page.

### All 18 categories and their rules (first match wins, in this order): Protected: owner.backup (path contains /library/application support/mobilesync/backup or /time machine/, name *.backupbundle, backups.backupdb, 'backups' under /volumes/); owner.virtualdisk (docker.raw, *.qcow2, *.pvm, *.utm, *.vmdk, ~/.docker, ~/.parallels); owner.cloud (Library/CloudStorage, Library/Mobile Documents); owner.profile (Chrome, Edge, Brave, Firefox, VS Code under Application Support); owner.communication (Library/Messages, Discord, Telegram, WhatsApp, Signal); system.trash (.trash/.trashes). Safe: xcode.deriveddata (exact ~/Library/Developer/Xcode/DerivedData), xcode.devicesupport (*DeviceSupport directly under Xcode/). Review: dev.node_modules (any node_modules), adobe.mediacache, adobe.cameraraw, dev.packagecache (Caches/Homebrew, _cacache, .gradle/caches, cocoapods caches/repos, .cache/yarn, .cargo/registry/cache), browser.cache, system.caches (folder named caches whose path contains /library/caches), dev.buildoutput (build/target/dist/.next/out under /developer/, /documents/, /projects/, /code/, /src/), system.logs (Library/Logs), user.installers (*.dmg/*.pkg/*.iso), user.downloads (folder 'downloads' under /users/).

Evidence: CleanupCatalog 311-415; CleanupClassifier.rules 422-507; ruleVersion 'rescue-2026-08-31.1' 420.

Source: Tessera/Engine/CleanupSuggestions.swift:422-507

Implication: There is no size threshold, no age test and no ranking by reclaim confidence. Only the two Xcode rules can ever be 'safe'. Everything else is review or protected.

### A matched directory hides its contents ('subsumed'), so ~/Library/Caches and ~/Downloads each become one opaque item. The rules for Homebrew, CocoaPods, browser caches and Yarn under ~/Library/Caches can never fire on a home or '/' scan.

Evidence: classify: on rule match append and 'continue' without considering children (603-608). ~/Library/Caches matches system.caches (488-490) before any child is visited. ~/Downloads matches user.downloads (504-506), so installers inside it are never listed. Browser cache paths (482-487) live under ~/Library/Caches or under protected profile roots (441-447), so browser.cache only fires when the scan source is inside those folders.

Source: Tessera/Engine/CleanupSuggestions.swift:599-614

Implication: The biggest cache folders show as one item, e.g. 'Caches 30 GB' or 'Downloads 60 GB', with no breakdown. Pressing 'Add' stages the whole ~/Library/Caches or the whole ~/Downloads folder as one unit. This is cheap to fix because the children are already in the tree.

### Only directories are tested against the rules. For files, only the .dmg/.pkg/.iso installer test runs. So the file-name rules for Docker.raw, .qcow2 and .vmdk can never produce a Rescue row.

Evidence: consider(): directories are pushed to the stack; files only get the installer suffix test (589-594). Docker.raw lives at ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw (a file), and no ancestor matches '/.docker'. addToCollector's protectedCategory(for:) does test the file path (ScanViewModel.swift:495), so Docker.raw is blocked from the collector but never shown in Rescue.

Source: Tessera/Engine/CleanupSuggestions.swift:583-596

Implication: Docker and qcow2/vmdk VM disks, often the single largest item on a developer Mac, are invisible in Rescue. A file-name pass would be pure CPU over the existing tree.

### Owner-safety covers only Xcode. CleanupOwnerState checks whether Xcode, its build system or Previews are running; every other category gets ownerState .unknown.

Evidence: CleanupOwnerState.current() bundle IDs (127-136); ownerState forced to .unknown for non-safe categories (289); holdIfRescueOwnerIsActive is the final check (ScanViewModel.swift:1062-1073).

Source: Tessera/Engine/CleanupSuggestions.swift:125-136

Implication: Promoting any new category to safe needs a matching owner check (Docker, Simulator, browsers and so on). This is the main cost of widening the safe tier.

### Sizes: each item shows physicalBytes (allocated, recursive for folders). logicalBytes exists only for files. Group size is the sum of item physicalBytes. There is no clone, sparse-file or hard-link reclaim estimate beyond scanner-level hard-link dedup.

Evidence: physicalBytes = node.physicalSize = size (286-287; FileNode.swift:327); group totalBytes (627); FileNode.logicalSize set only from identity, nil for directories (FileNode.swift:232-234, 280); BulkReader requests ATTR_FILE_DATALENGTH and ATTR_FILE_ALLOCSIZE (BulkReader.c:100-101).

Source: Tessera/Engine/CleanupSuggestions.swift:286-287

Implication: Allocated size is the right figure for 'space freed', but APFS clones and shared snapshots can make the real reclaim smaller. The results card exposes this as a mismatch instead of setting expectations before the user acts.

### Moving to Trash frees no space. Rescue treats Trash as Protected and has no Empty Trash step. Its verification also compares moved bytes with measured change by exact equality, so the result is almost always flagged.

Evidence: trash category sideEffect 'Empty Trash is a separate action and is not part of Rescue.' (378-382); recoveryNote 'Trash still uses disk space until you empty it.' (931-935); hasMeasurementMismatch returns movedBytes != verifiedReclaimedBytes (947-951), giving status 'Removed, but reclaimed space is not proven' (958). The dock offers only 'Show Trash' (CollectorDock.swift:129). grep finds no Empty Trash action anywhere.

Source: Tessera/Engine/CleanupSuggestions.swift:947-958

Implication: The default safe path cannot reach the capacity goal it shows. The research doc records a 'separate Empty Trash step' as a settled decision (docs/research/tessera-disk-rescue-ethnographic-study.md:490), but it is not built.

### Big consumers that are detected: Xcode DerivedData and iOS/watchOS DeviceSupport (safe, but often moved to review); node_modules (review, one item each); npm _cacache, Gradle caches, Cargo registry cache (review); Adobe Media Cache, Camera Raw cache (review); ~/Library/Caches as one blob; ~/Library/Logs; ~/Downloads as one blob; loose .dmg/.pkg/.iso outside matched folders; build/target/dist/.next/out only under certain path words; Parallels .pvm and UTM .utm bundles (protected); MobileSync backups (protected); Messages, Discord, Telegram, WhatsApp, Signal (protected); iCloud and CloudStorage (protected); browser and VS Code profiles (protected); ~/.Trash (protected).

Evidence: Rules 422-507; buildOutput path words 493-497; virtual disk 431-436.

Source: Tessera/Engine/CleanupSuggestions.swift:422-507

Implication: Protected items are listed, but the only 'action' is the text 'Owner handoff'. No button opens Docker, Parallels, Finder Trash or the Messages settings, so even the protected tier is a dead end.

### Partly detected: Rust target dirs (only under /developer/, /documents/, /projects/, /code/ or /src/); Yarn (rule checks ~/.cache/yarn, but on macOS Yarn uses ~/Library/Caches/Yarn, which is subsumed); Homebrew, CocoaPods and pip caches (under ~/Library/Caches, subsumed); browser caches (rule effectively dead on normal scans); Downloads installers (subsumed into the Downloads blob); iOS Simulator runtimes (shown only as synthetic crossVolume nodes in Explore, which Rescue skips); Trash (protected only, and ~/.Trash likely needs FDA to read); Time Machine local snapshots and purgeable space (HiddenSpaceView, reachable only from Explore).

Evidence: packageCache rule 475-481; buildOutput 493-497; classify skips isSynthetic children (584); attachCrossMounts sizes mounts from getmntinfo (FileScanner.swift:829-871); HiddenSpaceView is shown only in InspectorView when node.kind == .hiddenSpace (InspectorView.swift:47-48).

Source: Tessera/Engine/CleanupSuggestions.swift:475-497

Implication: Most developer caches already exist in the tree but are hidden inside larger matches. Splitting them out is mainly a rule-order and descend change, with no new I/O.

### Not detected at all: Xcode Archives (~/Library/Developer/Xcode/Archives, *.xcarchive), CoreSimulator Devices and Caches (~/Library/Developer/CoreSimulator), the Docker.raw file, VMware *.vmwarevm, qcow2/vmdk files, pnpm store (~/Library/pnpm), Maven ~/.m2, conda pkgs, Go ~/go/pkg/mod, pip, AI model stores (~/.cache/huggingface, ~/.ollama), Photos Library.photoslibrary, Mail and Mail Downloads, Music/Podcasts/TV downloads, Steam steamapps, Final Cut .fcpbundle render and transcode files, Logic and GarageBand sound libraries, general Application Support bloat, .zip/.xip/.tar archives, old installers by age, large and old files, duplicates, unused apps, APFS snapshots and purgeable space in Rescue itself, and 'System Data'.

Evidence: There is no rule or catalog entry for any of these in CleanupCatalog.all (409-414) or CleanupClassifier.rules (422-507). '.photoslibrary', '.fcpbundle', '.xcarchive' and '.vmwarevm' are not in packageExtensions (BulkDirScanner.swift:28-33), so they are plain folders with no rule. Photos Library is also not in the protected rules, so Explore can stage it to Trash.

Source: Tessera/Engine/CleanupSuggestions.swift:409-507

Implication: The largest typical Mac consumers (Photos, Docker, simulators, iOS backups, game and media libraries, AI models) are absent or appear only as opaque blobs. Photos Library is not protected; this is a safety gap next to the Rescue work.

### Installers rule: only the suffixes .dmg, .pkg and .iso. No .zip or .xip, no age test, no Downloads-specific logic, and any loose installer anywhere outside a matched folder is flagged.

Evidence: consider() installers test (591-594); rule (501-503).

Source: Tessera/Engine/CleanupSuggestions.swift:501-503

Implication: 'Old installers in Downloads' needs Downloads to be descended into instead of treated as one item, plus an age test (modTime is already stored).

### Per-node data the scanner already has: name, isDirectory, kind (regular/package/hiddenSpace/aggregate/cloudOnlyStorage/crossVolume), modTime in ns (ATTR_CMN_MODTIME; for folders this is the folder's own mtime, not the newest file inside), allocated size (recursive), logical size (files only), identity (device, inode, resource type, logical and allocated size, mtime), parent and children, root scanCoverageGaps. The scanner reads dataless flags and link counts, but does not keep them on the node.

Evidence: FileNode fields and Kind (FileNode.swift:126-234); attributes requested from getattrlistbulk: NAME, DEVID, OBJTYPE, MODTIME, FLAGS, FILEID, LINKCOUNT, DATALENGTH, ALLOCSIZE (BulkReader.c:92-101).

Source: Tessera/Model/FileNode.swift:126-234

Implication: Free to add (pure CPU over the tree): splitting cache blobs, finding Docker and VM files, Xcode Archives and CoreSimulator Devices, AI-model folders, installers and archives by age, and largest-first ranking. Not available: access time, date added, last-used date, xattrs (quarantine/where-from), and APFS clone or purgeable flags. Each would need new attributes or other APIs.

### The scanner only sees the chosen source and skips /Volumes, /System/Volumes, /dev and /Network. Hidden Space exists only on volume-root scans.

Evidence: skippedPaths (FileScanner.swift:65-70); attachHiddenSpace guards isVolumeRoot and hidden > 1 GiB (787-799); RescueMeasurement captures capacity for the whole volume but tree totals only for the source (CleanupSuggestions.swift:704-715).

Source: Tessera/Engine/FileScanner.swift:62-70

Implication: If the user scans a project folder or an external drive, Rescue shows a drive-wide 'more space needed' figure but suggestions from that folder only. Home-level caches need either a home or '/' scan, or targeted reads outside the scanned source.

### Cost of new detection outside the tree: snapshots need /usr/bin/tmutil (list only, no sizes; delete may need admin). Purgeable space needs volume resource keys (cheap). Unused apps need Spotlight kMDItemLastUsedDate (the uninstaller has no last-used signal). MobileSync, Messages, Mail, ~/.Trash and Safari need Full Disk Access. Photos needs FDA or Photos access and should be handed to the Photos app. Other apps' ~/Library/Containers (Docker, UTM) may trigger the App Data permission prompt on macOS 14+. Simulators are best handled with xcrun simctl (delete unavailable devices, runtimes).

Evidence: HiddenSpaceAnalyzer.listSnapshots and deleteSnapshot run tmutil (HiddenSpace.swift:57-80); purgeableBytes from URL keys (46-54); FDA probe on TCC.db and Safari Bookmarks (ScanViewModel.swift:1250-1270); AppUninstaller enumerates /Applications and ~/Applications and leftover dirs with no last-used logic (AppUninstaller.swift:90-99, 145-170).

Source: Tessera/Engine/HiddenSpace.swift:44-80

Implication: The cheap wins are tree-only rules. Snapshot, purgeable and Trash summaries are cheap but involve processes or permissions. Unused apps (Spotlight), simulators (simctl) and protected personal stores (FDA plus owner handoff) cost the most.

### Tools menu ('Tools', help 'Search, duplicates, apps, file types and old files') has a section 'Explore this scan' with: Uninstall Apps ('Remove apps and their matching leftovers.'), Find Duplicates ('Compare identical files before staging copies.'), Browse by Type ('See which file types use the most space.'), Big & Old Files ('Find large files you may no longer need.'), Search Files ('Search the current scan with plain words.'), then 'Open Rescue'. Each opens a 720x500 sheet, and all stage into the same Cleanup List.

Evidence: Tool enum labels and descriptions 11-58; menu 89-107; sheet 110-156; disabled while scanning or with no root (62).

Source: Tessera/Views/CleanupActionBar.swift:11-107

Implication: Rescue never mentions or embeds these tools, and their findings (duplicate reclaimable bytes, big and old files, orphan leftovers) never appear in the Rescue plan. A user in Rescue does not know they exist.

### Hidden Space (snapshots and purgeable) is not in the Tools menu. It can be reached only by selecting the synthetic 'Hidden Space' wedge in Explore and reading Details. It offers 'Delete all…' and per-snapshot deletion through tmutil, and says purgeable is 'Nothing for you to do.'

Evidence: InspectorView shows HiddenSpaceView when node.kind == .hiddenSpace (InspectorView.swift:47-48); HiddenSpaceView copy 'Hidden space', 'Backup snapshots', 'Delete all…', purgeable note (HiddenSpaceView.swift:21-103).

Source: Tessera/Views/InspectorView.swift:47-48

Implication: In Rescue, snapshots appear only as one coverage sentence. 'System Data' and snapshot space, a top user complaint, have no path from Rescue.

### Big & Old Files defaults to a 1 GB minimum and any age, with picks of 100 MB, 500 MB, 1 GB, 5 GB and 30d, 6mo, 1yr, 2yr. It lists files only (packages count as files), sorted by size and capped at 500. Duplicates scans files of 1 MiB or more, hashing in full up to 1 MiB and sampling above that.

Evidence: LargeOldFilesView MinSize/AgeWindow (LargeOldFilesView.swift:16-50, 52-53); LargeOldFiles.find and resultCap (LargeOldFiles.swift:31, 38-77); DuplicateFinder defaultMinSize and exactThreshold (DuplicateFinder.swift:52, 276-279).

Source: Tessera/Engine/LargeOldFiles.swift:31-77

Implication: Both engines are pure tree passes and could feed Rescue directly, for example as 'Large files untouched for 1 year' and 'Duplicate copies' groups, with no new I/O for large-and-old.

### The Review group's 'Add' button stages every node in the group with one click, including broad units like the whole ~/Downloads folder, the whole ~/Library/Caches folder, or every node_modules folder.

Evidence: Group 'Add' calls vm.toggleCleanupGroup (CleanupSuggestionsView.swift:442-451) -> stageCleanupGroup adds all group.nodes unless the group is protected (ScanViewModel.swift:584-588).

Source: Tessera/ViewModel/ScanViewModel.swift:584-603

Implication: This contradicts the subtitle 'Nothing is added automatically' and the review-first intent. It is a safety and clarity issue to fix in the redesign.

### The build-output rule matches common folder names under broad path words. For example, 'out' or 'build' anywhere under ~/Documents is flagged.

Evidence: (n == build|target|dist|.next|out) && path contains /developer/, /documents/, /projects/, /code/ or /src/.

Source: Tessera/Engine/CleanupSuggestions.swift:493-497

Implication: False positives are likely in personal folders, and repos under ~/dev, ~/repos or ~/work are missed. A marker-file test (Cargo.toml, package.json, .xcodeproj next to the folder) would be more exact but needs each candidate's siblings, which are in the tree.

## patterns

- Avoid: ordering by risk tier before size (CleanupSuggestions.swift:654-659). Lead with size inside a clear 'what you can do' frame, and show risk as a property of each row, not as the top sort key.
- Avoid: three repeated risk labels (section title, group tag, item capsule). Use one tier signal per row.
- Avoid: subsuming broad roots (~/Library/Caches, ~/Downloads) into one row. Descend one level and show the largest children with their owner names.
- Avoid: putting state-machine and proof jargon in the main view (phase badge, 'Stable scan identity: captured', byte counts). Keep proof behind one disclosure and write it in plain words.
- Avoid: a capacity bar that fills with free space while the caption talks about used space. Use a used-space bar with a goal marker and a 'selected items would bring you to X%' overlay.
- Copy: one headline figure, 'You can free about X GB', built from all stageable groups, next to the drive's free space and goal.
- Copy: put the reason for a demotion first, or as its own line, so 'why is this in review' is visible without hovering.
- Copy: feed tree-only engines (LargeOldFiles, DuplicateFinder results, AppUninstaller orphans) into Rescue as groups, so Rescue is the single place to act and the Tools sheets become drill-downs.
- Copy: show Trash, snapshots and purgeable space as a 'Space macOS is holding' strip with real owner actions (Empty Trash with confirm, open Hidden Space, open Time Machine), not as a protected group with an inert 'Owner handoff' label.
- Pattern: protected and owner-managed items need a real handoff button (reveal or open the owner app or its settings pane). Otherwise the protected tier is a dead end.
- Pattern: show age (modTime) on rows and groups ('untouched 14 months'). It is already in the tree and is the strongest signal users trust for 'safe to remove'.

## open questions

- Runtime check needed: on a real Mac, does a '/' or home scan ever produce a non-empty 'Safe to review' section, given that any Hidden Space, iCloud online-only folder, Simulator mount or FDA gap makes coverage partial (CleanupSuggestions.swift:250-258, 783-808)?
- Should a coverage gap in an unrelated part of the tree really move Xcode DerivedData down to review? Or should the gate apply only to gaps inside the candidate's own folder?
- Which source does a first-time user usually scan in Rescue: Macintosh HD, home or a folder? This decides whether home caches and Library paths are even in the tree.
- Should Rescue gain an Empty Trash step (recorded as settled in docs/research/tessera-disk-rescue-ethnographic-study.md:490) so the default Trash path actually frees space and the goal can be met?
- Does ~/.Trash, ~/Library/Application Support/MobileSync or Photos Library read as a coverage gap without FDA on macOS 26? This needs a check on device.
- Is the 75% used capacity goal the right default, or should the goal be 'free X GB for a task' (RescueGoal exists but is unused in the UI, CleanupSuggestions.swift:51-78)?
- Should the per-group 'Add' button stay on Review groups, given that it can stage all of ~/Downloads or ~/Library/Caches in one click?
- Should Photos Library, Final Cut libraries and other personal media libraries be added to the protected rules? Today they can be staged from Explore without any owner warning.
