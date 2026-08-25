# Handover

Snapshot of where this experiment stands, for whoever (human or AI agent)
picks it up next. Update this file at the start and end of each significant
work session — it should always answer "what's the state right now and what's
the next concrete step," not narrate history (that's what git log and
`docs/findings.md` are for).

## Status as of 2026-08-25

**Phases 0–6 all run for real against both municipalities.** Phase 4
(full-profile Sarabetsu) found the session's biggest finding: determinism
fails at full scale even though it holds at small scale. Phase 5 (small
Muroran) confirmed small-profile determinism holds regardless of
municipality and found a real structural tile-refinement difference
driven by Muroran's LOD1-only source data. **Phase 6 (full-profile
Muroran) confirms Phase 4's determinism failure generalizes beyond
Sarabetsu, and refines the root cause** — Muroran shows no single
"problem file" the way Sarabetsu did, pointing instead at batching
multiple buildings into one content tile as the real source of
non-determinism, with a concurrency-dependent hint (more threads, more
affected tiles) not yet confirmed at more than n=1. This was a
single long session that took the project
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

**(2026-08-25 update, post-push) Re-verified against the real deployed
GitHub Pages page — no site errors, but a testing-tool caveat worth
recording.** `gh run watch`/`gh run view` confirmed both the CI and
"Deploy viewer to GitHub Pages" workflows succeeded. On the live page:
console had zero errors/warnings throughout; `tileset.json`, the subtree
JSON, and the content GLB all fetched successfully (200, correct
content/CORS) via direct `fetch()`; a manually-instantiated
`Cesium3DTileset` against the live `tunnel.optgeo.org` tileset correctly
traversed the implicit quadtree down to the exact expected leaf
(`level=3, x=4, y=2`). **Could not get a manually-driven
`Cesium3DTileset.statistics.selected` to go above 0 for the *remote*
host inside this session's automated browser pane** — root-caused to
`document.visibilityState: "hidden"` (confirmed directly), which Chrome
uses to pause `requestAnimationFrame` and deprioritize non-loopback
network requests for backgrounded tabs; the same code against `localhost`
in the same tool, same session, worked immediately (`selected:1`,
`tris:14`), which is consistent with loopback requests not being subject
to that bandwidth-saving throttling. This is a limitation of testing
through this specific automated browser tool while its pane isn't the
visible/focused tab — not a defect in the deployed site. (Claude in
Chrome, a real Chrome instance, was tried as an independent check but its
extension wasn't connected in this session.) **Takeaway for future
verification:** if a Claude Code session needs to re-confirm real-host
content actually renders (not just traverses) via this browser tool,
either keep the pane genuinely focused/visible throughout, or treat a
localhost re-test as sufficient corroboration — don't read a stuck
`selected:0` against a remote host as a site regression without first
checking `document.visibilityState`.

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

## Phase 2's remaining comparison item (hierarchy/geometric error) is done

Completed the last open `docs/test-plan.md` Phase 2 comparison item.
Explicit's tree: root has no content, 2 sibling LOD branches (not a
coarse-to-fine chain), each refining through 4 levels with an identical
`120.01 → 50.01 → 8.01 → 0.01` geometricError sequence, bounding volumes
tightly fit to each LOD's real geometry. Implicit's tree: only root
geometricError (`64.0`) is stored; per-level values are client-computed;
one subtree file marks exactly the 4-tile ancestor path to its single
populated leaf as available; bounding volumes come from uniform quadtree
subdivision, not per-LOD geometry fitting. Full writeup:
`docs/findings.md` Phase 2 Confirmed.

**Found and corrected while doing this:** `docs/findings.md` and (by
inference) the RC0000/RC1000 LOD labeling had the mapping backwards —
`RC0000.glb` was documented as LOD0, `RC1000.glb` as LOD1, a guess from
the numeric filename prefix that was never checked against the mesh
itself. Decoding both GLBs' `POSITION` accessor bounds: `RC0000.glb` has
real vertical extent (2 local units), `RC1000.glb` is flat (Z ≈ 0).
Cross-checked against `docs/information-retention.md`'s independent
`bldg:measuredHeight = 2` (metres) finding — matches `RC0000.glb` exactly.
**Corrected: `RC0000.glb` = LOD1 (solid), `RC1000.glb` = LOD0 (footprint).**

**Also found and fixed:** two real bugs in `tools/inspect_subtree.py` and
`tools/normalize.py`, surfaced while decoding the Implicit subtree for
this comparison. Both tools read `subtreeLevels` from the *subtree file's
own* JSON header, but real mago-3d-tiler subtree files never declare that
key (it's inherited from tileset.json's `implicitTiling` block per spec)
— this silently defaulted to 1, undercounting availability. The earlier
session's "tiles=1 content=0 children=0" claim (see "Tooling gaps closed"
below) was **wrong**; hand-decoded against the raw bitstream, the correct
values are **tiles=4, content=1, children=0**. `tools/normalize.py` had a
second bug: it never handled `contentAvailability` as a JSON array (real
mago output uses a one-element list), crashing and silently recording an
opaque `"error"` string in every normalized manifest generated so far.
Both fixed (new shared `find_subtree_levels()` helper reads from
tileset.json instead; list-handling copied from `inspect_subtree.py`,
which already had it right). All four Phase 3 normalized manifests and
their 3 comparison reports regenerated — determinism verdict unchanged
(still L2/PASS in all three). Also had to add `from __future__ import
annotations` to both files: a new top-level function's `int | None`
annotation crashed at import time on this environment's Python 3.9 (no
minimum Python version is pinned anywhere in this repo). Full detail:
`docs/findings.md` Phase 2.

## Fixed and user-confirmed: viewer camera pointed 14km/2.7km away from the actual building

**Reported directly by the user** (2026-08-25, after the tunnel.optgeo.org
push): the live GitHub Pages page loaded with no error, but no building
was ever visible. Root cause: `viewer/viewer.js`'s `VIEWPOINTS.destination`
coordinates were a rough municipality-center guess ((143.1, 42.6) for
Sarabetsu, (141.0, 42.3) for Muroran) left over from before this session
established the small_file building's actual coordinates — computed the
real distance and got **14.2 km** (Sarabetsu) / **2.7 km** (Muroran) from
where the camera was actually looking to where the (tiny, ~77 m bounding
sphere) building actually is. At the previous 5000–8000 m altitude with a
45° downward pitch, the building was never inside the camera's frustum.
Not a tileset, publish, or CesiumJS defect — the underlying data was
already confirmed working correctly earlier in this session (direct
`fetch()` checks and manual `Cesium3DTileset` traversal both succeeded
against the real host). Fixed by pointing `destination` at each dataset's
real verified coordinates, 300 m altitude, straight nadir (`pitch: -90`,
chosen specifically so the tiny building can't fall outside frame from a
forward-look offset error like this one). Not independently re-confirmed
by live rendering in this session's automated browser tool (blocked by
the same `document.visibilityState: "hidden"` throttling documented
above), but **the user reloaded the live GitHub Pages page in their own
browser and confirmed the single building is now visible** — real,
human-verified confirmation, not just the coordinate-math argument. Full
detail: `docs/findings.md` Phase 2 Unexpected findings.

## Phase 4 (full-profile Sarabetsu): determinism fails at scale — the session's biggest finding

Ran the full formal `docs/determinism.md` procedure again, this time at
full profile (all 187 building files, 6,795 buildings) instead of the
single-building small_file. **Result flips from L2/PASS to L3/FAIL at
both concurrency settings tested (1 and 4).** Two builds of byte-identical
input produced real geometry (vertex/index) differences in specific
content tiles, and one comparison found a content tile
(`data/R/5/13/12.glb`) present in one build and completely missing from
the other. Not diffuse noise: every affected tile across both comparisons
shares one common source file — `63437175_bldg_6697_op.gml`, 15.3 MB, 826
buildings in one file (the small_file used for Phase 1–3 was 8,455 bytes,
1 building). This is a real, reproducible, root-caused non-determinism in
Mago 3DTiler 1.16.2 — a much stronger upstream candidate than
`METADATA_INVALID_LENGTH`'s spec ambiguity, since this one isn't a
validator-strictness question: the same input produced different output.

**Also fixed before running any full-profile build:**
`scripts/build.sh`'s full-profile branch searched `find $SOURCE_DIR -name
"*.gml"` across the *whole* source tree, not `udx/bldg/` specifically. A
real PLATEAU package also has `udx/dem`/`frn`/`luse`/`tran`/`veg`
(terrain, street furniture, land use, roads, vegetation) — unscoped, this
would have fed ~1,123 non-building files into Mago, directly crossing
CLAUDE.md's buildings-only scope boundary. Caught by inspecting the
extracted source tree before running anything; fixed to scope to
`udx/bldg/`.

Both full-profile builds (Explicit: 202 tile contents, 31s; Implicit: 804
tile contents, 31s) otherwise succeeded structurally, and the
`METADATA_INVALID_LENGTH` alignment-padding pattern (see above) holds
consistently across 1439 combined instances at full scale — strengthening
that finding's "benign padding" reading. Full detail, exact byte offsets,
and the source-file isolation method: `docs/findings.md` Phase 4,
`docs/determinism.md` Results.

## Phase 5 (small Muroran) run for real

Repeated Phase 1–3's small-profile procedure on Muroran's small_file
(`63403767_bldg_6697_op.gml`) instead of Sarabetsu's — this supersedes
the earlier Phase 0 config-only spot check. Both modes convert correctly;
geographic placement matches the known-correct coordinates exactly
(140.9694°E/42.3076°N), and the output height range (4.213 m) closely
matches the source's declared `bldg:measuredHeight` (4.6 m). Formal
determinism check (4 builds, 2 concurrency settings, same procedure as
Phase 3/4): **L2/PASS at both settings** — a useful cross-check on Phase
4's finding, since it confirms small-profile determinism holds regardless
of *which* municipality's single building is used, reinforcing that
Phase 4's L3/FAIL was specifically about processing many buildings from
one large source file, not something Sarabetsu-specific.

**Real structural finding, not a bug:** Muroran's Explicit tree looks
different from Sarabetsu's — one branch with byte-identical geometry at
two refinement depths, instead of Sarabetsu's two sibling branches with
genuinely different LOD0/LOD1 geometry. Traced to the source data:
Muroran's PLATEAU dataset is LOD1-only (confirmed back in Phase 0), so
Mago has only one real geometry to place and duplicates it across its own
internal refinement chain rather than expressing a second LOD. Same
converter, same mode, structurally different output — driven by what LODs
the source actually contains, exactly the kind of "Special attention:
Tile refinement" finding `docs/test-plan.md` names as Phase 5's purpose.
Full detail: `docs/findings.md` Phase 5.

## Phase 6 (full-profile Muroran): confirms Phase 4 generalizes, refines the root cause

Ran the exact Phase 4 procedure on Muroran's full profile (55,906
buildings, 100 files, 485 MB — bigger on disk than Sarabetsu's full
profile despite ~8× fewer buildings). Both modes convert correctly
(Explicit: 1259 tile contents, 83s; Implicit: 553 tile contents, 78s).
**Determinism fails again, at both concurrency settings** (L3/FAIL for
concurrency=1 vs 1, and 4 vs 4), confirming Phase 4's finding isn't
Sarabetsu-specific.

**But the failure shape is different, which matters:** Sarabetsu's
non-determinism traced cleanly to one dominant 826-building source file.
Muroran has no comparable outlier (its 100 files are much more uniform in
size), and decoding the `FileName` values in all 5 concurrency=1
geometry-affected tiles found **no single file common to all of them** —
each affected tile batches a different, partially-overlapping set of
building files. This rules out "one specific file has a defect" as the
general explanation and points instead at **batching multiple buildings
into one content tile's mesh** (whatever merge/triangulation step that
involves) as where the non-determinism actually lives, independent of
municipality or source file. Also notable: the concurrency=4 pair showed
5× as many affected tiles as the concurrency=1 pair (25 vs 5) — a real
hint that thread-level ordering contributes on top of a baseline
non-determinism present even single-threaded, but this is one comparison
at each setting, not a confirmed effect size (would need repeated trials
to establish). `METADATA_INVALID_LENGTH`'s alignment-padding pattern
continues to hold with zero outliers, now across 4097 combined instances
spanning both municipalities and both scales. Full detail:
`docs/findings.md` Phase 6, `docs/determinism.md` Results.

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

**All of Phases 0–6 are now done for real, for both municipalities.**
This session's commits, in order: viewer VIEWPOINTS repointed at real
`tunnel.optgeo.org` URLs + formal Phase 3 small-profile determinism
(`53075b4`); Phase 2 hierarchy/geometric-error comparison + LOD↔filename
correction + subtree-tooling bugfixes (`92c9f7d`); GitHub Pages
re-verification notes (`77a0c01`); `METADATA_INVALID_LENGTH` spec check +
the 14km/2.7km viewer camera-target bug fix (`1817ddc`); user-confirmed
the camera fix actually works (`d0eee89`); Phase 4 full-profile
Sarabetsu, this session's biggest finding — determinism fails at scale
(`214c74e`); Phase 5 small Muroran (`531bdce`). **Phase 6 (full-profile
Muroran) is done but not yet committed** — see above for the finding
itself.

The user explicitly said an upstream Mago 3DTiler report is not
necessarily the goal, so that's optional future work only, not a next
step.

Immediate next steps:

1. Commit and push Phase 6's work: `docs/findings.md`/
   `docs/determinism.md`/`docs/hypothesis.md` (Phase 6 findings +
   Claim 2 status now covering both municipalities), this file, plus the
   new Muroran full-profile build/normalized/comparison/validation
   manifests under `manifests/`.
2. Only real remaining measurement gap from `docs/test-plan.md`'s Phase
   4/6 lists: peak process memory, first-useful-render time, initial
   request count/bytes, navigation responsiveness, geographic-jump
   convergence, and browser long-session memory trend — none measured
   this session (needs either `docker stats` monitoring during a build or
   live interactive browser testing this session's automated tooling
   couldn't reliably do).
3. The concurrency=1-vs-4 affected-tile-count asymmetry found in Phase 6
   (5 vs 25) is currently a single-comparison hint, not a confirmed
   effect — repeating that comparison a few more times at each setting
   would turn it into an actual finding instead of a "worth watching"
   note.
4. Phase 7 (optional higher-detail/LOD2+/texture tests) remains untouched
   and explicitly optional per `docs/scope.md` — the only phase not yet
   run in some form.

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
