# Handover

Snapshot of where this experiment stands, for whoever (human or AI agent)
picks it up next. Update this file at the start and end of each significant
work session — it should always answer "what's the state right now and what's
the next concrete step," not narrate history (that's what git log and
`docs/findings.md` are for).

## Status as of 2026-08-25

**Phase: 0 (not started).** [PR #1](https://github.com/dwg7/plateau-mago-implicit/pull/1)
merged the full experiment scaffold (docs, `Makefile`, Docker setup, shell
scripts, Python tools, CesiumJS viewer, CI) into what was previously an empty
stub repo (LICENSE + two-line README). **No PLATEAU data has been fetched, no
conversion has been run, no claim in `docs/hypothesis.md` has been evaluated.**
Every field in `docs/data-selection.md` and `config/{sarabetsu,muroran}.yml`
is still `TBD_VERIFIED_SOURCE_REQUIRED`. `docs/findings.md` correctly shows
every phase as "Not started" — trust that file's status markers over anything
else when checking what's actually been done versus merely scaffolded.

Immediately after merging PR #1, all 6 confirmed pipeline bugs from the merge
review were fixed directly on `main` (commits `a046e8c`..`e07f092`, 2026-08-24),
along with two lower-severity issues. See "Bugs fixed after PR #1" below.
`make test` and CI are green as of that push. **This still does not mean the
pipeline works end-to-end** — CI has no Docker/network access, so `make build`,
`make experiment`, and the viewer have still never been exercised against a
real Mago 3DTiler run. Treat them as fixed-on-paper, not proven, until Phase 0
actually runs them.

## Bugs fixed after PR #1 (2026-08-24, commits a046e8c..e07f092)

All 6 bugs confirmed during the PR #1 review, plus 2 of the lower-severity
ones, were fixed directly on `main`:

1. ✅ `config/muroran.yml`'s `small_files:` (plural) renamed to `small_file:`
   (singular) to match what `scripts/build.sh` reads — Muroran's small-profile
   build no longer fails outright.
2. ✅ `scripts/build.sh`'s Docker invocation no longer goes through `eval`
   (replaced with an array-based `docker "${ARGS[@]}"` call), and every
   script that accepts `$DATASET` now validates it against
   `^[a-zA-Z0-9_-]+$` before it reaches any path construction.
3. ✅ `viewer/viewer.js`'s tileset URLs now point at
   `/tiles/<dataset>/<mode>/small/latest/tileset.json` (matching nginx's
   actual `/tiles/` alias), and `scripts/build.sh` maintains a `latest`
   symlink to the most recent successful build. The no-op `resolveTilesetUrl()`
   was removed.
4. ✅ `scripts/generate-manifest.sh` now writes metrics to a standalone
   `manifests/reports/<build-id>-metrics.json` file instead of appending JSON
   onto the YAML build manifest. `tools/summarize_metrics.py`'s `--manifest`
   flag was renamed to `--output` and no longer opens in append mode.
5. ✅ `scripts/compare-builds.sh` (and `validate.sh`, for consistency) now use
   `find -mindepth 1 -maxdepth 1` so the parent output directory is never
   counted as a build.
6. ✅ `scripts/build.sh`'s config lookup no longer does an ambiguous
   `grep "^  image:"`; `get_config_field()` scopes the lookup to a named
   top-level YAML section (`mago:` vs `java:`).
7. ✅ (plausible-severity) `Makefile`'s `experiment` target now hardcodes
   `implicit` for the final `generate-manifest.sh` call instead of passing
   the overridable `$(MODE)`, matching the steps actually run.
8. ✅ (plausible-severity) `config/nginx.conf` now serves `.subtree` files as
   `application/octet-stream` instead of `application/json` (they're a
   binary format per `tools/inspect_subtree.py`'s decoder).

**Not yet addressed** (tracked, not blocking, lower severity — see DECISIONS.md D7):

- `tools/normalize.py`'s docstring overstates GLB normalization (it only
  hashes GLB files today, no mesh/accessor-level comparison) — matters for
  the Phase 3 determinism claim, since a byte-identical-but-differently-
  serialized GLB would currently register as a false structural difference.
  `tests/run-tests.sh` only exercises `normalize.py` against an empty
  directory, so a regression here wouldn't be caught by CI either.
- `tools/inspect_subtree.py` and `tools/normalize.py` independently
  reimplement the same subtree magic/header parsing and bit-counting logic —
  a fix to one won't propagate to the other. Worth extracting to a shared
  module if it causes an actual divergence, per DECISIONS.md D11.

## Next concrete step

Phase 0 per `docs/test-plan.md`:

1. Pick a specific, versioned PLATEAU release for Sarabetsu Village (更別村)
   from https://www.geospatial.jp/ckan/organization/mlit-plateau and resolve
   every `TBD_VERIFIED_SOURCE_REQUIRED` field in `data/input-manifest.yml` and
   `config/sarabetsu.yml` — dataset identifier, download URL, archive name,
   SHA-256, year, spec version, CityGML version, selected building file(s).
   **Never fabricate these values**; if a value can't be verified yet, leave
   it as `TBD_VERIFIED_SOURCE_REQUIRED` and the scripts will refuse to run
   rather than silently using a wrong value.
2. Resolve `config/common.yml`'s Mago 3DTiler pinning (`jar_url`/`jar_sha256`
   or `image`/`image_digest`) — check the
   [Mago 3DTiler releases](https://github.com/Gaia3D/mago-3d-tiler) for a
   specific tagged version and pin by digest, not `latest`.
3. `make fetch DATASET=sarabetsu` → `make inspect DATASET=sarabetsu`, then
   record source statistics into `config/sarabetsu.yml`'s `source_stats`
   block.
4. Only after that: `make build DATASET=sarabetsu MODE=explicit PROFILE=small`
   (Phase 1, the Explicit baseline) before touching Implicit tiling.

Do not skip ahead to Muroran, to Implicit tiling, or to the "full" profile
before the corresponding smaller phase in `docs/test-plan.md` has actually
produced recorded findings in `docs/findings.md`.

## Where things live

| What | Where |
|---|---|
| Research question, 4 claims | `docs/hypothesis.md` |
| What's in/out of scope | `docs/scope.md`, `docs/limitations.md` |
| Full pipeline diagram | `docs/architecture.md` |
| Step-by-step test procedure | `docs/test-plan.md` |
| Experiment log (fill in as you go) | `docs/findings.md` |
| Per-dataset config (fill in TBDs here) | `config/sarabetsu.yml`, `config/muroran.yml` |
| Tool/converter version pins | `config/common.yml` |
| Orchestration entry point | `Makefile` (`make help` lists targets) |
| Architecture decisions and why | `DECISIONS.md` |
| Agent working conventions | `CLAUDE.md` |

## Open questions for the user

- Which specific PLATEAU dataset year/release should be pinned for Sarabetsu
  and Muroran? (Not yet chosen — this is the actual blocker for Phase 0.)
- Which Mago 3DTiler version should be pinned? `Dockerfile` currently defaults
  `MAGO_VERSION=1.0.0` as an `ARG` but the digest/checksum are still TBD.
