# Tessera — Distribution & Packaging Plan

How Tessera is delivered per platform. macOS is shipping today; **Windows and Linux
are future work** and are tracked here so the groundwork (naming, versioning,
download URLs, package-manager channels) is settled before the port begins.

Single source of truth for every channel:
- **Product name:** `Tessera`
- **Version:** `CFBundleShortVersionString` in `Tessera/Info.plist` (macOS). Other
  platforms mirror the same semantic version so a `1.2.0` build is `1.2.0` everywhere.
- **Release host:** GitHub Releases on `unknown6003/tessera`. Every artifact is a
  release asset; download URLs are stable at
  `github.com/unknown6003/tessera/releases/latest/download/<file>`.

---

## macOS — shipping now ✅

- **Format:** signed + notarized `.dmg` (drag-to-Applications). See
  [RELEASING.md](RELEASING.md).
- **Updates:** Sparkle OTA, appcast served from the latest GitHub Release.
- **Package-manager channel (planned):** a **Homebrew cask** so users can
  `brew install --cask tessera`. The cask formula points at the notarized `.dmg`
  release asset and is bumped per release (can be automated in `release.sh`). This
  is additive to the direct `.dmg` download — no code changes required.

## Windows — future ⏳

- **Format:** an installer — **MSIX** (preferred; clean install/uninstall, ties into
  the Store/winget signing model) or a WiX/MSI as a fallback. Authenticode-signed
  with a Windows code-signing certificate (separate from the Apple Developer ID).
- **Package-manager channels:**
  - **winget** (primary): submit a manifest to `microsoft/winget-pkgs` →
    `winget install Tessera`.
  - **Scoop** / **Chocolatey** (secondary community channels).
- **Updates:** winget handles upgrades; for the direct installer, either an in-app
  updater (WinSparkle mirrors the Sparkle appcast) or MSIX auto-update.

## Linux — future ⏳

Ship through the native package managers rather than a raw tarball:
- **Flatpak** on **Flathub** (primary, distro-agnostic): `flatpak install tessera`.
- **AUR** (Arch): a `tessera-bin` PKGBUILD.
- **.deb** (Debian/Ubuntu, via an apt repo/PPA): `apt install tessera`.
- **.rpm** (Fedora/RHEL, via Copr or a dnf repo): `dnf install tessera`.
- **Snap** (optional): `snap install tessera`.
- **Updates:** handled by each package manager.

---

## Porting reality (what a Windows/Linux build actually requires)

Tessera is currently a native macOS app; these subsystems are macOS-specific and
must be re-implemented (or abstracted behind a platform interface) before a port:

| Subsystem | macOS today | Port needs |
|---|---|---|
| Scan engine | `getattrlistbulk` bulk directory reads, APFS device/firmlink handling | `readdirplus`/`io_uring`/`statx` on Linux; `NtQueryDirectoryFile` / MFT on Windows |
| On-device AI | Apple `FoundationModels` + MLX/Metal | llama.cpp / ONNX Runtime with CPU/GPU backends |
| UI | SwiftUI + "Liquid Glass" | a cross-platform UI (e.g. a shared Rust/C++ core with a native or web-tech shell) |
| Updates | Sparkle | WinSparkle (Windows) / package manager (Linux) |
| Signing | Apple Developer ID + notarization | Authenticode (Windows) / Flatpak & distro signing (Linux) |

**Recommended strategy when the port starts:** extract the platform-agnostic logic
(scan model, sizing/rollup, cleanup classification, dedupe) into a shared core with a
thin per-OS filesystem + AI + UI layer, so the three platforms share one engine and
one version number. Until then, this file is the contract the landing page and
release tooling build against.
