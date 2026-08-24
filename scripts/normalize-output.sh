#!/usr/bin/env bash
# normalize-output.sh — Normalize output for determinism comparison
# Usage: bash scripts/normalize-output.sh <build-dir> <output-manifest>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${1:-}"
OUTPUT_MANIFEST="${2:-}"

if [ -z "$BUILD_DIR" ] || [ -z "$OUTPUT_MANIFEST" ]; then
    echo "Usage: $0 <build-dir> <output-manifest>" >&2
    exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Build directory not found: $BUILD_DIR" >&2
    exit 1
fi

python3 "$REPO_ROOT/tools/normalize.py" \
    --input-dir "$BUILD_DIR" \
    --output "$OUTPUT_MANIFEST"

echo "Normalized manifest written to: $OUTPUT_MANIFEST"
