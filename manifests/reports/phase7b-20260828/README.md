# Phase 7b (texture sub-goal) test artifacts, 2026-08-28

Not produced by `make build` — a deliberately isolated, one-off test per
`docs/findings.md`'s "Phase 7b: texture sub-goal" section. See that
section for the full reproduction steps, source building IDs, and
findings. Mirrors the `manifests/reports/phase7-20260828/` (LOD3) report
directory's structure and rationale.

- `tileset-explicit.json` / `tileset-implicit.json`: root tileset.json
  from each mode's output (5 / 3 tile contents respectively).
- `3dtiles-validator-*.log`: raw `3d-tiles-validator@0.6.1` output.
- `glb-gltf-json-sample.json`: the decoded glTF JSON chunk from one
  representative GLB (`RC12.glb`, the LOD2 content tile from the
  Explicit build), showing the actual `materials`/`images`/`textures`
  arrays Mago produced — the direct evidence for this test's central
  finding (no `images` or `textures`, only a flat default material).

The full output directories (GLB/subtree content) and the source data
(the 2.7GB Sapporo archive, the merged 657KB CityGML extract, and the
geoid-corrected intermediate) are not committed, for the same reason
`manifests/reports/phase7-20260828/README.md` gives: this was a manual,
one-off invocation outside `make build`, not reproducible by a single
command.

## Provenance (see also `docs/data-selection.md`'s Phase 7b note)

Source: Sapporo City (札幌市) PLATEAU CityGML,
`01100_sapporo-shi_city_2020_citygml_7_op.zip`,
SHA-256 `bc0f3d9de76b5f298741a5c0cac747293fbff8ec07de8a4dbf7c8d944dd8ac72`,
2,718,857,710 bytes, downloaded from
`https://assets.cms.plateau.reearth.io/assets/be/3b8cfb-5459-4f9d-b08c-fb4ab72fbdbd/01100_sapporo-shi_city_2020_citygml_7_op.zip`.

Three buildings, each the sole texture-bearing (`app:ParameterizedTexture`)
building found in its respective PLATEAU 3rd-level mesh cell:

| Building `gml:id` | Source mesh file | Texture surfaces |
|---|---|---|
| `bldg_16052a8c-cc5c-470f-bfec-24c954e9238b` | `udx/bldg/64414293_bldg_6697_op.gml` | 3 |
| `bldg_b8f611c9-0d44-4b14-8d63-a890f526881a` | `udx/bldg/64414279_bldg_6697_op.gml` | 23 |
| `bldg_6d43503c-fa27-421f-83cb-2bbdc9a32be2` | `udx/bldg/64414380_bldg_6697_op.gml` | 38 |

14 of Sapporo's 604 `udx/bldg/*.gml` mesh files contain an
`_appearance/` subdirectory with real JPEG textures; every one checked
(3 of 14) turned out to have exactly one textured building, suggesting
Sapporo's LOD2 texturing is applied to selected landmark buildings, not
uniformly across the LOD2-covered area — itself a finding, not an
assumption.
