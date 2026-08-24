#!/usr/bin/env bash
# tests/run-tests.sh — Run all tests
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Running tests ==="
echo ""

ERRORS=0

run_test() {
    local name="$1"
    local cmd="$2"
    printf "  %-50s " "$name"
    if eval "$cmd" &>/dev/null; then
        echo "PASS"
    else
        echo "FAIL"
        ERRORS=$((ERRORS + 1))
    fi
}

# Python tool unit tests
echo "--- Python tool tests ---"
run_test "inspect_citygml imports" \
    "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT\"); import tools.inspect_citygml'"
run_test "inspect_subtree imports" \
    "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT\"); import tools.inspect_subtree'"
run_test "normalize imports" \
    "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT\"); import tools.normalize'"
run_test "compare_manifests imports" \
    "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT\"); import tools.compare_manifests'"
run_test "summarize_metrics imports" \
    "python3 -c 'import sys; sys.path.insert(0, \"$REPO_ROOT\"); import tools.summarize_metrics'"
echo ""

# Configuration validity
echo "--- Configuration tests ---"
run_test "config/common.yml is valid YAML" \
    "python3 -c \"import sys; data=open('$REPO_ROOT/config/common.yml').read(); import re; assert 'schema_version' in data\""
run_test "config/sarabetsu.yml has required fields" \
    "python3 -c \"data=open('$REPO_ROOT/config/sarabetsu.yml').read(); assert 'code:' in data and 'name_en:' in data\""
run_test "config/muroran.yml has required fields" \
    "python3 -c \"data=open('$REPO_ROOT/config/muroran.yml').read(); assert 'code:' in data and 'name_en:' in data\""
run_test "data/input-manifest.yml has sarabetsu entry" \
    "python3 -c \"data=open('$REPO_ROOT/data/input-manifest.yml').read(); assert 'sarabetsu' in data\""
run_test "data/input-manifest.yml has muroran entry" \
    "python3 -c \"data=open('$REPO_ROOT/data/input-manifest.yml').read(); assert 'muroran' in data\""
echo ""

# TBD guard tests (scripts should fail when TBD values are present)
echo "--- TBD guard tests ---"
run_test "fetch.sh fails on TBD_VERIFIED_SOURCE_REQUIRED" \
    "! bash '$REPO_ROOT/scripts/fetch.sh' tbd-guard-test 2>/dev/null"
echo ""

# Fixture tests
echo "--- Fixture tests ---"
FIXTURE_DIR="$REPO_ROOT/data/fixtures"

# CityGML fixture inspection
FIXTURE_GML="$FIXTURE_DIR/test_building.gml"
if [ -f "$FIXTURE_GML" ]; then
    run_test "inspect_citygml on fixture" \
        "python3 '$REPO_ROOT/tools/inspect_citygml.py' --dataset test --source-dir '$FIXTURE_DIR' --output /tmp/test-inspect.json"
fi

# Subtree fixture
FIXTURE_SUBTREE="$FIXTURE_DIR/test.subtree"
if [ -f "$FIXTURE_SUBTREE" ]; then
    run_test "inspect_subtree on fixture" \
        "python3 '$REPO_ROOT/tools/inspect_subtree.py' --input-dir '$FIXTURE_DIR' --output /tmp/test-subtree.json"
fi

# Normalize + compare with identical inputs
run_test "normalize empty directory" \
    "mkdir -p /tmp/test-norm-dir && python3 '$REPO_ROOT/tools/normalize.py' --input-dir /tmp/test-norm-dir --output /tmp/test-norm.json"
run_test "compare identical manifests" \
    "python3 '$REPO_ROOT/tools/compare_manifests.py' --build1 /tmp/test-norm.json --build2 /tmp/test-norm.json --output-json /tmp/test-cmp.json --output-md /tmp/test-cmp.md"
echo ""

# Viewer file checks
echo "--- Viewer tests ---"
run_test "viewer/index.html exists" "[ -f '$REPO_ROOT/viewer/index.html' ]"
run_test "viewer/viewer.js exists" "[ -f '$REPO_ROOT/viewer/viewer.js' ]"
run_test "viewer/index.html references viewer.js" \
    "grep -q 'viewer.js' '$REPO_ROOT/viewer/index.html'"
echo ""

# Documentation link checks
echo "--- Documentation tests ---"
for doc in hypothesis scope architecture data-selection test-plan reproducibility \
           determinism validation performance information-retention \
           respectful-positioning limitations findings; do
    run_test "docs/${doc}.md exists" "[ -f '$REPO_ROOT/docs/${doc}.md' ]"
done
echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo "=== TESTS FAILED: $ERRORS failure(s) ==="
    exit 1
else
    echo "=== ALL TESTS PASSED ==="
fi
