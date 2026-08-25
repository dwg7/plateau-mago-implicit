# Handover

Snapshot of where this experiment stands, for whoever (human or AI agent)
picks it up next. Update this file at the start and end of each significant
work session — it should always answer "what's the state right now and what's
the next concrete step," not narrate history (that's what git log and
`docs/findings.md` are for).

## Status as of 2026-08-25

**Phase 0 complete, Phase 1 complete, Phase 2 substantially complete
(including real browser rendering + real public hosting), Phase 3 formally
complete for the small profile.** This was a single long session that took the project
from "merged scaffolding, never actually run" to "real PLATEAU data,
real Mago 3DTiler output, rendering correctly in a real browser from a
real public host." Almost everything that could plausibly be wrong with
an unverified pipeline WAS wrong, and got found only by actually running
each step — see `docs/findings.md` for the complete evidence trail (exact
commands, byte offsets, error text). **Read it before trusting any claim
about Mago's CLI, CRS handling, subtree format, or CesiumJS behavior.**

## What actually works right now (all verified by running it for real)

- `make fetch` / `make inspect` for both `sarabetsu` and `muroran` — real
  archives, real checksums, real extraction.
- `make build DATASET=sarabetsu MODE=explicit|implicit PROFILE=small` —
  produces correct, geographically-verified 3D Tiles from one real
  building (small_file). Explicit: 2 separate `.glb` files (LOD0/LOD1).
  Implicit: 1 merged content tile + 1 subtree.
- `make compare` / `make validate` — both give trustworthy answers now
  (see "Tooling gaps closed" below).
- **The CesiumJS viewer actually renders real Implicit Tiling output**,
  confirmed in a real browser: `https://dwg7.github.io/plateau-mago-implicit/`
  (GitHub Pages, auto-deployed from `viewer/` on every push) loading a
  real build published to `https://tunnel.optgeo.org/plateau-mago-implicit/`
  (see "Real public hosting" below). This required upgrading CesiumJS from
  1.117 to 1.144 — see "CesiumJS 1.117 bug" below, the single most
  important technical finding of this session.

**Not yet done:** `make build ... PROFILE=full` (whole-municipality, never
attempted); Muroran through the real pipeline (Phase 5 — only a
config-verification spot check was done); Phase 4 (expanded, multi-building
Sarabetsu determinism/concurrency check — Phase 3 so far only used the
single-building small_file); loading Muroran or a multi-building dataset in
the viewer (only ever tested with the single-building small_file).

## The single most important finding: CesiumJS 1.117 cannot render Implicit Tiling at all

Found while trying to view the real published build in the GitHub
Pages viewer: nothing rendered. Debugged live in the browser console —
`tileset.statistics.visited` stayed `0` forever; the root tile's subtree
file was never even requested (confirmed via
`performance.getEntriesByType('resource')`). **Reproduced identically
with the official `CesiumGS/3d-tiles-samples` `1.1/SparseImplicitQuadtree`
reference tileset** (combined-binary `.subtree` format — ruling out our
JSON+bin format as the cause). This is a **CesiumJS defect, not a
PLATEAU/Mago data problem.**

**Fixed by upgrading CesiumJS 1.117 → 1.144** (current latest as of
2026-08-25) in `viewer/index.html`. Immediately after the upgrade, the
same real build rendered correctly: `tileset.statistics` went from
`{visited:0, selected:0}` to `{visited:5, selected:1,
numberOfFeaturesSelected:2, numberOfTrianglesSelected:14}` — exactly
matching the known "1 building, LOD0+LOD1" test data. Not bisected to
find which exact release between 1.117 and 1.144 fixed it (27 releases
apart) — low priority, only useful if this project ever needs to state a
precise minimum-supported-CesiumJS version.

**Mago 3DTiler is already on the latest possible version** — verified
`main` branch HEAD and the `v1.16.2` tag point at the exact same commit
(`ahead_by: 0, behind_by: 0` via the GitHub compare API). No newer
unreleased fixes are being missed.

## Real public hosting: tunnel.optgeo.org

The user's own infrastructure — Raspberry Pi 4B, Caddy + Cloudflare
Tunnel + Martin (Martin serves PMTiles/vector tiles only, unrelated to
this project; our output goes through Caddy's plain static file serving).
**SSH/rsync target is `jaxa.optgeo.org`** (different hostname from the
public HTTPS front `tunnel.optgeo.org` — a Cloudflare Tunnel detail);
files land in `/home/pod/x-24b/data/plateau-mago-implicit/` (a
subdirectory chosen to not collide with the many other large datasets
already in that shared `data/` directory) and are publicly served at
`https://tunnel.optgeo.org/plateau-mago-implicit/...` — **no Caddy config
changes were needed**, the existing config already does open static
file serving with `Access-Control-Allow-Origin: *`.

`scripts/publish.sh` (also `make publish`) does this: dry-run by default,
`--execute` to actually rsync + update a remote `latest` symlink +
record `manifests/reports/published-<build-id>.json`. **Both Sarabetsu
small-profile builds (Explicit and Implicit) are published for real
right now** — verified reachable with correct `Content-Type`/CORS headers
via `curl -I`, and verified rendering in the real GitHub Pages viewer.

Real, currently-live URLs:
- `https://tunnel.optgeo.org/plateau-mago-implicit/sarabetsu/implicit/small/latest/tileset.json`
- `https://tunnel.optgeo.org/plateau-mago-implicit/sarabetsu/explicit/small/latest/tileset.json`

`config/tunnel-optgeo.Caddyfile` (a draft Caddy config with per-extension
MIME/CORS/cache headers) exists in the repo but **was not applied** —
the user confirmed the existing simpler Caddy config already works fine
as-is (generic `file_server`, CORS already `*`). That draft file is now
effectively unnecessary; kept for reference/if the simpler config ever
needs it, but don't assume it's in use.

**(2026-08-25 update) `viewer/viewer.js`'s `VIEWPOINTS` now point the two
published Sarabetsu entries at the real
`https://tunnel.optgeo.org/plateau-mago-implicit/...` URLs**; the two
Muroran entries still point at same-origin `/tiles/...` (only resolve via
`make serve`) since Muroran hasn't been built/published yet — their
dropdown labels now say so explicitly (`viewer/index.html`). Verified for
real: served `viewer/` locally, selected "Sarabetsu Village — Implicit
(small)" from the dropdown, confirmed via
`performance.getEntriesByType('resource')` that it fetched
`tileset.json` from `tunnel.optgeo.org` (not localhost), and confirmed
`tileset.statistics` reached `{visited:5, selected:1}` — the exact
known-good numbers from the Phase 2 CesiumJS 1.144 finding above. Same
check done for "Sarabetsu Village — Explicit (small)": confirmed both
`data/RC0000.glb` and `data/RC1000.glb` were actually fetched from
`tunnel.optgeo.org` and reached `{selected:2, features:2, tris:14,
tilesLoaded:2}` — matching Explicit mode's known 2-content-tile (LOD0 +
LOD1) structure. Not yet re-verified through the actual deployed GitHub
Pages page (only tested against the edited local files) — that requires
committing and pushing first.

## Phase 3 (determinism) is now formally complete for the small profile

Ran the actual `docs/test-plan.md` procedure — two concurrency settings,
not just the earlier single-pair preliminary check: 4 builds (2×
`CONCURRENCY=1`, 2× `CONCURRENCY=4`), 3 pairwise comparisons (1v1, 4v4, and
directly 1v4). All 4 root `tileset.json` files are byte-identical (same
SHA-256); every comparison classifies **L2/PASS**, with the only
difference in each case being the same benign per-run embedded-UUID
`byte-only` difference in the GLB (see the Phase 3 tooling gap above).
Concurrency itself introduced no additional non-determinism. Full run log
and reports: `docs/determinism.md` Results, `docs/findings.md` Phase 3.
**Caveat carried forward to Phase 4:** this only tested one building: a
real multi-building/parallel-write race could behave differently at scale,
so Phase 4 should re-check determinism, not just assume it from this
result.

**Found and fixed in the process:** `scripts/compare-builds.sh` and
`scripts/build.sh`'s `full`-profile branch both used `mapfile` (a bash 4+
builtin). macOS ships bash 3.2 as its default `/bin/bash`; whenever that's
earlier on `PATH` than a newer bash, `#!/usr/bin/env bash` resolves to it
and `mapfile` fails outright with `mapfile: command not found` — this
silently broke `make compare` (and would break `make build ...
PROFILE=full`) on an unmodified macOS `PATH`. Fixed by replacing both with
a portable `while IFS= read -r; do …; done` loop; re-verified `make
compare` succeeds under both plain `/bin/bash` (3.2) and Homebrew's bash 5,
and `make test` still passes.

## Tooling gaps closed this session

Two gaps found while first trying to validate/compare real output, both
fixed and re-verified same day:

1. **Subtree format.** Real mago-3d-tiler 1.16.2 output is a `.json`+`.bin`
   pair (e.g. `subtrees/R/0/0/0.json` referencing `0.bin`), not the
   combined binary `.subtree` format `tools/inspect_subtree.py` and
   `tools/normalize.py` originally only implemented. Both now detect it
   by content shape (presence of `tileAvailability`/etc. keys) alongside
   the original binary decoder. `make validate` now reports real subtree
   counts instead of always "0".
2. **GLB non-determinism.** Mago embeds a fresh random UUID in every
   GLB's `EXT_structural_metadata` on each run (in an `id` property,
   *not* the source `gml:id` — the source `gml:id` is not retained at
   all). This caused a real, reproducible false-negative determinism
   result. `tools/normalize.py` now redacts UUID-shaped property values
   (detected generically via the property table) before hashing GLB
   content; `tools/compare_manifests.py` prefers that normalized hash.
   Re-running the same two-build pair: L3/FAIL → **L2/PASS**.

Also fixed while in the area: `scripts/validate.sh` wasn't gating on the
validator's own `numErrors` — it printed "VALIDATION PASSED" over a real
`METADATA_INVALID_LENGTH` finding. Now correctly fails on it.

## The `METADATA_INVALID_LENGTH` validator finding — status: genuinely ambiguous, not "confirmed Mago bug"

`3d-tiles-validator` flags `BatchId`/`FileName` structural-metadata
property buffer views as having the wrong byte length. Decoded by hand:
every flagged bufferView's declared `byteLength` exceeds its
`stringOffsets`-derived content length by exactly enough to round up to
4-byte alignment (e.g. content ends at byte 50, declared length 52) — the
standard "pad binary buffers to 4-byte alignment" pattern, not obviously
a content bug. Whether `EXT_structural_metadata`'s spec permits this
padding or requires exact-length bufferViews has **not been checked
against the normative spec text**. Don't report this upstream as a
confirmed bug until that's resolved either way.

## All prior pipeline bugs (found + fixed, for reference — full detail in git log / docs/findings.md)

Every one of these made the pipeline, as originally merged in PR #1,
either crash immediately or silently do the wrong thing. All fixed and
re-verified against real data:

- Nonexistent Mago CLI flags (`--outputType 3dtiles`, `--tileType
  implicit`, `--thread`) — crashed every single build, both modes.
- Mago requires `--input` to be writable, not `:ro`.
- `--crs <EPSG code>` silently produces wrong coordinates (axis-order
  mismatch); fixed with an explicit `--proj ... +axis=neu`.
- "small" profile was silently building the entire municipality (Mago's
  `--input` is a directory, not a file); fixed with an isolated staging
  directory per build.
- No public Docker image for Mago on GHCR (one does exist on Docker Hub,
  not used — JAR-based local build already verified working).
- Muroran's `small_file`/`small_files` key mismatch, `eval`-based Docker
  injection risk, viewer tileset URL mismatch, YAML/JSON manifest
  corruption, a `compare-builds.sh` off-by-one, an ambiguous
  `config/common.yml` grep, a `Makefile` MODE mismatch, `.subtree`
  Content-Type — all from the PR #1 code review, fixed same day.
- Sarabetsu Village's municipality code was wrong (`01643`, actually
  Makubetsu Town's code — corrected to `01639`).

## Next concrete step

1. ~~Point `viewer/viewer.js`'s `VIEWPOINTS` at the real
   `https://tunnel.optgeo.org/plateau-mago-implicit/...` URLs~~ **Done
   2026-08-25** — see "Real public hosting" above for verification detail.
   Not yet committed/pushed, so the live GitHub Pages page doesn't have
   this change yet.
2. ~~Run the formal Phase 3 procedure (two concurrency settings, full
   `docs/determinism.md` classification, a proper run log)~~ **Done
   2026-08-25** — see "Phase 3 (determinism) is now formally complete"
   above. L2/PASS confirmed at both concurrency settings and across them,
   for the single-building small profile.
3. Complete Phase 2's remaining checklist items: geometric-error/hierarchy
   comparison against `docs/test-plan.md`'s full checklist (feature-count
   reconciliation is already done).
4. Resolve the `METADATA_INVALID_LENGTH` ambiguity against
   `EXT_structural_metadata`'s actual spec text before deciding whether
   to report it upstream.
5. Only after Phase 1–4 fully complete for Sarabetsu: start Phase 5
   (Muroran) for real.

Uncommitted local changes this session: `viewer/viewer.js`,
`viewer/index.html` (Sarabetsu VIEWPOINTS → real tunnel.optgeo.org URLs),
`scripts/compare-builds.sh`, `scripts/build.sh` (mapfile → portable loop),
`docs/determinism.md`, `docs/findings.md`, this file. Not committed yet —
ask the user before committing/pushing (pushing is what makes the GitHub
Pages viewer pick up the VIEWPOINTS change).

Lower-priority, tracked but not blocking:

- Pin `validators.tiles_validator_version` for real (recorded in config,
  not actually read by `scripts/validate.sh`).
- `tools/inspect_subtree.py`/`tools/normalize.py` still duplicate
  subtree-parsing logic across two files.
- `config/common.yml`'s `tiling.subtree_levels: 3` isn't wired into
  `scripts/build.sh` (Mago's default of 4 is always used).
- Optionally bisect which CesiumJS release between 1.117 and 1.144 fixed
  the implicit-tiling bug.

## Where things live

| What | Where |
|---|---|
| Research question, 4 claims, current status | `docs/hypothesis.md` |
| What's in/out of scope | `docs/scope.md`, `docs/limitations.md` |
| Full pipeline diagram, CRS notes | `docs/architecture.md` |
| **Experiment log — the authoritative, evidence-based record** | `docs/findings.md` |
| Resolved dataset config (real values, not TBD) | `config/sarabetsu.yml`, `config/muroran.yml` |
| Tool/converter version pins (real) | `config/common.yml` |
| Tile hosting plan + real publish mechanism | `docs/tile-hosting-plan.md`, `scripts/publish.sh` |
| Orchestration entry point | `Makefile` (`make help`) |
| Real inspection/build/publish evidence | `manifests/{reports,builds}/*` |
| Architecture decisions and why (D1–D19+) | `DECISIONS.md` |
| Agent working conventions | `CLAUDE.md` |
| Live GitHub Pages viewer | https://dwg7.github.io/plateau-mago-implicit/ |
| Live published tiles | https://tunnel.optgeo.org/plateau-mago-implicit/ |

## Open questions for the user

- None blocking. Everything above is technical follow-through, not a
  pending decision.
- Worth a decision eventually, not urgent: switch to the Docker Hub
  `gaia3d/mago-3d-tiler` public image instead of the local JAR build? The
  JAR path already works and is arguably more transparent.
