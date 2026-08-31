# Tessera app-profile follow-up

Status: bounded evidence expansion. This lane is a title and body screen of public issue trackers, not a prevalence study.

Date: 2026-08-31

## Collection

The lane contains 95 new URLs from the latest 100 issue records returned for each of:

- [Signal Desktop](https://github.com/signalapp/Signal-Desktop/issues)
- [Element Desktop](https://github.com/element-hq/element-desktop/issues)
- [Mattermost Desktop](https://github.com/mattermost/desktop/issues)

The records are in [tessera-disk-rescue-profile-followup-ledger.jsonl](./tessera-disk-rescue-profile-followup-ledger.jsonl). The first-person heuristic marked 90 as `core` and 5 as `adjacent`. These are automated candidate labels. This lane is noisy: Signal's latest issues include tray, rendering, and platform reports that do not describe storage. A title and body screen is therefore a discovery index, not manual ethnography.

The records carry `screening_status: automated_candidate`. Pull requests were excluded, and existing URLs were excluded before writing.

## Patterns to carry into Tessera

### 1. An app profile contains durable identity and recovery state

Signal reports failed or repeated chat-history export and linked-device transfer: [Signal chat-history export](https://github.com/signalapp/Signal-Desktop/issues/7887) and [Signal linked-device transfer](https://github.com/signalapp/Signal-Desktop/issues/7998). These are not cache problems. They show that local databases and attachments can be part of the user's recovery path.

Tessera implication: keep profile roots protected. Classify exact subpaths into cache, database, attachment, draft, session, extension, history, and credential or encryption state. Show the owner action and recovery effect before any candidate is staged.

### 2. Encryption and session state are paired dependencies

Element reports a safe-storage backend change that cannot migrate: [Element safe-storage migration](https://github.com/element-hq/element-desktop/issues/2822). Signal reports invalid session state after a cloned installation and desktop-backup authentication failure: [Signal cloned-installation session state](https://github.com/signalapp/Signal-Desktop/issues/7989) and [Signal desktop backup authentication](https://github.com/signalapp/Signal-Desktop/issues/7941).

Tessera implication: never treat an account database, key store, session file, or credential cache as disposable because its parent app is old or large. Record credential pairing, encryption backend, session recovery state, and whether the owner app is open.

### 3. Offline copies and attachments have a separate recovery role

Messaging clients can hold local media, message history, exports, thumbnails, and offline indexes. The user may accept loss of a redownloadable attachment but not the conversation index or an unsent draft. A generic `Cache` label cannot establish that boundary.

Tessera implication: show local versus remote state, attachment count or size when the owner exposes it, offline consequence, export or backup path, and owner-specific reset effect. Prefer an owner handoff or app-level cleanup command.

### 4. App lifecycle changes the scan result

A profile can change during the scan through sync, downloads, message receipt, attachment indexing, or compaction. The same directory can be safe to inspect while the app is open and unsafe to change while it has a writer or key store open.

Tessera implication: detect the owning app and helper processes, record the scan identity, revalidate immediately before action, and hard-hold active owner state. A generic process-name check is not enough for background or tray applications.

## Implementation boundary

Add exact subpath rules only when the owner defines the role. Return profile role, credential and encryption dependency, session recovery state, offline site or message data, extension state, drafts, local history, workspace database, current process handles, and owner reset effect. Keep profile cleanup out of `safeRegenerable`. Require the owner app to be closed or use a supported coordinated action.

## Limits and next pass

This lane is especially vulnerable to keyword noise and cross-platform differences. The next pass should manually code only storage, profile, export, backup, database, attachment, session, credential, and offline records. Add owner documentation for Signal, Element, Telegram, Discord, Slack, Mail, Messages, and Photos, and test exact macOS paths without reading personal content. Do not infer prevalence from 95 issue records.
