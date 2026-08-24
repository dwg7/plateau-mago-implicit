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

CI is green (fixture tests, shellcheck, flake8, YAML validation, doc checks —
all pass on `main`). Green CI here means the *scaffolding* is sound; it does
**not** mean the pipeline works end-to-end, because none of the CI jobs
actually run `make build`/`make experiment` against real data (that needs
Docker + network access CI doesn't have).

## Known bugs to fix before trusting the pipeline

Found during review of PR #1 (see that PR's review comments, or re-run
`/code-review` against the merge commit for full detail). Fix at least the
first two before starting Phase 0 for Muroran or before running anything
through `eval`-based `build.sh`:

1. **Muroran's small-profile build is broken.** `config/muroran.yml` defines
   `small_files:` (plural) but `scripts/build.sh` looks for `small_file:`
   (singular). Fix the key name mismatch in one of the two places before
   running `make build DATASET=muroran PROFILE=small`.
2. **`scripts/build.sh` uses `eval` on a Docker command string built from
   unsanitized `$DATASET`.** Add a `DATASET` allowlist check
   (`sarabetsu|muroran`, or read valid names from `config/`) near the top of
   every script that accepts it as an argument, and consider replacing the
   `eval "$DOCKER_CMD"` pattern with a plain array-based `docker run "${ARGS[@]}"`
   invocation so quoting can't be broken.
3. **The CesiumJS viewer's hardcoded tileset URLs don't match real build
   output** (missing the timestamped `BUILD_ID` path segment; also doesn't
   match nginx's `/tiles/` serving path). Fix `viewer/viewer.js` — or better,
   generate `VIEWPOINTS` from a manifest/config file instead of hand-coding
   URLs — before relying on `make serve` + the dropdown to view anything.
4. **`scripts/generate-manifest.sh` corrupts the build manifest.** It appends
   raw JSON (via `tools/summarize_metrics.py --manifest`) onto a file that
   `scripts/build.sh` already wrote as YAML. Either write metrics to a
   separate file, or make `summarize_metrics.py` merge into valid YAML.
5. **`scripts/compare-builds.sh` can silently compare a directory against
   itself** when only one real build exists, because its `find -maxdepth 1`
   listing includes the parent output directory. Exclude the base directory
   explicitly (e.g. `-mindepth 1 -maxdepth 1`).
6. **`scripts/build.sh`'s `grep "^  image:"` is ambiguous** — it matches both
   `mago.image:` and `java.image:` in `config/common.yml` and only picks the
   right one because of section ordering. Make the grep pattern more specific
   (e.g. grep within the `mago:` block only) before reordering that file.

Lower-priority, worth fixing but not blocking: `tools/normalize.py`'s
docstring overstates GLB normalization (it only hashes GLB files today, no
mesh/accessor-level comparison) — this matters for the Phase 3 determinism
claim specifically, since a byte-identical-but-differently-serialized GLB
would currently register as a false structural difference. `config/nginx.conf`
labels `.subtree` files (a binary format) as `application/json`.

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
3. Fix bug #1 and #2 above (they block Muroran and are a correctness/security
   issue respectively even for Sarabetsu-only work).
4. `make fetch DATASET=sarabetsu` → `make inspect DATASET=sarabetsu`, then
   record source statistics into `config/sarabetsu.yml`'s `source_stats`
   block.
5. Only after that: `make build DATASET=sarabetsu MODE=explicit PROFILE=small`
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
- Should the 6 known bugs above be fixed in one follow-up PR before Phase 0
  starts, or fixed incrementally as each one is actually hit?
