#!/usr/bin/env python3
"""
summarize_metrics.py — Summarize experiment metrics from a build directory.

Usage:
    python3 tools/summarize_metrics.py \
        --build-dir data/output/sarabetsu/implicit/small/<build-id> \
        [--manifest manifests/builds/<build-id>.yml]
"""

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


def collect_file_stats(build_dir: Path) -> dict:
    """Collect file size statistics from build output."""
    stats: dict[str, list[int]] = defaultdict(list)
    total_size = 0
    total_count = 0

    for p in build_dir.rglob("*"):
        if not p.is_file():
            continue
        size = p.stat().st_size
        ext = p.suffix.lower() or "no-ext"
        stats[ext].append(size)
        total_size += size
        total_count += 1

    per_ext = {}
    for ext, sizes in sorted(stats.items()):
        per_ext[ext] = {
            "count": len(sizes),
            "total_bytes": sum(sizes),
            "min_bytes": min(sizes),
            "max_bytes": max(sizes),
            "mean_bytes": int(sum(sizes) / len(sizes)) if sizes else 0,
        }

    return {
        "total_file_count": total_count,
        "total_bytes": total_size,
        "by_extension": per_ext,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize experiment metrics")
    parser.add_argument("--build-dir", required=True, type=Path)
    parser.add_argument(
        "--manifest",
        required=False,
        type=Path,
        help="Optional path to write or append metrics summary (JSON Lines)",
    )
    args = parser.parse_args()

    build_dir = args.build_dir
    if not build_dir.exists():
        print(f"ERROR: Build directory not found: {build_dir}", file=sys.stderr)
        return 1

    stats = collect_file_stats(build_dir)

    # Print summary
    print(f"Build directory: {build_dir}")
    print(f"Total files:     {stats['total_file_count']}")
    print(f"Total size:      {stats['total_bytes']:,} bytes")
    print("")
    print("By extension:")
    for ext, info in stats["by_extension"].items():
        print(
            f"  {ext:12s}  count={info['count']:5d}  "
            f"total={info['total_bytes']:12,}  "
            f"mean={info['mean_bytes']:8,}  "
            f"max={info['max_bytes']:8,}"
        )

    # Write metrics to manifest file if requested
    if args.manifest:
        metrics_record = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "build_dir": str(build_dir),
            "file_stats": stats,
        }
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        with open(args.manifest, "a", encoding="utf-8") as f:
            f.write(json.dumps(metrics_record, ensure_ascii=False) + "\n")
        print(f"\nMetrics appended to: {args.manifest}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
