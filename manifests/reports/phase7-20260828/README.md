# Phase 7 (LOD3 sub-goal) test artifacts, 2026-08-28

Not produced by `make build` — a deliberately isolated, one-off test
per `docs/findings.md`'s "Phase 7: Optional higher-detail tests" section.
See that section for the exact reproduction steps, source building IDs,
and findings.

- `tileset-explicit.json` / `tileset-implicit.json`: root tileset.json
  from each mode's output (147 / 57 tile contents respectively).
- `3dtiles-validator-*.log`: raw `3d-tiles-validator@0.6.1` output.

The full output directories (GLB/subtree content, ~9-13MB combined) and
the 8.9MB extracted source CityGML are not committed — see
docs/findings.md's "Not confirmed" note on why.

## Correction, 2026-08-29

The original 2026-08-28 run inferred LOD3 geometry was "actually being
processed" from tile counts alone, without an LOD1-only side-by-side
comparison. Built one on 2026-08-29 (same 4 buildings, same commands,
`tools/strip_higher_lod.py` applied instead of the `PHASE7=1` bypass):
the result is byte-for-byte SHA-256-identical to this directory's own
`tileset-*.json`/build output, in both modes. `sha256sum-glb-comparison.txt`
records the exact diff command and its empty (zero-differences) result.
Root cause and full write-up: `docs/findings.md`'s Phase 7 "Confirmed"
section (the corrected entry, not the struck-through original).
**Mago never actually incorporated this dataset's LOD3 geometry** — see
that section for why (the direct-child `lod3Solid` element is a pure
`xlink:href` reference wrapper with no inline geometry for these
buildings).
