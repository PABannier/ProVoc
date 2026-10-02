#!/bin/bash
# Packages the Release build as a disk image:
#
#   .github/scripts/package.sh [tag]
#
# dist/ProVoc-<version>-arm64.dmg holds ProVoc.app next to a shortcut to the
# Applications folder, to drag the application onto (the window is laid out by
# dmgbuild: "pip install dmgbuild", or DMGBUILD=<command>); dist/ProVoc.app is the same
# application. With a tag that is a version number (v4.3 or 4.3) the application gets
# that version; otherwise it keeps the one of Resources/Info.plist.
#
# The application is signed ad hoc, not notarized: see "Download" in the README for
# what macOS asks the first time it is opened.
set -euo pipefail
cd "$(dirname "$0")/../.."
BUILT=build/DerivedData/Build/Products/Release/ProVoc.app
[ -d "$BUILT" ] || { echo "no $BUILT: build the Release configuration first"; exit 1; }

TAG=${1:-}
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUILT/Contents/Info.plist")
rm -rf dist && mkdir -p dist/image
cp -R "$BUILT" dist/image/ProVoc.app
APP=dist/image/ProVoc.app
if [[ "$TAG" =~ ^v?([0-9]+(\.[0-9]+)*)$ ]]; then
	VERSION=${BASH_REMATCH[1]}
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
elif [ -n "$TAG" ]; then
	VERSION=$TAG
fi

# the licence of Arizona Software goes with the application (its second condition:
# the notice is reproduced in what is provided with a binary distribution)
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"

codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP"
# arm64, and nothing else, in every binary of the application
while IFS= read -r file; do
	if file -b "$file" | grep -q "Mach-O"; then
		[ "$(lipo -archs "$file")" = "arm64" ] || { echo "$file: $(lipo -archs "$file")"; exit 1; }
	fi
done < <(find "$APP" -type f)

DMG="dist/ProVoc-$VERSION-arm64.dmg"
${DMGBUILD:-dmgbuild} -s .github/scripts/dmg-settings.py -D app="$APP" "ProVoc $VERSION" "$DMG" > /dev/null

# what someone who opens the image gets
MOUNT=$(mktemp -d)
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" > /dev/null
trap 'hdiutil detach "$MOUNT" > /dev/null 2>&1 || true' EXIT
codesign --verify --deep --strict "$MOUNT/ProVoc.app"
[ "$(lipo -archs "$MOUNT/ProVoc.app/Contents/MacOS/ProVoc")" = "arm64" ]
[ "$(readlink "$MOUNT/Applications")" = "/Applications" ]
[ -f "$MOUNT/.DS_Store" ] || { echo "the image has no window layout"; exit 1; }
grep -q "Arizona Software" "$MOUNT/ProVoc.app/Contents/Resources/LICENSE.txt"
echo "in the image: $(ls "$MOUNT" | tr '\n' ' ')— ProVoc $(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$MOUNT/ProVoc.app/Contents/Info.plist")"
hdiutil detach "$MOUNT" > /dev/null
trap - EXIT

mv "$APP" dist/ProVoc.app && rm -rf dist/image
(cd dist && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "$DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
