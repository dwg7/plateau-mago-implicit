#!/usr/bin/env bash
# compare-builds.sh — Compare two most recent builds for determinism
# Usage: bash scripts/compare-builds.sh <dataset> <mode> <profile>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-}"
MODE="${2:-implicit}"
PROFILE="${3:-small}"

if [ -z "$DATASET" ]; then
    echo "Usage: $0 <dataset> <mode> <profile>" >&2
    exit 1
fi

if ! [[ "$DATASET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid dataset name: $DATASET" >&2
    echo "  Dataset must match ^[a-zA-Z0-9_-]+\$ (no slashes, spaces, or shell metacharacters)." >&2
    exit 1
fi

OUTPUT_BASE="$REPO_ROOT/data/output/${DATASET}/${MODE}/${PROFILE}"
NORM_DIR="$REPO_ROOT/manifests/normalized"
REPORT_DIR="$REPO_ROOT/manifests/reports"
mkdir -p "$NORM_DIR" "$REPORT_DIR"

# Find two most recent builds (exclude $OUTPUT_BASE itself)
mapfile -t BUILDS < <(find "$OUTPUT_BASE" -mindepth 1 -maxdepth 1 -type d | sort | tail -2)

if [ "${#BUILDS[@]}" -lt 2 ]; then
    echo "ERROR: Need at least two builds to compare." >&2
    echo "  Found: ${#BUILDS[@]} build(s) in $OUTPUT_BASE" >&2
    echo "  Run: make build DATASET=$DATASET MODE=$MODE PROFILE=$PROFILE (twice)" >&2
    exit 1
fi

BUILD1="${BUILDS[0]}"
BUILD2="${BUILDS[1]}"
BUILD1_ID="$(basename "$BUILD1")"
BUILD2_ID="$(basename "$BUILD2")"

echo "=== Comparing builds for $DATASET / $MODE / $PROFILE ==="
echo "  Build 1: $BUILD1_ID"
echo "  Build 2: $BUILD2_ID"
echo ""

# Normalize both builds
NORM1="$NORM_DIR/${BUILD1_ID}.json"
NORM2="$NORM_DIR/${BUILD2_ID}.json"

echo "Normalizing build 1..."
bash "$REPO_ROOT/scripts/normalize-output.sh" "$BUILD1" "$NORM1"

echo "Normalizing build 2..."
bash "$REPO_ROOT/scripts/normalize-output.sh" "$BUILD2" "$NORM2"

echo ""

# Compare
REPORT_FILE="$REPORT_DIR/comparison-${BUILD1_ID}-vs-${BUILD2_ID}.json"
REPORT_MD="$REPORT_DIR/comparison-${BUILD1_ID}-vs-${BUILD2_ID}.md"

python3 "$REPO_ROOT/tools/compare_manifests.py" \
    --build1 "$NORM1" \
    --build2 "$NORM2" \
    --output-json "$REPORT_FILE" \
    --output-md "$REPORT_MD"

echo ""
echo "Comparison report (JSON): $REPORT_FILE"
echo "Comparison report (MD):   $REPORT_MD"
