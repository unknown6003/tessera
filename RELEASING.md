# Releasing Tessera

The app ships **directly** (not the Mac App Store): Developer ID–signed, notarized,
packaged as a **.dmg**, and auto-updated via **Sparkle**. This is the full runbook.
You need an Apple Developer account (for the Developer ID certificate + notarization)
and a one-time Sparkle signing key.

> The app is hard-coded to be on-device only. The only network it performs is the
> optional model download and Sparkle update checks — keep it that way.

## 0. One-time setup

### Sparkle EdDSA signing key — ✅ generated locally; CI secret required
Already generated. The **private** key is in this Mac's login Keychain and the
**public** key is in `Tessera/Info.plist` (`SUPublicEDKey`). Don't commit the private
key or leave exported copies behind. To re-print the public key:
`<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -p`.
⚠️ Back up the private key (Keychain item "ed25519" / account
`https://sparkle-project.org`) — if it's lost you can't sign updates that existing
installs will accept.

GitHub's tag-driven release workflow needs the *same* key as the Actions secret
`SPARKLE_PRIVATE_KEY`. Export it once on the Mac that created the key, upload the
file directly to GitHub, then securely delete the exported copy:
```sh
TOOLS="<DerivedData>/SourcePackages/artifacts/sparkle/Sparkle/bin"
"$TOOLS/generate_keys" -x /tmp/tessera-sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY < /tmp/tessera-sparkle-private-key
rm -P /tmp/tessera-sparkle-private-key
```
Never generate a replacement key for this workflow: existing installations trust
the public key already embedded in 0.1.1.

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

For the current ad-hoc distribution channel, pushing a version tag runs the guarded
GitHub release workflow after the qualification checks have passed:
```sh
git tag v0.1.2
git push origin v0.1.2
```
It refuses a tag/plist mismatch or missing Sparkle key, runs the native suite again,
creates `Tessera.dmg`, EdDSA-signs the archive in `appcast.xml`, and publishes the
draft only after every asset has been validated. Developer ID signing/notarization
remains the production-distribution upgrade described below.

### Appcast feed URL
`SUFeedURL` in Info.plist currently points at:
`https://github.com/unknown6003/tessera/releases/latest/download/appcast.xml`
That works if you attach `appcast.xml` (and the `.dmg`) as assets on each GitHub
Release. Change it if you host the appcast elsewhere.

## 1. Bump the version
In `Tessera/Info.plist`: set `CFBundleShortVersionString` (e.g. `0.1.1`) and
increment `CFBundleVersion` (monotonic build number). Sparkle compares these.

**v1 launch guard:** `release.sh --publish` refuses every `1.x` version unless
the owner has explicitly directed the v1 launch and the command is rerun with
`CONFIRM_V1_RELEASE=YES`. Do not set that override preemptively.

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
hdiutil create -volname "Tessera" -srcfolder "$STAGE" -ov -format UDZO "Tessera-0.1.1.dmg"

codesign --force --sign "Developer ID Application: Your Name (YOURTEAMID)" --timestamp "Tessera-0.1.1.dmg"
xcrun notarytool submit "Tessera-0.1.1.dmg" --keychain-profile "TESSERA_NOTARY" --wait
xcrun stapler staple "Tessera-0.1.1.dmg"
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
gh release create v0.1.1 \
  Tessera-0.1.1.dmg appcast.xml \
  --repo unknown6003/tessera --title "0.1.1" --notes "…"
```
Because `SUFeedURL` uses `…/releases/latest/download/appcast.xml`, the newest
release's `appcast.xml` is what installed apps read on their next check.

## 6. Verify the update path
On a machine running the *previous* version, wait for a scheduled check or use the
app-menu item **Check for Updates Now** — Sparkle should find 0.1.1, verify the
EdDSA signature against `SUPublicEDKey`, download the `.dmg`, install it, and
relaunch the app by itself. If it reports a signature error, the archive wasn't
signed with the key whose public half is in Info.plist.

## 7. How updates behave for users (fully automatic)

Updates are **hands-off**: the app checks on a schedule, downloads in the
background, installs, and **relaunches itself**. The user is never prompted and
never clicks anything.

- Implemented by a custom `SPUUserDriver` (`SilentUserDriver` in
  `Tessera/Engine/Updater.swift`) that auto-approves every decision Sparkle would
  normally show a dialog for.
- Defaults come from Info.plist: `SUEnableAutomaticChecks` (no first-launch
  permission prompt), `SUAutomaticallyUpdate` + `SUAllowsAutomaticUpdates`
  (download+install without asking), `SUScheduledCheckInterval` = 6h.
- **The self-relaunch is held back while the app is busy** — mid-scan, or with
  files staged in the Cleanup List (a relaunch would discard that list). The
  queued update installs the moment the app goes idle, and lands on next launch
  regardless, since Sparkle installs a downloaded update on quit.
- The app-menu item doubles as status: *Checking… / Downloading Update… 42% /
  Installing Update… / Tessera is Up to Date*.
- Safety is unchanged: Sparkle verifies each update's EdDSA signature against
  `SUPublicEDKey` before installing, so **silent ≠ unverified** — an unsigned or
  tampered build cannot install. Guard the private key accordingly (§1).

---

### Notes
- **Icon:** done — `Tessera/Assets.xcassets/AppIcon.appiconset` is generated from the
  one brand vector (`cd web && npm run icons`), the same source as the site favicon.
- **License:** GPL-3.0 (`LICENSE`).
- **Windows / Linux:** see [DISTRIBUTION.md](DISTRIBUTION.md) for the cross-platform
  packaging plan (winget/MSI, apt/dnf/AUR/Flatpak). Those are future work — today's
  release is macOS-only.
- **`backend/`** (the old Cloudflare Worker) is gitignored and unused; the app is
  fully on-device.
