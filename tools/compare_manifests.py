#!/usr/bin/env python3
"""
compare_manifests.py — Compare two normalized build manifests for determinism.

Classifies differences as:
  byte-only, serialization-only, structural, hierarchy, availability,
  geometry, metadata, identifier, unexplained

Usage:
    python3 tools/compare_manifests.py \
        --build1 manifests/normalized/build1.json \
        --build2 manifests/normalized/build2.json \
        --output-json manifests/reports/comparison.json \
        --output-md manifests/reports/comparison.md
"""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


REPEATABILITY_LEVELS = {
    "L1": "Byte-identical",
    "L2": "Structurally identical after normalization",
    "L3": "Semantically equivalent but structurally different",
}


def load_manifest(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def build_file_index(manifest: dict) -> dict[str, dict]:
    """Build a dict from relative path to file entry."""
    return {entry["path"]: entry for entry in manifest.get("files", [])}


def compare_manifests(m1: dict, m2: dict) -> dict:
    """Compare two normalized manifests and return a comparison report."""
    idx1 = build_file_index(m1)
    idx2 = build_file_index(m2)

    paths1 = set(idx1.keys())
    paths2 = set(idx2.keys())

    only_in_1 = sorted(paths1 - paths2)
    only_in_2 = sorted(paths2 - paths1)
    common = sorted(paths1 & paths2)

    differences = []

    for path in common:
        e1 = idx1[path]
        e2 = idx2[path]

        sha1 = e1.get("sha256")
        sha2 = e2.get("sha256")
        size1 = e1.get("size_bytes")
        size2 = e2.get("size_bytes")

        if sha1 == sha2:
            continue

        diff_entry = {
            "path": path,
            "sha256_1": sha1,
            "sha256_2": sha2,
            "size_1": size1,
            "size_2": size2,
            "category": "unexplained",
        }

        # Classify based on file type
        if path.endswith(".json") or path == "tileset.json":
            norm1 = e1.get("normalized_content")
            norm2 = e2.get("normalized_content")
            if norm1 is not None and norm2 is not None:
                if norm1 == norm2:
                    diff_entry["category"] = "serialization-only"
                else:
                    diff_entry["category"] = "structural"
                    diff_entry["normalized_differ"] = True
            else:
                diff_entry["category"] = "structural"

        elif path.endswith(".subtree") or e1.get("subtree_counts") is not None:
            # Combined-binary .subtree files match on extension; real
            # mago-3d-tiler JSON+bin subtrees have no fixed name, so also
            # catch them via the subtree_counts field normalize.py attaches.
            sc1 = e1.get("subtree_counts", {})
            sc2 = e2.get("subtree_counts", {})
            if sc1 == sc2:
                diff_entry["category"] = "byte-only"
            else:
                diff_entry["category"] = "availability"
                diff_entry["subtree_counts_1"] = sc1
                diff_entry["subtree_counts_2"] = sc2

        elif path.endswith(".glb"):
            # Raw bytes differing doesn't necessarily mean the geometry
            # differs — mago-3d-tiler embeds a fresh random UUID in
            # structural metadata on every run (see docs/findings.md
            # Phase 3). normalize.py's glb_normalized.normalized_sha256
            # redacts that before hashing; prefer it when available so a
            # benign per-run ID doesn't register as a geometry difference.
            gn1 = e1.get("glb_normalized", {}).get("normalized_sha256")
            gn2 = e2.get("glb_normalized", {}).get("normalized_sha256")
            if gn1 is not None and gn2 is not None:
                diff_entry["category"] = "byte-only" if gn1 == gn2 else "geometry"
            else:
                diff_entry["category"] = "geometry"

        differences.append(diff_entry)

    # Determine repeatability level
    structural_diffs = [d for d in differences if d["category"] not in ("byte-only", "serialization-only")]
    byte_only_diffs = [d for d in differences if d["category"] in ("byte-only", "serialization-only")]

    if not differences and not only_in_1 and not only_in_2:
        level = "L1"
    elif not structural_diffs and not only_in_1 and not only_in_2:
        level = "L2"
    else:
        level = "L3"

    # Categorize difference types
    categories: dict[str, int] = {}
    for d in differences:
        cat = d["category"]
        categories[cat] = categories.get(cat, 0) + 1

    return {
        "schema_version": "1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repeatability_level": level,
        "repeatability_description": REPEATABILITY_LEVELS[level],
        "determinism_pass": level in ("L1", "L2"),
        "summary": {
            "common_files": len(common),
            "only_in_build1": len(only_in_1),
            "only_in_build2": len(only_in_2),
            "files_with_differences": len(differences),
            "byte_only_differences": len(byte_only_diffs),
            "structural_differences": len(structural_diffs),
            "difference_categories": categories,
        },
        "only_in_build1": only_in_1,
        "only_in_build2": only_in_2,
        "differences": differences,
    }


def render_markdown(report: dict, build1_path: str, build2_path: str) -> str:
    """Render the comparison report as Markdown."""
    level = report["repeatability_level"]
    passed = "✓ PASS" if report["determinism_pass"] else "✗ FAIL"
    lines = [
        "# Build comparison report",
        "",
        f"- **Build 1:** `{build1_path}`",
        f"- **Build 2:** `{build2_path}`",
        f"- **Generated:** {report['generated_at']}",
        "",
        "## Repeatability",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Level | {level} — {REPEATABILITY_LEVELS[level]} |",
        f"| Determinism | {passed} |",
        "",
        "## Summary",
        "",
        "| Metric | Count |",
        "|---|---|",
    ]
    s = report["summary"]
    lines += [
        f"| Common files | {s['common_files']} |",
        f"| Only in build 1 | {s['only_in_build1']} |",
        f"| Only in build 2 | {s['only_in_build2']} |",
        f"| Files with differences | {s['files_with_differences']} |",
        f"| Byte-only/serialization differences | {s['byte_only_differences']} |",
        f"| Structural differences | {s['structural_differences']} |",
    ]
    lines.append("")
    if report["only_in_build1"]:
        lines += ["## Only in build 1", ""]
        for p in report["only_in_build1"]:
            lines.append(f"- `{p}`")
        lines.append("")
    if report["only_in_build2"]:
        lines += ["## Only in build 2", ""]
        for p in report["only_in_build2"]:
            lines.append(f"- `{p}`")
        lines.append("")
    if report["differences"]:
        lines += ["## Differences", "", "| Path | Category | Notes |", "|---|---|---|"]
        for d in report["differences"]:
            notes = ""
            if d.get("subtree_counts_1"):
                notes = "subtree counts differ"
            lines.append(f"| `{d['path']}` | {d['category']} | {notes} |")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two normalized build manifests")
    parser.add_argument("--build1", required=True, type=Path)
    parser.add_argument("--build2", required=True, type=Path)
    parser.add_argument("--output-json", required=True, type=Path)
    parser.add_argument("--output-md", required=True, type=Path)
    args = parser.parse_args()

    m1 = load_manifest(args.build1)
    m2 = load_manifest(args.build2)

    report = compare_manifests(m1, m2)

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output_json, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output_md, "w", encoding="utf-8") as f:
        f.write(render_markdown(report, str(args.build1), str(args.build2)))

    level = report["repeatability_level"]
    passed = "PASS" if report["determinism_pass"] else "FAIL"
    print(f"Repeatability: {level} ({REPEATABILITY_LEVELS[level]})")
    print(f"Determinism:   {passed}")
    print(f"Report (JSON): {args.output_json}")
    print(f"Report (MD):   {args.output_md}")

    return 0 if report["determinism_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
