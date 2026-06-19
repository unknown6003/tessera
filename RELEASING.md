# Releasing Storage Optimizer

The app ships **directly** (not the Mac App Store): Developer ID–signed, notarized,
and auto-updated via **Sparkle**. This is the full runbook. You need an Apple
Developer account (for the Developer ID certificate + notarization) and a one-time
Sparkle signing key.

> The app is hard-coded to be on-device only. The only network it performs is the
> optional model download and Sparkle update checks — keep it that way.

## 0. One-time setup

### Apple Developer ID
- In Xcode → Settings → Accounts, sign in and create a **Developer ID Application**
  certificate (this is the cert used for direct distribution, *not* "Mac App
  Distribution").
- Create a notarytool credential profile:
  ```sh
  xcrun notarytool store-credentials "SO_NOTARY" \
    --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-pw"
  ```

### Sparkle EdDSA signing key (do this once, keep the private key safe)
Download the Sparkle release (https://github.com/sparkle-project/Sparkle/releases),
then:
```sh
./bin/generate_keys          # stores the PRIVATE key in your login Keychain
```
It prints your **public** key. Paste it into `StorageOptimizer/Info.plist` →
`SUPublicEDKey`, replacing `REPLACE_WITH_YOUR_SPARKLE_PUBLIC_ED_KEY`.
(Until you do this, OTA is inert by design — the app runs fine and the "Check for
Updates…" menu item stays disabled.)

### Appcast feed URL
`SUFeedURL` in Info.plist currently points at:
`https://github.com/unknown6003/storage-optimizer/releases/latest/download/appcast.xml`
That works if you attach `appcast.xml` (and the zip) as assets on each GitHub
Release. Change it if you host the appcast elsewhere.

## 1. Bump the version
In `StorageOptimizer/Info.plist`: set `CFBundleShortVersionString` (e.g. `1.0.1`)
and increment `CFBundleVersion` (monotonic build number). Sparkle compares these.

## 2. Build, sign, notarize, staple
```sh
# Fresh machines: xcodebuild -downloadComponent MetalToolchain
xcodebuild -project StorageOptimizer.xcodeproj -scheme StorageOptimizer \
  -configuration Release -derivedDataPath build clean build

APP="build/Build/Products/Release/StorageOptimizer.app"

# Sign with Developer ID + hardened runtime (required for notarization).
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (YOURTEAMID)" "$APP"

# Zip, notarize, staple.
ditto -c -k --keepParent "$APP" "StorageOptimizer.zip"
xcrun notarytool submit "StorageOptimizer.zip" --keychain-profile "SO_NOTARY" --wait
xcrun stapler staple "$APP"
```
> Sparkle's own helper tools inside the bundle (Autoupdate, Updater.app,
> Installer/Downloader XPC services) are signed by the `--deep` pass; verify with
> `codesign -dv --deep --strict "$APP"` and `spctl -a -vvv "$APP"` (should say
> "accepted, source=Notarized Developer ID").

## 3. Package the update + sign it for Sparkle
Re-zip the **stapled** app and sign the archive:
```sh
ditto -c -k --keepParent "$APP" "StorageOptimizer-1.0.1.zip"
./bin/sign_update "StorageOptimizer-1.0.1.zip"   # prints sparkle:edSignature + length
```

## 4. Generate the appcast
Easiest: drop all the signed `StorageOptimizer-*.zip` builds in one folder and run
Sparkle's tool — it signs and writes the appcast for you:
```sh
./bin/generate_appcast /path/to/updates_folder/   # produces appcast.xml
```
Add release notes (an HTML `<description>` or `<sparkle:releaseNotesLink>`) per item.

## 5. Publish the GitHub Release
```sh
gh release create v1.0.1 \
  StorageOptimizer-1.0.1.zip appcast.xml \
  --repo unknown6003/storage-optimizer --title "1.0.1" --notes "…"
```
Because `SUFeedURL` uses `…/releases/latest/download/appcast.xml`, the newest
release's `appcast.xml` is what installed apps read on their next check.

## 6. Verify the update path
On a machine running the *previous* version, use **Check for Updates…** — Sparkle
should find 1.0.1, verify the EdDSA signature against `SUPublicEDKey`, download, and
install. If it reports a signature error, the zip wasn't signed with the key whose
public half is in Info.plist.

---

### Notes
- **Icon:** add an `AppIcon` asset (1024px master) before public release; the build
  currently uses the default icon.
- **License:** none is committed yet — add `LICENSE` to match your open-source vs
  proprietary decision before publishing.
- **`backend/`** (the old Cloudflare Worker) is gitignored and unused; the app is
  fully on-device.
