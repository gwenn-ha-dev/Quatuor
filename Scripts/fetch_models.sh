#!/usr/bin/env bash
# Pré-télécharge les poids htdemucs_ft (fp16 safetensors) dans Models/.
# Optionnel : demucs-mlx-swift auto-télécharge au premier usage.
# Utile si tu veux bundler les poids dans l'app ou éviter le DL au runtime.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/Models/htdemucs_ft"
REPO="mlx-community/demucs-mlx-fp16"
BASE="https://huggingface.co/${REPO}/resolve/main"

mkdir -p "$OUT_DIR"

fetch() {
  local name="$1"
  local dest="$OUT_DIR/$name"
  if [[ -f "$dest" ]]; then
    echo "[fetch_models] $name déjà présent — skip"
    return
  fi
  echo "[fetch_models] téléchargement $name"
  curl -fL --retry 3 --progress-bar -o "$dest" "$BASE/$name"
}

fetch "htdemucs_ft.safetensors"
fetch "htdemucs_ft_config.json"

echo "[fetch_models] ✅ poids prêts dans $OUT_DIR"
echo "    DemucsSeparator les utilisera via DEMUCS_MLX_SWIFT_MODEL_DIR=$ROOT/Models"
