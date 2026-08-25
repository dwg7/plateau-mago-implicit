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

**Formal Phase 3 (this procedure, both concurrency settings) run
2026-08-25** — Sarabetsu Village, implicit mode, small profile, single
building (`63437290_bldg_6697_op.gml`), all four builds in the same pinned
environment (Mago 3DTiler 1.16.2, same Docker image) back-to-back:

| Run | Build ID | Concurrency | Duration | Root tileset.json SHA-256 |
|---|---|---|---|---|
| 1 | `20260825T101519Z-sarabetsu-implicit-small` | 1 | 2s | `4e86402...` |
| 2 | `20260825T101534Z-sarabetsu-implicit-small` | 1 | 1s | `4e86402...` (identical) |
| 3 | `20260825T101608Z-sarabetsu-implicit-small` | 4 | 1s | `4e86402...` (identical) |
| 4 | `20260825T101615Z-sarabetsu-implicit-small` | 4 | 1s | `4e86402...` (identical) |

| Comparison | Level | Determinism | Notes |
|---|---|---|---|
| Run 1 vs Run 2 (concurrency=1 vs 1) | L2 | ✓ PASS | Only difference: `data/R/3/4/2.glb`, classified `byte-only` (the known per-run random UUID Mago embeds in `EXT_structural_metadata`, redacted by `tools/normalize.py` before hashing) |
| Run 3 vs Run 4 (concurrency=4 vs 4) | L2 | ✓ PASS | Same single `byte-only` difference, same file |
| Run 1 vs Run 3 (concurrency=1 vs 4) | L2 | ✓ PASS | Same single `byte-only` difference — concurrency setting itself produced no additional differences beyond the baseline per-run UUID |

All four `tileset.json` root files are byte-identical (same SHA-256); all
four subtree JSON+bin pairs matched; the only difference in any comparison,
at either concurrency setting or across settings, was the same benign
embedded-UUID `byte-only` difference already characterized in Phase 3's
Unexpected findings. **Claim 2 (determinism) is now formally confirmed at
Level 2 for this dataset/profile** — not just the earlier preliminary
single-pair signal. Full reports:
`manifests/reports/comparison-20260825T101519Z-...-vs-20260825T101534Z-...md`,
`manifests/reports/comparison-20260825T101608Z-...-vs-20260825T101615Z-...md`,
`manifests/reports/comparison-20260825T101519Z-...-vs-20260825T101608Z-...-concurrency1v4.md`.

**Caveat:** this is still the single-building small_file, not a
multi-building/full-profile run — see Phase 4 for whether concurrency
effects change at real scale (many buildings processed across threads is a
materially different code path than one building on any thread count).
