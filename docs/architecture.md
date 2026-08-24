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

PLATEAU CityGML uses Japan Plane Rectangular Coordinate System (平面直角座標系)
with JGD2011 datum. 3D Tiles uses WGS84/ECEF.

Mago 3DTiler handles this transformation. Coordinate correctness is verified in
Phase 1 (Explicit baseline) before testing Implicit output.

Axis order and epoch handling are recorded in dataset configuration files.
