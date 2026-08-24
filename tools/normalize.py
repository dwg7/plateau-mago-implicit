#!/usr/bin/env python3
"""
normalize.py — Normalize 3D Tiles output for determinism comparison.

Creates a normalized manifest from a build output directory that:
- Sorts file paths
- Normalizes tileset.json (sorts keys, removes timestamps)
- Records file checksums
- Decodes subtree availability
- Records GLB mesh/accessor counts

Usage:
    python3 tools/normalize.py \
        --input-dir data/output/sarabetsu/implicit/small/<build-id> \
        --output manifests/normalized/<build-id>.json
"""

import argparse
import hashlib
import json
import os
import re
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path


TIMESTAMP_PATTERN = re.compile(
    r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?"
)


def sha256_file(path: Path) -> str:
    """Compute SHA-256 checksum of a file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def normalize_json_value(obj):
    """Recursively normalize a JSON value for comparison."""
    if isinstance(obj, dict):
        # Sort keys, remove timestamp-like values
        return {k: normalize_json_value(v) for k, v in sorted(obj.items())}
    if isinstance(obj, list):
        return [normalize_json_value(v) for v in obj]
    if isinstance(obj, str):
        # Redact timestamps
        return TIMESTAMP_PATTERN.sub("<TIMESTAMP>", obj)
    if isinstance(obj, float):
        # Round to 6 decimal places to avoid floating-point noise
        return round(obj, 6)
    return obj


def normalize_tileset(tileset_path: Path) -> dict:
    """Normalize a tileset.json for comparison."""
    with open(tileset_path, encoding="utf-8") as f:
        data = json.load(f)
    return normalize_json_value(data)


def count_subtree_bits(data: bytes, max_bits: int) -> int:
    """Count set bits in the first max_bits of data."""
    count = 0
    for i in range(min(max_bits, len(data) * 8)):
        byte_idx = i // 8
        bit_idx = i % 8
        if (data[byte_idx] >> bit_idx) & 1:
            count += 1
    return count


def inspect_subtree_counts(subtree_path: Path) -> dict:
    """Extract availability counts from a subtree file."""
    try:
        raw = subtree_path.read_bytes()
        if len(raw) < 24:
            return {"error": "too small"}
        if raw[0:4] != b"subt":
            return {"error": "bad magic"}
        json_len = struct.unpack_from("<Q", raw, 8)[0]
        bin_len = struct.unpack_from("<Q", raw, 16)[0]
        json_str = raw[24 : 24 + json_len].rstrip(b"\x00").decode("utf-8")
        header = json.loads(json_str)
        binary = raw[24 + json_len : 24 + json_len + bin_len]

        subtree_levels = header.get("subtreeLevels", 1)
        total_tiles = sum(4**i for i in range(subtree_levels))

        def get_bv_data(bv_index):
            bvs = header.get("bufferViews", [])
            if bv_index is None or bv_index >= len(bvs):
                return None
            bv = bvs[bv_index]
            off = bv.get("byteOffset", 0)
            length = bv.get("byteLength", 0)
            return binary[off : off + length]

        def avail_count(avail_obj, max_bits):
            if not avail_obj:
                return None
            constant = avail_obj.get("constant")
            if constant is not None:
                return max_bits if constant == 1 else 0
            bv_data = get_bv_data(avail_obj.get("bitstream"))
            if bv_data is None:
                return None
            return count_subtree_bits(bv_data, max_bits)

        return {
            "subtree_levels": subtree_levels,
            "tile_availability": avail_count(header.get("tileAvailability", {}), total_tiles),
            "content_availability": avail_count(
                header.get("contentAvailability", {}), total_tiles
            ),
            "child_subtree_availability": avail_count(
                header.get("childSubtreeAvailability", {}), 4**subtree_levels
            ),
        }
    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc)}


def main() -> int:
    parser = argparse.ArgumentParser(description="Normalize 3D Tiles output for comparison")
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    input_dir = args.input_dir
    if not input_dir.exists():
        print(f"ERROR: Input directory not found: {input_dir}", file=sys.stderr)
        return 1

    # Collect all files with sorted relative paths
    all_files = sorted(
        p.relative_to(input_dir) for p in input_dir.rglob("*") if p.is_file()
    )

    file_entries = []
    normalized_tileset = None

    for rel_path in all_files:
        abs_path = input_dir / rel_path
        entry = {
            "path": str(rel_path).replace(os.sep, "/"),
            "size_bytes": abs_path.stat().st_size,
            "sha256": sha256_file(abs_path),
        }

        if rel_path.name == "tileset.json":
            entry["normalized_content"] = normalize_tileset(abs_path)
            if normalized_tileset is None:
                normalized_tileset = entry["normalized_content"]

        if rel_path.suffix == ".subtree":
            entry["subtree_counts"] = inspect_subtree_counts(abs_path)

        file_entries.append(entry)

    manifest = {
        "schema_version": "1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "input_dir": str(input_dir),
        "file_count": len(file_entries),
        "normalized_tileset": normalized_tileset,
        "files": file_entries,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"Normalized manifest: {args.output} ({len(file_entries)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
