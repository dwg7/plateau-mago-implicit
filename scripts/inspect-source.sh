#!/usr/bin/env bash
# inspect-source.sh — Inspect source CityGML files for a dataset
# Usage: bash scripts/inspect-source.sh <dataset>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-}"

if [ -z "$DATASET" ]; then
    echo "Usage: $0 <dataset>" >&2
    exit 1
fi

if ! [[ "$DATASET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid dataset name: $DATASET" >&2
    echo "  Dataset must match ^[a-zA-Z0-9_-]+\$ (no slashes, spaces, or shell metacharacters)." >&2
    exit 1
fi

SOURCE_DIR="$REPO_ROOT/data/source/$DATASET"
REPORT_DIR="$REPO_ROOT/manifests/reports"
mkdir -p "$REPORT_DIR"

echo "=== Inspecting source for $DATASET ==="
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory not found: $SOURCE_DIR" >&2
    echo "  Run: make fetch DATASET=$DATASET" >&2
    exit 1
fi

# Find CityGML files
CITYGML_FILES="$(find "$SOURCE_DIR" -name "*.gml" -o -name "*.xml" 2>/dev/null | sort)"

if [ -z "$CITYGML_FILES" ]; then
    echo "No CityGML files found in $SOURCE_DIR"
    echo "The archive may need to be extracted first."
    # Try to extract if a zip exists
    ZIP_FILE="$(find "$SOURCE_DIR" -name "*.zip" 2>/dev/null | head -1)"
    if [ -n "$ZIP_FILE" ]; then
        echo "Found archive: $ZIP_FILE"
        echo "Extracting..."
        unzip -q "$ZIP_FILE" -d "$SOURCE_DIR"
        CITYGML_FILES="$(find "$SOURCE_DIR" -name "*.gml" -o -name "*.xml" 2>/dev/null | sort)"
    fi
fi

if [ -z "$CITYGML_FILES" ]; then
    echo "ERROR: No CityGML files found after extraction." >&2
    exit 1
fi

echo "Found CityGML files:"
echo "$CITYGML_FILES" | while read -r f; do
    SIZE="$(wc -c < "$f")"
    echo "  $f ($SIZE bytes)"
done
echo ""

# Run Python inspection tool
INSPECT_OUTPUT="$REPORT_DIR/inspect-${DATASET}.json"
echo "Running CityGML inspector..."
python3 "$REPO_ROOT/tools/inspect_citygml.py" \
    --dataset "$DATASET" \
    --source-dir "$SOURCE_DIR" \
    --output "$INSPECT_OUTPUT"

echo ""
echo "Inspection report: $INSPECT_OUTPUT"
echo ""
echo "Next step: make build DATASET=$DATASET MODE=explicit PROFILE=small"
