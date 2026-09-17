#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 2 ]]; then
    printf 'Usage: %s <signed-app> <output.dmg>\n' "$0" >&2
    exit 1
fi
APP_SOURCE="$1"
DMG_OUTPUT="$2"
DMG_STAGE="$(mktemp -d /private/tmp/get-clean-text-dmg.XXXXXX)"
DMG_MOUNT=""
cleanup() {
    if [[ -n "$DMG_MOUNT" ]]; then
        hdiutil detach "$DMG_MOUNT" -quiet || return
    fi
    rm -rf "$DMG_STAGE"
}
trap cleanup EXIT
mkdir -p "$DMG_STAGE/source/.background" "$DMG_STAGE/mount"
ditto --norsrc --noextattr "$APP_SOURCE" "$DMG_STAGE/source/Get Clean Text.app"
ln -s /Applications "$DMG_STAGE/source/Applications"
swift scripts/make-dmg-background.swift "$DMG_STAGE/source/.background/install-layout.pdf"
hdiutil create -volname "Get Clean Text Build ${DMG_STAGE##*.}" -srcfolder "$DMG_STAGE/source" \
    -format UDRW -size 32m "$DMG_STAGE/editable.dmg"
hdiutil attach "$DMG_STAGE/editable.dmg" -readwrite -nobrowse -noautoopen \
    -mountpoint "$DMG_STAGE/mount"
DMG_MOUNT="$DMG_STAGE/mount"
osascript scripts/style-dmg.applescript "$DMG_MOUNT"
# Finder writes layout metadata asynchronously after the window closes.
for attempt in {1..15}; do
    [[ -f "$DMG_MOUNT/.DS_Store" ]] && break
    sleep 1
done
test -f "$DMG_MOUNT/.DS_Store"
diskutil renameVolume "$DMG_MOUNT" "Get Clean Text"
sync
hdiutil detach "$DMG_MOUNT" -quiet
DMG_MOUNT=""
hdiutil convert "$DMG_STAGE/editable.dmg" -format UDZO -o "$DMG_STAGE/final.dmg"
hdiutil verify "$DMG_STAGE/final.dmg"
hdiutil attach "$DMG_STAGE/final.dmg" -readonly -nobrowse -noautoopen \
    -mountpoint "$DMG_STAGE/mount"
DMG_MOUNT="$DMG_STAGE/mount"
codesign --verify --strict "$DMG_MOUNT/Get Clean Text.app"
cmp "$APP_SOURCE/Contents/MacOS/PlainText" "$DMG_MOUNT/Get Clean Text.app/Contents/MacOS/PlainText"
test "$(readlink "$DMG_MOUNT/Applications")" = /Applications
test -f "$DMG_MOUNT/.background/install-layout.pdf"
test -f "$DMG_MOUNT/.DS_Store"
hdiutil detach "$DMG_MOUNT" -quiet
DMG_MOUNT=""
cp "$DMG_STAGE/final.dmg" "$DMG_OUTPUT"
printf 'DMG créé et vérifié : %s\n' "$DMG_OUTPUT"
