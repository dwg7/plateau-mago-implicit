#!/usr/bin/env bash
# publish.sh — Publish a build's output to a remote static host via rsync
# Usage: bash scripts/publish.sh <dataset> <mode> <profile> [--execute]
#
# See docs/tile-hosting-plan.md for the design this implements.
#
# Target host/path are read from the environment — never hardcoded, never
# committed (see .env.example): PUBLISH_HOST, PUBLISH_PATH, and optionally
# PUBLISH_USER. This script never handles a password or private key itself;
# it shells out to the system's own `rsync`/`ssh`, so auth is whatever your
# local SSH config already provides (key-based auth is assumed).
#
# Safe by default: without --execute, this only prints the rsync command it
# WOULD run and exits — nothing is transferred. Pass --execute to actually
# publish.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-}"
MODE="${2:-implicit}"
PROFILE="${3:-small}"
EXECUTE=0
for arg in "$@"; do
    if [ "$arg" = "--execute" ]; then
        EXECUTE=1
    fi
done

if [ -z "$DATASET" ]; then
    echo "Usage: $0 <dataset> <mode> <profile> [--execute]" >&2
    echo "  Without --execute: prints the rsync command and exits (dry run)." >&2
    echo "  Requires PUBLISH_HOST and PUBLISH_PATH in the environment (see .env.example)." >&2
    exit 1
fi

if ! [[ "$DATASET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid dataset name: $DATASET" >&2
    echo "  Dataset must match ^[a-zA-Z0-9_-]+\$ (no slashes, spaces, or shell metacharacters)." >&2
    exit 1
fi

: "${PUBLISH_HOST:?ERROR: PUBLISH_HOST is not set. See docs/tile-hosting-plan.md and .env.example.}"
: "${PUBLISH_PATH:?ERROR: PUBLISH_PATH is not set. See docs/tile-hosting-plan.md and .env.example.}"
PUBLISH_USER="${PUBLISH_USER:-}"

if ! command -v rsync &>/dev/null; then
    echo "ERROR: rsync is not installed." >&2
    exit 1
fi

OUTPUT_BASE="$REPO_ROOT/data/output/${DATASET}/${MODE}/${PROFILE}"
LATEST_LINK="$OUTPUT_BASE/latest"

if [ ! -L "$LATEST_LINK" ]; then
    echo "ERROR: No 'latest' build found at $LATEST_LINK" >&2
    echo "  Run: make build DATASET=$DATASET MODE=$MODE PROFILE=$PROFILE" >&2
    exit 1
fi

BUILD_ID="$(basename "$(readlink "$LATEST_LINK")")"
LOCAL_BUILD_DIR="$OUTPUT_BASE/$BUILD_ID"
ROOT_TILESET="$LOCAL_BUILD_DIR/tileset.json"

if [ ! -f "$ROOT_TILESET" ]; then
    echo "ERROR: No tileset.json in $LOCAL_BUILD_DIR" >&2
    exit 1
fi

REMOTE_TARGET="$PUBLISH_HOST"
if [ -n "$PUBLISH_USER" ]; then
    REMOTE_TARGET="${PUBLISH_USER}@${PUBLISH_HOST}"
fi

REMOTE_BASE="${PUBLISH_PATH%/}/${DATASET}/${MODE}/${PROFILE}"
REMOTE_BUILD_DIR="${REMOTE_BASE}/${BUILD_ID}/"

echo "=== Publish: $DATASET / $MODE / $PROFILE ==="
echo "  Build ID:      $BUILD_ID"
echo "  Local dir:     $LOCAL_BUILD_DIR"
echo "  Remote target: ${REMOTE_TARGET}:${REMOTE_BUILD_DIR}"
echo ""

RSYNC_CMD=(rsync -avz --checksum "${LOCAL_BUILD_DIR}/" "${REMOTE_TARGET}:${REMOTE_BUILD_DIR}")
echo "Command: ${RSYNC_CMD[*]}"

if [ "$EXECUTE" -ne 1 ]; then
    echo ""
    echo "Dry run only — nothing was transferred. Re-run with --execute to publish for real."
    exit 0
fi

echo ""
echo "Publishing..."
"${RSYNC_CMD[@]}"

echo ""
echo "Updating remote 'latest' symlink..."
ssh "$REMOTE_TARGET" "ln -sfn '$BUILD_ID' '${REMOTE_BASE}/latest'"

ROOT_TILESET_SHA256="$(sha256sum "$ROOT_TILESET" | awk '{print $1}')"
PUBLISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RECORD_FILE="$REPO_ROOT/manifests/reports/published-${BUILD_ID}.json"

cat > "$RECORD_FILE" << EOF
{
  "schema_version": "1",
  "build_id": "${BUILD_ID}",
  "dataset": "${DATASET}",
  "mode": "${MODE}",
  "profile": "${PROFILE}",
  "published_at": "${PUBLISHED_AT}",
  "remote_host": "${PUBLISH_HOST}",
  "remote_path": "${REMOTE_BUILD_DIR}",
  "root_tileset_sha256": "${ROOT_TILESET_SHA256}",
  "source_build_manifest": "manifests/builds/${BUILD_ID}.yml"
}
EOF

echo ""
echo "Published: $BUILD_ID"
echo "Record:    $RECORD_FILE"
echo ""
echo "Next step: verify with curl, then update viewer/viewer.js's VIEWPOINTS"
echo "if this should become one of the predefined dataset entries."
