#!/usr/bin/env python3
"""
inspect_subtree.py — Decode and validate 3D Tiles Implicit Tiling subtree files.

Reads .subtree files and checks:
- Magic bytes
- JSON header validity
- Binary buffer lengths
- Tile availability bits
- Content availability bits
- Child subtree availability bits

Usage:
    python3 tools/inspect_subtree.py \
        --input-dir data/output/sarabetsu/implicit/small/<build-id> \
        --output manifests/reports/subtree-validation-<build-id>.json
"""

import argparse
import json

import struct
import sys
from datetime import datetime, timezone
from pathlib import Path


SUBTREE_MAGIC = b"subt"
SUBTREE_VERSION = 1


def count_bits(data: bytes, bit_count: int) -> int:
    """Count the number of set bits in the first bit_count bits of data."""
    count = 0
    for i in range(bit_count):
        byte_idx = i // 8
        bit_idx = i % 8
        if byte_idx < len(data) and (data[byte_idx] >> bit_idx) & 1:
            count += 1
    return count


def decode_subtree(subtree_path: Path) -> dict:
    """Decode a single .subtree file."""
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
        data = subtree_path.read_bytes()

        if len(data) < 24:
            result["errors"].append(f"File too small: {len(data)} bytes (minimum 24)")
            return result

        # Header: magic (4), version (4), json_byte_length (8), binary_byte_length (8)
        magic = data[0:4]
        result["magic"] = magic.decode("ascii", errors="replace")

        if magic != SUBTREE_MAGIC:
            result["errors"].append(
                f"Invalid magic bytes: {magic!r} (expected {SUBTREE_MAGIC!r})"
            )

        version = struct.unpack_from("<I", data, 4)[0]
        result["version"] = version
        if version != SUBTREE_VERSION:
            result["warnings"].append(
                f"Unexpected version: {version} (expected {SUBTREE_VERSION})"
            )

        json_byte_length = struct.unpack_from("<Q", data, 8)[0]
        binary_byte_length = struct.unpack_from("<Q", data, 16)[0]
        result["json_byte_length"] = json_byte_length
        result["binary_byte_length"] = binary_byte_length

        header_size = 24
        expected_size = header_size + json_byte_length + binary_byte_length
        if len(data) < expected_size:
            result["errors"].append(
                f"File size mismatch: {len(data)} bytes, expected {expected_size}"
            )

        # Parse JSON header
        json_bytes = data[header_size : header_size + json_byte_length]
        try:
            json_str = json_bytes.rstrip(b"\x00").decode("utf-8")
            header = json.loads(json_str)
            result["json_header"] = header
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            result["errors"].append(f"JSON header parse error: {exc}")
            return result

        # Parse binary buffer
        binary_offset = header_size + json_byte_length
        binary_data = data[binary_offset : binary_offset + binary_byte_length]

        # Decode availability bitstreams
        buffer_views = header.get("bufferViews", [])

        def get_buffer_view_data(bv_index: int) -> bytes | None:
            if bv_index is None or bv_index >= len(buffer_views):
                return None
            bv = buffer_views[bv_index]
            buf_idx = bv.get("buffer", 0)
            byte_offset = bv.get("byteOffset", 0)
            byte_length = bv.get("byteLength", 0)
            if buf_idx == 0 and len(binary_data) >= byte_offset + byte_length:
                return binary_data[byte_offset : byte_offset + byte_length]
            return None

        def count_availability(availability_obj: dict, max_tiles: int) -> int | None:
            if availability_obj is None:
                return None
            constant = availability_obj.get("constant")
            if constant is not None:
                return max_tiles if constant == 1 else 0
            bv_index = availability_obj.get("bitstream")
            bv_data = get_buffer_view_data(bv_index)
            if bv_data is None:
                return None
            return count_bits(bv_data, max_tiles)

        subtree_levels = header.get("subtreeLevels", 1)
        # Total tiles in subtree: sum of 4^i for i in range(subtreeLevels)
        total_tiles = sum(4**i for i in range(subtree_levels))
        # Child subtrees: 4^subtreeLevels
        child_subtree_count = 4**subtree_levels

        tile_avail = header.get("tileAvailability", {})
        content_avail = header.get("contentAvailability", {})
        child_avail = header.get("childSubtreeAvailability", {})

        result["tile_availability_count"] = count_availability(tile_avail, total_tiles)
        if isinstance(content_avail, list):
            result["content_availability_count"] = sum(
                count_availability(ca, total_tiles) or 0 for ca in content_avail
            )
        else:
            result["content_availability_count"] = count_availability(
                content_avail, total_tiles
            )
        result["child_subtree_availability_count"] = count_availability(
            child_avail, child_subtree_count
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

    subtree_files = sorted(input_dir.rglob("*.subtree"))
    if not subtree_files:
        print(f"WARNING: No .subtree files found in {input_dir}", file=sys.stderr)

    print(f"Inspecting {len(subtree_files)} subtree file(s)")

    results = []
    errors_total = 0
    for sf in subtree_files:
        print(f"  {sf.relative_to(input_dir)} ...", end="", flush=True)
        res = decode_subtree(sf)
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
