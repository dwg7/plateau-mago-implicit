# Findings

This document is the experiment log. Results are recorded here as phases complete.

## Status key

| Symbol | Meaning |
|---|---|
| ✓ | Confirmed |
| ~ | Partially confirmed |
| ✗ | Not confirmed |
| ? | Unexpected finding |
| → | Upstream candidate |
| ↓ | Next smallest experiment |

---

## Phase 0: Environment and source discovery

**Status: Complete for Sarabetsu Village and Muroran City.** 2026-08-25.

### Confirmed

- ✓ Real, versioned PLATEAU datasets identified and downloaded for both
  municipalities, with checksums verified by `scripts/fetch.sh` itself
  (not just computed and trusted):
  - Sarabetsu Village: `01639_sarabetsu-mura_city_2023_citygml_2_op.zip`
    (V4 spec, 2023 catalog year), 1,148,012,455 bytes, SHA-256
    `6a4639c5699c8d27581a6d44051aa449d5fc5dc7f2b42ee679fa8d8b3ddda086`.
  - Muroran City: `01205_muroran-shi_city_2022_citygml_4_op.zip` (V4 spec,
    2022 catalog year), 238,403,688 bytes, SHA-256
    `1ed95f59d5374cc809999fc57ac18501f667fef2b32af0f4a104de44422600a9`.
  - Both conform to PLATEAU standard product specification **第4.1版
    (4.1)**, CityGML **2.0**, iur/uro extension namespace **3.1**.
- ✓ `make inspect` (`tools/inspect_citygml.py`) run against both fully
  extracted archives. Results cross-check cleanly against each archive's
  own `README.md`:
  - Sarabetsu: 1,139 CityGML/XML files, **6,795 buildings** detected
    (README states 6,801 — see ? below), LODs {1,2,3} present, 7,643,758
    polygons, single CRS across every file.
  - Muroran: 284 files, **55,906 buildings** detected — matches the
    README's "LOD1: 5.97km² 55906棟" exactly. LOD {1} only, 1,192,276
    polygons, single CRS across every file.
  - Full reports: `manifests/reports/inspect-sarabetsu.json`,
    `manifests/reports/inspect-muroran.json`.
- ✓ **Both datasets use EPSG:6697 (JGD2011, geographic 3D)**, not the Japan
  Plane Rectangular Coordinate System originally assumed in
  `docs/architecture.md` (now corrected there). Axis order in every
  observed `gml:pos`/`lowerCorner`/`upperCorner` is (latitude, longitude,
  height) — northing-first.
- ✓ Small building files selected for Phase 1/2 (Sarabetsu) and Phase 5
  (Muroran): the smallest bldg mesh file by byte size in each archive,
  each containing exactly one `bldg:Building`.
  - Sarabetsu: `udx/bldg/63437290_bldg_6697_op.gml` (8,455 bytes).
  - Muroran: `udx/bldg/63403767_bldg_6697_op.gml` (10,637 bytes).
- ✓ Mago 3DTiler **v1.16.2** pinned by JAR SHA-256 (no public Docker image
  exists — see ? below): jar SHA-256
  `d37e58b634e91d7ce7ca046168b1db2cf950cd9b2ffacb826fd3b10a8d31f7e2`,
  independently re-verified by `Dockerfile`'s own build-time
  `sha256sum --check --strict` step (not just our own computation).

### Partially confirmed

- ~ **Sarabetsu Village municipality code was wrong in the merged PR**
  (`01643`, actually Makubetsu Town's code) and has been corrected to
  `01639` (verified against Wikipedia and the PLATEAU catalog page/archive
  metadata, which both consistently use 01639). Muroran's code (01205) was
  already correct.

### Not confirmed

*None — all Phase 0 pass criteria (docs/test-plan.md) were met for both
municipalities.*

### Unexpected findings

- ? **Sarabetsu's archive (1.1 GB) is larger than Muroran's (238 MB)**,
  contradicting `docs/data-selection.md`'s stated rationale for choosing
  Sarabetsu first ("smaller dataset... low-cost baseline"). The building
  *count* is smaller (6,795 vs 55,906, as intended), but total archive size
  is dominated by the terrain (DEM) layer, not buildings: Sarabetsu's DEM
  alone is 492 files; the whole archive decompresses to ~21 GB on disk.
  Does not block using Sarabetsu first (building count, the actual
  Phase 1–4 variable, is still smaller) but the stated cost rationale was
  incorrect as written.
- ? **inspect_citygml.py's building count (6,795) differs slightly from
  Sarabetsu's own README.md (6,801)** — a 6-building (0.09%) discrepancy.
  Not investigated further; plausible causes include the tool's regex-ish
  `bldg:Building` XPath missing a handful of buildings embedded in
  `BuildingPart`-only structures, or the README's own count including
  something the LOD1-only building search doesn't. Low priority given the
  small magnitude, but noted rather than silently accepted.
- ? **No public Docker image for Mago 3DTiler exists on GHCR**
  (`ghcr.io/gaia3d/mago-3d-tiler` → `denied`, i.e. not found), contrary to
  this project's original `config/common.yml` design (which had
  `mago.image`/`image_digest` fields, unfillable). **Correction to an
  earlier statement in this session: a public image DOES exist on Docker
  Hub** (`docker.io/gaia3d/mago-3d-tiler`, confirmed via
  `docker manifest inspect`, both `:latest` and `:1.16.2` tags, multi-arch).
  This project still pins via JAR SHA-256 (building a local image from
  `Dockerfile`) rather than switching to the Docker Hub image, since the
  JAR path was already implemented and verified working end-to-end, and is
  equally valid per the original pinning-mechanism design
  (`DECISIONS.md` D2). Revisit if the local-build step becomes a
  bottleneck.

### Upstream candidates

*None yet — no Mago 3DTiler or CesiumJS issue has been prepared. See Phase 1
Unexpected findings for a UUID-embedding behavior that may become a
candidate once Phase 3 (determinism) confirms it's the sole source of
non-determinism.*

### Next smallest experiment

Phase 0 is complete. See Phase 1 below, already partially executed.

---

## Phase 1: Small Sarabetsu Village Explicit baseline

**Status: Complete.** 2026-08-24/25.

### Confirmed

- ✓ `udx/bldg/63437290_bldg_6697_op.gml` (Sarabetsu small_file) parses and
  converts via Mago 3DTiler 1.16.2 without fatal loss: `make build
  DATASET=sarabetsu MODE=explicit PROFILE=small` produced a valid
  `tileset.json` + 2 tile contents (LOD0 footprint + LOD1 solid) from the
  file's single building, 10,353 bytes total output.
- ✓ **After fixing coordinate handling (see ? below), buildings appear in
  the correct geographic location.** Output region matched the source
  envelope exactly: 143.2530°E, 42.6604°N (Sarabetsu Village, Hokkaido) —
  verified by converting the 3D Tiles `region` radians back to degrees and
  comparing against the source `gml:Envelope`.
- ✓ Vertical placement is reasonable: root tileset height range 0–154.376 m
  matches the source envelope's height range exactly (no unexplained
  offset).

### Partially confirmed

- ~ **`gml:id` is NOT retained in the output — corrected from an earlier,
  wrong claim in this same entry.** The source building's `gml:id`
  (`bldg_c86b549e-78ae-4129-b7d5-717fa6968e57`) does **not** appear
  anywhere in the GLB. Checked directly by decoding
  `data/RC0000.glb`'s `EXT_structural_metadata` property table: Mago's
  default schema retains `NodeName` ("root"), `BatchId` (a small integer,
  "0"), `FileName` (the source filename,
  "63437290_bldg_6697_op.gml" — genuinely traceable), and `id` — but `id`
  is a **freshly-generated random UUID** (e.g.
  `c6f4ee32-41c9-4842-b32d-2e3c68682184`), not the source `gml:id`. This
  is the same mechanism behind the Phase 3 non-determinism finding below —
  `id` gets a new random value on every conversion run. Traceability back
  to source is therefore only as precise as "this file" (via `FileName`),
  not "this specific building record" (no `gml:id` round-trip).

### Not confirmed

*None for Explicit mode, once the fixes below were applied. Before the
fixes, Explicit mode did not run at all — every invocation failed with a
command-line parse error (see ? below).*

### Unexpected findings

Several bugs in the merged pipeline meant `scripts/build.sh` **never
successfully invoked Mago 3DTiler**, in either mode, as originally shipped.
All were found and fixed by actually running the real tool against real
data (not by reading Mago's docs alone):

- ? **`--outputType 3dtiles` and `--tileType implicit` are not real Mago
  3DTiler CLI flags.** Confirmed via `mago-3d-tiler --help`, `MANUAL.md`,
  and by triggering the actual error:
  `org.apache.commons.cli.UnrecognizedOptionException: Unrecognized option:
  --tileType` (and separately for `--thread`, also nonexistent — the real
  flag is `--multiThreadCount`, marked `[Deprecated]` but functional).
  Every `make build` invocation, for both `explicit` and `implicit` modes,
  crashed immediately with a CLI parse error before this was fixed. The
  correct flags: no `--outputType` needed for CityGML→b3dm (that's the
  default); implicit tiling is `--tilingMode implicit` (marked
  `[Experimental]` in Mago's own `--help` output — see → below).
- ? **Mago 3DTiler requires the `--input` directory to be *writable*, not
  read-only.** `scripts/build.sh` originally mounted it `:ro`; this threw
  `java.io.IOException: /data/input path is not writable`. Fixed by
  dropping `:ro` from the Docker volume mount.
- ? **`--crs <EPSG code>` (6697, 6668, and 4326 were all tried) silently
  produces geographically WRONG output** — the building was placed at
  approximately 137°W, 37°N (off the California coast) instead of 143°E,
  43°N (Hokkaido). Root cause: PLATEAU's `gml:pos` coordinates are ordered
  (lat, lon, height), but Mago's `--crs` path assumes (lon, lat) order.
  **Fix:** pass an explicit Proj4 string via `--proj` declaring
  north-east-up axis order: `+proj=longlat +datum=WGS84 +axis=neu
  +no_defs`. Verified correct for both Sarabetsu's and Muroran's small
  files (output matched source envelope exactly in both cases). Recorded
  in `config/{sarabetsu,muroran}.yml`'s `crs.mago_proj` field.
- ? **The `small` profile did not actually build only the small file.**
  Mago's `--input` takes a *directory* and converts every CityGML file
  found in it; `scripts/build.sh` was mounting the small file's *parent
  directory* (`udx/bldg/`, containing all ~100–190 building mesh files for
  that municipality), not an isolated copy of just the one selected file.
  First `explicit small` test run produced 202 tile contents from "one"
  file — i.e. it silently built the entire municipality's buildings on
  every "small" run. **Fix:** `scripts/build.sh` now copies the single
  selected file into an isolated per-build staging directory
  (`data/.build-staging/<dataset>/<build-id>/`) before mounting it. After
  the fix, the same command produced exactly 2 tile contents (matching the
  file's single building).
- ? **Real 3D Tiles 1.1 Implicit subtree output from Mago 3DTiler is a
  `.json` + `.bin` pair** (e.g. `subtrees/R/0/0/0.json` referencing
  `subtrees/R/0/0/0.bin` via `buffers[].uri`), **not the combined binary
  `.subtree` file format** (magic bytes `"subt"` + header + inline JSON +
  binary chunk) that `tools/inspect_subtree.py` and `tools/normalize.py`
  are built to decode. Both are legal per the 3D Tiles 1.1 spec, but our
  tooling only implements the binary form. Consequence, confirmed by
  actually running `make validate`: it reports **"Subtree files: 0"**
  against real Implicit output — the subtree inspection/validation step is
  currently a silent no-op against Mago's actual output. See ↓ below —
  this is now the single highest-priority tooling gap.
- ? The independent `npx 3d-tiles-validator` (unpinned version, `0.6.1` as
  installed 2026-08-24) found **real `METADATA_INVALID_LENGTH` errors** in
  Mago's GLB output — `BatchId` and `FileName` structural-metadata property
  buffer views have byte lengths inconsistent with their declared string
  offsets. `scripts/validate.sh` printed `VALIDATION PASSED` regardless
  (it does not gate on the validator's own `numErrors` field — a real,
  minor bug in `scripts/validate.sh`, not yet fixed).

### Upstream candidates

- → **`METADATA_INVALID_LENGTH` root-caused precisely (2026-08-25) — turns
  out to be more ambiguous than "a Mago bug," not less interesting.**
  Decoded the actual `stringOffsets`/`values` bufferViews by hand for both
  Explicit and Implicit tiles: in every flagged property, the declared
  `byteLength` exceeds the content the `stringOffsets` actually require by
  exactly enough to round up to the next multiple of 4 bytes (e.g.
  Implicit's `FileName`: offsets end at 50, declared byteLength 52;
  Explicit's `BatchId`: offsets end at 1, declared byteLength 4). This is
  the standard "pad binary buffer views to 4-byte alignment" pattern
  common in glTF binary data — not obviously a content bug. Whether
  `EXT_structural_metadata`'s spec requires exact-length bufferViews (in
  which case Mago's alignment padding is non-conformant) or tolerates
  trailing padding (in which case `3d-tiles-validator` is being overly
  strict) has **not been checked against the normative spec text** — this
  needs resolving before deciding which project (if either) to report to.
  `scripts/validate.sh` correctly surfaces this as a failure either way
  (per its job of not hiding real validator output), but "Mago has a
  metadata bug" should not be asserted as fact until this is resolved.
- → `--tilingMode implicit` is explicitly marked `[Experimental]` in Mago
  3DTiler's own `--help` output (v1.16.2). Per `docs/limitations.md`, this
  is stated here accurately and neutrally, not as a defect — but it means
  Claims 1/2/3 for Implicit specifically should be read with that caveat.

### Next smallest experiment

Phase 1 is complete; proceed to Phase 2 (already partially executed — see
below) and prioritize the subtree-format tooling gap.

---

## Phase 2: Small Sarabetsu Village Implicit output

**Status: Partially complete, validation tooling gap closed.** 2026-08-25.
Implicit output was successfully generated and geographically verified;
the subtree-format tooling gap flagged below has since been fixed (same
day) — see the update at the end of this section.

### Confirmed

- ✓ Implicit 3D Tiles generated from the same small_file input:
  `make build DATASET=sarabetsu MODE=implicit PROFILE=small` (with the
  Phase 1 fixes applied) produced a valid `tileset.json` declaring
  `implicitTiling` (QUADTREE, 4 subtree levels — Mago's default; our
  `config/common.yml`'s `tiling.subtree_levels: 3` is not currently wired
  into `scripts/build.sh` — see ↓), one content tile
  (`data/R/3/4/2.glb`), and one subtree (`subtrees/R/0/0/0.json` +
  `.bin`).
- ✓ Same geographic placement fix (`--proj` with `+axis=neu`) applies
  identically to Implicit mode — verified by decoding the output region
  back to degrees.
- ✓ **(2026-08-25 update) Actually loaded and rendered in a real browser,
  from a real public host — not just structurally well-formed.** Full
  detail and the CesiumJS version bug this uncovered: see Phase 4 below
  (Claim 4, practical consumption). Short version: CesiumJS 1.117 (the
  version originally pinned in `viewer/index.html`) never renders this
  output — confirmed the exact same failure with the official
  `CesiumGS/3d-tiles-samples` implicit-tiling sample too, so it's a
  CesiumJS bug, not a defect in Mago's output. CesiumJS 1.144 (latest)
  renders it correctly. `viewer/index.html` now pins 1.144.
- ✓ **(2026-08-25 update) Subtree validation now actually runs.**
  `tools/inspect_subtree.py` and `tools/normalize.py` were extended to
  detect and decode the real JSON+`.bin` subtree pair (by content shape —
  presence of `tileAvailability`/`contentAvailability`/
  `childSubtreeAvailability` keys — since these files have no fixed name).
  Re-running `make validate`: `Subtree files: 1` (was 0), decoded
  correctly (`tiles=1 content=0 children=0` for the one-building
  small_file build), and the report is written to
  `manifests/reports/subtree-validation-*.json` as designed.
- ✓ **(2026-08-25 update) `scripts/validate.sh` now actually fails on real
  validator errors.** It previously printed `VALIDATION PASSED`
  regardless of the `3d-tiles-validator`'s own `numErrors` field (the CLI
  exits 0 even when it reports content errors). Fixed to parse
  `numErrors` from the validator's JSON output; re-running now correctly
  prints `VALIDATION FAILED: 1 error(s)` for the real
  `METADATA_INVALID_LENGTH` finding in Mago's GLB metadata (see Phase 1
  Unexpected findings, and the Upstream candidates note below on why its
  status is "ambiguous," not "confirmed Mago bug") — this was a real
  finding being silently hidden by our own tooling, not a false alarm.
- ✓ **(2026-08-25) Explicit-vs-Implicit comparison done by decoding both
  outputs' `EXT_structural_metadata` directly.** No missing or duplicate
  geometry: both represent the same single building's LOD0+LOD1 (1 mesh,
  5 accessors per LOD, `FileName=63437290_bldg_6697_op.gml` in every
  case). The two modes structure it differently, not incorrectly:
  Explicit emits two separate `.glb` files (`RC0000.glb` LOD0,
  `RC1000.glb` LOD1), each with a `propertyTable.count=1`; Implicit merges
  both LODs into the single `data/R/3/4/2.glb` content tile, with
  `propertyTable.count=2` (`BatchId` 0 and 1, both rows sharing the same
  `FileName`). This — two batched rows in one Implicit content tile —
  is also *why* the `METADATA_INVALID_LENGTH` alignment-padding pattern
  was easier to spot in Implicit output than Explicit's (Explicit's
  single-row tables have the same padding, just a smaller, easy-to-miss
  offset).

### Partially confirmed

*(Resolved 2026-08-25 — was: subtree validation reporting "0" against
real output. See Confirmed above.)*

### Not confirmed

- ✗ Geometric error / hierarchy comparison against docs/test-plan.md's
  full checklist (bounding volumes at each tree level, refinement
  strategy differences) — feature-count/identity reconciliation above is
  done, but the tree-structure-level comparison is not.
- ✗ "Implicit output... validates independently" (docs/hypothesis.md Claim
  1) — now genuinely evaluable (tooling fixed), and the honest answer is
  **not yet**: `3d-tiles-validator` reports a real `METADATA_INVALID_LENGTH`
  error against this build. Not a tooling false-negative this time.

### Unexpected findings

*See Phase 1 for the subtree format and `--tilingMode implicit`
[Experimental] findings (now fixed in tooling, see Confirmed above) and
the `METADATA_INVALID_LENGTH` validator finding.*

- ? **CesiumJS 1.117 never renders Implicit Tiling content — reproduced
  with two completely independent tilesets, so it's a CesiumJS bug, not a
  data problem.** Found while actually loading the real, published
  Sarabetsu Implicit build in the GitHub Pages viewer
  (`viewer/index.html`, which pinned CesiumJS 1.117). Symptom, confirmed
  by direct inspection of `Cesium3DTileset` internals in the browser
  console: `tileset.statistics.visited` stays `0` forever — the traversal
  never visits even the root tile, so the subtree file is never requested
  (confirmed via `performance.getEntriesByType('resource')`: only
  `tileset.json` was ever fetched, never the subtree). This reproduced
  identically with the **official `CesiumGS/3d-tiles-samples`
  `1.1/SparseImplicitQuadtree` sample tileset** (combined-binary
  `.subtree` format — ruling out our JSON+bin format as the cause) loaded
  through the same viewer code. **Upgrading to CesiumJS 1.144 (current
  latest) fixed it immediately** — `tileset.statistics` went from
  `{visited:0, selected:0}` to `{visited:5, selected:1,
  numberOfFeaturesSelected:2, numberOfTrianglesSelected:14}`, matching our
  known "1 building, LOD0+LOD1" test data exactly. `viewer/index.html` now
  pins 1.144. **Not bisected** to find which exact version between 1.117
  and 1.144 (27 releases) fixed it — see ↓.
- ✓ **Claim 4 (practical consumption) has real, positive first evidence**:
  a real build, published to a real public host
  (`tunnel.optgeo.org`, via `scripts/publish.sh`), loaded and rendered
  correctly in the GitHub Pages-hosted viewer (`https://dwg7.github.io/plateau-mago-implicit/`)
  over real HTTPS/CORS, in a real browser. `docs/hypothesis.md`'s Claim 4
  status updated accordingly.

### Upstream candidates

*See Phase 1.* The CesiumJS 1.117 implicit-tiling traversal bug above is
**not** an upstream candidate — it's already fixed as of 1.144 (current
latest), so there's nothing to report; noted here purely as a warning for
anyone still pinned to an old CesiumJS release.

### Next smallest experiment

↓ Optionally bisect which CesiumJS release between 1.117 and 1.144 fixed
the implicit-tiling traversal bug, by checking that version's CHANGES.md
— useful context (not blocking) if this project ever needs to state a
minimum supported CesiumJS version precisely.

↓ Wire `config/common.yml`'s `tiling.subtree_levels` into
`scripts/build.sh`'s Mago invocation (`--implicitSubtreeLevels`) — currently
unused, so Mago's default of 4 is used regardless of what's configured.

↓ Prepare a minimal reproduction of the `METADATA_INVALID_LENGTH`
error (`BatchId`/`FileName` buffer-view length mismatches) as a proper
upstream report per `CONTRIBUTING.md`'s process, now that it's confirmed
as a real, validator-detected defect rather than a hypothesis.

---

## Phase 3: Determinism

**Status: Formally complete for Sarabetsu Village, implicit mode, small
profile (single building).** 2026-08-25. The formal `docs/test-plan.md`
procedure — two concurrency settings, full `docs/determinism.md`
classification, a proper run log — has now been executed, not just the
earlier single-pair preliminary check.

### Confirmed

- ✓ **(2026-08-25) With the GLB normalization fix in place, the same two
  builds from the preliminary check now correctly classify as
  Repeatability: L2, Determinism: PASS** — `tileset.json`, the subtree
  JSON+bin, and now the GLB's normalized content (embedded random ID
  redacted before hashing) are all either byte-identical or classified
  `byte-only`. `manifests/reports/comparison-*.md` for this pair now
  records `byte-only` for `data/R/3/4/2.glb`, not `geometry`.
- ✓ This confirms the Phase 1/2 preliminary read was correct: the earlier
  L3/FAIL was a tooling false-negative (a benign, non-geometric random ID
  Mago embeds per-run), not evidence of real non-determinism in
  mago-3d-tiler's actual conversion output.
- ✓ **(2026-08-25) Formal two-concurrency-setting procedure run for real**:
  4 builds total (2× `CONCURRENCY=1`, 2× `CONCURRENCY=4`), all back-to-back
  in the same pinned environment. All four root `tileset.json` files are
  **byte-identical** (same SHA-256,
  `4e8640202f3cb3720a934c1379595b3452295199ed03495add0d85e16b5d83bd`,
  verified directly from each build's own manifest, not just inferred).
  Three pairwise comparisons — concurrency=1 vs 1, concurrency=4 vs 4, and
  directly across concurrency=1 vs concurrency=4 — each classify **L2 /
  PASS**, with the only difference in every case being the same benign
  embedded-UUID `byte-only` difference in `data/R/3/4/2.glb`. Concurrency
  setting itself introduced no additional differences. Full detail and the
  run log: `docs/determinism.md` Results.
- ✓ **(2026-08-25) Unexpected finding while running this: `scripts/compare-builds.sh`
  and `scripts/build.sh`'s "full profile" branch both used `mapfile` (a bash
  4+ builtin), which fails immediately with `mapfile: command not found`
  under macOS's stock `/bin/bash` (3.2 — Apple ships an old bash for
  licensing reasons) whenever `#!/usr/bin/env bash` resolves to it ahead of
  a newer bash on `PATH`. This is a real, reproducible portability bug, not
  environment-specific noise: it blocks `make compare` (and the `full`
  profile of `make build`) on an unmodified macOS PATH. Fixed by replacing
  both `mapfile` calls with a portable `while IFS= read -r; do …; done`
  loop; re-verified `make compare` succeeds under both plain `/bin/bash`
  (3.2) and Homebrew's bash 5.

### Unexpected findings

- ? **Root cause of the GLB difference, found by byte-diffing the two
  files (`cmp -l`), hex-dumping the differing region, and then precisely
  identified by decoding the `EXT_structural_metadata` property table:**
  it's the **`id` property** — Mago's default metadata schema
  (`NodeName`, `BatchId`, `FileName`, `id`) generates a **fresh random
  UUID for `id` on every run** (e.g.
  `3343371d-a841-49a5-b6d1-90a1d6104b68a35ea799-7725-4603-a13b-822dfbf87d5c`
  in run 1 vs. a different value in run 2 — this is also the same
  mechanism behind the Phase 1 finding that the source `gml:id` is not
  retained; `id` is Mago's own generated identifier, unrelated to the
  source `gml:id`). All 61 differing bytes between the two GLBs fall
  within this one embedded string; everything else in the file — `NodeName`,
  `BatchId`, `FileName`, and the actual mesh/geometry buffers — is
  byte-identical.
  **This is exactly the class of difference `docs/determinism.md` already
  anticipated and classified as normalizable** ("Embedded timestamps or
  UUIDs in output"), but `tools/normalize.py` does not currently redact or
  otherwise normalize any content inside GLB files — it only computes a
  raw SHA-256 over the whole file (see the PR #1 code review finding on
  this, already tracked in `HANDOVER.md`). Once GLB-internal UUID
  normalization is implemented, this specific build pair would very likely
  reclassify as Level 1 or Level 2, not L3/FAIL. **(2026-08-25: implemented
  and confirmed — see Confirmed above.)**

### Upstream candidates

- → The embedded UUID's purpose is unclear (feature ID? processing
  trace ID?) and it is not obviously required for correct 3D Tiles
  playback. If it serves no client-facing purpose, this could be raised
  with Mago 3DTiler as a documentation question rather than a bug — not
  prepared yet.

### Next smallest experiment

Phase 3 is formally complete for this dataset/mode/profile. Phase 4
(expanded Sarabetsu test, many buildings) is next — it should re-check
whether concurrency affects determinism at real scale, since one building
processed on any thread count is not a strong test of parallel-write
races that could only show up with many buildings/tiles in flight at
once.

---

## Phase 4: Expanded Sarabetsu Village test

*Not started. Blocked on Phase 3 completing formally (docs/scope.md: do not
skip ahead of the corresponding smaller phase).*

---

## Phase 5: Small Muroran City test

*Not started as a formal phase run. A config-verification spot check was
done during Phase 0 (see below) to confirm the CRS/proj fix generalizes to
Muroran before recording it in `config/muroran.yml` — this is not a Phase 5
run and Phase 5 should still start fresh once Phase 1–4 for Sarabetsu are
complete.*

- ✓ (spot check only) `+proj=longlat +datum=WGS84 +axis=neu +no_defs` also
  correctly places Muroran's small_file
  (`udx/bldg/63403767_bldg_6697_op.gml`): output matched the source
  envelope exactly (140.9694°E, 42.3076°N).

---

## Phase 6: Expanded Muroran City test

*Not started.*

---

## Phase 7: Optional higher-detail tests

*Not started. Phase 7 is optional and separate.*

---

## Summary table

| Claim | Status | Phase evaluated | Notes |
|---|---|---|---|
| Conversion feasibility | Partially confirmed | 1, 2 | Explicit fully confirmed for the small_file; Implicit generated, geographically correct, now fully validatable (subtree tooling gap closed), AND confirmed rendering correctly in a real browser (CesiumJS 1.144) — but validation surfaced a real Mago defect (`METADATA_INVALID_LENGTH`), so "validates independently" is currently ✗ |
| Determinism | Confirmed (Level 2) for small profile | 3 (formal) | Initial L3/FAIL was a tooling false-negative (a benign per-run random ID in GLB metadata); after fixing `tools/normalize.py` to redact it, formal Phase 3 (4 builds, concurrency=1 and concurrency=4, 3 pairwise comparisons) confirms L2/PASS in every comparison, with byte-identical `tileset.json` across all 4 builds. Not yet re-checked at Phase 4 (multi-building) scale |
| Reproducibility | Partially confirmed | 0 | Source checksums and Mago JAR checksum both independently re-verified (fetch.sh's own check; Dockerfile's own check) — a third party could reproduce Phase 0/1 fetch+build from this repo's config as-is |
| Practical consumption | Partially confirmed | 2 | A real build, published to a real public host (tunnel.optgeo.org) over real HTTPS/CORS, loaded and rendered correctly in the GitHub Pages-hosted viewer in a real browser — but only tested with the tiniest possible dataset (1 building); navigation/memory/long-session behavior at any real scale is still untested |

Do not pre-fill conclusions. Record only evidence-based findings.
