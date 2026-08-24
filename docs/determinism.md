# Determinism

## Goal

Confirm that repeated builds from identical source data, converter version,
configuration, and environment produce stable output paths and logical content.

## Repeatability levels

| Level | Description | Determinism status |
|---|---|---|
| 1 | Byte-identical output | Passes (strong) |
| 2 | Structurally identical after documented normalization | Passes (required minimum) |
| 3 | Semantically equivalent but structurally different | Fails |

A deterministic pass requires Level 2 or better.

## Potentially non-semantic differences (normalizable)

These differences are expected and do not indicate non-determinism:

- JSON key ordering in `tileset.json`
- Embedded timestamps or UUIDs in output
- Binary padding that decodes identically
- Compression details that produce identical decoded content
- File ordering within archives

These are handled by `tools/normalize.py` before comparison.

## Operationally significant differences (must not occur)

These differences indicate non-determinism and must be investigated:

- Changed output file paths or directory structure
- Changed subtree boundaries
- Changed tile availability bits
- Changed feature-to-tile assignment
- Changed `gml:id` preservation
- Changed bounding volumes or geometric errors
- Missing or duplicate geometry between builds
- Changed metadata schemas or values
- Changed identifier assignments

## Test procedure

1. Build the target dataset twice in the same pinned environment
2. Record start time, end time, and return code for each build
3. Run `tools/normalize.py` on both outputs
4. Run `tools/compare_manifests.py` to classify differences
5. Record the repeatability level achieved

```bash
# Build 1
make build DATASET=sarabetsu MODE=implicit PROFILE=small

# Build 2
make build DATASET=sarabetsu MODE=implicit PROFILE=small

# Compare
make compare DATASET=sarabetsu MODE=implicit PROFILE=small
```

## Concurrency effect

Test at two concurrency settings if possible:

```bash
make build DATASET=sarabetsu MODE=implicit PROFILE=small CONCURRENCY=1
make build DATASET=sarabetsu MODE=implicit PROFILE=small CONCURRENCY=4
```

Record whether parallelism changes output. If it does, document the specific
differences and classify them.

## Difference classification

After normalization, differences are classified as:

| Category | Description |
|---|---|
| `byte-only` | Raw byte difference that decodes identically |
| `serialization-only` | JSON ordering or formatting difference |
| `structural` | Structural difference in hierarchy or file layout |
| `hierarchy` | Subtree boundary or level assignment change |
| `availability` | Tile or content availability bit change |
| `geometry` | Mesh vertex/index content change |
| `metadata` | Feature metadata change |
| `identifier` | Feature identifier change |
| `unexplained` | Cannot be classified by known categories |

`unexplained` differences must be investigated before declaring a pass.

## Results

**Formal Phase 3 (this procedure, both concurrency settings) has not been
run yet.** A preliminary, informal two-build comparison was done
2026-08-24 while verifying Phase 1/2 worked at all, and is recorded here
because it produced a concrete, root-caused finding worth keeping — full
detail in `docs/findings.md` Phase 3:

| Run | Build ID | Duration | Level | Notes |
|---|---|---|---|---|
| 1 | `20260824T215746Z-sarabetsu-implicit-small` | 1s | — | `tileset.json` + subtree byte-identical to run 2 |
| 2 | `20260824T215851Z-sarabetsu-implicit-small` | 2s | — | Same as above; `compare-builds.sh` verdict: **L3 / FAIL**, but root-caused to a random UUID mago-3d-tiler embeds in GLB metadata (`id` property) — not a difference in `tileset.json`, subtree structure, or actual geometry. Believed to be a tooling false-negative (`tools/normalize.py` doesn't yet redact GLB-internal UUIDs), not evidence of genuine Mago non-determinism, but that belief has not been confirmed by fixing the tooling and re-running. |

Formal Phase 3 (concurrency=1 vs concurrency>1, full classification) is
next after the GLB-UUID normalization gap is closed — see `HANDOVER.md`.
| 2 | TBD | TBD | TBD | TBD |
