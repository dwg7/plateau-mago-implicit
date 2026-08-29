# CLAUDE.md

Guidance for Claude Code (and other AI coding agents) working in this repository.

## What this repository is

**PLATEAU Kai** — applying the latest (2026) open-source technology to
Project PLATEAU building data for Hokkaido, aiming for faster PLATEAU
display, as a way to test where 3D web mapping currently stands. See
`DECISIONS.md` D22 for the full naming rationale (開/カイ/快) and how
this broader purpose relates to the project's original research
question.

Concretely, that purpose is pursued through a small, rigorous,
reproducible technical experiment (UN Open GIS Initiative DWG7 working
style) testing whether Project PLATEAU (プロジェクト PLATEAU) CityGML
building data for three Hokkaido municipalities — Sarabetsu Village
(更別村), Muroran City (室蘭市), and Sapporo City (札幌市) — can be
converted to **Implicit 3D Tiles** via **Mago 3DTiler**, deterministically
and reproducibly, and served to **CesiumJS** from plain static HTTP (no
backend, no spatial database). This experiment — the four claims below,
the hard scope boundaries, and the respectful-positioning stance — is
the actual evaluation mechanism; the broader purpose above explains why
it matters, not a license to relax any of it.

Read [README.md](README.md) and, in order, `docs/hypothesis.md`, `docs/scope.md`,
`docs/architecture.md`, `docs/test-plan.md` before making non-trivial changes.
`docs/findings.md` is the running experiment log — check its "Not started" /
"Confirmed" markers to see what has actually been executed versus what is still
scaffolding.

## Hard scope boundaries — do not cross without the user's explicit sign-off

These are deliberate, documented constraints (see `docs/scope.md`,
`docs/limitations.md`, `CONTRIBUTING.md`). Treat any change that crosses one of
these as a scope change to flag, not a routine edit:

- **Three municipalities**: Sarabetsu Village, Muroran City, and Sapporo City
  (札幌市). Sapporo was added 2026-08-28 at the user's explicit request,
  specifically to demonstrate Implicit's practical-consumption advantage at
  real metropolitan scale (~1.96M population, vs Muroran's ~90K) — not for
  texture testing (Phase 7b, `docs/findings.md`, established that Mago
  3DTiler 1.16.2's CityGML importer does not support texture conversion at
  all, confirmed against upstream source and maintainer statements). Do not
  add a fourth without the user asking for it.
- **Building features only, LOD1 in baseline.** Roads, terrain, bridges,
  vegetation, land use, water bodies, underground structures, and higher LOD /
  textures are explicitly out of scope for the baseline (Phase 7 is the only
  place higher detail is allowed, and it must stay separate from Phase 1–6).
- **No spatial database, no dynamic tile server, no custom backend.** The whole
  point of the experiment is static-HTTP delivery of pre-generated tiles.
- **CesiumJS is the only tested client.** Don't add MapLibre or another viewer
  framework as part of routine work.
- **Mago 3DTiler is the converter under test.** Don't swap in a different
  converter without first establishing the existing baseline.
- **Never fabricate source data values.** Dataset identifiers, download URLs,
  checksums, versions, and feature counts must come from real, verified
  sources. Unresolved values stay as the literal string
  `TBD_VERIFIED_SOURCE_REQUIRED` — every script that consumes them is expected
  to fail loudly and safely when it encounters that string. Do not invent a
  plausible-looking URL or checksum to make a script "work."

## Tone and framing (docs/respectful-positioning.md)

This project is explicitly **not** a criticism of, competitor to, or
replacement for commercial 3D city data conversion/delivery services, nor a
new standard. When writing docs, commit messages, or comments that touch
positioning:

- Prefer: independent regeneration path, open-source reference workflow,
  reproducible derived delivery view, static delivery pattern, complementary
  implementation path, inspectable conversion workflow, different operational
  assumptions.
- Avoid: vendor lock-in, escape, replacement, fake open, proprietary trap,
  "superior," "obsolete."
- Findings about Mago 3DTiler or CesiumJS limitations are reported as specific,
  reproducible, version-pinned facts — never as negative characterization of
  the upstream developers.
- English is the primary language. On first use of a Japanese proper noun in a
  document, give the Japanese name in parentheses (e.g. "Muroran City
  (室蘭市)"); English alone is fine after that.

## The four claims, and why they stay separate

`docs/hypothesis.md` and `docs/test-plan.md` define four independently
evaluated claims: conversion feasibility, determinism, reproducibility, and
practical consumption. **Never collapse these into one pass/fail verdict** —
that framing is called out explicitly in the docs, and code that reports
results should preserve the separation (see `tools/compare_manifests.py`'s
difference classification and `docs/determinism.md`'s repeatability levels 1–3
as the model to follow).

## Architecture at a glance

```
PLATEAU CityGML --fetch.sh (checksummed)--> data/source/
                 --build.sh (Mago in Docker)--> data/output/ (3D Tiles 1.1)
                 --validate.sh / normalize.py + compare_manifests.py--> manifests/
                 --serve.sh (nginx, static)--> CesiumJS viewer (viewer/)
```

Everything is driven through the `Makefile` (`bootstrap`, `fetch`, `inspect`,
`build`, `validate`, `compare`, `serve`, `viewer`, `test`, `clean`,
`experiment`), which shells out to `scripts/*.sh`, which in turn call
`tools/*.py` and read `config/common.yml` + `config/<dataset>.yml` +
`data/input-manifest.yml`. See `docs/architecture.md` for the full diagram and
`docs/reproducibility.md` for what must be pinned (tool versions, Docker
digests, checksums) versus what's allowed to vary.

## Known issues in the current pipeline

**Status as of 2026-08-25: Phase 1 (Sarabetsu Explicit + Implicit, small
profile) is real and verified working** — the pipeline was actually run
end-to-end against real PLATEAU data and real Mago 3DTiler, not just
linted. That run found and fixed several bugs that meant the pipeline, as
originally merged, crashed on *every single* `make build` invocation in
*both* modes (wrong CLI flags, a read-only mount Mago rejects, wrong CRS
handling, and a "small" profile that silently built the whole
municipality). Full detail with exact error text: `docs/findings.md`
Phase 1. Before touching `scripts/build.sh` or the Mago invocation again,
read that section — several of Mago's actual CLI flags are not what you'd
guess from its `--help` text alone without testing (e.g. `--crs 6697`
looks correct and runs without error, but silently produces wrong
coordinates; the fix is `--proj` with an explicit `+axis=neu`).

**Update 2026-08-25: the three tooling gaps below are now fixed and
re-verified against real data** (`tools/inspect_subtree.py`/
`tools/normalize.py` now decode the real `.json`+`.bin` subtree pair;
`tools/normalize.py` redacts mago-3d-tiler's per-run random UUID from GLB
content before hashing; `scripts/validate.sh` now gates on the
validator's `numErrors`). `make validate` and `make compare` now give
trustworthy answers — re-running the earlier two-build comparison
reclassified from L3/FAIL to L2/PASS, and `make validate` now correctly
reports a real `METADATA_INVALID_LENGTH` failure that was previously
silently hidden. Full detail: `docs/findings.md` Phase 2/3.

**Still not pinned:** `validators.tiles_validator_version` in
`config/common.yml` records the version observed (0.6.1) but
`scripts/validate.sh` doesn't actually read it — `npx` resolves whatever's
current at run time. Low priority, tracked in `HANDOVER.md`.

**Update 2026-08-25: real end-to-end browser rendering confirmed, but only
after fixing a CesiumJS version bug.** `viewer/index.html` originally
pinned CesiumJS 1.117, which has an implicit-tiling bug where the tile
traversal never visits the root tile — reproduced identically with the
official `CesiumGS/3d-tiles-samples` reference tileset, so it's a CesiumJS
defect, not anything about Mago's or this project's output. Fixed by
bumping to 1.144 (current latest). **Keep both CesiumJS and Mago 3DTiler
pinned to their latest releases** — re-check at the start of any session
that touches the viewer or the conversion pipeline (`gh api
repos/CesiumGS/cesium/releases/latest`, `gh api
repos/Gaia3D/mago-3d-tiler/releases/latest`; Mago's `main` branch and its
latest tag were confirmed to be the exact same commit, so no unreleased
snapshot is being missed as of this writing). Full detail: `docs/findings.md`
Phase 2, `DECISIONS.md` D20.

**A real build is now published to a real public host:**
`https://tunnel.optgeo.org/plateau-mago-implicit/` (via `scripts/publish.sh`
/ `make publish`, safe-by-default dry run unless `--execute`; SSH target
is `jaxa.optgeo.org`, distinct from the public HTTPS host — a Cloudflare
Tunnel detail, see `HANDOVER.md`). The live GitHub Pages viewer
(`https://dwg7.github.io/plateau-mago-implicit/`) loads and renders it
correctly. `viewer/viewer.js`'s predefined `VIEWPOINTS` still point at
same-origin `/tiles/...` paths, not yet repointed at the real hosted URLs
— see `HANDOVER.md`'s next step.

## Working conventions

- Shell scripts: POSIX-ish Bash, always `set -euo pipefail` (see
  `CONTRIBUTING.md`). Every script fails loudly (`exit 1` with a clear message
  on stderr) rather than silently proceeding with missing/TBD config.
- Python: PEP 8, standard library only — no new external dependencies without
  discussing it with the user first (`tools/*.py` currently has zero
  third-party imports beyond what's already in use).
- YAML: two-space indentation, quote strings where ambiguous.
- Every build produces a manifest under `manifests/builds/` recording tool
  versions/digests, exact command, timing, return code, and output checksums —
  don't add a code path that skips manifest generation.
- Source PLATEAU data is never committed to the repo (`data/source/`,
  `data/output/` are gitignored except `.gitkeep`); only the small synthetic
  fixture `data/fixtures/test_building.gml` is checked in, for CI.
- `make test` (== `tests/run-tests.sh`) must stay runnable with no network
  access — it's what CI (`.github/workflows/ci.yml`) runs on every PR. Don't
  make it depend on `docker`, real PLATEAU downloads, or Mago.

## Before claiming something works

`docs/findings.md` is explicit: "Do not pre-fill conclusions. Record only
evidence-based findings." Do not update phase status to ✓/~ without having
actually run the corresponding `make` target and inspected the output. If you
implement or fix something in the pipeline, that's a code change — it does not
by itself constitute a "finding" until someone runs it against real data.
