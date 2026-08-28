# Test plan

## Overview

Four claims are evaluated separately. Each has independent pass criteria.
Do not collapse into one overall pass or fail.

---

## Phase 0: Environment and source discovery

**Goal:** Identify datasets, verify checksums, inspect CityGML.

**Steps:**
1. Identify versioned PLATEAU datasets for each municipality
2. Verify archive checksums
3. Inspect archive and directory structure
4. Identify building CityGML files
5. Inspect namespaces, `srsName`, CityGML version, PLATEAU extensions
6. Record source statistics

**Pass criteria:**
- Checksums verified
- Building CityGML files identified
- Source statistics recorded in dataset configuration

---

## Phase 1: Small Sarabetsu Village Explicit baseline

**Goal:** Establish that CityGML parses and produces correct Explicit 3D Tiles.

**Input:** One small building CityGML file from Sarabetsu Village (更別村).

**Steps:**
1. Run Mago 3DTiler in Explicit mode
2. Serve through static HTTP
3. Display in CesiumJS
4. Measure: building count, geographic placement, heights, attributes

**Pass criteria:**
- CityGML parses without fatal loss
- Explicit 3D Tiles generated
- Buildings appear in correct geographic location
- Vertical placement is reasonable or explained
- Source building count reconciled with output
- `gml:id` identifiers traceable

---

## Phase 2: Small Sarabetsu Village Implicit output

**Goal:** Produce and validate Implicit 3D Tiles from the same input.

**Steps:**
1. Run Mago 3DTiler in Implicit mode with same input
2. Validate `tileset.json`, subtree files, tile availability
3. Validate GLB content
4. Compare with Explicit output
5. Display in CesiumJS

**Comparison items:**
- Represented building count
- Geographic and vertical extent
- Missing or duplicate geometry
- Total size and file count
- Root tileset size
- Hierarchy and geometric error
- Feature identifiers
- CesiumJS behavior

**Pass criteria:**
- Implicit output generated
- Validates independently
- CesiumJS loads and renders correctly
- No unexplained missing or duplicate geometry
- Comparison with Explicit is documented

---

## Phase 3: Determinism

**Goal:** Confirm repeated builds produce Level 2 or better repeatability.

**Steps:**
1. Build the same Sarabetsu input at least twice in the pinned environment
2. Classify repeatability level
3. Test at two CPU concurrency settings if possible

**Repeatability levels:**
- **Level 1:** Byte-identical output
- **Level 2:** Structurally identical after documented normalization
  (JSON ordering, timestamps, binary padding that decodes identically)
- **Level 3:** Semantically equivalent but structurally different

**Pass criteria (Level 2 required):**
- Paths are stable
- Hierarchy and subtree boundaries are stable
- Availability is stable
- Feature-to-tile assignment is stable
- Identifiers are stable
- Bounding volumes and geometric errors are stable
- No unexplained structural changes

**Operationally significant differences (must not occur):**
- Changed paths
- Changed subtree boundaries
- Changed availability
- Changed feature-to-tile assignment
- Changed identifiers
- Changed bounding volumes or geometric errors
- Missing or duplicate geometry
- Changed metadata

---

## Phase 4: Expanded Sarabetsu Village test

**Goal:** Scale to full municipal building coverage.

**Measurements:**
- Source size and building count
- Conversion time
- Peak process memory
- Output size and file count
- Subtree and content counts
- Content-size distribution
- First useful render time
- Initial request count and transferred bytes
- Navigation and refinement behavior
- Geographic jump behavior
- Browser memory trend

---

## Phase 5: Small Muroran City test

**Goal:** Verify workflow on more demanding urban dataset.

**Special attention:**
- Slope and coastal conditions
- Horizontal and vertical placement
- CRS axis order
- ECEF placement
- Ellipsoidal versus orthometric height
- Bounding regions
- Tile refinement
- High-latitude graphics precision

---

## Phase 6: Expanded Muroran City test

**Goal:** Full municipal coverage and comparative analysis.

**Comparison with Sarabetsu:**
- Subtree sparsity
- Tile occupancy
- Content sizes
- Request patterns
- Conversion time
- Rendering and memory behavior

---

## Phase 7: Optional higher-detail tests (LOD2+, textures)

**Goal:** Test higher LOD and texture support if LOD1 baseline is stable.

Phase 7 is separate. Failure here does not invalidate Phase 1–6 results.

Sub-goals: 7a (LOD3, Sarabetsu) confirmed Mago converts higher LOD
geometry cleanly. 7b (texture, Sapporo) confirmed real texture data
exists in PLATEAU source but Mago 3DTiler 1.16.2 does not convert it —
confirmed against upstream source and maintainer statements, not
revisited further.

---

## Phase 8: Sapporo City — scale demonstration

**Goal:** Demonstrate whether Implicit's practical-consumption advantage
(established at Sarabetsu/Muroran scale, cross-phase finding) holds or
widens at real metropolitan scale (~1.96M population). LOD1 baseline
only — texture support is not re-tested here (see Phase 7b).

**Steps:**
1. Small-profile validation (same methodology as Phase 1/2/5)
2. Full-profile build, both modes
3. Publish and measure practical consumption in a real browser, same
   methodology as the Sarabetsu/Muroran cross-phase measurement

**Pass criteria:** Same as Phase 4/6 (conversion feasibility at scale),
plus a recorded practical-consumption comparison against
Sarabetsu/Muroran. No determinism or structural-comparison depth-match
required — those claims already generalized across two municipalities
in Phase 6.

---

## Validation tools

| Tool | Purpose |
|---|---|
| JSON schema validation | Validate configuration and manifest schemas |
| 3D Tiles validator | Validate `tileset.json` and subtree files |
| glTF validator | Validate GLB content |
| `tools/inspect_subtree.py` | Decode and inspect subtree availability |
| `tools/normalize.py` | Normalize for comparison |
| `tools/compare_manifests.py` | Compare two builds |
| `tools/inspect_citygml.py` | Inspect source CityGML |

Validator versions are pinned. Raw output is preserved.
Successful CesiumJS rendering is not sufficient proof of validity.
Validator success is not sufficient proof of usability.

---

## Practical consumption criteria

### Obvious failures (unacceptable)

- No useful view
- Persistent missing subtrees or visible holes
- Request activity that never settles
- Browser failure
- Continual unexplained memory growth
- Severe interaction stalls
- Incorrect geographic placement
- Invalid tile content
- Unexplained differences between repeated builds

### "First useful view" definition

A reproducible state in which:
- The camera has reached the predefined target
- Expected buildings are visible
- The scene is interactive

Do not invent universal thresholds before collecting evidence.
Record baseline values; label later thresholds as experiment-specific.
