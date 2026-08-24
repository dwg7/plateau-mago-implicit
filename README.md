# plateau-mago-implicit

This repository tests whether PLATEAU building CityGML for Muroran City (室蘭市) and Sarabetsu Village (更別村) can be converted into Implicit 3D Tiles using Mago 3DTiler in a deterministic and reproducible manner, and consumed comfortably with CesiumJS from static HTTP storage.

The experiment does not propose a new standard, replace PLATEAU CityGML, or evaluate the general value of specialized commercial conversion and delivery services. Its narrower purpose is to determine whether an independent open-source regeneration path can be maintained for a derived 3D delivery view under different operational assumptions.

PLATEAU CityGML remains the source dataset. Generated 3D Tiles are treated as disposable and reproducible delivery artifacts.

---

## Research question

> Can building data from Project PLATEAU CityGML for Muroran City (室蘭市) and Sarabetsu Village (更別村) be converted into Implicit 3D Tiles using Mago 3DTiler in a deterministic and reproducible manner, and then consumed comfortably with CesiumJS from ordinary static HTTP storage?

This experiment is presented in the working style of UN Open GIS Initiative DWG7: modest scope, rigorous recording, empirically cautious conclusions, and full reproducibility.

## Municipality roles

| Municipality | Role |
|---|---|
| **Sarabetsu Village (更別村)** | Smaller, rural target. Used to establish the small-to-municipal workflow, parsing behavior, coordinate correctness, Explicit versus Implicit comparison, and repeated-build repeatability. |
| **Muroran City (室蘭市)** | Larger, urban target. Used to test denser building distribution, coastal terrain variation, larger output volume, subtree organization, and CesiumJS behavior at meaningful scale. |

The two municipalities are complementary, not competitive.

## Core position

- PLATEAU CityGML is the source dataset and authoritative input.
- Generated 3D Tiles are disposable delivery artifacts, comparable to materialized views.
- The experiment uses an independent open-source regeneration path.
- Specialized commercial services are respectfully outside the experiment boundary. See [docs/respectful-positioning.md](docs/respectful-positioning.md).

## Claims under evaluation

Four claims are evaluated separately:

1. **Conversion feasibility** — Mago 3DTiler can parse PLATEAU building CityGML and produce valid 3D Tiles 1.1 with Implicit Tiling.
2. **Determinism** — Repeated builds from identical source, converter, and environment produce stable structural output.
3. **Reproducibility** — A third party can reproduce the experiment from public source data and this repository.
4. **Practical consumption** — Outputs work through ordinary static HTTP delivery, and CesiumJS can traverse and render them acceptably.

See [docs/hypothesis.md](docs/hypothesis.md) and [docs/test-plan.md](docs/test-plan.md).

## Architecture

```
PLATEAU CityGML  →  Mago 3DTiler (Docker, pinned)  →  3D Tiles output
                                                           ↓
                                              static HTTP server
                                                           ↓
                                                   CesiumJS viewer
```

See [docs/architecture.md](docs/architecture.md).

## Quick start

### Prerequisites

- Docker or Podman (OCI-compatible runtime)
- GNU Make
- Python 3.10+
- Node.js 18+
- Bash 4+

### Bootstrap

```bash
make bootstrap
```

Verifies dependencies and prints environment information.

### Sarabetsu Village (small test)

```bash
make experiment DATASET=sarabetsu PROFILE=small
```

This command:
1. Verifies the environment
2. Fetches and verifies source data checksums
3. Inspects CityGML files
4. Generates Explicit and Implicit 3D Tiles
5. Validates outputs
6. Repeats the Implicit build
7. Compares both builds
8. Generates build manifests
9. Prints viewer instructions

**Note:** Source data checksums must be resolved before the experiment runs. See [data/input-manifest.yml](data/input-manifest.yml) and search for `TBD_VERIFIED_SOURCE_REQUIRED`.

### Individual commands

```bash
make fetch DATASET=sarabetsu
make inspect DATASET=sarabetsu
make build DATASET=sarabetsu MODE=explicit PROFILE=small
make build DATASET=sarabetsu MODE=implicit PROFILE=small
make validate DATASET=sarabetsu MODE=implicit PROFILE=small
make compare DATASET=sarabetsu MODE=implicit PROFILE=small
make serve
make viewer
make clean
```

## Data licensing and attribution

Source data is from Project PLATEAU (プロジェクト PLATEAU), provided by the Ministry of Land, Infrastructure, Transport and Tourism (国土交通省).

Datasets are published under the [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license unless otherwise noted.

**Required attribution:**

> 国土交通省 Project PLATEAU (https://www.mlit.go.jp/plateau/)

Do not redistribute original PLATEAU dataset files from this repository. Download them using the provided scripts.

See [NOTICE](NOTICE) for full attribution.

## Experimental phases

| Phase | Description | Status |
|---|---|---|
| 0 | Environment and source discovery | Complete (both municipalities) |
| 1 | Small Sarabetsu Explicit baseline | Complete |
| 2 | Small Sarabetsu Implicit output | Partially complete — generated and geographically verified; full validation blocked by a tooling gap (see findings) |
| 3 | Determinism testing | Preliminary only — an early signal was found and root-caused, formal procedure not yet run |
| 4 | Expanded Sarabetsu test | Not started |
| 5 | Small Muroran test | Not started (a config spot-check only, not a phase run) |
| 6 | Expanded Muroran test | Not started |
| 7 | Optional higher-detail tests | Not started |

## Pass criteria

See [docs/test-plan.md](docs/test-plan.md) for full criteria. Summary:

- **Conversion:** CityGML parses; Implicit output generated and validates; CesiumJS loads it.
- **Fidelity:** Building counts reconciled; retained/lost information documented.
- **Determinism:** Repeated builds reach Level 2 (structurally identical after documented normalization) or better.
- **Reproducibility:** Source and tool versions immutable and recorded; clean environment can reproduce.
- **Delivery:** Static HTTP works; no persistent missing subtrees.
- **Practical use:** Viewer reaches useful view; navigation responsive; no persistent geometry gaps.

## Current status

Real PLATEAU data has been fetched and inspected for both municipalities,
and Sarabetsu Village's small-profile Explicit and Implicit builds run
successfully end to end against a real, pinned Mago 3DTiler 1.16.2. Getting
here required fixing several pipeline bugs that only surfaced when the
tool was actually run (wrong CLI flags, a CRS/axis-order mismatch, and a
"small" profile that was silently building the whole municipality) — see
[docs/findings.md](docs/findings.md) for the full, evidence-based record,
including two known tooling gaps (Implicit subtree format handling, and a
non-deterministic UUID mago-3d-tiler embeds in GLB output) that currently
block a fully trustworthy Phase 2/3 verdict.

See [docs/findings.md](docs/findings.md) for the experiment log — the
authoritative source for what's actually been verified, phase by phase.

## Limitations and non-goals

- Tests two municipalities only. No planet-scale claims.
- LOD1 buildings only in baseline.
- Roads, terrain, vegetation, and other feature types excluded from baseline.
- No spatial database, dynamic tile server, or cloud infrastructure required.
- CesiumJS is the baseline client; MapLibre and others are not tested in the baseline.

See [docs/limitations.md](docs/limitations.md).

## Reproducing this experiment

1. Clone this repository.
2. Install prerequisites (Docker, Python 3.10+, Node.js 18+, Make, Bash 4+).
3. Resolve `TBD_VERIFIED_SOURCE_REQUIRED` values in [data/input-manifest.yml](data/input-manifest.yml) and [config/sarabetsu.yml](config/sarabetsu.yml).
4. Run `make experiment DATASET=sarabetsu PROFILE=small`.

All tool versions, checksums, commands, and logs are recorded in build manifests under `manifests/builds/`.

See [docs/reproducibility.md](docs/reproducibility.md).

## Citation

See [CITATION.cff](CITATION.cff).

## Upstream acknowledgements

- [Project PLATEAU](https://www.mlit.go.jp/plateau/) — source building data
- [Mago 3DTiler](https://github.com/Gaia3D/mago-3d-tiler) — CityGML to 3D Tiles conversion
- [CesiumJS](https://cesium.com/platform/cesiumjs/) — 3D Tiles viewer
- [3D Tiles specification](https://github.com/CesiumGS/3d-tiles) — output format
- [UN Open GIS Initiative DWG7](https://www.opengis.net/) — working style reference

