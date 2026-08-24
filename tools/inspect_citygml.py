#!/usr/bin/env python3
"""
inspect_citygml.py — Inspect PLATEAU CityGML source files.

Reads CityGML files and records:
- File count and sizes
- Building and building-part counts
- gml:id counts
- LODs present
- Polygon and surface counts
- Texture references
- CRS / srsName
- Bounding box
- PLATEAU extension attributes present

Usage:
    python3 tools/inspect_citygml.py --dataset sarabetsu \
        --source-dir data/source/sarabetsu \
        --output manifests/reports/inspect-sarabetsu.json
"""

import argparse
import json

import sys
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET


# CityGML namespaces
NS = {
    "gml": "http://www.opengis.net/gml",
    "core": "http://www.opengis.net/citygml/2.0",
    "bldg": "http://www.opengis.net/citygml/building/2.0",
    "app": "http://www.opengis.net/citygml/appearance/2.0",
    "gen": "http://www.opengis.net/citygml/generics/2.0",
    "uro": "https://www.geospatial.jp/iur/uro/3.0",
    "uro2": "https://www.geospatial.jp/iur/uro/2.0",
    "xsi": "http://www.w3.org/2001/XMLSchema-instance",
}


def find_citygml_files(source_dir: Path) -> list[Path]:
    """Find all CityGML files in source directory."""
    files = []
    for ext in ("*.gml", "*.xml", "*.GML", "*.XML"):
        files.extend(source_dir.rglob(ext))
    return sorted(files)


def inspect_file(gml_file: Path) -> dict:
    """Inspect a single CityGML file."""
    result = {
        "path": str(gml_file),
        "size_bytes": gml_file.stat().st_size,
        "building_count": 0,
        "building_part_count": 0,
        "gml_id_count": 0,
        "lods_present": [],
        "polygon_count": 0,
        "texture_reference_count": 0,
        "srs_name": None,
        "bbox": None,
        "plateau_extensions_present": [],
        "errors": [],
    }

    try:
        tree = ET.parse(gml_file)
        root = tree.getroot()

        # Get srsName from envelope
        for env_tag in [
            ".//{http://www.opengis.net/gml}Envelope",
            ".//{http://www.opengis.net/gml/3.2}Envelope",
        ]:
            env = root.find(env_tag)
            if env is not None:
                result["srs_name"] = env.get("srsName")
                lower = env.find("{http://www.opengis.net/gml}lowerCorner")
                upper = env.find("{http://www.opengis.net/gml}upperCorner")
                if lower is not None and upper is not None:
                    result["bbox"] = {
                        "lower": lower.text.strip() if lower.text else None,
                        "upper": upper.text.strip() if upper.text else None,
                    }
                break

        # Count buildings
        for ns_bldg in [
            "{http://www.opengis.net/citygml/building/2.0}Building",
            "{http://www.opengis.net/citygml/building/1.0}Building",
        ]:
            buildings = root.findall(f".//{ns_bldg}")
            result["building_count"] += len(buildings)

        # Count building parts
        for ns_bldg_part in [
            "{http://www.opengis.net/citygml/building/2.0}BuildingPart",
            "{http://www.opengis.net/citygml/building/1.0}BuildingPart",
        ]:
            parts = root.findall(f".//{ns_bldg_part}")
            result["building_part_count"] += len(parts)

        # Count gml:id attributes
        gml_ids = set()
        for elem in root.iter():
            gid = elem.get("{http://www.opengis.net/gml}id") or elem.get(
                "{http://www.opengis.net/gml/3.2}id"
            )
            if gid:
                gml_ids.add(gid)
        result["gml_id_count"] = len(gml_ids)

        # Detect LODs present
        lods = set()
        for elem in root.iter():
            tag = elem.tag
            if "lod1" in tag.lower():
                lods.add(1)
            elif "lod2" in tag.lower():
                lods.add(2)
            elif "lod3" in tag.lower():
                lods.add(3)
            elif "lod4" in tag.lower():
                lods.add(4)
        result["lods_present"] = sorted(lods)

        # Count polygons
        polygon_count = 0
        for poly_tag in [
            "{http://www.opengis.net/gml}Polygon",
            "{http://www.opengis.net/gml/3.2}Polygon",
        ]:
            polygon_count += len(root.findall(f".//{poly_tag}"))
        result["polygon_count"] = polygon_count

        # Count texture references
        tex_count = 0
        for tex_tag in [
            "{http://www.opengis.net/citygml/appearance/2.0}imageURI",
            "{http://www.opengis.net/citygml/appearance/1.0}imageURI",
        ]:
            tex_count += len(root.findall(f".//{tex_tag}"))
        result["texture_reference_count"] = tex_count

        # Detect PLATEAU URO extensions
        uro_attrs = set()
        for elem in root.iter():
            if "uro" in elem.tag.lower() or "iur" in elem.tag.lower():
                # Get local name
                local = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
                uro_attrs.add(local)
        result["plateau_extensions_present"] = sorted(uro_attrs)

    except ET.ParseError as exc:
        result["errors"].append(f"XML parse error: {exc}")
    except Exception as exc:  # noqa: BLE001
        result["errors"].append(f"Unexpected error: {exc}")

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect PLATEAU CityGML source files")
    parser.add_argument("--dataset", required=True, help="Dataset name (e.g. sarabetsu)")
    parser.add_argument(
        "--source-dir", required=True, type=Path, help="Directory containing CityGML files"
    )
    parser.add_argument("--output", required=True, type=Path, help="Output JSON report path")
    args = parser.parse_args()

    source_dir = args.source_dir
    if not source_dir.exists():
        print(f"ERROR: Source directory not found: {source_dir}", file=sys.stderr)
        return 1

    files = find_citygml_files(source_dir)
    if not files:
        print(f"WARNING: No CityGML files found in {source_dir}", file=sys.stderr)

    print(f"Inspecting {len(files)} CityGML file(s) in {source_dir}")

    file_results = []
    total_buildings = 0
    total_parts = 0
    total_gml_ids = 0
    all_lods: set[int] = set()
    total_polygons = 0
    total_textures = 0
    all_srs: set[str] = set()

    for gml_file in files:
        print(f"  {gml_file.name} ...", end="", flush=True)
        res = inspect_file(gml_file)
        file_results.append(res)
        total_buildings += res["building_count"]
        total_parts += res["building_part_count"]
        total_gml_ids += res["gml_id_count"]
        all_lods.update(res["lods_present"])
        total_polygons += res["polygon_count"]
        total_textures += res["texture_reference_count"]
        if res["srs_name"]:
            all_srs.add(res["srs_name"])
        status = "errors" if res["errors"] else "ok"
        print(f" [{status}] buildings={res['building_count']}")

    report = {
        "schema_version": "1",
        "dataset": args.dataset,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_dir": str(source_dir),
        "summary": {
            "file_count": len(files),
            "total_building_count": total_buildings,
            "total_building_part_count": total_parts,
            "total_gml_id_count": total_gml_ids,
            "lods_present": sorted(all_lods),
            "total_polygon_count": total_polygons,
            "total_texture_reference_count": total_textures,
            "srs_names": sorted(all_srs),
        },
        "files": file_results,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print("\nSummary:")
    print(f"  Files:     {len(files)}")
    print(f"  Buildings: {total_buildings}")
    print(f"  LODs:      {sorted(all_lods)}")
    print(f"  SRS:       {sorted(all_srs)}")
    print(f"\nReport written to: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
