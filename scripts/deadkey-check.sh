#!/bin/bash
# Answers a written test with dead keys typed by the system itself: osascript asks
# System Events to press real keys, on the French (AZERTY) layout and, when it is
# enabled, on the ABC / U.S. layout. The answers are typed ahead, without waiting
# between words: no key may be lost. The document is then saved (Command-S) and the
# file is read back: every word must have been answered right, never wrong.
#
# usage: scripts/deadkey-check.sh [path of ProVoc.app]   (default: the Debug build)
#
# macOS only lets a program press keys if it is listed in System Settings > Privacy &
# Security > Accessibility: the terminal (or the program) that runs this script must be
# allowed there, by hand. Until then the script fails and says so.
cd "$(dirname "$0")/.."
APP="${1:-$PWD/build/DerivedData/Build/Products/Debug/ProVoc.app}"
DECK="fixtures/generated/Dead keys.pvoc"
LAYOUT=build/keyboard-layout
mkdir -p build
[ -x $LAYOUT ] && [ $LAYOUT -nt scripts/keyboard-layout.m ] || clang -fobjc-arc -framework Foundation -framework Carbon scripts/keyboard-layout.m -o $LAYOUT || exit 1
script() { perl -e 'alarm 60; exec @ARGV' osascript "$@" 2>&1; }

OUT=$(script -e 'tell application "System Events" to key code 63')    # the fn key alone: types nothing
case "$OUT" in *1002*|*"not allowed"*|*-1743*|*"Alarm clock"*)
	echo "FAIL: this terminal is not allowed to press keys (System Settings > Privacy & Security > Accessibility; then Automation > System Events): $OUT"; exit 1;;
esac
$LAYOUT --list | grep -qx "com.apple.keylayout.French" || { echo "FAIL: the French (AZERTY) keyboard layout is not enabled (System Settings > Keyboard > Input Sources)"; exit 1; }

WORK=$(mktemp -d /tmp/provoc-deadkeys-XXXXXX)
cp -R "$DECK" "$WORK/Dead keys.pvoc"
USER_LAYOUT=$($LAYOUT)
finish() { $LAYOUT "$USER_LAYOUT"; pkill -f "$APP/Contents/MacOS/ProVoc"; rm -rf "$WORK"; }
trap finish EXIT
fail() { echo "FAIL: $1"; exit 1; }

# right and wrong answers of the three words in the saved document, e.g. "1/0 1/0 1/0"
counts() {
	python3 - "$WORK/Dead keys.pvoc/Data" <<'PY'
import plistlib, sys
objects = plistlib.load(open(sys.argv[1], 'rb'))['$objects']
words = [o for o in objects if isinstance(o, dict) and 'ProVocSourceWord' in o]
print(' '.join('%d/%d' % (w.get('ProVocRight', 0), w.get('ProVocWrong', 0)) for w in words))
PY
}

pkill -f "$APP/Contents/MacOS/ProVoc"
open -n -a "$APP" "$WORK/Dead keys.pvoc" --args -ApplePersistenceIgnoreState YES -PVResetDefaults YES || fail "cannot launch $APP"
for i in $(seq 1 60); do [ "$(script -e "tell application \"$APP\" to count documents")" = "1" ] && break; sleep 0.5; done
[ "$(script -e "tell application \"$APP\" to count documents")" = "1" ] || fail "the deck did not open"
[ "$(counts)" = "0/0 0/0 0/0" ] || fail "the deck is not new: $(counts)"

# One test of the three words (être, naïf, été), typed with the dead keys of a layout:
# $1 = layout, $2 = the AppleScript lines that type the three answers, $3 = expected counts
pass() {
	$LAYOUT "$1" || fail "cannot select the layout $1"
	BEFORE=$(script -e "tell application \"$APP\" to count windows")
	script -e "tell application \"$APP\" to activate" -e "tell application \"$APP\" to start test" > /dev/null
	for i in $(seq 1 40); do [ "$(script -e "tell application \"$APP\" to count windows")" -gt "$BEFORE" ] 2>/dev/null && break; sleep 0.25; done
	[ "$(script -e "tell application \"$APP\" to count windows")" -gt "$BEFORE" ] || fail "$1: the test did not start"
	MODIFIED=$(stat -f %m "$WORK/Dead keys.pvoc/Data")
	# the three answers (Return after each: a right answer goes straight to the next word),
	# Return on the result panel (Done), Command-S
	OUT=$(script -e "tell application \"System Events\"
$2
key code 36
keystroke \"s\" using command down
end tell")
	[ -z "$OUT" ] || fail "$1: System Events: $OUT"
	for i in $(seq 1 40); do [ "$(stat -f %m "$WORK/Dead keys.pvoc/Data")" != "$MODIFIED" ] && break; sleep 0.25; done
	[ "$(counts)" = "$3" ] || fail "$1: right/wrong answers of être, naïf, été are $(counts), expected $3 (a key was lost, or a dead key did not compose)"
	echo "ok: être, naïf, été typed with the dead keys of $1 ($(counts))"
}

# Only key codes (physical keys) are sent: what they type is decided by the layout of
# the application, as with a real keyboard. ("keystroke" would let System Events choose
# the keys with its own idea of the layout.)
#   key codes: e 14, t 17, r 15, n 45, i 34, f 3, u 32, Return 36;
#   the key of A is 12 on AZERTY and 0 on QWERTY.

# French (AZERTY): ^ is the key right of P (key code 33), ¨ the same key with Shift, é the key 2 (key code 19)
pass com.apple.keylayout.French 'key code 33
key code 14
key code 17
key code 15
key code 14
key code 36
key code 45
key code 12
key code 33 using shift down
key code 34
key code 3
key code 36
key code 19
key code 17
key code 19
key code 36' "1/0 1/0 1/0"

# ABC or U.S.: Option-I then e = ê, Option-U then i = ï, Option-E then e = é.
# (One second between two presses of Option: Option pressed twice in a row is a
# system-wide shortcut of some applications - the Claude desktop application opens its
# quick entry window, which then gets the keys.)
for OTHER in com.apple.keylayout.ABC com.apple.keylayout.US; do
	if $LAYOUT --list | grep -qx "$OTHER"; then
		pass $OTHER 'key code 34 using option down
key code 14
key code 17
key code 15
key code 14
key code 36
key code 45
key code 0
delay 1
key code 32 using option down
key code 34
key code 3
key code 36
delay 1
key code 14 using option down
key code 14
key code 17
delay 1
key code 14 using option down
key code 14
key code 36' "2/0 2/0 2/0"
		break
	fi
done
echo "PASS"
