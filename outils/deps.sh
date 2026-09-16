#!/bin/bash
# libmp3lame is a third-party static library: built from source, never committed.
# A fresh clone has no ThirdParty/lame, so build it once, here.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f ThirdParty/lame/include/lame/lame.h ]; then
    exit 0
fi

echo "› libmp3lame missing — fetching and building it (once)"
./Scripts/fetch_lame.sh
./Scripts/build_lame.sh
