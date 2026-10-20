#!/bin/bash
# Copies dist/ProVoc.app (made by scripts/verify.sh) to /Applications. A copy that is
# already there is archived in ~/ProVoc backups/ first, as a zip, never deleted.
#
# Only one ProVoc.app may be left on the disk. Launch Services (Spotlight, the Dock, a
# double-clicked deck, "open -a ProVoc") chooses among every application that has
# ProVoc's bundle identifier, wherever it is: an old copy left as a .app in the backups
# folder could be the one that opened, under its own name ("ProVoc 2026-10-02-134136").
# So old copies become zip archives, and the copies of the build are forgotten by Launch
# Services until they are launched again.
#
#   scripts/install.sh
#   PROVOC_INSTALL_DIR=<folder> PROVOC_BACKUP_DIR=<folder> scripts/install.sh   (scripts/install-check.sh)
set -u
cd "$(dirname "$0")/.." || exit 1
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
INSTALL_DIR=${PROVOC_INSTALL_DIR:-/Applications}
BACKUP_DIR=${PROVOC_BACKUP_DIR:-$HOME/ProVoc backups}
APP="$INSTALL_DIR/ProVoc.app"
[ -d dist/ProVoc.app ] || { echo "no dist/ProVoc.app: run scripts/verify.sh first"; exit 1; }
codesign --verify --deep --strict dist/ProVoc.app || { echo "dist/ProVoc.app is not properly signed"; exit 1; }
# the executable paths only (comm), not the command lines: a shell whose command mentions the path is not ProVoc
RUNNING=$(ps -axo comm= | grep -F -e "$APP/Contents/MacOS/ProVoc" -e "$BACKUP_DIR/" | head -1)
[ -z "$RUNNING" ] || { echo "ProVoc is running ($RUNNING): quit it first"; exit 1; }
if [ -e "$APP" ]; then
	mkdir -p "$BACKUP_DIR" || exit 1
	BACKUP="$BACKUP_DIR/ProVoc $(date +%Y-%m-%d-%H%M%S).app"
	"$LSREGISTER" -u "$APP"
	mv "$APP" "$BACKUP" || exit 1
fi
# every .app in the backups folder (this one, and those left by earlier installs) becomes a zip
for OLD in "$BACKUP_DIR"/*.app; do
	[ -d "$OLD" ] || continue
	ZIP="${OLD%.app}.zip"
	"$LSREGISTER" -u "$OLD" 2> /dev/null
	ditto -c -k --sequesterRsrc --keepParent "$OLD" "$ZIP" && unzip -tqq "$ZIP" && rm -rf "$OLD" || exit 1
	echo "the previous ProVoc.app is archived: $ZIP"
done
cp -R dist/ProVoc.app "$APP" || exit 1
codesign --verify --deep --strict "$APP" || exit 1
# .pvoc documents open with this copy, and Spotlight finds its importer
"$LSREGISTER" -u build/DerivedData/Build/Products/Release/ProVoc.app dist/ProVoc.app 2> /dev/null
"$LSREGISTER" -f "$APP"
echo "installed: $APP ($(lipo -archs "$APP/Contents/MacOS/ProVoc"), version $(defaults read "$APP/Contents/Info" CFBundleShortVersionString))"
# (NSWorkspace looks the application up without launching it; AppleScript's "path to application" launches it)
OPENS=$(osascript -l JavaScript -e "ObjC.import('AppKit'); var u = \$.NSWorkspace.sharedWorkspace.URLForApplicationWithBundleIdentifier('ch.arizona-software.provoc'); u.isNil() ? 'none' : u.path.js")
echo "ProVoc opens: $OPENS"
[ "$INSTALL_DIR" != /Applications ] || [ "$OPENS" = "$APP" ] || { echo "another copy of ProVoc still opens instead: archive or remove it"; exit 1; }
