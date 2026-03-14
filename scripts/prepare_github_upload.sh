#!/bin/bash
set -e

# Creates a zip with everything needed for GitHub upload
# Run from the project root: ./scripts/prepare_github_upload.sh

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/github-upload"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ZIP_NAME="MacOptimizerStudio_github_upload_${TIMESTAMP}.zip"

echo "=== MacOptimizer Studio — GitHub Upload Packager ==="
echo ""

# Clean previous output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/repo-files/docs"
mkdir -p "$OUTPUT_DIR/repo-files/screenshots"
mkdir -p "$OUTPUT_DIR/release-binaries"

# ---- 1. Repo files (commit these to GitHub) ----
echo "[1/3] Copying repo files..."

# Logo
cp "$PROJECT_DIR/logo.png" "$OUTPUT_DIR/repo-files/"

# Website (docs/)
cp "$PROJECT_DIR/docs/index.html" "$OUTPUT_DIR/repo-files/docs/"
cp "$PROJECT_DIR/docs/logo.png" "$OUTPUT_DIR/repo-files/docs/"

# README
cp "$PROJECT_DIR/README.md" "$OUTPUT_DIR/repo-files/"

# Screenshots placeholder
echo "PUT YOUR SCREENSHOTS HERE" > "$OUTPUT_DIR/repo-files/screenshots/README.txt"
echo ""
echo "  Screenshots folder created at: $OUTPUT_DIR/repo-files/screenshots/"
echo "  Take these screenshots and drop them in:"
echo ""
echo "    1. home.png        — Home dashboard with overview cards"
echo "    2. quick-clean.png — Quick Clean scan results or button"
echo "    3. memory.png      — Memory monitor with process list"
echo "    4. cache.png       — Cache cleanup with categories expanded"
echo "    5. disk.png        — Disk analysis with largest folders"
echo "    6. cpu.png         — CPU monitor with process table"
echo "    7. docker.png      — Docker management (images/volumes)"
echo "    8. battery.png     — Battery health view"
echo "    9. maintenance.png — Maintenance scripts view"
echo "   10. activity_log.png — Activity/audit log view"
echo ""

# ---- 2. Release binaries (upload as GitHub Release v1.0) ----
echo "[2/3] Copying release binaries..."

DMG_PATH="$PROJECT_DIR/build/local-app/MacOptimizerStudio-unsigned.dmg"
ZIP_PATH="$PROJECT_DIR/build/local-app/MacOptimizerStudio.zip"

if [ -f "$DMG_PATH" ]; then
    cp "$DMG_PATH" "$OUTPUT_DIR/release-binaries/"
    echo "  ✓ DMG copied"
else
    echo "  ⚠ DMG not found at $DMG_PATH"
    echo "    Run ./scripts/package_clickable_app.sh first to build it"
fi

if [ -f "$ZIP_PATH" ]; then
    cp "$ZIP_PATH" "$OUTPUT_DIR/release-binaries/"
    echo "  ✓ ZIP copied"
else
    echo "  ⚠ ZIP not found at $ZIP_PATH"
fi

# ---- 3. Create final zip ----
echo ""
echo "[3/3] Creating zip..."
cd "$OUTPUT_DIR/.."
zip -r "$ZIP_NAME" "github-upload/" -x "*.DS_Store"
echo ""
echo "=== Done! ==="
echo ""
echo "Zip created: $PROJECT_DIR/$ZIP_NAME"
echo ""
echo "--- What to do on your laptop ---"
echo ""
echo "1. Unzip $ZIP_NAME"
echo ""
echo "2. TAKE SCREENSHOTS first (open the app, capture each view)"
echo "   Drop them into github-upload/repo-files/screenshots/"
echo ""
echo "3. COMMIT repo files to GitHub:"
echo "   cp -r github-upload/repo-files/* /path/to/MacOptimizerStudio/"
echo "   cd /path/to/MacOptimizerStudio"
echo "   git add README.md logo.png docs/ screenshots/"
echo "   git commit -m 'Update README, website, and add screenshots'"
echo "   git push origin main"
echo ""
echo "4. ENABLE GitHub Pages:"
echo "   GitHub repo → Settings → Pages → Source: Deploy from branch"
echo "   Branch: main, Folder: /docs → Save"
echo ""
echo "5. CREATE GitHub Release v1.0:"
echo "   GitHub repo → Releases → Draft new release"
echo "   Tag: v1.0"
echo "   Title: MacOptimizer Studio v1.0"
echo "   Attach: github-upload/release-binaries/MacOptimizerStudio-unsigned.dmg"
echo "   Attach: github-upload/release-binaries/MacOptimizerStudio.zip"
echo "   Publish release"
echo ""
