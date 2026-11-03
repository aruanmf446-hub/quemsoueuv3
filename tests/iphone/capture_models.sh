#!/usr/bin/env bash
# Captura todas as telas em todos os tamanhos de iPhone. Uso: capture_models.sh <pasta> [rotas]
set -e
OUT="$1"; ONLY="${2:-}"; G="${GODOT:-godot}"
cd "$(dirname "$0")/../.."
grep -v '^#' tests/iphone/models.txt | awk 'NF{print $1, $NF}' | while read -r name size; do
  mkdir -p "$OUT/$name"
  xvfb-run -a "$G" --path . --script res://tests/iphone/capture_iphone.gd -- "$OUT/$name" "$size" $ONLY --iphone 2>&1 | grep -c CAPTURED | sed "s/^/$name $size capturas: /"
done
