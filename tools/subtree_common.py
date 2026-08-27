#!/usr/bin/env python3
"""
subtree_common.py — Shared 3D Tiles Implicit Tiling subtree-decoding
primitives, used by both tools/inspect_subtree.py and tools/normalize.py.

Both tools independently re-implemented (and independently needed the
same two bugfixes for — see docs/findings.md Phase 2)
`find_subtree_levels()` and `is_subtree_json()`, plus near-identical
bit-counting/availability-decoding logic. Extracted here as a pure
refactor: each tool's own output shape/behavior is unchanged, only the
low-level parsing primitives moved. Deliberately does NOT unify error
handling for magic-byte/version mismatches, since the two tools already
treated those differently before this refactor (inspect_subtree.py
reports a version mismatch as a warning, not an error; normalize.py never
checked the version field at all) — callers still make that judgment
themselves using the raw `magic`/`version` fields this module returns.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

SUBTREE_MAGIC = b"subt"
SUBTREE_VERSION = 1
SUBTREE_JSON_KEYS = {"tileAvailability", "contentAvailability", "childSubtreeAvailability"}


def count_bits(data: bytes, bit_count: int) -> int:
    """Count the number of set bits in the first bit_count bits of data."""
    count = 0
    for i in range(bit_count):
        byte_idx = i // 8
        bit_idx = i % 8
        if byte_idx < len(data) and (data[byte_idx] >> bit_idx) & 1:
            count += 1
    return count


def is_subtree_json(data) -> bool:
    """Detect a real mago-3d-tiler-style subtree JSON by content shape,
    since these files have no fixed name (e.g. "0.json") — path/filename
    can't distinguish them from any other JSON output."""
    return isinstance(data, dict) and bool(SUBTREE_JSON_KEYS & data.keys())


def find_subtree_levels(input_dir: Path) -> int | None:
    """Read implicitTiling.subtreeLevels from the build's tileset.json.

    Subtree files themselves never declare this field — per the 3D Tiles
    1.1 spec it's inherited from the tileset's implicitTiling block, not
    encoded in the subtree JSON/binary header. See docs/findings.md
    Phase 2 for why this must come from tileset.json, not the subtree
    file's own header (which silently defaults to 1 and undercounts
    availability if read from there)."""
    tileset_path = input_dir / "tileset.json"
    if not tileset_path.exists():
        return None
    try:
        data = json.loads(tileset_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None

    def _search(tile):
        if not isinstance(tile, dict):
            return None
        implicit = tile.get("implicitTiling")
        if implicit and "subtreeLevels" in implicit:
            return implicit["subtreeLevels"]
        for child in tile.get("children", []) or []:
            found = _search(child)
            if found is not None:
                return found
        return None

    return _search(data.get("root", {}))


def get_buffer_view_bytes(buffer_views: list, bv_index, binary_data: bytes):
    """Slice out one bufferView's bytes from a subtree's binary chunk."""
    if bv_index is None or bv_index >= len(buffer_views):
        return None
    bv = buffer_views[bv_index]
    off = bv.get("byteOffset", 0)
    length = bv.get("byteLength", 0)
    if len(binary_data) >= off + length:
        return binary_data[off : off + length]
    return None


def count_availability(availability_obj, max_bits: int, buffer_views: list, binary_data: bytes):
    """Count set bits for one availability object (tileAvailability,
    childSubtreeAvailability, or one entry of contentAvailability) —
    either a `constant` (0/1 for all bits) or a `bitstream` bufferView
    index."""
    if not availability_obj:
        return None
    constant = availability_obj.get("constant")
    if constant is not None:
        return max_bits if constant == 1 else 0
    bv_data = get_buffer_view_bytes(buffer_views, availability_obj.get("bitstream"), binary_data)
    if bv_data is None:
        return None
    return count_bits(bv_data, max_bits)


def count_availability_multi(availability_obj, max_bits: int, buffer_views: list, binary_data: bytes):
    """contentAvailability is an array (one entry per content slot per
    tile, e.g. multiple LODs) per the 3D Tiles 1.1 spec — mago-3d-tiler
    emits it as a one-element list even for a single content slot.
    tileAvailability/childSubtreeAvailability are always single objects."""
    if isinstance(availability_obj, list):
        return sum(
            count_availability(a, max_bits, buffer_views, binary_data) or 0
            for a in availability_obj
        )
    return count_availability(availability_obj, max_bits, buffer_views, binary_data)


def parse_binary_subtree(path: Path) -> dict:
    """Parse the combined-binary .subtree container format: magic (4),
    version (4), json_byte_length (8), binary_byte_length (8), then the
    JSON header and binary chunk.

    Returns a dict: magic (str), version (int), json_byte_length,
    binary_byte_length, header (parsed dict, or None if unparseable),
    binary_data (bytes), errors (list of str — only structural problems
    both existing callers already treated as fatal: too-small file, a
    size mismatch, or a JSON parse failure; magic/version mismatches are
    NOT included here, see module docstring).
    """
    result = {
        "magic": None,
        "version": None,
        "json_byte_length": None,
        "binary_byte_length": None,
        "header": None,
        "binary_data": b"",
        "errors": [],
    }
    data = path.read_bytes()
    if len(data) < 24:
        result["errors"].append(f"File too small: {len(data)} bytes (minimum 24)")
        return result

    result["magic"] = data[0:4].decode("ascii", errors="replace")
    result["version"] = struct.unpack_from("<I", data, 4)[0]

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

    json_bytes = data[header_size : header_size + json_byte_length]
    try:
        json_str = json_bytes.rstrip(b"\x00").decode("utf-8")
        result["header"] = json.loads(json_str)
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        result["errors"].append(f"JSON header parse error: {exc}")
        return result

    binary_offset = header_size + json_byte_length
    result["binary_data"] = data[binary_offset : binary_offset + binary_byte_length]
    return result


def load_json_bin_subtree(json_path: Path) -> dict:
    """Load a subtree delivered as JSON + external .bin buffer (what
    mago-3d-tiler 1.16.2 actually produces — see docs/findings.md
    Phase 1/2). Returns {header, binary_data, errors}."""
    result = {"header": None, "binary_data": b"", "errors": []}
    header = json.loads(json_path.read_text(encoding="utf-8"))
    result["header"] = header
    buffers = header.get("buffers", [])
    if buffers:
        bin_path = json_path.parent / buffers[0].get("uri", "")
        if bin_path.exists():
            result["binary_data"] = bin_path.read_bytes()
        else:
            result["errors"].append(f"Referenced buffer not found: {bin_path}")
    return result
