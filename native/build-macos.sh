#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_DIR="$PROJECT_DIR/build/时迹.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="$PROJECT_DIR/build/module-cache"
SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
BUILD_ARCH="${TARGET_ARCH:-$(uname -m)}"

case "$BUILD_ARCH" in
  arm64|x86_64) ;;
  *) echo "Unsupported architecture: $BUILD_ARCH" >&2; exit 1 ;;
esac

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

xcrun swiftc \
  "$SCRIPT_DIR/ShijiApp.swift" \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -target "$BUILD_ARCH-apple-macosx13.0" \
  -framework AppKit \
  -framework WebKit \
  -o "$MACOS_DIR/Shiji"

cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/dist/index.html" "$RESOURCES_DIR/index.html"
cp "$PROJECT_DIR/dist/popover.html" "$RESOURCES_DIR/popover.html"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
