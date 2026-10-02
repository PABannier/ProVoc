#!/bin/bash
# Drives ProVoc from outside with osascript, through its AppleScript dictionary:
# opens a deck, reads its words, imports text, starts a test.
#
# usage: scripts/applescript-check.sh [path of ProVoc.app]   (default: the Debug build)
#
# macOS asks once whether the terminal may control ProVoc ("Automation"); until
# someone allows it, every command fails with error -1743 and so does this script.
cd "$(dirname "$0")/.."
APP="${1:-$PWD/build/DerivedData/Build/Products/Debug/ProVoc.app}"
WORK=$(mktemp -d /tmp/provoc-applescript-XXXXXX)
cp -R "fixtures/generated/Plain.pvoc" "$WORK/Scripted.pvoc"
fail() { echo "FAIL: $1"; pkill -f "$APP/Contents/MacOS/ProVoc"; rm -rf "$WORK"; exit 1; }
# an answer is waited for 30 s at most (osascript would wait for the permission dialog)
script() { perl -e 'alarm 30; exec @ARGV' osascript "$@" 2>&1; }

pkill -f "$APP/Contents/MacOS/ProVoc"
open -n -a "$APP" --args -ApplePersistenceIgnoreState YES -PVResetDefaults YES || fail "cannot launch $APP"
for i in $(seq 1 50); do pgrep -f "$APP/Contents/MacOS/ProVoc" > /dev/null && break; sleep 0.2; done

OUT=$(script -e "tell application \"$APP\" to open POSIX file \"$WORK/Scripted.pvoc\"")
case "$OUT" in *-1743*|*"Not authorized"*|*"Alarm clock"*) fail "the terminal is not allowed to control ProVoc (System Settings > Privacy & Security > Automation): $OUT";; esac
OUT=$(script -e "tell application \"$APP\" to get name of front document")
[ "$OUT" = "Scripted" ] || [ "$OUT" = "Scripted.pvoc" ] || fail "open: the front document is \"$OUT\""
echo "ok: open a deck ($OUT)"

OUT=$(script -e "tell application \"$APP\" to export \"\"")
echo "$OUT" | grep -q "house" && echo "$OUT" | grep -q "maison" && echo "$OUT" | grep -q "pain" || fail "export: the words are not returned: $OUT"
echo "ok: read the words ($(echo "$OUT" | grep -c .) lines)"

OUT=$(script -e "tell application \"$APP\" to export \"$WORK/exported.txt\" with include names")
# (with the "Default" text encoding of a document the file is written in Mac OS Roman, as it always was)
grep -q "# Lesson 1" "$WORK/exported.txt" 2>/dev/null && iconv -f MACINTOSH -t UTF-8 "$WORK/exported.txt" | grep -q "été" || fail "export to a file with lesson names: $(cat "$WORK/exported.txt" 2>&1 | head -3)"
echo "ok: export to a file with lesson names"

script -e "tell application \"$APP\" to import text \"sun	soleil
moon	lune\"" > /dev/null
OUT=$(script -e "tell application \"$APP\" to export \"\"")
echo "$OUT" | grep -q "soleil" && echo "$OUT" | grep -q "moon" || fail "import text: the words were not added: $OUT"
echo "ok: import text"

BEFORE=$(script -e "tell application \"$APP\" to count windows")
script -e "tell application \"$APP\" to start test" > /dev/null
sleep 2
AFTER=$(script -e "tell application \"$APP\" to count windows")
[ "$AFTER" -gt "$BEFORE" ] 2>/dev/null || fail "start test: no test panel appeared (windows: $BEFORE before, $AFTER after)"
echo "ok: start a test (windows: $BEFORE -> $AFTER)"

pkill -f "$APP/Contents/MacOS/ProVoc"
rm -rf "$WORK"
echo "PASS"
