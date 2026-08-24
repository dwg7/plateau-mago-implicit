# Validation

## Policy

Use independent validation where practical. Successful CesiumJS rendering is not
sufficient proof of validity. Validator success is not sufficient proof of usability.

Pin all validator versions. Preserve raw output. If validators disagree, retain
both findings.

## Validation checklist

For each Implicit 3D Tiles output:

- [ ] JSON schema validation of `tileset.json`
- [ ] 3D Tiles specification validation
- [ ] GLB/glTF content validation
- [ ] Subtree file decoding and availability validation
- [ ] URI template existence checks
- [ ] MIME-type checks on served files
- [ ] Checksum verification of output files
- [ ] Bounding-volume sanity checks
- [ ] Source-to-output building count reconciliation
- [ ] Duplicate and missing `gml:id` checks
- [ ] Repeated-build comparison

## Validators

| Tool | Purpose | Version |
|---|---|---|
| 3d-tiles-validator | 3D Tiles spec validation | 0.6.1 as run 2026-08-24 via unpinned `npx 3d-tiles-validator` — **not actually pinned**; `scripts/validate.sh` does not read `validators.tiles_validator_version` from `config/common.yml` at all. Real gap, tracked in HANDOVER.md. |
| gltf-validator | GLB/glTF content validation | TBD_VERIFIED_SOURCE_REQUIRED — not yet run independently; 3d-tiles-validator's content validation covers GLB but is a different tool |
| tools/inspect_subtree.py | Subtree decoding and inspection | (this repo) — **only implements the combined binary `.subtree` format; does not recognize the `.json`+`.bin` pair mago-3d-tiler 1.16.2 actually outputs.** Verified against real output: reports "Subtree files: 0". See docs/findings.md Phase 1/2. |
| tools/inspect_citygml.py | Source inspection | (this repo) |
| tools/compare_manifests.py | Build comparison | (this repo) |

## Subtree validation items

**Real mago-3d-tiler 1.16.2 output does not produce a combined binary
`.subtree` file** — it produces a separate JSON file (e.g.
`subtrees/R/0/0/0.json`) whose `buffers[0].uri` points at a sibling `.bin`
file (e.g. `subtrees/R/0/0/0.bin`). Both encodings are legal per the 3D
Tiles 1.1 spec. The checklist below describes the combined binary form as
originally planned; `tools/inspect_subtree.py` currently only implements
that form and is a no-op against real output (see docs/findings.md). This
checklist needs a second variant (or a rewrite) for the JSON+BIN form
before it can be run for real:

For each `.subtree` file (combined binary form):

- Magic bytes correct (`subt`)
- JSON header valid
- Binary buffer lengths match
- Tile availability bits decoded correctly
- Content availability bits decoded correctly
- Child subtree availability bits decoded correctly
- Available tile count matches content count (where applicable)
- No out-of-bounds addressing

For each subtree JSON+BIN pair (JSON-with-external-buffer form, what
mago-3d-tiler 1.16.2 actually produces) — not yet implemented by any tool
in this repo:

- Referenced `.bin` file exists and its size matches `buffers[0].byteLength`
- `bufferViews[]` offsets/lengths stay within the buffer
- `tileAvailability`/`contentAvailability`/`childSubtreeAvailability`
  bitstream references resolve to valid buffer views
- Available tile count matches content count (where applicable)

## Bounding volume checks

- Root bounding volume covers all buildings
- Tile bounding volumes are contained within parent
- No degenerate bounding volumes (zero-size or infinity)
- Geographic placement matches expected municipality location

## Building count reconciliation

```
source_building_count = (from tools/inspect_citygml.py)
output_building_count = (from tiles feature count)
missing_count = source_building_count - output_building_count
duplicate_count = (from gml:id duplicate check)
```

All missing or duplicate buildings must be explained, not silently accepted.

## HTTP delivery validation

- `Content-Type: application/json` for `.json` files (including subtree
  JSON, per the real output format — see above)
- `Content-Type: application/octet-stream` for combined-binary `.subtree`
  files (spec form not currently produced by mago-3d-tiler 1.16.2) and for
  `.bin` subtree buffer files (real output form)
- `Content-Type: model/gltf-binary` for `.glb` files
- `Access-Control-Allow-Origin: *` present
- `Accept-Ranges: bytes` present for large content
- No 4xx or 5xx responses for expected tile paths

Verified 2026-08-25 by starting the real `server` (nginx) compose service
and curling a real build's `tileset.json` and (at the time, still binary
`.subtree` format assumption) subtree path directly — see
`config/nginx.conf` and the commit that fixed its `.subtree` Content-Type
from `application/json` to `application/octet-stream`.

## Results

**Partially evaluated — see `docs/findings.md` for the authoritative,
phase-by-phase record.** Summary: Explicit baseline (Phase 1) fully passed
for Sarabetsu's small_file. Implicit output (Phase 2) generated and
geographically verified, but the subtree validation checklist above could
not be run for real (tooling gap). Independent `3d-tiles-validator` found
real `METADATA_INVALID_LENGTH` errors in generated GLB content that
`scripts/validate.sh` does not currently gate on.
