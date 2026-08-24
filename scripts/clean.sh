#!/usr/bin/env bash
# clean.sh — Remove generated outputs (preserves source data)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Cleaning generated outputs ==="
echo ""
echo "This will remove:"
echo "  data/output/"
echo "  manifests/builds/"
echo "  manifests/normalized/"
echo "  manifests/reports/"
echo ""
read -r -p "Continue? [y/N] " REPLY
if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

find "$REPO_ROOT/data/output" -mindepth 1 -not -name ".gitkeep" -delete 2>/dev/null || true
find "$REPO_ROOT/manifests/builds" -mindepth 1 -not -name ".gitkeep" -delete 2>/dev/null || true
find "$REPO_ROOT/manifests/normalized" -mindepth 1 -not -name ".gitkeep" -delete 2>/dev/null || true
find "$REPO_ROOT/manifests/reports" -mindepth 1 -not -name ".gitkeep" -delete 2>/dev/null || true

echo "Done. Source data in data/source/ was not removed."
