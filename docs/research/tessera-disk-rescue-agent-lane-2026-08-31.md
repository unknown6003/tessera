# Tessera disk-rescue agent lane: developer and creator storage blockers

Collected 2026-08-31. This lane covers Xcode, Docker Desktop on macOS, Unity and creative-project caches, Android tooling, media caches, and backup or update failures. It contains 46 URLs from direct first-person reports, product communities, and first-party documentation. Every URL was checked against the existing `docs/research/tessera-disk-rescue-*` files before this report was written. No existing ledger or handoff was changed.

This is directional ethnographic evidence. It shows how people describe blocked work and what product documentation says. It does not estimate how common each problem is.

## Xcode, DerivedData, archives, and Apple update work

### 01. Xcode install rejected with 24.68 GB free

- URL: [Apple Developer Forums](https://developer.apple.com/forums/thread/660905)
- Source type: First-person Apple Developer Forum report.
- Observed behavior: The poster had 24.68 GB free, while the App Store reported an 11 GB Xcode download. Other replies report that 37 GB still failed and about 41 GB worked; freeing about 40 GB fixed the original failure.
- Product implication: Show estimated temporary and unpacking space, not only download size. Give a measurable threshold before an install or update starts.

### 02. Xcode archive failed after a macOS update

- URL: [Apple Developer Forums](https://developer.apple.com/forums/thread/815588)
- Source type: First-person Apple Developer Forum report.
- Observed behavior: The project built before a macOS 26.2 update but archive failed after it. The developer exported a build report after Apple asked for exact diagnostics.
- Product implication: Preserve the failed operation, system-change context, and diagnostic report. Do not send the user directly to cleanup when the failure may be an update regression.

### 03. Xcode previews stayed stuck for days

- URL: [Apple Developer Forums](https://developer.apple.com/forums/thread/697975)
- Source type: First-person Apple Developer Forum report.
- Observed behavior: Previews stayed stuck for days and the iMac became slow. Replies discuss temporary files, clean builds, reboots, and diagnostics, but some temporary files could not be deleted.
- Product implication: Separate build-state repair from storage cleanup. Show which generated data can be rebuilt and which cleanup will not address the current failure.

### 04. Deleted data did not make space available

- URL: [Apple Developer Forums](https://developer.apple.com/forums/thread/78819)
- Source type: First-person Apple Developer Forum report.
- Observed behavior: The poster deleted about 25 GB but saw no change in available space. Xcode installer decompression still failed, leading people to consider a clean reinstall.
- Product implication: Compare free, available, purgeable, snapshots, and open-file state. A deleted byte count is not proof that usable space returned.

### 05. Xcode update looped on component selection

- URL: [Apple Developer Forums](https://developer.apple.com/forums/thread/812741)
- Source type: First-person Apple Developer Forum report with Apple support guidance.
- Observed behavior: Xcode 26.2 downloaded but could not complete component selection. The support path considered compatibility, storage, partial versions, and permissions.
- Product implication: Diagnose incomplete installers and version conflicts as one guided state. Show the exact blocker and the next retry condition.

### 06. DerivedData reached about 22 GB

- URL: [Stack Overflow](https://stackoverflow.com/questions/18933321/can-i-safely-delete-contents-of-xcode-derived-data-folder/39867128)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: The poster found about 22 GB in DerivedData, deleted one project's generated data, then rebuilt, tested, and archived successfully. Other comments report that deletion can expose a build failure until the project is rebuilt.
- Product implication: Label DerivedData as rebuildable, but show rebuild time and active-project impact. Offer a post-clean build check.

### 07. The Xcode folder was over 17 GB in a small VM

- URL: [Stack Overflow](https://stackoverflow.com/questions/39481549/what-can-i-delete-from-library-developer-xcode-folder)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: An Xcode folder used over 17 GB inside a 64 GB Parallels VM. Answers separate Archives, DerivedData, DeviceSupport, simulator data, snapshots, and user data, and warn that archives can help later debugging.
- Product implication: Explain each directory's role, recovery path, and debugging cost. Do not present all Xcode data as the same kind of cache.

### 08. The App Store rejected Xcode despite 52 GB available

- URL: [Stack Overflow](https://stackoverflow.com/questions/53432700/xcode-on-mac-app-store-cant-install-show-disk-space-not-enough)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: The poster saw 52 GB available and 39 GB purgeable, but the App Store still rejected Xcode. Removing the `storedownloadd` cache fixed the install.
- Product implication: Inspect stale installer state as a separate owner. Explain why clearing an installer cache may force a new download.

### 09. Xcode update failed with 27 GB free

- URL: [Stack Overflow](https://stackoverflow.com/questions/66223546/unable-to-update-xcode-not-enough-space/69746389)
- Source type: First-person Stack Overflow report and community answers.
- Observed behavior: The poster removed DeviceSupport, DerivedData, Archives, and unavailable simulators, but an update still failed at 27 GB free. Reports say roughly 35 to 43 GB was needed.
- Product implication: Treat updates as operations with a working-space threshold. Show which developer tools remain unavailable until the update completes.

### 10. Projects consumed nearly all free space while open

- URL: [Stack Overflow](https://stackoverflow.com/questions/12358266/why-is-xcode-reserving-so-much-disk-space-when-running)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: Free space fell to about 40 MB when projects were open. The discussion points to temporary files, backing stores, or a runaway subprocess.
- Product implication: Inspect live writers and open handles before proposing deletion. A growing file may be an active fault, not old clutter.

### 11. Simulator cleanup still left about 6 GB

- URL: [Stack Overflow](https://stackoverflow.com/questions/63576430/how-to-clean-junk-files-in-xcode-from-ios-support?noredirect=1)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: Simulator cleanup left about 6 GB on the Mac. Answers distinguish Archives, CoreSimulator data, and DerivedData, with different rebuild and symbolication consequences.
- Product implication: Let users inspect cleanup classes separately. Show the lost debugging value and expected regeneration work before confirmation.

## Docker Desktop on macOS and virtual disk images

### 12. Docker.raw grew past the configured limit

- URL: [Docker Community Forums](https://forums.docker.com/t/docker-desktop-mac-ignoring-the-disk-usage-limit-i-specified-in-settings-resources/147964)
- Source type: First-person Docker Community Forum report and maintainer reply.
- Observed behavior: A Mac mini M1 was configured with an 8 GB limit, but Docker.raw grew to about 34 GB after Compose recreated data. The UI still showed a 32 GB limit and prune reported no reclaimable data.
- Product implication: Show configured maximum, physical allocation, guest usage, and reclaimable content as separate values. Identify the active backend before cleanup.

### 13. Removing Docker objects did not shrink the host file

- URL: [Docker Community Forums](https://forums.docker.com/t/release-space-after-remove-container/22561)
- Source type: First-person Docker Community Forum report and maintainer answer.
- Observed behavior: The poster expected removed containers and images to free host space. The answer explains that Docker for Mac uses a sparse disk image that can stay large after internal data is removed.
- Product implication: Separate logical Docker cleanup from host-file compaction. Show which owner action is needed for each result.

### 14. Docker image import failed with space on the wrong volume

- URL: [Docker Community Forums](https://forums.docker.com/t/docker-load-no-space-left-on-device/146937)
- Source type: First-person Docker Community Forum report and community replies.
- Observed behavior: The poster moved Docker storage to an external drive, but import still failed with “no space left on device.” Two Docker.raw files together used about 94 GB, while the external drive had about 136 GB free.
- Product implication: Trace the active image and every duplicate before suggesting removal. Do not treat a raw virtual disk as an ordinary archive.

### 15. Each Docker sandbox added about 17 GB

- URL: [Docker Community Forums](https://forums.docker.com/t/config-options-to-reduce-docker-raw-for-docker-sandboxes-on-docker-desktop-for-mac/151143)
- Source type: First-person Docker Community Forum report from a coding-agent workflow.
- Observed behavior: Each new sandbox allocated about 17 GB even though the base image was about 2.2 GB. A guest used about 1.5 GB while the host raw disk occupied about 17 GB.
- Product implication: Model per-environment overhead before creation. Show guest content and host allocation so repeated short-lived environments do not look free.

### 16. Docker filled the disk and normal commands failed

- URL: [Docker Community Forums](https://forums.docker.com/t/docker-hosed-15-characters/151207)
- Source type: First-person Docker Community Forum report and follow-up diagnosis.
- Observed behavior: After an update, Docker showed a full disk and builds returned random errors. Prune, reboot, delete, factory reset, and reinstall were attempted; later investigation found a bad copy command inside a container had filled the disk.
- Product implication: Preserve the failure state and inspect workload writers before factory reset or reinstall. Warn that broad recovery actions can destroy useful state.

### 17. Moving the Docker image to an external disk hung

- URL: [Docker Community Forums](https://forums.docker.com/t/macos-disk-image-location-not-working/136587)
- Source type: First-person Docker Community Forum report and issue discussion.
- Observed behavior: Moving the image to an external SSD on an M1 Mac stayed in an Apply or restart loop for over 40 minutes. Reports say the host and VM could both show free space while Docker services still failed.
- Product implication: Treat relocation as a transaction with progress, timeout, rollback, and verification. Do not leave a user with an empty or ambiguous storage location.

## Unity project caches and Android tooling

### 18. Unity import from an external drive stopped at 85 percent

- URL: [Reddit r/Unity3D](https://www.reddit.com/r/Unity3D/comments/11ju0md/)
- Source type: First-person Reddit creator report.
- Observed behavior: A creator with little internal storage moved a Unity project to a 1 TB external HDD, but Plastic SCM import stopped at about 85 percent. Importing to internal storage worked, while moving the project afterward caused temp-file errors.
- Product implication: Scan project volume, package cache, temp path, and app-managed cache separately. External project capacity does not prove that the workflow has internal working space.

### 19. Unity generated millions of occlusion files

- URL: [Reddit r/Unity3D](https://www.reddit.com/r/Unity3D/comments/17z76x1/)
- Source type: First-person Reddit creator report.
- Observed behavior: The project contained about three million files in a `Library/occlusion` area. Clearing them took about an hour and the occlusion bake could not proceed.
- Product implication: Report file count and cleanup time, not size alone. Offer selective cache classes and a way to stop an expensive cleanup.

### 20. iCloud placeholders blocked Unity's asset refresh

- URL: [Reddit r/Unity3D](https://www.reddit.com/r/Unity3D/comments/159k094/)
- Source type: First-person Reddit creator report.
- Observed behavior: iCloud offloaded project files from Desktop. Unity became stuck during the initial asset database refresh while waiting for downloads; downloading the files before opening the project fixed it.
- Product implication: Distinguish cloud placeholders and unavailable files from local disk pressure. Show the exact files that must be local before retry.

### 21. Unity's installer cache approached 50 GB

- URL: [Reddit r/Unity3D](https://www.reddit.com/r/Unity3D/comments/ox3rhp/)
- Source type: First-person Reddit creator report and community replies.
- Observed behavior: Unity Editor would not install on a Mac. Replies identify a Unity cache near 50 GB and a download that did not resume after a network interruption.
- Product implication: Show installer cache ownership, partial-download state, and the redownload cost before clearing it.

### 22. A Unity shader compiler filled a 2 TB drive

- URL: [Reddit r/Unity3D](https://www.reddit.com/r/Unity3D/comments/1dumudf/)
- Source type: First-person Reddit creator report and community replies.
- Observed behavior: A mostly empty 2 TB drive became full while Unity's shader compiler logged indefinitely. The work stopped at zero free bytes; replies point to large logs and occlusion data.
- Product implication: Detect runaway writers and preserve a small diagnostic sample before containment. Do not classify every growing Unity file as disposable cache.

### 23. Running a Unity game consumed system disk space

- URL: [Reddit r/Unity3D](https://www.reddit.com/r/Unity3D/comments/zcue46/)
- Source type: First-person Reddit creator report and community replies.
- Observed behavior: A game used up to 20 GB of system disk and crashed when space was low, even though the assets were on another drive. Replies point to lightmap, mesh, and texture caches.
- Product implication: Map cross-volume scratch and cache dependencies. Reserve headroom for the operation that will run, not only for the source assets.

### 24. Unity's asset package cache has its own location

- URL: [Unity Manual](https://docs.unity3d.com/Manual/upm-config-cache-as.html)
- Source type: First-party Unity documentation.
- Observed behavior: Unity documents a separate asset package cache that can be moved to save internal-drive space. Existing packages can remain in the old location, and environment-variable overrides apply only to a launch.
- Product implication: Show every cache root and the data left behind after a location change. Explain whether the change is persistent and whether a relaunch is required.

### 25. Unity build caches are tied to build troubleshooting

- URL: [Unity Manual](https://docs.unity3d.com/Manual/build-cache-location-reference.html)
- Source type: First-party Unity documentation.
- Observed behavior: Unity documents cache and metadata locations for Player builds and points to them when investigating build problems. These caches can be regenerated, but deletion can trigger long rebuilds or expose version-specific issues.
- Product implication: Mark generated data as rebuildable while showing rebuild cost and project or editor version scope.

### 26. Deleting Unity's Asset Store cache does not delete imported assets

- URL: [Unity Manual](https://docs.unity3d.com/Manual/upm-del-pkg-as-cache.html)
- Source type: First-party Unity documentation.
- Observed behavior: Unity says downloaded `.unitypackage` files live in an Asset Store cache. Removing the cache package does not remove assets already imported into a project.
- Product implication: Explain the relationship between source download, cache copy, and project copy. This reduces fear while preventing users from deleting the wrong project data.

### 27. Android Studio reported low space with over 300 GB free

- URL: [Stack Overflow](https://stackoverflow.com/questions/30839193/low-disk-space-error-in-android-studio-on-mac-during-gradle-sync-and-build/30842760)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: Android Studio reported low disk in a system directory even though the Mac had over 300 GB free. The discussion points to the monitored path, not the headline disk total.
- Product implication: Name the exact path and volume behind a low-space alert. Do not rely on one global free-space number.

### 28. Gradle daemon files reached 50 GB

- URL: [Stack Overflow](https://stackoverflow.com/questions/67052684/reduce-gradle-daemon-disk-space-it-takes-up-to-50gb)
- Source type: First-person Stack Overflow report.
- Observed behavior: The `.gradle/daemon` directory reached about 50 GB across roughly 50 files, with individual files between 1 MB and 3 GB. The developer asked what could be removed.
- Product implication: Show file age, process ownership, and regeneration behavior for each daemon artifact. A blanket “clear Gradle” action hides useful distinctions.

### 29. Gradle failures created repeated multi-gigabyte heap dumps

- URL: [Stack Overflow](https://stackoverflow.com/questions/36441598/why-is-gradle-2-0-so-slow)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: A long build used about 6 GB of SSD space. Each garbage-collection error created an approximately 1.2 GB `.hprof` file, so repeated failures multiplied the damage.
- Product implication: Correlate growth with repeated failures and identify crash dumps as evidence of an active problem, not ordinary build cache.

### 30. Android system-image download failed despite a large laptop drive

- URL: [Stack Overflow](https://stackoverflow.com/questions/47543823/java-io-ioexception-cannot-download-no-space-left-on-device)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: An emulator system-image download failed with “no space left on device” even though the laptop had about 960 GB free. The answer points to a temporary partition or cache path.
- Product implication: Inspect the temporary volume used by the downloader. Explain why free space on the main data volume may not help.

### 31. Android Studio and command-line tools downloaded duplicates

- URL: [Stack Overflow](https://stackoverflow.com/questions/47739438/gradlew-command-line-and-gradle-from-android-studio-will-download-duplicate-tools)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: Android Studio and command-line Gradle downloaded the same tool into duplicate directories, including an 87 MB tool represented by roughly 271 MB of files.
- Product implication: Detect duplicate versions across toolchains and show which workflow owns each copy before offering cleanup.

### 32. `/tmp` blocked an Android emulator image install

- URL: [Stack Overflow](https://stackoverflow.com/questions/35949698/android-studio-2-1-preview1-gives-no-space-left-on-device-error)
- Source type: First-person Stack Overflow report and community answers.
- Observed behavior: A large device image failed to install because `/tmp` was too small. The same temporary-space issue could also prevent an AVD from starting.
- Product implication: Treat temporary storage as a first-class volume. Show the temporary path and required working space in the failed operation.

### 33. SDK Manager left a failed emulator download incomplete

- URL: [Stack Overflow](https://stackoverflow.com/questions/44785258/cannot-set-java-io-tmpdir-for-android-sdkmanager)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: An emulator image download failed, after which SDK Manager showed no images. Java warned about insufficient shared-memory file space and suggested another temporary directory.
- Product implication: Preserve and identify partial downloads, then offer a scoped retry after the temporary path is fixed.

### 34. An incomplete NDK directory broke later builds

- URL: [Stack Overflow](https://stackoverflow.com/questions/64372383/ndk-at-library-android-sdk-ndk-bundle-did-not-have-a-source-properties-file/69823272)
- Source type: First-person Stack Overflow report and community answer.
- Observed behavior: An automatic NDK download failed from insufficient space and left an almost empty version directory. Later builds failed because the directory lacked `source.properties`; deleting only the incomplete directory and retrying helped some users.
- Product implication: Detect incomplete installs by required marker files. Offer exact-path repair and retry, not a broad SDK purge.

### 35. Android Studio's documented install footprint grows with emulators

- URL: [Android Developers](https://developer.android.com/studio/install.html)
- Source type: First-party Android documentation.
- Observed behavior: Android documents about 8 GB free for Studio, about 16 GB for Studio plus an emulator, and up to about 6 GB for extra AVDs. It also documents physical-device and cloud alternatives.
- Product implication: Calculate expected space from selected components and AVD count. Offer a lower-footprint workflow when the user does not need local emulators.

### 36. AVD disk images can be moved with environment variables

- URL: [Android Developers](https://developer.android.com/tools/variables)
- Source type: First-party Android documentation.
- Observed behavior: Android documents that AVD files are mostly large disk images and that `ANDROID_AVD_HOME` can move them away from a full default location.
- Product implication: Detect AVD ownership and provide a documented relocation path. Show that moving the owner root changes future placement, not necessarily old data.

### 37. The emulator refuses to start below 5 GB free

- URL: [Android Developers](https://developer.android.com/studio/run/emulator-troubleshooting?hl=en)
- Source type: First-party Android documentation.
- Observed behavior: Android documents a startup check that can refuse to run an emulator with less than 5 GB free. Low space can also cause hangs or crashes.
- Product implication: Protect a reserved headroom threshold and explain the blocked launch condition before cleanup begins.

## Creative media caches and scratch disks

### 38. Premiere's displayed free disk did not match macOS

- URL: [Adobe Community](https://community.adobe.com/questions-729/free-media-disk-space-not-reflecting-available-disk-space-in-storage-1408757)
- Source type: First-person Adobe Community report.
- Observed behavior: Premiere's rendering “Free Disk” value did not match the Mac's available space. The poster had already cleared the media cache on an M2 Max Mac.
- Product implication: Show the application scratch path and host-volume space side by side. Do not imply that clearing one Adobe cache fixes every render-space reading.

### 39. Photoshop consumed 34 GB during one PSD open

- URL: [Adobe Community](https://community.adobe.com/questions-712/photoshop-using-massive-amount-of-disk-space-when-opening-a-psd-and-then-scratch-disks-are-full-1129996)
- Source type: First-person Adobe Community report.
- Observed behavior: A Mac with 45 GB free fell to 25 GB when Photoshop opened, then to 11 GB when a PSD under 1 GB opened. Photoshop reported that the scratch disk was full.
- Product implication: Model operation-time spikes and required headroom. The source file size is not a useful estimate of scratch-space demand.

### 40. Adobe media caches grew into system data

- URL: [Adobe Community](https://community.adobe.com/questions-712/adobe-cache-takes-up-too-much-space-in-my-macbook-s-system-data-1177582)
- Source type: Adobe Community explanation and product guidance.
- Observed behavior: The discussion describes After Effects and Premiere media or disk caches becoming very large. It points to emptying caches or moving them to an external volume, with a tradeoff for rebuild time and fast storage.
- Product implication: Identify high-growth creative caches, show their application owner, and explain the performance cost of moving or rebuilding them.

### 41. Editors needed to choose separate source, project, and scratch volumes

- URL: [Adobe Community](https://community.adobe.com/questions-729/scratch-disks-media-cache-settings-for-macbook-pro-1384663)
- Source type: First-person Adobe Community report.
- Observed behavior: A video editor kept raw video on an external SSD and asked where scratch disks and projects should live on a 1 TB MacBook Pro.
- Product implication: Ask which volume owns source media, project state, cache, and scratch data. Offer role-based placement instead of one generic move action.

## Backup and update failures

### 42. Time Machine failed after copying about 958 GB

- URL: [Apple Support Community](https://discussions.apple.com/thread/256167650)
- Source type: First-person Apple Support Community report and replies.
- Observed behavior: A 2 TB Time Machine disk backed up a 1 TB Mac for two years, then reported insufficient space after a macOS update. A later attempt failed after about 958 GB copied, while replies discuss source snapshots, external drives, and different free-space metrics.
- Product implication: Show source and destination owners, backup phase, copied amount, snapshots, and the exact metric used. “Not enough space” must say where.

### 43. Time Machine reported a backup of “null”

- URL: [Apple Support Community](https://discussions.apple.com/thread/256211365)
- Source type: First-person Apple Support Community report and replies.
- Observed behavior: Time Machine said there was not enough space to back up “null” even after old backups were deleted. The same result appeared with two destinations, including a network share.
- Product implication: Expose the failing item or phase when possible. Repeating destination cleanup without a file-level clue creates a dead end.

### 44. A 500 GB Mac could not back up to a 1 TB disk

- URL: [Apple Support Community](https://discussions.apple.com/thread/255624357)
- Source type: First-person Apple Support Community report and replies.
- Observed behavior: A 500 GB MacBook could not back up to a 1 TB external disk. Replies point to source-drive snapshots, staging, and churn after an update.
- Product implication: Treat backup as a transaction that may need source-side working space. Check snapshots and staging before blaming the destination.

### 45. The backup disk had terabytes free while the Mac had 1.6 GB

- URL: [Apple Support Community](https://discussions.apple.com/thread/255503647)
- Source type: First-person Apple Support Community report and replies.
- Observed behavior: The backup disk had about 3.5 TB free, but the Mac's internal disk had about 1.6 GB. The poster suspected a source snapshot, and deleting old destination backups did not solve it.
- Product implication: Point the user to the pressured volume and owner. Do not offer destination cleanup when the source volume is the bottleneck.

### 46. A macOS upgrade made Time Machine treat the Mac as new

- URL: [Apple Support Community](https://discussions.apple.com/thread/6657440)
- Source type: First-person Apple Support Community report and replies.
- Observed behavior: After a Yosemite upgrade, Time Machine estimated 838 GB needed against 712 GB available, even though the prior backup used 898 GB. The external drive was included and the sparse bundle did not shrink; the upgrade was treated as a new machine.
- Product implication: Detect identity and backup-scope changes after an OS migration. Explain why an incremental backup can become a near-full backup.

### 47. Time Machine history was hidden behind an old Mac identity

- URL: [Apple Support Community](https://discussions.apple.com/thread/7922124)
- Source type: First-person Apple Support Community report and replies.
- Observed behavior: Time Machine did not remove old backups and kept failing. A new Mac name left the previous machine's backup history unseen but still consuming space; the poster wanted to keep that history instead of erasing the disk.
- Product implication: Enumerate backup generations and identities before any reset. Preserve history as a named recovery object, not anonymous storage.

## Pattern summary

1. The headline free-space number is often not the working-space number. Temporary directories, snapshots, scratch disks, guest virtual disks, purgeable data, and staging copies decide whether the next operation can finish.
2. Rebuildable data is not cost-free data. DerivedData, Unity Library data, Gradle artifacts, AVD images, and media caches can be removed, but users care about rebuild time, redownloads, lost symbols, and whether the active project still opens.
3. The block happens at a workflow boundary: archive, install, package refresh, emulator launch, render, image import, backup, or update. Tessera should capture the failed phase and its owner before it recommends a cleanup.
4. Relocation is a separate operation from deletion. External-drive moves can hang, duplicate data, leave an old copy, or continue using an internal cache. They need progress, rollback, and post-move verification.
5. Broad reset and reinstall appear when the product does not explain scope. Tessera should default to read-only evidence, classify data by owner and recoverability, show the consequence of each exact action, require confirmation for mutation, and run a fresh verification scan afterward.
