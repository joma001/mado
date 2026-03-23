#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Mado"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
INSTALL_PATH="/Applications/mado.app"
xcodebuild \
  -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build 2>&1 | tail -5
# Find the built .app in DerivedData
APP_PATH=$(find "$DERIVED_DATA/Build/Products/Release" -name "mado.app" -maxdepth 1 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  APP_PATH="$BUILD_DIR/mado.app"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "Build failed — app not found"
  exit 1
fi

echo ""
echo "Installing to /Applications..."
if [ -d "$INSTALL_PATH" ]; then
  rm -rf "$INSTALL_PATH"
fi
cp -R "$APP_PATH" "$INSTALL_PATH"

# Clear Gatekeeper quarantine flag
xattr -cr "$INSTALL_PATH" 2>/dev/null || true

echo ""
echo "Done. Run from /Applications or Spotlight."
echo "(First launch: if macOS blocks it, right-click → Open)"
