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

### Sapporo City (札幌市)

- **Role:** Third and largest-scale target
- **Purpose:** Demonstrate Implicit's practical-consumption advantage at real
  metropolitan scale (~1.96M population, vs Muroran's ~90K). Added
  2026-08-28 at the user's explicit request, after a smaller texture-testing
  sub-goal (Phase 7b) established that Mago 3DTiler does not support
  CityGML texture conversion — so Sapporo's role in the baseline is scale
  only, not texture.
- **Starting point:** Full LOD1 building coverage (651.36 km²)
- **LOD:** LOD1 in baseline, same as Sarabetsu/Muroran
- **Special considerations:** Building count and build/publish time expected
  to substantially exceed both prior municipalities, given the population
  difference; real numbers recorded in `docs/findings.md` Phase 8

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

Three municipalities in Hokkaido Prefecture (北海道), Japan.

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
| 8 | Sapporo City — scale demonstration |

Phase 7 results are kept separate. Failure in Phase 7 does not invalidate Phase 1–6.
Phase 8 tests scale only (LOD1 baseline); it does not revisit texture support,
which Phase 7b already answered.
