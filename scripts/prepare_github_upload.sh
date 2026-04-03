#!/bin/bash
set -e

# Creates github-upload folder with everything needed for GitHub
# Run from the project root: ./scripts/prepare_github_upload.sh

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/github-upload"

echo "=== MacOptimizer Studio — GitHub Upload Packager ==="
echo ""

# Clean previous output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/repo-files"
mkdir -p "$OUTPUT_DIR/release-binaries"

# ---- 1. Repo files (all source code + assets) ----
echo "[1/3] Copying repo files..."

REPO="$OUTPUT_DIR/repo-files"

# Package.swift
cp "$PROJECT_DIR/Package.swift" "$REPO/"

# README & logo
cp "$PROJECT_DIR/README.md" "$REPO/"
[ -f "$PROJECT_DIR/logo.png" ] && cp "$PROJECT_DIR/logo.png" "$REPO/"

# .gitignore
cp "$PROJECT_DIR/.gitignore" "$REPO/"

# Sources (all Swift code)
rsync -a --exclude '.DS_Store' "$PROJECT_DIR/Sources/" "$REPO/Sources/"

# Tests
if [ -d "$PROJECT_DIR/Tests" ]; then
    rsync -a --exclude '.DS_Store' "$PROJECT_DIR/Tests/" "$REPO/Tests/"
fi

# Website (docs/)
if [ -d "$PROJECT_DIR/docs" ]; then
    rsync -a --exclude '.DS_Store' "$PROJECT_DIR/docs/" "$REPO/docs/"
fi

# Scripts
mkdir -p "$REPO/scripts"
for f in "$PROJECT_DIR/scripts/"*.sh; do
    [ -f "$f" ] && cp "$f" "$REPO/scripts/"
done

# Screenshots
if [ -d "$PROJECT_DIR/screenshots" ]; then
    rsync -a --exclude '.DS_Store' "$PROJECT_DIR/screenshots/" "$REPO/screenshots/"
    echo "  ✓ Screenshots copied"
else
    mkdir -p "$REPO/screenshots"
    echo "  ⚠ No screenshots/ folder found — created empty one"
fi

echo "  ✓ All source files copied"

# ---- 2. Release binaries ----
echo ""
echo "[2/3] Copying release binaries..."

DMG_PATH="$PROJECT_DIR/build/local-app/MacOptimizerStudio-unsigned.dmg"
ZIP_PATH="$PROJECT_DIR/build/local-app/MacOptimizerStudio.zip"

if [ -f "$DMG_PATH" ]; then
    cp "$DMG_PATH" "$OUTPUT_DIR/release-binaries/"
    echo "  ✓ DMG copied"
else
    echo "  ⚠ DMG not found — run ./scripts/package_clickable_app.sh first"
fi

if [ -f "$ZIP_PATH" ]; then
    cp "$ZIP_PATH" "$OUTPUT_DIR/release-binaries/"
    echo "  ✓ ZIP copied"
else
    echo "  ⚠ ZIP not found"
fi

# ---- 3. Summary ----
echo ""
echo "=== Done! ==="
echo ""
echo "github-upload/"
echo "  repo-files/       ← commit all of this to GitHub"
echo "  release-binaries/ ← attach to GitHub Release"
echo ""
echo "--- Quick push from laptop ---"
echo ""
echo "  cp -r github-upload/repo-files/* /path/to/MacOptimizerStudio/"
echo "  cd /path/to/MacOptimizerStudio"
echo "  git add -A && git commit -m 'v1.0.1 — fixes and improvements'"
echo "  git push origin main"
echo ""
