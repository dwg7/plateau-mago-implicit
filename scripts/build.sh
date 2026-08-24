#!/usr/bin/env bash
# build.sh — Convert CityGML to 3D Tiles using Mago 3DTiler
# Usage: bash scripts/build.sh <dataset> <mode> <profile> [concurrency]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-}"
MODE="${2:-implicit}"
PROFILE="${3:-small}"
CONCURRENCY="${4:-1}"

if [ -z "$DATASET" ]; then
    echo "Usage: $0 <dataset> <mode> <profile> [concurrency]" >&2
    echo "  dataset:     sarabetsu | muroran" >&2
    echo "  mode:        explicit | implicit" >&2
    echo "  profile:     small | full" >&2
    echo "  concurrency: number of threads (default: 1)" >&2
    exit 1
fi

if ! [[ "$DATASET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid dataset name: $DATASET" >&2
    echo "  Dataset must match ^[a-zA-Z0-9_-]+\$ (no slashes, spaces, or shell metacharacters)." >&2
    exit 1
fi

CONFIG_COMMON="$REPO_ROOT/config/common.yml"
CONFIG_DATASET="$REPO_ROOT/config/${DATASET}.yml"
SOURCE_DIR="$REPO_ROOT/data/source/$DATASET"
OUTPUT_BASE="$REPO_ROOT/data/output"
BUILD_ID="$(date -u +%Y%m%dT%H%M%SZ)-${DATASET}-${MODE}-${PROFILE}"
OUTPUT_DIR="$OUTPUT_BASE/${DATASET}/${MODE}/${PROFILE}/${BUILD_ID}"
MANIFEST_DIR="$REPO_ROOT/manifests/builds"
MANIFEST_FILE="$MANIFEST_DIR/${BUILD_ID}.yml"

mkdir -p "$OUTPUT_DIR" "$MANIFEST_DIR"

# Helper: fail if value is unresolved
check_tbd() {
    local value="$1"
    local label="$2"
    if [ "$value" = "TBD_VERIFIED_SOURCE_REQUIRED" ] || [ -z "$value" ]; then
        echo "ERROR: $label is TBD_VERIFIED_SOURCE_REQUIRED." >&2
        echo "  Resolve this value before building." >&2
        exit 1
    fi
}

# Read a field from a top-level YAML section without requiring yq.
# Scoped to the named section only, since multiple sections can share a
# sub-key name (e.g. both "mago:" and "java:" have an "image:" field).
get_config_field() {
    local section="$1"
    local field="$2"
    awk -v section="^${section}:" -v field="  ${field}:" '
        $0 ~ section { in_section=1; next }
        in_section && /^[^ ]/ { in_section=0 }
        in_section && index($0, field) == 1 {
            sub(field " *", "");
            gsub(/"/, "");
            print;
            exit
        }
    ' "$CONFIG_COMMON"
}

MAGO_IMAGE="$(get_config_field mago image)"
MAGO_IMAGE_DIGEST="$(get_config_field mago image_digest)"

check_tbd "$MAGO_IMAGE" "mago.image in config/common.yml"
check_tbd "$MAGO_IMAGE_DIGEST" "mago.image_digest in config/common.yml"

# Determine input files
if [ "$PROFILE" = "small" ]; then
    SMALL_FILE="$(grep "^  small_file:" "$CONFIG_DATASET" | head -1 | sed 's/^  small_file: *//' | tr -d '"')"
    check_tbd "$SMALL_FILE" "source.small_file in config/${DATASET}.yml"
    INPUT_FILES=("$SOURCE_DIR/$SMALL_FILE")
else
    # Full profile: use all building files
    mapfile -t INPUT_FILES < <(find "$SOURCE_DIR" -name "*.gml" | sort)
    if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
        echo "ERROR: No CityGML files found in $SOURCE_DIR" >&2
        exit 1
    fi
fi

INPUT_DIR="$(dirname "${INPUT_FILES[0]}")"

echo "=== Build: $DATASET / $MODE / $PROFILE ==="
echo "  Build ID:     $BUILD_ID"
echo "  Input:        $INPUT_DIR"
echo "  Output:       $OUTPUT_DIR"
echo "  Mode:         $MODE"
echo "  Concurrency:  $CONCURRENCY"
echo "  Mago image:   $MAGO_IMAGE@$MAGO_IMAGE_DIGEST"
echo ""

# Set Mago options based on mode
if [ "$MODE" = "implicit" ]; then
    MAGO_OPTS=(--input /data/input --output /data/output --outputType 3dtiles --tileType implicit)
elif [ "$MODE" = "explicit" ]; then
    MAGO_OPTS=(--input /data/input --output /data/output --outputType 3dtiles)
else
    echo "ERROR: Unknown mode: $MODE (use explicit or implicit)" >&2
    exit 1
fi

START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_EPOCH="$(date +%s)"

# Run Mago 3DTiler via Docker. Built as an array (not a string handed to
# `eval`) so that a dataset/path value can never be interpreted as shell
# syntax, regardless of what characters it contains.
DOCKER_ARGS=(
    run --rm
    -v "$INPUT_DIR:/data/input:ro"
    -v "$OUTPUT_DIR:/data/output"
    -e "JAVA_OPTS=${JAVA_OPTS:--Xmx4g}"
    "${MAGO_IMAGE}@${MAGO_IMAGE_DIGEST}"
    "${MAGO_OPTS[@]}"
    --thread "$CONCURRENCY"
)
DOCKER_CMD="docker ${DOCKER_ARGS[*]}"

echo "Command: $DOCKER_CMD"
echo ""

RETURN_CODE=0
docker "${DOCKER_ARGS[@]}" || RETURN_CODE=$?

END_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
END_EPOCH="$(date +%s)"
DURATION=$((END_EPOCH - START_EPOCH))

# Count output files
OUTPUT_FILE_COUNT="$(find "$OUTPUT_DIR" -type f | wc -l | tr -d ' ')"
OUTPUT_TOTAL_BYTES="$(find "$OUTPUT_DIR" -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)"

# Get root tileset checksum if it exists
ROOT_TILESET="$OUTPUT_DIR/tileset.json"
ROOT_TILESET_SHA256=""
ROOT_TILESET_BYTES=0
if [ -f "$ROOT_TILESET" ]; then
    ROOT_TILESET_SHA256="$(sha256sum "$ROOT_TILESET" | awk '{print $1}')"
    ROOT_TILESET_BYTES="$(wc -c < "$ROOT_TILESET")"
fi

# On success, point "latest" at this build so consumers (the viewer, ad
# hoc curl/inspection) don't need to know the timestamped BUILD_ID.
if [ "$RETURN_CODE" -eq 0 ]; then
    ln -sfn "$BUILD_ID" "$OUTPUT_BASE/${DATASET}/${MODE}/${PROFILE}/latest"
fi

# Write build manifest
cat > "$MANIFEST_FILE" << EOF
schema_version: "1"
build_id: "${BUILD_ID}"
municipality: "${DATASET}"
mode: "${MODE}"
profile: "${PROFILE}"
mago_image: "${MAGO_IMAGE}"
mago_image_digest: "${MAGO_IMAGE_DIGEST}"
concurrency: ${CONCURRENCY}
input_dir: "${INPUT_DIR}"
output_dir: "${OUTPUT_DIR}"
command: "${DOCKER_CMD}"
started_at: "${START_TIME}"
ended_at: "${END_TIME}"
duration_seconds: ${DURATION}
return_code: ${RETURN_CODE}
output_file_count: ${OUTPUT_FILE_COUNT}
output_total_bytes: ${OUTPUT_TOTAL_BYTES}
root_tileset_sha256: "${ROOT_TILESET_SHA256}"
root_tileset_bytes: ${ROOT_TILESET_BYTES}
validation_status: "not-run"
git_commit: "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
git_dirty: $(git -C "$REPO_ROOT" diff --quiet 2>/dev/null && echo false || echo true)
EOF

echo ""
echo "Build manifest: $MANIFEST_FILE"

if [ "$RETURN_CODE" -ne 0 ]; then
    echo ""
    echo "ERROR: Mago 3DTiler exited with code $RETURN_CODE" >&2
    exit "$RETURN_CODE"
fi

echo ""
echo "Build complete in ${DURATION}s"
echo "  Output files: $OUTPUT_FILE_COUNT"
echo "  Output size:  $OUTPUT_TOTAL_BYTES bytes"
if [ -n "$ROOT_TILESET_SHA256" ]; then
    echo "  Root tileset: $ROOT_TILESET_SHA256"
fi
echo ""
echo "Next step: make validate DATASET=$DATASET MODE=$MODE PROFILE=$PROFILE"
