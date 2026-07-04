# Releasing Tessera

The app ships **directly** (not the Mac App Store): Developer ID–signed, notarized,
packaged as a **.dmg**, and auto-updated via **Sparkle**. This is the full runbook.
You need an Apple Developer account (for the Developer ID certificate + notarization)
and a one-time Sparkle signing key.

> The app is hard-coded to be on-device only. The only network it performs is the
> optional model download and Sparkle update checks — keep it that way.

## 0. One-time setup

### Sparkle EdDSA signing key — ✅ DONE
Already generated. The **private** key is in this Mac's login Keychain and the
**public** key is in `Tessera/Info.plist` (`SUPublicEDKey`). Don't commit or export
the private key. To re-print the public key:
`<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -p`.
⚠️ Back up the private key (Keychain item "ed25519" / account
`https://sparkle-project.org`) — if it's lost you can't sign updates that existing
installs will accept.

### Apple Developer ID — ⛔ STILL NEEDED (enroll personal account first)
`security find-identity -v -p codesigning` currently shows **0 identities**. Being
signed into your Apple account in Xcode is not enough.

**Decision (2026-06-19):** ship under your **personal** name, not a company. The
Apple ID `unknown6003@gmail.com` currently has access to two teams:
- `W6X7YJF8ZQ` — *Ammar Badawy (Personal Team)* — **free**; cannot notarize or make
  Developer ID certs.
- `YYN7R25WT5` — *AL BURSA E TICARET ANONIM SIRKETI* — paid Company team (declined,
  to avoid publishing under the company's name).

Notarized direct distribution requires a **paid** membership, so the personal Apple
ID must be enrolled in the Apple Developer Program first.

1. **Enroll** the personal Apple ID as an *Individual* at
   <https://developer.apple.com/account> → Enroll ($99/yr; approval can take 1–2
   days). Accept the Program License Agreement.
2. **Find your new personal Team ID:** developer.apple.com/account → Membership
   details (an Individual enrollment shows a personal Team ID, e.g. `ABCDE12345`).
3. **Create the cert** (one time): Xcode → Settings → Accounts → (your now-paid
   personal team) → Manage Certificates → + → **Developer ID Application**.
4. **Create the notarytool credential profile** (stores the app-specific password in
   the Keychain only — never in a file):
   ```sh
   xcrun notarytool store-credentials "TESSERA_NOTARY" \
     --apple-id "unknown6003@gmail.com" --team-id "<YOUR-PERSONAL-TEAM-ID>" \
     --password "<app-specific-password>"
   ```
   > Verified the app-specific password authenticates; the only thing missing is a
   > paid membership on a team you want to publish under. With the free personal team
   > this returns HTTP 403 "a required agreement is missing"; the Company team works
   > but was declined for branding.

### Then: one command
```sh
./release.sh            # build → sign → notarize → staple → .dmg → Sparkle-sign → appcast
./release.sh --publish  # ...and create the GitHub Release (serves the appcast)
```
`release.sh` auto-detects the Developer ID identity and the Sparkle tools and reads
the version from Info.plist. The manual steps below (1–6) are what it automates,
kept for reference / troubleshooting.

### Appcast feed URL
`SUFeedURL` in Info.plist currently points at:
`https://github.com/unknown6003/tessera/releases/latest/download/appcast.xml`
That works if you attach `appcast.xml` (and the `.dmg`) as assets on each GitHub
Release. Change it if you host the appcast elsewhere.

## 1. Bump the version
In `Tessera/Info.plist`: set `CFBundleShortVersionString` (e.g. `1.0.1`) and
increment `CFBundleVersion` (monotonic build number). Sparkle compares these.

## 2. Build, sign, notarize, staple the app
```sh
# Fresh machines: xcodebuild -downloadComponent MetalToolchain
xcodebuild -project Tessera.xcodeproj -scheme Tessera \
  -configuration Release -derivedDataPath dist/build clean build

APP="dist/build/Build/Products/Release/Tessera.app"

# Sign with Developer ID + hardened runtime (required for notarization).
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (YOURTEAMID)" "$APP"

# Notarize + staple the app itself so it verifies offline after drag-install.
ditto -c -k --keepParent "$APP" "Tessera.zip"
xcrun notarytool submit "Tessera.zip" --keychain-profile "TESSERA_NOTARY" --wait
xcrun stapler staple "$APP"
```
> Sparkle's own helper tools inside the bundle (Autoupdate, Updater.app,
> Installer/Downloader XPC services) are signed by the `--deep` pass; verify with
> `codesign -dv --deep --strict "$APP"` and `spctl -a -vvv "$APP"` (should say
> "accepted, source=Notarized Developer ID").

## 3. Package the .dmg, then sign + notarize it
```sh
STAGE="$(mktemp -d)"; cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Tessera" -srcfolder "$STAGE" -ov -format UDZO "Tessera-1.0.1.dmg"

codesign --force --sign "Developer ID Application: Your Name (YOURTEAMID)" --timestamp "Tessera-1.0.1.dmg"
xcrun notarytool submit "Tessera-1.0.1.dmg" --keychain-profile "TESSERA_NOTARY" --wait
xcrun stapler staple "Tessera-1.0.1.dmg"
```
Sparkle delivers this `.dmg` directly (it mounts it and installs the `.app` inside).

## 4. Generate the appcast
Put the signed `Tessera-*.dmg` builds in one folder and run Sparkle's tool — it
EdDSA-signs each archive and writes the appcast for you:
```sh
./bin/generate_appcast /path/to/updates_folder/   # produces appcast.xml
```
Add release notes (an HTML `<description>` or `<sparkle:releaseNotesLink>`) per item.

## 5. Publish the GitHub Release
```sh
gh release create v1.0.1 \
  Tessera-1.0.1.dmg appcast.xml \
  --repo unknown6003/tessera --title "1.0.1" --notes "…"
```
Because `SUFeedURL` uses `…/releases/latest/download/appcast.xml`, the newest
release's `appcast.xml` is what installed apps read on their next check.

## 6. Verify the update path
On a machine running the *previous* version, use **Check for Updates…** — Sparkle
should find 1.0.1, verify the EdDSA signature against `SUPublicEDKey`, download the
`.dmg`, and install. If it reports a signature error, the archive wasn't signed with
the key whose public half is in Info.plist.

---

### Notes
- **Icon:** add an `AppIcon` asset (1024px master) before public release; the build
  currently uses the default icon.
- **License:** none is committed yet — add `LICENSE` to match your open-source vs
  proprietary decision before publishing.
- **Windows / Linux:** see [DISTRIBUTION.md](DISTRIBUTION.md) for the cross-platform
  packaging plan (winget/MSI, apt/dnf/AUR/Flatpak). Those are future work — today's
  release is macOS-only.
- **`backend/`** (the old Cloudflare Worker) is gitignored and unused; the app is
  fully on-device.
