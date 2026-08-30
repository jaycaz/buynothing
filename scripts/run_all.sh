#!/usr/bin/env bash
# run_all.sh — run every cutout strategy on a photo + build the comparison grid.
#   ./run_all.sh /path/to/photo.png [outDir]
set -euo pipefail
cd "$(dirname "$0")/.."
PHOTO="${1:?usage: run_all.sh <photo> [outDir]}"
OUT="${2:-out/seg}"
ROOT="$(pwd)"
mkdir -p "$OUT"

echo "==> Swift: vision / handpose / skincolor"
( cd tools/segsuite
  if [ ! -x ./segsuite ]; then
    swiftc -O -o segsuite main.swift \
      ../../Pipeline/Sources/CollagePipeline/ForegroundSegmenter.swift \
      ../../Pipeline/Sources/CollagePipeline/ImageGeometry.swift
  fi
  ./segsuite "$PHOTO" "$OUT"
)

echo "==> Python: sam_auto"
python3 scripts/sam_auto.py "$PHOTO" --out "$OUT" --region "$OUT/s1_mask.png" || true

echo "==> Python: composite (best)"
python3 scripts/composite.py "$PHOTO" --out "$OUT" --region "$OUT/s1_mask.png" || true

echo "==> Montage"
python3 scripts/montage.py "$OUT"
echo "DONE -> $OUT/MONTAGE.png"
