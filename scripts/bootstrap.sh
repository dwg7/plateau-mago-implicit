#!/usr/bin/env bash
# bootstrap.sh — Verify prerequisites and print environment information
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/config/common.yml"

echo "=== plateau-mago-implicit bootstrap ==="
echo ""

ERRORS=0

check_command() {
    local cmd="$1"
    local desc="$2"
    if command -v "$cmd" &>/dev/null; then
        local version
        version="$($cmd --version 2>&1 | head -1)"
        echo "  ✓ $desc: $version"
    else
        echo "  ✗ $desc: NOT FOUND (install $cmd)"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "--- Required tools ---"
check_command docker "Docker"
check_command make "Make"
check_command python3 "Python 3"
check_command node "Node.js"
check_command bash "Bash"
check_command curl "curl"
check_command sha256sum "sha256sum"
echo ""

echo "--- Optional tools ---"
check_command git "Git"
check_command yq "yq (YAML parser)"
echo ""

echo "--- Environment ---"
echo "  OS: $(uname -s) $(uname -r)"
echo "  Arch: $(uname -m)"
echo "  Python: $(python3 --version 2>&1)"
if command -v node &>/dev/null; then
    echo "  Node.js: $(node --version)"
fi
echo "  Working directory: $REPO_ROOT"
echo ""

echo "--- Configuration ---"
if [ -f "$CONFIG" ]; then
    # Check for unresolved TBD values
    TBD_COUNT=$(grep -c "TBD_VERIFIED_SOURCE_REQUIRED" "$CONFIG" || true)
    if [ "$TBD_COUNT" -gt 0 ]; then
        echo "  ⚠ config/common.yml: $TBD_COUNT unresolved TBD_VERIFIED_SOURCE_REQUIRED values"
        echo "    Resolve these before running experiments."
    else
        echo "  ✓ config/common.yml: no unresolved values"
    fi
else
    echo "  ✗ config/common.yml: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "--- Data ---"
if [ -f "$REPO_ROOT/data/input-manifest.yml" ]; then
    TBD_COUNT=$(grep -c "TBD_VERIFIED_SOURCE_REQUIRED" "$REPO_ROOT/data/input-manifest.yml" || true)
    echo "  data/input-manifest.yml: $TBD_COUNT unresolved values"
else
    echo "  ✗ data/input-manifest.yml: NOT FOUND"
    ERRORS=$((ERRORS + 1))
fi
echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo "BOOTSTRAP FAILED: $ERRORS required tool(s) missing."
    echo "Install missing prerequisites and run again."
    exit 1
else
    echo "Bootstrap OK. Prerequisites present."
    echo ""
    echo "Next steps:"
    echo "  1. Resolve TBD_VERIFIED_SOURCE_REQUIRED values in data/input-manifest.yml"
    echo "     and config/sarabetsu.yml (and config/muroran.yml for Muroran City)"
    echo "  2. Run: make fetch DATASET=sarabetsu"
    echo "  3. Run: make experiment DATASET=sarabetsu PROFILE=small"
fi
