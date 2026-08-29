# Architecture

## Overview

```
┌─────────────────────────────┐
│  Project PLATEAU (国土交通省) │
│  CityGML Building Data      │
│  (CC BY 4.0)                │
└──────────────┬──────────────┘
               │ fetch.sh (checksummed)
               ▼
┌─────────────────────────────┐
│  data/source/               │
│  PLATEAU CityGML archive    │
└──────────────┬──────────────┘
               │ build.sh
               ▼
┌─────────────────────────────┐
│  Mago 3DTiler               │
│  (Docker, pinned digest)    │
│  Explicit or Implicit mode  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  data/output/               │
│  3D Tiles 1.1               │
│  (Explicit or Implicit)     │
└──────┬───────────┬──────────┘
       │           │
       │ validate  │ normalize
       ▼           ▼
┌──────────┐ ┌─────────────────┐
│ validator│ │ compare-builds  │
│ logs     │ │ manifests       │
└──────────┘ └─────────────────┘
                    │ serve.sh
                    ▼
        ┌───────────────────────┐
        │  Static HTTP Server   │
        │  (nginx, no backend)  │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  CesiumJS Viewer      │
        │  viewer/index.html    │
        └───────────────────────┘
```

## Components

### Source data

Project PLATEAU CityGML datasets, fetched by `scripts/fetch.sh`.
Checksums are verified before any conversion step.
Source data is not committed to this repository.

### Mago 3DTiler

- Runs in Docker with a pinned image digest.
- Converts CityGML to 3D Tiles in Explicit or Implicit mode.
- Configuration via `config/common.yml` and dataset-specific files.
- Build records preserved in `manifests/builds/`.

See `config/common.yml` for pinning details.

### 3D Tiles output

- Format: 3D Tiles 1.1
- Explicit Tiling: used as the control baseline (Phase 1)
- Implicit Tiling: primary research target (Phase 2+)
- Output stored under `data/output/` (not committed)

### Static HTTP server

- nginx running in Docker
- No backend processing
- Standard HTTP GET with CORS and correct MIME types
- Byte ranges supported for large tile content

See `config/nginx.conf` for headers.

### CesiumJS viewer

- Minimal HTML/JS viewer under `viewer/`
- Loads configurable `tileset.json`
- Switches between Sarabetsu Village and Muroran City
- Switches between Explicit and Implicit outputs
- Displays predefined viewpoints and diagnostics panel
- No large framework dependency

### Inspection and validation tools

- `tools/inspect_citygml.py` — inspect CityGML source
- `tools/inspect_subtree.py` — decode and inspect subtree files
- `tools/normalize.py` — normalize outputs for comparison
- `tools/compare_manifests.py` — compare two build manifests
- `tools/summarize_metrics.py` — summarize experiment metrics

### Build manifests

Each build run produces a manifest under `manifests/builds/` recording:
- Tool versions and digests
- Exact command and configuration
- Timing and return code
- Output file counts and checksums
- Validation status
- Git commit and working-tree status

## Data flow for comparison

```
Build 1 output  ─┐
                  ├─ normalize.py ─→ normalized manifests ─→ compare_manifests.py ─→ report
Build 2 output  ─┘
```

## CRS considerations

**Updated 2026-08-25 from Phase 0 inspection of real source data — see
`docs/findings.md`.** This section originally assumed PLATEAU CityGML uses
the Japan Plane Rectangular Coordinate System (平面直角座標系). That does not
hold for the actual Sarabetsu Village (2023, V4) and Muroran City (2022, V4)
releases used by this project: every source file in both datasets uses
**EPSG:6697 (JGD2011, geographic 3D)** instead, with axis order
(latitude, longitude, height) — northing-first, not the (lon, lat, height)
order 3D Tiles/CesiumJS use internally. 3D Tiles itself uses WGS84/ECEF
(EPSG:4978).

Mago 3DTiler handles this transformation via its `--crs`/`--proj` options.
Coordinate correctness is verified in Phase 1 (Explicit baseline) before
testing Implicit output.

Axis order and epoch handling are recorded in dataset configuration files
(`config/sarabetsu.yml`, `config/muroran.yml`, `crs:` block).

## Viewer terrain (not part of the conversion pipeline above)

`viewer/viewer.js` renders buildings over real elevation via Re:Earth
Terrain (`terrain.reearth.land`, a quantized-mesh-1.0 service blending
Mapterhorn's global DEM with the EGM2008 geoid) — a viewer-only concern,
independent of the CityGML → Mago → 3D Tiles pipeline above; the
building GLBs themselves carry no terrain data.

**Planned future source**: `hfu/mapterhorn-japan-bridge` — a
GSI-DEM-to-Mapterhorn-PMTiles bridge that priority-merges Japan's best
available DEM (including 1m GSI DEM1A airborne-laser data) until
upstream Mapterhorn's own Japan source catches up. Part of PLATEAU
Kai's broader purpose (see `DECISIONS.md` D22) — swapping in
higher-resolution, Japan-specific terrain once that project stabilizes.
Not yet integrated: as of 2026-08-29 its own commit history still shows
active bug-fixing (orphaned tiles, downsampling convergence issues),
confirmed by checking its recent commits directly rather than assuming
readiness. No integration work is planned until the user revisits this.
