# Tessera disk rescue: game launcher and library research lane

Date: 2026-08-31
Collection: `game-library-lane-2026-08-31`

## Scope

This lane asks how Tessera should classify and safely reclaim macOS storage when a game launcher or library mixes installed game data, downloads, patch and shader caches, saves, screenshots, mods, Workshop content, compatibility state, authentication, and external-volume locations.

The lane covers Steam, Epic Games Launcher, GOG GALAXY, Battle.net and World of Warcraft, itch.io, Heroic Games Launcher, Whisky, Prism Launcher, ATLauncher, Minecraft, and PlayCover.

## Answer

Tessera must not classify a launcher folder as one disposable object. It must first map every path to an owner, a game or instance, a storage role, a recovery cost, and a volume state.

The safe classification is:

1. **Protect by default.** This includes saves, worlds, screenshots, recordings, mods, resource packs, shader packs selected by the user, add-on settings, macros, instance settings, and local configuration.
2. **Owner-managed and replaceable.** This includes installed game payloads, depots, Workshop packages, Java runtimes, Wine engines, Game Porting Toolkit files, and verified offline installers. Prefer the owner's uninstall or repair action.
3. **Rebuildable after checks.** This includes web caches, verified download caches, logs, shader caches that the game can recreate, failed extraction output, and inactive patch staging.
4. **Uncertain or orphan candidates.** These include unregistered installs, stale manifests, missing bottles, partial downloads, old compatibility prefixes, and data under an owner root that the owner no longer lists. They require evidence and confirmation. Folder age or location is not enough.
5. **Unavailable, never orphaned.** This includes data on an offline, unmounted, permission-denied, wrong-format, or owner-unrecognized external volume. Freeze all cleanup decisions until access and volume identity are restored.

Compatibility containers need a second scan. A Whisky bottle, Wine prefix, or similar container can hold the launcher, installed games, runtime files, registry state, saves, mods, and authentication together. Tessera must show the container and its descendants. It must not offer direct container deletion based only on its top-level size.

## Method

- User evidence came from first-person reports in owner issue trackers and direct owner community forums.
- Product facts came from official documentation, owner source code, maintained owner wikis, or an owner implementation note.
- Product and maker statements were classified as owner facts. They were not counted as user evidence.
- Direct behavior reports were classified as `core`.
- Useful design requests and cross-platform failure cases were classified as `adjacent`.
- First-party product behavior was classified as `owner_fact`.
- Search pages, fragments, tracking parameters, and fabricated trailing-slash variants were excluded.
- No prevalence estimate was made. Each report is a case, not a population measure.

## Exact counts

### By owner family and evidence class

| Owner family | Total | Core | Adjacent | Owner fact |
|---|---:|---:|---:|---:|
| Steam | 18 | 10 | 2 | 6 |
| Epic Games Launcher | 15 | 7 | 1 | 7 |
| GOG GALAXY | 11 | 0 | 3 | 8 |
| Battle.net and World of Warcraft | 15 | 5 | 5 | 5 |
| itch.io | 17 | 8 | 1 | 8 |
| Heroic Games Launcher | 20 | 11 | 3 | 6 |
| Whisky | 18 | 15 | 1 | 2 |
| Prism Launcher | 22 | 0 | 14 | 8 |
| ATLauncher | 10 | 10 | 0 | 0 |
| Minecraft | 5 | 0 | 0 | 5 |
| PlayCover | 5 | 5 | 0 | 0 |
| **Total** | **156** | **71** | **30** | **55** |

### By source kind

| Source kind | Count |
|---|---:|
| first_party_documentation | 52 |
| first_person_owner_forum_thread | 33 |
| first_person_owner_issue | 68 |
| owner_forum_product_notice | 1 |
| owner_issue_implementation_note | 2 |
| **Total** | **156** |

### By source type

| Source type | Count |
|---|---:|
| direct_community_forum_report | 33 |
| official_owner_documentation | 52 |
| owner_forum_product_notice | 1 |
| owner_issue_implementation_note | 2 |
| owner_issue_tracker_report | 68 |
| **Total** | **156** |

The corpus contains 101 direct user or adjacent behavior records and 55 owner facts.

## Screening limits

- The corpus uses public reports and public owner material. It does not include private support tickets, launcher telemetry, or direct observation of a user's full disk.
- Forum and issue records show real failure modes. They do not show how common those failures are.
- Some adjacent records are from Windows or Linux. They are included only when the owner-state, archive, cache, instance, or external-volume behavior transfers to the macOS safety decision.
- Official documentation can change after collection.
- The bounded link check returned no 404 response. Epic and GOG returned 403 to the automated checker. Minecraft requests timed out in that pass. These blocked responses were not used as content validation.
- No destructive action or live owner uninstall was tested.
- Record observations are short paraphrases. They are not long quotations.

## Selected records

### Steam

- **GL001 | core | [Move Steam games to an external drive on Mac](https://steamcommunity.com/discussions/forum/2/6821308966015924903/)**: A Mac user wanted to free internal space by moving installed Steam games. Replies used Steam library folders and Move Install Folder, and one user said Steam sometimes forgot the external location.
- **GL002 | core | [Move an entire Steam library to an external drive](https://steamcommunity.com/discussions/forum/2/35221031624524339/)**: A MacBook Air user copied a library to an external drive, then hit read and write errors before Steam could verify the files.
- **GL003 | core | [Steam reports insufficient space for small installs on Mac](https://steamcommunity.com/discussions/forum/2/624076751540813939/)**: A Mac user saw an insufficient-space error for games smaller than the reported free space and could not select a new library folder.
- **GL004 | core | [Steam download and update consumed more Mac space than expected](https://steamcommunity.com/discussions/forum/2/4417479689924108066/)**: Mac users reported installs taking much more temporary space than the listed download and external drives being rejected as too small after a client update.
- **GL005 | core | [Steam lost a symlinked external game library](https://steamcommunity.com/discussions/forum/2/648817378047235198/)**: A Mac user moved steamapps to an external drive through a symbolic link, but Steam showed the games as not downloaded.
- **GL006 | core | [Steam could not write to an existing external Mac library](https://steamcommunity.com/discussions/forum/2/4417479689914343069/)**: A long-used external Steam library became read-only to the client and its games were no longer recognized. A later reply restored access through macOS Full Disk Access.
- **GL007 | core | [Mac user considered one-game-at-a-time deletion before moving Steam](https://steamcommunity.com/discussions/forum/2/882959799632031695/)**: A MacBook user with a small SSD considered deleting and redownloading each large game, then explored moving steamapps and using a symbolic link.
- **GL008 | core | [Steam games failed on a case-sensitive external Mac volume](https://steamcommunity.com/discussions/forum/2/523897653318870000/)**: A Mac user installed six games externally to save internal space, but games rejected the case-sensitive filesystem or failed to find expected data.
- **GL009 | core | [Steam screenshot storage on Mac was hard to locate](https://steamcommunity.com/discussions/forum/2/135508662493348877/)**: A Mac user could not find Steam screenshot settings while replies described a selectable uncompressed-copy folder and a separate screenshot shortcut.
- **GL010 | core | [Steam Cloud did not carry saves between macOS and Windows](https://steamcommunity.com/discussions/forum/2/3819657183205792611/)**: A user tested several games and found that saves or edits did not sync reliably between macOS and Windows despite cloud sync being enabled.
- **GL011 | owner_fact | [Roguebook Mac cloud path change lost track of saves](https://steamcommunity.com/app/1076200/discussions/0/3052862906994491076/)**: The game maker said a Mac Steam Cloud change caused the game to lose track of local saves in alternate Application Support folders and published recovery steps.
- **GL012 | adjacent | [Steam screenshot folder setting created copies, not a relocation](https://steamcommunity.com/discussions/forum/0/3177855357749495486/)**: A user expected the chosen screenshot folder to replace Steam's storage, then learned that Steam still kept managed screenshots under userdata and used the chosen folder for copies.
- **GL013 | adjacent | [Steam Storage Manager media was local screenshot data](https://steamcommunity.com/discussions/forum/1/4511002214536968104/)**: A user assumed Steam media might be cloud-backed save data, then matched its size to locally stored compressed screenshots while separate uncompressed copies lived elsewhere.
- **GL014 | owner_fact | [Steam Cloud storage and macOS save roots](https://partner.steamgames.com/doc/features/cloud)**: Steam documents per-game cloud quotas, local synchronization before and after play, macOS roots under home, Application Support, and Documents, plus root overrides for cross-platform saves.
- **GL015 | owner_fact | [Steam Workshop content model](https://partner.steamgames.com/doc/features/workshop)**: Steam Workshop ties downloadable user-generated content to app IDs, item IDs, subscriptions, and owner APIs rather than a plain folder alone.
- **GL016 | owner_fact | [Steam Workshop installation and update lifecycle](https://partner.steamgames.com/doc/features/workshop/implementation)**: Steam documents subscribed-item download, installation state, update state, content folders, and explicit item removal through Workshop APIs.
- **GL017 | owner_fact | [Steam screenshot ownership and library integration](https://partner.steamgames.com/doc/features/screenshots)**: Steam exposes screenshot capture and library integration through an owner API, with screenshots attached to games and user metadata.
- **GL018 | owner_fact | [SteamPipe depots, builds, and local content](https://partner.steamgames.com/doc/sdk/uploading)**: Steam distributes game payloads as depots and builds through SteamPipe, with manifests and chunk-based content rather than one monolithic installer artifact.

### Epic Games Launcher

- **GL019 | core | [External Unreal Engine installs crashed on a full MacBook](https://forums.unrealengine.com/t/ue-5-3-crashes-at-initialization/1301861)**: A Mac user installed several Unreal Engine versions externally because the internal drive was full, but each install crashed during initialization.
- **GL020 | core | [Epic Launcher did not recognize a shared Mac lab install](https://forums.unrealengine.com/t/epic-games-launcher-not-recognising-unreal-engine-install-or-projects/1247176)**: Mac lab users could launch a shared Unreal install directly, but Epic Launcher asked each account to reinstall into the nonempty directory and could not see projects.
- **GL021 | core | [Epic Launcher logs consumed Mac disk space](https://forums.unrealengine.com/t/why-is-the-epic-games-launcher-constantly-spamming-the-console-logs-with-process-names/445850)**: A Mac user reported the launcher logging process names fast enough to consume disk space and make Console lag.
- **GL022 | core | [Epic reported no space despite 136 GB free on Mac](https://forums.unrealengine.com/t/not-enough-disk-space-error-when-there-is-enough/480261)**: A MacBook user reported that Unreal Engine installation stopped immediately for insufficient space while macOS showed 136.25 GB free.
- **GL023 | core | [Stale shared folders blocked Epic Launcher installation on Mac](https://forums.unrealengine.com/t/found-bug-installing-epic-games-launcher-on-mac/404494)**: A Mac user traced repeated launcher installation failure to an existing shared UnrealEngine folder and described a clean install path that worked.
- **GL024 | core | [Epic Launcher cache deletion restored its Mac interface](https://forums.unrealengine.com/t/epic-games-launcher-not-loading-properly-mac-user/453780)**: A Mac user reinstalled and restarted without success, then restored the launcher by removing its cache. Other Mac users confirmed the result.
- **GL025 | core | [Moved Fortnite files left Epic with stale free-space state on Mac](https://forums.unrealengine.com/t/error-file-for-not-enough-storage-error-is-ds01/457332)**: A Mac user manually reorganized Fortnite and Unreal files, after which Epic no longer recognized the install and kept reporting an old free-space value through reinstalls.
- **GL026 | adjacent | [Epic Launcher could not find an external Unreal install](https://forums.unrealengine.com/t/epic-games-launcher-cant-find-my-ue4-installation/383082)**: A user moved an Unreal install to an external drive for use on another machine, but Epic asked for a new install and refused the existing nonempty directory.
- **GL027 | owner_fact | [Clear Epic Games Launcher webcache on Mac](https://www.epicgames.com/help/en-US/c-Category_EpicAccounts/c-TechnicalSupport_GeneralSupport/a000086158)**: Epic directs Mac users to quit the launcher and remove webcache under ~/Library/Caches/com.epicgames.EpicGamesLauncher before relaunching.
- **GL028 | owner_fact | [Change Epic Games Launcher installation directory](https://www.epicgames.com/help/en-US/c-Category_EpicGamesStore/c-EpicGamesStore_LauncherSupport/how-do-i-change-the-installation-directory-of-the-epic-games-launcher-a000084679)**: Epic says changing the launcher location may require uninstall and reinstall, and warns that uninstalling the launcher removes installed games on some platforms.
- **GL029 | owner_fact | [Move an Epic-installed game to another directory](https://www.epicgames.com/help/en-US/c-Category_EpicGamesStore/c-EpicGamesStore_LauncherSupport/how-to-move-an-installed-game-from-the-epic-games-launcher-to-another-directory-on-your-computer-a000084687)**: Epic's move workflow makes a backup, uninstalls the owner record, starts a small new download, restores files, and lets the launcher verify them.
- **GL030 | owner_fact | [Epic cannot automatically detect every prior install](https://www.epicgames.com/help/en-US/c-Category_EpicGamesStore/c-EpicGamesStore_LauncherSupport/can-the-epic-games-launcher-detect-previously-installed-games-a000084800)**: Epic says the launcher has no general feature to detect prior game files and documents a partial-download workaround that may not work for every game.
- **GL031 | owner_fact | [Enable Epic cloud saves](https://www.epicgames.com/help/c-202300000001639/c-202300000001735/a202300000012791)**: Epic documents a global cloud-save setting and warns that changing it across machines can create cloud-save conflicts.
- **GL032 | owner_fact | [Epic uninstall can remove local saves](https://www.epicgames.com/help/c-202300000001639/c-202300000001735/epic-games-a202300000015527)**: Epic says uninstall may delete saves inside the install location when a game lacks cloud-save support and advises backing them up first.
- **GL033 | owner_fact | [Epic update size, verification, and Mac webcache](https://www.epicgames.com/help/c-32735058/c-36403860/why-do-download-file-sizes-seem-larger-than-normal-especially-after-an-update-in-epic-games-launcher-a10746187)**: Epic separates file verification from cache cleanup, says verification repairs changed files without affecting saves, and gives the Mac webcache path.

### GOG GALAXY

- **GL034 | adjacent | [GOG GALAXY did not rescan an external game library](https://www.gog.com/forum/general/how_do_i_make_galaxy_recheck_my_external_for_all_my_installed_games)**: After reboot, a user saw only part of an external GOG library and sought a full rescan; replies described scan folders and per-game import.
- **GL035 | adjacent | [Moving GOG games to an external SSD required re-import](https://www.gog.com/forum/general_beta_gog_galaxy_2.0/so_much_hassle_to_move_gog_games_to_external_ssd/post4)**: Users copied games externally, changed the default install folder, and then imported each game so GALAXY changed its state from Install to Play.
- **GL036 | adjacent | [A GOG GALAXY debug log filled a system drive](https://www.gog.com/forum/general/gog_galaxy_is_consuming_space_from_my_c_drive)**: A user reported GALAXY consuming about 40 GB rapidly, and replies traced similar cases to a runaway debug log.
- **GL037 | owner_fact | [Uninstall a game through GOG GALAXY](https://support.gog.com/hc/en-us/articles/360003936497-How-to-uninstall-my-game-via-GOG-GALAXY)**: GOG documents owner-managed game uninstall through GALAXY rather than raw folder deletion.
- **GL038 | owner_fact | [Back up GOG cloud saves](https://support.gog.com/hc/en-us/articles/18730324957213-How-do-I-back-up-my-cloud-saves)**: GOG provides a separate cloud-save backup procedure, which confirms that cloud availability and a user-held backup are different states.
- **GL039 | owner_fact | [GOG GALAXY storage and import error classes](https://support.gog.com/hc/en-us/sections/360003883478-GOG-GALAXY-Error-codes)**: GOG separates not-enough-space, import, library removal, local executable, uninstall, and cloud-sync failures into different error classes.
- **GL040 | owner_fact | [Remove saves from GOG cloud](https://support.gog.com/hc/en-us/articles/360003905358-How-can-I-remove-saves-from-the-cloud)**: GOG treats cloud-save removal as a separate owner action from deleting local game data.
- **GL041 | owner_fact | [Delete local GOG GALAXY data](https://support.gog.com/hc/en-us/articles/360003935897-How-can-I-delete-my-data-from-GOG-GALAXY)**: GOG documents local GALAXY data deletion separately from account deletion, installed games, and cloud state.
- **GL042 | owner_fact | [Disable GOG cloud saves](https://support.gog.com/hc/en-us/articles/20396092915997-How-can-I-disable-the-Cloud-Saves-functionality)**: GOG exposes cloud-save control as a product setting rather than a property of every local save folder.
- **GL043 | owner_fact | [Choose GOG install and download locations](https://support.gog.com/hc/en-us/articles/212806885-How-do-I-change-where-my-games-should-be-installed-and-where-I-want-to-download-files)**: GOG distinguishes the game installation destination from the location used to download files.
- **GL044 | owner_fact | [GOG GALAXY troubleshooting state list](https://support.gog.com/hc/en-us/sections/360001106718-GOG-GALAXY-Issues-and-troubleshooting)**: GOG's owner support separates a missing game, corrupt game data, inaccessible drive, and out-of-space state.

### Battle.net and World of Warcraft

- **GL045 | core | [Battle.net failed to reinstall on Mac until shared folders were copied](https://us.forums.blizzard.com/en/blizzard/t/error-blzbntagt00000840-when-trying-to-install-battlenet/53549)**: A Mac user restored Battle.net by copying the app and /Users/Shared/Battle.net and Blizzard folders from another Mac through an external drive.
- **GL046 | adjacent | [Battle.net stayed on calculating size for an external install](https://us.forums.blizzard.com/en/blizzard/t/calculating-size-on-external/21167)**: A user could not start an external Battle.net install because size calculation never completed; support replied that external drives can cause install and update failures.
- **GL047 | core | [Mac user needed WoW add-ons and settings on a new PC](https://us.forums.blizzard.com/en/wow/t/copying-ui-and-addons-from-mac-to-windows/351277)**: A Mac user planned to redownload WoW but copy Interface/AddOns and WTF/Accounts to preserve the configured UI and add-on state.
- **GL048 | adjacent | [WoW user moved the game but protected add-on configuration](https://us.forums.blizzard.com/en/wow/t/how-do-i-preserve-my-addons/228384)**: A user moving WoW between drives wanted to preserve heavily configured add-ons; replies identified Interface and WTF as the critical folders.
- **GL049 | adjacent | [WoW player wanted to back up years of UI work](https://us.forums.blizzard.com/en/wow/t/what-is-legal/974905)**: A player asked whether copying AddOns, WTF, and Screenshots to an external drive was allowed because the UI represented years of work.
- **GL050 | adjacent | [WoW user separated backups from rebuildable cache](https://us.forums.blizzard.com/en/wow/t/new-pc-what-to-back-up/29535)**: A user asked which WoW folders to back up. The thread distinguished Screenshots, Interface, and WTF from cache and the redownloadable game install.
- **GL051 | core | [Mac WoW repair could redownload Data without touching add-ons](https://us.forums.blizzard.com/en/wow/t/the-game-wont-finish-loading-every-once-in-a-while/881114)**: Mac troubleshooting separated the redownloadable WoW Data folder from Interface/AddOns and WTF settings, which users were told to back up first.
- **GL052 | core | [Mac WoW reinstall preserved three user folders](https://us.forums.blizzard.com/en/wow/t/ui-taking-too-long-to-load-since-7-3-5/16847)**: Mac users discussed reinstalling WoW while backing up and restoring WTF, Interface, and Screenshots because those held the valuable personal state.
- **GL053 | core | [WoW folders on macOS 11 were outside the app bundle](https://us.forums.blizzard.com/en/wow/t/wow-wtf-and-macos-11/773823)**: A new Mac user searched inside the WoW app bundle for Interface and WTF, but the active folders were beside the app under the retail directory.
- **GL054 | adjacent | [WoW drive migration split payload from settings and screenshots](https://us.forums.blizzard.com/en/wow/t/switching-to-new-drive/651175)**: A player moving WoW to a new drive identified WTF, Interface, and Screenshots as the parts worth preserving even if the game client was reinstalled.
- **GL055 | owner_fact | [Delete Battle.net owner state on Mac](https://us.support.blizzard.com/en/article/34719)**: Blizzard identifies /Users/Shared/Battle.net/Agent, agent.db, and the Battle.net shared folder as repair targets and warns that deleting them can make the app forget game locations.
- **GL056 | owner_fact | [Uninstall games through Battle.net](https://us.support.blizzard.com/en/article/Uninstalling-Games-with-the-Battle-net-App)**: Blizzard documents owner-managed game uninstall and says player data for supported games remains on Blizzard servers, while leftover local files may remain.
- **GL057 | owner_fact | [Delete the Battle.net cache folder](https://us.support.blizzard.com/en/article/34721)**: Blizzard publishes a separate procedure for removing Battle.net cache so the owner app can rebuild it.
- **GL058 | owner_fact | [Reset game folder permissions on Mac](https://us.support.blizzard.com/en/article/71962)**: Blizzard treats Mac game-folder permission failure as a repair problem for the folder and enclosed files.
- **GL059 | owner_fact | [Check case-sensitive volumes for Blizzard games on Mac](https://us.support.blizzard.com/en/article/31352)**: Blizzard identifies case-sensitive volumes as a cause of Mac installation problems.

### itch.io

- **GL060 | core | [itch install failed when the expected Mac Applications path was missing](https://github.com/itchio/itch/issues/2127)**: A macOS install failed when ~/Applications did not exist, and another case failed when itch.app existed but setup state.json did not.
- **GL061 | core | [itch could reinstall but not update a bundled Mac game](https://github.com/itchio/itch/issues/2952)**: A developer's signed .app game launched when downloaded directly, but itch could not update it in place; uninstall and clean reinstall worked.
- **GL062 | owner_fact | [itch external install paths need compatible filesystems](https://github.com/itchio/itch/issues/1065)**: The owner issue records extraction to a staged archive on an incompatible external filesystem and proposes blocking unsupported install paths.
- **GL063 | core | [Clearing itch cache and user data did not fix a Mac launch crash](https://github.com/itchio/itch/issues/3474)**: A Mac user tried uninstall, reinstall, cache cleanup, and user-data cleanup, but a launcher crash remained.
- **GL064 | core | [itch sandbox hid a RenPy save on macOS](https://github.com/itchio/itch/issues/2223)**: A Mac player lost visible progress when sandboxing blocked RenPy from its normal save path under Library, even though the storage issue was path access rather than a deleted game.
- **GL065 | core | [itch user installed games to the wrong Library location](https://github.com/itchio/itch/issues/1033)**: A user accidentally installed many items to the default ~/Library location and wanted an owner-managed way to move them to another registered install location.
- **GL066 | core | [itch kept versioned butler files under Application Support](https://github.com/itchio/itch/issues/2616)**: A Mac user found butler downloaded under Application Support/itch/broth/versions but missing from the apps link expected by the launcher.
- **GL067 | core | [Deleting an itch app forced Mac trust setup again](https://github.com/itchio/itch/issues/2820)**: A Mac report noted that deleting and restoring an unsigned app repeated the manual trust action required by macOS.
- **GL068 | core | [itch sandbox launch failed for a Java game on Mac](https://github.com/itchio/itch/issues/2378)**: A Mac user reported that a Java game ran outside the itch sandbox but failed inside it because the sandbox launch path could not find a class.
- **GL069 | owner_fact | [itch reinstall should repair bundle permissions](https://github.com/itchio/itch/issues/2314)**: A maintainer issue says reinstall did not reconfigure a Mac bundle with missing execute permission and proposes always repairing it.
- **GL070 | adjacent | [itch user wanted visible progress for multiple game downloads](https://github.com/itchio/itch/issues/2325)**: A user asked for system-visible progress while downloading one or more games because active download state was hard to see.
- **GL071 | owner_fact | [itch install locations](https://itch.io/docs/itch/using/install-locations.html)**: itch defines registered install locations, lets users add more, and chooses the last-used location for later installs.
- **GL072 | owner_fact | [itch scans for owner metadata before importing games](https://itch.io/docs/itch/using/scan-install-locations.html)**: itch can re-import only folders with its .itch metadata and cannot identify website downloads placed there manually.
- **GL073 | owner_fact | [itch sandbox can create alternate save roots](https://itch.io/docs/itch/using/sandbox.html)**: itch says sandbox modes may isolate or simulate home directories, so saves can remain on disk while becoming invisible after a mode change.
- **GL074 | owner_fact | [itch versioned dependencies under macOS Application Support](https://itch.io/docs/itch/installing/dependencies.html)**: itch stores downloaded runtime dependencies under ~/Library/Application Support/itch/broth and uses butler plus a SQLite database to manage installs.
- **GL075 | owner_fact | [itch download compatibility and offline library](https://itch.io/docs/itch/using/downloading.html)**: itch filters downloads by platform, can show incompatible builds with a warning, and keeps the user's own library searchable offline.
- **GL076 | owner_fact | [itch per-game launch and sandbox settings](https://itch.io/docs/itch/using/launch-settings.html)**: itch stores per-game arguments, wrappers, environment variables, and sandbox overrides that can be required for a game to launch.

### Heroic Games Launcher

- **GL077 | core | [Heroic could not import Mac games from a shared drive](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4562)**: A Mac user selected .app games installed on a shared drive by another launcher or Mac, but Heroic returned to the game page without importing them.
- **GL078 | core | [Heroic downloaded a native Mac game before installation failed](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4036)**: On macOS 15, Heroic completed the game download but then marked installation failed while a direct GOG download worked.
- **GL079 | core | [Heroic could not uninstall an Amazon game missing from disk](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4127)**: A deleted Amazon game remained in Heroic as not available, and the owner uninstall action failed before removing the record.
- **GL080 | core | [Heroic redownloaded an unwanted GPTK runtime](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4964)**: A Mac user deleted an unused roughly 1 GB GPTK runtime, but Heroic downloaded it again and sometimes replaced the preferred CrossOver setting.
- **GL081 | core | [Heroic reinstalled GPTK and changed the saved Wine choice](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/5428)**: A Mac user said each restart restored GPTK and made it the default after the user removed it and selected Wine Staging.
- **GL082 | core | [Heroic Move Game failed with the macOS rsync version](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/3697)**: Heroic's Move Game action failed on macOS because its rsync arguments were not accepted by the system version.
- **GL083 | core | [A macOS username change left Heroic paths stale](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/5079)**: After the macOS account and home name changed, Heroic did not update configuration and game paths.
- **GL084 | core | [Heroic confused a native Mac app with its parent install folder](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4246)**: For native games installed as a single .app, Heroic's Install Path action opened the app rather than its containing folder.
- **GL085 | core | [Heroic could not import an Amazon game from an external drive](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4463)**: A user moved to a new computer with games on an external drive. Heroic imported GOG and Epic installs but stopped while importing Amazon games.
- **GL086 | core | [Heroic used the wrong Wine prefix for a GOG game on Mac](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/3084)**: A Mac user found Heroic launching a GOG game through the default ~/.wine prefix while the launcher showed another configured prefix.
- **GL087 | core | [Heroic expected missing helper tools under Mac Application Support](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/2438)**: A Mac report found winetricks absent under Heroic Application Support and identified other helper binaries missing from the runtime.
- **GL088 | adjacent | [Heroic game shortcut kept stale Mac metadata](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/4350)**: After a user renamed an installed game and changed its icon, Heroic created a Mac shortcut with the new name but the old icon.
- **GL089 | adjacent | [Heroic reported a Mac shortcut created when no file appeared](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/5636)**: Heroic displayed success for a manually added program shortcut, but no shortcut appeared in either Applications location checked by the user.
- **GL090 | adjacent | [Heroic needed Rosetta before compatibility tools could run](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/3292)**: Heroic actions on Apple silicon failed through helper commands when Rosetta was absent, leading to a request for an explicit warning.
- **GL091 | owner_fact | [Heroic macOS configuration, cache, and game logs](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/Troubleshooting)**: Heroic documents macOS cache under ~/Library/Application Support/heroic plus separate configuration, store, GameConfig, install logs, and play logs.
- **GL092 | owner_fact | [Heroic Wine and Proton prefix model](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/How-To%3A-Wine-and-Proton)**: Heroic passes a selected WINEPREFIX or STEAM_COMPAT_DATA_PATH and searches several locations for Wine and Proton versions.
- **GL093 | owner_fact | [Fully remove Heroic on Mac](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/Removing-Uninstalling-Heroic-Games-Launcher)**: Heroic separates the app, config folder, installed game folder, and prefixes in its Mac removal instructions and marks game and prefix deletion as optional.
- **GL094 | owner_fact | [Heroic save paths can live inside Wine prefixes](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/Game-Workarounds)**: Heroic warns that cloud sync depends on the correct save path and that Windows game saves often live inside the Wine prefix.
- **GL095 | owner_fact | [Heroic Mac compatibility runtimes](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/Using-Heroic-on-a-Mac-computer)**: Heroic supports several Mac compatibility layers, downloads some through its manager, and requires Rosetta for x86_64 software on Apple silicon.
- **GL096 | owner_fact | [Steam games installed inside a Heroic Wine prefix on Mac](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/wiki/Installing-Steam-for-Windows-on-MacOS/45eaa195e31ec2a4003526ebfd9cfd3d365fdabb)**: Heroic's Mac guide says Windows Steam games can live inside the selected prefix and warns that deleting the prefix loses all downloaded content.

### Whisky

- **GL097 | core | [Moving one Whisky bottle cleared pins from all bottles](https://github.com/Whisky-App/Whisky/issues/830)**: Changing the default bottle path and moving one bottle cleared pinned programs across moved and unmoved bottles.
- **GL098 | core | [New Whisky bottles disappeared from the owner list](https://github.com/Whisky-App/Whisky/issues/798)**: A user created bottles that disappeared from Whisky's list immediately, leaving uncertainty about whether files remained on disk.
- **GL099 | core | [Whisky bottle vanished and no Finder folder appeared](https://github.com/Whisky-App/Whisky/issues/1237)**: A user saw a newly created bottle for about a second, then it vanished and no bottle folder appeared in Finder.
- **GL100 | core | [A Steam bottle disappeared after creation in Whisky](https://github.com/Whisky-App/Whisky/issues/1231)**: A user's Steam bottle disappeared milliseconds after creation although the same workflow had worked the day before.
- **GL101 | core | [Genshin installer saw too little disk space in Whisky](https://github.com/Whisky-App/Whisky/issues/443)**: A user received an insufficient-space warning from a game installer inside Whisky despite choosing a destination believed to have room.
- **GL102 | core | [Whisky users could leave gigabytes of bottles after abandoning the app](https://github.com/Whisky-App/Whisky/issues/411)**: A user asked for a full uninstaller because people can remove or abandon Whisky without realizing that bottles remain and occupy gigabytes.
- **GL103 | core | [Whisky bottle export to an external SSD lacked progress](https://github.com/Whisky-App/Whisky/issues/827)**: A user exporting bottles to an external SSD to free laptop space could only infer progress from the growing archive file.
- **GL104 | core | [Whisky logs grew to 187 GB](https://github.com/Whisky-App/Whisky/issues/1115)**: A user traced low disk space to Whisky logs under ~/Library/Logs/com.isaacmarovitz.Whisky, with the largest file at 187 GB and repeating msync errors.
- **GL105 | core | [Whisky repeated errors into a 10 GB log](https://github.com/Whisky-App/Whisky/issues/1261)**: A user found a 10 GB log made from the same repeating errors and asked for repeated lines to be collapsed.
- **GL106 | core | [A Whisky game could not read its own save files](https://github.com/Whisky-App/Whisky/issues/479)**: A user created a world and character, saved, exited, then could not load them because the game lacked expected file access inside Whisky.
- **GL107 | core | [Wine misreported free space for a Whisky bottle on a 4 TB external drive](https://github.com/Whisky-App/Whisky/issues/510)**: A bottle on a 4 TB external drive with 2247 GB available reported only 47 GB to Wine and blocked a Steam game install.
- **GL108 | core | [Steam in Whisky showed an uninstalled game still using space](https://github.com/Whisky-App/Whisky/issues/337)**: After uninstalling Elden Ring, Steam inside Whisky still showed its space as occupied while macOS storage did not.
- **GL109 | core | [A game in Whisky saw 5 GB free when macOS had 145 GB](https://github.com/Whisky-App/Whisky/issues/387)**: A game reported only 5 GB free inside Whisky while the user reported 145 GB available on the Mac.
- **GL110 | core | [Removed Whisky bottles could leave full files on disk](https://github.com/Whisky-App/Whisky/issues/403)**: Whisky could remove a bottle from its UI without deleting the files, after which the user had no easy way to review or restore the unregistered bottle.
- **GL111 | core | [Reinstalling Whisky did not restore bottle creation](https://github.com/Whisky-App/Whisky/issues/1191)**: After a reinstall, a user got a blank app after bottle creation and could not recover normal behavior through broader cleanup attempts.
- **GL112 | adjacent | [Whisky and CrossOver bottle sharing was unclear](https://github.com/Whisky-App/Whisky/issues/790)**: A user wanted to share bottles between Whisky and CrossOver but could not identify a supported path.
- **GL113 | owner_fact | [Whisky bottles and shared Steam libraries](https://docs.getwhisky.app/)**: Whisky defines each bottle as a self-contained Windows filesystem and recommends a separate shared Steam library so games survive bottle replacement.
- **GL114 | owner_fact | [Whisky remove and delete are different commands](https://docs.getwhisky.app/whiskycmd.html)**: WhiskyCmd lists bottles from BottleVM.plist and has separate delete-from-disk and remove-from-Whisky commands, plus add from Metadata.plist.

### Prism Launcher

- **GL115 | adjacent | [Prism users wanted external instance folders from several launchers](https://github.com/PrismLauncher/PrismLauncher/issues/1566)**: A user wanted Prism to load instances stored by several launchers without copying each instance into one owner folder.
- **GL116 | adjacent | [Prism appeared to lose instances when a drive was unplugged](https://github.com/PrismLauncher/PrismLauncher/issues/5775)**: A user opened Prism while the instance drive was unplugged and then saw the instances gone, raising concern that owner state had been changed.
- **GL117 | adjacent | [Prism users needed several instance roots to manage drive space](https://github.com/PrismLauncher/PrismLauncher/issues/901)**: A player wanted important modpacks on a small fast drive and other packs on a larger drive through multiple instance folders.
- **GL118 | adjacent | [Changing Prism's instance folder did not imply moving its contents](https://github.com/PrismLauncher/PrismLauncher/issues/1089)**: A user asked Prism to offer a content move when the configured instance folder changes instead of only pointing new operations elsewhere.
- **GL119 | adjacent | [Prism instances duplicated resource and shader packs](https://github.com/PrismLauncher/PrismLauncher/issues/38)**: A player wanted shared resource packs and shader packs because separate instances required repeated downloads or copies.
- **GL120 | adjacent | [Changing a Prism folder did not move the shared Minecraft payload](https://github.com/PrismLauncher/PrismLauncher/issues/5934)**: A user with a full system drive changed the instance folder but found shared Minecraft files still on the original drive.
- **GL121 | adjacent | [Prism users wanted central resource and shader pack folders](https://github.com/PrismLauncher/PrismLauncher/issues/2056)**: A player asked for central resource and shader pack folders because separate instances duplicated the same large files.
- **GL122 | adjacent | [Prism proposal described a cache for repeated mod downloads](https://github.com/PrismLauncher/PrismLauncher/issues/1221)**: A user proposed caching downloaded mods and using links or copy-on-write clones to avoid duplicate files across instances.
- **GL123 | adjacent | [Prism redirect cache could persist after its purpose ended](https://github.com/PrismLauncher/PrismLauncher/issues/4108)**: A user asked Prism to clear its redirect cache automatically because cached download redirects could become stale.
- **GL124 | adjacent | [A Prism user wanted to offload mods while keeping saves and settings](https://github.com/PrismLauncher/PrismLauncher/issues/5597)**: A user wanted to remove or offload downloadable mods from old instances while retaining saves, settings, and other personal state.
- **GL125 | adjacent | [Prism could fail poorly when the disk filled during an operation](https://github.com/PrismLauncher/PrismLauncher/issues/2371)**: A user reported poor handling when an operation ran out of disk space, leaving uncertainty about the partial result.
- **GL126 | adjacent | [A Prism log grew to several gigabytes](https://github.com/PrismLauncher/PrismLauncher/issues/752)**: A user reported a launcher log reaching about four gigabytes during repeated output.
- **GL127 | adjacent | [A Prism user wanted old modpacks moved to archive storage](https://github.com/PrismLauncher/PrismLauncher/issues/5808)**: A user wanted inactive modpacks moved to a slower archive drive without losing their launcher identity.
- **GL128 | adjacent | [Prism users wanted screenshots managed across instances](https://github.com/PrismLauncher/PrismLauncher/issues/1027)**: A user asked for a central view of screenshots stored inside several instances.
- **GL129 | owner_fact | [Prism Launcher data location](https://prismlauncher.org/wiki/getting-started/data-location/)**: Prism documents its platform data locations and the files and folders stored under its data root.
- **GL130 | owner_fact | [Prism Launcher settings](https://prismlauncher.org/wiki/help-pages/launcher-settings/)**: Prism documents launcher settings that control folders, Java, downloads, and other owner state.
- **GL131 | owner_fact | [Migrating MultiMC instances into Prism Launcher](https://prismlauncher.org/wiki/getting-started/migrating-multimc/)**: Prism documents migration as moving or copying instance data into an owner-recognized location.
- **GL132 | owner_fact | [Installing loader mods in Prism Launcher](https://prismlauncher.org/wiki/help-pages/loader-mods/)**: Prism documents mods as instance-managed files with enablement and dependency state.
- **GL133 | owner_fact | [Copying a Prism Launcher instance](https://prismlauncher.org/wiki/help-pages/instance-copy/)**: Prism provides an owner operation to copy an instance and select which data is included.
- **GL134 | owner_fact | [Managing screenshots in Prism Launcher](https://prismlauncher.org/wiki/help-pages/screenshots-management/)**: Prism documents viewing, uploading, and deleting screenshots tied to instances.
- **GL135 | owner_fact | [Importing a zip instance into Prism Launcher](https://prismlauncher.org/wiki/help-pages/zip-import/)**: Prism documents importing packaged instances from local files or links.
- **GL136 | owner_fact | [Java settings in Prism Launcher](https://prismlauncher.org/wiki/help-pages/java-settings/)**: Prism documents Java runtimes as launch dependencies selected globally or per instance.

### ATLauncher

- **GL137 | core | [ATLauncher runtime data appeared in a macOS temporary folder](https://github.com/ATLauncher/ATLauncher/issues/502)**: A macOS user found the jar build writing launcher runtime data under a private temporary folder while the app build failed to launch instances.
- **GL138 | core | [ATLauncher copied downloaded mod files into instances](https://github.com/ATLauncher/ATLauncher/issues/566)**: A macOS user observed downloaded mod jars being copied into an instance, leaving both the source download and installed copy.
- **GL139 | core | [ATLauncher instances consumed about 30 GB inside the app bundle path](https://github.com/ATLauncher/ATLauncher/issues/820)**: A macOS user reported roughly 30 GB of instance data under the launcher's app-related path and asked to move it.
- **GL140 | core | [ATLauncher users asked to change the instance folder](https://github.com/ATLauncher/ATLauncher/issues/654)**: A user asked for a supported way to change where launcher instances are stored.
- **GL141 | core | [ATLauncher on macOS did not accept an external CurseForge download](https://github.com/ATLauncher/ATLauncher/issues/705)**: A macOS user could download a pack outside the launcher but could not get the launcher to recognize it.
- **GL142 | core | [A new ATLauncher install failed downloads until the user retried on another network](https://github.com/ATLauncher/ATLauncher/issues/976)**: A macOS user hit rate-limit failures during a new instance install and retried through another network.
- **GL143 | core | [ATLauncher placed a game directory inside its macOS app contents](https://github.com/ATLauncher/ATLauncher/issues/989)**: A macOS user reported a game directory under ATLauncher.app Contents, and a launcher update disrupted the instance.
- **GL144 | core | [A mod could not read or write in an ATLauncher macOS instance](https://github.com/ATLauncher/ATLauncher/issues/880)**: A macOS user reported that a mod could not read and write expected files inside an ATLauncher instance.
- **GL145 | core | [ATLauncher did not see requested mods in macOS Downloads](https://github.com/ATLauncher/ATLauncher/issues/645)**: A macOS user said requested mod files were present in Downloads but the launcher could not see them despite permission changes.
- **GL146 | core | [ATLauncher file picker showed protected macOS folders as empty](https://github.com/ATLauncher/ATLauncher/issues/430)**: A macOS user saw Downloads, Documents, and Desktop as empty in the add-mod file picker even after granting broad disk access.

### Minecraft

- **GL147 | owner_fact | [Transferring a Minecraft license between devices](https://help.minecraft.net/hc/en-us/articles/4408945065357-Transferring-Your-Minecraft-Bedrock-Edition-or-Minecraft-Legends-License-Between-Devices)**: Minecraft support separates account license access from locally stored game worlds and device data.
- **GL148 | owner_fact | [Troubleshooting Minecraft Launcher startup](https://help.minecraft.net/hc/en-us/articles/23431114561037-Troubleshooting-Launching-Minecraft-from-the-Minecraft-Launcher)**: Minecraft support includes launcher and Java troubleshooting steps while warning that prior settings or modifications can affect behavior.
- **GL149 | owner_fact | [Minecraft Java Edition hotkeys and screenshots](https://help.minecraft.net/hc/en-us/articles/360059148111-Minecraft-Java-Edition-Hotkeys)**: Minecraft documents the screenshot hotkey and the creation of screenshot files during play.
- **GL150 | owner_fact | [Accounts required to play Minecraft](https://help.minecraft.net/hc/en-us/articles/19615552270221-Accounts-Required-to-Play-Minecraft)**: Minecraft documents the account requirements used to authenticate and access editions of the game.
- **GL151 | owner_fact | [Downloading and installing Minecraft Launcher](https://help.minecraft.net/hc/en-us/articles/23907917790093)**: Minecraft support documents the launcher as the owner-managed entry point for downloading and starting game versions.

### PlayCover

- **GL152 | core | [PlayCover import reported a full disk during extraction](https://github.com/PlayCover/PlayCover/issues/2188)**: A macOS user importing an app saw a disk-full extraction error followed by an illegal byte-sequence error.
- **GL153 | core | [A PlayCover game downloaded more resources after IPA installation](https://github.com/PlayCover/PlayCover/issues/2206)**: A macOS user reached an in-game resource download after installing the IPA, showing that the installed app was not the full storage footprint.
- **GL154 | core | [Clearing PlayCover data and cache did not fix a crash](https://github.com/PlayCover/PlayCover/issues/2172)**: A user reinstalled and cleared PlayCover data and cache, but the application still crashed.
- **GL155 | core | [PlayCover failed while installing an IPA](https://github.com/PlayCover/PlayCover/issues/2169)**: A macOS user reported an error during IPA installation, leaving uncertain install state.
- **GL156 | core | [A PlayCover game decompressed shaders during startup](https://github.com/PlayCover/PlayCover/issues/1921)**: A macOS user saw a game spend startup time decompressing shaders before failing later in launch.

## Distilled patterns

### 1. One visible game has several storage owners and roles

The install can include an owner package, patch staging, manifests, entitlement state, saves, screenshots, mods, cloud-sync state, and compatibility files. These can be in different roots. A single folder label such as "Steam data" is too coarse.

### 2. Owner inventory and filesystem presence can disagree

A launcher can forget a valid external library, bottle, or copied install. A folder can also remain after the owner record is removed. Tessera must show both facts:

- Files exist at this path.
- The owner currently recognizes or does not recognize them.

A disagreement is a repair or review state. It is not automatic proof of an orphan.

### 3. External volumes must fail closed

Unmounted volumes, changed mount points, missing security bookmarks, permission failures, case-sensitive filesystems, and unsupported formats can make a valid library appear missing. Tessera must record stable volume identity where possible and stop cleanup when the volume is unavailable.

### 4. A move is a transaction, not a copy command

A safe move needs these gates:

1. Resolve the exact source and target volume.
2. Check free space, format, permissions, and owner support.
3. Copy all selected roles.
4. Verify byte or owner integrity.
5. Import or register the new location with the owner.
6. Launch or otherwise validate the destination.
7. Confirm the exact old path and consequence.
8. Remove the source only after every earlier gate passes.

Changing a default install folder does not prove that existing data moved.

### 5. Personal state outranks redownload cost

Saves, worlds, screenshots, recordings, add-on settings, macros, mods, and instance configuration can be small but hard or impossible to recreate. Installed packages can be large but recoverable. Tessera must sort by recovery risk before size.

### 6. Cloud enabled is not backup proof

Cloud support can be optional, game-specific, stale, conflicted, or limited to selected paths. Account entitlement also does not prove that local saves or worlds are backed up. Tessera needs per-game sync evidence and a last-known successful state before it changes local personal data.

### 7. Compatibility state is a nested owner boundary

A bottle or prefix can contain a second launcher and several games. It can also hold registry state, authentication, game saves, mods, and runtime files. Tessera must inspect the nested structure before it offers any reclaim action.

### 8. Caches and logs are lower-risk, not risk-free

A web cache, redirect cache, patch cache, log, or shader cache can often be rebuilt. Tessera still needs to check for active writers, active installs, active patching, shared references, and documented owner behavior. Large recurring logs also need a cause or growth warning after cleanup.

### 9. Remove from list and delete from disk are different actions

Several owners can remove an item from their interface without removing its files, or remove files while preserving separate owner state. Tessera must use distinct labels:

- Hide or unregister from owner.
- Delete local files.
- Reset owner state.
- Uninstall through owner.

Every action must state what stays and what is lost.

### 10. Downloads and extraction output have lifecycle state

An archive can be unimported, importing, installed, failed, retained for backup, or safe to redownload. Patch files can be active, paused, failed, or stale. Tessera needs lifecycle state before it calls these bytes temporary.

### 11. Permissions can imitate absence

Protected macOS folders, sandbox rules, owner security bookmarks, and shared helper folders can be unreadable even when data exists. Tessera must report "access unavailable" instead of "empty" or "orphaned."

### 12. Cleanup should stop the growth loop

Removing a runaway log or stale cache can reclaim space once. Tessera should also identify the writing process, show recent growth, and warn when the same owner is likely to recreate the data.

## Counterexamples

- Clearing cache did not fix every reported crash. Cache cleanup must not be sold as a repair guarantee.
- A launcher can report insufficient space even when Finder shows free space because staging, preallocation, target format, or a different checked volume changes the result.
- A copied install can exist but remain unusable until the owner imports or verifies it.
- An owner can report success while files are incomplete, missing, or placed under another root.
- A launcher can appear to lose all instances when an external drive is unplugged. That is not proof that the instances were deleted.
- A duplicate archive can be an intentional offline backup. Byte duplication is not enough to call it waste.
- A shader directory can be rebuildable for one game and contain selected user shader packs for another. Name matching alone is unsafe.

## Product implications for Tessera

### Required object model

Each discovered path should carry:

- `owner_family`
- `logical_game_or_instance_id`
- `storage_role`
- `exact_path`
- `physical_volume_id`
- `volume_state`
- `owner_registration_state`
- `active_write_state`
- `recovery_class`
- `redownload_or_rebuild_source`
- `cloud_sync_state`
- `user_created_state`
- `compatibility_container_id`
- `last_owner_validation`
- `dependencies_and_dependents`

Unknown values must remain unknown. Tessera must not convert an unknown into a safe-to-delete result.

### Required user actions

Tessera should offer five clear actions:

1. **Protect.** Mark saves, worlds, screenshots, mods, settings, or any selected item as retained.
2. **Reclaim rebuildable data.** Select exact inactive cache, log, shader, download, or failed-staging paths after checks.
3. **Uninstall with owner.** Open or invoke the supported owner removal flow for installed payloads.
4. **Move safely.** Run the verified transaction for a game, library, instance, or bottle.
5. **Review possible orphan.** Explain why owner and filesystem state disagree. Require exact-path confirmation.

### Required confirmation

Before any deletion, show:

- Exact path.
- Exact measured size.
- Owner and game or instance.
- Storage role.
- Why Tessera thinks it is reclaimable.
- What will stop working or need to download again.
- What personal data was found nearby and protected.
- Whether the owner is closed and the path has no active writer.
- Whether the item is on an external volume.
- The recovery method, if one exists.

Confirmation must apply only to the selected exact paths. A category-level approval must not expand to hidden descendants.

### Recommended first version

The first safe release should be conservative:

- Read owner roots and inventories.
- Group data by game or instance and role.
- Detect external-volume state.
- Protect personal and authentication state.
- Identify exact, inactive, owner-documented caches and logs.
- Prefer owner uninstall for installed payloads.
- Support a verified move flow.
- Put all possible orphans in review.
- Never delete automatically.

## Exact de-duplication proof

The final comparison selected every current corpus input with:

```bash
rg --files docs/research | rg '(ledger|market-scan)\.jsonl$'
```

The new game-library ledger was excluded from the prior-corpus side of the comparison. Each prior file's `.url` value was read with `jq -r .url`.

Final result:

- Prior corpus inputs: 14 files.
- Prior corpus unique URLs: 3,090.
- Selected records: 156.
- Selected exact unique URLs: 156.
- Internal exact duplicates: 0.
- Internal duplicates after removing one trailing slash: 0.
- Exact overlap with the prior corpus: 0.
- Overlap after removing one trailing slash: 0.
- URLs with a query string or fragment: 0.

The comparison used sorted URL sets and `comm -12`. The normalized comparison used the same sets after `jq` removed one trailing slash. No fragment, tracking parameter, search page, or trailing-slash variant was used to create novelty.

## Files and validation

- `docs/research/tessera-disk-rescue-game-library-agent-lane-2026-08-31.md`
- `docs/research/tessera-disk-rescue-game-library-ledger.jsonl`

Validation result: 156 JSONL records parsed with `jq`; all records have the required schema, collection ID, date, and continuous IDs from GL001 through GL156; 156 URLs are unique; internal duplicates are 0; exact and normalized overlap with 3,090 URLs across 14 prior corpus inputs is 0.
