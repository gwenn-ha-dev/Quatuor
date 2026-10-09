#!/bin/bash
# README captures — CHARTE.md §12. `make shots` delegates here.
#
# The song is "Happy Happy HardPopCoreTastic" by Mesostic, dedicated to the public
# domain (CC0 1.0) on Wikimedia Commons:
#   https://commons.wikimedia.org/wiki/File:Happy_Happy_HardPopCoreTastic.ogg
# It is downloaded once into build/captures/, checked against its hash, and
# converted to AAC: never commit it, and never swap in a song under copyright.
#
# Nothing can click in the app (no Accessibility), so each view is reached at
# launch: the file is handed over with `open -a`, and the
# launch key `-open.separate YES` starts the separation without the button.
# The model (~670 MB) is downloaded on the first separation, then cached.
set -euo pipefail
cd "$(dirname "$0")/.."
capturer=${CHARTE:-../../Charte}/outils/capturer.sh
app=$PWD/build/Quatuor.app
[ -d "$app" ] || { echo "captures: build the app first (make package)" >&2; exit 1; }

dir=build/captures
ogg=$dir/happy.ogg
song="$PWD/$dir/Happy Happy HardPopCoreTastic.m4a"
sum=dba924608bc3e299880f88f2c1739d5331c0dafec30a30f4859d1926a86f53d3
if [ ! -f "$song" ]; then
  mkdir -p "$dir"
  curl -fsSL -A "Quatuor-captures" -o "$ogg" \
    "https://upload.wikimedia.org/wikipedia/commons/6/61/Happy_Happy_HardPopCoreTastic.ogg"
  [ "$(shasum -a 256 "$ogg" | cut -d' ' -f1)" = "$sum" ] \
    || { echo "captures: the downloaded song is not the expected one" >&2; exit 1; }
  afconvert -f m4af -d aac -b 256000 "$ogg" "$song"
fi

# The stems are written to the app's temporary directory, in its container.
stems=$HOME/Library/Containers/dev.gwennha.Quatuor/Data/tmp

# The window opens at its default size (900 × 680 points, all four stems in view)
# unless a previous session saved another: pass the saved key back, resized.
prefs=$HOME/Library/Containers/dev.gwennha.Quatuor/Data/Library/Preferences/dev.gwennha.Quatuor.plist
frame=()
if [ -f "$prefs" ]; then
  while IFS=$'\t' read -r key value; do
    frame+=(-"$key" "$value")
  done < <(plutil -convert json -o - "$prefs" | python3 -I -c '
import json, sys
for k, v in json.load(sys.stdin).items():
    if k.startswith("NSWindow Frame "):
        f = v.split()
        f[2:4] = ["900", "680"]
        print(k + "\t" + " ".join(f))')
fi

quit() { pkill -x Quatuor 2>/dev/null || true; sleep 1; }

launch() {  # launch <language> [file] [-open.separate YES]
  local lang=$1; shift
  local locale; locale=$( [ "$lang" = en ] && echo en_GB || echo fr_FR )
  quit
  if [ $# -gt 0 ]; then
    local file=$1; shift
    open -n -a "$app" "$file" --args -AppleLanguages "($lang)" -AppleLocale "$locale" -ApplePersistenceIgnoreState YES ${frame[@]+"${frame[@]}"} "$@"
  else
    open -n -a "$app" --args -AppleLanguages "($lang)" -AppleLocale "$locale" -ApplePersistenceIgnoreState YES ${frame[@]+"${frame[@]}"}
  fi
}

for lang in en fr; do
  suffix=$( [ "$lang" = en ] && echo "" || echo ".fr" )

  launch "$lang"
  sleep 3
  "$capturer" Quatuor "docs/img/drop$suffix.png"

  launch "$lang" "$song" -open.separate NO
  sleep 5
  "$capturer" Quatuor "docs/img/loaded$suffix.png"

  marker=$(mktemp "${TMPDIR:-/tmp}/quatuor-captures.XXXXXX")
  launch "$lang" "$song" -open.separate YES
  sleep 20
  "$capturer" Quatuor "docs/img/separating$suffix.png"
  # Done when the four stems of this run are written; then let the view settle.
  for _ in $(seq 1 60); do
    n=$(find "$stems" -name '*.wav' -newer "$marker" 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -ge 4 ] && break
    sleep 5
  done
  rm -f "$marker"
  sleep 4
  "$capturer" Quatuor "docs/img/stems$suffix.png"
done
quit
