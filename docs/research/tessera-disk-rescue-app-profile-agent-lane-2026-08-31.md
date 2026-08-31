# Tessera disk rescue: app profile boundary, lane C

Date: 2026-08-31
Collection: `app-profile-lane-2026-08-31`
Records: 183

## Scope

This lane answers one question: how should Tessera distinguish disposable browser or app caches from profiles, session restore, local databases, offline data, extensions, credentials or encryption state, downloads, drafts, and workspace state on macOS?

The selected corpus covers Zen Browser, Brave, Firefox, Chrome and Chromium, Safari and WebKit, VS Code, JetBrains IDEs, Slack, and Discord. User evidence comes from first-person reports in owner issue trackers or owner-hosted support communities. Product facts come from owner documentation or owner-maintained source documentation.

## Method

1. Selected every current corpus input with `rg --files docs/research | rg '(ledger|market-scan)\.jsonl$'`.
2. Read every existing `.url` value with `jq -r '.url'`.
3. Built an initial exact set of 2,683 pre-existing URLs from 12 files before writing.
4. Removed query strings, fragments, search pages, and trailing-slash variants from candidates instead of treating them as novel URLs.
5. Compared all 183 candidate URLs by exact string against the pre-existing set.
6. Read issue bodies or first-person support posts for user evidence.
7. Used first-party documentation for product behavior and path boundaries.
8. Excluded memory-only performance reports unless the source also established a disk, profile, session, or state boundary.
9. Did not infer prevalence. Each report is one observed case.
10. Repeated the full comparison before handoff after two concurrent lane ledgers appeared. The final pre-existing set contained 3,063 unique URLs from 14 files.

## Exact counts

### By owner family

| Owner family | Records |
|---|---:|
| Zen Browser | 29 |
| Brave | 29 |
| Firefox | 18 |
| Chrome and Chromium | 17 |
| Safari and WebKit | 17 |
| VS Code | 38 |
| JetBrains | 18 |
| Slack | 5 |
| Discord | 12 |
| Total | 183 |

### By source type

| Source type | Records |
|---|---:|
| Owner issue tracker | 79 |
| Direct support community | 46 |
| Owner documentation | 58 |
| Total | 183 |

### By evidence class

| Evidence class | Records |
|---|---:|
| core | 120 |
| adjacent | 5 |
| owner_fact | 58 |
| Total | 183 |

### By source kind

| Source kind | Records |
|---|---:|
| First-person issue report | 74 |
| Owner issue tracker context | 5 |
| First-person support report | 46 |
| Official product documentation | 58 |
| Total | 183 |

## Screening limits

- The corpus records observed failure modes and owner-defined behavior. It does not measure how often each event occurs.
- Support-community replies can be wrong or version-specific. The report uses the first-person event as evidence and uses owner documentation for product facts.
- GitHub issues can be incomplete, unreproduced, duplicated, or fixed in later releases. They still establish the reported boundary between cache and user state.
- Some records cover Windows or Linux when they prove a cross-platform profile dependency that also exists in the product family. macOS actions are based on owner macOS documentation where available.
- Cloud sync behavior, retention, and profile formats can change. Tessera needs versioned owner adapters and should show the source date.
- A URL returning a valid page does not prove every claim in user text. Product implications use only the disk or state boundary supported by the report.
- Private-browsing state, volatile memory state, and data that was never written to disk cannot be recovered by a disk rescue tool.

## Selected records

### Zen Browser

- AP001. [New profile created after power outage](https://github.com/zen-browser/desktop/issues/14690): After a power outage, Zen opened a new-looking profile and the reporter lost settings, cookies, and extension settings.
- AP002. [All spaces, pins, and Essentials gone](https://github.com/zen-browser/desktop/issues/14276): The reporter opened Zen and found all spaces, pinned tabs, and Essentials missing.
- AP003. [Previous tabs not opened](https://github.com/zen-browser/desktop/issues/9107): Zen failed to open the previous tabs after restart.
- AP004. [Zen keeps logging me out](https://github.com/zen-browser/desktop/issues/7212): The reporter was repeatedly signed out of sites while using Zen.
- AP005. [Blank startup after tab corruption](https://github.com/zen-browser/desktop/issues/12073): Zen opened a blank window after a tab or session failure.
- AP006. [Lost all spaces](https://github.com/zen-browser/desktop/issues/12812): The reporter lost every Zen space.
- AP007. [Random tab loss](https://github.com/zen-browser/desktop/issues/9313): The reporter described tabs disappearing without an intentional close.
- AP008. [macOS update lost tabs and preferences](https://github.com/zen-browser/desktop/issues/14141): After a macOS update, tabs and preferences appeared lost.
- AP009. [Containers disappeared](https://github.com/zen-browser/desktop/issues/14008): The reporter lost browser containers.
- AP010. [Pinned tabs and Essentials lost after Sync](https://github.com/zen-browser/desktop/issues/12336): On macOS, pinned tabs and Essentials disappeared after Sync activity.
- AP011. [Blank window and session loss after update](https://github.com/zen-browser/desktop/issues/12460): An update left the reporter with a blank window and no prior session.
- AP012. [Zen forgets Essentials, tabs, and workspaces](https://github.com/zen-browser/desktop/issues/9394): Zen repeatedly forgot Essentials, tabs, and workspaces.
- AP013. [Moving tabs lost workspace and open tabs](https://github.com/zen-browser/desktop/issues/12707): A tab move was followed by loss of a workspace and open tabs.
- AP014. [Restart removes pinned tabs and Essentials](https://github.com/zen-browser/desktop/issues/11157): Pinned tabs and Essentials disappeared after restart.
- AP015. [Auto-update lost all tabs](https://github.com/zen-browser/desktop/issues/12163): An automatic update was followed by total tab loss.
- AP016. [Reboot lost tabs](https://github.com/zen-browser/desktop/issues/8162): A system reboot was followed by missing tabs.
- AP017. [Update lost workspaces and tabs](https://github.com/zen-browser/desktop/issues/12028): An update removed visible workspaces and tabs.
- AP018. [Previous session not restored](https://github.com/zen-browser/desktop/issues/13022): Zen did not restore the previous session.
- AP019. [Backup existed but tabs were not recoverable](https://github.com/zen-browser/desktop/issues/14256): The reporter found backup data but could not recover the tabs through Zen.
- AP020. [Update deleted sessions](https://github.com/zen-browser/desktop/issues/15139): The reporter said an update deleted saved sessions.
- AP021. [Closing browser changed profiles and data disappeared](https://github.com/zen-browser/desktop/issues/14079): After closing Zen, the visible profile changed and data appeared gone.
- AP022. [Site data list is empty](https://github.com/zen-browser/desktop/issues/13906): The clear-data interface showed no sites even though site state was expected.
- AP023. [Restart logs out all accounts](https://github.com/zen-browser/desktop/issues/13482): Restarting Zen logged the reporter out of every account.
- AP024. [Cookies, history, and tabs deleted on every restart](https://github.com/zen-browser/desktop/issues/10377): The reporter lost cookies, history, and tabs after every restart.
- AP025. [Workspaces, pinned tabs, and folders lost](https://github.com/zen-browser/desktop/issues/13109): The reporter lost workspaces, pinned tabs, and tab folders.
- AP026. [Manage profiles](https://docs.zen-browser.app/guides/manage-profiles): Zen documents profile files for bookmarks, cookies, extensions, sessions, and the password file set, and says to close the app before copying.
- AP027. [Workspaces](https://docs.zen-browser.app/user-manual/workspaces): Zen workspaces can use separate containers while history and extensions remain profile-wide.
- AP028. [Extensions](https://docs.zen-browser.app/user-manual/extensions): Zen separates browser extensions from Mods and their preferences.
- AP029. [Window Sync and session backup](https://docs.zen-browser.app/user-manual/window-sync): Zen names zen-sessions.jsonlz4, sessionstore-backups, and zen-sessions-backup as session recovery state.

### Brave

- AP030. [Data loss reports in Brave](https://github.com/brave/brave-browser/issues/40375): A maintainer issue groups reports of apparently random browser data loss.
- AP031. [Urgent Brave profile deleted and critical data loss](https://github.com/brave/brave-browser/issues/55111): The reporter found two profiles deleted with critical personal data missing.
- AP032. [Cookies gone while site storage remains](https://github.com/brave/brave-browser/issues/47374): Cookies disappeared although site storage still consumed disk space.
- AP033. [Leo chats suddenly deleted](https://github.com/brave/brave-browser/issues/53162): The reporter lost local Leo chat history after a cache reset.
- AP034. [Logins and custom search engines gone](https://github.com/brave/brave-browser/issues/50568): Site logins and custom search engines disappeared while extensions, history, tabs, and the profile remained.
- AP035. [Sessions, accounts, and passwords gone](https://github.com/brave/brave-browser/issues/53456): The reporter lost sessions, account access, and passwords while tabs and the profile still existed.
- AP036. [Randomly logged out of all sites](https://github.com/brave/brave-browser/issues/39758): The reporter was logged out of all sites without enabling clear-on-exit.
- AP037. [Profile folder copy did not restore all state](https://github.com/brave/brave-browser/issues/8069): Copying a Brave profile restored some preferences but not extensions or passwords.
- AP038. [Cookie and localStorage deletion across users](https://github.com/brave/brave-browser/issues/50411): An owner tracker issue summarizes reports of cookies and localStorage disappearing after a Chromium update.
- AP039. [Internal upgrade test lost tab groups and tabs](https://github.com/brave/brave-browser/issues/44013): An owner test recorded tab-group and tab loss during an upgrade path.
- AP040. [Loss of data after an update](https://github.com/brave/brave-browser/issues/56249): The reporter lost tabs and bookmarks after an update.
- AP041. [Large session restore crashes](https://github.com/brave/brave-browser/issues/47792): A large saved session crashed during restoration.
- AP042. [Offline restart did not restore all tabs](https://github.com/brave/brave-browser/issues/42154): After power loss, Brave failed to restore tabs while offline.
- AP043. [Empty session restoration on macOS](https://github.com/brave/brave-browser/issues/10301): On macOS, restore opened an empty session.
- AP044. [Stale session restored after freeze](https://github.com/brave/brave-browser/issues/27730): After a freeze, Brave restored an older session instead of the latest state.
- AP045. [Overlapping restore prompts lost session recovery](https://github.com/brave/brave-browser/issues/18288): On macOS, overlapping restore prompts led to lost recovery state.
- AP046. [Active-tab save race reproduced by maintainer](https://github.com/brave/brave-browser/issues/40551): A maintainer reproduced a race that could omit the active tab from saved state.
- AP047. [Cookies and session data cleared every restart](https://github.com/brave/brave-browser/issues/57079): The reporter lost cookies and session state on each restart.
- AP048. [Logins and passwords do not survive reboot](https://github.com/brave/brave-browser/issues/45785): Saved logins and passwords did not survive a reboot.
- AP049. [Cookies and state not persisted after restart](https://github.com/brave/brave-browser/issues/44803): A direct report said cookies and site state were not persisted after restart.
- AP050. [Saved passwords lost without Sync](https://github.com/brave/brave-browser/issues/25198): Saved passwords disappeared on desktop systems where Sync was not a usable backup.
- AP051. [Deleting Temp reset Brave user data](https://github.com/brave/brave-browser/issues/45522): The reporter said deleting broad Temp and Prefetch folders reset Brave to a fresh state.
- AP052. [Service worker Cache Storage is not cleared by cached-file control](https://github.com/brave/brave-browser/issues/47275): The reporter found service worker Cache Storage survived the normal cached-file clearing control.
- AP053. [Saved passwords and logged-in sessions disappear after update](https://github.com/brave/brave-browser/issues/10672): After an update, saved passwords and logged-in sessions appeared gone, but a downgrade made them return.
- AP054. [Clear cookies and site data in Brave](https://support.brave.com/hc/en-us/articles/360048833872-How-Do-I-Clear-Cookies-And-Site-Data-In-Brave): Brave exposes separate controls for history, cached files, cookies, and site data.
- AP055. [Sync FAQ](https://support.brave.com/hc/en-us/articles/360047642371-Sync-FAQ): Brave states that Sync is not a backup service and server retention differs from local copies.
- AP056. [Reset Brave settings to default](https://support.brave.com/hc/en-us/articles/360017903152-How-do-I-reset-Brave-settings-to-default): Brave's reset keeps bookmarks, history, and saved passwords while resetting other settings.
- AP057. [Import or export browsing data](https://support.brave.com/hc/en-us/articles/360019782291-How-do-I-import-or-export-browsing-data): Brave import and export cover selected data types, not a complete profile image.
- AP058. [Sensitive data storage](https://support.brave.com/hc/en-us/articles/29808985123085-Sensitive-data-storage): Brave documents OS-backed encryption and local sensitive-data dependencies.

### Firefox

- AP059. [Refresh erased saved logins](https://support.mozilla.org/en-US/questions/1306785): After Firefox Refresh, the reporter lost saved logins and needed a matching logins.json and key4.db pair.
- AP060. [Update lost passwords](https://support.mozilla.org/en-US/questions/1233332): The reporter lost passwords after an update and recovery depended on matching key and login files.
- AP061. [Restored profile but passwords were missing](https://support.mozilla.org/en-US/questions/1253159): A profile restore brought back other data but not passwords.
- AP062. [Bookmarks restored but logins failed](https://support.mozilla.org/en-US/questions/1310179): Bookmarks returned, but mismatched credential files prevented login recovery.
- AP063. [Missing logins recovered from an old profile](https://support.mozilla.org/en-US/questions/1297681): The reporter recovered missing logins from an older Firefox profile.
- AP064. [Reinstall created a new profile while old data remained](https://support.mozilla.org/en-US/questions/1476994): After reinstall, Firefox used a new profile while the old profile still held credential files.
- AP065. [Profile copy restored most data but not passwords](https://support.mozilla.org/en-US/questions/1214197): A copied profile restored most data only after the correct password files were added.
- AP066. [Time Machine recovery on Mac](https://support.mozilla.org/en-US/questions/1224278): A Mac user sought to restore Firefox data from Time Machine.
- AP067. [Transfer passwords from an old disk profile](https://support.mozilla.org/en-US/questions/1278115): The reporter needed passwords from a Firefox profile on an old disk.
- AP068. [Large Firefox profile contained Zotero data](https://support.mozilla.org/en-US/questions/1070116): A large Firefox profile was traced to Zotero data rather than disposable web cache.
- AP069. [Profiles: where Firefox stores user data](https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data): Mozilla lists profile stores for places, sessions, cookies, extensions, passwords, and containers.
- AP070. [Recover important data from an old profile](https://support.mozilla.org/en-US/kb/about-your-important-data-and-their-files): Mozilla names the files used to recover specific profile data.
- AP071. [Back up and restore Firefox information](https://support.mozilla.org/en-US/kb/Backing%20up%20your%20information): Mozilla documents copying the closed Firefox profile as a backup and restore unit.
- AP072. [Restore a previous session](https://support.mozilla.org/en-US/kb/restore-previous-session): Mozilla documents session restoration and excludes private windows from saved sessions.
- AP073. [Local storage settings](https://support.mozilla.org/en-US/kb/storage): Mozilla separates persistent site storage from cached web content.
- AP074. [Clear cookies and site data](https://support.mozilla.org/en-US/kb/clear-cookies-and-site-data-firefox): Firefox offers separate controls for cookies, site data, and cached web content.
- AP075. [Refresh Firefox](https://support.mozilla.org/en-US/kb/refresh-firefox-reset-add-ons-and-settings): Firefox Refresh preserves selected essential data but removes extensions, extension data, preferences, and DOM storage.
- AP076. [Profile Manager](https://support.mozilla.org/en-US/kb/profile-management): Mozilla says profiles keep user data separate, with limited settings outside that boundary.

### Chrome and Chromium

- AP077. [History and tabs gone after update](https://support.google.com/chrome/thread/383042274/history-and-tabs-gone-after-update): After an update, the reporter lost visible history and tabs.
- AP078. [Update removed startup page and open tabs](https://support.google.com/chrome/thread/434649284/chrome-just-updated-and-nuked-my-startup-page-and-the-tabs-i-had-open-how-do-i-recover-that): A Chrome update removed the configured startup page and open tabs.
- AP079. [Tabs, data, history, and bookmarks gone](https://support.google.com/chrome/thread/408035838/tabs-data-history-bookmarks-gone): The reporter found several kinds of browser state missing at once.
- AP080. [Mac update lost history and saved tabs](https://support.google.com/chrome/thread/417420585/lost-all-my-chrome-history-and-saved-tabs-after-a-macbook-sofware-update): After a Mac software update, Chrome history and saved tabs disappeared.
- AP081. [Signed-in profiles and saved data lost](https://support.google.com/chrome/thread/331754532/lost-signed-in-google-chrome-profiles-and-their-saved-informations-passwords-bookmarks): The reporter lost visible signed-in profiles, passwords, and bookmarks.
- AP082. [Chrome loses all tabs on restart](https://support.google.com/chrome/thread/450897647/chrome-losing-all-tabs-on-restart): Chrome repeatedly lost all tabs after restart.
- AP083. [Chrome User Data directory is large and slow](https://support.google.com/chrome/thread/82160058/appdata-local-google-chrome-userdata-folder-takes-a-very-long-time-to-load-on-vm): The reporter found the full Chrome User Data tree large and slow to load.
- AP084. [New Chrome profile update lost tabs](https://support.google.com/chrome/thread/308375483/new-chrome-profile-update-lost-all-my-tabs-and-i-want-them-back): A profile update left the reporter without prior tabs.
- AP085. [Passwords disappeared from Chrome Password Manager](https://support.google.com/chrome/thread/352958584/all-of-my-passwords-have-disappeared-from-chrome-password-manager): The reporter lost visible passwords from Chrome Password Manager.
- AP086. [Login Data exists but the profile is not attached](https://support.google.com/chrome/thread/383715408): The report describes credential data existing on disk while Chrome no longer exposed the expected profile state.
- AP087. [Chromium user data directory](https://chromium.googlesource.com/chromium/src/%2Bshow/master/docs/user_data_dir.md): Chromium documents the macOS user data directory under Application Support and the cache outside it under Library/Caches.
- AP088. [Chromium user data storage policy](https://chromium.googlesource.com/chromium/src/%2Bshow/main/docs/user_data_storage.md): Chromium's storage guidance distinguishes configuration and user-created data from recreatable data.
- AP089. [Chrome extension storage API](https://developer.chrome.com/docs/extensions/reference/api/storage): Chrome documents local, sync, managed, and session extension storage with different lifetimes.
- AP090. [Extension storage and cookies](https://developer.chrome.com/docs/extensions/develop/concepts/storage-and-cookies): Chrome states that extension storage is not cleared like ordinary browsing data and can persist independently.
- AP091. [Manage Chrome profiles](https://support.google.com/chrome/answer/2364824): Google says deleting a profile removes that profile's bookmarks, history, passwords, and settings from the computer.
- AP092. [Delete Chrome browsing data](https://support.google.com/chrome/answer/2392709): Chrome distinguishes download history from downloaded files and offers separate data categories.
- AP093. [Chrome sessions API](https://developer.chrome.com/docs/extensions/reference/api/sessions): Chrome exposes recently closed tabs and windows as restorable session state.

### Safari and WebKit

- AP094. [Passwords moved out of Safari after update](https://discussions.apple.com/thread/256223133): The reporter thought Safari passwords were gone after they moved to the Passwords app.
- AP095. [Safari tabs disappeared after restart](https://discussions.apple.com/thread/256042734): The reporter lost Safari tabs after restart and sought SafariTabs.db recovery.
- AP096. [Tab groups lost after macOS update](https://discussions.apple.com/thread/256210284): Tab groups disappeared after a macOS update.
- AP097. [Reading List does not save offline](https://discussions.apple.com/thread/254598683): The reporter expected Reading List items to remain available offline.
- AP098. [SafariTabs database reached 35 GB](https://discussions.apple.com/thread/255681867): The reporter found SafariTabs.db using about 35 GB and asked whether it was safe to delete.
- AP099. [Keychain passwords lost after update](https://discussions.apple.com/thread/251393735): The reporter lost access to Keychain passwords after an update.
- AP100. [Safari size included tabs database and cache](https://discussions.apple.com/thread/255027692): The reporter traced Safari disk use to both SafariTabs.db and cache data.
- AP101. [Website database returns after removal](https://discussions.apple.com/thread/7916863): A website database returned after the user removed it.
- AP102. [Restore Safari windows and tabs](https://support.apple.com/guide/safari/go-back-to-websites-you-already-visited-ibrw1009/mac): Safari documents reopening recently closed tabs and windows and restoring the last session.
- AP103. [Clear cookies and website data in Safari](https://support.apple.com/guide/safari/sfri11471/mac): Apple warns that removing website data can sign the user out and can affect other apps.
- AP104. [Use Safari profiles](https://support.apple.com/guide/safari/ibrwf3a9e7d6/mac): Safari profiles separate history, cookies, website data, and extensions while some data remains shared.
- AP105. [Get Safari extensions](https://support.apple.com/guide/safari/get-extensions-sfri32508/mac): Safari extensions are distributed as apps and can be shared across devices.
- AP106. [Use the Passwords app](https://support.apple.com/guide/passwords/the-passwords-app-mchl901b1b95/mac): Apple manages website and app credentials in the Passwords app outside Safari.
- AP107. [Set up iCloud Keychain](https://support.apple.com/en-us/109016): Apple documents encrypted credential sync and local access through iCloud Keychain.
- AP108. [Keep a Reading List offline](https://support.apple.com/guide/safari/sfri35905/mac): Safari lets users explicitly save Reading List items for offline access.
- AP109. [Download items from the web](https://support.apple.com/guide/safari/sfri40598/mac): Safari separates downloaded files from the Downloads list and notes that moving a file breaks the list link.
- AP110. [Clear Safari browsing history](https://support.apple.com/guide/safari/sfri47acf5d6/mac): Clearing Safari history removes navigation records and the Downloads list but not downloaded files.

### VS Code

- AP111. [VACUUM shrank state.vscdb without deleting workspace state](https://github.com/microsoft/vscode/issues/235684): The reporter reduced workspace storage from about 995 MB to 219 MB by vacuuming state.vscdb.
- AP112. [Dirty files missing and Backups folder empty](https://github.com/microsoft/vscode/issues/114022): The reporter lost dirty files and found the expected Backups directory empty.
- AP113. [Auto-update lost unsaved files](https://github.com/microsoft/vscode/issues/230463): An automatic update was followed by loss of unsaved files.
- AP114. [Restart after update lost open and unsaved work](https://github.com/microsoft/vscode/issues/155385): The reporter lost open and unsaved work after restart.
- AP115. [Reopen Closed Editor data disappeared after update](https://github.com/microsoft/vscode/issues/181188): An update removed data expected through Reopen Closed Editor.
- AP116. [Update forgot saved open documents](https://github.com/microsoft/vscode/issues/197704): VS Code forgot saved open documents but restored unsaved ones.
- AP117. [macOS restart left untitled tabs empty](https://github.com/microsoft/vscode/issues/70247): After a macOS restart, untitled tabs reopened empty.
- AP118. [Update reopened tabs with empty content](https://github.com/microsoft/vscode/issues/69972): Tabs reopened after update but their unsaved content was empty.
- AP119. [Power loss lost open and unsaved files](https://github.com/microsoft/vscode/issues/52868): A power loss caused loss of open and unsaved files.
- AP120. [Closed untitled note needed recovery](https://github.com/microsoft/vscode/issues/114184): The reporter accidentally closed a persistent untitled note and sought recovery.
- AP121. [Forced restart caused data loss](https://github.com/microsoft/vscode/issues/1161): A forced restart caused unsaved work loss.
- AP122. [Crash lost edits](https://github.com/microsoft/vscode/issues/21183): A crash was followed by missing edits.
- AP123. [macOS restorable state kept only one unsaved document](https://github.com/microsoft/vscode/issues/30649): macOS restoration preserved only one of several unsaved documents.
- AP124. [Saving an untitled workspace lost chat history](https://github.com/microsoft/vscode/issues/301793): Saving an untitled workspace made prior chat history disappear.
- AP125. [Workspace hash change hid chat history](https://github.com/microsoft/vscode/issues/313223): Chat transcript files remained on disk but became invisible after a workspace hash changed.
- AP126. [Chat session files exist but are invisible](https://github.com/microsoft/vscode/issues/288600): The reporter found chat session files on disk although VS Code no longer listed them.
- AP127. [Chat history disappeared after update](https://github.com/microsoft/vscode/issues/298602): An update made chat history disappear.
- AP128. [Chat JSON exists but is not indexed](https://github.com/microsoft/vscode/issues/292028): Chat JSON files existed, but the app did not index them.
- AP129. [Conversations lost with only partial global storage left](https://github.com/microsoft/vscode/issues/285535): The reporter lost conversations and found only partial global storage records.
- AP130. [state.vscdb retains chats while UI loses them](https://github.com/microsoft/vscode/issues/307761): Chat records remained in state.vscdb after disappearing from the interface.
- AP131. [VSIX cache remains after extension install](https://github.com/microsoft/vscode/issues/235301): A Mac user found retained VSIX packages consuming scarce disk after installation.
- AP132. [Old VS Code Server versions accumulated 6.55 GB](https://github.com/microsoft/vscode/issues/330519): Old VS Code Server versions accumulated several gigabytes.
- AP133. [Old server versions and extension caches are not cleaned](https://github.com/microsoft/vscode/issues/330505): The reporter found old server versions and extension caches accumulating.
- AP134. [Old extension versions consume gigabytes](https://github.com/microsoft/vscode/issues/206256): The reporter manually removed old extension versions that had accumulated to gigabytes.
- AP135. [Extension Memento storage deleted during upgrade](https://github.com/microsoft/vscode/issues/68468): An extension's Memento state disappeared during an upgrade.
- AP136. [Update erased settings file](https://github.com/microsoft/vscode/issues/125970): An update erased a large settings file, and a backup prevented loss.
- AP137. [Cannot write user-data and extension directories](https://github.com/microsoft/vscode/issues/112846): The issue exposes separate user-data and extension directory boundaries.
- AP138. [Portable mode loses workspace tabs](https://github.com/microsoft/vscode/issues/163928): A portable VS Code setup lost all workspace tabs.
- AP139. [Clean up workspace state for missing workspaces](https://github.com/microsoft/vscode/issues/32461): A maintainer request proposes cleanup for workspace state whose workspace no longer exists.
- AP140. [Disk-full chat export truncated target file](https://github.com/microsoft/vscode/issues/308213): When the disk was full, chat export truncated the target file to zero bytes.
- AP141. [Basic editing and Hot Exit](https://code.visualstudio.com/docs/editing/codebasics): VS Code documents Hot Exit backups under Application Support on macOS.
- AP142. [Extension storage and secrets](https://code.visualstudio.com/api/extension-capabilities/common-capabilities): VS Code exposes workspace, global, file, and secret storage with different lifetimes; secrets are encrypted.
- AP143. [User and workspace settings](https://code.visualstudio.com/docs/configure/settings): VS Code distinguishes user, remote, and workspace settings and documents the macOS user settings path.
- AP144. [Profiles](https://code.visualstudio.com/docs/configure/profiles): VS Code profiles group settings, extensions, snippets, tasks, and UI state; temporary profiles are deleted when closed.
- AP145. [Settings Sync](https://code.visualstudio.com/docs/configure/settings-sync): Settings Sync covers selected settings, UI state, extensions, and profiles, but not all workspace data or secrets.
- AP146. [Local History and Timeline](https://code.visualstudio.com/docs/editing/userinterface): VS Code stores full local file-history contents for recovery.
- AP147. [Portable mode](https://code.visualstudio.com/docs/setup/portable): Portable mode puts session state, preferences, and extensions under the portable data folder.
- AP148. [Command-line data directories](https://code.visualstudio.com/docs/configure/command-line): VS Code can use custom user-data and extensions directories from command-line options.

### JetBrains

- AP149. [Where is Local History stored](https://intellij-support.jetbrains.com/hc/en-us/community/posts/207071225-Where-is-the-local-history): The reporter needed the on-disk Local History location for recovery.
- AP150. [Settings gone after update and plugin mismatch](https://intellij-support.jetbrains.com/hc/en-us/community/posts/4449852761362-Settings-gone-after-update-mismatch-of-plugin): After an update, settings and plugin compatibility state appeared lost.
- AP151. [Local History shows only 12 hours](https://intellij-support.jetbrains.com/hc/en-us/community/posts/207058365-Local-History-only-shows-entrys-from-Last-12-Hours): The reporter expected older Local History but saw only recent entries.
- AP152. [Local History disappeared](https://intellij-support.jetbrains.com/hc/en-us/community/posts/207063895-Local-history): The reporter lost access to expected Local History.
- AP153. [Restore code from Local History or cache](https://intellij-support.jetbrains.com/hc/en-us/community/posts/115000569084-Restore-my-code-from-local-history-or-cache): The reporter sought deleted code in Local History or cache data.
- AP154. [Local History empty and shelf gone](https://intellij-support.jetbrains.com/hc/en-us/community/posts/360007653520-Local-history-is-empty-and-shelf-is-gone): Local History and shelved changes disappeared from the UI.
- AP155. [Database configurations export without passwords](https://intellij-support.jetbrains.com/hc/en-us/community/posts/360007638840-Export-all-databases-configuration): The reporter found database connection settings exported without passwords.
- AP156. [IntelliJ deleted project files](https://intellij-support.jetbrains.com/hc/en-us/community/posts/206877445-Please-help-IntelliJ-11-just-deleted-all-my-files): The reporter used Local History as the hoped-for recovery path after project files disappeared.
- AP157. [Settings lost after upgrade](https://intellij-support.jetbrains.com/hc/en-us/community/posts/115000734890-I-lost-many-of-my-settings-after-upgrade): An upgrade was followed by missing settings, plugins, credentials, and project data-source state.
- AP158. [Local History missing after cache problem](https://intellij-support.jetbrains.com/hc/en-us/community/posts/206228639-Local-History-missing): The reporter lost Local History after cache-related trouble.
- AP159. [Local History](https://www.jetbrains.com/help/idea/local-history.html): JetBrains documents Local History as automatic recovery for edits and deletions with finite retention.
- AP160. [IDE directories for settings, caches, plugins, and logs](https://www.jetbrains.com/help/idea/directories-used-by-the-ide-to-store-settings-caches-plugins-and-logs.html): JetBrains separates Application Support configuration and plugins from Library/Caches system data, which includes Local History.
- AP161. [Invalidate caches](https://www.jetbrains.com/help/idea/invalidate-caches.html): JetBrains offers separate options for caches, Local History, and JCEF browser cookies.
- AP162. [Project settings and .idea](https://www.jetbrains.com/help/idea/project-settings-and-structure.html): JetBrains stores project-specific user and structure settings in the project .idea directory.
- AP163. [IDE and project settings](https://www.jetbrains.com/help/idea/configuring-project-and-ide-settings.html): JetBrains distinguishes IDE-wide and project settings and creates settings backups during resets.
- AP164. [Backup and Sync settings](https://www.jetbrains.com/help/idea/sharing-your-ide-settings.html): JetBrains Backup and Sync covers selected settings and plugins, not every project or local recovery store.
- AP165. [Scratch files](https://www.jetbrains.com/help/idea/scratches.html): Scratch files are user-created files stored under the IDE configuration area rather than the project.
- AP166. [Password Safe](https://www.jetbrains.com/help/idea/reference-ide-settings-password-safe.html): JetBrains can store passwords in macOS Keychain or other configured stores.

### Slack

- AP167. [Troubleshoot connection issues](https://slack.com/help/articles/205138367-Troubleshoot-connection-issues): Slack exposes a Clear Cache and Restart action and can save diagnostic logs to Downloads.
- AP168. [Troubleshoot Slack notifications](https://slack.com/help/articles/360001559367-Troubleshoot-Slack-notifications): Slack troubleshooting distinguishes cache clearing from broader app-data resets that can sign users out.
- AP169. [Update the Slack desktop app](https://slack.com/help/articles/360048367814-Update-the-Slack-desktop-app): Slack's deep update repair can remove the full Application Support tree.
- AP170. [Manage the default download location](https://slack.com/help/articles/4609980592915-Manage-your-default-download-location): Slack lets the user choose a normal file-system download destination.
- AP171. [Manage desktop app configurations](https://slack.com/help/articles/11906214948755-Manage-desktop-app-configurations): Slack documents managed desktop settings, including download paths and configuration keys.

### Discord

- AP172. [Change the default cache directory](https://support.discord.com/hc/en-us/community/posts/1500000476902-Change-default-cache-directory): The reporter wanted to move a growing Discord cache to another disk.
- AP173. [Cache should not be inside config](https://support.discord.com/hc/en-us/community/posts/360030135411-Use-cache-instead-of-config-discord-Cache-on-Linux): The reporter said placing Cache inside the config tree harms backups and migration.
- AP174. [Add a clear-cache option](https://support.discord.com/hc/en-us/community/posts/360032708392-Option-to-clear-the-cache-files): The reporter wanted a cache-only action without reinstalling Discord.
- AP175. [Save message drafts](https://support.discord.com/hc/en-us/community/posts/360056955472-Would-really-like-if-message-drafts-were-saved): The reporter lost long unsent messages and asked for persistent drafts.
- AP176. [Modified unsent message disappears](https://support.discord.com/hc/en-us/community/posts/360051827654-Problem-with-disappearing-modified-unsent-message): An edited but unsent message disappeared when the user switched context.
- AP177. [Discord keeps logging me out](https://support.discord.com/hc/en-us/community/posts/4407504297751-Stop-logging-me-out): A Mac user reported repeated logouts that required password and MFA recovery.
- AP178. [Back up local user settings](https://support.discord.com/hc/en-us/community/posts/6976609542167--User-Data-Backup-settings-to-local-or-online-storage): The reporter said reinstalling Discord lost app preferences and requested backup or export.
- AP179. [Profile notes disappear](https://support.discord.com/hc/en-us/community/posts/1500000796921-Randomly-losing-profile-notes-for-no-reason): The reporter lost profile notes and other local personalization state.
- AP180. [Discord troubleshooting guide](https://support.discord.com/hc/en-us/articles/31623498041623-Discord-Troubleshooting-Guide): Discord identifies ~/Library/Application Support/discord/Cache as the Mac cache and separately warns users to back up settings before broader Application Support removal.
- AP181. [Your Discord Data Package](https://support.discord.com/hc/en-us/articles/360004957991-Your-Discord-Data-Package): Discord's account export includes messages, settings, sessions, notes, and other server-held data.
- AP182. [Recover an account locked by MFA](https://support.discord.com/hc/en-us/articles/115001221072-How-to-Recover-Your-Discord-Account-When-Locked-Out-of-Multi-Factor-Authentication-MFA): Discord says saved backup codes can be essential and support cannot replace them.
- AP183. [macOS install and updating errors](https://support.discord.com/hc/en-us/articles/360022082931--macOS-Install-and-Updating-Errors): Discord's macOS repair guide removes the full Application Support directory after closing all Discord processes.

## Observed patterns

1. A folder name does not establish value. JetBrains keeps Local History under its system or cache area. Chromium extensions keep durable state outside ordinary browsing-data controls. A safe classifier needs owner semantics, not name matching.
2. A profile is a graph, not one directory. It can depend on profile files, session backups, Keychain items, encryption metadata, extension stores, download destinations, workspace roots, and cloud identity.
3. Session state is a recovery class. Tabs, windows, tab groups, pinned tabs, Zen spaces, SafariTabs.db, Hot Exit backups, and chat indexes can be the only copy of active work.
4. Interface visibility and disk existence can diverge. VS Code chat files and databases can remain after an index or workspace hash stops exposing them. Browsers can open a new profile while an older profile remains on disk.
5. Credential recovery uses dependency groups. Firefox needs matching login and key files. Chromium-based browsers can depend on password databases, Local State, and macOS Keychain. JetBrains connection settings can depend on Password Safe or Keychain.
6. Clear cache, clear site data, reset settings, remove a profile, invalidate IDE caches, and reinstall an app are different actions. Tessera must not collapse them into one cleanup label.
7. Offline content can be intentional. Safari Reading List, persistent website storage, service worker Cache Storage, and extension local storage can hold data the user expects to work without a network.
8. Extension packages and extension state have different value. A package may be downloadable again. Its settings, local databases, global state, workspace state, and secrets may be unique.
9. Download records and downloaded files are different objects. Clearing a browser's download list does not remove the file. Removing the file does not necessarily remove its record.
10. Drafts, scratches, Local History, untitled documents, notes, and local assistant chats are authored data even when stored inside Application Support, a database, or a directory named cache.
11. Sync is not a backup. It can omit local data, propagate deletion, expire server copies, or restore only selected settings.
12. App closure is a safety boundary. Session races, live SQLite writes, and post-delete recreation make cleanup unsafe while the owner app is open.
13. Disk-full repair needs free working space. A write or export can truncate the last copy when the disk has no room.

## Counterexamples to simple cleanup rules

- "Everything in Library/Caches is safe": JetBrains Local History can live under the IDE system directory in Library/Caches and can recover deleted code.
- "A large database is cache": SafariTabs.db can be very large but represents session and tab-group state. VS Code state.vscdb can contain workspace and chat state even when SQLite free pages inflate it.
- "Temp means disposable": A Brave report says a broad Temp cleanup reset user data. Generic sweeps can cross owner boundaries.
- "The app cannot see it, so it is stale": VS Code transcripts can remain on disk after an index or workspace identity failure.
- "The profile was copied, so passwords are safe": Firefox and Chromium credential stores can fail without matching encryption state.
- "Sync makes local data replaceable": Brave states that Sync is not a backup. VS Code and JetBrains Sync omit some local workspace, recovery, or secret state.
- "Reinstall cleanup is a normal cache action": Slack and Discord support flows can remove full Application Support directories. Those are high-risk repair recipes.
- "Offline web data is cache": Reading List and service worker storage can be intentional saved content.
- "Old means unused": Older profiles and session generations often become the recovery source after updates or profile-picker failures.

## Tessera product implications

### Required classification

| Class | Examples | Default action |
|---|---|---|
| `cache_rebuildable` | Owner-declared image, code, renderer, or network cache with no recovery-bearing child | Safe candidate only when the app is closed |
| `profile_core` | Preferences, bookmarks, history, cookies, site databases, profile registry | Protect; offer owner-specific review |
| `session_recovery` | Tabs, windows, tab groups, Zen spaces, Hot Exit, session backups | Protect by default |
| `user_authored_app_data` | Drafts, scratches, Local History, notes, local chats, untitled files | Protect by default |
| `extension_binary` | Installed extension package or old package version | Review after active-version check |
| `extension_state` | Extension local, global, workspace, sync, and secret stores | Protect by default |
| `credential_ciphertext` | Password or token databases | Protect as a dependency group |
| `credential_key` | macOS Keychain items, key4.db, Local State encryption metadata | Protect as a dependency group |
| `offline_content` | Reading List downloads, persistent site data, service worker storage | Review with owner and site name |
| `download_record` | Browser or app download history | Explain low disk effect |
| `download_file` | Files in Downloads or a user-selected folder | Protect; show exact path |
| `workspace_state` | Editor layout, project associations, .idea data, remote session state | Protect by default |
| `owner_reset_bundle` | Full Application Support removal used in a support repair | High-risk action with separate confirmation |
| `ephemeral_runtime` | In-memory extension session data and temporary runtime state | No disk cleanup action |

### Required dependency groups

- Firefox credentials: `logins.json` plus `key4.db`, with profile identity.
- Chromium credentials: password database plus `Local State` encryption metadata plus macOS Keychain access.
- Zen recovery: active profile plus `zen-sessions.jsonlz4`, `sessionstore-backups`, and `zen-sessions-backup`.
- VS Code recovery: backup or transcript content plus workspace identity, indexes, `state.vscdb`, and configured user-data path.
- JetBrains database access: project or IDE connection configuration plus Password Safe or macOS Keychain.
- Safari recovery: Safari profile and session databases plus shared Passwords or Keychain state.
- Extensions: installed package plus owner-specific global, local, workspace, sync, and secret stores.

### Required scan behavior

1. Resolve the actual running app, version, channel, profile, portable path, command-line overrides, and managed configuration.
2. Require the app to be fully closed. Check open file handles before a mutation.
3. Inventory stores as separate rows. Do not show one profile-size number as one deletion unit.
4. Mark dependency groups and block partial deletion of credentials, encryption state, active sessions, or indexed content.
5. Compare detached and old profiles by content, last meaningful use, profile registry, and recovery files. Age alone is not enough.
6. Detect recovery signals: unclean shutdown, recent update, new profile, missing UI index, disk-full event, corrupt database, or active restore prompt.
7. Prefer owner actions such as Clear Cache, Invalidate Caches, Remove Profile, or Reset Settings when their effect is documented.
8. Show outcome text before confirmation, including sign-outs, offline loss, extension reset, session loss, and whether disk space will actually be freed.
9. Use recoverable staging for review actions. Keep a manifest that can put an exact dependency group back.
10. Re-scan after the action and verify both freed space and owner-app health.

### Required user interface labels

Use labels that name data and effect:

- "Cached web files. Sites can download these again."
- "Website data. This can sign you out and remove offline content."
- "Open tabs and session recovery. Keep."
- "Old browser profile. Contains bookmarks, passwords, or extensions. Review."
- "Extension package. Can usually be installed again."
- "Extension settings and local data. Keep."
- "Saved passwords and encryption keys. Keep together."
- "Downloaded files. These are your files."
- "Download history only. Removing it frees little space."
- "Drafts, Local History, and unsaved work. Keep."
- "App repair reset. This removes the full local profile."

## Exact de-duplication proof

- Initial pre-write corpus inputs selected by the required command: 12 JSONL files.
- Initial pre-write URL values read with `jq`: 2,683.
- Initial pre-write unique URLs: 2,683.
- Final pre-existing corpus inputs after concurrent lane updates: 14 JSONL files.
- Final pre-existing URL values read with `jq`: 3,063.
- Final unique pre-existing URLs: 3,063.
- Duplicate URLs in the final pre-existing corpus: 0.
- Candidate records before acceptance: 183.
- Candidate canonical URL count: 183.
- Candidate internal duplicate URLs: 0.
- Candidate URLs containing a query, fragment, or trailing slash: 0.
- Exact URL overlap with the pre-existing corpus: 0.
- Search result pages accepted: 0.
- Fragment or tracking-parameter variants accepted: 0.

The initial overlap test compared each candidate URL against every `.url` value from all 12 files selected before this lane ledger existed. The final test excluded this lane ledger, read every `.url` from all 14 other files then selected by `rg --files docs/research | rg '(ledger|market-scan)\.jsonl$'`, and again found zero overlap.

## Files and validation

- `docs/research/tessera-disk-rescue-app-profile-agent-lane-2026-08-31.md`
- `docs/research/tessera-disk-rescue-app-profile-ledger.jsonl`
- Validation result: `jq -e` passed all 183 JSONL lines. The ledger has 183 unique URLs, 0 duplicate URLs, and 0 exact URL overlaps with the pre-existing corpus. A direct link check returned 156 HTTP 200 responses, 27 HTTP 403 responses from sites that block automated requests, and 0 HTTP 404, 410, or unreachable responses.
