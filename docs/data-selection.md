# Data selection

## Policy

For each municipality, select a specific, versioned PLATEAU release.
Record all fields below. Never fabricate or estimate values.
Use `TBD_VERIFIED_SOURCE_REQUIRED` for unresolved values.

## Sarabetsu Village (更別村)

| Field | Value |
|---|---|
| Municipality name (English) | Sarabetsu Village |
| Municipality name (Japanese) | 更別村 |
| Municipality code | 01639 |
| Prefecture | Hokkaido (北海道) |
| PLATEAU dataset identifier | 01639_sarabetsu-mura_city_2023 |
| Source catalog URL | https://www.geospatial.jp/ckan/dataset/plateau-01639-sarabetsu-mura-2023 |
| Download URL | https://assets.cms.plateau.reearth.io/assets/81/fcc64a-cc94-403e-9022-d187415f00f5/01639_sarabetsu-mura_city_2023_citygml_2_op.zip |
| Dataset year | 2023 (catalog/filename year; the archive's own README.md title says "（2022年度）" — recorded verbatim, not reconciled) |
| PLATEAU spec version | 4.1 (第4.1版) |
| CityGML version | 2.0 (iur/uro extension namespace 3.1) |
| Archive name | 01639_sarabetsu-mura_city_2023_citygml_2_op.zip |
| Archive SHA-256 | 6a4639c5699c8d27581a6d44051aa449d5fc5dc7f2b42ee679fa8d8b3ddda086 |
| Archive size (bytes) | 1,148,012,455 |
| License | CC BY 4.0 |
| Attribution | 国土交通省 Project PLATEAU |
| Selected building files | 187 total under `udx/bldg/` (full list: `config/sarabetsu.yml` `source.building_files`); small_file for Phase 1/2: `udx/bldg/63437290_bldg_6697_op.gml` |
| Reason for file selection | Smallest bldg mesh file by byte size (8,455 bytes); contains exactly one building |

### Selection rationale

Sarabetsu Village (更別村) is selected because:
- It is a small rural municipality with a limited building count
- Smaller datasets establish parsing and workflow before scaling
- It provides a repeatable, low-cost baseline for determinism testing

**Verified 2026-08-25 (Phase 0):** the building count assumption holds
(6,795 buildings vs. Muroran's 55,906), but the *archive size* assumption
does not — Sarabetsu's archive (1.1 GB) is actually larger than Muroran's
(238 MB), because non-building layers (chiefly terrain/DEM) dominate total
size. See `docs/findings.md` Phase 0.

## Muroran City (室蘭市)

| Field | Value |
|---|---|
| Municipality name (English) | Muroran City |
| Municipality name (Japanese) | 室蘭市 |
| Municipality code | 01205 |
| Prefecture | Hokkaido (北海道) |
| PLATEAU dataset identifier | 01205_muroran-shi_city_2022 |
| Source catalog URL | https://www.geospatial.jp/ckan/dataset/plateau-01205-muroran-shi-2022 |
| Download URL | https://assets.cms.plateau.reearth.io/assets/ab/da35f0-8c55-43d1-ad9e-1689bbc084a8/01205_muroran-shi_city_2022_citygml_4_op.zip |
| Dataset year | 2022 |
| PLATEAU spec version | 4.1 (第4.1版) |
| CityGML version | 2.0 (iur/uro extension namespace 3.1) |
| Archive name | 01205_muroran-shi_city_2022_citygml_4_op.zip |
| Archive SHA-256 | 1ed95f59d5374cc809999fc57ac18501f667fef2b32af0f4a104de44422600a9 |
| Archive size (bytes) | 238,403,688 |
| License | CC BY 4.0 |
| Attribution | 国土交通省 Project PLATEAU |
| Selected building files | 100 total under `udx/bldg/` (full list: `config/muroran.yml` `source.building_files`); small_file for Phase 5: `udx/bldg/63403767_bldg_6697_op.gml` |
| Reason for file selection | Smallest bldg mesh file by byte size (10,637 bytes); contains exactly one building |

### Selection rationale

Muroran City (室蘭市) is selected because:
- It is an urban coastal city with terrain variation, sloped areas, and denser buildings
- It tests more demanding subtree organization, height handling, and CesiumJS behavior
- It is in the same PLATEAU program and uses the same CityGML structure as Sarabetsu
- Comparing Sarabetsu and Muroran explains how spatial distribution affects tiling behavior

## Sapporo City (札幌市)

| Field | Value |
|---|---|
| Municipality name (English) | Sapporo City |
| Municipality name (Japanese) | 札幌市 |
| Municipality code | 01100 |
| Prefecture | Hokkaido (北海道) |
| PLATEAU dataset identifier | 01100_sapporo-shi_city_2020 |
| Source catalog URL | https://www.geospatial.jp/ckan/dataset/plateau-01100-sapporo-shi-2020 |
| Download URL | https://assets.cms.plateau.reearth.io/assets/be/3b8cfb-5459-4f9d-b08c-fb4ab72fbdbd/01100_sapporo-shi_city_2020_citygml_7_op.zip |
| Dataset year | 2020 |
| PLATEAU spec version | 4 (V4) |
| CityGML version | 2.0 |
| Archive name | 01100_sapporo-shi_city_2020_citygml_7_op.zip |
| Archive SHA-256 | bc0f3d9de76b5f298741a5c0cac747293fbff8ec07de8a4dbf7c8d944dd8ac72 |
| Archive size (bytes) | 2,718,857,710 |
| License | CC BY 4.0 |
| Attribution | 国土交通省 Project PLATEAU |
| Selected building files | 604 total under `udx/bldg/` (full list: `config/sapporo.yml` `source.building_files`); small_file for small-profile validation: `udx/bldg/64413140_bldg_6697_op.gml` |
| Reason for file selection | Smallest bldg mesh file with exactly one building (11,517 bytes), of 16 single-building candidates found; minimizes variables for the initial parse/coordinate/height baseline, same reasoning as Sarabetsu/Muroran's small_file |

### Selection rationale

Sapporo City (札幌市) is selected because:
- It is Hokkaido's capital and largest city by a wide margin (~1.96M
  population, vs Muroran's ~90K) — the natural next step for testing
  Implicit's practical-consumption advantage at real metropolitan scale
- Added 2026-08-28/29 at the user's explicit request, as a genuine third
  baseline municipality (`CLAUDE.md`'s "two municipalities only... do
  not add a third without the user asking" boundary — the user did ask,
  explicitly, for exactly this purpose)
- Not chosen for texture support: a smaller-scope sub-goal (Phase 7b,
  below) investigated Sapporo's real LOD2/texture data first, using a
  hand-picked 3-building extract kept separate from this full-dataset
  entry — that investigation found Mago 3DTiler does not convert CityGML
  texture data at all (confirmed against Mago's own source and upstream
  maintainer statements), so Sapporo's role in the actual baseline
  (full LOD1 profile, 646,474 buildings) is scale only, same LOD1 scope
  as Sarabetsu/Muroran

**Verified 2026-08-28/29 (Phase 8):** `make inspect DATASET=sapporo`
confirmed 646,474 buildings (95x Sarabetsu, 11.6x Muroran), single CRS
(EPSG:6697) across the whole dataset, same axis order as
Sarabetsu/Muroran. Full-profile builds (both modes) and a real-browser
practical-consumption measurement are recorded in `docs/findings.md`
Phase 8.

### Phase 7b texture sub-goal — a separate, smaller extract, not this entry

`docs/findings.md`'s "Phase 7b: texture sub-goal" used a different,
much smaller extract from the same archive above: 3 of the 604
`udx/bldg/*.gml` files, chosen for containing real texture data
(`64414293_bldg_6697_op.gml`, `64414279_bldg_6697_op.gml`,
`64414380_bldg_6697_op.gml` — of 14 files with a paired `_appearance/`
texture directory out of 604 total), with one texture-bearing building
extracted from each (`bldg_16052a8c-cc5c-470f-bfec-24c954e9238b`,
`bldg_b8f611c9-0d44-4b14-8d63-a890f526881a`,
`bldg_6d43503c-fa27-421f-83cb-2bbdc9a32be2` — picked for a range of
texture complexity: 3, 23, 38 texture surfaces respectively). This ran
*before* Sapporo was added as a full baseline municipality above, as an
isolated test of whether Mago converts texture data at all (it doesn't
— see `docs/findings.md`'s Phase 7b section) — kept as a separate note
here since it used a different, non-representative subset of the
archive than the full-profile entry above.

## Source data policy

- Prefer immutable or version-specific URLs
- If only a `latest` or redirecting URL is available, resolve and record the actual target
- Do not commit full PLATEAU datasets to Git
- Download scripts and manifests are provided
- Small fixtures may be committed only when licensing and size permit
- Never fabricate URLs, checksums, versions, or feature counts

All unresolved values must remain as `TBD_VERIFIED_SOURCE_REQUIRED`.
Scripts fail safely when these values are present.
