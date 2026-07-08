# Tessera

A fast, private, native macOS disk visualizer and cleaner. Scan any disk, cloud
folder, or network share; see exactly what's using space in an interactive Liquid
Glass sunburst; and reclaim it safely — with duplicate detection, an app
uninstaller, dev-junk cleanup, and hidden-space tools. **Everything runs
on-device. No user data ever leaves your Mac.**

**Free and open source** under the [GPL-3.0](LICENSE).

![macOS](https://img.shields.io/badge/macOS-26%2B-000?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-000)
![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue)

## Features

- **Visual scan** — a parallel `getattrlistbulk` engine renders a live sunburst of
  your disk; multi-disk/cloud/network sources with an in-memory scan cache for
  instant switching.
- **Cleanup suggestions** — rule-based detection of caches, dev junk (DerivedData,
  node_modules, package caches), Adobe media cache, logs, installers, and more.
  Everything is staged for you to review; nothing is deleted automatically.
- **Duplicate finder** — content-verified duplicates via a fast bounded fingerprint.
- **Large & Old Files** — filter by size, age, and kind.
- **By Kind lens** — see space grouped by Video / Photo / App / Archive / Code / …
- **File search** — filter files across the scan by name, size, age, and kind.
- **App Uninstaller** — remove an app *and* its leftovers (Caches, Application
  Support, Preferences, Containers, LaunchAgents…), conservatively matched.
- **Leftover finder** — support files left behind by apps you already deleted.
- **Hidden Space** — read and clear purgeable caches, APFS local snapshots, and
  Full-Disk-Access–gated files.
- **Safe by default** — staged items are reviewed in the collector; deletion
  defaults to **Move to Trash** (recoverable), with Delete Permanently as an
  explicit, confirmed option.

## Privacy

Tessera makes **no network calls related to your files**. The only outbound
traffic is Sparkle auto-update checks, plus any network shares *you* choose to
mount and scan. There is no account, no telemetry, no analytics, and no cloud
processing — and because the source is open, you can verify all of that yourself.

## Requirements

- macOS 26 (Tahoe) or later, Apple Silicon.
- Full Disk Access (granted in System Settings) to scan protected locations.

## Install

Download the latest `Tessera.dmg` from
[Releases](https://github.com/unknown6003/tessera-releases/releases/latest),
drag Tessera to Applications, then right-click it and choose **Open** the first
time (the current build is unsigned; you only approve it once).

## Building from source

```sh
# The Xcode project is generated from project.yml via XcodeGen.
xcodegen generate

xcodebuild -project Tessera.xcodeproj -scheme Tessera -configuration Debug build
xcodebuild -project Tessera.xcodeproj -scheme Tessera -configuration Debug test
```

To produce a distributable unsigned `.dmg`:

```sh
./release-unsigned.sh   # → dist/updates/Tessera-<version>.dmg
```

## Distribution

Distributed directly (not the Mac App Store — full-disk scanning and `tmutil` use
are incompatible with the App Sandbox) as a `.dmg`, with Sparkle for over-the-air
updates. Builds and the Sparkle appcast are published on the public
[`tessera-releases`](https://github.com/unknown6003/tessera-releases) repo so they
are anonymously downloadable. See [RELEASING.md](RELEASING.md).

Windows and Linux builds are planned; the packaging plan lives in
[DISTRIBUTION.md](DISTRIBUTION.md).

## Contributing

Issues and pull requests are welcome. By contributing you agree that your
contributions are licensed under the GPL-3.0.

## License

[GNU General Public License v3.0](LICENSE) © 2026 Tessera contributors.
