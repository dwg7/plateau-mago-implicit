#!/usr/bin/env bash
# validate.sh — Validate 3D Tiles output
# Usage: bash scripts/validate.sh <dataset> <mode> <profile>
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
LOG_DIR="$REPO_ROOT/manifests/reports"
mkdir -p "$LOG_DIR"

# Find most recent build
LATEST_BUILD="$(find "$OUTPUT_BASE" -maxdepth 1 -type d | sort | tail -1)"
if [ -z "$LATEST_BUILD" ] || [ "$LATEST_BUILD" = "$OUTPUT_BASE" ]; then
    echo "ERROR: No build found at $OUTPUT_BASE" >&2
    echo "  Run: make build DATASET=$DATASET MODE=$MODE PROFILE=$PROFILE" >&2
    exit 1
fi

BUILD_ID="$(basename "$LATEST_BUILD")"
echo "=== Validating $DATASET / $MODE / $PROFILE ==="
echo "  Build: $BUILD_ID"
echo "  Path:  $LATEST_BUILD"
echo ""

ERRORS=0
WARNINGS=0

# Check tileset.json exists
TILESET="$LATEST_BUILD/tileset.json"
if [ ! -f "$TILESET" ]; then
    echo "  ✗ tileset.json: NOT FOUND" >&2
    ERRORS=$((ERRORS + 1))
else
    echo "  ✓ tileset.json: found ($(wc -c < "$TILESET") bytes)"

    # Check JSON validity
    if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TILESET" 2>/dev/null; then
        echo "  ✓ tileset.json: valid JSON"
    else
        echo "  ✗ tileset.json: invalid JSON"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for Implicit Tiling declaration if mode is implicit
    if [ "$MODE" = "implicit" ]; then
        if python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
root=d.get('root',{})
it=root.get('implicitTiling')
if not it:
    sys.exit(1)
" "$TILESET" 2>/dev/null; then
            echo "  ✓ Implicit Tiling: declared in root"
        else
            echo "  ✗ Implicit Tiling: not found in root (expected for implicit mode)"
            ERRORS=$((ERRORS + 1))
        fi
    fi
fi

# Count subtree files
SUBTREE_COUNT="$(find "$LATEST_BUILD" -name "*.subtree" 2>/dev/null | wc -l | tr -d ' ')"
echo "  Subtree files: $SUBTREE_COUNT"

# Count GLB files
GLB_COUNT="$(find "$LATEST_BUILD" -name "*.glb" 2>/dev/null | wc -l | tr -d ' ')"
echo "  GLB files:     $GLB_COUNT"

# Run Python subtree validator if subtrees present
if [ "$SUBTREE_COUNT" -gt 0 ]; then
    echo ""
    echo "  Running subtree validation..."
    python3 "$REPO_ROOT/tools/inspect_subtree.py" \
        --input-dir "$LATEST_BUILD" \
        --output "$LOG_DIR/subtree-validation-${BUILD_ID}.json" \
        2>&1 | sed 's/^/    /' || WARNINGS=$((WARNINGS + 1))
fi

# Run 3d-tiles-validator if available
if command -v npx &>/dev/null; then
    echo ""
    echo "  Running 3d-tiles-validator..."
    VALIDATOR_LOG="$LOG_DIR/3dtiles-validator-${BUILD_ID}.log"
    npx 3d-tiles-validator \
        --tilesetFile "$TILESET" \
        2>&1 | tee "$VALIDATOR_LOG" | sed 's/^/    /' || WARNINGS=$((WARNINGS + 1))
    echo "  Validator log: $VALIDATOR_LOG"
else
    echo "  ⚠ 3d-tiles-validator not available (npx not found)"
    echo "    Install with: npm install -g 3d-tiles-tools"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo "VALIDATION FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo "VALIDATION PASSED WITH WARNINGS: $WARNINGS warning(s)"
else
    echo "VALIDATION PASSED"
fi
