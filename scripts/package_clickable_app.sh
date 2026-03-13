#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacOptimizerStudio"
BUNDLE_ID="com.macoptimizer.studio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_ROOT="${REPO_ROOT}/build/local-app"
APP_BUNDLE="${BUILD_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ZIP_PATH="${BUILD_ROOT}/${APP_NAME}.zip"
DMG_PATH="${BUILD_ROOT}/${APP_NAME}-unsigned.dmg"

mkdir -p "${BUILD_ROOT}"

echo "[1/6] Building Rust scanner (release)"
pushd "${REPO_ROOT}/rust/macopt-scanner" >/dev/null
cargo build --release
popd >/dev/null

SCANNER_PATH="${REPO_ROOT}/rust/macopt-scanner/target/release/macopt-scanner"
if [[ ! -x "${SCANNER_PATH}" ]]; then
  echo "Scanner not found at ${SCANNER_PATH}" >&2
  exit 1
fi

echo "[2/6] Building Swift app (release)"
swift build -c release --product "${APP_NAME}"
SWIFT_BIN_DIR="$(swift build -c release --product "${APP_NAME}" --show-bin-path)"
APP_EXECUTABLE="${SWIFT_BIN_DIR}/${APP_NAME}"

if [[ ! -x "${APP_EXECUTABLE}" ]]; then
  echo "App binary not found at ${APP_EXECUTABLE}" >&2
  exit 1
fi

echo "[3/6] Creating app bundle"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${APP_EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"
cp "${SCANNER_PATH}" "${RESOURCES_DIR}/macopt-scanner"
chmod +x "${MACOS_DIR}/${APP_NAME}" "${RESOURCES_DIR}/macopt-scanner"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "[4/6] Ad-hoc signing bundle for local launch"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "[5/6] Creating zip"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "[6/6] Creating unsigned dmg"
rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${BUILD_ROOT}" -ov -format UDZO "${DMG_PATH}" >/dev/null

echo ""
echo "Done. Artifacts:"
echo "  App: ${APP_BUNDLE}"
echo "  Zip: ${ZIP_PATH}"
echo "  DMG: ${DMG_PATH}"
echo ""
echo "For another Mac without Developer ID notarization:"
echo "  - Share ${ZIP_PATH} or ${DMG_PATH}"
echo "  - Receiver can right-click ${APP_NAME}.app -> Open"
