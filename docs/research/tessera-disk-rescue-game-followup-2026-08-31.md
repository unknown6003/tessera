# Tessera game-library follow-up

Status: bounded evidence expansion. This lane is a title and body screen of public issue trackers, not a prevalence study.

Date: 2026-08-31

## Collection

The lane contains 178 new URLs from the latest 100 issue records returned for each of:

- [Lutris](https://github.com/lutris/lutris/issues)
- [Proton](https://github.com/ValveSoftware/Proton/issues)
- [Prism Launcher](https://github.com/PrismLauncher/PrismLauncher/issues)

The records are in [tessera-disk-rescue-game-followup-ledger.jsonl](./tessera-disk-rescue-game-followup-ledger.jsonl). The first-person heuristic marked 149 as `core` and 29 as `adjacent`. These labels are automated candidate labels. They have not been manually read one by one, and many issues are about compatibility rather than storage.

The query looked for storage, cache, path, move, library, download, install, save, mod, prefix, external-volume, folder, directory, and related words. Pull requests were excluded. Existing URLs were excluded before writing. The records carry `screening_status: automated_candidate` so a later coding pass can downgrade noise without losing the raw discovery.

## Patterns to carry into Tessera

### 1. A launcher library is registered state, not only a folder

Issue reports describe launchers losing a path, opening the wrong `game_paths.json`, or failing to recognize an existing instance after a move or reset. A payload that exists on disk can still be unavailable to its owner. See [Lutris game path handling](https://github.com/lutris/lutris/issues/6822) and [Prism instance upgrade data loss](https://github.com/PrismLauncher/PrismLauncher/issues/5969).

Tessera implication: represent launcher identity, install path, manifest or instance metadata, volume identity, and owner recognition as separate fields. A missing external volume is unavailable, not orphaned.

### 2. A compatibility container can hold the user's state

Proton prefixes and Prism instances can hold settings, saves, mods, and other state beside the redownloadable game payload. A proposal to deduplicate prefixes also shows that apparent folder size can be shared or repeated physical state: [Proton prefix deduplication request](https://github.com/ValveSoftware/Proton/issues/4093). A shared installation path can also create cross-user or cross-game effects: [Proton shared installation path](https://github.com/ValveSoftware/Proton/issues/4820).

Tessera implication: never classify a prefix, instance, bottle, or compatibility directory by name alone. Show payload, personal state, compatibility state, shared references, and the owner action separately.

### 3. Transfer and update state changes the safe action

Lutris and Prism reports include broken or incomplete runner, modpack, and game downloads. A progress bar request is also a request for the user to know whether a large transfer is still active: [Lutris runner update progress](https://github.com/lutris/lutris/issues/6860) and [Prism incomplete modpack update](https://github.com/PrismLauncher/PrismLauncher/issues/2678).

Tessera implication: expose active transfer, partial, stale-partial, and verified-complete states. Keep staging and patch workspace out of safe cleanup. Include the extra space needed for an update or repair.

### 4. Mod and firmware-like content is personal or required state

The lane includes reports about mods, BIOS folders, and custom paths. A large BIOS or mod directory may be required by several instances and may not be replaceable from the main game download: [Lutris BIOS folder report](https://github.com/lutris/lutris/issues/6783) and [Prism user-defined mod folders](https://github.com/PrismLauncher/PrismLauncher/issues/154).

Tessera implication: show required-by and used-by relationships. Do not preselect mods, saves, worlds, screenshots, BIOS, or compatibility data. Offer the launcher's own remove, verify, or move action when available.

## Implementation boundary

The game adapter should be read-only first. It should return launcher and game identity, payload paths, save and mod paths, cloud state, registration state, patch workspace, compatibility-container state, external-volume identity, active processes, and supported owner actions. A removal or relocation plan must pass an owner recognition check, a launcher restart check, a representative launch, and a save or mod check before the old bytes become reviewable.

## Limits and next pass

The repositories are mostly Linux or cross-platform projects. They are useful for state and failure patterns, but they do not prove Mac behavior or user frequency. The next pass should manually code the storage-relevant subset, add Steam, Epic, GOG, and Mac launcher reports, and inspect owner documentation for current macOS path and cloud-save rules. Do not convert the automated 178-record count into a demand estimate.
