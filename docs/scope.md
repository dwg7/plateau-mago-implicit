# Scope

## Municipalities

### Sarabetsu Village (更別村)

- **Role:** First and smaller target
- **Purpose:** Establish the small-to-municipal workflow, parsing behavior, coordinate
  correctness, Explicit versus Implicit comparison, and repeated-build repeatability
- **Starting point:** One small building CityGML file
- **LOD:** LOD1 in baseline
- **Higher LOD/texture:** Optional in Phase 7

### Muroran City (室蘭市)

- **Role:** Second and more demanding target
- **Purpose:** Test denser urban distribution, coastal terrain variation, larger output
  volume, subtree organization, and CesiumJS behavior at meaningful scale
- **Starting point:** Representative small building area
- **LOD:** LOD1 in baseline
- **Special considerations:** Slope, coastal, terrain height variation, potential CRS issues

## Feature scope

**Included in baseline:**
- Building features (`bldg:Building`)
- LOD1 geometry

**Excluded from baseline:**
- Roads and transportation
- Terrain and DEM
- Bridges
- Vegetation
- Urban facilities
- Land use
- Water bodies
- Underground structures
- All other feature types

Do not expand feature scope without first completing the building baseline.

## Geographic scope

Two municipalities in Hokkaido Prefecture (北海道), Japan.

Do not claim:
- Planet-scale capability
- Performance representative of all Japanese municipalities
- Universal applicability to other CityGML sources

## Technical scope

**Required:**
- Mago 3DTiler (Docker)
- Java (as required by Mago)
- CesiumJS
- Python (inspection, validation, normalization, comparison)
- Node.js (viewer)
- Static HTTP server
- Portable Bash scripts

**Not required:**
- PostgreSQL or PostGIS
- 3DCityDB
- Spatial database
- Dynamic tile server
- Custom application server
- Account with any conversion or delivery service
- Cloud-specific infrastructure
- Large frontend framework

## Phase scope

| Phase | Scope |
|---|---|
| 0 | Environment setup and source discovery |
| 1 | Small Sarabetsu Explicit baseline |
| 2 | Small Sarabetsu Implicit output |
| 3 | Determinism testing |
| 4 | Expanded Sarabetsu |
| 5 | Small Muroran |
| 6 | Expanded Muroran |
| 7 | Optional higher-detail (LOD2+, textures) |

Phase 7 results are kept separate. Failure in Phase 7 does not invalidate Phase 1–6.
