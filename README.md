# Storage Optimizer

A fast, private, native macOS disk visualizer and cleaner. Scan any disk, cloud
folder, or network share; see exactly what's using space in an interactive Liquid
Glass sunburst; and reclaim it safely — with on-device AI, duplicate detection, an
app uninstaller, and hidden-space tools. **Everything runs on-device. No user data
ever leaves your Mac.**

## Features

- **Visual scan** — a parallel `getattrlistbulk` engine renders a live sunburst of
  your disk; multi-disk/cloud/network sources with an in-memory scan cache for
  instant switching.
- **Cleanup suggestions** — rule-based detection of caches, dev junk (DerivedData,
  node_modules, package caches), Adobe media cache, logs, installers, and more.
- **Ask to Clean Up** — natural-language cleanup ("free up 20 GB", "dev junk but
  keep my projects"), matched on-device.
- **Duplicate finder** — exact-content duplicates via a fast bounded fingerprint.
- **Large & Old Files** — filter by size, age, and kind.
- **By Kind lens** — see space grouped by Video / Photo / App / Archive / Code / …
- **Search** — natural-language file search across the scan.
- **App Uninstaller** — remove an app *and* its leftovers (Caches, Application
  Support, Preferences, Containers, LaunchAgents…), conservatively matched.
- **Leftover finder** — support files left behind by apps you already deleted.
- **Hidden Space** — read and clear purgeable caches, APFS local snapshots, and
  Full-Disk-Access–gated files.
- **On-device AI** — an optional, downloadable local model (MLX) powers the smart
  features. No model is bundled and nothing is sent to a server.
- **Safe by default** — staged items are reviewed in the collector; deletion
  defaults to **Move to Trash** (recoverable), with Delete Permanently as an
  explicit, confirmed option.

## Privacy

The app makes **no network calls related to your files**. The only outbound traffic
is (1) the optional, user-initiated on-device model download and (2) Sparkle
auto-update checks, plus any network shares *you* choose to mount and scan. There is
no telemetry, analytics, or cloud processing.

## Requirements

- macOS 26 or later, Apple Silicon (the on-device model uses MLX/Metal).
- Full Disk Access (granted in System Settings) to scan protected locations.

## Building

```sh
xcodebuild -project StorageOptimizer.xcodeproj -scheme StorageOptimizer -configuration Debug build
xcodebuild -project StorageOptimizer.xcodeproj -scheme StorageOptimizer -configuration Debug test
```

First build only: if you hit `missing Metal Toolchain`, run
`xcodebuild -downloadComponent MetalToolchain` (MLX compiles Metal shaders).

## Distribution

Distributed directly (not the Mac App Store — full-disk scanning and `tmutil` use
are incompatible with the App Sandbox), Developer ID–signed and notarized, with
Sparkle for over-the-air updates. See [RELEASING.md](RELEASING.md).
