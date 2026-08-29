# Limitations

## Declared scope limitations

- Tests three municipalities (Sarabetsu Village, Muroran City, and Sapporo
  City — the last added 2026-08-28 specifically for scale, not texture;
  see `docs/findings.md` Phase 8)
- No planet-scale capability is claimed
- LOD1 buildings only in baseline
- Feature scope: building features only

## Excluded feature types

The following are excluded from the baseline:

- Roads and transportation infrastructure
- Terrain and digital elevation models
- Bridges
- Vegetation
- Urban facilities
- Land use
- Water bodies
- Underground structures
- Any other non-building feature types

Expanding feature scope requires separate investigation.

## Technical limitations

- CesiumJS is the only tested client in the baseline
- MapLibre and other clients are not tested
- No spatial database or dynamic tile server
- No production reliability, SLA, or scale testing
- No network shape testing (local loopback only in development profile)
- **CesiumJS version matters a great deal for Implicit Tiling specifically.**
  CesiumJS 1.117 (this project's originally pinned version) never renders
  Implicit Tiling content at all — its tile traversal never visits even
  the root tile, so the subtree file is never requested. Confirmed with
  both this project's own Mago output and the official
  `CesiumGS/3d-tiles-samples` implicit-tiling reference tileset, so it's a
  CesiumJS defect, not a PLATEAU/Mago data issue. **Fixed as of CesiumJS
  1.144** (current latest as of 2026-08-25) — `viewer/index.html` now
  pins that version. Best-evidenced candidate for the exact fix (via
  changelog/PR research, not literal bisection): CesiumJS 1.135,
  [PR #12972](https://github.com/CesiumGS/cesium/pull/12972). See
  `docs/findings.md` Phase 2.

## Data limitations

- Source data is limited to publicly available PLATEAU releases
- Source data checksums must be resolved before the experiment runs
- Source data is not committed to this repository
- Fixture files are small and may not represent full municipal complexity

## Mago 3DTiler limitations

**Populated from Phase 0/1 (2026-08-25), version 1.16.2.** See
`docs/findings.md` for full detail and evidence.

- **Implicit Tiling is marked `[Experimental]`** in mago-3d-tiler's own
  `--help` output and `MANUAL.md`, stated here accurately and neutrally per
  the note this section originally called for.
- **CRS/axis-order handling requires a workaround.** Passing `--crs`
  with PLATEAU's own EPSG code (6697) or common alternatives (6668, 4326)
  silently produces geographically wrong output, because PLATEAU's
  `gml:pos` axis order (lat, lon, height) doesn't match what `--crs`
  assumes. An explicit `--proj "+proj=longlat +datum=WGS84 +axis=neu
  +no_defs"` is required instead. This is a real limitation of the
  `--crs` code path for this class of source data, not a PLATEAU data
  defect.
- **Implicit subtree output is JSON+BIN, not the combined binary
  `.subtree` format.** Both are legal per the 3D Tiles 1.1 spec, but
  this project's own `tools/inspect_subtree.py`/`tools/normalize.py` only
  implement the binary form (a gap in this project's tooling, not a Mago
  defect) — tracked as the top HANDOVER.md follow-up.
- **A random UUID is embedded in generated GLB structural metadata** on
  every conversion run, changing the file's raw bytes even for identical
  input. This is the direct, confirmed cause of a false-negative
  determinism result during a preliminary two-build comparison (see
  `docs/findings.md` Phase 3). Not yet reported upstream (no minimal
  reproduction case prepared); its purpose (feature ID? trace ID?) is not
  yet understood.
- **The independent `3d-tiles-validator` found real
  `METADATA_INVALID_LENGTH` errors** in generated GLB structural metadata
  (`BatchId`/`FileName` properties) — a plausible Mago 3DTiler bug, flagged
  as an upstream candidate in `docs/findings.md` but not yet reported.
- Height offset handling and PLATEAU URO extension attribute support have
  not yet been specifically investigated (only geometry/coordinates so
  far) — remains open for Phase 1–2 follow-up.
- **CityGML texture/appearance data (`app:ParameterizedTexture`) is not
  converted.** Confirmed both empirically (Phase 7b: a real textured
  Sapporo building produced a GLB with no `images`/`textures`, only a flat
  default material) and against Mago's own source
  (`CityGmlConverter.java`, 1.16.2, contains no texture/appearance-handling
  code) and upstream maintainer statements
  ([Gaia3D/mago-3d-tiler#81](https://github.com/Gaia3D/mago-3d-tiler/issues/81),
  [#73](https://github.com/Gaia3D/mago-3d-tiler/issues/73)): *"At the
  moment, CityGML texturing is not yet fully supported in
  mago-3d-tiler."* Geometry conversion itself (including LOD2/LOD3) is
  unaffected. See `docs/findings.md` Phase 7b.

## Validation limitations

- Validators may disagree with each other; both findings are retained
- Validator success is not proof of usability
- CesiumJS rendering success is not proof of specification conformance

## Reproducibility limitations

- Non-deterministic behavior in Mago (if any) will be documented
- Platform-specific differences (if any) will be recorded
- The experiment does not guarantee reproducibility across all platforms

## What cannot be concluded from this experiment

- That 3D Tiles are superior or inferior to other delivery formats
- That the tested approach is production-ready
- That Mago 3DTiler is the best or only suitable converter
- That CesiumJS is the only suitable client
- That three municipalities represent all PLATEAU data behavior
- That open-source tools equal commercial service quality at scale

## Non-goals

See [scope.md](scope.md) for the full non-goals list.
