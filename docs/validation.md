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
| 3d-tiles-validator | 3D Tiles spec validation | TBD_VERIFIED_SOURCE_REQUIRED |
| gltf-validator | GLB/glTF content validation | TBD_VERIFIED_SOURCE_REQUIRED |
| tools/inspect_subtree.py | Subtree decoding and inspection | (this repo) |
| tools/inspect_citygml.py | Source inspection | (this repo) |
| tools/compare_manifests.py | Build comparison | (this repo) |

## Subtree validation items

For each `.subtree` file:

- Magic bytes correct (`subt`)
- JSON header valid
- Binary buffer lengths match
- Tile availability bits decoded correctly
- Content availability bits decoded correctly
- Child subtree availability bits decoded correctly
- Available tile count matches content count (where applicable)
- No out-of-bounds addressing

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

- `Content-Type: application/json` for `.json` and `.subtree` files
- `Content-Type: model/gltf-binary` for `.glb` files
- `Access-Control-Allow-Origin: *` present
- `Accept-Ranges: bytes` present for large content
- No 4xx or 5xx responses for expected tile paths

## Results

*Not yet evaluated. This section will be filled as phases complete.*
