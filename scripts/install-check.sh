#!/bin/bash
# scripts/install.sh, into folders of its own (nothing in /Applications or in
# ~/ProVoc backups/ is touched): a second install must archive the first copy as a zip,
# as well as a .app left in the backups folder by an earlier version of the installer,
# leave no .app there, and Launch Services must have forgotten the archived copies, so
# that only the installed ProVoc can open.
set -eu
cd "$(dirname "$0")/.."
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
T=$(mktemp -d "$PWD/build/install-check.XXXXXX")
export PROVOC_INSTALL_DIR="$T/Applications" PROVOC_BACKUP_DIR="$T/ProVoc backups"
trap '"$LSREGISTER" -u "$PROVOC_INSTALL_DIR/ProVoc.app" > /dev/null 2>&1 || true; rm -rf "$T"' EXIT
mkdir -p "$PROVOC_INSTALL_DIR" "$PROVOC_BACKUP_DIR"
cp -R dist/ProVoc.app "$PROVOC_BACKUP_DIR/ProVoc 2000-01-01-000000.app"	# left by an earlier installer
"$LSREGISTER" -f "$PROVOC_BACKUP_DIR/ProVoc 2000-01-01-000000.app"
scripts/install.sh
scripts/install.sh
echo "backups: $(ls "$PROVOC_BACKUP_DIR" | tr '\n' ' ')"
[ "$(ls "$PROVOC_BACKUP_DIR" | grep -c '\.zip$')" = 2 ]
! ls "$PROVOC_BACKUP_DIR" | grep -q '\.app$'
for ZIP in "$PROVOC_BACKUP_DIR"/*.zip; do unzip -l "$ZIP" | grep -q '\.app/Contents/MacOS/ProVoc$'; done
! "$LSREGISTER" -dump | grep -q -F "$PROVOC_BACKUP_DIR"
[ -x "$PROVOC_INSTALL_DIR/ProVoc.app/Contents/MacOS/ProVoc" ]
echo "PASS: the previous copies are archived and forgotten by Launch Services"
