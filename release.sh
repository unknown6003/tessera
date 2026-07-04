#!/usr/bin/env bash
#
# One-command release: build → Developer ID sign → notarize → staple → DMG →
# Sparkle-sign → appcast → (optional) GitHub Release. Run from the repo root.
#
# The app ships as a signed+notarized .dmg (drag-to-Applications). Sparkle
# delivers the same .dmg for over-the-air updates.
#
# Prerequisites (one-time):
#   • A "Developer ID Application" certificate in your login Keychain
#     (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ▸ Developer ID Application).
#   • A notarytool credential profile:
#       xcrun notarytool store-credentials "TESSERA_NOTARY" \
#         --apple-id you@example.com --team-id TEAMID --password app-specific-pw
#   • The Sparkle signing key (ALREADY GENERATED — private key is in this Mac's
#     Keychain; public key is in Info.plist).
#
# Usage:
#   ./release.sh                       # build, sign, notarize, dmg, appcast (no upload)
#   ./release.sh --publish             # also create the GitHub Release
#   NOTARY_PROFILE=TESSERA_NOTARY ./release.sh --publish
set -euo pipefail

REPO="unknown6003/tessera"
SCHEME="Tessera"
PROJECT="Tessera.xcodeproj"
INFO_PLIST="Tessera/Info.plist"
NOTARY_PROFILE="${NOTARY_PROFILE:-TESSERA_NOTARY}"
PUBLISH=0
[[ "${1:-}" == "--publish" ]] && PUBLISH=1

step() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# --- locate the Developer ID identity ---
DEV_ID="${DEV_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')}"
[[ -n "$DEV_ID" ]] || fail "No 'Developer ID Application' certificate found in the Keychain.
   Create one: Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ▸ Developer ID Application."

# --- locate the Sparkle tools (resolved SwiftPM artifact) ---
TOOLS="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*artifacts/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -1)"
TOOLS="$(dirname "${TOOLS:-}")"
[[ -x "$TOOLS/sign_update" ]] || fail "Sparkle tools not found — build once so SwiftPM resolves Sparkle."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
step "Releasing $SCHEME $VERSION   (identity: $DEV_ID)"

DIST="dist"; rm -rf "$DIST"; mkdir -p "$DIST"
DERIVED="$DIST/build"
UPDATES="$DIST/updates"; mkdir -p "$UPDATES"   # only release archives live here (appcast source)
TMP="$DIST/tmp"; mkdir -p "$TMP"

step "Release build"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED" clean build >/dev/null
APP="$DERIVED/Build/Products/Release/$SCHEME.app"
[[ -d "$APP" ]] || fail "build produced no app at $APP"

step "Code-sign the app (Developer ID, hardened runtime)"
codesign --force --deep --options runtime --timestamp --sign "$DEV_ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

step "Notarize + staple the app (offline-verifiable after drag-install)"
ditto -c -k --keepParent "$APP" "$TMP/notarize-app.zip"
xcrun notarytool submit "$TMP/notarize-app.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

step "Build the .dmg (drag-to-Applications)"
DMG="$UPDATES/$SCHEME-$VERSION.dmg"
STAGE="$TMP/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$SCHEME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

step "Code-sign, notarize + staple the .dmg"
codesign --force --sign "$DEV_ID" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -vvv "$DMG" 2>&1 | grep -i "accepted\|notarized" || true

step "Generate appcast (Sparkle EdDSA-signs the .dmg)"
"$TOOLS/generate_appcast" "$UPDATES"
[[ -f "$UPDATES/appcast.xml" ]] || fail "appcast.xml not generated"
rm -rf "$TMP"
echo "  → $UPDATES/appcast.xml  +  $DMG"

if [[ "$PUBLISH" == "1" ]]; then
  step "Publish GitHub Release v$VERSION"
  gh release create "v$VERSION" "$DMG" "$UPDATES/appcast.xml" \
     --repo "$REPO" --title "$VERSION" --generate-notes
  echo "  Published. SUFeedURL (releases/latest/download/appcast.xml) now serves $VERSION."
else
  printf "\n\033[1;32m✓ Built, signed, notarized, .dmg + appcast ready in %s/. Re-run with --publish to upload.\033[0m\n" "$UPDATES"
fi
