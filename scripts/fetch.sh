#!/usr/bin/env bash
# fetch.sh — Download and verify source data for a dataset
# Usage: bash scripts/fetch.sh <dataset>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-}"

if [ -z "$DATASET" ]; then
    echo "Usage: $0 <dataset>" >&2
    echo "  dataset: sarabetsu | muroran" >&2
    exit 1
fi

MANIFEST="$REPO_ROOT/data/input-manifest.yml"
SOURCE_DIR="$REPO_ROOT/data/source/$DATASET"

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: data/input-manifest.yml not found." >&2
    exit 1
fi

# Simple YAML field extraction without yq dependency
get_field() {
    local field="$1"
    grep -A 50 "^  ${DATASET}:" "$MANIFEST" | grep "^    ${field}:" | head -1 | sed "s/^    ${field}: *//" | tr -d '"'
}

DOWNLOAD_URL="$(get_field download_url)"
ARCHIVE_NAME="$(get_field archive_name)"
ARCHIVE_SHA256="$(get_field archive_sha256)"

if [ "$DOWNLOAD_URL" = "TBD_VERIFIED_SOURCE_REQUIRED" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: download_url for '$DATASET' is TBD_VERIFIED_SOURCE_REQUIRED." >&2
    echo "  Resolve this value in data/input-manifest.yml before fetching." >&2
    exit 1
fi

if [ "$ARCHIVE_NAME" = "TBD_VERIFIED_SOURCE_REQUIRED" ] || [ -z "$ARCHIVE_NAME" ]; then
    echo "ERROR: archive_name for '$DATASET' is TBD_VERIFIED_SOURCE_REQUIRED." >&2
    exit 1
fi

if [ "$ARCHIVE_SHA256" = "TBD_VERIFIED_SOURCE_REQUIRED" ] || [ -z "$ARCHIVE_SHA256" ]; then
    echo "ERROR: archive_sha256 for '$DATASET' is TBD_VERIFIED_SOURCE_REQUIRED." >&2
    echo "  Resolve this value in data/input-manifest.yml before fetching." >&2
    exit 1
fi

mkdir -p "$SOURCE_DIR"
ARCHIVE_PATH="$SOURCE_DIR/$ARCHIVE_NAME"

echo "=== Fetching $DATASET ==="
echo "  URL: $DOWNLOAD_URL"
echo "  Destination: $ARCHIVE_PATH"
echo ""

if [ -f "$ARCHIVE_PATH" ]; then
    echo "Archive already exists. Verifying checksum..."
    ACTUAL="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
    if [ "$ACTUAL" = "$ARCHIVE_SHA256" ]; then
        echo "  ✓ Checksum verified: $ARCHIVE_SHA256"
        echo "Fetch complete (cached)."
        exit 0
    else
        echo "  ✗ Checksum mismatch. Expected: $ARCHIVE_SHA256"
        echo "    Got: $ACTUAL"
        echo "  Removing corrupt file and re-downloading..."
        rm -f "$ARCHIVE_PATH"
    fi
fi

echo "Downloading..."
curl -fL --progress-bar -o "$ARCHIVE_PATH" "$DOWNLOAD_URL"

echo "Verifying checksum..."
ACTUAL="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
if [ "$ACTUAL" != "$ARCHIVE_SHA256" ]; then
    echo "ERROR: Checksum verification failed." >&2
    echo "  Expected: $ARCHIVE_SHA256" >&2
    echo "  Got:      $ACTUAL" >&2
    rm -f "$ARCHIVE_PATH"
    exit 1
fi

echo "  ✓ Checksum verified: $ARCHIVE_SHA256"
echo ""
echo "Fetch complete: $ARCHIVE_PATH"
echo ""
echo "Next step: make inspect DATASET=$DATASET"
