#!/bin/bash
# Builds BetterSound.app — a proper macOS app bundle — from the Swift package.
# No Xcode project needed; this wraps `swift build`'s release binary.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="BetterSound"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "==> Building release binary..."
swift build -c release

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "    Move it to /Applications, then open it. Launch-at-login registration"
echo "    works best when the app runs from a stable, permanent location."
