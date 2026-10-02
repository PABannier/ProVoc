#!/bin/bash
# The whole verification of ProVoc, from a clean build to the report.
#
#   scripts/verify.sh
#
# 1. generates the Xcode project (XcodeGen) and builds the small tools of the tests;
# 2. clean-builds Release and Debug for arm64, keeps the warnings, checks with lipo that
#    every binary is arm64 only;
# 3. makes dist/ProVoc.app from the Release build, signs it, launches it as the Finder does;
# 4. runs the tests hosted in the application (ProVocTests) twice, back to back;
# 5. runs the scenarios of the stand-alone application (scripts/e2e.py) twice, back to back;
# 6. runs the osascript checks (AppleScript dictionary, dead keys typed by the system);
# 7. checks that the log scan really fails on an exception, and scans the logs;
# 8. writes verification/report.md, with a verdict for each line of FEATURES.md.
#
# verification/LAST_RUN_PASSED is touched only if everything passed; it is removed first.
#
# The tests type and click in the application: the screen must be unlocked and the Mac
# left alone meanwhile (about half an hour). In a fresh checkout the copies of the real
# decks are missing (fixtures/user-decks is not in git): PV_USER_DECKS=<folder> copies them.

cd "$(dirname "$0")/.." || exit 1
ROOT=$PWD
V=verification
DD=build/DerivedData
PRODUCTS=$DD/Build/Products
rm -f $V/LAST_RUN_PASSED
rm -rf $V/logs $V/results
mkdir -p $V/logs $V/results $V/screenshots build
FAILED=0

say() { echo; echo "== $1"; }
record() {    # record PASS|FAIL id [detail]
	echo "$1 $2" >> $V/results/verify.txt
	echo "$1 $2${3:+: $3}"
	[ "$1" = PASS ] || FAILED=1
}
check() {     # check id command...: PASS if the command succeeds
	local id=$1; shift
	if "$@" >> $V/logs/verify-steps.log 2>&1; then record PASS "$id"; else record FAIL "$id" "see $V/logs/verify-steps.log"; fi
}

# the display must stay awake, and no "quit unexpectedly" dialog may take the keyboard
caffeinate -d -i -u -w $$ &
OLD_DIALOG=$(defaults read com.apple.CrashReporter DialogType 2>/dev/null)
defaults write com.apple.CrashReporter DialogType none
ACTIVATOR=
finish() {
	[ -n "$ACTIVATOR" ] && kill $ACTIVATOR 2>/dev/null
	if [ -n "$OLD_DIALOG" ]; then defaults write com.apple.CrashReporter DialogType "$OLD_DIALOG"; else defaults delete com.apple.CrashReporter DialogType 2>/dev/null; fi
}
trap finish EXIT

if ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes'; then
	record FAIL verify/screen-unlocked "THE SCREEN IS LOCKED: the tests that type and click cannot run (see $V/NEEDS_HUMAN.md)"
else
	record PASS verify/screen-unlocked
fi

if [ -n "$PV_USER_DECKS" ] && [ ! -d fixtures/user-decks ]; then
	mkdir -p fixtures/user-decks && cp -R "$PV_USER_DECKS"/. fixtures/user-decks/
fi

say "Project and tools"
check verify/project xcodegen generate
check verify/tools sh -c "clang -framework Cocoa scripts/activate-test-host.m -o build/activate-test-host && clang -fobjc-arc -framework Foundation -framework Carbon scripts/keyboard-layout.m -o build/keyboard-layout"

say "Clean builds (arm64)"
build() {     # build Configuration action...
	local config=$1; shift
	xcodebuild -project ProVoc.xcodeproj -scheme ProVoc -configuration $config -derivedDataPath $DD ARCHS=arm64 ONLY_ACTIVE_ARCH=NO "$@" > $V/logs/build-$config.log 2>&1
	local status=$?
	grep -E "warning: " $V/logs/build-$config.log | sed -E "s#$ROOT/##" | sort -u > $V/results/warnings-$config.txt
	echo "$config: $(grep -c . $V/results/warnings-$config.txt) different warnings (in $V/results/warnings-$config.txt)"
	return $status
}
check verify/build-release build Release clean build
check verify/build-debug build Debug clean build-for-testing

# Every Mach-O file of an application is arm64, and nothing else. (Contents/Frameworks is
# left out: ProVoc has none; in the Debug build that hosts the tests, Xcode puts its own
# universal XCTest frameworks there. The application made for dist/ must not have it.)
arm64_only() {
	local bad=0 file
	while IFS= read -r file; do
		if file -b "$file" | grep -q "Mach-O"; then
			[ "$(lipo -archs "$file")" = "arm64" ] || { echo "$file: $(lipo -archs "$file")"; bad=1; }
		fi
	done < <(find "$1" -type f ! -path "*/Contents/Frameworks/*")
	[ "$(lipo -archs "$1/Contents/MacOS/ProVoc")" = "arm64" ] || bad=1
	return $bad
}
check verify/arm64-only-release arm64_only $PRODUCTS/Release/ProVoc.app
check verify/arm64-only-debug arm64_only $PRODUCTS/Debug/ProVoc.app
echo "lipo -archs: $(lipo -archs $PRODUCTS/Release/ProVoc.app/Contents/MacOS/ProVoc) (Release), $(lipo -archs $PRODUCTS/Debug/ProVoc.app/Contents/MacOS/ProVoc) (Debug)" | tee $V/results/lipo.txt

say "dist/ProVoc.app"
make_dist() {
	rm -rf dist && mkdir dist && cp -R $PRODUCTS/Release/ProVoc.app dist/ProVoc.app || return 1
	codesign --force --deep -s - dist/ProVoc.app || return 1
	codesign --verify --deep --strict dist/ProVoc.app || return 1
	arm64_only dist/ProVoc.app || return 1
	[ ! -e dist/ProVoc.app/Contents/Frameworks ] || { echo "dist/ProVoc.app has embedded frameworks"; return 1; }
	# the importer of 2008 (PowerPC / i386) is not shipped; the new one is
	[ ! -e dist/ProVoc.app/Contents/Resources/ProVoc.mdimporter ] && [ -d dist/ProVoc.app/Contents/Library/Spotlight/ProVoc.mdimporter ]
}
check verify/dist-signed make_dist
# launched as the Finder does (LaunchServices); it must come up with a window, and quit when asked
launch_dist() {
	local app="$ROOT/dist/ProVoc.app" binary="$ROOT/dist/ProVoc.app/Contents/MacOS/ProVoc" i windows=0
	pkill -f "$binary"
	open -n "$app" --args -ApplePersistenceIgnoreState YES || return 1
	for i in $(seq 1 40); do pgrep -f "$binary" > /dev/null && break; sleep 0.25; done
	for i in $(seq 1 40); do
		windows=$(perl -e 'alarm 20; exec @ARGV' osascript -e "tell application \"$app\" to count windows" 2>/dev/null)
		[ "${windows:-0}" -ge 1 ] 2>/dev/null && break
		sleep 0.25
	done
	echo "windows of dist/ProVoc.app: $windows"
	pgrep -f "$binary" > /dev/null || { echo "dist/ProVoc.app is not running"; return 1; }
	perl -e 'alarm 20; exec @ARGV' osascript -e "tell application \"$app\" to quit" 2>/dev/null
	for i in $(seq 1 40); do pgrep -f "$binary" > /dev/null || break; sleep 0.25; done
	if pgrep -f "$binary" > /dev/null; then pkill -f "$binary"; echo "dist/ProVoc.app did not quit"; return 1; fi
	[ "${windows:-0}" -ge 1 ]
}
check verify/dist-launches launch_dist

# "PASS id" / "FAIL id" for each test of a log of xcodebuild
hosted_results() {
	sed -nE "s/^Test Case '-\[([A-Za-z0-9_]+) ([A-Za-z0-9_]+)\]' (passed|failed).*/\3 ProVocTests\/\1\/\2/p" "$1" | sed -e 's/^passed/PASS/' -e 's/^failed/FAIL/' | awk '{ last[$2] = $1 } END { for (id in last) print last[id], id }' | sort -k2
}
run_hosted() {    # run_hosted N
	say "Tests hosted in the application, run $1"
	pkill -f "$ROOT/$PRODUCTS/Debug/ProVoc.app/Contents/MacOS/ProVoc"
	build/activate-test-host "$ROOT/$PRODUCTS/Debug/ProVoc.app/Contents/MacOS/ProVoc" & ACTIVATOR=$!
	xcodebuild -project ProVoc.xcodeproj -scheme ProVoc -configuration Debug -derivedDataPath $DD ARCHS=arm64 ONLY_ACTIVE_ARCH=NO test-without-building -only-testing:ProVocTests > $V/logs/hosted-run$1.log 2>&1
	local status=$?
	kill $ACTIVATOR 2>/dev/null; ACTIVATOR=
	hosted_results $V/logs/hosted-run$1.log > $V/results/hosted-run$1.txt
	local passed=$(grep -c "^PASS" $V/results/hosted-run$1.txt) failed=$(grep -c "^FAIL" $V/results/hosted-run$1.txt)
	echo "run $1: $passed passed, $failed failed (xcodebuild status $status)"
	grep "^FAIL" $V/results/hosted-run$1.txt
	if [ $status -eq 0 ] && [ "$failed" -eq 0 ] && [ "$passed" -gt 100 ]; then record PASS verify/hosted-run$1; else record FAIL verify/hosted-run$1 "$failed failed, $passed passed, see $V/logs/hosted-run$1.log"; fi
}
run_e2e() {       # run_e2e N
	say "Scenarios of the stand-alone application, run $1"
	python3 scripts/e2e.py --logs $V/logs/e2e-run$1 > $V/logs/e2e-run$1.log 2>&1
	local status=$?
	sed -nE "s/^(PASS|FAIL) ([a-z0-9-]+) \(.*/\1 e2e\/\2/p" $V/logs/e2e-run$1.log > $V/results/e2e-run$1.txt
	cat $V/logs/e2e-run$1.log | cut -c1-300
	if [ $status -eq 0 ] && [ "$(grep -c "^PASS" $V/results/e2e-run$1.txt)" -gt 15 ]; then record PASS verify/e2e-run$1; else record FAIL verify/e2e-run$1 "see $V/logs/e2e-run$1.log"; fi
}
run_hosted 1
run_hosted 2
run_e2e 1
run_e2e 2

say "osascript checks"
script_check() {  # script_check name
	scripts/$1 > $V/logs/$1.log 2>&1
	local status=$?
	tail -3 $V/logs/$1.log
	if [ $status -eq 0 ]; then echo "PASS scripts/$1" >> $V/results/scripts.txt; record PASS verify/$1; else echo "FAIL scripts/$1" >> $V/results/scripts.txt; record FAIL verify/$1 "$(tail -1 $V/logs/$1.log | cut -c1-300)"; fi
}
script_check applescript-check.sh
script_check deadkey-check.sh

say "Logs"
# the scan must fail when the application logs an exception: one is raised on purpose
python3 scripts/e2e.py --self-test-exception --logs $V/logs/self-test > $V/logs/self-test.log 2>&1
if [ $? -ne 0 ] && grep -q "log: .*\*\*\* Exception: PVSelfTestException" $V/logs/self-test.log; then record PASS verify/log-scan-self-test; else record FAIL verify/log-scan-self-test "an exception raised on purpose was not caught by the log scan"; fi
# (the logs of the scenarios were scanned by scripts/e2e.py; here, what the application wrote during the hosted tests: scripts/scan-log.py)
for run in 1 2; do
	python3 scripts/scan-log.py $V/logs/hosted-run$run.log > $V/results/log-scan-hosted-run$run.txt 2>&1
	if [ $? -eq 0 ]; then record PASS verify/log-scan-hosted-run$run; else record FAIL verify/log-scan-hosted-run$run "$(grep -c . $V/results/log-scan-hosted-run$run.txt) forbidden lines, see $V/results/log-scan-hosted-run$run.txt"; fi
done

say "Report"
python3 scripts/report.py > $V/logs/report.log 2>&1
if [ $? -eq 0 ]; then record PASS verify/features; else record FAIL verify/features "$(tail -1 $V/logs/report.log)"; fi
tail -12 $V/logs/report.log

echo
if [ $FAILED -eq 0 ]; then
	touch $V/LAST_RUN_PASSED
	echo "VERIFIED: everything passed ($V/report.md)"
else
	echo "NOT VERIFIED: $(grep -c "^FAIL" $V/results/verify.txt) step(s) failed ($V/report.md):"
	grep "^FAIL" $V/results/verify.txt
	exit 1
fi
