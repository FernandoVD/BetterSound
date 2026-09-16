#!/bin/bash
# Builds BetterSound.app — a proper macOS app bundle — from the Swift package.
# No Xcode project needed; this wraps `swift build`'s release binary.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="BetterSound"
APP_BUNDLE="${APP_NAME}.app"

# Universal binary — arm64 for Apple Silicon, x86_64 for the handful of
# Intel Macs macOS 26 still supports (16" MacBook Pro 2019, 13" MacBook Pro
# 2020, 2020 iMac, 2019 Mac Pro; Apple has said Tahoe is the last macOS
# version to support Intel at all). --show-bin-path finds the real output
# directory rather than hardcoding it, since SwiftPM's layout can vary.
echo "==> Building universal release binary (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64
BUILD_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

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
