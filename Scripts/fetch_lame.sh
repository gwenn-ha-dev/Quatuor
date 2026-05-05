#!/usr/bin/env bash
# Télécharge les sources LAME 3.100 dans ThirdParty/lame-src/.
# Aucune install système — tout reste local au repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/ThirdParty/lame-src"
VERSION="3.100"
TARBALL="lame-${VERSION}.tar.gz"
URL="https://downloads.sourceforge.net/project/lame/lame/${VERSION}/${TARBALL}"
SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"

mkdir -p "$ROOT/ThirdParty"

if [[ -d "$SRC_DIR" ]]; then
  echo "[fetch_lame] sources déjà présentes dans $SRC_DIR — skip"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[fetch_lame] téléchargement $URL"
curl -fL --retry 3 -o "$TMP/$TARBALL" "$URL"

echo "[fetch_lame] vérification SHA-256"
ACTUAL=$(shasum -a 256 "$TMP/$TARBALL" | awk '{print $1}')
if [[ "$ACTUAL" != "$SHA256" ]]; then
  echo "[fetch_lame] ❌ SHA mismatch — attendu $SHA256, obtenu $ACTUAL" >&2
  exit 1
fi

echo "[fetch_lame] extraction"
tar -xzf "$TMP/$TARBALL" -C "$TMP"
mv "$TMP/lame-${VERSION}" "$SRC_DIR"

echo "[fetch_lame] ✅ sources prêtes dans $SRC_DIR"
echo "    → lance ./Scripts/build_lame.sh pour compiler la static lib"
