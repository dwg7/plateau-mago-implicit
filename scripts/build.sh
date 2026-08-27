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

# Determine source input files (pre-stripping)
if [ "$PROFILE" = "small" ]; then
    SMALL_FILE="$(grep "^  small_file:" "$CONFIG_DATASET" | head -1 | sed 's/^  small_file: *//' | tr -d '"')"
    check_tbd "$SMALL_FILE" "source.small_file in config/${DATASET}.yml"
    SMALL_FILE_PATH="$SOURCE_DIR/$SMALL_FILE"
    if [ ! -f "$SMALL_FILE_PATH" ]; then
        echo "ERROR: source.small_file not found: $SMALL_FILE_PATH" >&2
        echo "  Run: make inspect DATASET=$DATASET (extracts the archive)" >&2
        exit 1
    fi
    SOURCE_FILES=("$SMALL_FILE_PATH")
else
    # Full profile: use all building files.
    #
    # Scoped to udx/bldg/ specifically, not the whole $SOURCE_DIR: a real
    # PLATEAU package also contains udx/dem, udx/frn, udx/luse, udx/tran,
    # udx/veg (terrain, street furniture, land use, roads, vegetation).
    # CLAUDE.md's scope boundary is explicit that this project is
    # buildings-only for the baseline (Phase 7 is the only place higher
    # detail/other feature types are allowed, and it must stay separate).
    # An earlier version of this branch searched $SOURCE_DIR unscoped,
    # which would have fed all ~1100 non-building files into Mago too —
    # caught before ever actually running a full-profile build.
    BLDG_DIR="$SOURCE_DIR/udx/bldg"
    if [ ! -d "$BLDG_DIR" ]; then
        echo "ERROR: $BLDG_DIR not found" >&2
        echo "  Run: make inspect DATASET=$DATASET (extracts the archive)" >&2
        exit 1
    fi
    # Avoids `mapfile`/`readarray` (bash 4+ only) — see compare-builds.sh
    # for why: macOS's default `/bin/bash` is 3.2 and `env bash` resolves
    # to it whenever nothing newer is earlier on PATH.
    SOURCE_FILES=()
    while IFS= read -r f; do
        SOURCE_FILES+=("$f")
    done < <(find "$BLDG_DIR" -name "*.gml" | sort)
    if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
        echo "ERROR: No CityGML files found in $BLDG_DIR" >&2
        exit 1
    fi
fi

# Stage every source file through tools/strip_higher_lod.py before Mago
# ever sees it — mago-3d-tiler converts every bldg:lod*Solid/MultiSurface/
# FootPrint/RoofEdge element it finds, one sibling tile branch per LOD,
# all loaded together via `refine: ADD` (verified empirically: up to 4
# overlapping representations of the same building for the handful that
# carry LOD0+LOD1+LOD3 simultaneously — see docs/findings.md). CLAUDE.md's
# scope boundary is explicit that this project's baseline is LOD1 only;
# this enforces that boundary at the source-data level for Phase 1-6.
#
# Phase 7 (docs/scope.md: "Optional higher-detail (LOD2+, textures)",
# explicitly separate from and not invalidating Phase 1-6) is the one
# legitimate exception, requested and approved by the user 2026-08-28 —
# not a routine bypass. PHASE7=1 skips this stripping step entirely
# (opt-in, defaults off, loud about it) so higher-LOD geometry reaches
# Mago unmodified. Never touches data/source/ itself either way — always
# reads from there and writes into a per-build staging directory.
STAGING_DIR="$REPO_ROOT/data/.build-staging/${DATASET}/${BUILD_ID}"
mkdir -p "$STAGING_DIR"
STAGED_FILES=()
if [ "${PHASE7:-}" = "1" ]; then
    echo "*** PHASE7 mode: higher-LOD geometry included, this is OUT OF the LOD1 baseline. ***" >&2
    echo "*** Results from this build must not be compared against or merged into Phase 1-6. ***" >&2
    for src in "${SOURCE_FILES[@]}"; do
        dest="$STAGING_DIR/$(basename "$src")"
        cp "$src" "$dest"
        STAGED_FILES+=("$dest")
    done
else
    for src in "${SOURCE_FILES[@]}"; do
        dest="$STAGING_DIR/$(basename "$src")"
        python3 "$REPO_ROOT/tools/strip_higher_lod.py" "$src" "$dest" || {
            echo "ERROR: tools/strip_higher_lod.py failed on $src" >&2
            exit 1
        }
        STAGED_FILES+=("$dest")
    done
fi

# Second staging pass: PLATEAU's building heights are referenced to Tokyo
# Bay mean sea level (orthometric), not the ellipsoid, even though
# EPSG:6697 is nominally an ellipsoidal-height CRS — verified empirically
# against two independent, correctly-ellipsoidal terrain services
# (buildings sit 28-34m below real terrain, matching each site's
# GSIGEO2011 geoid undulation almost exactly; see docs/findings.md
# "Cross-phase follow-up: terrain/building vertical datum mismatch").
# Mago's --proj only fixes horizontal axis order and passes Z through
# unchanged, so this has to happen before Mago sees the file, same as
# LOD stripping above. Unconditional for both profiles — there's no
# baseline scenario where feeding Mago un-geoid-corrected height is
# correct once the destination renderer treats Z as ellipsoidal.
GEOID_STAGING_DIR="$REPO_ROOT/data/.build-staging-geoid/${DATASET}/${BUILD_ID}"
mkdir -p "$GEOID_STAGING_DIR"
INPUT_FILES=()
for src in "${STAGED_FILES[@]}"; do
    dest="$GEOID_STAGING_DIR/$(basename "$src")"
    python3 "$REPO_ROOT/tools/geoid_correct.py" "$src" "$dest" || {
        echo "ERROR: tools/geoid_correct.py failed on $src" >&2
        echo "  Is the japan-geoid package installed? pip3 install -r requirements.txt" >&2
        exit 1
    }
    INPUT_FILES+=("$dest")
done

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

    # config/common.yml's tiling.subtree_levels was recorded but never
    # actually passed to Mago (every build to date used Mago's own
    # default of 4, confirmed via decoded subtree files in
    # docs/findings.md's Phase 2). Mago does expose a real flag for this
    # — `-isl, --implicitSubtreeLevels <arg>` — confirmed via
    # `docker run <image> --help`, but it's marked "[Experimental]" by
    # Mago itself, so treat any resulting structural change as expected,
    # not a bug, if this is ever compared against pre-change builds.
    SUBTREE_LEVELS="$(get_config_field tiling subtree_levels)"
    if [ -n "$SUBTREE_LEVELS" ] && [ "$SUBTREE_LEVELS" != "TBD_VERIFIED_SOURCE_REQUIRED" ]; then
        MAGO_OPTS+=(--implicitSubtreeLevels "$SUBTREE_LEVELS")
    fi
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
# "IOException: /data/input path is not writable" under :ro). Since every
# profile now stages through tools/strip_higher_lod.py first (see above),
# $INPUT_DIR is always the per-build staging directory, never $SOURCE_DIR
# itself — so whatever Mago writes into it doesn't touch the checksummed
# source extraction.
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
