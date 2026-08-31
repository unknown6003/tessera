# Communication storage local probe

Date: 2026-08-31

Scope: read-only inspection of known macOS communication-app roots on the current machine. No file contents were read. No file was moved, deleted, or changed.

## Method

The probe used bounded, same-volume allocation scans on explicit paths:

```text
gdu -x -s -B1 <known app root>
gdu -x -h -d 1 <known app root>
stat -f %z and stat -f %b <known database path>
ps -axo pid=,comm=
```

The output records folder roles and aggregate bytes only. It does not record message text, account names, contacts, attachment names, or other personal content.

## Aggregate result

| Root | Allocated bytes | Current owner state |
| --- | ---: | --- |
| `~/Library/Messages` | 10,565,980,160 | Messages was running |
| `~/Library/Application Support/discord` | 1,036,320,768 | Discord was running |
| `~/Library/Mail` | 5,976,064 | Mail daemon was running |
| Apple Notes group container | 11,354,112 | Not inspected below the root |

WhatsApp was also running. This pass did not measure its container because the active bundle and group-container roots need owner lookup first.

## Storage roles found

The Messages root held several different roles:

| Role | Allocated size |
| --- | ---: |
| Attachments | 8.1 GiB |
| Owner-managed caches | 1.4 GiB |
| Sync state | 133 MiB |
| Message database | 312,250,368 allocated bytes |
| Drafts and small metadata caches | Less than 25 MiB combined in this view |

The Discord root also mixed roles:

| Role | Allocated size |
| --- | ---: |
| HTTP or media cache | 741 MiB |
| Installed application payload | 201 MiB |
| Logs | 24 MiB |
| Code cache | 11 MiB |
| Local Storage | 8.6 MiB |
| Session, service worker, GPU, crash, and other state | Less than 5 MiB combined in this view |

## What this proves

1. A communication-app root is not one cleanup object. The largest Messages items were attachments, a cache tree, sync state, and a live database with different recovery paths.
2. A large cache can sit beside local storage, session state, drafts, and installed payload. A parent-folder rule would cross those boundaries.
3. Owner state matters before reclaim. Messages, Discord, and WhatsApp were running during the probe. A path-only classifier cannot prove that a cache has no active writer.
4. An attachment is not a cache because it is old, large, or downloaded. Tessera needs account, message, local-copy, remote-copy, sync, retention, and owner-action evidence.
5. Logical file size and allocated bytes differ. The live Messages database had a 295,858,176-byte logical size and 312,250,368 allocated bytes at the time of the probe.

A second bounded read during the same research turn measured the live roots slightly differently: Messages changed by 18,560 allocated bytes and Discord by 6,912 bytes in the opposite direction. The difference is small, but it is direct evidence that a scan snapshot can age while an owner app is running. Tessera should treat a change event as a rescan trigger, not as proof that the whole root is unsafe.

## Tessera implications

- Keep the whole Messages, Mail, Notes, Discord, Slack, Teams, Outlook, WhatsApp, Telegram, and Signal roots protected.
- Add owner adapters before any communication cleanup rule.
- Classify attachment, cache, draft, database, index, token, encryption key, downloaded offline copy, sync metadata, application payload, and log as separate roles.
- Check the owner process and open handles immediately before any owner action.
- Prefer owner settings for retention, downloaded-copy removal, cache reset, sign-out, or account repair. State the remote effect and whether the action bypasses Trash.
- Treat an owner-declared cache as reviewable only after Tessera proves the exact subpath, current owner state, sync state, recovery source, and expected side effect.

## Current source risk

`Tessera/Engine/CleanupSuggestions.swift` labels `node_modules`, package-manager caches, browser caches, and the top-level `Library/Caches` tree as `safeRegenerable` from path rules. The classifier is intentionally pure and does not inspect a running owner, open handle, sync state, or recovery source. The rescue flow must add those gates before it uses the confidence label to preselect an item.

Do not add a Messages or communication-app path rule from this probe. The probe shows why an owner and state model is required first.
