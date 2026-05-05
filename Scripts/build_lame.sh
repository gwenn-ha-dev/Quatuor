#!/usr/bin/env bash
# Compile libmp3lame en static lib pour arm64 (Apple Silicon).
# Output: ThirdParty/lame/{include,lib}/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/ThirdParty/lame-src"
OUT_DIR="$ROOT/ThirdParty/lame"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "[build_lame] ❌ sources absentes — lance ./Scripts/fetch_lame.sh d'abord" >&2
  exit 1
fi

if [[ -f "$OUT_DIR/lib/libmp3lame.a" ]]; then
  echo "[build_lame] static lib déjà compilée dans $OUT_DIR — skip"
  exit 0
fi

cd "$SRC_DIR"

echo "[build_lame] configure (arm64, static, sans frontend ni decoder)"
# Patch pour macOS 14+ : LAME 3.100 a un test obsolète sur xmmintrin.h
# qui peut casser. CFLAGS forcent arm64, désactivent les optims x86.
make distclean >/dev/null 2>&1 || true
./configure \
  --prefix="$OUT_DIR" \
  --host=aarch64-apple-darwin \
  --disable-shared \
  --enable-static \
  --disable-frontend \
  --disable-decoder \
  --disable-analyzer-hooks \
  --disable-gtktest \
  CFLAGS="-O3 -arch arm64 -mmacosx-version-min=14.0" \
  LDFLAGS="-arch arm64"

echo "[build_lame] make -j$(sysctl -n hw.ncpu)"
make -j"$(sysctl -n hw.ncpu)"

echo "[build_lame] make install (vers $OUT_DIR)"
make install

echo "[build_lame] ✅ libmp3lame.a + headers dans $OUT_DIR"
ls -la "$OUT_DIR/lib/libmp3lame.a" "$OUT_DIR/include/lame/lame.h"
