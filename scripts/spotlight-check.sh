#!/bin/bash
# Asks Spotlight itself about a deck, where the tests load the importer directly:
# copies a deck where Spotlight indexes, has it imported, then reads its type and its
# attributes back from the index (mdls) and finds it again with queries (mdfind).
#
# usage: scripts/spotlight-check.sh [path of ProVoc.app]   (default: the Debug build)
#
# The deck is copied into the home folder, because /tmp is not indexed. Spotlight must
# know the importer of this application: it does once the application has been launched
# (running the tests is enough), and `mdimport -L` lists it.
cd "$(dirname "$0")/.."
APP="${1:-$PWD/build/DerivedData/Build/Products/Debug/ProVoc.app}"
IMPORTER="$APP/Contents/Library/Spotlight/ProVoc.mdimporter"
TYPE="ch.arizona-software.provoc.vocabulary"
WORK=$(mktemp -d "$HOME/provoc-spotlight-XXXXXX")
DECK="$WORK/Indexed.pvoc"
fail() { echo "FAIL: $1"; rm -rf "$WORK"; exit 1; }
attribute() { mdls -raw -name "$1" "$DECK" 2>/dev/null; }

[ -d "$IMPORTER" ] || fail "no importer in $APP"
mdimport -L 2>&1 | grep -qF "$IMPORTER" || fail "Spotlight does not list $IMPORTER (launch the application once, then see mdimport -L)"
echo "ok: Spotlight lists the importer of this application"

cp -R "fixtures/generated/Plain.pvoc" "$DECK"

# a test import says which plug-in Spotlight chooses for the deck, without indexing it
OUT=$(mdimport -t -d1 "$DECK" 2>&1)
echo "$OUT" | grep -qF "$TYPE" || fail "the deck is not of type $TYPE: $OUT"
echo "$OUT" | grep -qF "$IMPORTER" || fail "the deck is imported with another plug-in: $OUT"
echo "ok: the deck is imported as $TYPE with this importer"

# the real import; the index is not written at once: wait for it, 30 s at most
mdimport "$DECK"
for i in $(seq 1 60); do [ "$(attribute kMDItemContentType)" = "$TYPE" ] && break; sleep 0.5; done
OUT=$(attribute kMDItemContentType)
[ "$OUT" = "$TYPE" ] || fail "the index has the deck under the type \"$OUT\""
for i in $(seq 1 60); do [ "$(attribute ch_arizonasoftware_provoc_numberofwords)" = "5" ] && break; sleep 0.5; done
OUT=$(attribute ch_arizonasoftware_provoc_numberofwords)
[ "$OUT" = "5" ] || fail "the index has \"$OUT\" words for the deck, not 5"
OUT=$(attribute ch_arizonasoftware_provoc_languages)
echo "$OUT" | grep -q "English" || fail "the index has no languages for the deck: $OUT"
echo "ok: the index has the type, the number of words and the languages"

OUT=$(mdfind -onlyin "$WORK" "kMDItemContentType == '$TYPE'")
echo "$OUT" | grep -qF "Indexed.pvoc" || fail "a query on the type does not find the deck: $OUT"
OUT=$(mdfind -onlyin "$WORK" "ch_arizonasoftware_provoc_numberofwords == 5")
echo "$OUT" | grep -qF "Indexed.pvoc" || fail "a query on the number of words does not find the deck: $OUT"
echo "ok: queries on the type and on the number of words find the deck"

rm -rf "$WORK"
echo "PASS"
