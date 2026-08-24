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

if ! [[ "$DATASET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid dataset name: $DATASET" >&2
    echo "  Dataset must match ^[a-zA-Z0-9_-]+\$ (no slashes, spaces, or shell metacharacters)." >&2
    exit 1
fi

OUTPUT_BASE="$REPO_ROOT/data/output/${DATASET}/${MODE}/${PROFILE}"
REPORT_DIR="$REPO_ROOT/manifests/reports"

LATEST_BUILD="$(find "$OUTPUT_BASE" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
if [ -z "$LATEST_BUILD" ]; then
    echo "ERROR: No build found at $OUTPUT_BASE" >&2
    exit 1
fi

BUILD_ID="$(basename "$LATEST_BUILD")"
# Metrics are written as a standalone JSON report, separate from the build's
# YAML manifest (manifests/builds/<build-id>.yml, written by scripts/build.sh)
# — the two must never share a file, since one is YAML and the other JSON.
METRICS_FILE="$REPORT_DIR/${BUILD_ID}-metrics.json"

echo "Metrics report: $METRICS_FILE"

python3 "$REPO_ROOT/tools/summarize_metrics.py" \
    --build-dir "$LATEST_BUILD" \
    --output "$METRICS_FILE"
