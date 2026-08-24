# Handover

Snapshot of where this experiment stands, for whoever (human or AI agent)
picks it up next. Update this file at the start and end of each significant
work session — it should always answer "what's the state right now and what's
the next concrete step," not narrate history (that's what git log and
`docs/findings.md` are for).

## Status as of 2026-08-25

**Phase: 1 complete, 2 partially complete, 3 preliminary-only.** Real
progress, not scaffolding: real PLATEAU data downloaded and inspected for
both municipalities, a real Mago 3DTiler 1.16.2 image built and pinned by
JAR SHA-256, and — critically — the pipeline was actually run end-to-end
against real data, which surfaced and fixed several build-breaking bugs
that made the merged PR's pipeline **never actually work, in either
Explicit or Implicit mode, for any dataset.** See `docs/findings.md` for
the full evidence-based record; this file is the fast-orientation summary.

**Read `docs/findings.md` before trusting anything about Mago behavior,
CRS handling, or subtree format** — it has exact commands, byte offsets,
and error messages, not just conclusions.

## What actually works right now (verified by running it, not by reading code)

- `make fetch DATASET=sarabetsu` / `muroran` — real archives downloaded,
  checksums verified by the script itself.
- `make inspect DATASET=sarabetsu` / `muroran` — real extraction (Sarabetsu
  decompresses to ~21 GB on disk) and `tools/inspect_citygml.py` run,
  producing `manifests/reports/inspect-{sarabetsu,muroran}.json`. Building
  counts cross-checked against each archive's own README and matched
  closely (exact match for Muroran: 55,906).
- `make build DATASET=sarabetsu MODE=explicit PROFILE=small` — produces
  correct, geographically-verified Explicit 3D Tiles from one real
  building.
- `make build DATASET=sarabetsu MODE=implicit PROFILE=small` — produces
  correct, geographically-verified Implicit 3D Tiles (subtree available,
  content tile available) from the same building.
- `make compare DATASET=sarabetsu MODE=implicit PROFILE=small` (after two
  builds) — runs for real, produces a real (if currently misleading —
  see below) determinism verdict.
- `make validate DATASET=sarabetsu MODE=implicit PROFILE=small` — runs the
  real `3d-tiles-validator` via `npx` (auto-installs), which found real
  errors in Mago's own GLB metadata.
- The `server` (nginx) compose service, started for real: a real build's
  `tileset.json` is reachable at exactly the URL `viewer/viewer.js`
  requests, and `.subtree`-path Content-Type is correct.

**Not yet exercised for real:** the CesiumJS viewer in an actual browser;
`make build ... PROFILE=full` (whole-municipality); Muroran through the
real pipeline (Phase 5 hasn't formally started — only a config-verification
spot check was done); `make experiment` end-to-end.

## Critical bugs found and fixed by actually running the pipeline (2026-08-24/25)

The PR #1 code review (see below) found bugs by reading the code. These
were found by **running mago-3d-tiler for real** and reading its actual
error output — none of them were visible from source alone:

1. **`--outputType 3dtiles` and `--tileType implicit` are not real Mago CLI
   flags.** Confirmed by triggering
   `UnrecognizedOptionException: Unrecognized option: --tileType` (and
   separately for `--thread`, also fake — real flag is
   `--multiThreadCount`). **This means the pipeline, as merged, crashed on
   every single `make build` invocation, in both modes, for both
   datasets.** Fixed: real flags are `--tilingMode implicit|explicit`
   (default explicit, no flag needed) and no `--outputType` needed for
   CityGML input (defaults to b3dm).
2. **Mago requires the `--input` directory to be writable**, not `:ro`.
   Fixed by dropping `:ro` from `scripts/build.sh`'s Docker mount.
3. **`--crs <EPSG code>` (tried 6697, 6668, 4326) silently produces WRONG
   coordinates** — building placed off the California coast instead of in
   Hokkaido. Root cause: PLATEAU's `gml:pos` axis order is (lat, lon,
   height); `--crs` assumes (lon, lat). Fixed with an explicit `--proj
   "+proj=longlat +datum=WGS84 +axis=neu +no_defs"`, now in
   `config/{sarabetsu,muroran}.yml`'s `crs.mago_proj` field, verified
   correct for both datasets' small_file.
4. **The `small` profile was building the ENTIRE municipality**, not just
   the one selected file — Mago's `--input` takes a directory and converts
   everything in it, and `scripts/build.sh` was mounting the small file's
   whole parent directory (100–190 other files). Fixed: the single file is
   now staged in an isolated `data/.build-staging/<dataset>/<build-id>/`
   directory before mounting.
5. **No public Docker image for Mago 3DTiler exists on GHCR** — confirmed
   `ghcr.io/gaia3d/mago-3d-tiler` doesn't exist, so `config/common.yml`'s
   original `mago.image`/`image_digest` fields were unfillable.
   `scripts/build.sh` now builds a local image from the pinned JAR
   (`mago.version`/`jar_url`/`jar_sha256`) via the existing `Dockerfile`,
   verified end-to-end including the Dockerfile's own independent
   `sha256sum --check --strict`. **Correction:** a public image DOES exist
   on Docker Hub (`docker.io/gaia3d/mago-3d-tiler`) — not switching to it
   since the JAR path is already verified working, but worth knowing it's
   an option.

Plus the 6 bugs + 2 lower-severity ones found in the PR #1 code review and
fixed the same day (commits `a046e8c`..`e07f092`): Muroran's
`small_file`/`small_files` key mismatch, the `eval`-based Docker
injection risk (fixed via array-based invocation + a `DATASET` allowlist
on every script), viewer tileset URL mismatch (fixed via a `latest`
symlink), YAML/JSON manifest corruption (fixed via a separate metrics
file), a `compare-builds.sh` off-by-one, an ambiguous `config/common.yml`
grep, a `Makefile` MODE mismatch, and the `.subtree` Content-Type.

Also fixed: **Sarabetsu Village's municipality code was wrong** (`01643`,
actually Makubetsu Town's code — corrected to `01639`, verified against
Wikipedia and the PLATEAU catalog itself).

## Real findings worth knowing before continuing (full detail: docs/findings.md)

- **Both datasets use EPSG:6697 (JGD2011 geographic 3D)**, not the Plane
  Rectangular CS `docs/architecture.md` originally assumed (now corrected).
- **Real Implicit subtree output is `.json`+`.bin`, not the combined
  binary `.subtree` format** `tools/inspect_subtree.py`/`tools/normalize.py`
  implement. Verified: `make validate` reports "Subtree files: 0" against
  real output. **This is the single highest-priority tooling gap** —
  Phase 2's validation criteria and all of Phase 3's determinism tooling
  are currently running against zero real subtree data.
- **A random UUID is embedded in every GLB's structural metadata** by Mago
  on each run, causing a real, reproducible false-negative determinism
  result (`compare-builds.sh` reported L3/FAIL between two builds whose
  `tileset.json` and subtree were byte-identical — only this one embedded
  string differed, confirmed via `cmp -l` + hex dump).
  `docs/determinism.md` already anticipated this exact class of difference
  as normalizable; `tools/normalize.py` doesn't yet redact it.
- **`3d-tiles-validator` (unpinned, v0.6.1 as installed) found real
  `METADATA_INVALID_LENGTH` errors** in Mago's GLB output
  (`BatchId`/`FileName` properties) — `scripts/validate.sh` prints
  "VALIDATION PASSED" regardless, since it doesn't gate on the validator's
  own `numErrors` field (a real, minor, not-yet-fixed bug).
- Sarabetsu's archive (1.1 GB) is bigger than Muroran's (238 MB) —
  contradicts `docs/data-selection.md`'s original size-based rationale for
  picking Sarabetsu first (building count is still smaller, which is what
  actually matters for Phase 1–4; the doc's stated cost reasoning was
  wrong, now noted in `docs/findings.md`).

## Next concrete step

Priority order:

1. **↓ Fix `tools/normalize.py` to redact the embedded UUID from GLB
   content before hashing** (same idea as its existing JSON timestamp
   redaction), then re-run the two-build comparison. This is small,
   well-understood (exact byte pattern already known — see
   `docs/findings.md` Phase 3), and unblocks a trustworthy determinism
   read.
2. **↓ Extend `tools/inspect_subtree.py`/`tools/normalize.py` to handle the
   real JSON+BIN subtree pair**, not just the combined binary format. This
   is the bigger of the two tooling gaps.
3. Complete Phase 2's remaining checklist items (Explicit-vs-Implicit
   comparison: feature counts, hierarchy, `gml:id`s) once #2 unblocks real
   subtree inspection.
4. Run the formal Phase 3 procedure (two concurrency settings, full
   docs/determinism.md classification) once #1 is done — the current L3
   result is believed to be a tooling false-negative, not proof of real
   Mago non-determinism, but that needs confirming properly.
5. Actually load a real build in the CesiumJS viewer via `make serve` and
   a real browser — not yet done.
6. Only after Phase 1–4 fully complete for Sarabetsu: start Phase 5
   (Muroran) for real (a CRS spot-check was done during Phase 0 config
   setup, but that's not a Phase 5 run).

Lower-priority, tracked but not blocking:

- `scripts/validate.sh` should fail (not print "VALIDATION PASSED") when
  the validator's JSON has `numErrors > 0`.
- Pin `validators.tiles_validator_version` for real — `scripts/validate.sh`
  currently ignores that config field and lets `npx` install whatever's
  current.
- `tools/inspect_subtree.py` and `tools/normalize.py` still duplicate
  subtree-parsing logic (PR #1 review finding, not yet addressed).
- `config/common.yml`'s `tiling.subtree_levels: 3` is not wired into
  `scripts/build.sh` (`--implicitSubtreeLevels` is never passed); Mago's
  default of 4 is used regardless of what's configured.

## Where things live

| What | Where |
|---|---|
| Research question, 4 claims | `docs/hypothesis.md` |
| What's in/out of scope | `docs/scope.md`, `docs/limitations.md` |
| Full pipeline diagram, CRS notes | `docs/architecture.md` |
| Step-by-step test procedure | `docs/test-plan.md` |
| **Experiment log — the authoritative record** | `docs/findings.md` |
| Resolved dataset config (real values, not TBD) | `config/sarabetsu.yml`, `config/muroran.yml` |
| Tool/converter version pins (real) | `config/common.yml` |
| Orchestration entry point | `Makefile` (`make help` lists targets) |
| Real inspection reports | `manifests/reports/inspect-{sarabetsu,muroran}.json` |
| Real build manifests | `manifests/builds/*.yml` |
| Architecture decisions and why | `DECISIONS.md` |
| Agent working conventions | `CLAUDE.md` |

## Open questions for the user

- None blocking right now — Phase 0 is fully resolved for both
  municipalities and Phase 1 is complete. The next steps above are
  technical follow-through, not open decisions.
- Worth a decision eventually: should the Docker Hub
  `gaia3d/mago-3d-tiler` public image replace the local JAR-based build
  for simplicity, now that it's confirmed to exist? Not urgent — the
  current approach works and is arguably more transparent/reproducible.
