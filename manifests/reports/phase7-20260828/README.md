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
