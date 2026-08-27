#!/usr/bin/env python3
"""
inspect_subtree.py — Decode and validate 3D Tiles Implicit Tiling subtree files.

Reads both subtree encodings legal under the 3D Tiles 1.1 spec:
- The combined binary .subtree format (magic bytes, JSON header, binary chunk)
- The JSON + external .bin form (what mago-3d-tiler 1.16.2 actually
  produces — see docs/findings.md Phase 1/2; these files have no fixed
  name, e.g. "0.json", so they're detected by content shape)

Checks for both:
- Header/magic validity (binary form only)
- Binary buffer lengths
- Tile availability bits
- Content availability bits
- Child subtree availability bits

Usage:
    python3 tools/inspect_subtree.py \
        --input-dir data/output/sarabetsu/implicit/small/<build-id> \
        --output manifests/reports/subtree-validation-<build-id>.json
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Make the sibling tools/subtree_common.py importable regardless of how
# this script is invoked — both `python3 tools/inspect_subtree.py` (which
# puts tools/ itself on sys.path) and `import tools.inspect_subtree` from
# a context with only the repo root on sys.path (e.g. tests/run-tests.sh)
# need to resolve the same bare `import subtree_common`.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import subtree_common  # noqa: E402
from subtree_common import (  # noqa: E402
    count_availability_multi as _count_availability_multi,
    find_subtree_levels,
    is_subtree_json,
)


def decode_subtree(subtree_path: Path, subtree_levels: int) -> dict:
    """Decode a single .subtree file (combined-binary format)."""
    result = {
        "path": str(subtree_path),
        "size_bytes": subtree_path.stat().st_size,
        "valid": False,
        "magic": None,
        "version": None,
        "json_byte_length": None,
        "binary_byte_length": None,
        "json_header": None,
        "tile_availability_count": None,
        "content_availability_count": None,
        "child_subtree_availability_count": None,
        "errors": [],
        "warnings": [],
    }

    try:
        parsed = subtree_common.parse_binary_subtree(subtree_path)
        result["magic"] = parsed["magic"]
        result["version"] = parsed["version"]
        result["json_byte_length"] = parsed["json_byte_length"]
        result["binary_byte_length"] = parsed["binary_byte_length"]
        result["json_header"] = parsed["header"]

        if parsed["magic"] is None:
            result["errors"].extend(parsed["errors"])  # too-small file
            return result

        # Preserve the original error-ordering: magic check first, then
        # version warning, then parse_binary_subtree's own structural
        # errors (size mismatch / JSON parse failure) — matters for
        # byte-identical output, not just semantic equivalence.
        if parsed["magic"] != subtree_common.SUBTREE_MAGIC.decode("ascii"):
            result["errors"].append(
                f"Invalid magic bytes: {parsed['magic']!r} "
                f"(expected {subtree_common.SUBTREE_MAGIC!r})"
            )
        if parsed["version"] != subtree_common.SUBTREE_VERSION:
            result["warnings"].append(
                f"Unexpected version: {parsed['version']} "
                f"(expected {subtree_common.SUBTREE_VERSION})"
            )
        result["errors"].extend(parsed["errors"])

        header = parsed["header"]
        if header is None:
            return result  # JSON header parse error; already recorded

        binary_data = parsed["binary_data"]
        buffer_views = header.get("bufferViews", [])

        # Total tiles in subtree: sum of 4^i for i in range(subtreeLevels)
        total_tiles = sum(4**i for i in range(subtree_levels))
        # Child subtrees: 4^subtreeLevels
        child_subtree_count = 4**subtree_levels

        result["tile_availability_count"] = subtree_common.count_availability(
            header.get("tileAvailability", {}), total_tiles, buffer_views, binary_data
        )
        result["content_availability_count"] = _count_availability_multi(
            header.get("contentAvailability", {}), total_tiles, buffer_views, binary_data
        )
        result["child_subtree_availability_count"] = subtree_common.count_availability(
            header.get("childSubtreeAvailability", {}),
            child_subtree_count,
            buffer_views,
            binary_data,
        )

        if not result["errors"]:
            result["valid"] = True

    except Exception as exc:  # noqa: BLE001
        result["errors"].append(f"Unexpected error: {exc}")

    return result


def decode_subtree_json_bin(json_path: Path, subtree_levels: int) -> dict:
    """Decode a subtree delivered as JSON + external .bin buffer, in the
    same result shape as decode_subtree() above so downstream consumers
    don't need to special-case the encoding."""
    result = {
        "path": str(json_path),
        "size_bytes": json_path.stat().st_size,
        "valid": False,
        "format": "json+bin",
        "json_header": None,
        "tile_availability_count": None,
        "content_availability_count": None,
        "child_subtree_availability_count": None,
        "errors": [],
        "warnings": [],
    }
    try:
        loaded = subtree_common.load_json_bin_subtree(json_path)
        header = loaded["header"]
        result["json_header"] = header
        result["errors"].extend(loaded["errors"])

        binary_data = loaded["binary_data"]
        buffer_views = header.get("bufferViews", [])

        total_tiles = sum(4**i for i in range(subtree_levels))
        child_subtree_count = 4**subtree_levels

        result["tile_availability_count"] = subtree_common.count_availability(
            header.get("tileAvailability", {}), total_tiles, buffer_views, binary_data
        )
        result["content_availability_count"] = _count_availability_multi(
            header.get("contentAvailability", {}), total_tiles, buffer_views, binary_data
        )
        result["child_subtree_availability_count"] = subtree_common.count_availability(
            header.get("childSubtreeAvailability", {}),
            child_subtree_count,
            buffer_views,
            binary_data,
        )

        if not result["errors"]:
            result["valid"] = True

    except Exception as exc:  # noqa: BLE001
        result["errors"].append(f"Unexpected error: {exc}")

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect 3D Tiles Implicit subtree files")
    parser.add_argument(
        "--input-dir", required=True, type=Path, help="Directory containing .subtree files"
    )
    parser.add_argument("--output", required=True, type=Path, help="Output JSON report path")
    args = parser.parse_args()

    input_dir = args.input_dir
    if not input_dir.exists():
        print(f"ERROR: Input directory not found: {input_dir}", file=sys.stderr)
        return 1

    binary_subtree_files = sorted(input_dir.rglob("*.subtree"))

    # Real mago-3d-tiler subtree JSON files have no fixed name (e.g.
    # "0.json") — find candidates by extension, then confirm by content
    # shape so tileset.json and other JSON output aren't misclassified.
    json_subtree_files = []
    for jf in sorted(input_dir.rglob("*.json")):
        try:
            parsed = json.loads(jf.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            continue
        if is_subtree_json(parsed):
            json_subtree_files.append(jf)

    subtree_files = binary_subtree_files + json_subtree_files
    if not subtree_files:
        print(f"WARNING: No subtree files (binary or JSON+bin) found in {input_dir}", file=sys.stderr)

    print(
        f"Inspecting {len(subtree_files)} subtree file(s) "
        f"({len(binary_subtree_files)} binary, {len(json_subtree_files)} json+bin)"
    )

    subtree_levels = find_subtree_levels(input_dir)
    if subtree_files and subtree_levels is None:
        print(
            f"WARNING: Could not determine implicitTiling.subtreeLevels from "
            f"{input_dir}/tileset.json — availability counts will be unreliable.",
            file=sys.stderr,
        )
        subtree_levels = 1

    results = []
    errors_total = 0
    for sf in subtree_files:
        print(f"  {sf.relative_to(input_dir)} ...", end="", flush=True)
        res = (
            decode_subtree(sf, subtree_levels)
            if sf in binary_subtree_files
            else decode_subtree_json_bin(sf, subtree_levels)
        )
        results.append(res)
        status = "ERRORS" if res["errors"] else ("warnings" if res["warnings"] else "ok")
        if res["errors"]:
            errors_total += 1
        print(
            f" [{status}] "
            f"tiles={res['tile_availability_count']} "
            f"content={res['content_availability_count']} "
            f"children={res['child_subtree_availability_count']}"
        )

    report = {
        "schema_version": "1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "input_dir": str(input_dir),
        "subtree_file_count": len(subtree_files),
        "error_count": errors_total,
        "subtrees": results,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\nSubtree files: {len(subtree_files)}, errors: {errors_total}")
    print(f"Report: {args.output}")
    return 1 if errors_total > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
