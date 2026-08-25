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

**Caveat (resolved, see below): this was still the single-building
small_file, not a multi-building/full-profile run** — the concurrency
effects at real scale turned out to matter a great deal.

**Formal Phase 4 (same procedure, full profile) run 2026-08-25** —
Sarabetsu Village, implicit mode, **full profile** (all 187 building mesh
files, 6,795 buildings), same environment, same procedure:

| Run | Build ID | Concurrency | Duration | Output files | Root tileset.json SHA-256 |
|---|---|---|---|---|---|
| 1 | `20260825T134415Z-sarabetsu-implicit-full` | 1 | 31s | 1061 | `016c449...` |
| 2 | `20260825T134614Z-sarabetsu-implicit-full` | 1 | 34s | 1061 | `016c449...` (identical) |
| 3 | `20260825T134848Z-sarabetsu-implicit-full` | 4 | 27s | **1060** | `016c449...` (identical) |
| 4 | `20260825T134925Z-sarabetsu-implicit-full` | 4 | 28s | 1061 | `016c449...` (identical) |

| Comparison | Level | Determinism | Notes |
|---|---|---|---|
| Run 1 vs Run 2 (concurrency=1 vs 1) | **L3** | **✗ FAIL** | 804/1061 files differ; 794 `byte-only` (benign UUID, as expected), but **10 files classified `geometry`** — real vertex/index binary differences |
| Run 3 vs Run 4 (concurrency=4 vs 4) | **L3** | **✗ FAIL** | 790 `byte-only`, 13 `geometry`, **plus `data/R/5/13/12.glb` present in run 4 and entirely absent from run 3** — a missing content tile, the "missing or duplicate geometry between builds" case this document lists as operationally significant |

Root `tileset.json` stayed byte-identical across all four runs — the
non-determinism is confined to specific content GLBs, not the tile
hierarchy structure itself. Every recurring `geometry`-flagged tile across
both comparisons shares one common source file in its batched content:
`63437175_bldg_6697_op.gml` (15.3 MB, 826 buildings) — no other source
file appears in an affected tile that this one doesn't also appear in.
**Claim 2 (determinism) fails at full-profile scale, for a real,
root-caused, non-diffuse reason** — not evenly distributed noise, one
specific large multi-building source file's geometry (most plausibly its
triangulation step) is non-deterministic between runs, at both
concurrency settings tested. The earlier single-building small-profile
L2/PASS was correct but never a valid basis for a general "Mago is
deterministic" claim. Full detail and the exact byte-diff analysis:
`docs/findings.md` Phase 4.

**Formal Phase 6 (same procedure, Muroran full profile) run 2026-08-25**
— repeats the exact Phase 4 procedure on Muroran (55,906 buildings, 100
files) instead of Sarabetsu, to check generalization:

| Run | Build ID | Concurrency | Output files | Root tileset.json SHA-256 |
|---|---|---|---|---|
| 1 | `20260825T140722Z-muroran-implicit-full` | 1 | 818 | `69175b7...` |
| 2 | `20260825T140847Z-muroran-implicit-full` | 1 | 818 | `69175b7...` (identical) |
| 3 | `20260825T141104Z-muroran-implicit-full` | 4 | 818 | `69175b7...` (identical) |
| 4 | `20260825T141217Z-muroran-implicit-full` | 4 | 818 | `69175b7...` (identical) |

| Comparison | Level | Determinism | Notes |
|---|---|---|---|
| Run 1 vs Run 2 (concurrency=1 vs 1) | **L3** | **✗ FAIL** | 548 `byte-only`, **5 `geometry`** (real vertex/index differences, confirmed by byte-diffing the largest affected tile) |
| Run 3 vs Run 4 (concurrency=4 vs 4) | **L3** | **✗ FAIL** | 528 `byte-only`, **25 `geometry`** — 5× the concurrency=1 count, from a single comparison at each setting (a signal, not a confirmed effect size without repeated trials) |

**Confirms Phase 4 generalizes beyond Sarabetsu, but refines the
root-cause picture.** Unlike Sarabetsu, no single source file was common
to every geometry-affected tile — Muroran's 100 building files are more
uniform in size (no 15 MB/826-building outlier), so tiles batch
contributions from several files rather than one dominant one. The more
defensible characterization: non-determinism lives in *batching multiple
buildings into one content tile's mesh*, not in one specific defective
source file. The concurrency=1-vs-4 asymmetry (5 vs 25 affected tiles) is
a real hint that thread-level ordering adds on top of a baseline
non-determinism present even single-threaded, but this needs repeated
trials at each setting to confirm as an effect, not just note as a single
comparison's result. Full detail: `docs/findings.md` Phase 6.
