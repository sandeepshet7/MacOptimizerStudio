#!/usr/bin/env bash
set -euo pipefail

# Prerequisites:
# - Xcode project/workspace configured for signing
# - APP_BUNDLE_ID, DEVELOPER_ID_APP, DEVELOPER_ID_INSTALLER exported
# - NOTARYTOOL_PROFILE configured with xcrun notarytool store-credentials

SCHEME="MacOptimizerStudio"
CONFIGURATION="Release"
ARCHIVE_PATH="build/MacOptimizerStudio.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/MacOptimizerStudio.dmg"

mkdir -p build

echo "[1/5] Build archive"
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH"

echo "[2/5] Export signed app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist scripts/exportOptions.plist

echo "[3/5] Create DMG"
rm -f "$DMG_PATH"
hdiutil create -volname "MacOptimizer Studio" -srcfolder "$EXPORT_PATH" -ov -format UDZO "$DMG_PATH"

echo "[4/5] Notarize DMG"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "macoptimizer-notary" --wait

echo "[5/5] Staple + verify"
xcrun stapler staple "$DMG_PATH"
spctl -a -vv "$EXPORT_PATH/MacOptimizerStudio.app"
spctl -a -vv "$DMG_PATH"

echo "Release DMG ready: $DMG_PATH"
