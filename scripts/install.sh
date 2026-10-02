#!/bin/bash
# Copies dist/ProVoc.app (made by scripts/verify.sh) to /Applications. A copy that is
# already there is moved to ~/ProVoc backups/ first, never deleted.
cd "$(dirname "$0")/.." || exit 1
[ -d dist/ProVoc.app ] || { echo "no dist/ProVoc.app: run scripts/verify.sh first"; exit 1; }
codesign --verify --deep --strict dist/ProVoc.app || { echo "dist/ProVoc.app is not properly signed"; exit 1; }
if pgrep -f "/Applications/ProVoc.app/Contents/MacOS/ProVoc" > /dev/null; then echo "ProVoc is running: quit it first"; exit 1; fi
if [ -e /Applications/ProVoc.app ]; then
	mkdir -p "$HOME/ProVoc backups"
	BACKUP="$HOME/ProVoc backups/ProVoc $(date +%Y-%m-%d-%H%M%S).app"
	mv /Applications/ProVoc.app "$BACKUP" || exit 1
	echo "the previous /Applications/ProVoc.app is now $BACKUP"
fi
cp -R dist/ProVoc.app /Applications/ProVoc.app || exit 1
codesign --verify --deep --strict /Applications/ProVoc.app || exit 1
# .pvoc documents open with this copy, and Spotlight finds its importer
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ProVoc.app
echo "installed: /Applications/ProVoc.app ($(lipo -archs /Applications/ProVoc.app/Contents/MacOS/ProVoc), version $(defaults read /Applications/ProVoc.app/Contents/Info CFBundleShortVersionString))"
