#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Always package a fresh, verified build, extracted outside synced folders.
./scripts/build.sh
PKG_STAGE="$(mktemp -d /private/tmp/texte-brut-pkg.XXXXXX)"
trap 'rm -rf "$PKG_STAGE"' EXIT
PKG_ROOT="$PKG_STAGE/root"
mkdir -p "$PKG_ROOT/Applications"
ditto -x -k dist/Get-Clean-Text-Apple-Silicon.zip "$PKG_ROOT/Applications"
PKG_APP="$PKG_ROOT/Applications/Get Clean Text.app"
codesign --verify --strict "$PKG_APP"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PKG_APP/Contents/Info.plist")"
APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PKG_APP/Contents/Info.plist")"

pkgbuild --analyze --root "$PKG_ROOT" "$PKG_STAGE/components.plist"
/usr/bin/python3 - "$PKG_STAGE" "$PKG_APP" <<'PY'
import pathlib
import plistlib
import sys

stage, app = map(pathlib.Path, sys.argv[1:])
with (stage / 'components.plist').open('rb') as source:
    components = plistlib.load(source)
assert len(components) == 1, 'The installer must contain exactly one app'
for component in components:
    # Always install into /Applications; never update an old development copy.
    component['BundleIsRelocatable'] = False
    component['BundleIsVersionChecked'] = True
    component['BundleHasStrictIdentifier'] = True
    component['BundleOverwriteAction'] = 'upgrade'
with (stage / 'components.plist').open('wb') as target:
    plistlib.dump(components, target)
with (app / 'Contents/Info.plist').open('rb') as source:
    info = plistlib.load(source)
with (stage / 'requirements.plist').open('wb') as target:
    plistlib.dump({'arch': ['arm64'], 'os': [info['LSMinimumSystemVersion']]}, target)
PY

pkgbuild --root "$PKG_ROOT" \
    --component-plist "$PKG_STAGE/components.plist" \
    --identifier "$APP_IDENTIFIER.installer" \
    --version "$APP_VERSION" --install-location / --ownership recommended \
    "$PKG_STAGE/texte-brut-component.pkg"
productbuild --synthesize --product "$PKG_STAGE/requirements.plist" \
    --package "$PKG_STAGE/texte-brut-component.pkg" "$PKG_STAGE/Distribution.xml"

/usr/bin/python3 - "$PKG_STAGE/Distribution.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()
ET.SubElement(root, 'title').text = 'Get Clean Text'
ET.SubElement(root, 'welcome', {'file': 'welcome.html', 'mime-type': 'text/html'})
ET.SubElement(root, 'conclusion', {'file': 'conclusion.html', 'mime-type': 'text/html'})
ET.SubElement(root, 'domains', {
    'enable_localSystem': 'true', 'enable_currentUserHome': 'false', 'enable_anywhere': 'false'
})
options = root.find('options')
assert options is not None
options.set('customize', 'never')
tree.write(path, encoding='utf-8', xml_declaration=True)
PY

PKG_OUTPUT="$PWD/dist/Get-Clean-Text-$APP_VERSION-Apple-Silicon.pkg"
productbuild --distribution "$PKG_STAGE/Distribution.xml" \
    --resources Resources/Installer --package-path "$PKG_STAGE" "$PKG_OUTPUT"

# Extract and verify the actual delivery payload, not just the source app.
pkgutil --expand-full "$PKG_OUTPUT" "$PKG_STAGE/verification"
PKG_VERIFIED_APP="$PKG_STAGE/verification/texte-brut-component.pkg/Payload/Applications/Get Clean Text.app"
codesign --verify --strict "$PKG_VERIFIED_APP"
cmp "$PKG_APP/Contents/MacOS/PlainText" "$PKG_VERIFIED_APP/Contents/MacOS/PlainText"
/usr/bin/xmllint --noout "$PKG_STAGE/verification/Distribution"
/usr/sbin/installer -pkginfo -pkg "$PKG_OUTPUT"
printf '\nInstallateur créé et vérifié : %s\n' "$PKG_OUTPUT"
