#!/usr/bin/env python3
"""
normalize.py — Normalize 3D Tiles output for determinism comparison.

Creates a normalized manifest from a build output directory that:
- Sorts file paths
- Normalizes tileset.json (sorts keys, removes timestamps)
- Records file checksums
- Decodes subtree availability (both the combined-binary .subtree format
  and the JSON+external-.bin form mago-3d-tiler actually produces)
- Normalizes GLB content by redacting per-run-random UUID-shaped
  structural-metadata property values before hashing (does not compare
  mesh/accessor content itself — see docs/findings.md Phase 3)

Usage:
    python3 tools/normalize.py \
        --input-dir data/output/sarabetsu/implicit/small/<build-id> \
        --output manifests/normalized/<build-id>.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

# Make the sibling tools/subtree_common.py importable regardless of how
# this script is invoked — both `python3 tools/normalize.py` (which puts
# tools/ itself on sys.path) and `import tools.normalize` from a context
# with only the repo root on sys.path (e.g. tests/run-tests.sh) need to
# resolve the same bare `import subtree_common`.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import subtree_common  # noqa: E402
from subtree_common import find_subtree_levels, is_subtree_json  # noqa: E402

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


def _subtree_availability(header: dict, binary: bytes, subtree_levels: int) -> dict:
    """Shared availability-decoding logic for both subtree encodings, built
    on the low-level primitives in tools/subtree_common.py."""
    total_tiles = sum(4**i for i in range(subtree_levels))
    buffer_views = header.get("bufferViews", [])

    return {
        "subtree_levels": subtree_levels,
        "tile_availability": subtree_common.count_availability(
            header.get("tileAvailability", {}), total_tiles, buffer_views, binary
        ),
        "content_availability": subtree_common.count_availability_multi(
            header.get("contentAvailability", {}), total_tiles, buffer_views, binary
        ),
        "child_subtree_availability": subtree_common.count_availability(
            header.get("childSubtreeAvailability", {}), 4**subtree_levels, buffer_views, binary
        ),
    }


def inspect_subtree_counts(subtree_path: Path, subtree_levels: int) -> dict:
    """Decode the combined-binary .subtree format (magic 'subt' + header)."""
    try:
        raw = subtree_path.read_bytes()
        if len(raw) < 24:
            return {"error": "too small"}
        if raw[0:4] != b"subt":
            return {"error": "bad magic"}
        parsed = subtree_common.parse_binary_subtree(subtree_path)
        if parsed["header"] is None:
            return {"error": "; ".join(parsed["errors"]) or "unknown parse error"}
        result = _subtree_availability(parsed["header"], parsed["binary_data"], subtree_levels)
        result["format"] = "binary"
        return result
    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc)}


def inspect_subtree_json_bin(json_path: Path, subtree_levels: int) -> dict:
    """Decode a subtree delivered as JSON + external .bin buffer."""
    try:
        loaded = subtree_common.load_json_bin_subtree(json_path)
        result = _subtree_availability(loaded["header"], loaded["binary_data"], subtree_levels)
        result["format"] = "json+bin"
        return result
    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc)}


GLB_UUID_PATTERN = re.compile(
    rb"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)


def _decode_glb_chunks(data: bytes):
    """Return (gltf_dict, bin_bytearray_or_None), or None if not a decodable GLB."""
    if len(data) < 12 or data[0:4] != b"glTF":
        return None
    offset = 12
    if offset + 8 > len(data):
        return None
    json_len, json_type = struct.unpack_from("<II", data, offset)
    if json_type != 0x4E4F534A:  # 'JSON'
        return None
    try:
        gltf = json.loads(data[offset + 8 : offset + 8 + json_len])
    except json.JSONDecodeError:
        return None
    offset2 = offset + 8 + json_len
    bin_bytes = None
    if offset2 + 8 <= len(data):
        bin_len, bin_type = struct.unpack_from("<II", data, offset2)
        if bin_type == 0x004E4942:  # 'BIN\0'
            start = offset2 + 8
            bin_bytes = bytearray(data[start : start + bin_len])
    return gltf, bin_bytes


def normalize_glb(glb_path: Path) -> dict:
    """Normalize a GLB for comparison by redacting per-run-random
    EXT_structural_metadata string properties (detected as UUID-shaped
    values, e.g. mago-3d-tiler's generated "id" property) before hashing,
    so a benign, non-geometric random ID doesn't register as a structural
    difference between two builds of identical input. See
    docs/findings.md Phase 3."""
    decoded = _decode_glb_chunks(glb_path.read_bytes())
    if decoded is None:
        return {"error": "not a decodable GLB"}
    gltf, bin_bytes = decoded

    redacted = 0
    if bin_bytes is not None:
        buffer_views = gltf.get("bufferViews", [])
        for ext in (gltf.get("extensions") or {}).values():
            if not isinstance(ext, dict):
                continue
            for pt in ext.get("propertyTables") or []:
                for prop in (pt.get("properties") or {}).values():
                    bv_idx = prop.get("values")
                    if bv_idx is None or not (0 <= bv_idx < len(buffer_views)):
                        continue
                    bv = buffer_views[bv_idx]
                    start = bv.get("byteOffset", 0)
                    length = bv.get("byteLength", 0)
                    if start + length > len(bin_bytes):
                        continue
                    segment = bytes(bin_bytes[start : start + length])
                    if GLB_UUID_PATTERN.match(segment):
                        bin_bytes[start : start + length] = b"\x00" * length
                        redacted += 1

    hasher = hashlib.sha256()
    hasher.update(json.dumps(normalize_json_value(gltf), sort_keys=True).encode("utf-8"))
    if bin_bytes is not None:
        hasher.update(bytes(bin_bytes))
    return {"normalized_sha256": hasher.hexdigest(), "redacted_property_count": redacted}


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

    # Resolved once upfront (not discovered mid-loop): subtree files never
    # declare their own subtreeLevels, so it must come from tileset.json.
    # None (Explicit mode, or missing tileset.json) is fine as long as no
    # subtree files are actually present to decode.
    subtree_levels = find_subtree_levels(input_dir)

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
        elif rel_path.suffix == ".json":
            # Real mago-3d-tiler subtree files have no fixed name (e.g.
            # "0.json") — detect by content shape, not filename.
            try:
                parsed = json.loads(abs_path.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError, json.JSONDecodeError):
                parsed = None
            if is_subtree_json(parsed):
                entry["subtree_counts"] = (
                    inspect_subtree_json_bin(abs_path, subtree_levels)
                    if subtree_levels is not None
                    else {"error": "tileset.json implicitTiling.subtreeLevels not found"}
                )

        if rel_path.suffix == ".subtree":
            entry["subtree_counts"] = (
                inspect_subtree_counts(abs_path, subtree_levels)
                if subtree_levels is not None
                else {"error": "tileset.json implicitTiling.subtreeLevels not found"}
            )

        if rel_path.suffix == ".glb":
            entry["glb_normalized"] = normalize_glb(abs_path)

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
