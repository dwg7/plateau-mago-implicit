#!/usr/bin/env python3
"""
strip_higher_lod.py — Remove non-LOD1 building geometry from a PLATEAU
CityGML file before it reaches Mago 3DTiler.

Why: PLATEAU building records can carry multiple LOD geometries for the
same bldg:Building/bldg:BuildingPart (lod0FootPrint/lod0RoofEdge,
lod1Solid, lod3Solid/lod3Geometry/lod3MultiSurface — no lod2 elements
were found in either dataset this project uses). Mago 3DTiler doesn't
pick one; it converts every geometry element it finds, producing one
sibling tile branch per LOD, all loaded together via `refine: ADD`. For
buildings that only have LOD0+LOD1, this looks like a flat footprint
z-fighting against the solid roof. For a handful of buildings that also
carry real LOD3 detail (found 2026-08-26: 4 buildings in Sarabetsu's
63437175_bldg_6697_op.gml, up to 2004 lod3MultiSurface elements and 5.5MB
of XML for one building alone), up to four overlapping representations
of the same building can end up loaded simultaneously.

CLAUDE.md's scope boundary is explicit: this project's baseline is LOD1
only; higher LOD is Phase 7 territory, kept separate. This script
enforces that boundary at the source-data level, before conversion,
rather than trying to filter or restyle Mago's output after the fact
(which has no supported way to do this — --minLod/--maxLod control
Mago's own internal tiling refinement depth, not which PLATEAU LOD is
used, confirmed empirically; see docs/findings.md).

Scope of what this actually removes, checked empirically (2026-08-26):
this only removes lodN-prefixed elements that are *direct children* of
bldg:Building/bldg:BuildingPart (lod0FootPrint, lod0RoofEdge, lod3Solid,
lod3Geometry). It deliberately does NOT descend into bldg:boundedBy
(WallSurface/RoofSurface/GroundSurface, which can carry their own
lod3MultiSurface) or bldg:outerBuildingInstallation/innerBuildingInstallation
— removing those correctly would mean cleaning up now-empty wrapper
elements too, real added complexity. Tested whether skipping them still
matters: ran Mago on 63437175_bldg_6697_op.gml (the 15.3MB, 826-building,
4-buildings-with-LOD3 file) with and without this stripping. Direct-child
stripping alone dropped the batched feature count from 5,288 to 4,470 —
a reduction of exactly 818, matching the 818 lod0FootPrint elements
removed — and total output size fell only ~6.5% despite the file
containing 7,292 lod3MultiSurface elements nested in boundary surfaces.
That's strong evidence Mago's own mesh generation is driven by the
direct-child Solid/MultiSurface declarations, not the nested boundary-
surface breakdown, so leaving the latter in place doesn't reintroduce
the overlapping-geometry problem this script exists to fix — but if a
future PLATEAU dataset or Mago version behaves differently, that
assumption should be re-checked the same way (a before/after Mago run,
not just counting XML elements).

Never modifies data/source/ in place — always reads one file and writes
to a separate output path, so the checksummed, verified source archive
extraction stays untouched.

Usage:
    python3 tools/strip_higher_lod.py <input.gml> <output.gml>
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

BLDG_NS = "http://www.opengis.net/citygml/building/2.0"

# Any direct child of bldg:Building / bldg:BuildingPart whose local name
# matches this is a per-LOD geometry element. Keep only lod1*.
KEPT_LOD = "lod1"


def _local_name(tag: str) -> str:
    """Strip the {namespace} prefix ElementTree tags carry."""
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def strip_higher_lod(input_path: Path, output_path: Path) -> dict:
    """Remove non-LOD1 geometry elements from a CityGML file.

    Returns a summary dict: how many elements were removed, grouped by
    tag name, for logging/verification.
    """
    # Register every namespace prefix actually declared on the root
    # element before parsing, so ET.write() round-trips the same
    # prefixes (bldg:, gml:, core:, ...) instead of inventing ns0/ns1
    # aliases. ET's global registry is fine here — this process only
    # ever handles one file at a time (invoked once per file by
    # scripts/build.sh's staging step).
    for _, (prefix, uri) in ET.iterparse(str(input_path), events=["start-ns"]):
        ET.register_namespace(prefix, uri)

    tree = ET.parse(str(input_path))
    root = tree.getroot()

    removed_counts: dict[str, int] = {}
    building_tags = {f"{{{BLDG_NS}}}Building", f"{{{BLDG_NS}}}BuildingPart"}

    for building in root.iter():
        if building.tag not in building_tags:
            continue
        to_remove = []
        for child in list(building):
            if _local_name(child.tag).lower().startswith("lod") and not _local_name(
                child.tag
            ).lower().startswith(KEPT_LOD):
                to_remove.append(child)
        for child in to_remove:
            building.remove(child)
            removed_counts[_local_name(child.tag)] = (
                removed_counts.get(_local_name(child.tag), 0) + 1
            )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(str(output_path), encoding="UTF-8", xml_declaration=True)

    return removed_counts


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.gml> <output.gml>", file=sys.stderr)
        return 1

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not input_path.is_file():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        return 1

    removed = strip_higher_lod(input_path, output_path)
    total = sum(removed.values())
    print(f"{input_path.name}: removed {total} element(s): {removed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
