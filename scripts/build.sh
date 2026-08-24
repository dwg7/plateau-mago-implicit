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

# Same as get_config_field, but reads from the per-dataset config file.
get_dataset_field() {
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
    ' "$CONFIG_DATASET"
}

MAGO_VERSION="$(get_config_field mago version)"
MAGO_JAR_URL="$(get_config_field mago jar_url)"
MAGO_JAR_SHA256="$(get_config_field mago jar_sha256)"

check_tbd "$MAGO_VERSION" "mago.version in config/common.yml"
check_tbd "$MAGO_JAR_URL" "mago.jar_url in config/common.yml"
check_tbd "$MAGO_JAR_SHA256" "mago.jar_sha256 in config/common.yml"

# No public pre-built Docker image exists for Mago 3DTiler (verified
# 2026-08-24), so build a local image from the pinned JAR. `docker build`
# is cache-friendly: unless the build args change, this is a fast no-op
# after the first run for a given version.
MAGO_IMAGE_TAG="plateau-mago-implicit-tiler:${MAGO_VERSION}"
echo "Building Mago 3DTiler image (cached if unchanged): $MAGO_IMAGE_TAG"
docker build \
    --build-arg "MAGO_VERSION=${MAGO_VERSION}" \
    --build-arg "MAGO_JAR_URL=${MAGO_JAR_URL}" \
    --build-arg "MAGO_JAR_SHA256=${MAGO_JAR_SHA256}" \
    -t "$MAGO_IMAGE_TAG" \
    -f "$REPO_ROOT/Dockerfile" \
    "$REPO_ROOT"
echo ""

# Determine input files
if [ "$PROFILE" = "small" ]; then
    SMALL_FILE="$(grep "^  small_file:" "$CONFIG_DATASET" | head -1 | sed 's/^  small_file: *//' | tr -d '"')"
    check_tbd "$SMALL_FILE" "source.small_file in config/${DATASET}.yml"
    SMALL_FILE_PATH="$SOURCE_DIR/$SMALL_FILE"
    if [ ! -f "$SMALL_FILE_PATH" ]; then
        echo "ERROR: source.small_file not found: $SMALL_FILE_PATH" >&2
        echo "  Run: make inspect DATASET=$DATASET (extracts the archive)" >&2
        exit 1
    fi
    # mago-3d-tiler's --input takes a DIRECTORY and processes every CityGML
    # file found in it — mounting $SOURCE_DIR/udx/bldg (the small_file's
    # parent) would silently convert ALL ~100-200 building mesh files in
    # that municipality's bldg/ directory, not just the one small_file
    # (verified empirically: a "small" build of one file produced 202 tile
    # contents). Stage just the single selected file in an isolated
    # directory so "small" actually means small.
    STAGING_DIR="$REPO_ROOT/data/.build-staging/${DATASET}/${BUILD_ID}"
    mkdir -p "$STAGING_DIR"
    cp "$SMALL_FILE_PATH" "$STAGING_DIR/"
    INPUT_FILES=("$STAGING_DIR/$(basename "$SMALL_FILE_PATH")")
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
echo "  Mago image:   $MAGO_IMAGE_TAG (jar sha256: ${MAGO_JAR_SHA256:0:12}...)"
echo ""

# Mago 3DTiler's CRS handling (--crs <EPSG code>) assumes (lon, lat) axis
# order; PLATEAU CityGML's gml:pos/lowerCorner/upperCorner values are
# (lat, lon, height) per their declared srsName (e.g. EPSG:6697's axis
# order). Passing --crs 6697/6668/4326 directly silently produces WRONG
# output coordinates (verified empirically: building placed off the coast
# of California instead of Hokkaido). The fix is an explicit --proj string
# with +axis=neu (north-east-up) to declare the source axis order, recorded
# per-dataset in config/<dataset>.yml's crs.mago_proj field.
MAGO_PROJ="$(get_dataset_field crs mago_proj)"
check_tbd "$MAGO_PROJ" "crs.mago_proj in config/${DATASET}.yml"

# --outputType and --tileType do not exist in mago-3d-tiler's actual CLI
# (verified against v1.16.2 --help and MANUAL.md: real flags are
# --inputType/--outputType [b3dm|i3dm|pnts] and --tilingMode
# [explicit|implicit]). Passing the old, nonexistent flags made every
# build fail immediately with UnrecognizedOptionException, for both modes.
MAGO_OPTS=(--input /data/input --output /data/output --inputType citygml --proj "$MAGO_PROJ")
if [ "$MODE" = "implicit" ]; then
    MAGO_OPTS+=(--tilingMode implicit)
elif [ "$MODE" = "explicit" ]; then
    : # explicit is mago-3d-tiler's default tilingMode; nothing to add
else
    echo "ERROR: Unknown mode: $MODE (use explicit or implicit)" >&2
    exit 1
fi

START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START_EPOCH="$(date +%s)"

# Run Mago 3DTiler via Docker. Built as an array (not a string handed to
# `eval`) so that a dataset/path value can never be interpreted as shell
# syntax, regardless of what characters it contains.
#
# The input mount is NOT read-only: mago-3d-tiler itself requires the
# input path to be writable (verified empirically — it throws
# "IOException: /data/input path is not writable" under :ro). This means
# a `full` profile build writes into $SOURCE_DIR itself, not just $OUTPUT_DIR.
DOCKER_ARGS=(
    run --rm
    -v "$INPUT_DIR:/data/input"
    -v "$OUTPUT_DIR:/data/output"
    -e "JAVA_OPTS=${JAVA_OPTS:--Xmx4g}"
    "$MAGO_IMAGE_TAG"
    "${MAGO_OPTS[@]}"
    --multiThreadCount "$CONCURRENCY"
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
mago_version: "${MAGO_VERSION}"
mago_image: "${MAGO_IMAGE_TAG}"
mago_jar_url: "${MAGO_JAR_URL}"
mago_jar_sha256: "${MAGO_JAR_SHA256}"
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
