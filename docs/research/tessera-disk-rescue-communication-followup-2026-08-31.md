# Tessera communication and offline-state follow-up

Status: bounded evidence expansion plus a local aggregate probe. The GitHub lane is a discovery screen, not a prevalence study.

Date: 2026-08-31

## Collection

The GitHub lane contains 67 new URLs from the latest 100 issue records returned for:

- [Telegram Desktop](https://github.com/telegramdesktop/tdesktop/issues)
- [Jitsi Meet Electron](https://github.com/jitsi/jitsi-meet-electron/issues)

The records are in [tessera-disk-rescue-communication-followup-ledger.jsonl](./tessera-disk-rescue-communication-followup-ledger.jsonl). The first-person heuristic marked 31 as `core` and 36 as `adjacent`. The lane is noisy because a communication app's issue template repeats words such as message, profile, or local even when the issue is only about interface behavior. Every record is marked `screening_status: automated_candidate`; it must be manually coded before it changes a safety rule.

## Local read-only probe

The probe did not read message, mail, note, or attachment content. It measured directory allocation only and recorded whether the owner app was running. A repeated bounded read changed the Messages allocation by 18,560 bytes and the Discord allocation by 6,912 bytes in the opposite direction while the apps were active. That small change is useful evidence of scan expiry, not a claim about the size of future growth.

| Area | Allocated bytes | Approximate display | Important child signal |
| --- | ---: | ---: | --- |
| `~/Library/Messages` | 10,565,980,160 | 9.9 GB | Attachments about 8.1 GB; caches about 1.4 GB; sync about 133 MB; chat database about 298 MB logical and 312 MB allocated |
| `~/Library/Application Support/discord` | 1,036,327,680 | 989 MB | Cache about 741 MB; app payload about 201 MB; logs about 24 MB |
| `~/Library/Mail` | 5,976,064 | 5.7 MB | Small in this probe |
| `~/Library/Group Containers/group.com.apple.notes` | 11,354,112 | 10.8 MB | Small in this probe |

Messages, Discord, and WhatsApp processes were running during the probe. The exact method and limits are in [tessera-disk-rescue-communication-local-probe-2026-08-31.md](./tessera-disk-rescue-communication-local-probe-2026-08-31.md). No action was taken.

## Patterns to carry into Tessera

### 1. Attachments are not the conversation database

The local probe shows a large split between Messages attachments and the smaller chat database. Signal reports also separate chat-history export, linked-device transfer, and database or backup state: [Signal export failure](https://github.com/signalapp/Signal-Desktop/issues/7887), [Signal linked-device transfer](https://github.com/signalapp/Signal-Desktop/issues/7998), and [Signal backup authentication](https://github.com/signalapp/Signal-Desktop/issues/7941).

Tessera implication: an attachment directory may be reviewable only with owner context. The message database, encryption state, drafts, and export path stay protected. Never turn the parent communication folder into a cache candidate.

### 2. Active communication apps are live writers

Messages and Discord were running while the read-only size probe ran. Incoming messages, indexing, compaction, upload, and sync can change the result during review. A deletion that looks like attachment cleanup can race with an owner write or leave the app unable to index its local history.

Tessera implication: capture owner process and helper state, revalidate the identity and size before staging, and hard-hold a live owner unless the owner exposes a safe coordinated action. A tray app or background helper can remain active even when no main window is visible.

### 3. Offline and remote state are different promises

Communication users may need old media while offline, may have pending sync, or may treat a local export as their only recovery copy. A remote account does not prove that a local attachment or database can be recreated with the same history, ordering, or encryption state.

Tessera implication: show account owner, local or remote status, sync completion, offline need, export or backup identity, and remote-delete meaning. Prefer the owner app's storage or export controls. Generic Trash is not the first action for a communication database.

### 4. The source of truth may be the app, not the path

Telegram issue reports include media, rich messages, attachment, and delete behavior, while Jitsi reports include recent rooms and user data. The path does not explain retention, server state, or the effect of a local reset. The owner app must define what a local file means.

Tessera implication: add a communication role such as `attachment`, `cache`, `message_store`, `draft`, `export`, `session`, `credential`, or `unknown`; add `syncStatus`, `remoteAuthority`, `retentionState`, `ownerResetEffect`, and `activeWriter`. Unknown stays review-only or protected.

## Implementation boundary

Start with read-only inventory and an owner handoff. Do not add a broad Messages, Mail, Discord, Telegram, or WhatsApp deletion rule from the local size numbers. A future attachment action must prove the exact owner scope, app state, local and remote semantics, and post-action owner health. Preserve a local report without filenames or message content.

## Limits and next pass

The local probe is one machine snapshot, not a user sample. The GitHub records include many unrelated UI issues. The next pass should manually inspect owner documentation and direct user reports for Messages, Signal, Telegram, Discord, Mail, Notes, and Photos; add provider and encryption states; and test a closed-app or owner-coordinated dry run in a disposable fixture. No personal content should enter the corpus.
