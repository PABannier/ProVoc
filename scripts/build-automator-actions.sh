#!/bin/bash
# Build phase of the application: makes the three Automator actions of ProVoc
# (Actions/Resources) in Contents/Library/Automator, as the project of 2008 did.
# An AppleScript action is a bundle without code: its Info.plist, its script compiled
# to main.scpt, and the nib of its settings in each language.
set -e
APP="$TARGET_BUILD_DIR/$WRAPPER_NAME"
for SOURCE in "$SRCROOT"/Actions/Resources/*Action; do
	NAME=$(/usr/libexec/PlistBuddy -c "Print :AMName" "$SOURCE/Info.plist")
	ACTION="$APP/Contents/Library/Automator/$NAME.action/Contents"
	# (an action that is up to date is left alone: the application is signed after this phase,
	# and nothing tells Xcode to sign it again when only these files change)
	if [ -f "$ACTION/Resources/main.scpt" ] && [ -z "$(find "$SOURCE" "$0" -newer "$ACTION/Resources/main.scpt" -type f ! -name .DS_Store | head -1)" ]; then
		continue
	fi
	rm -rf "$APP/Contents/Library/Automator/$NAME.action"
	mkdir -p "$ACTION/Resources"
	cp "$SOURCE/Info.plist" "$ACTION/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $NAME" -c "Set :AMRequiredResources:0:Resource $PRODUCT_BUNDLE_IDENTIFIER" "$ACTION/Info.plist"
	# (the application by the identifier of this build: the Debug build has its own)
	sed "s/set theApplication to \"ch.arizona-software.provoc\"/set theApplication to \"$PRODUCT_BUNDLE_IDENTIFIER\"/" "$SOURCE/main.applescript" > "$DERIVED_FILE_DIR/$NAME.applescript"
	grep -q "set theApplication to \"$PRODUCT_BUNDLE_IDENTIFIER\"" "$DERIVED_FILE_DIR/$NAME.applescript"
	/usr/bin/osacompile -o "$ACTION/Resources/main.scpt" "$DERIVED_FILE_DIR/$NAME.applescript"
	for LPROJ in "$SOURCE"/*.lproj; do
		rsync -a --exclude .DS_Store --exclude classes.nib --exclude info.nib --exclude data.dependency "$LPROJ" "$ACTION/Resources/"
	done
	# a bundle in Contents/Library is code for the signature of the application: it must be signed itself
	/usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --timestamp=none "$APP/Contents/Library/Automator/$NAME.action"
done
