#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build -c release --arch arm64 --disable-sandbox --cache-path "$PWD/.build/cache"
BIN_DIR="$(swift build -c release --arch arm64 --disable-sandbox --cache-path "$PWD/.build/cache" --show-bin-path)"
STAGING_DIR="$(mktemp -d /private/tmp/texte-brut-build.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP="$STAGING_DIR/Texte brut.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PlainText" "$APP/Contents/MacOS/PlainText"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
# Sign outside cloud-synced folders, which can attach Finder metadata.
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
mkdir -p "$PWD/dist"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$PWD/dist/Texte-brut-Apple-Silicon.zip"
ditto --norsrc --noextattr "$APP" "$PWD/dist/Texte brut.app"
xattr -d com.apple.FinderInfo "$PWD/dist/Texte brut.app" 2>/dev/null || true
# The archive preserves the verified bundle even if the sync provider later
# adds FinderInfo to the loose copy in dist.
printf 'Application créée : %s\n' "$PWD/dist/Texte brut.app"
