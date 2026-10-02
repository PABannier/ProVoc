#!/bin/bash
# Makes macOS ask whether ProVoc (the Debug build that the tests drive) may use the
# microphone and the camera. Someone has to click "Allow" in the two dialogs: nothing
# else can. Run once; the answers are remembered by macOS.
#
# The release application asks by itself the first time a sound, a picture or a movie
# is recorded.
cd "$(dirname "$0")/.."
python3 scripts/e2e.py --request-capture-access
