# CLAUDE.md

Guidance for Claude Code (and other AI coding agents) working in this repository.

## What this repository is

A small, rigorous, reproducible technical experiment (UN Open GIS Initiative DWG7
working style) testing whether Project PLATEAU (プロジェクト PLATEAU) CityGML
building data for two Hokkaido municipalities — Sarabetsu Village (更別村) and
Muroran City (室蘭市) — can be converted to **Implicit 3D Tiles** via **Mago
3DTiler**, deterministically and reproducibly, and served to **CesiumJS** from
plain static HTTP (no backend, no spatial database).

Read [README.md](README.md) and, in order, `docs/hypothesis.md`, `docs/scope.md`,
`docs/architecture.md`, `docs/test-plan.md` before making non-trivial changes.
`docs/findings.md` is the running experiment log — check its "Not started" /
"Confirmed" markers to see what has actually been executed versus what is still
scaffolding.

## Hard scope boundaries — do not cross without the user's explicit sign-off

These are deliberate, documented constraints (see `docs/scope.md`,
`docs/limitations.md`, `CONTRIBUTING.md`). Treat any change that crosses one of
these as a scope change to flag, not a routine edit:

- **Two municipalities only**: Sarabetsu Village and Muroran City. Do not add a
  third without the user asking for it.
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

## Known issues in the current pipeline (read before running `make experiment`)

A review of the bootstrap PR found several bugs that will surface the moment
someone actually runs the pipeline end-to-end rather than just linting it.
Check `docs/findings.md` / recent commits to see whether these have been fixed
before assuming the pipeline works as documented:

- `config/muroran.yml` used `small_files:` (plural) while `scripts/build.sh`
  looked for `small_file:` (singular) — Muroran's small-profile build failed
  outright. Verify the key names in `config/*.yml` actually match what
  `scripts/build.sh` greps for before trusting a `make build DATASET=muroran`
  run.
- `scripts/build.sh` builds its `docker run` invocation as a string and
  executes it with `eval`, with `$DATASET` flowing unsanitized (and without an
  allowlist) into the interpolated path. Treat `DATASET` as an untrusted input
  boundary if you touch this script — validate it against `sarabetsu|muroran`
  (or the current dataset list) before it reaches any path construction or
  `eval`.
- `viewer/viewer.js`'s hardcoded tileset URLs don't include the build's
  timestamped `BUILD_ID` directory and don't match the `/tiles/` path nginx
  actually serves — the viewer 404s against real build output. If you change
  `scripts/build.sh`'s output path or `config/nginx.conf`'s serving path,
  update `viewer/viewer.js` in the same change.
- `scripts/generate-manifest.sh` → `tools/summarize_metrics.py --manifest`
  appends a raw JSON line onto the `.yml` build manifest that
  `scripts/build.sh` already wrote, corrupting it as YAML.
- `scripts/compare-builds.sh`'s `find -maxdepth 1 -type d | sort | tail -2`
  includes the parent output directory itself, so the "need at least two
  builds" guard can be bypassed when only one real build exists.
- `tools/normalize.py`'s docstring claims it records GLB mesh/accessor counts;
  it currently only hashes GLB files. Since `tests/run-tests.sh` only exercises
  `normalize.py` against an empty directory, this gap is invisible until a real
  build's `.glb` output is normalized — be skeptical of "Level 2 determinism"
  claims until this is either implemented or the claim is corrected.

None of this blocks documentation-only or scaffolding work, but treat
`make build DATASET=muroran`, `make experiment`, and `make serve` + viewer as
**not yet proven to work** until these are addressed.

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
