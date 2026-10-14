#!/usr/bin/env bash
set -euo pipefail

# Cellar release script — archive, export, notarize, staple, package as DMG,
# and generate a signed Sparkle appcast for GitHub Releases.
#
# Prerequisites (one-time):
#   xcrun notarytool store-credentials "cellar-notary" \
#     --apple-id "tuhage@gmail.com" --team-id "23H73A78A7" \
#     --password "<app-specific-password>"
#
# Usage:
#   ./scripts/release.sh                   # uses version/build from project
#   ./scripts/release.sh 1.6.0 15          # override marketing version and build
#   SKIP_NOTARIZE=1 ./scripts/release.sh  # archive + export only

cd "$(dirname "$0")/.."

PROJECT="Cellar.xcodeproj"
SCHEME="Cellar"
TEAM_ID="23H73A78A7"
KEYCHAIN_PROFILE="cellar-notary"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Cellar.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/Cellar.app"
SPARKLE_PACKAGES_DIR="$BUILD_DIR/SourcePackages"
APPCAST_DIR="$BUILD_DIR/appcast"
APPCAST_PATH="$APPCAST_DIR/appcast.xml"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}')
fi
BUILD_NUMBER="${2:-}"
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/CURRENT_PROJECT_VERSION/ {print $2; exit}')
fi
DMG_PATH="$BUILD_DIR/Cellar-$VERSION.dmg"
BUILD_OVERRIDES=(MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER")

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_PATH"

cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

log "Archiving $SCHEME $VERSION ($BUILD_NUMBER)"
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  "${BUILD_OVERRIDES[@]}" \
  archive | xcbeautify 2>/dev/null || \
xcodebuild -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  "${BUILD_OVERRIDES[@]}" \
  archive

log "Exporting Developer ID build"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -allowProvisioningUpdates

if [[ ! -d "$APP_PATH" ]]; then
  echo "Export failed: $APP_PATH not found" >&2
  exit 1
fi

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
  log "SKIP_NOTARIZE=1 — skipping notarization & DMG"
  log "Done. App at: $APP_PATH"
  exit 0
fi

log "Notarizing app"
ZIP_PATH="$BUILD_DIR/Cellar-notarize.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
rm -f "$ZIP_PATH"

log "Building DMG: $DMG_PATH"
STAGING_DIR="$BUILD_DIR/dmg-staging"
RW_DMG="$BUILD_DIR/Cellar-rw.dmg"
MOUNT_POINT="/Volumes/Cellar"

rm -rf "$STAGING_DIR" "$RW_DMG"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

# Make sure no stale mount is around
if [[ -d "$MOUNT_POINT" ]]; then
  hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
fi

# Create a read-write DMG large enough for the app + Finder metadata
hdiutil create \
  -srcfolder "$STAGING_DIR" \
  -volname "Cellar" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size 200m \
  "$RW_DMG" >/dev/null

hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -noverify -noautoopen >/dev/null

# Drop an Applications symlink so users can drag-install
ln -s /Applications "$MOUNT_POINT/Applications"

# Lay out the Finder window: hidden toolbar/sidebar, 540×380, icons side-by-side
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "Cellar"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set sidebar width of container window to 0
        set the bounds of container window to {400, 100, 940, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 13
        set position of item "Cellar.app" of container window to {140, 170}
        set position of item "Applications" of container window to {400, 170}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_POINT" >/dev/null

# Convert read-write to compressed read-only final DMG
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGING_DIR"

log "Signing DMG"
codesign --sign "Developer ID Application: Tugrul Hakan Gencturk ($TEAM_ID)" "$DMG_PATH"

log "Notarizing DMG"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

log "Resolving Sparkle release tools"
xcodebuild -resolvePackageDependencies \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -clonedSourcePackagesDirPath "$SPARKLE_PACKAGES_DIR" >/dev/null

GENERATE_APPCAST="$SPARKLE_PACKAGES_DIR/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast tool not found at $GENERATE_APPCAST" >&2
  exit 1
fi

log "Generating signed Sparkle appcast"
rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DMG_PATH" "$APPCAST_DIR/"

if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
    echo "RELEASE_NOTES_FILE does not exist: $RELEASE_NOTES_FILE" >&2
    exit 1
  fi
  cp "$RELEASE_NOTES_FILE" "$APPCAST_DIR/Cellar-$VERSION.md"
fi

"$GENERATE_APPCAST" \
  --download-url-prefix "https://github.com/tuhage/Cellar/releases/download/v$VERSION/" \
  --link "https://github.com/tuhage/Cellar/releases/tag/v$VERSION" \
  --maximum-versions 1 \
  --maximum-deltas 0 \
  -o "$APPCAST_PATH" \
  "$APPCAST_DIR"

if ! grep -q 'sparkle:edSignature=' "$APPCAST_PATH"; then
  echo "Appcast was generated without an Ed25519 signature" >&2
  exit 1
fi

log "Done"
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"
echo "  Appcast: $APPCAST_PATH"
echo
RELEASE_ASSETS="\"$DMG_PATH\" \"$APPCAST_PATH\""
RELEASE_NOTES="--generate-notes"
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  # The appcast's release notes link points at this file on the release.
  RELEASE_ASSETS+=" \"$APPCAST_DIR/Cellar-$VERSION.md\""
  RELEASE_NOTES="--notes-file \"$RELEASE_NOTES_FILE\""
fi

echo "Publish:"
echo "  git tag -a v$VERSION -m \"v$VERSION\" && git push origin v$VERSION"
echo "  gh release create v$VERSION $RELEASE_ASSETS --title \"Cellar $VERSION\" $RELEASE_NOTES --verify-tag"
echo "  ./scripts/update-cask.sh $VERSION"
