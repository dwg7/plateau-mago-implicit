# PLATEAU Kai (plateau-mago-implicit)

**PLATEAU Kai** applies the latest (2026) open-source technology to
Project PLATEAU building data for Hokkaido (北海道), aiming for faster
PLATEAU display — using that as a way to test where 3D web mapping
currently stands. The name plays on three meanings: 開 (open, from
open-source), 北海道の「カイ」(Hokkaido's "kai"), and 快速の「快」
(fast/speedy). See [DECISIONS.md](DECISIONS.md) D22 for the full
rationale, including how this broader purpose relates to the project's
original, narrower research question below.

This repository tests whether PLATEAU building CityGML for Muroran City (室蘭市), Sarabetsu Village (更別村), and Sapporo City (札幌市) can be converted into Implicit 3D Tiles using Mago 3DTiler in a deterministic and reproducible manner, and consumed comfortably with CesiumJS from static HTTP storage. This remains the specific, rigorous methodology through which the broader PLATEAU Kai purpose above is evaluated — see the four claims below.

The experiment does not propose a new standard, replace PLATEAU CityGML, or evaluate the general value of specialized commercial conversion and delivery services. Its narrower purpose is to determine whether an independent open-source regeneration path can be maintained for a derived 3D delivery view under different operational assumptions.

PLATEAU CityGML remains the source dataset. Generated 3D Tiles are treated as disposable and reproducible delivery artifacts.

---

## Research question

> Can building data from Project PLATEAU CityGML for Muroran City (室蘭市), Sarabetsu Village (更別村), and Sapporo City (札幌市) be converted into Implicit 3D Tiles using Mago 3DTiler in a deterministic and reproducible manner, and then consumed comfortably with CesiumJS from ordinary static HTTP storage?

This experiment is presented in the working style of UN Open GIS Initiative DWG7: modest scope, rigorous recording, empirically cautious conclusions, and full reproducibility.

## Municipality roles

| Municipality | Role |
|---|---|
| **Sarabetsu Village (更別村)** | Smaller, rural target. Used to establish the small-to-municipal workflow, parsing behavior, coordinate correctness, Explicit versus Implicit comparison, and repeated-build repeatability. |
| **Muroran City (室蘭市)** | Larger, urban target. Used to test denser building distribution, coastal terrain variation, larger output volume, subtree organization, and CesiumJS behavior at meaningful scale. |
| **Sapporo City (札幌市)** | Largest-scale target (646,474 buildings). Added to demonstrate Implicit's practical-consumption advantage at real metropolitan scale, once Phase 7b established that texture conversion isn't supported by Mago 3DTiler and so wasn't the right reason to add a third municipality. |

The three municipalities are complementary, not competitive.

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

### Viewer

The CesiumJS viewer (`viewer/`) is also deployed as a static app to
**[GitHub Pages](https://dwg7.github.io/plateau-mago-implicit/)** on every
push to `viewer/**`. It ships with no tile data — that's derived and
regenerable, not committed (see [DECISIONS.md](DECISIONS.md) D8/D10) — so
use its "Custom tileset URL" field to point it at a tileset you're hosting
yourself, or run `make serve` locally for the predefined-viewpoint dropdown
to resolve.

## Data licensing and attribution

Source data is from Project PLATEAU (プロジェクト PLATEAU), provided by the Ministry of Land, Infrastructure, Transport and Tourism (国土交通省).

Datasets are published under the [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license unless otherwise noted.

**Required attribution:**

> 国土交通省 Project PLATEAU (https://www.mlit.go.jp/plateau/)

Do not redistribute original PLATEAU dataset files from this repository. Download them using the provided scripts.

See [NOTICE](NOTICE) for full attribution.

## Experimental phases

Phase-by-phase status (0 through 8, covering all three municipalities)
is tracked in one place, kept current as work happens:
[docs/findings.md](docs/findings.md). A separate summary table here
duplicated that tracking and had already gone stale once — see
`docs/scope.md`'s phase table for the phase list itself.

## Pass criteria

See [docs/test-plan.md](docs/test-plan.md) for full criteria. Summary:

- **Conversion:** CityGML parses; Implicit output generated and validates; CesiumJS loads it.
- **Fidelity:** Building counts reconciled; retained/lost information documented.
- **Determinism:** Repeated builds reach Level 2 (structurally identical after documented normalization) or better.
- **Reproducibility:** Source and tool versions immutable and recorded; clean environment can reproduce.
- **Delivery:** Static HTTP works; no persistent missing subtrees.
- **Practical use:** Viewer reaches useful view; navigation responsive; no persistent geometry gaps.

## Current status

Real PLATEAU data has been fetched, built, validated, and published for
all three municipalities (Phases 0–8), including full-profile builds at
metropolitan scale (Sapporo: 646,474 buildings) and a real-browser
practical-consumption measurement. Getting here required fixing several
pipeline bugs and tooling gaps that only surfaced when the tools were
actually run against real data — wrong CLI flags, a CRS/axis-order
mismatch, a vertical-datum (geoid) mismatch, a non-deterministic UUID
Mago embeds in GLB output, and others. See
[docs/findings.md](docs/findings.md) for the full, evidence-based
record — the authoritative source for what's actually been verified,
phase by phase. It is not all good news: determinism fails at full
scale for every municipality tested, and Mago 3DTiler does not support
CityGML texture conversion — both reported plainly, not smoothed over.

## Limitations and non-goals

- Tests three municipalities only. No planet-scale claims.
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

## Related projects

- [hfu/kitaphoto17-navara](https://github.com/hfu/kitaphoto17-navara) — same PLATEAU building data via Navara

## Upstream acknowledgements

- [Project PLATEAU](https://www.mlit.go.jp/plateau/) — source building data
- [Mago 3DTiler](https://github.com/Gaia3D/mago-3d-tiler) — CityGML to 3D Tiles conversion
- [CesiumJS](https://cesium.com/platform/cesiumjs/) — 3D Tiles viewer
- [3D Tiles specification](https://github.com/CesiumGS/3d-tiles) — output format
- [UN Open GIS Initiative DWG7](https://github.com/unopengis/7) — working style reference

