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
  common in glTF binary data — not obviously a content bug.
- → **(2026-08-25) Checked against the normative spec text and the
  validator's own source — genuinely ambiguous, not resolvable to
  "confirmed bug" on either side; recommend an upstream *clarification
  question*, not a bug report.** Read the primary sources directly rather
  than inferring from behavior:
  - `EXT_structural_metadata`'s spec
    ([CesiumGS/glTF, `3d-tiles-next` branch](https://github.com/CesiumGS/glTF/blob/3d-tiles-next/extensions/2.0/Vendor/EXT_structural_metadata/README.md))
    and the `propertyTable.property.schema.json` it defines say nothing
    about the `values` buffer view's `byteLength` needing to exactly equal
    the content length implied by `stringOffsets` — the spec only defines
    how to *compute* a string's length from consecutive offsets, not a
    constraint on the containing buffer view's declared size. The same
    spec document *does* explicitly describe padding elsewhere (GLB `BIN`
    chunk padded to an 8-byte boundary, "byte length of the BIN chunk may
    be up to 7 bytes larger than JSON-defined `buffer.byteLength`"),
    confirming trailing padding is an anticipated, normal part of this
    extension's binary encoding at the chunk level — just not stated
    either way at the individual-bufferView level.
  - `3d-tiles-validator`'s own implementation
    (`src/validation/metadata/BinaryPropertyTableValidator.ts`,
    `computeNumberOfValues()` + `validateValuesBufferViewByteLength()`)
    computes the expected length for a STRING property as *exactly* the
    last `stringOffset` value, then rejects the buffer view on any
    deviation (`actualByteLength !== expectedByteLength`, zero tolerance).
    This is a deliberate, hand-written strict-equality check — not a
    validator bug in the sense of misreading the spec, since the spec
    doesn't state the rule either way at this level; it's a validator
    design choice that happens to reject Mago's common alignment-padding
    convention. No spec citation appears in the validator's code comments
    or the PR that introduced it
    ([CesiumGS/3d-tiles-validator#357](https://github.com/CesiumGS/3d-tiles-validator/pull/357)
    and its predecessor metadata-validation PRs #236–238).
  - No prior GitHub issue in `CesiumGS/3d-tiles-validator` discusses this
    specific question (searched for `METADATA_INVALID_LENGTH` and
    `byteLength`/padding — no hits).
  **Conclusion:** neither "Mago has a metadata bug" nor "the validator is
  wrong" can be asserted as fact — the spec is silent on this specific
  point, and the validator's strictness is a defensible-but-undocumented
  design choice. `scripts/validate.sh` correctly continues to surface this
  as a real validation failure (per its job of not hiding real validator
  output). The appropriate next action, if pursued, is a clarification
  *question* to `CesiumGS/3d-tiles-validator` or the `EXT_structural_metadata`
  spec repo asking whether the `values` buffer view's `byteLength` must
  exactly match the content length or may include alignment padding — not
  a bug report against either project.
- → `--tilingMode implicit` is explicitly marked `[Experimental]` in Mago
  3DTiler's own `--help` output (v1.16.2). Per `docs/limitations.md`, this
  is stated here accurately and neutrally, not as a defect — but it means
  Claims 1/2/3 for Implicit specifically should be read with that caveat.

### Next smallest experiment

Phase 1 is complete; proceed to Phase 2 (already partially executed — see
below) and prioritize the subtree-format tooling gap.

---

## Phase 2: Small Sarabetsu Village Implicit output

**Status: All docs/test-plan.md comparison items complete; one pass
criterion still failing for a real, root-caused reason.** 2026-08-25.
Implicit output was successfully generated, geographically verified, and
now fully compared against Explicit (including the hierarchy/geometric
error item, completed last). The one remaining gap is a pass criterion,
not a comparison item: "validates independently" is currently ✗ because
of the real `METADATA_INVALID_LENGTH` finding (status: ambiguous, not yet
resolved against the spec — see Upstream candidates).

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
  Explicit emits two separate `.glb` files, each with a
  `propertyTable.count=1`; Implicit merges both LODs into the single
  `data/R/3/4/2.glb` content tile, with `propertyTable.count=2` (`BatchId`
  0 and 1, both rows sharing the same `FileName`). This — two batched
  rows in one Implicit content tile — is also *why* the
  `METADATA_INVALID_LENGTH` alignment-padding pattern was easier to spot
  in Implicit output than Explicit's (Explicit's single-row tables have
  the same padding, just a smaller, easy-to-miss offset).
- ? **(2026-08-25) Correction: the Explicit LOD↔filename mapping stated
  above in an earlier version of this entry was backwards.** It previously
  claimed `RC0000.glb` = LOD0, `RC1000.glb` = LOD1 — a guess from the
  numeric filename prefix that was never actually checked against the
  mesh geometry. Decoding both GLBs' `POSITION` accessor bounds directly:
  `RC0000.glb`'s mesh spans a real Z range (`min=[-2.20, -1.95, -1.00]`,
  `max=[2.20, 1.95, 1.00]` — 2 local units of vertical extent), while
  `RC1000.glb`'s spans essentially zero Z (`min`/`max` both
  ≈ `-6.8e-7`). Both files share the same rotation quaternion (their
  local axes are oriented identically), so this isn't an artifact of
  differing transforms. Cross-checked against
  `docs/information-retention.md`, independently recorded the same day:
  the source building's `bldg:measuredHeight` is `2` (metres), and that
  value is "used-for-geometry," i.e. baked into a mesh rather than kept as
  a named property — matching `RC0000.glb`'s 2-unit Z extent exactly.
  **Corrected mapping: `RC0000.glb` = LOD1 (solid, ~2 m tall), `RC1000.glb`
  = LOD0 (flat footprint).** Also structurally notable while checking
  this: the Explicit tree does **not** encode LOD0→LOD1 as a
  coarse-to-fine refinement chain in one branch — both LODs are separate
  sibling branches under the root, refined independently down through 4
  levels each to their own single content leaf (root `refine: REPLACE`,
  every other node `refine: ADD`), so a client always loads both LODs
  together rather than refining from one into the other. See "Hierarchy
  and geometric error comparison" below for the full tree structure.
- ✓ **(2026-08-25) Hierarchy and geometric error comparison** — the
  remaining `docs/test-plan.md` Phase 2 comparison item. Both
  `tileset.json` files fetched directly from the published build and
  decoded by hand:

  **Explicit** (`data/output/sarabetsu/explicit/small/latest/tileset.json`):
  tileset-level `geometricError: 16.0`; root has no content, `refine:
  REPLACE`, `geometricError: 120.01`, and 2 children — one per LOD (see
  the LOD↔filename correction above). Each branch independently refines
  through 4 levels (`refine: ADD` throughout) with an identical
  geometricError sequence **120.01 → 50.01 → 8.01 → 0.01**, terminating in
  a single content leaf (`RC0000.glb` or `RC1000.glb`). 9 tiles total (1
  root + 2 branches × 4 levels). Each branch's bounding volume is tightly
  fit to *that LOD's own real extent*: the LOD1 branch's region spans a
  ~2 m height band matching its solid geometry; the LOD0 branch's region
  is a near-zero-height band matching its flat footprint. Root `refine:
  REPLACE` with two always-loaded `ADD` children means both LODs load
  together — there's no single-branch coarse-to-fine LOD0→LOD1 refinement
  here, structurally unlike a typical progressive-LOD tileset.

  **Implicit** (`.../implicit/small/latest/tileset.json`): tileset-level
  `geometricError: 154.376`; root has `refine: ADD`, `geometricError:
  64.0`, content is a URI template (`data/R/{level}/{x}/{y}.glb`), and an
  `implicitTiling` block declaring `subdivisionScheme: QUADTREE`,
  `availableLevels: 4`, `subtreeLevels: 4`. Only the root's geometricError
  is stored explicitly — per-level values for descendant tiles are
  computed by the client from the quadtree subdivision (architecturally
  different from Explicit's approach of storing every level's value, not
  just numerically different; the exact client-side formula wasn't
  independently verified here). One subtree file
  (`subtrees/R/0/0/0.json`), decoded with the now-fixed
  `tools/inspect_subtree.py` (see "Two real bugs" below):
  `tileAvailability=4`, `contentAvailability=1`,
  `childSubtreeAvailability=0`. The known single content tile is
  `data/R/3/4/2.glb` (level 3, x=4, y=2); a quadtree's minimum
  ancestor-to-leaf chain for one level-3 tile is exactly 4 tiles (levels
  0, 1, 2, 3), matching `tileAvailability=4` exactly — consistent with
  "this subtree marks only the ancestor path to its one populated leaf as
  available," though the individual bit positions in the availability
  bitstream weren't decoded to confirm this beyond the count match. Unlike
  Explicit, tile bounding volumes here come from the quadtree's uniform
  spatial subdivision of the tileset's overall region, not from
  per-LOD-fitted geometry.

  **Net comparison:** both trees reach the same single building with no
  missing/duplicate geometry (already confirmed above), but express
  LOD and spatial subdivision through structurally different mechanisms —
  Explicit: geometry-fitted bounding volumes, explicit per-level
  geometricError, independent sibling LOD branches; Implicit:
  spec-uniform quadtree bounding volumes, client-computed per-level
  geometricError, both LODs merged into one content tile at the
  deepest available level. Neither is more "correct"; this is the two
  modes' designed structural difference, per `docs/test-plan.md`'s
  framing of this as a comparison item, not a pass/fail check.

- ? **(2026-08-25) Two real bugs found in `tools/inspect_subtree.py` and
  `tools/normalize.py` while doing the hierarchy comparison above — both
  fixed.** (1) Both tools read `subtreeLevels` from the *subtree file's
  own* JSON header (`header.get("subtreeLevels", 1)`), but real
  mago-3d-tiler subtree files never declare this key — per the 3D Tiles
  1.1 spec it's inherited from the tileset's `implicitTiling` block, not
  the subtree. This silently defaulted `subtree_levels` to 1 for every
  real build, undercounting `total_tiles` and misreporting availability:
  the earlier-recorded "tiles=1 content=0 children=0" (see Phase 2
  Confirmed above, subtree tooling gap) was **wrong** — hand-decoding the
  raw bitstream (`cmp`/`xxd` against the subtree's own declared
  `availableCount` fields) confirms the correct values are **tiles=4,
  content=1, children=0**. Fixed by reading `subtreeLevels` from the
  sibling `tileset.json` instead (new `find_subtree_levels()` helper in
  both tools). (2) `tools/normalize.py`'s `_subtree_availability()` never
  handled `contentAvailability` being a JSON array (real mago output uses
  a one-element list, per spec, for multi-content support) — it always
  crashed with `'list' object has no attribute 'get'`, silently caught by
  an outer `try/except` and recorded as an opaque `"error"` string in
  *every* normalized manifest generated so far (`inspect_subtree.py`
  already handled this correctly; `normalize.py` did not). Fixed to match
  `inspect_subtree.py`'s existing list-handling logic. Re-verified: both
  tools now report tiles=4/content=1/children=0 for the same real build;
  all four Phase 3 normalized manifests regenerated with the fix; the
  three Phase 3 comparison reports re-run and unchanged (still L2/PASS —
  these counts weren't used in the hash-based comparison itself, only in
  informational reporting). Also had to add `from __future__ import
  annotations` to both files: a new top-level helper function used
  `int | None`-style annotations (already present, but dormant, elsewhere
  in `inspect_subtree.py`), which crashes at import time on this
  environment's Python 3.9 without that import — a latent version-
  compatibility gap, not previously exercised because the affected code
  paths had never actually run.

### Partially confirmed

*(Resolved 2026-08-25 — was: subtree validation reporting "0" against
real output. See Confirmed above.)*

### Not confirmed

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
- ✓ **(2026-08-25, reported by the user directly, fix confirmed by the
  user in their own browser) The GitHub Pages viewer loaded successfully
  but showed no building — not a tileset or CesiumJS defect, a wrong
  camera target in `viewer/viewer.js`.** `VIEWPOINTS`'
  `destination` coordinates were a rough Sarabetsu/Muroran
  municipality-center guess ((143.1, 42.6) and (141.0, 42.3)) dating from
  before the small_file building's precise coordinates were established in
  Phase 1/5 — never corrected afterward. Computed the actual distance from
  each guess to the real, verified building location (143.2530°E,
  42.6604°N for Sarabetsu; 140.9694°E, 42.3076°N for Muroran, both from
  earlier Phase 1/5 findings): **14.2 km** for Sarabetsu, **2.7 km** for
  Muroran. At the previous 5000–8000 m viewing altitude with a 45°
  downward pitch, a building this size (bounding sphere radius ~77 m) at
  that distance is far outside the camera's view frustum — the tileset was
  correctly published and correctly loaded (confirmed independently
  earlier the same day via direct `fetch()` and manual `Cesium3DTileset`
  traversal against the real host), but the camera never pointed anywhere
  near it. Fixed by setting `destination` to each dataset's actual
  verified building coordinates at a much closer 300 m, with a straight
  nadir (`pitch: -90`) orientation specifically to guarantee the tiny
  building stays centered in frame regardless of forward-look offset —
  the kind of framing math error that caused this bug in the first place.
  Not independently re-confirmed by pixel/screenshot rendering in this
  session's automated browser tool — the same `document.visibilityState:
  "hidden"` testing artifact from the earlier CesiumJS-1.144
  re-verification (see Phase 2 "post-push" note in `HANDOVER.md`) blocked
  live tile selection there even after the fix — but **the user reloaded
  the live GitHub Pages page in their own browser and confirmed the single
  building is now visible**, closing the loop with real, human-verified
  evidence rather than just a coordinate-math argument.

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

↓ (2026-08-28: done — see "Cross-phase follow-up: small fixes" near the
end of this file. Re-confirmed the flag name via a fresh `docker run
<image> --help`, not just this note, before wiring it in — it's marked
"[Experimental]" by Mago itself.) Wire `config/common.yml`'s
`tiling.subtree_levels` into `scripts/build.sh`'s Mago invocation
(`--implicitSubtreeLevels`) — currently unused, so Mago's default of 4 is
used regardless of what's configured.

↓ (2026-08-25: superseded — see Phase 1 Upstream candidates, spec text now
checked.) If pursued further, prepare a minimal reproduction of the
`METADATA_INVALID_LENGTH` finding and file it as a *clarification
question* (not a bug report) against `CesiumGS/3d-tiles-validator` or the
`EXT_structural_metadata` spec repo, per `CONTRIBUTING.md`'s process — the
spec text doesn't settle whether trailing alignment padding on a
property-table `values` buffer view is conformant, so neither project can
honestly be told "you have a bug" yet.

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

**Status: Run for real, 2026-08-25.** Full-profile builds (all 187 real
building mesh files, 6,795 buildings, 61 MB under `udx/bldg/`) for both
modes, plus a formal multi-build determinism check at two concurrency
settings — the honest result is that **Claim 2 (determinism) fails at
full scale**, contradicting the Level 2/PASS Phase 3 established for the
single-building small profile. This is the single most important finding
of Phase 4.

### Confirmed

- ✓ Both modes convert the full municipality without crashing.
  `make build DATASET=sarabetsu MODE=explicit PROFILE=full`:
  build `20260825T134334Z-sarabetsu-explicit-full`, 31s, 202 tile
  contents, 203 output files, 15,958,768 bytes.
  `make build DATASET=sarabetsu MODE=implicit PROFILE=full`: build
  `20260825T134415Z-sarabetsu-implicit-full`, 31s, 804 tile contents,
  1061 output files, 18,180,034 bytes, 128 subtree files (1 root +
  127 children — the municipality's spatial extent needs more than one
  subtree's worth of quadtree depth, unlike the single-building
  small-profile case which fit in one). Root subtree:
  `tiles=54 content=6 children=127` (decoded with the `subtreeLevels`
  fix from Phase 2 — this is the first real test of that fix generalizing
  beyond the single-subtree small-profile case, and it does).
- ✓ **`find $SOURCE_DIR -name "*.gml"` in `scripts/build.sh`'s full-profile
  branch was scoped to the whole source tree, not `udx/bldg/`** — caught
  and fixed *before* ever running a full-profile build. A real PLATEAU
  package also contains `udx/dem`, `udx/frn`, `udx/luse`, `udx/tran`,
  `udx/veg` (terrain, street furniture, land use, roads, vegetation);
  unscoped, this would have fed all ~1,123 non-building-inclusive files
  into Mago, directly crossing CLAUDE.md's buildings-only scope boundary
  for the baseline. Fixed to search `$SOURCE_DIR/udx/bldg` specifically.
- ✓ **The `METADATA_INVALID_LENGTH` alignment-padding pattern holds
  consistently at full scale, strengthening the "benign padding, not
  content corruption" reading from Phase 1.** `3d-tiles-validator` against
  the full Explicit build: 169 affected content files, 263
  `METADATA_INVALID_LENGTH` leaf issues; against full Implicit: 679
  affected files, 1176 leaf issues. Computed the declared-vs-required byte
  delta for every single one of the 1439 combined instances: **100% are
  1, 2, or 3 bytes** — exactly the range needed to round up to a 4-byte
  boundary, zero outliers. If this were genuine content corruption rather
  than systematic alignment padding, a sample this large would be very
  unlikely to show zero deltas outside [1,3].
- ✓ **Content-size distribution for the full Implicit build** (804 tile
  contents): min 3,876 bytes, median 8,252 bytes, p90 31,556 bytes, max
  1,315,588 bytes (one content tile batching many buildings from a dense
  cluster), total 18,123,996 bytes.

### Not confirmed

- ✗ **Claim 2 (determinism): fails at full-profile scale.** Ran the exact
  `docs/determinism.md` procedure again, this time at full profile: 2
  builds at `CONCURRENCY=1` (`20260825T134415Z`, `20260825T134614Z`) and 2
  at `CONCURRENCY=4` (`20260825T134848Z`, `20260825T134925Z`). All four
  root `tileset.json` are byte-identical (same SHA-256,
  `016c449d47be9a1502a2f6f8170e241da76136f1da21322385f22a6b7f5da011`), but
  both same-concurrency pairs classify **L3 / FAIL**:
  - Concurrency=1 vs 1: 804/1061 common files differ; 794 `byte-only`
    (the known benign per-run UUID, same as Phase 3), but **10 files
    classified `geometry`** — real vertex/index binary differences, not
    metadata.
  - Concurrency=4 vs 4: similar picture (790 `byte-only`, 13 `geometry`),
    **plus one file, `data/R/5/13/12.glb`, present in one build and
    completely absent from the other** — a missing content tile between
    two builds of identical input, exactly the "missing or duplicate
    geometry between builds" case `docs/determinism.md` lists as
    operationally significant and "must not occur."
  - Output file counts themselves varied run-to-run at the same
    concurrency setting: 1061, 1061, 1060, 1061 across the four
    full-profile implicit builds — the 1060 case is the same missing-tile
    build.
- ✗ **Root-caused to one specific source file, not random/diffuse
  noise.** Every recurring `geometry`-classified content tile across both
  comparisons (`R/3/3/2`, `R/4/6/6`, `R/4/7/5`, `R/5/13/12`, `R/5/14/11`,
  `R/6/26/25`, `R/6/27/25`, `R/6/28/23`, `R/6/28/24`, `R/6/28/25`) was
  decoded for its `FileName` property values, and **every single one
  includes `63437175_bldg_6697_op.gml`** — a 15.3 MB source file
  containing 826 separate `bldg:Building` features (versus the 8,455-byte,
  1-building small_file used for Phase 1–3). Byte-diffing
  `data/R/3/3/2.glb` between the two `CONCURRENCY=1` runs (same JSON
  header, byte-identical apart from binary buffers): differences land in
  the `indices` bufferView (448/4796 bytes) and `positions` bufferView
  (1071/14532 bytes, concentrated in the last ~460 of 3633 floats — the
  tail of the vertex buffer, not scattered throughout), plus the expected
  `id_values` UUID bytes. This localizes cleanly to *this one source
  file's* geometry (most plausibly its triangulation/tessellation step,
  given the pattern — a large batch of buildings being non-deterministically
  ordered or triangulated) rather than to concurrency, tile-grid
  assignment, or any other file: no other source filename appears in any
  affected tile that `63437175_bldg_6697_op.gml` doesn't also appear in.

### Unexpected findings

- ? **The Phase 3 small-profile L2/PASS result was correct as far as it
  went, but was never a valid basis for a general determinism verdict** —
  exactly the caveat already recorded in `HANDOVER.md` after Phase 3
  ("one building processed on any thread count is not a strong test...").
  That caveat is now confirmed, not merely theoretical: real geometric
  non-determinism exists in Mago 3DTiler 1.16.2's output, but only
  manifests with a large multi-building source file, invisible at
  single-building scale regardless of how many times or at how many
  concurrency settings that single building is rebuilt.

### Upstream candidates

- → **A strong, well-isolated candidate for Mago 3DTiler, unlike
  `METADATA_INVALID_LENGTH`'s spec ambiguity — this one is unambiguous
  non-determinism, not a validator-strictness question.** Two builds of
  byte-identical input (same JAR, same Docker image, same CLI flags,
  verified via `git_dirty: false` / matching manifests) produce different
  mesh geometry and, in one observed case, a content tile that exists in
  one build and not the other. Root-caused to one specific 15.3 MB, 826-building
  source file (`63437175_bldg_6697_op.gml`); not yet minimized to a small
  standalone reproduction (would need extracting a small subset of that
  file's buildings that still reproduces the issue — not attempted this
  session). Worth a proper upstream report once minimized, per
  `CONTRIBUTING.md`'s process — this is exactly the kind of concrete,
  version-pinned, reproducible finding the project is meant to surface.

### Next smallest experiment

↓ Minimize `63437175_bldg_6697_op.gml` to the smallest subset of its 826
buildings that still reproduces a `geometry`-classified difference between
two same-input builds — needed before an upstream report can include a
practical reproduction case rather than a 15 MB file.

↓ Peak process memory, first-useful-render time, initial request
count/bytes, navigation responsiveness, geographic-jump convergence, and
browser long-session memory trend from `docs/test-plan.md`'s Phase 4
measurement list were **not measured this session** — they need either
`docker stats` monitoring during the build or live, interactive browser
testing beyond what this session's automated tooling could reliably do
(see the `document.visibilityState: "hidden"` testing-tool caveat
recorded earlier in this file and in `HANDOVER.md`).

---

## Phase 5: Small Muroran City test

**Status: Run for real, 2026-08-25.** Repeats Phase 1–3's small-profile
procedure (Explicit build, Implicit build, geographic/vertical
verification, formal determinism check) on Muroran's small_file
(`udx/bldg/63403767_bldg_6697_op.gml`) instead of Sarabetsu's — this
supersedes the earlier Phase 0 config-only spot check with a full,
evidence-based run through the actual pipeline.

### Confirmed

- ✓ Both modes convert Muroran's small_file without crashing. `make build
  DATASET=muroran MODE=explicit PROFILE=small`: build
  `20260825T135855Z-muroran-explicit-small`, 1s, 2 tile contents, 3 output
  files, 10,225 bytes. `make build DATASET=muroran MODE=implicit
  PROFILE=small`: build `20260825T135919Z-muroran-implicit-small`, 1s, 1
  tile content, 4 output files, 5,425 bytes, 1 subtree file (0 errors,
  `availableLevels: 3` — one fewer than Sarabetsu's small-profile 4,
  consistent with a single simple building needing less quadtree depth).
- ✓ **Geographic and vertical placement confirmed correct** — the same
  `+proj=longlat +datum=WGS84 +axis=neu +no_defs` fix from Sarabetsu
  generalizes, now verified through a real pipeline run rather than a
  config-only spot check: decoded the Implicit tileset's region back to
  degrees and got 140.96940°E–140.96958°E, 42.30758°N–42.30777°N —
  matching the known-correct 140.9694°E/42.3076°N exactly. Height range
  1.760–5.973 m (4.213 m span) closely matches the source's own declared
  `bldg:measuredHeight` of **4.6 m** (small discrepancy expected: the
  output range comes from actual mesh vertex bounds, not the declared
  attribute value directly).
- ✓ **Formal Phase 3-style determinism check, small profile: L2/PASS at
  both concurrency settings**, consistent with Sarabetsu's small-profile
  result. 4 builds total (`20260825T135919Z`, `20260825T140031Z` at
  `CONCURRENCY=1`; `20260825T140047Z`, `20260825T140049Z` at
  `CONCURRENCY=4`), all four with identical root `tileset.json` SHA-256
  (`c36ed337...`). Both same-concurrency comparisons classify L2/PASS
  (the same benign per-run UUID `byte-only` difference as every other
  small-profile comparison this session). This is a useful cross-check on
  Phase 4's finding: small-profile determinism holds regardless of
  *which* municipality's single building is used, reinforcing that Phase
  4's L3/FAIL was specifically about processing many buildings from one
  large source file, not something Sarabetsu-specific.
- ✓ **Same `METADATA_INVALID_LENGTH` pattern present, same
  alignment-padding signature.** Explicit: 2 errors (one per content
  file); Implicit: 1 error. Not re-decoded byte-by-byte again (already
  established the pattern conclusively at both small and full scale for
  Sarabetsu) — consistent with expectations, nothing new here.
- ✓ **No missing or duplicate geometry between Explicit and Implicit.**
  Decoded all three content GLBs (`RC000.glb`, `RC0000.glb` from
  Explicit; `data/R/2/2/1.glb` from Implicit): all three carry the same
  `FileName` (`63403767_bldg_6697_op.gml`), the same `propertyTable.count
  = 1`, and byte-identical geometry accessors (24-vertex `VEC3`, same
  min/max bounds in every file).

### Unexpected findings

- ? **Muroran's Explicit tree structure is qualitatively different from
  Sarabetsu's small-profile tree — a real "Special attention: Tile
  refinement" finding from `docs/test-plan.md`'s Phase 5 goal, not a
  bug.** Sarabetsu's Explicit small-profile tree (Phase 2) has **two
  sibling branches** under the root, one per PLATEAU LOD, each with
  *genuinely different geometry* (a flat footprint vs. a solid volume).
  Muroran's Explicit tree has **one single branch** with content at two
  different refinement depths (`RC000.glb` at `geometricError: 8.01`,
  `RC0000.glb` at `geometricError: 0.01`) — and those two files are
  **byte-identical in geometry** (same accessor, same vertex bounds).
  Root cause: Sarabetsu's source data has LOD0 and LOD1 both present (so
  Mago has two genuinely different geometries to place in sibling
  branches); Muroran's PLATEAU dataset is LOD1-only (confirmed in Phase
  0: "LOD {1} only" for the whole municipality), so Mago has only one
  real geometry and duplicates it across its own internal two-step
  refinement chain instead of expressing a second, different LOD. Same
  mode, same converter, structurally different output — driven entirely
  by what LODs the *source* data actually contains.

### Not confirmed

- ✗ Several of `docs/test-plan.md`'s Phase 5 "Special attention" items
  are genuinely about the *whole municipality's* varied terrain (slope
  and coastal conditions, high-latitude graphics precision at scale) —
  not meaningfully testable against one flat building's small_file. These
  remain open for Phase 6 (expanded Muroran), where the terrain variation
  they're meant to probe actually exists in the input.

### Next smallest experiment

Phase 5 (small profile) is complete. Phase 6 (expanded/full-profile
Muroran) is next if pursued — given Phase 4's finding that determinism
issues only appeared at full-profile scale with a large multi-building
source file, Phase 6 should specifically re-run the same determinism
procedure on Muroran's full profile to check whether the same class of
issue reproduces with Muroran's own building files, not just Sarabetsu's.

---

## Phase 6: Expanded Muroran City test

**Status: Run for real, 2026-08-25.** Full-profile builds (all 100 real
building mesh files, 55,906 buildings, 485 MB under `udx/bldg/` — bigger
on disk than Sarabetsu's full profile despite roughly 8× fewer buildings
having a materially larger per-file average size) for both modes, plus
the same formal two-concurrency-setting determinism procedure as Phase 4.
**Determinism fails here too — the Phase 4 finding generalizes beyond
Sarabetsu — but the failure pattern is meaningfully different, which
refines rather than just repeats the earlier finding.**

### Confirmed

- ✓ Both modes convert the full municipality without crashing. `make
  build DATASET=muroran MODE=explicit PROFILE=full`: build
  `20260825T140552Z-muroran-explicit-full`, 83s, 1259 tile contents, 1260
  output files, 76,202,797 bytes. `make build DATASET=muroran
  MODE=implicit PROFILE=full`: build `20260825T140722Z-muroran-implicit-full`,
  78s, 553 tile contents, 818 output files, 73,390,981 bytes, 132 subtree
  files (root: `tiles=58 content=46 children=131`).
- ✓ **`METADATA_INVALID_LENGTH` alignment-padding pattern holds here too,
  now across 4 independent full-profile validator runs (2 municipalities
  × 2 modes).** Muroran Explicit: 1164 affected files, 1871 leaf issues;
  Muroran Implicit: 528 affected files, 787 leaf issues. Every one of the
  2658 combined instances has a declared-vs-required byte delta of 1, 2,
  or 3 — the same 100%-within-alignment-padding-range result as
  Sarabetsu's full-profile run, now over 4097 combined instances across
  both municipalities and both scales with zero outliers.

### Not confirmed

- ✗ **Claim 2 (determinism) fails at Muroran's full-profile scale too —
  confirming Phase 4 generalizes, with a different failure shape worth
  distinguishing.** Same procedure: 2 builds at `CONCURRENCY=1`
  (`20260825T140722Z`, `20260825T140847Z`), 2 at `CONCURRENCY=4`
  (`20260825T141104Z`, `20260825T141217Z`), all four with byte-identical
  root `tileset.json` (SHA-256 `69175b76...`).
  - Concurrency=1 vs 1: 553/818 files differ; 548 `byte-only`, **5
    `geometry`** (`R/2/2/0`, `R/2/2/1`, `R/3/4/1`, `R/3/5/2`, `R/4/7/2`).
  - Concurrency=4 vs 4: 553/818 files differ; 528 `byte-only`, **25
    `geometry`** — five times as many geometry-affected tiles as the
    concurrency=1 pair, from a single comparison at each setting (not
    averaged over repeated trials, so this ratio is a signal worth
    following up, not a confirmed effect size).
  - Byte-diffed the largest affected tile (`R/2/2/1`, 13 batched
    buildings, 252,616 bytes): real differences in both `indices`
    (103/25,712 bytes) and `positions` (343/81,828 bytes) bufferViews,
    confirming genuine geometry non-determinism here too, not just the
    expected per-row UUID noise (which also differed, as expected, in the
    much larger `id_values` bufferView).
- ✗ **Unlike Sarabetsu, no single source file is common to every affected
  tile.** Decoded `FileName` values for all 5 concurrency=1
  geometry-affected tiles: the building files batched into each tile
  overlap partially (e.g. `63403788_bldg_6697_op.gml` appears in 3 of the
  5; `63414000_bldg_6697_op.gml` in a different 3 of the 5) but **no
  filename appears in all five**. Muroran's 100 building files are far
  more uniform in size than Sarabetsu's (no single 15 MB/826-building
  outlier), so many files get batched together per content tile instead
  of one large file dominating — consistent with a revised picture where
  the non-determinism isn't tied to one specific problem file, but to
  *how many buildings get batched into one content tile* in general, with
  larger batches carrying more risk regardless of whether that comes from
  one big source file (Sarabetsu) or several combined smaller ones
  (Muroran).

### Unexpected findings

- ? **This refines Phase 4's root-cause hypothesis, not just confirms
  it.** Phase 4's Sarabetsu finding could have been read as "one specific
  source file has a defect." Phase 6 rules that reading out: Muroran
  reproduces real geometry non-determinism with no comparable single-file
  culprit. The more defensible characterization now: **batching multiple
  buildings into one content tile's mesh (via whatever triangulation/merge
  step Mago performs) is where the non-determinism actually lives**,
  independent of which municipality or which specific source file
  supplies those buildings.
- ? **(2026-08-25/26 follow-up) The concurrency effect is confirmed, not
  just a single-comparison hint — and it has a clean, specific shape.**
  Built 2 more `CONCURRENCY=1` runs (`20260825T193738Z`,
  `20260825T193913Z`) and compared them: **exactly 5 `geometry`-classified
  tiles again, and it's the literal same 5 tiles** (`R/2/2/0`, `R/2/2/1`,
  `R/3/4/1`, `R/3/5/2`, `R/4/7/2`) as the first concurrency=1 pair, byte
  for byte the same set. This isn't noise fluctuating around 5 — at
  concurrency=1, the same fixed subset of tiles is unstable every time,
  while everything else stays reproducible. Cross-checked against the
  concurrency=4 pair's 25 affected tiles: **all 5 of the concurrency=1
  tiles are a subset of the concurrency=4 set** — concurrency=4 doesn't
  replace the baseline instability, it adds ~20 more unstable tiles on
  top of it. This is now a real, well-characterized finding, not a
  single-sample hint: there's a baseline, thread-count-independent
  non-determinism affecting a fixed, identifiable set of tiles, and
  concurrency adds further instability beyond that baseline.

### Next smallest experiment

↓ (2026-08-25/26: partially done — see the follow-up above, which
confirms the concurrency effect with 2 pairs at each setting rather than
1. A larger n, e.g. 5+ pairs at each setting, would firm up the exact
"how much does concurrency add" effect size, and checking whether the
concurrency=4 tile *set* is stable run-to-run the way the concurrency=1
set is would be the natural next question.)

↓ (2026-08-27: this question now has an answer — see "Cross-phase
follow-up: additional determinism sampling" near the end of this file.
Short version: concurrency=4 has a stable 19-tile core across 3 pairs,
plus some build-specific extra instability at the edges — not perfectly
rock-solid like concurrency=1's exact-same-5-tiles-every-time, but not
random either.)

↓ If a minimal reproduction is ever pursued (per Phase 4's note, not
committed to), Muroran's diffuse multi-file pattern is actually easier to
reason about for isolating "does batch size alone predict non-determinism
risk" than Sarabetsu's single dominant file — e.g. deliberately building
tiny batches of 2, 5, 10 buildings and checking at what batch size
geometry differences start appearing.

---

## Cross-phase follow-up: LOD1-baseline enforcement (2026-08-26)

**Status: Done, verified against real data.** Prompted by the user
reporting a visual artifact in the viewer ("texture pasting looks
incomplete/half-done, competing with what's underneath" on a large
Sarabetsu building) — this turned out to be a real scope-boundary gap in
every full-profile build up to this point, not a rendering bug.

### Confirmed

- ✓ **The already-published full-profile builds (Phase 4/6) contained
  LOD3 geometry, crossing CLAUDE.md's explicit LOD1-baseline scope
  boundary.** Checked directly: Sarabetsu's `udx/bldg/` has
  `bldg:lod3Solid` (28), `bldg:lod3Geometry` (24), and `bldg:lod3MultiSurface`
  (14,858) elements across the dataset, concentrated in 4 buildings inside
  `63437175_bldg_6697_op.gml` — the same file Phase 4 already identified
  as the source of full-profile non-determinism. One of those 4 buildings
  alone has 2,004 `lod3MultiSurface` elements and a 5.5 MB XML footprint.
  No `app:ParameterizedTexture`/`app:Appearance` elements exist anywhere
  in the dataset (re-confirmed the Phase 0 "0 texture references"
  finding), so the visual artifact isn't a real photo-texture — it's
  multiple overlapping *geometric* representations of the same building
  (LOD0 + LOD1 + LOD3, all loaded together via `refine: ADD`) that read
  as a "torn"/competing texture from a distance.
- ✓ **Confirmed empirically (not assumed) that Mago's own `--minLod`/`--maxLod`
  flags don't help.** Tested `--minLod 1` directly against the small_file:
  it controls Mago's *own* internal tiling-refinement depth (the
  RC0→RC00→RC000→RC0000 chain), not which PLATEAU LOD gets converted —
  setting it dropped the small_file's output to **zero** tile contents
  rather than selecting LOD1. Ruled out as a fix path; the fix has to
  happen at the source-data level, before Mago ever sees the file.
- ✓ **Built and verified `tools/strip_higher_lod.py`** — parses a CityGML
  file with `xml.etree.ElementTree`, removes any `lod{N}`-prefixed element
  (N ≠ 1) that is a *direct child* of `bldg:Building`/`bldg:BuildingPart`,
  writes to a separate output path (never touches `data/source/`). Wired
  into `scripts/build.sh` unconditionally for both profiles (no bypass
  flag — CLAUDE.md's LOD1-baseline scope has no legitimate exception for
  Phase 1–6 builds), replacing the small-profile-only staging step with
  one that always stages through the stripper first.
- ✓ **Verified the fix works, quantitatively, on the exact building that
  motivated it.** Ran Mago on `63437175_bldg_6697_op.gml` with and
  without stripping: batched feature count dropped from 5,288 to 4,470 —
  a reduction of exactly 818, matching the 818 `lod0FootPrint` elements
  removed — and total output size fell only ~6.5% despite the file
  containing 7,292 `lod3MultiSurface` elements. That's strong evidence
  Mago's mesh generation is driven by the direct-child `Solid`/`MultiSurface`
  declarations only, not the `bldg:boundedBy`-nested boundary-surface
  breakdown (`lod3MultiSurface` lives inside `WallSurface`, not directly
  under `Building`) — so the script's narrower direct-children-only scope
  is empirically sufficient, not just a shortcut. Documented as an
  assumption to re-check if a future dataset or Mago version behaves
  differently, not asserted as universally true.
- ✓ **End-to-end confirmation on the small_file**: before stripping,
  Sarabetsu's small_file (LOD0+LOD1) produced 2 tile contents (Explicit)
  / `propertyTable.count: 2` (Implicit). After: exactly 1 tile content /
  `propertyTable.count: 1` — the LOD0 sibling branch is gone entirely,
  not just resized.
- ✓ **Rebuilt and re-published all 4 full-profile combinations.**
  Sarabetsu Explicit: 202→198 tile contents, 15,958,768→13,820,511 bytes
  (13.4% smaller). Sarabetsu Implicit: 804→760 tile contents,
  18,180,034→15,899,663 bytes (12.5% smaller). **Muroran (both modes):
  byte-identical output before and after** (same root `tileset.json`
  SHA-256 in both cases) — confirmed the stripper genuinely removed
  `lod0RoofEdge` from the staged files (checked directly), so this isn't
  a no-op bug; it means Mago already produced identical geometry for
  Muroran's `lod0RoofEdge` and `lod1Solid` for every building, consistent
  with Phase 5's earlier single-building finding that Muroran's LOD0/LOD1
  outputs were byte-identical. Muroran's already-published build needed
  no re-publish (nothing to change); Sarabetsu's two full-profile builds
  were re-published.

### Unexpected findings

- ? **Stripping LOD3 does *not* fix the Phase 4/6 non-determinism** — a
  useful negative result that refines rather than weakens that finding.
  Built two post-stripping Sarabetsu Implicit full-profile runs
  (`20260825T204728Z`, `20260825T205302Z`) and compared: still **L3/FAIL**,
  still 10 `geometry`-classified tiles, and **the same tile coordinates**
  as the original (pre-stripping) comparison (`R/3/3/2`, `R/4/6/6`,
  `R/5/13/12`, etc., plus one new one, `R/5/14/12`). Since the LOD3
  content that previously coexisted in this exact file is now gone and
  the non-determinism persists unchanged, the cause is conclusively *not*
  LOD-complexity-related — it's specifically about processing many
  buildings (826, in this file) as one batch, independent of what LOD
  those buildings are declared at. This sharpens Phase 6's "batching
  drives non-determinism" hypothesis: batch size/count is the driver, not
  geometry complexity within a batch.

### Next smallest experiment

Phase 4/6's open items (repeated concurrency trials for a firmer effect
size, checking whether the concurrency=4 tile set is stable run-to-run)
still stand — LOD stripping didn't change what's left to investigate
there, only ruled out one candidate explanation.

---

## Cross-phase follow-up: terrain/building vertical datum mismatch (2026-08-26)

**Status: Root-caused and fixed, verified against real (re)builds.** Answers the open question HANDOVER.md
flagged when Re:Earth Terrain was wired in ("Mago's building placement uses
ellipsoid height by default... a building's base may not sit flush with the
terrain surface"). The real answer is more severe than "may not sit flush":
buildings are placed **systematically 28–34 m below** the real terrain
surface, in both municipalities, and the exact offset matches each
location's EGM2008 geoid undulation almost exactly.

### Confirmed

- ✓ **`bldg:lod1Solid`'s absolute Z coordinates are real, location-varying
  elevations, not a flat placeholder.** Decoded 20 buildings' `lod1Solid`
  `gml:posList` values directly from source CityGML (not from `lod0RoofEdge`,
  which uses a literal `0` Z placeholder for its 2D outline and produced a
  false "every building's base Z is 0" reading on a first, sloppier pass —
  corrected before drawing any conclusion). Muroran's base elevations range
  from ~1.3 m (coastal) to ~82 m (hillside, port-city terrain); Sarabetsu's
  range ~222–316 m (inland plateau farmland) — both geographically
  plausible, confirming these are real absolute heights, declared under
  each dataset's `EPSG:6697` (JGD2011, geographic 3D — ellipsoidal height by
  CRS definition).
- ✓ **Sampled the live viewer's actual Re:Earth Terrain provider** (the
  exact `CesiumTerrainProvider` instance `viewer/viewer.js` constructs, via
  `Cesium.sampleTerrain(viewer.terrainProvider, 12, cartographics)` run
  against the deployed `https://dwg7.github.io/plateau-mago-implicit/` page
  in a real browser tab — `sampleTerrainMostDetailed` returned `null` at
  several points, root-caused to real coverage gaps in Mapterhorn's global
  DEM at max zoom, not a bug; fixed by requesting a fixed level (12) instead)
  at 17 of those 20 building coordinates (3 still returned no data even at
  level 12/10/8/6/4 and were dropped).
- ✓ **The source height vs. sampled terrain height difference is a tight,
  per-municipality constant, not noise:** Muroran (n=12): mean **−33.37 m**,
  population stdev 0.75 m, range −32.34 to −34.75 m — this despite the 12
  points spanning coastal (~1.3 m source elevation) to hillside (~82 m)
  terrain, exactly the "slope and coastal conditions" `docs/test-plan.md`
  flagged for Phase 5. Sarabetsu (n=5): mean **−27.78 m**, population stdev
  0.66 m, range −26.85 to −28.72 m. A sub-1m-stdev cluster across such
  different elevations/slopes rules out ordinary DEM-resolution noise as
  the explanation — that would scatter much more on Muroran's slopes.
- ✓ **Independently cross-checked against `GeographicLib`'s EGM2008 geoid
  calculator** (`geographiclib.sourceforge.io/cgi-bin/GeoidEval`, a
  standard reference tool, not this project's own code): EGM2008 geoid
  undulation (N) at 42.32°N/140.98°E (central Muroran) is **32.83 m**; at
  42.58°N/143.11°E (central Sarabetsu) is **27.91 m**. Both match the
  measured offsets above to within 0.5 m (Muroran) and 0.13 m (Sarabetsu) —
  well inside the ~0.7 m per-municipality stdev already observed from real
  DEM/geoid-model discretization. This is a quantitative match, not a
  qualitative "seems plausible" — the two independent numbers (measured
  offset vs. published EGM2008 N) agree to a fraction of a percent at both
  sites.

### Root cause (strong evidence, not yet upstream-confirmed)

PLATEAU's `bldg:lod1Solid` height values, though declared under `EPSG:6697`
(nominally ellipsoidal height by CRS definition), are in practice populated
with **orthometric heights** — elevation above the geoid, i.e. Japan's
standard 標高/T.P.-referenced elevation, most likely derived from GSI's DEM
during PLATEAU production. `scripts/build.sh`'s
`--proj "+proj=longlat +datum=WGS84 +axis=neu +no_defs"` only fixes
axis *order* for the horizontal components; it passes the Z value straight
through unchanged, so Mago places buildings at that raw orthometric value
and 3D Tiles/CesiumJS then interpret it as WGS84 **ellipsoidal** height (by
construction — `Cartesian3.fromDegrees`/`CARTOGRAPHIC_DEGREES` height is
always ellipsoidal). Re:Earth Terrain's DEM, per its own documentation and
`viewer/viewer.js`'s comment on it, *does* apply the EGM2008 geoid
correction to render a true ellipsoidal ground surface. The gap between
"building Z taken as ellipsoidal but is actually orthometric" and "terrain
correctly rendered as ellipsoidal" is exactly the local geoid undulation —
which is what was measured.

### Unexpected findings

- ? **The severity was worse than the open question anticipated when first
  raised.** HANDOVER.md originally framed this as "may not sit flush" (a
  cosmetic edge case). The real measured effect — buildings placed 28–34 m
  *below* the real terrain surface, uniformly across both municipalities
  and regardless of slope — meant every building in the published
  full-profile builds rendered as fully buried once real terrain became
  the ground surface, not merely misaligned at the base. Confirmed by the
  user directly, independently of this investigation: after seeing the
  live site with real terrain, they reported "all buildings except a few
  of Muroran's high-rises appear sunk into the ground" — matching the
  measured 28–34 m offset almost exactly (a high-rise tall enough to
  poke back above a ~33 m sinking would look mostly normal from a distance;
  everything shorter would visibly disappear into the terrain).
- ✓ (resolved) **This is a documented, known PLATEAU convention, not
  specific to these two datasets.** PLATEAU's own technical documentation
  (https://www.mlit.go.jp/plateau/learning/tpc03-4/, "CityGMLの座標・高さと
  データ変換") states building heights are referenced to Tokyo Bay mean sea
  level, not the ellipsoid. PLATEAU's officially-recommended FME conversion
  workflow includes a "Vertical Transformation with GSIGEO2011" step for
  exactly this reason — every PLATEAU CityGML consumer that wants correct
  absolute placement is expected to apply this conversion themselves; it
  is not something Mago 3DTiler (or any other converter) does automatically
  (confirmed directly in Mago's own build log output: `Geoid Model(Height
  Reference): Ellipsoid` — it takes input height as already ellipsoidal,
  with no correction option).
- ✓ (resolved) **Swapping to PLATEAU's own official terrain service does
  NOT fix this on its own** — tested directly (see Confirmed, next
  section) — because the terrain side was never the problem; the source
  building height data is the side that needs correcting, and no terrain
  provider can compensate for that from the outside.

### Confirmed (fix)

- ✓ **Tried the "Eukarya-aligned" terrain-only fix first, and it didn't
  work — which is itself informative.** At the user's request ("Eukarya
  さんの方で何かやってなかったっけ？"), found and tested **PLATEAU-Terrain**
  (`https://tile.plateauview.mlit.go.jp/terrain`), operated by Eukarya as
  part of the official PLATEAU VIEW infrastructure, whose own
  documentation states it converts GSI's DEM via GSIGEO2011 "to ensure
  vertical alignment with PLATEAU's 3D building datasets." Re-ran the same
  17-point `Cesium.sampleTerrain` check against this provider instead of
  Re:Earth Terrain: **the offset was unchanged** (Muroran ~−33m, Sarabetsu
  ~−27m, same as before). This confirms the terrain side was always
  correct — the mismatch is entirely in how this project's own pipeline
  handles the *source* building height, not in which terrain service is
  used.
- ✓ **Found the actual fix PLATEAU's own tooling uses**: PLATEAU's
  officially-recommended FME workflow applies a "Vertical Transformation
  with GSIGEO2011" step, and a small MIT-licensed library exists that
  embeds the same model: `japan-geoid` (https://github.com/ciscorn/japan-geoid,
  Rust with Python/JS bindings). Verified `geoid.get_height(lon, lat)`
  against both municipalities' central coordinates: Muroran 32.99m,
  Sarabetsu 28.08m — matching the measured offsets (33.37m / 27.78m) to
  within the sampling noise already established, and even closer than the
  EGM2008 cross-check above (as expected: GSIGEO2011 is Japan's own,
  more locally accurate model, and the one PLATEAU's own tooling uses).
- ✓ **Approved by the user** (via explicit confirmation, offered
  alongside a no-new-dependency viewer-side alternative and a "do nothing
  yet" option) to add `japan-geoid` as this project's first third-party
  Python dependency — recorded in the new `requirements.txt` and
  `DECISIONS.md` D21, checked (not silently auto-installed) by
  `scripts/bootstrap.sh`.
- ✓ **Built `tools/geoid_correct.py`**, a second build-time staging step
  (same shape as `tools/strip_higher_lod.py`, wired into `scripts/build.sh`
  immediately after it, unconditional for both profiles) that adds
  GSIGEO2011 geoid undulation to every `gml:posList`/`gml:pos` height
  found inside a `bldg:Building`/`bldg:BuildingPart` element — i.e.
  orthometric → ellipsoidal, matching PLATEAU's own recommended
  conversion. Benchmarked the geoid lookup at ~0.1μs/call (50,000 calls in
  4.8ms), so no numpy/batching was needed even for source files with
  30,000+ coordinate values.
- ✓ **Verified end-to-end on the small_file before touching real
  published data.** Ran `scripts/build.sh muroran implicit small` with the
  new staging step: Mago's own log confirmed it still treats input height
  as `Ellipsoid` (unchanged Mago behavior — the fix has to happen before
  Mago, which it now does), and the output tileset's root bounding region
  height became `34.79–39.01m` — exactly the geoid-corrected source value,
  and squarely inside the real terrain range (~34–37m) measured near that
  coastal location earlier in this investigation. Confirms Mago passes the
  corrected Z through losslessly.
- ✓ **Rebuilt all 4 full-profile combinations** (`sarabetsu`/`muroran` ×
  `explicit`/`implicit`). Tile content counts are **unchanged** from the
  pre-fix (post-LOD1-stripping) builds — 198/760/1259/553 — confirming the
  fix only shifts vertical placement, not tiling structure or feature
  count. `make validate` on all 4 shows only the already-documented,
  unrelated `METADATA_INVALID_LENGTH` alignment-padding pattern (same
  `CONTENT_VALIDATION_ERROR`/`METADATA_INVALID_LENGTH` shape as every
  prior build) — no new error type introduced by this change.

### Next smallest experiment

The 4 rebuilt full-profile combinations need to be re-published (not yet
done — a real, public-facing action, held for explicit confirmation) and
then visually reconfirmed by the user in the live viewer — this fix was
verified through coordinate math, an independent geoid calculator, a
second official terrain service, and one small-profile build round-trip,
not through a screenshot, for the same `document.visibilityState:
"hidden"` reason as every other viewer check this project has done.
A full-profile GLB spot-check (decoding an actual built building's Z from
the 4 rebuilt tilesets, the way the small-profile check was done) was not
repeated — the small-profile round-trip already established Mago
preserves corrected height losslessly, and tile-count parity across all 4
rebuilds shows no structural regression — but would be the next thing to
do if any doubt remains after visual reconfirmation.

---

## Cross-phase follow-up: does Implicit actually show a benefit over Explicit? (2026-08-27)

Prompted by the user asking directly, after the geoid and imagery fixes made
the live viewer usable enough to actually compare. Structural differences
were already established in Phase 2 (small_file only — see that section for
the full tree-shape comparison: geometry-fitted bounding volumes and
explicit per-level `geometricError` for Explicit vs. uniform quadtree-grid
volumes and client-computed per-level error for Implicit). This section
adds the full-profile, real-scale numbers that answer "does it help,"
using the current (post-geoid-fix, post-LOD1-enforcement) builds already
on disk — no new build was run for this.

### Confirmed

- ✓ **Implicit's designed advantage — a tiny, constant-size initial
  payload — is real and large.** `tileset.json` size: Sarabetsu Explicit
  44,766 bytes vs. Implicit 427 bytes (105x smaller); Muroran Explicit
  286,635 bytes vs. Implicit 432 bytes (663x smaller). Explicit's
  `tileset.json` must enumerate the *entire* tree explicitly, so it grows
  with tile count (6.4x more tiles → 6.4x larger file, roughly, comparing
  the two municipalities); Implicit's stays ~430 bytes regardless of
  scale, since availability lives in separate subtree files fetched
  lazily. This is the one place the numbers unambiguously favor Implicit,
  and the gap should widen further for any larger municipality.
- ✓ **Total file count and total data size do NOT consistently favor
  either mode — direction depends on the dataset's building density, not
  on which mode is "better."** Exact numbers (content `.glb` files / total
  files incl. subtrees+tileset.json / total bytes):
  - Sarabetsu (6,795 buildings): Explicit 198 / 199 / 13.78MB — Implicit
    760 / 1,017 / 15.84MB. Implicit needs **5.1x more files** here.
  - Muroran (55,906 buildings): Explicit 1,259 / 1,260 / 75.92MB —
    Implicit 553 / 818 / 73.34MB. Implicit needs **35% fewer files**
    here — the opposite direction from Sarabetsu.
  - Subtree files themselves are negligible in size either way (128 pairs
    / 55,596 bytes for Sarabetsu, 132 pairs / 57,307 bytes for Muroran) —
    the file-count difference is a request-count concern, not a bytes
    concern.
- ✓ **The direction-flip traces to buildings-per-content-tile, which
  moves in opposite directions between the two modes depending on the
  dataset:** Sarabetsu goes from 34.3 buildings/tile (Explicit) down to
  8.9 (Implicit) — Implicit's uniform quadtree subdivides Sarabetsu's
  sparse, spread-out buildings *more finely* than Mago's adaptive
  Explicit batching does. Muroran goes the opposite way: 44.4
  (Explicit) up to 101.1 (Implicit) — Implicit's quadtree cells end up
  *coarser* (more buildings each) than Explicit's batching for Muroran's
  denser distribution. Same converter, same two modes, opposite effect —
  a real, dataset-dependent structural interaction, not noise (though see
  Not confirmed below for a caveat on run-to-run stability of the exact
  counts).
- ✓ **A real, previously-found Implicit downside carries over here, not
  freshly discovered:** Implicit's root bounding region is padded to the
  quadtree grid boundary rather than tightly fit to actual building
  content — confirmed earlier by comparing the two regions directly
  (Implicit's edge sits 3-6km further out than Explicit's, for both
  datasets), which is why `viewer/viewer.js`'s predefined viewpoints use
  Explicit's region for centering even for the Implicit dataset entries.
  This is a real, measured cost of the uniform-grid approach, not
  theoretical.

### Not confirmed

- ✗ **The practical-consumption question that would actually settle
  "does it help in real use" — first-useful-render time and total
  network requests during realistic pan/zoom — remains unmeasured, after
  a real attempt.** `docs/test-plan.md` calls for exactly this;
  `HANDOVER.md`'s "Next concrete step" carried it as an open item across
  multiple sessions. Everything else in this section is static file/byte
  counts, not observed browser behavior. Implicit's lazy per-subtree
  fetching *could* mean more total round-trips during an exploration
  session even where its initial payload is smaller — genuinely unknown
  without measuring it.

  **(2026-08-27) Actually tried, real progress made, ultimately
  abandoned as unreliable — worth recording since it's the first session
  to get partway past this project's long-standing
  `document.visibilityState: "hidden"` blocker.** Found that calling
  `viewer.camera.setView(...)` (not `flyTo`, which itself depends on the
  paused render loop to animate) followed by manually pumping
  `viewer.scene.render()` in a tight synchronous loop *sometimes*
  drives a real `Cesium3DTileset` traversal forward even in a
  backgrounded/hidden tab — reached a genuine useful-render state twice
  (`selected: 4`, 165 features, 25,599 triangles, real GLB content
  fetched from `tunnel.optgeo.org` and decoded) for
  `sarabetsu_explicit_full`. Ruled out several other candidate
  explanations first: `document.visibilityState` spoofing via
  `Object.defineProperty` had no effect (confirms real browser-engine
  throttling, not a self-imposed JS-level check Cesium could be tricked
  out of); `viewer.cesiumWidget.render()` and `scene.forceRender()`
  behaved identically to plain `scene.render()`; the actual blocker in
  earlier attempts turned out to be `flyTo`'s animation never
  completing (camera stuck at the default startup view), not the
  render-pump technique itself. **But repeating the *exact* same
  minimal sequence on a fresh tab immediately afterward failed
  (`visited: 0` after hundreds of render calls)** — the effect is
  real but non-deterministic, most likely a genuine race against
  Chrome's own background-tab scheduling jitter, not something
  controllable from the page's JS. Not reliable enough to produce
  trustworthy timed measurements across 4 combinations. **Decision
  (user, 2026-08-27): leave this metric unmeasured for now** rather
  than report numbers from an unreliable method — static comparisons
  above stand as the current evidence. If a future session revisits
  this, the render-pump + `setView` technique is a real, partially-
  working lead worth trying again (ideally from a genuinely visible
  browser — Claude in Chrome or the user's own — rather than fighting
  this tool's headless throttling further).
- ? The exact content-tile counts above come from one build per
  dataset/mode, not repeated runs. Phase 4/6 already established that
  full-profile batching is non-deterministic (L3/FAIL) for both modes —
  so the *exact* counts (198, 760, 1259, 553) could shift somewhat on a
  rebuild. The qualitative pattern (which mode wins on file count flips
  between the two datasets) is judged likely to hold, since it tracks a
  real, large density difference between the municipalities, but this
  hasn't been re-verified across multiple builds the way Phase 3/5's
  determinism claims were.

### Update (2026-08-28): the practical-consumption gap is now closed, with real numbers

After the render-pump workaround proved unreliable, the user ran the
measurement directly in their own browser (Brave, real/foreground —
Brave being Chromium-based meant no browser-specific script changes were
needed). A single real trial per combination, pasting a
provided instrumentation snippet into DevTools and reporting the console
output back verbatim:

| Dataset | mode | first content (ms) | useful view (ms) | requests |
|---|---|---|---|---|
| Sarabetsu | Explicit | 401 | 1662 | 119 |
| Sarabetsu | Implicit | 401 | 1453 | 52 |
| Muroran | Explicit | 303 | 1602 | 159 |
| Muroran | Implicit | 501 | 1200 | 56 |

**Confirmed**

- ✓ **Implicit needs dramatically fewer network requests to reach a
  useful view in real, realistic use** — 56% fewer for Sarabetsu (119→52),
  65% fewer for Muroran (159→56). This is a different, more directly
  meaningful metric than the earlier static "total files in the dataset"
  comparison above (which favored Explicit for Sarabetsu) — that counted
  every file that *could* be fetched across the whole tileset; this
  counts what's *actually* fetched to render one real view. The two
  don't have to agree, and here they don't: Sarabetsu Implicit has more
  total files (1017 vs 199) but needs *fewer* requests for a real view.
  The likely mechanism, consistent with Phase 2's tree-shape finding:
  Explicit's sibling-LOD-branches-with-`refine:ADD` structure loads
  content at *every* level along a path simultaneously, not just the
  leaf, while Implicit's sparser `contentAvailability` means fewer
  distinct positions actually carry content to fetch.
- ✓ **Implicit reaches a useful view faster in both cases** — 13% faster
  for Sarabetsu (1662ms→1453ms), 25% faster for Muroran (1602ms→1200ms).
  Directionally consistent with the request-count difference (fewer
  round-trips, less to parse before the view is usable).
- ? `firstContentTime` (first *any* content ready, not yet a useful
  view) doesn't show the same clean pattern — identical for Sarabetsu
  (401ms both) and *slower* for Muroran Implicit (501ms vs 303ms). The
  advantage shows up specifically between "first content" and "useful
  view," not before it — consistent with Implicit needing more content
  tiles loaded before the view stabilizes into something worth calling
  useful, even though the total request count for the whole session
  ends up lower.

**Not confirmed / caveats**

- ✗ **Byte totals could not be measured** — the instrumentation summed
  `PerformanceResourceTiming.transferSize`, but the browser zeroes that
  field for cross-origin resources whose server doesn't send a
  `Timing-Allow-Origin` header (a deliberate privacy restriction,
  correctly enforced by the browser — neither `tunnel.optgeo.org` nor
  `stars.optgeo.org` currently sends that header). All 4 results came
  back `totalKB: 0`, an instrumentation limitation now known for next
  time, not a real "zero bytes transferred" finding.
- ✗ **n=1 per combination, no repeated trials.** This is real,
  human-observed data from an actual foreground browser — a
  qualitatively stronger form of evidence than anything measurable
  through this session's own automated tooling — but a single run each,
  not an average with variance. The *direction* (Implicit: fewer
  requests, faster useful view) is consistent across both municipalities,
  which is reassuring, but the exact percentages could shift on a
  re-run.
- ✗ Still only covers "load once and fly to the predefined viewpoint,"
  not the fuller "pan across a populated area, zoom to street level"
  session `docs/test-plan.md` originally asked for, nor memory/navigation-
  responsiveness/long-session trends.

### Next smallest experiment

If firmer numbers are wanted: repeat the same measurement 2-3 more times
per combination (same low-friction paste-a-script-into-Brave method) to
get a variance estimate, and/or extend the script to `Timing-Allow-Origin`-
independent size measurement (e.g. summing `Content-Length` response
headers via `fetch()` HEAD requests instead of the Resource Timing API,
which isn't subject to the same cross-origin restriction) to finally get
real byte totals. Otherwise, the core practical-consumption question this
project set out to answer — does Implicit help in real use — now has a
real, if single-trial, answer: yes, on both request count and
useful-view time, for both municipalities.

---

## Cross-phase follow-up: additional determinism sampling — is the concurrency=4 tile set stable? (2026-08-27)

Answers Phase 6's own "Next smallest experiment" (repeated concurrency
trials for a firmer effect size; is the concurrency=4 tile set stable
run-to-run the way concurrency=1's is). Built 2 more `CONCURRENCY=4`
pairs and 1 more `CONCURRENCY=1` pair for Muroran Implicit full profile
(6 new builds total: `20260827T132457Z`, `20260827T132741Z`,
`20260827T133030Z`, `20260827T133304Z` at concurrency=4;
`20260827T133725Z`, `20260827T134001Z` at concurrency=1).

### A methodological trap, caught before it produced a false finding

The very first cross-pair comparison run — new concurrency=4 build
`20260827T132457Z` against the *original* Phase 6 concurrency=4 build
`20260825T141104Z` — showed **553/553 tiles differing in geometry**,
i.e. every single tile. Read naively, this would have looked like a
dramatic new non-determinism finding. It isn't one: `20260825T141104Z`
was built *before* this session's `tools/geoid_correct.py` fix (see
"Cross-phase follow-up: terrain/building vertical datum mismatch"
above) was wired into `scripts/build.sh`, and every one of today's
builds includes it. Geoid correction deterministically shifts every
building's Z coordinate by the local geoid undulation (~33m for
Muroran) — comparing across that boundary compares two *intentionally*
different, both-correct outputs, not a determinism failure. **Lesson
for any future determinism comparison: only compare builds made with
the same pipeline version** (in practice, same git commit / same day
this session, until build manifests record a pipeline-version hash
explicitly — they currently record `git_commit`, so this is
checkable, just wasn't checked before running the comparison here).
All comparisons below are same-day (2026-08-27), same-pipeline,
apples-to-apples.

### Confirmed

- ✓ **Concurrency=1's 5-tile baseline is now confirmed across 3
  independent pairs, including one spanning a real pipeline change.**
  The new pair (`20260827T133725Z` vs `20260827T134001Z`) shows exactly
  **5** geometry-diff tiles, and they are the *exact same 5* found in
  both original Aug 25 pairs: `R/2/2/0`, `R/2/2/1`, `R/3/4/1`, `R/3/5/2`,
  `R/4/7/2`. Zero variation across 3 pairs, one of which used
  geoid-corrected coordinates the other two didn't — about as strong as
  a reproducibility result gets without exhaustive trials.
- ✓ **Concurrency=4 has a stable core, but it's not perfectly rock-solid
  like concurrency=1 — a real, previously-unmeasured distinction.**
  Comparing all 3 same-day concurrency=4 pairings (`T2457` vs `T2741`;
  `T3030` vs `T3304`; and cross-pair `T2457` vs `T3030`) as a 3-way
  intersection: **19 tiles appear as geometry-different in all three
  comparisons** — a hard, reproducible core, and it fully contains the
  concurrency=1 5-tile set (consistent with Phase 6's original "adds on
  top of the baseline" framing). But there's also a soft edge: **7
  additional tiles appear only in the `T3030` vs `T3304` comparison**
  (`R/3/1/4`, `R/3/2/1`, `R/4/13/6`, `R/4/14/6`, `R/4/3/9`, `R/5/26/12`,
  `R/5/28/12`), and since none of them show up in `T2457` vs `T3030`
  either, the extra instability traces specifically to build `T3304`
  itself, not to the pairing. Individual per-pair totals were 23, 28,
  and 23 tiles — in the same ballpark as Phase 6's original single-pair
  observation of 25, but now known to have a reproducible ~19-tile core
  plus some build-specific variability at the edges, not a flat "25
  every time."

### Not confirmed

- ✗ Still not a large-n study — 3 pairs at concurrency=4, 3 at
  concurrency=1 (2 original + 1 new each), not the "5+ pairs" originally
  floated as a target. The 7-tile "extra instability in one build"
  observation is based on a single occurrence; whether that's typical
  variance or unusual would need more pairs to say confidently.

### Next smallest experiment

The remaining open question from here: is the 7-tile "extra" pattern
something that shows up in roughly 1-in-3 concurrency=4 builds, or was
`T3304` unusual? A few more concurrency=4 pairs (comparing each new
build against the existing 19-tile core, not just internally) would
answer this without needing a full new large-n study from scratch.

---

## Cross-phase follow-up: the 19-tile core survives a real pipeline change (2026-08-28)

Attempting to push the concurrency=4 sample toward n=5 hit the *exact*
same class of trap as the geoid-fix boundary lesson above, caught before
it produced a false result: the two new builds
(`20260827T190046Z`, `20260827T190435Z`) were built *after*
`git 214b1c7` (this session's roadmap §1 work, which wired
`config/common.yml`'s `tiling.subtree_levels` into Mago's
`--implicitSubtreeLevels` flag) — a different `git_commit` from the
existing n=3 concurrency=4 sample (`git 8bfae0b` and earlier), and a
real structural change: `subtreeLevels` went from Mago's default 4 to
the configured 3, changing subtree file layout (818 → 636 total output
files for the same dataset/mode/profile). Checked `git_commit` in both
manifests *before* comparing this time, per the lesson from two days
ago — the new pair is only compared against each other, not naively
against the older, differently-configured sample.

### Confirmed

- ✓ **The new pair still fails determinism (L3/FAIL)**, as expected.
- ✓ **The previous 19-tile "hard core" reproduces 100% under the new
  subtreeLevels=3 configuration** — all 19 tiles from the earlier
  3-pair intersection appear again, exactly, in this new pair's 25
  geometry-diff tiles. Strong evidence the non-determinism lives
  entirely in Mago's content-tile generation (batching/triangulation),
  genuinely independent of how the implicit quadtree gets grouped into
  subtree files — a real config change didn't move the core at all,
  the same way the concurrency=1 baseline survived the geoid-fix
  boundary.
- ✓ **A second, independent "extra instability beyond the core"
  observation, similar in size to the first.** This new pair's 25 tiles
  include 6 beyond the 19-tile core (`R/5/9/7`, `R/3/7/3`, `R/3/3/1`,
  `R/4/14/6`, `R/4/13/6`, `R/4/3/9`) — not the same 6 tiles as the
  earlier 7-tile anomaly traced to build `T3304`, but a similar
  magnitude (6 vs 7). Two independent occurrences of "core plus ~6-7
  extra" is a real hint that this edge instability is a recurring
  feature of concurrency=4 builds in general, not a one-off fluke from
  one unusual build — though n=2 still isn't enough to call this
  confidently.

### Not confirmed (at the time of writing — superseded below)

- ✗ n=2 for the new-pipeline sample (this pair) is not enough on its
  own to firm up the "how often does the extra-instability edge appear"
  question either — it corroborates the earlier n=1 (`T3304`) rather
  than replacing the need for more trials.

### Update: extended to n=4 pairs under the new pipeline (same session)

Built 2 more concurrency=4 pairs (`20260827T191514Z`/`T191834Z`,
`20260827T192221Z`/`T192718Z`), all confirmed same-pipeline (`git
a6d382f` vs the first pair's `git 214b1c7` — different hashes, but
diffing `scripts/`, `tools/`, `config/`, `Dockerfile` between the two
commits is empty: the only difference was a docs/manifests-only commit
in between, so all 4 pairs are legitimately comparable despite the
differing `git_commit`. Worth noting as a refinement of the "check
`git_commit` matches" heuristic: what actually matters is whether the
*build-relevant* files changed, not the literal commit hash — matching
hashes is a sufficient but not necessary condition, checkable directly
with `git diff <a> <b> -- scripts/ tools/ config/ Dockerfile`).

Computed the intersection across all 4 comparisons (2 internal pairs +
1 cross-pair `T1514` vs `T2221`, mirroring the earlier 3-comparison
methodology): individual per-comparison totals 25/28/24/25 geometry-diff
tiles; **4-way intersection is 19 tiles again** — same *size* as the
earlier 3-pair core, but **not the identical set**: 16 tiles are shared
between the old (subtreeLevels=4) and new (subtreeLevels=3) 19-tile
cores, with 3 tiles unique to each (`R/4/11/5`, `R/4/12/5`, `R/4/13/5`
only in the old core; `R/3/7/3`, `R/4/13/6`, `R/4/14/6` only in the new
one). Union across all 4 new-pipeline comparisons: 32 tiles, with only
2 tiles appearing in just one single comparison each (not a repeated
"one build is unusually noisy" pattern like `T3304` before).

**This refines, rather than contradicts, the "stable core" framing
above — a more honest characterization: there is no perfectly fixed
identity-level core the way concurrency=1's exact-same-5-tiles is.**
Instead there's a broader pool of tiles (union ~32 and likely growing
slowly with more trials) each individually unstable with high but
not-quite-100% probability across trials; which ~19 of them happen to
appear in *every* comparison in a given small sample depends partly on
which specific trials were run, not a fixed guaranteed set. Concurrency=4's
non-determinism is real, large, and reproducibly *sized* (~19-32 tiles
out of 553), but not reproducibly *identical* the way concurrency=1's
is — a genuine, qualitative difference between the two settings, now
resting on real multi-sample evidence rather than a single pair's
observation.

### Next smallest experiment

The remaining natural extension — same-size trials for **Sarabetsu**
(only Muroran has been sampled this deeply at concurrency=4) — would
show whether "core-with-fuzzy-edges rather than fixed-identity" is a
Muroran-specific texture or a general property of concurrency=4's
non-determinism, mirroring how Phase 6 originally generalized Phase 4's
Sarabetsu-only finding.

---

## Cross-phase follow-up: small fixes — validator pin, subtree_levels wiring, tooling dedup (2026-08-28)

Three small, no-scope-risk items from the project's own tracked
follow-ups, done as the first step of a broader remaining-work roadmap.

### Confirmed

- ✓ **`validators.tiles_validator_version` is now actually enforced.**
  `scripts/validate.sh` previously read it from `config/common.yml` but
  never passed it to `npx`, which resolved whatever was current at run
  time. Now runs `npx --yes 3d-tiles-validator@<pinned-version>`.
  Confirmed the resolved version (0.6.1) already matched the pin before
  this change (`npm view 3d-tiles-validator version`), so this protects
  against *future* drift rather than changing anything retroactively —
  re-ran validation on an existing build and got the identical known
  687-error result.
- ✓ **`config/common.yml`'s `tiling.subtree_levels: 3` is now wired into
  Mago's invocation.** Confirmed the real flag name empirically first
  (`docker run <mago-image> --help`) rather than trusting this file's own
  earlier "Next smallest experiment" note blindly: `-isl,
  --implicitSubtreeLevels <arg>`, marked "[Experimental]" by Mago itself.
  Wired in for implicit-mode builds only (the concept doesn't apply to
  Explicit). Verified end-to-end on a fresh Sarabetsu Implicit
  small-profile build: `tileset.json` now declares `subtreeLevels: 3`
  (was 4), correctly producing 2 subtree files instead of 1 (root
  subtree covers levels 0-2, a child subtree covers level 3), and
  `make validate` decodes both without error. **Not applied
  retroactively** — the 4 live published full-profile builds still use
  Mago's default of 4 and were not rebuilt for this.
- ✓ **De-duplicated subtree-parsing logic between `tools/inspect_subtree.py`
  and `tools/normalize.py`** into a new shared `tools/subtree_common.py`
  (bit-counting, `find_subtree_levels()`, `is_subtree_json()`,
  binary/JSON+bin container parsing, availability counting — the exact
  logic that needed the same two bugs fixed independently in both files
  during Phase 2). Verified as a genuinely behavior-preserving refactor,
  not just "looks equivalent": ran both tools on 4 real builds (Sarabetsu
  full + small, Muroran full, one with the new non-default
  `subtreeLevels: 3`) before and after the refactor and diffed the
  JSON output — byte-identical except the `generated_at` timestamp, in
  every case. `make validate` and the full `make test` suite both
  re-confirmed passing after.
- ? **Real gotcha caught by `make test`, not by the manual verification
  above:** a bare `import subtree_common` only resolves when the
  importing script's own directory is on `sys.path` — true for direct
  `python3 tools/inspect_subtree.py` execution (Python adds the script's
  own directory automatically), but false for how
  `tests/run-tests.sh` imports these tools (`import tools.inspect_subtree`
  with only the repo root on `sys.path`, so `tools/` itself is never
  added). Fixed by explicitly inserting the script's own directory into
  `sys.path` before the import, in both files. A reminder that "ran it
  directly and it worked" isn't sufficient verification for a refactor
  touching how a script is imported — `make test` catching this the way
  it did is exactly what it's for.

---

## Phase 7: Optional higher-detail tests

**Status: LOD3 sub-goal (Sarabetsu) run for real, 2026-08-28. Texture
sub-goal (Sapporo, see "Phase 7b" below) also run for real, 2026-08-28,
after the user explicitly asked for it as a separately-staged follow-up.
Explicitly optional and separate — per `docs/test-plan.md`, failure here
does not invalidate Phase 1-6, and per `CLAUDE.md`'s scope boundary, this
section's results are never merged into the Phase 1-6 summary table
below.**

Run at the user's explicit request and sign-off (`CLAUDE.md`: "Phase 7
is the only place higher detail is allowed... requires the user's
explicit sign-off" — asked and approved before any code change, see
chat history 2026-08-28).

### What's actually testable — checked before running anything

- **Higher LOD (LOD3): real, testable.** Neither dataset has LOD2
  (`tools/strip_higher_lod.py`'s own docstring: "no lod2 elements were
  found in either dataset"). Sarabetsu's `63437175_bldg_6697_op.gml` (the
  826-building file already central to Phase 4 and the LOD1-enforcement
  finding) has 4 buildings with genuine LOD3 detail: 92, 2004, 2682, and
  2514 `lod3MultiSurface` elements respectively (`bldg_3ac5d900...`,
  `bldg_88f31791...`, `bldg_ad16daa0...`, `bldg_e9a284d3...`).
- **Textures: not evaluable with current project data, not attempted (as
  of this LOD3 sub-goal run).** Re-confirmed zero
  `app:ParameterizedTexture`/`app:Appearance` elements in both full
  datasets and in the committed CI fixture
  (`data/fixtures/test_building.gml`). Testing texture support for real
  would need a third data source, itself a separate scope question
  (`CLAUDE.md`: "two municipalities only... do not add a third without
  the user asking") — not decided as part of this task. **Update
  2026-08-28: the user explicitly asked for this, staged separately from
  a possible full third-municipality integration — see "Phase 7b: texture
  sub-goal" below.**

### Method

Not run through `make build` — this is a deliberately small, isolated
test, not a Phase-1-6-style full pipeline run. `scripts/build.sh` gained
an opt-in `PHASE7=1` env var (defaults off, prints a loud warning when
set) that skips `tools/strip_higher_lod.py` entirely, letting higher-LOD
geometry reach Mago unmodified; **verified this doesn't touch Phase 1-6
behavior** by rebuilding `sarabetsu/implicit/small` with `PHASE7` unset
and confirming the root `tileset.json` SHA-256 is byte-identical to the
pre-change build.

For the actual Phase 7 test: extracted just the 4 LOD3-bearing buildings
from `63437175_bldg_6697_op.gml` into a standalone 8.9MB CityGML document
(kept out of the repo — see "Not confirmed" below for why), ran it
through `tools/geoid_correct.py` (a real, always-needed correction,
unrelated to LOD scope — see the vertical-datum-mismatch finding above)
but *not* `tools/strip_higher_lod.py`, then invoked Mago directly for
both modes with the same flags `scripts/build.sh` itself uses:

```
docker run --rm -v <input>:/data/input -v <output>:/data/output \
  plateau-mago-implicit-tiler:1.16.2 \
  --input /data/input --output /data/output --inputType citygml \
  --proj "+proj=longlat +datum=WGS84 +axis=neu +no_defs" \
  --multiThreadCount 1
# (Implicit mode additionally: --tilingMode implicit --implicitSubtreeLevels 3)
```

### Confirmed

- ✓ **Mago 3DTiler converts real LOD3 geometry without crashing, in both
  modes.** Explicit: 147 tile contents, 9.4s. Implicit: 57 tile contents,
  10.3s. Both completed cleanly — no exceptions, no silent truncation
  (147/57 tile contents from just 4 buildings is far more geometric
  complexity than a LOD1-only file of this building count would ever
  produce, consistent with the real LOD3 detail actually being
  processed, not dropped).
- ✓ **Geographic placement is correct.** Root bounding region decodes to
  143.193-143.194°E / 42.645-42.647°N (both modes) — squarely inside
  Sarabetsu's known extent, and the geoid-corrected height range
  (214.9-226.1m) is plausible for that inland plateau area, consistent
  with other Sarabetsu elevation samples this project has taken.
- ✓ **No new validator error class.** `3d-tiles-validator@0.6.1` against
  both outputs shows only the already-documented, ambiguous-not-confirmed
  `METADATA_INVALID_LENGTH` alignment-padding pattern (see "The
  `METADATA_INVALID_LENGTH` validator finding" above) — nothing LOD3-
  specific or new.
- ✓ **The `PHASE7=1` bypass is genuinely inert by default.** Confirmed
  via SHA-256 comparison, not just "looks like it should be," per this
  project's own standard for claiming something works.

### Not confirmed

- ✗ **No structural tree comparison against Phase 2's methodology done
  yet** (Explicit's per-LOD sibling branch shape, Implicit's subtree
  availability decode) — this run only confirmed conversion succeeds and
  validates the same as every other build, not the detailed tree-shape
  analysis Phase 2 did for the LOD1-only case.
- ✗ **The 8.9MB extracted test file was not committed to the repo** —
  it doesn't fit `CLAUDE.md`'s "only the small synthetic fixture
  `data/fixtures/test_building.gml` is checked in" convention, and this
  was a one-off manual invocation (not wired into `make build`/`make
  test`), so it isn't reproducible by running a single command the way
  Phase 1-6 builds are. Reproducible by re-running the extraction
  described above against the same source file with the same 4
  `gml:id`s, which *is* committed (`data/source/` is fetched via `make
  fetch`, checksummed).
- ✗ **Texture support remains completely untested** — not a finding,
  a scope decision (see above).
- ✗ Determinism, full-profile behavior, and practical-consumption
  metrics were not evaluated for Phase 7 content — out of scope for
  what `docs/test-plan.md` actually asks ("test higher LOD and texture
  support if LOD1 baseline is stable"), and explicitly not proposed when
  this was approved.

### Next smallest experiment

If Phase 7 is revisited: the structural tree comparison Phase 2 did for
LOD1-only content, applied here — does Explicit now show 3 sibling
branches (LOD0/LOD1/LOD3) instead of 2, and does Implicit's merged
content tile's `propertyTable` grow accordingly? Would directly answer
whether Mago's Implicit merging behavior (already confirmed to combine
multiple LODs into one content tile for the LOD0+LOD1 case, Phase 2)
extends cleanly to a third LOD.

### Phase 7b: texture sub-goal (Sapporo City, 札幌市 — 2026-08-28)

**Status: Run for real. Explicitly optional and separate, same as the
LOD3 sub-goal above — never merged into the Phase 1-6 summary table, and
does not change the "two municipalities" baseline declared in
`CLAUDE.md`/`docs/scope.md`.** Run at the user's explicit request in
chat, staged deliberately separately from a possible future full
third-municipality integration (see "Not confirmed" below).

Real, verified source data (not fabricated): Sapporo City (札幌市)
PLATEAU CityGML, dataset `01100_sapporo-shi_city_2020`, archive
`01100_sapporo-shi_city_2020_citygml_7_op.zip`, downloaded from
`https://assets.cms.plateau.reearth.io/assets/be/3b8cfb-5459-4f9d-b08c-fb4ab72fbdbd/01100_sapporo-shi_city_2020_citygml_7_op.zip`,
2,718,857,710 bytes (HEAD-confirmed before download, byte-identical
after), SHA-256
`bc0f3d9de76b5f298741a5c0cac747293fbff8ec07de8a4dbf7c8d944dd8ac72`
(computed on download, not published anywhere to cross-check against —
same trust-on-first-fetch model as Sarabetsu/Muroran's original
checksums). Catalog:
`https://www.geospatial.jp/ckan/dataset/plateau-01100-sapporo-shi-2020`.
2020 catalog year, V4 spec. License/attribution same as Sarabetsu/Muroran
(CC BY 4.0, 国土交通省 Project PLATEAU). Full provenance note in
`docs/data-selection.md`.

### Method

Same out-of-pipeline approach as the LOD3 sub-goal: not run through
`make build`/`make fetch`, no `config/sapporo.yml`, no
`data/input-manifest.yml` entry — a deliberately isolated, manual test
that leaves the formal per-dataset pipeline (confirmed generic/reusable
for a real third dataset, but not invoked here) untouched.

1. Downloaded the full archive (its own distribution unit — PLATEAU does
   not offer partial/per-feature downloads), listed its contents without
   full extraction (`unzip -l`), found 604 `udx/bldg/*.gml` mesh files,
   of which exactly 14 have a paired `_appearance/` subdirectory
   containing real JPEG textures (confirms Sapporo's declared 3.27 km²
   LOD2 coverage is not textured uniformly — texturing is scoped to
   specific mesh cells).
2. Extracted and inspected 3 of those 14 mesh files
   (`64414293`, `64414279`, `64414380` — chosen for a range of texture
   complexity: 3, 23, and 38 `_appearance/*.jpg` files respectively).
   Each turned out to contain **exactly one** `app:ParameterizedTexture`-
   referencing building, out of 2,548 / 1,449 / 796 total buildings in
   those files — real evidence, not assumed, that Sapporo applies LOD2
   texturing to selected landmark buildings within the coverage area,
   not blanket citywide.
3. Verified CRS/axis order empirically against the extract's own
   `gml:pos` values before running `tools/geoid_correct.py` (which
   assumes lat/lon/height order, `tools/geoid_correct.py:42-45`) —
   confirmed `srsName="http://www.opengis.net/def/crs/EPSG/0/6697"` and
   coordinates in `(lat≈43.0-43.1, lon≈141.29, height)` order, identical
   to Sarabetsu/Muroran, so the tool's hardcoded assumption held without
   modification.
4. Merged the 3 buildings' `<core:cityObjectMember>` (geometry) and
   `<app:appearanceMember>` (texture reference) blocks into one 657KB
   standalone CityGML document (kept out of the repo, same as the LOD3
   extract — see `docs/data-selection.md`'s Phase 7b note for exact
   reproduction steps).
5. Ran the extract through `tools/geoid_correct.py` (corrected 177
   coordinate triplets across the 3 buildings) but skipped
   `tools/strip_higher_lod.py` (would have stripped the LOD2/texture
   geometry this test exists to check), then invoked Mago directly for
   both modes, same flags as the LOD3 sub-goal:
   ```
   docker run --rm -v <input>:/data/input -v <output>:/data/output \
     plateau-mago-implicit-tiler:1.16.2 \
     --input /data/input --output /data/output --inputType citygml \
     --proj "+proj=longlat +datum=WGS84 +axis=neu +no_defs" \
     --multiThreadCount 1
   # (Implicit mode additionally: --tilingMode implicit --implicitSubtreeLevels 3)
   ```

### Confirmed

- ✓ **Mago 3DTiler converts the extract cleanly in both modes.** Explicit:
  5 tile contents, 1.6s. Implicit: 3 tile contents, 1.3s. No crash, no
  exceptions.
- ✓ **Geographic placement is correct.** Root bounding region decodes to
  lon 141.29-141.38°E / lat 43.06-43.15°N (both modes) — inside Sapporo's
  real municipal extent (~43.0-43.2°N, 141.2-141.5°E), not accidentally
  reusing Sarabetsu/Muroran's coordinate range. Height range (45.7-75.7m
  ellipsoidal) is plausible for central Sapporo after geoid correction.
- ✓ **No new validator error class.** `3d-tiles-validator@0.6.1` against
  both outputs shows only the already-documented
  `METADATA_INVALID_LENGTH` pattern (same as every other build in this
  project) — nothing texture- or LOD2-specific.
- ✓ **Mago 3DTiler's CityGML import path does not preserve
  `app:ParameterizedTexture`/`app:Appearance` texture data into the
  output GLB — confirmed definitively, not just observed.** Directly
  inspected the decoded glTF JSON of the LOD2 content tile (`RC12.glb`,
  Explicit build): `images` and `textures` are both absent; every tile
  instead gets one flat default `COLOR_MATERIAL`
  (`baseColorFactor: [0.9, 0.9, 0.9, 1.0]`, an off-white gray) regardless
  of whether the source building had real texture data. Saved as
  `manifests/reports/phase7b-20260828/glb-gltf-json-sample.json`. Ruled
  out one alternate code path: `--photogrammetry`
  (`[Experimental] Generate b3dm with the compatibility-focused
  photogrammetry pipeline`) does not accept `citygml` input at all —
  threw `TileProcessingException: tileInfos is empty` immediately.

  **2026-08-28, follow-up investigation — root cause and upstream
  confirmation, both real:**
  - Cloned `github.com/Gaia3D/mago-3d-tiler` at commit `58fa970`
    (verified identical to tag `v1.16.2`, the exact version this project
    runs). `mago-io/src/main/java/com/gaia3d/converter/citygml/CityGmlConverter.java`
    (63,714 bytes) contains **zero** references to `texture`,
    `appearance`, `imageURI`, or `ParameterizedTexture` (case-insensitive
    grep, whole file, whole repo). Meanwhile the *output* writer
    (`mago-io/.../gltf/GltfWriter.java`) and the Assimp-based
    OBJ/FBX/3DS importer (`AssimpConverter.java`) both do reference
    texture handling — i.e. Mago's 3D Tiles/glTF writer is texture-capable
    in general; the CityGML *importer* specifically never populates any
    texture data for it to write. A structural gap in one input path,
    not a product-wide limitation.
  - **A Gaia3D maintainer confirms this directly.** GitHub issue
    [Gaia3D/mago-3d-tiler#81](https://github.com/Gaia3D/mago-3d-tiler/issues/81)
    ("CityGML Texture Issue: 'No surface found for city object' when
    using appearance with .tif textures", opened 2026-04-08) got this
    reply from maintainer `znkim` on 2026-04-13: *"At the moment, CityGML
    texturing is not yet fully supported in mago-3d-tiler... the current
    CityGML parser does not yet fully handle all geometry and appearance
    mappings required to bake textures correctly... I'll mention you once
    this is improved in a future release."* A second issue,
    [#73](https://github.com/Gaia3D/mago-3d-tiler/issues/73) ("How to
    make buildings have textures?"), got a similar answer from
    maintainer `sdson` for SHP input: *"mago-3d-tiles does not support
    textures for geometries built from shp. May be in the future we
    develop the texture version."* Consistent pattern across two
    different input formats, both confirmed by the people who wrote the
    code, not inferred.

  **Conclusion: this is a known, currently-unimplemented feature in
  Mago 3DTiler 1.16.2's CityGML import path — not a flag this project
  is missing, not a misconfiguration, and not something
  `--photogrammetry` or any other tested option works around.** Reported
  here as the specific, reproducible, version-pinned fact it is, per
  this project's tone conventions — not as criticism of the upstream
  project, which has already acknowledged the gap and stated an intent
  to improve it.

### Not confirmed

- ✗ Same scope as the LOD3 sub-goal: no structural tree comparison, no
  determinism, no full-profile build, no practical-consumption
  measurement — this is a small isolated conversion-and-inspect test,
  not a full phase.

### Conclusion and disposition

Per the user's explicit instruction (2026-08-28, after reviewing this
GitHub-sourced confirmation): **all further texture-dependent work is
discarded.** No upstream issue will be filed by this project (issues #81
and #73 already cover it, and Gaia3D is already aware). No further
CLI-flag exploration, no revisit of this sub-goal. The user's second,
separately-staged Sapporo motivation — demonstrating Implicit's
practical-consumption advantage at real scale — is **not affected** by
this finding (it never depended on texture support) and proceeds next as
the project's declared "Stage 2," a genuine third-municipality
integration. See the entry below this Phase 7 section once that work
lands.

---

## Phase 8: Sapporo City (札幌市) — scale demonstration

**Status: Fetch, inspect, small/full build, and validate all complete and
real, 2026-08-28. Full builds published to the same public host as
Sarabetsu/Muroran. Practical-consumption measurement handed off to the
user — same real-browser methodology as the 2026-08-26/27 cross-phase
measurement, blocked here for the same reason
(`document.visibilityState: "hidden"` prevents this session's own
browser tool from forcing real tile rendering).**

Run at the user's explicit request, after Phase 7b established Mago does
not support CityGML texture conversion — Sapporo's role here is scale
only, using the LOD1 baseline, same as Sarabetsu/Muroran. This is a real,
deliberate crossing of the "two municipalities only" boundary
(`CLAUDE.md`), done through the formal `config/`/`data/input-manifest.yml`
pipeline this time (not an isolated manual test like Phase 7), because
the goal — comparing practical consumption at real scale — needs the
actual publish/viewer path, not a hand-extracted sample.

### Source data (real, verified)

Dataset `01100_sapporo-shi_city_2020`, archive
`01100_sapporo-shi_city_2020_citygml_7_op.zip`, 2,718,857,710 bytes,
SHA-256 `bc0f3d9de76b5f298741a5c0cac747293fbff8ec07de8a4dbf7c8d944dd8ac72`
(same file Phase 7b used, re-fetched through `make fetch` this time —
checksum matched on re-verification). `make inspect DATASET=sapporo`
(`manifests/reports/inspect-sapporo.json`):

- 2,816 CityGML/XML files (whole-archive scan, same methodology as
  Sarabetsu/Muroran — most are non-building layers)
- **646,474 buildings** — 95x Sarabetsu's 6,795, 11.6x Muroran's 55,906
- 2,079,121 `gml:id`s, 67,363,086 polygons
- LODs present: [1, 2, 4] (LOD4 on a building feature is unusual but
  real, not a parsing artifact — irrelevant to the LOD1 baseline either
  way, since `tools/strip_higher_lod.py` strips everything except LOD1
  regardless of which higher LODs exist)
- 3,649 texture references (not used — Phase 7b already answered the
  texture question)
- Single CRS across the whole dataset: EPSG:6697, same as
  Sarabetsu/Muroran
- bbox: lat 42.781-43.192°N, lon 140.991-141.512°E

### Confirmed

- ✓ **Small-profile validation passed** (mirrors Phase 1/2/5): both
  modes built from the smallest single-building file
  (`udx/bldg/64413140_bldg_6697_op.gml`, 11,517 bytes), correct
  geographic placement (root region decodes to exactly the source
  file's own bbox, 42.956°N/141.130°E), only the already-documented
  `METADATA_INVALID_LENGTH` validator pattern (no new error class).
- ✓ **Full-profile Explicit build succeeds at this scale.** 15,001 tile
  contents, 152,242,012 bytes output, 53m38s build time, root
  `tileset.json` 3MB. Validator: 13,519 errors, all the same
  `CONTENT_VALIDATION_ERROR`-wrapped `METADATA_INVALID_LENGTH` pattern
  seen at every other scale in this project — confirmed by checking the
  distinct error `type` values directly (only 3 types total:
  `CONTENT_VALIDATION_ERROR`, `CONTENT_VALIDATION_INFO`,
  `METADATA_INVALID_LENGTH`) — no new class introduced by this dataset's
  much larger scale.
- ✓ **Full-profile Implicit build succeeds at this scale.** 6,450 tile
  contents (2.3x fewer than Explicit's 15,001, consistent with the
  content-merging behavior established in Phase 2), 440,093,344 bytes
  output (larger than Explicit's here — see "Not confirmed" below, this
  cuts against the file-count/byte-total pattern from Sarabetsu/Muroran),
  33m27s build time (faster than Explicit's), root `tileset.json` 436
  bytes (**7,032x smaller** than Explicit's 3MB — even more pronounced
  than the 105-663x range found at Sarabetsu/Muroran scale). Validator:
  6,067 errors, same pattern, no new class.
- ✓ **Geographic placement correct at full scale.** Explicit build's
  root region (fit to actual building extent) decodes to lon
  141.120-141.505°E / lat 42.896-43.184°N — squarely inside Sapporo's
  real municipal extent, ~31km × 32km (the largest extent of any dataset
  in this project — Sarabetsu was ~22km, Muroran ~15.5km).
- ✓ **Both full builds published to the real public host**
  (`tunnel.optgeo.org`, same target as Sarabetsu/Muroran), verified
  reachable via `curl -I` (200 OK, correct `content-length` for each).
- ✓ **Viewer wiring verified working**, without relying on the blocked
  full-rendering path: added `sapporo_explicit_full`/
  `sapporo_implicit_full` entries to `viewer/viewer.js`'s `VIEWPOINTS`
  (destination computed from the real Explicit build's bounding region,
  same convention as the existing entries — center lon 141.312568/lat
  43.040184, altitude 6000m, chosen the same way as Sarabetsu's 6000m:
  well below the ~19.8km distance at which this dataset's root
  geometricError (460.05) would stop refining at the default 16px SSE
  threshold) and matching `<option>`s in `viewer/index.html`. Loaded both
  in a local static-server preview and confirmed: correct dataset label,
  correct published tileset URL resolved, zero console errors, and the
  diagnostic hooks (`window.__practicalConsumptionDiagnostics`) fired
  correctly for the Implicit entry (useful-view time recorded: 96.6ms —
  fast because `flyTo`'s completion is camera-animation-based, not
  tile-render-based, consistent with how the diagnostic is defined).

### Not confirmed

- ✗ **Practical-consumption measurement not yet run.** This is the
  actual point of Phase 8 and needs the user's own browser (same
  blocker, same workaround as the 2026-08-26/27 measurement —
  `document.visibilityState: "hidden"` prevents this session's browser
  tool from forcing real tile rendering). `viewer/measure_practical_consumption.js`
  (new — closes the "never saved" gap from the earlier ad hoc DevTools
  snippet) is ready to paste into DevTools against
  `https://dwg7.github.io/plateau-mago-implicit/#dataset=sapporo_explicit_full`
  and `..._implicit_full` once the viewer changes are deployed to
  GitHub Pages.
- ✗ **Implicit's byte-total advantage does not hold at this scale, on
  raw output size** — Implicit's full build is 440MB vs Explicit's
  145MB, the opposite of what "Implicit wins on requests" might suggest
  and consistent with the earlier finding that "total file count/bytes
  don't consistently favor either mode" (Sarabetsu/Muroran cross-phase
  finding). Worth flagging plainly rather than only reporting the
  numbers that support the hypothesis: raw published size is not the
  claim under test here — request count and time-to-useful-view are
  (same distinction the original practical-consumption finding drew).
- ✗ No determinism study, no structural tree-comparison depth-match to
  Phase 2 — explicitly out of scope for "demonstrate scale advantage"
  (Phase 6 already generalized the batching-driven non-determinism
  finding across two municipalities; a third would be a separate ask).
- ✗ Viewer changes verified locally but not yet deployed — the public
  GitHub Pages viewer (`dwg7.github.io/plateau-mago-implicit`) still
  serves the pre-Sapporo `viewer.js`/`index.html` until this work is
  committed and pushed.

### Next smallest experiment

Commit and push the viewer/config/docs changes, confirm the GitHub Pages
deployment picks them up, then hand the two dataset URLs and
`viewer/measure_practical_consumption.js` to the user for the actual
measurement — the same handoff that produced real numbers on 2026-08-28
for Sarabetsu/Muroran.

---

## Summary table

| Claim | Status | Phase evaluated | Notes |
|---|---|---|---|
| Conversion feasibility | Partially confirmed | 1, 2, 4, 5, 6, 8 | Explicit fully confirmed for both municipalities' small_files; Implicit generated, geographically correct for both, fully validatable and fully compared against Explicit — but `3d-tiles-validator` reports a real `METADATA_INVALID_LENGTH` finding whose spec conformance is genuinely ambiguous (checked against the normative text), so "validates independently" is currently ✗. Both modes also convert both municipalities' full profiles (6,795 and 55,906 buildings) without crashing, and the METADATA_INVALID_LENGTH pattern holds consistently across both municipalities and both scales (4097 combined instances, 100% within the 4-byte-alignment-padding range). **(2026-08-26)** Discovered and fixed a real scope-boundary gap: full-profile builds were feeding Mago LOD0+LOD3 geometry alongside LOD1, contradicting CLAUDE.md's LOD1-only baseline — `tools/strip_higher_lod.py` now enforces this at the source-data level for every build, verified to shrink Sarabetsu's full-profile output 12-13% with no loss of LOD1 content (Muroran's output was already LOD0/LOD1-identical, so unaffected). **(2026-08-28, Phase 8)** Both modes also convert Sapporo's 646,474-building full profile (11.6x Muroran's scale) without crashing — 53m38s/33m27s build times, same already-documented METADATA_INVALID_LENGTH pattern only, no new error class at this larger scale |
| Determinism | **Fails at full scale for both municipalities (L3/FAIL); Level 2 holds only for the single-building small profile** | 3, 4, 5, 6 | Phase 3/5 (single-building small profile, Sarabetsu and Muroran, 2 concurrency settings each) confirm L2/PASS after fixing a GLB-UUID tooling false-negative. Phase 4/6 (full municipality, same procedure, both municipalities) contradict this: L3/FAIL at both concurrency settings for both. Sarabetsu's failure traced to one dominant 826-building source file; Muroran's showed no single common file, refining the hypothesis to "batching multiple buildings into one content tile carries non-determinism risk in general," not a one-file defect. **(2026-08-26)** Stripping that same file's LOD3 geometry (a plausible alternate explanation) left the non-determinism completely unchanged — same tile count, same coordinates — ruling out LOD-complexity as the cause and further confirming batch size/count is the real driver. Small-profile results were correct but never generalizable; full-scale is the honest answer for this claim, for both municipalities |
| Reproducibility | Partially confirmed | 0 | Source checksums and Mago JAR checksum both independently re-verified (fetch.sh's own check; Dockerfile's own check) — a third party could reproduce Phase 0/1 fetch+build from this repo's config as-is |
| Practical consumption | Partially confirmed | 2, 8, cross-phase (Implicit vs Explicit) | A real build, published to a real public host (tunnel.optgeo.org) over real HTTPS/CORS, loaded and rendered correctly in the GitHub Pages-hosted viewer in a real browser — but navigation/memory/long-session behavior at scale is still untested. **(2026-08-27)** Static file/byte comparison: Implicit's initial `tileset.json` payload is 105-663x smaller and constant-size regardless of building count, but total file count/bytes don't consistently favor either mode. **(2026-08-28)** Real-browser measurement (user's own Brave, one trial per combination): Implicit needs 56-65% fewer network requests and reaches a useful view 13-25% faster than Explicit for both municipalities' full profiles — the practical-consumption question this project set out to answer now has a real, if single-trial, answer favoring Implicit. Byte totals still unmeasured (blocked by `Timing-Allow-Origin`, an instrumentation gap, not a data gap). **(2026-08-28, Phase 8)** Sapporo City (646,474 buildings, 11.6x Muroran) built and published to test whether this gap widens at real metropolitan scale — root `tileset.json` gap widened further (7,032x smaller for Implicit, vs 105-663x at Sarabetsu/Muroran scale), but raw published output size does NOT favor Implicit here (440MB vs Explicit's 145MB, the opposite direction) — a reminder that byte totals and the actual practical-consumption claim (requests/time-to-useful-view) are different things. Real-browser request-count/timing measurement for Sapporo not yet run — same user-in-the-loop handoff as before |

Do not pre-fill conclusions. Record only evidence-based findings.
