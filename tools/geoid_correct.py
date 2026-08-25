#!/usr/bin/env python3
"""
geoid_correct.py — Convert PLATEAU CityGML building height values from
orthometric (elevation above Tokyo Bay mean sea level) to ellipsoidal
height (above the GRS80/WGS84 ellipsoid), before a file reaches Mago
3DTiler.

Why: PLATEAU's own documentation
(https://www.mlit.go.jp/plateau/learning/tpc03-4/) states building
heights are referenced to Tokyo Bay mean sea level, not the ellipsoid —
even though both datasets this project uses declare EPSG:6697 (JGD2011,
geographic 3D), which is nominally an ellipsoidal-height CRS by
definition. Verified empirically (2026-08-26/27, see docs/findings.md
"Cross-phase follow-up: terrain/building vertical datum mismatch"):
sampled real elevation at 17 building coordinates across both
municipalities against two independent, correctly-ellipsoidal terrain
services (Re:Earth Terrain and PLATEAU-Terrain, the latter operated by
Eukarya as part of the official PLATEAU VIEW infrastructure) and found
buildings sitting a tight, per-municipality-constant 28-34m *below* the
real terrain surface — matching each site's GSIGEO2011 geoid undulation
to within a few centimeters. `scripts/build.sh`'s `--proj
+axis=neu` fix only corrects horizontal axis order; it passes the Z
value straight through unchanged, so Mago places buildings at the raw
orthometric value while 3D Tiles/CesiumJS (and any correctly-built
terrain) both treat height as ellipsoidal.

This script closes that gap the same way PLATEAU's own officially
recommended FME workflow does ("Vertical Transformation with
GSIGEO2011"): ellipsoidal height = orthometric height + geoid height (N),
using the `japan-geoid` package (MIT license,
https://github.com/ciscorn/japan-geoid), which embeds GSI's own
GSIGEO2011 grid — the same model PLATEAU-Terrain and PLATEAU's official
conversion tooling use, chosen over the newer JPGEO2024 specifically for
that consistency. This is the only third-party Python dependency in this
project (see requirements.txt) — CLAUDE.md's "standard library only"
convention was discussed with and approved by the user before adding it.

Scope: only corrects gml:posList/gml:pos elements found within
bldg:Building/bldg:BuildingPart (mirrors tools/strip_higher_lod.py's
scoping) — i.e. the actual placement geometry Mago converts. Does not
touch gml:Envelope bounding boxes or anything outside a building element.
Coordinate axis order is assumed (lat, lon, height) per EPSG:6697
+axis=neu, matching config/<dataset>.yml's crs.mago_proj and
scripts/build.sh's CRS handling — a 2-value (lat, lon only) pos/posList
is left untouched rather than guessed at.

Never modifies data/source/ in place — always reads one file and writes
to a separate output path.

Usage:
    python3 tools/geoid_correct.py <input.gml> <output.gml>
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from japan_geoid import load_embedded_gsigeo2011

BLDG_NS = "http://www.opengis.net/citygml/building/2.0"

_GEOID = load_embedded_gsigeo2011()


def _local_name(tag: str) -> str:
    """Strip the {namespace} prefix ElementTree tags carry."""
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _correct_coord_text(text: str) -> tuple[str, int]:
    """Add geoid undulation to every third value (height) in a
    "lat lon height lat lon height ..." whitespace-separated list.

    Returns (new_text, number_of_triplets_corrected). A list whose length
    isn't a multiple of 3 (e.g. a 2D pos with no height) is returned
    unchanged.
    """
    nums = text.split()
    if not nums or len(nums) % 3 != 0:
        return text, 0

    out = []
    count = 0
    for i in range(0, len(nums), 3):
        lat_s, lon_s, h_s = nums[i], nums[i + 1], nums[i + 2]
        lat, lon, h = float(lat_s), float(lon_s), float(h_s)
        # japan_geoid's get_height takes (longitude, latitude).
        n = _GEOID.get_height(lon, lat)
        out.extend([lat_s, lon_s, repr(h + n)])
        count += 1
    return " ".join(out), count


def geoid_correct(input_path: Path, output_path: Path) -> dict:
    """Add GSIGEO2011 geoid undulation to every building's coordinate
    heights in a CityGML file.

    Returns a summary dict for logging/verification.
    """
    # Register every namespace prefix actually declared on the root
    # element before parsing, so ET.write() round-trips the same
    # prefixes instead of inventing ns0/ns1 aliases — same approach as
    # tools/strip_higher_lod.py.
    for _, (prefix, uri) in ET.iterparse(str(input_path), events=["start-ns"]):
        ET.register_namespace(prefix, uri)

    tree = ET.parse(str(input_path))
    root = tree.getroot()

    building_tags = {f"{{{BLDG_NS}}}Building", f"{{{BLDG_NS}}}BuildingPart"}
    buildings = 0
    triplets = 0

    for building in root.iter():
        if building.tag not in building_tags:
            continue
        buildings += 1
        for elem in building.iter():
            if _local_name(elem.tag) not in ("posList", "pos"):
                continue
            if not elem.text or not elem.text.strip():
                continue
            new_text, count = _correct_coord_text(elem.text.strip())
            if count:
                elem.text = new_text
                triplets += count

    output_path.parent.mkdir(parents=True, exist_ok=True)
    tree.write(str(output_path), encoding="UTF-8", xml_declaration=True)

    return {"buildings": buildings, "coordinate_triplets_corrected": triplets}


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.gml> <output.gml>", file=sys.stderr)
        return 1

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not input_path.is_file():
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        return 1

    stats = geoid_correct(input_path, output_path)
    print(
        f"{input_path.name}: corrected "
        f"{stats['coordinate_triplets_corrected']} coordinate triplet(s) "
        f"across {stats['buildings']} building(s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
