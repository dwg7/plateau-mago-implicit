#!/usr/bin/env bash
# generate-manifest.sh — Generate a build manifest
# Usage: bash scripts/generate-manifest.sh <dataset> <mode> <profile>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-}"
MODE="${2:-implicit}"
PROFILE="${3:-small}"

if [ -z "$DATASET" ]; then
    echo "Usage: $0 <dataset> <mode> <profile>" >&2
    exit 1
fi

OUTPUT_BASE="$REPO_ROOT/data/output/${DATASET}/${MODE}/${PROFILE}"
MANIFEST_DIR="$REPO_ROOT/manifests/builds"

LATEST_BUILD="$(find "$OUTPUT_BASE" -maxdepth 1 -type d | sort | tail -1)"
if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" = "$OUTPUT_BASE" ]; then
    echo "ERROR: No build found at $OUTPUT_BASE" >&2
    exit 1
fi

BUILD_ID="$(basename "$LATEST_BUILD")"
MANIFEST_FILE="$MANIFEST_DIR/${BUILD_ID}.yml"

echo "Manifest: $MANIFEST_FILE"

python3 "$REPO_ROOT/tools/summarize_metrics.py" \
    --build-dir "$LATEST_BUILD" \
    --manifest "$MANIFEST_FILE"
