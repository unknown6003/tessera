#!/usr/bin/env bash
# Unsigned release: build Release → ad-hoc sign (runs on Apple Silicon) →
# .dmg (drag-to-Applications) → copy to web/public/download/Tessera.dmg.
# No Developer ID, no notarization — nothing to wait on from Apple.
set -euo pipefail

SCHEME="Tessera"
PROJECT="Tessera.xcodeproj"
INFO_PLIST="Tessera/Info.plist"
WEB_DOWNLOAD="web/public/download"

step() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
step "Building $SCHEME $VERSION  (unsigned / ad-hoc)"

DIST="dist"
DERIVED="$DIST/build"
UPDATES="$DIST/updates"; mkdir -p "$UPDATES"
TMP="$DIST/tmp"; rm -rf "$TMP"; mkdir -p "$TMP"

step "Release build (ad-hoc signing, no Developer ID)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  clean build >"$DIST/build-unsigned.log" 2>&1 || { tail -40 "$DIST/build-unsigned.log"; fail "build failed (see $DIST/build-unsigned.log)"; }

APP="$DERIVED/Build/Products/Release/$SCHEME.app"
[[ -d "$APP" ]] || fail "build produced no app at $APP"

step "Ad-hoc re-sign (whole bundle, so it launches on Apple Silicon)"
codesign --force --deep --sign - --entitlements Tessera/Tessera.entitlements "$APP"
codesign --verify --deep --verbose=2 "$APP" 2>&1 | tail -2 || true

step "Build the .dmg (drag-to-Applications)"
DMG="$UPDATES/$SCHEME-$VERSION.dmg"
STAGE="$TMP/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$SCHEME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$TMP"

step "Publish to landing-page download folder"
mkdir -p "$WEB_DOWNLOAD"
cp "$DMG" "$WEB_DOWNLOAD/$SCHEME.dmg"

SIZE="$(du -h "$DMG" | cut -f1)"
printf "\n\033[1;32m✓ Unsigned .dmg ready (%s)\033[0m\n" "$SIZE"
echo "  → $DMG"
echo "  → $WEB_DOWNLOAD/$SCHEME.dmg"
