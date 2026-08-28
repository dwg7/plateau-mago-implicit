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

## Phase 7b texture sub-goal: Sapporo City (札幌市) extract

**This is not a third baseline municipality.** It's a scoped provenance
note for the small, isolated data extract used in
`docs/findings.md`'s "Phase 7b: texture sub-goal" — recorded here per
this document's own policy ("Never fabricate or estimate values") even
though it's not a full parallel entry to Sarabetsu/Muroran above. See
`CLAUDE.md`'s "two municipalities only" boundary and
`docs/findings.md`'s Phase 7b section for why this stays separate from
the declared baseline.

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
| Selected building files | 3 of 604 `udx/bldg/*.gml` files, chosen for containing texture data: `64414293_bldg_6697_op.gml`, `64414279_bldg_6697_op.gml`, `64414380_bldg_6697_op.gml` |
| Selected buildings | 1 textured building extracted from each file: `bldg_16052a8c-cc5c-470f-bfec-24c954e9238b`, `bldg_b8f611c9-0d44-4b14-8d63-a890f526881a`, `bldg_6d43503c-fa27-421f-83cb-2bbdc9a32be2` |
| Reason for file selection | LOD2 coverage is a 3.27 km² subset of the city (651.36 km² LOD1 coverage); only 14 of the 604 mesh files have a paired `_appearance/` texture directory, and each of the 3 checked contained exactly one texture-bearing building — picked for a range of texture complexity (3, 23, 38 texture surfaces) |

### Selection rationale

Not a workflow-scaling or urban-density rationale like Sarabetsu/Muroran
— chosen specifically because it's the smallest real PLATEAU dataset
this project could confirm actually contains `app:ParameterizedTexture`
elements (zero in both baseline municipalities, re-confirmed multiple
times). Extraction and reproduction steps: `docs/findings.md`'s Phase 7b
section.

## Source data policy

- Prefer immutable or version-specific URLs
- If only a `latest` or redirecting URL is available, resolve and record the actual target
- Do not commit full PLATEAU datasets to Git
- Download scripts and manifests are provided
- Small fixtures may be committed only when licensing and size permit
- Never fabricate URLs, checksums, versions, or feature counts

All unresolved values must remain as `TBD_VERIFIED_SOURCE_REQUIRED`.
Scripts fail safely when these values are present.
