#!/usr/bin/env bash
# serve.sh — Start static HTTP server for outputs
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${SERVER_PORT:-8080}"

echo "=== Starting static HTTP server ==="
echo ""
echo "  Serving:"
echo "    Tiles:  http://localhost:$PORT/tiles/"
echo "    Viewer: http://localhost:$PORT/viewer/"
echo ""
echo "  Open the viewer at: http://localhost:$PORT/viewer/"
echo "  Press Ctrl+C to stop."
echo ""

if command -v docker &>/dev/null && [ -f "$REPO_ROOT/compose.yml" ]; then
    echo "Using nginx via Docker Compose..."
    docker compose -f "$REPO_ROOT/compose.yml" up server
elif command -v python3 &>/dev/null; then
    echo "Using Python http.server (development only)..."
    echo "Note: MIME types may not be optimal. Use Docker/nginx for production testing."
    cd "$REPO_ROOT"
    python3 -m http.server "$PORT"
else
    echo "ERROR: Neither Docker nor Python 3 available." >&2
    exit 1
fi
