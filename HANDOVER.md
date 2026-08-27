# Handover

Snapshot of where this experiment stands, for whoever (human or AI agent)
picks it up next. Update this file at the start and end of each significant
work session — it should always answer "what's the state right now and what's
the next concrete step," not narrate history (that's what git log and
`docs/findings.md` are for).

## Status as of 2026-08-25/26/27

**2026-08-27, updated end-of-session:** found and fixed a real
vertical-datum bug — PLATEAU buildings were rendering 28-34m buried below
the newly-added real terrain; root-caused, fixed with a new
`japan-geoid`-based build step, rebuilt and republished all 4 full-profile
combinations (see "Real elevation added" below). Once the user could
actually see the live site, a run of real, user-reported issues followed,
all found, fixed, and pushed the same session:
- Blurry imagery → the tileset in use (`kitaphoto`) was a deliberately
  downsampled, z12-capped derivative; switched to `seamlessphoto512`
  (real per-level data to z17).
- `seamlessphoto512` alone showed GSI's raw multi-survey patchwork at low
  zoom (visible seams, inconsistent) → built **`kitaphoto17.pmtiles`**, a
  custom-merged basemap (kitaphoto's smooth low-zoom + seamlessphoto512's
  real high-zoom, Hokkaido+Northern-Territories-scoped) after `go-pmtiles
  extract` repeatedly OOM'd on the target host; see "kitaphoto17" below
  for the full build story.
- Buildings looked dark against real photography → styled off-white, but
  the first attempt silently did nothing because `Cesium3DTileset`'s
  `colorBlendMode` defaults to multiply (`HIGHLIGHT`), not replace — fixed
  by setting `colorBlendMode = REPLACE`.
- Roof/wall shimmer on a large building → investigated (duplicate
  geometry ruled out via direct GLB decode: only 2/21,794 triangles were
  true duplicates), traced to CesiumJS's logarithmic depth buffer per
  Cesium's own engineering blog; mitigated with
  `logarithmicDepthFarToNearRatio = 1e5`.
- Added a MapLibre-style URL hash (dataset + camera pose) for
  bookmarking/sharing a view.

**All of the above is committed and pushed** (`b1a4e59` through `921083a`
on `main`). **None of it has been visually reconfirmed by the user yet**
— same `document.visibilityState: "hidden"` limitation as always; a real
attempt this session to break through it (manual `scene.render()` pumping
after `camera.setView()`) sometimes worked but was non-deterministic, so
it wasn't relied on for anything visual, only used for a separate
practical-consumption measurement attempt (also abandoned as unreliable —
see `docs/findings.md`).

Also done this session: a full Implicit-vs-Explicit structural/size
comparison at full profile, at the user's direct request — recorded in
`docs/findings.md` "Cross-phase follow-up: does Implicit actually show a
benefit over Explicit?". Short answer: Implicit's tiny constant-size
`tileset.json` is a real, large advantage (105-663x smaller); total file
count and bytes don't consistently favor either mode (direction flips
between the two municipalities by building density); the number that
would actually settle "does it help in real use" (render time/request
count) remains unmeasured after a real attempt.

**Phases 0–6 all run for real against both municipalities, and all 8
dataset/mode/profile combinations are published live on
tunnel.optgeo.org.** Phase 4 (full-profile Sarabetsu) found the session's
biggest finding: determinism fails at full scale even though it holds at
small scale. Phase 5 (small Muroran) confirmed small-profile determinism
holds regardless of municipality and found a real structural
tile-refinement difference driven by Muroran's LOD1-only source data.
**Phase 6 (full-profile Muroran) confirms Phase 4's determinism failure
generalizes beyond Sarabetsu, and refines the root cause** — Muroran
shows no single "problem file" the way Sarabetsu did, pointing instead at
batching multiple buildings into one content tile as the real source of
non-determinism, with a confirmed (not just hinted) concurrency effect: a
fixed baseline of 5 tiles is unstable regardless of thread count, and
`CONCURRENCY=4` adds ~20 more on top. All 8 combinations were published
for real at one point; **the 4 small-profile ones were then removed again**
(server + viewer menu, per the user's follow-up request once Phase 1-3/5
were done with them) — only the 4 full-profile combinations are live and
in the dropdown now. **The viewer also got a real bug fix and a
ground-up redesign 2026-08-26**: `Cesium.Viewer`'s `imageryProvider`
option has been removed since CesiumJS 1.107 and was silently doing
nothing — the basemap was never actually loading, in any session,
including this one until caught. Fixed (now uses
`imageryLayers.addImageryProvider`), switched the basemap to the user's
own `kitaphoto` tiles (GSI aerial photography, no API key needed), and
rebuilt the UI as a Japanese-language, consumer-facing panel with
developer diagnostics collapsed by default — see "Viewer overhaul" below
for the full account. **The user then reported a visual artifact that led
to a real scope-boundary finding**: full-profile builds had been feeding
Mago LOD0 *and* LOD3 geometry alongside LOD1, contradicting CLAUDE.md's
explicit LOD1-only baseline. Built and wired in
`tools/strip_higher_lod.py`, verified it quantitatively, rebuilt and
re-published all 4 full-profile combinations (Sarabetsu got 12-13%
smaller; Muroran was already unaffected by this), and — as a useful
negative result — confirmed this does *not* explain the Phase 4/6
non-determinism (same failure, same tiles, before and after stripping).
See "LOD1-baseline enforcement" below for the full account. This was a
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
record `manifests/reports/published-<build-id>.json`. **(2026-08-26,
superseded within the same session)** All 8 combinations were published
at the user's explicit request ("full-profileも含めて全部公開"), then the
4 small-profile ones were deleted again once their experiments were done
(see "Viewer overhaul" below) — **only the 4 full-profile combinations
are live now.**

**`.env` had to be recreated this session** — it's gitignored and wasn't
present on disk (the file that made the earlier Sarabetsu-only publish
work in a prior session is gone; not investigated why). Recreated from
the real, already-documented values in `.env.example`'s comments and this
file's own text above (`PUBLISH_HOST=jaxa.optgeo.org`,
`PUBLISH_PATH=/home/pod/x-24b/data/plateau-mago-implicit`,
`PUBLISH_URL_BASE=https://tunnel.optgeo.org/plateau-mago-implicit`) — not
secrets, auth is via the local SSH config already set up on this machine
(confirmed working: `ssh jaxa.optgeo.org` succeeds). If a future session
finds `.env` missing again, this is exactly what to put back.

`viewer/viewer.js`'s `VIEWPOINTS` and `viewer/index.html`'s dropdown now
have only the 4 `*_full` entries (small-profile entries removed along
with their published data, see "Viewer overhaul" below) — centers
computed from each dataset's *Explicit* build's root bounding region
(Implicit's is grid-padded, not tightly fit — see "Viewer overhaul"),
altitude deliberately lower than "fit the whole extent" would need (see
the long comment in `viewer.js` itself for the SSE-threshold math this is
based on). **Not independently re-confirmed by live pixel rendering in
this session's automated browser tool** — the same
`document.visibilityState: "hidden"` limitation as every other viewer
check this session; network-level (`fetch()`, layer/provider counts) and
math-level (bounding-region computation) checks are solid, actual
on-screen appearance needs the user's own browser.

Real, currently-live URLs (`<dataset>/<mode>/full`):
- `sarabetsu/explicit/full`, `sarabetsu/implicit/full`
- `muroran/explicit/full`, `muroran/implicit/full`

  (pattern: `https://tunnel.optgeo.org/plateau-mago-implicit/<dataset>/<mode>/full/latest/tileset.json`)

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
municipality or source file. **Follow-up, confirmed not just a
single-comparison hint:** built 2 more concurrency=1 runs and compared —
**the exact same 5 tiles** as the first concurrency=1 pair, byte-identical
file set. All 5 are a subset of the concurrency=4 pair's 25-tile set.
Clean, reproducible shape: a fixed baseline of 5 unstable tiles exists
regardless of thread count, and `CONCURRENCY=4` adds roughly 20 more on
top of that baseline rather than replacing it. `METADATA_INVALID_LENGTH`'s
alignment-padding pattern continues to hold with zero outliers, now
across 4097 combined instances spanning both municipalities and both
scales. Full detail: `docs/findings.md` Phase 6, `docs/determinism.md`
Results.

## Viewer overhaul, 2026-08-26: site cleanup + a real CesiumJS imagery bug + consumer-facing redesign

At the user's direction, several changes bundled into one session:

**Site/data cleanup.** The 4 small_file (single-building) combinations —
which only ever existed to support Phase 1-3/5's determinism/comparison
experiments, now complete — were removed from both
`tunnel.optgeo.org` (`rm -rf` on the remote `sarabetsu/{explicit,implicit}/small`
and `muroran/{explicit,implicit}/small` directories via SSH) and the
viewer's dataset dropdown. Local `data/output/` and all research records
(`docs/findings.md`, `manifests/`) were deliberately left untouched — the
user's explicit scope was "server-published data and the viewer menu
only." **Caveat:** Cloudflare's edge cache (`cache-control: max-age=14400`)
will keep serving stale 200 responses for the deleted URLs for up to ~4
hours after deletion (confirmed via `cf-cache-status: HIT` on a
still-200 response right after deleting the origin files) — no
Cloudflare API/purge access is configured in this session, so this can't
be forced; it'll clear on its own.

**Implicit full-profile viewpoints were off-center** (user-reported,
both municipalities) — root-caused to Implicit's root bounding region
being padded to the quadtree grid boundary (not tightly fit to actual
buildings the way Explicit's is), confirmed by comparing the two regions
directly (Implicit's north edge sits 3-6km further out for both
datasets). Fixed by computing both `*_full` viewpoints' centers from the
*Explicit* build's region instead, for both datasets.

**A real, previously-undiagnosed CesiumJS bug: the viewer's imagery was
never loading, in any session before this one.** `Cesium.Viewer`'s
`imageryProvider` constructor option — used here for OSM, and initially
for kitaphoto too — was deprecated in CesiumJS 1.104 and fully **removed**
in 1.107, with zero warning or error when passed to 1.144 (just silently
ignored: `viewer.imageryLayers.length` was 0 after construction). Every
screenshot this session showing a flat blue globe with no basemap was
this bug, not a network/test-environment issue as first assumed. Fixed
by using `viewer.imageryLayers.addImageryProvider(...)` after
construction instead, with `baseLayer: false` in the constructor options
to stop Cesium from also creating its own default (token-less, therefore
always-failing) ion base layer alongside it.

**Switched the base imagery from OSM to `kitaphoto`** (the user's own
Martin tileserver at `stars.optgeo.org`, GSI seamless aerial photography,
CC BY 4.0) — TileJSON confirmed via `curl https://stars.optgeo.org/kitaphoto`:
`https://stars.optgeo.org/kitaphoto/{z}/{x}/{y}`, JPEG, 512x512 tiles
(not Cesium's 256x256 default — `tileWidth`/`tileHeight` had to be set
explicitly or the zoom-level-to-URL mapping would be wrong), minzoom 2,
maxzoom 12. Confirmed real image data is served (downloaded and
inspected a sample tile: valid 512x512 JPEG) and that CesiumJS correctly
issues fetches for it once the `imageryProvider` bug above was fixed.
**Known cosmetic issue, not fixed:** the console logs "Failed to obtain
image tile" for level 0/1 (below kitaphoto's minzoom, requested anyway
despite `minimumLevel: 2` — Cesium's imagery tile pyramid appears to
probe low levels regardless) and for some level 2 tiles outside
kitaphoto's actual coverage (server correctly returns 204, not an error,
for those). Mitigated somewhat by setting the viewer's default startup
camera to Hokkaido instead of the whole-Earth default (also just a more
sensible default for a viewer that's only ever about two Hokkaido
municipalities), which doesn't eliminate the low-level requests but
reduces how much of the console noise a user would ever see in practice
since real usage flies straight to a dataset. Not independently
confirmed by live pixel rendering in this session (same
`document.visibilityState: "hidden"` limitation as every other viewer
check this session) — network-level and layer-count checks are solid,
actual on-screen appearance needs the user's own browser.

**Also disabled `infoBox`** (Cesium's default click-to-inspect popup,
which would have shown the raw `id`/`BatchId`/`NodeName`/`FileName`
properties — directly contradicting the point of hiding technical detail
from the main UI, see below).

**Consumer-facing UI redesign, per explicit user direction ("look and
feel の大幅な改善", UI language = Japanese, no small print/project
codename, hide developer-facing diagnostics by default).** Rewrote
`viewer/index.html`'s panel: Japanese labels throughout (dataset names as
更別村/室蘭市, status messages, buttons); title changed from
"plateau-mago-implicit viewer" to "PLATEAU 3D建物ビューア" (no internal
codename); the outer panel got a minimize toggle (already added earlier
this session, kept); a *second*, independent collapse — "詳細情報・開発者向け"
("details / for developers") — now hides the custom-URL input, hint
text, and the full FPS/heap/tiles-loaded diagnostics readout, collapsed
by default, so a first-time visitor sees only the dataset picker and a
status line. `viewer.js`'s `updateDiagnostic()` calls were changed to set
only the value (the label now comes from CSS `::before` + a `data-label`
attribute), matching the new layout.

**Reference material prepared, not acted on:** the user asked what
proportion of file size the `id` property (the meaningless, freshly-random
UUID discussed extensively above) actually costs, to inform a future
design decision — not asking for removal yet. Measured directly:
raw-byte share is 4.66% (Sarabetsu full) / 3.05% (Muroran full), but
because `id` is the one incompressible (high-entropy) property in the
schema, its share of **gzip-compressed** size is roughly double that —
10.07% / 7.16%. Full detail and methodology: `docs/information-retention.md`
"Reference material: what the `id` property costs in bytes".

**Still not done:** the footprint/roof z-fighting the user reported
(likely the same root cause as the earlier LOD0-footprint sibling-branch
finding from Phase 2 — the LOD0 flat footprint and the LOD1+ solid roof
sitting at nearly the same height, both loaded together via `refine:
ADD`) — the user chose "build a CityGML LOD0-stripping preprocessing
script" as the fix direction, not yet implemented.

## Real elevation added: Re:Earth Terrain (Mapterhorn DEM + EGM2008)

Answers the terrain half of the earlier "ground surface" request (only
kitaphoto, the imagery half, was done in the first pass). Found
[Re:Earth Terrain](https://terrain.reearth.land/) via web search — a
public, no-API-key quantized-mesh-1.0 service that blends
[Mapterhorn](https://mapterhorn.com/)'s global open DEM with the EGM2008
geoid (so heights land on the WGS84 ellipsoid CesiumJS draws, not just
mean-sea-level heights). Confirmed real and reachable: `curl
https://terrain.reearth.land/cesium-mesh/ellipsoid/layer.json` returns
valid TileJSON (quantized-mesh-1.0, global bounds, minzoom 0/maxzoom 14).
Wired in via `Cesium.CesiumTerrainProvider.fromUrl(...)` (async — resolves
after Viewer construction, replacing the placeholder
`EllipsoidTerrainProvider` set initially), with `requestVertexNormals` and
`requestWaterMask` both on. Verified at the network level in this
session's automated browser tool: `viewer.terrainProvider instanceof
Cesium.CesiumTerrainProvider` is true, `hasWaterMask`/`hasVertexNormals`
are both true, and real terrain tile requests (`layer.json`, `0/0/0.terrain`,
`0/1/0.terrain`) succeed with no console errors. Not confirmed by live
pixel rendering (same limitation as everything else viewer-related this
session).

**Update 2026-08-26/27: the open question above was answered (worse than
"may not sit flush"), and then fixed.** Decoded real absolute elevations
from `bldg:lod1Solid` for 20 buildings across both municipalities and
sampled the live viewer's actual Re:Earth Terrain provider at those exact
coordinates (`Cesium.sampleTerrain` in a real browser tab against the
deployed GitHub Pages page). Result: buildings sit a tight, systematic
**28–34 m below** the real terrain surface — Muroran: mean −33.37 m
(stdev 0.75 m, n=12, coastal to hillside); Sarabetsu: mean −27.78 m
(stdev 0.66 m, n=5). Cross-checked independently against
`GeographicLib`'s EGM2008 geoid calculator: undulation (N) at Muroran's
coordinates is 32.83 m, at Sarabetsu's is 27.91 m — both match the
measured offsets to within 0.5 m. **Root cause: PLATEAU's `lod1Solid`
height values are effectively orthometric (geoid-referenced, confirmed
against PLATEAU's own documentation) despite being declared under
EPSG:6697 (nominally ellipsoidal by CRS definition); `scripts/build.sh`'s
`--proj` fix only corrects horizontal axis order and passes Z through
unchanged, so Mago places buildings at the raw orthometric value while 3D
Tiles/CesiumJS — and Re:Earth Terrain's EGM2008-corrected DEM — both
treat height as true ellipsoidal.** The user independently confirmed this
visually on the live site before the fix: "全部建物が沈んでいる" (all the
buildings are sunk), matching high-rises being the visible exception (a
tall enough building pokes back up through a ~33m sink).

**The user then asked whether Eukarya (who operate Re:Earth Terrain) had
already solved this** — leading to finding **PLATEAU-Terrain**
(`tile.plateauview.mlit.go.jp`), Eukarya's *official* PLATEAU VIEW terrain
service, whose own docs claim GSIGEO2011-based alignment with PLATEAU's
3D building data specifically. Tested it directly: **the offset was
unchanged** — confirming the terrain side was never the problem; the fix
has to happen on the building-height side, in this project's own
pipeline. Found the real fix PLATEAU's own tooling uses instead: an
official FME "Vertical Transformation with GSIGEO2011" step, and a small
MIT-licensed library implementing the same model —
[japan-geoid](https://github.com/ciscorn/japan-geoid). With the user's
explicit approval (this project's first third-party Python dependency —
see `DECISIONS.md` D21), built `tools/geoid_correct.py` (a second
build-time staging step alongside `tools/strip_higher_lod.py`) that adds
GSIGEO2011 geoid undulation to every building coordinate's height before
Mago sees it. Verified end-to-end on the small_file first (output
region height became 34.79–39.01m, matching both the geoid-corrected
source value and real terrain at that location), then rebuilt all 4
full-profile combinations — tile counts unchanged (198/760/1259/553),
`make validate` shows only the pre-existing, unrelated
`METADATA_INVALID_LENGTH` pattern. Full detail: `docs/findings.md`
"Cross-phase follow-up: terrain/building vertical datum mismatch."

**Published 2026-08-27** (user approved): all 4 full-profile combinations
re-published via `make publish ... EXECUTE=1`. Verified the origin itself
is correct — a cache-busting query string (`?cachebust=...`) returns
`cf-cache-status: MISS` and the new, geoid-corrected root bounding region
(Sarabetsu 142.3–354.9m, Muroran 32.3–521.6m — matching the local
rebuilt output exactly).

**Caching gotcha, worth knowing before checking visually:** immediately
after publishing, the canonical `/latest/tileset.json` URLs were still
returning `cf-cache-status: HIT` with `age: ~6600s` (~110 min) — i.e.
**Cloudflare's edge cache is still serving the pre-fix (buried-buildings)
tileset**, same `cache-control: max-age=14400` (4h) behavior already
documented above for the small-profile deletion. No Cloudflare purge
API is configured in this session, so this can't be forced. It'll clear
on its own within 4h of each tile's own cache time, but a spot-check on
the live viewer soon after this publish may still show the *old*, buried
appearance purely from caching, not because the fix didn't take —
appending a throwaway query string to the URL (or waiting) sidesteps it.

Still needs: visual reconfirmation in the live viewer once the cache
clears — this fix was verified through coordinate math, two independent
geoid cross-checks (EGM2008 calculator, PLATEAU-Terrain), one
small-profile build round-trip, and an origin-vs-cache check via
cache-busting, not through a screenshot, for the same
`document.visibilityState: "hidden"` reason as every other viewer check
this project has done.

Attribution for the terrain layer (Re:Earth Terrain / Mapterhorn) added
to `viewer/index.html`'s attribution line, alongside PLATEAU and
kitaphoto/GSI.

## LOD1-baseline enforcement, 2026-08-26: a real scope-boundary gap, found via a UI bug report

The user reported a visual artifact on a large Sarabetsu building —
"texture pasting looks incomplete, competing with what's underneath."
Investigating it surfaced something more consequential than a rendering
bug: **every full-profile build up to this point had been feeding Mago
LOD0 and LOD3 geometry alongside LOD1**, directly contradicting
CLAUDE.md's explicit "baseline is LOD1 only, higher LOD is Phase 7
territory" scope boundary. No real photo-textures were involved (checked:
zero `app:ParameterizedTexture`/`app:Appearance` elements anywhere in
either dataset) — the "torn texture" look was multiple full 3D geometric
representations of the same building (LOD0 footprint + LOD1 solid + LOD3
solid + LOD3 detailed multi-surface) all loaded together via `refine:
ADD`, concentrated in 4 buildings inside `63437175_bldg_6697_op.gml` —
the same file Phase 4 already flagged as the non-determinism source. One
of those 4 buildings alone has 2,004 `lod3MultiSurface` elements and a
5.5 MB XML footprint.

**Ruled out Mago's own `--minLod`/`--maxLod` flags as a fix** by testing
directly: they control Mago's own internal tiling-refinement depth (the
RC0→RC00→RC000→RC0000 chain), not which PLATEAU LOD gets converted.
`--minLod 1` against the small_file produced **zero** tile contents,
confirming this isn't the right lever.

**Built `tools/strip_higher_lod.py`** — parses a CityGML file
(`xml.etree.ElementTree`, stdlib only), removes any `lod{N}`-prefixed
element (N ≠ 1) that's a direct child of `bldg:Building`/`bldg:BuildingPart`,
writes to a separate path (never touches `data/source/`). Wired into
`scripts/build.sh` **unconditionally, for both profiles** — no bypass
flag, since there's no legitimate baseline scenario for feeding Mago
non-LOD1 geometry. Verified quantitatively before wiring it in: running
Mago on the 15.3 MB problem file with/without stripping dropped the
batched feature count by exactly 818 (matching the 818 `lod0FootPrint`
elements removed) while total output size fell only ~6.5% despite 7,292
`lod3MultiSurface` elements existing in the file — strong evidence Mago's
mesh generation only uses the direct-child `Solid`/`MultiSurface`
declarations, not the `bldg:boundedBy`-nested boundary-surface breakdown,
so the script's narrower scope (direct children only, not a full
CityGML-schema-aware cleanup) is empirically sufficient. Confirmed
end-to-end on the small_file: 2 tile contents → 1 (Explicit),
`propertyTable.count: 2` → `1` (Implicit) — the LOD0 sibling branch is
gone entirely, not just resized.

**Rebuilt and re-published all 4 full-profile combinations.** Sarabetsu
Explicit: 202→198 tile contents, 15,958,768→13,820,511 bytes (13.4%
smaller). Sarabetsu Implicit: 804→760 tile contents, 18,180,034→15,899,663
bytes (12.5% smaller). **Muroran (both modes): byte-identical output
before and after** — confirmed the stripper genuinely ran (checked the
staged file directly: `lod0RoofEdge` gone, only `lod1Solid` remains), so
this means Mago already produced identical geometry for Muroran's
`lod0RoofEdge` and `lod1Solid` for every building — consistent with Phase
5's earlier single-building finding. Muroran's already-published build
needed no re-publish (nothing changed); Sarabetsu's two full-profile
builds were re-published and verified reachable (200).

**Useful negative result:** stripping LOD3 does **not** fix the Phase 4/6
non-determinism. Built two post-stripping Sarabetsu Implicit full-profile
runs and compared: still L3/FAIL, still 10 geometry-affected tiles, same
tile coordinates as before stripping. Since the LOD3 content that
coexisted in this exact file is now gone and the non-determinism is
unchanged, this rules out LOD-complexity as the cause and sharpens Phase
6's finding to "batch size/count is the driver, not geometry complexity
within a batch." Full detail: `docs/findings.md`, new section
"Cross-phase follow-up: LOD1-baseline enforcement."

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

## Viewer polish, 2026-08-27: imagery was capped at a blurred derivative; buildings looked too dark

Two more issues the user found by actually looking at the live site
(with the geoid fix above already visible) — both viewer-only changes,
no build pipeline involvement.

**Imagery was blurry — the user specifically suspected a 512px-tile
zoom-level mismatch, and was right, just not in the way first assumed.**
`viewer.js`'s original comment (see "Viewer overhaul" above) asserted
that a 512px tile at level z is *more* detailed than a standard 256px
scheme's level z (roughly z+1 equivalent) — true in general, but
`kitaphoto` (the specific tileset wired in) turned out to be a
*deliberately downsampled* derivative capped at z12, not the real
source. Found by reading its own catalog description
(`curl https://stars.optgeo.org/catalog`): "z13 GSI seamlessphoto512 ...
downsampled to z2-12 via 2x2 box averaging ... z13+ intentionally not
included here — served from the original seamlessphoto512.pmtiles
instead." So `kitaphoto` was both capped (no path past z12 — Cesium
over-zooms its best-available tile rather than failing, which is exactly
what reads as "blurry") and, even within z2-12, synthetically softened
relative to the real per-level source. Switched to `seamlessphoto512`
(same server, same 512px JPEG format, real "zoom 1-17" per-level detail,
not a downsample) — confirmed it has genuine, non-blank coverage at both
municipalities' coordinates up to z17 (`curl` + Pillow pixel-stats check:
mean brightness 105-139, stdev 27-36, i.e. real photo content, not
black/empty tiles) before switching. `viewer.js`'s `minimumLevel`/
`maximumLevel` updated from 2/12 to 1/17 accordingly. Traded away
`kitaphoto`'s low-zoom satellite-mosaic gap-filling, judged low-risk
since this viewer only ever shows two specific, well-covered Hokkaido
municipalities, never an arbitrary global low-zoom view.

**Buildings looked too dark/"sunken" against the real photo basemap.**
Decoded a real built GLB's materials directly: Mago 3DTiler assigns its
own placeholder colors per building — a warm orange roof
(`baseColorFactor [1.0, 0.5, 0.25]`) and light-gray walls (`[0.9, 0.9,
0.9]`), fully rough/non-metal. Against real aerial photography this read
as dark/artificial rather than the pale/white cladding common on real
Hokkaido buildings (the user's own framing). Fixed with a
`tileset.style = new Cesium.Cesium3DTileStyle({color: "color('#F2EFE6')"})`
override in `loadTileset()` — a warm off-white, applied uniformly. This
is a viewer-only style override; it doesn't touch the GLB data, so it
has no effect on the Explicit/Implicit comparison or any
determinism/validation finding.

Both changes verified locally (served `viewer/` with a plain
`python3 -m http.server`, loaded in this session's browser tool):
imagery provider correctly reports `minimumLevel:1, maximumLevel:17,
tileWidth:512` pointed at `seamlessphoto512`; loading a real dataset sets
`currentTileset.style.color.expression === "color('#F2EFE6')"`; zero
console errors either way. Pushed to `main` (`c3b22d6`) at the user's
request — GitHub Pages auto-deploys `viewer/` on push. **The user then
looked at the live site and confirmed the geoid fix worked** (buildings
sitting on real terrain, not buried) and reported two follow-on issues,
addressed in "Roof/wall shimmer and a URL hash feature" below.

## Roof/wall shimmer and a URL hash feature, 2026-08-27

The user reported roofs and wall/window areas of a large, complex
Sarabetsu building "チカチカ" (flickering/shimmering) on the live site,
screenshotted directly, and asked a direct question: is this Mago's
fault, or is it CesiumJS being "too clever" (their analogy: like a
certain era of Microsoft)?

**Investigated rather than guessed, per this project's own standard.**
Two candidate causes:
1. **Duplicate/overlapping LOD1 geometry** (from Mago, or from the
   source CityGML modeling a complex building as multiple BuildingParts
   with independently-digitized shared walls) — decoded a real built
   GLB (`sarabetsu/explicit/full`'s `RC021.glb`, chosen because its
   bounding region contains the predefined Sarabetsu viewpoint
   coordinates; 21,794 triangles) with a small ad hoc script
   (struct/json/numpy, not committed to `tools/` — a one-off
   investigation, not a pipeline step) and searched for triangles
   sharing the same 3 vertices to within 1mm. Found only **2 exact
   duplicates (0.01%)** — not remotely enough to explain widespread
   shimmer across both roof and wall areas. This rules out duplicate
   geometry as the primary cause, at least in the sampled tile.
2. **CesiumJS's logarithmic depth buffer.** Cesium's own engineering
   blog (https://cesium.com/blog/2018/05/24/logarithmic-depth/) states
   precision loss from it is "particularly problematic with flat
   surfaces like roofs" — the exact reported symptom, on both roof and
   flat wall/window areas. `Scene`'s own API docs describe a tuning
   knob for exactly this: "if a primitive or model close to the surface
   shows z-fighting, decreasing [the ratio] will eliminate the
   artifact, but decrease performance."

**Verdict, evidence-based: this reads as CesiumJS's known depth-buffer
precision trade-off, not a Mago/PLATEAU data defect** — and not "too
clever" either; it's a real, openly-documented, unavoidable engineering
trade-off every WebGL globe-scale renderer using a single depth buffer
has to make (planet-to-building scale in one scene), not something
unique to Cesium's design. Mitigated in `viewer.js` by setting
`viewer.scene.logarithmicDepthFarToNearRatio = 1e5` (down from the
default `1e9`) — this viewer only ever shows two small municipalities,
never a true planet-scale view, so the traded-away far-range precision
isn't needed here. **Not independently confirmed by live rendering this
session** (same `document.visibilityState: "hidden"` limitation as
everything else) — worth the user's own look; if shimmer persists,
the next things to try are an even lower ratio or, if that's not
enough, revisiting whether the source CityGML's multi-part buildings
have near- (not exact-) duplicate walls that only a looser geometric
tolerance would catch (the 1mm search here was intentionally strict).

**Also added:** a MapLibre GL JS-style URL hash for bookmarking/sharing
a specific view. Format: `#dataset=<key>&lon=<deg>&lat=<deg>&h=<m>&
heading=<deg>&pitch=<deg>&roll=<deg>` (or `#url=<encoded tileset URL>&...`
in place of `dataset` when a custom tileset was loaded via the URL
field). Updates on `viewer.camera.moveEnd` via `history.replaceState`
(no history spam); restored at startup by reading `location.hash` before
falling back to the normal empty-state behavior. Cesium has no built-in
equivalent, so this is hand-rolled — deliberately kept to the same small
position+orientation parameter set MapLibre's own hash uses, not an
attempt to serialize full viewer state. Verified locally (`python3 -m
http.server` + this session's browser tool): selecting a dataset and
moving the camera produces a correct hash string; reloading the page
with that exact hash restores the same dataset selection, tileset, and
camera position exactly, with zero console errors either way.

Also trimmed the post-flyTo status message to an empty string per the
user's request ("情報量は削ろう") — it previously read "表示準備完了。
マウス・タッチで操作できます。"

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

**Phases 0–6 are done for real, for both municipalities. The viewer has
now been through two full rounds of user-driven fixes** (2026-08-26 and
2026-08-27 — see "Viewer overhaul", "Real elevation added", "LOD1-baseline
enforcement", "Viewer polish", "Roof/wall shimmer and a URL hash feature",
and "kitaphoto17" above) — this is the freshest, least-settled part of the
project, more than the experiment phases themselves. **Everything
described above is implemented, tested against real data or config, and
committed+pushed (CI/Pages green) unless a section explicitly says
otherwise.**

The user explicitly said an upstream Mago 3DTiler report is not
necessarily the goal, so that's optional future work only, not a next
step.

Immediate next steps, roughly in priority order:

1. ~~Ask the user to spot-check the viewer live~~ **Done — user confirmed
   in their own browser (2026-08-27) that the fixes work**: terrain
   placement, `kitaphoto17` imagery, off-white buildings, and (implicitly,
   no complaint raised) the shimmer mitigation and URL hash. This closes
   out the last "unconfirmed" item from both 2026-08-26 and 2026-08-27's
   viewer work — every fix listed in this file's "Status" section above
   is now real, not just network/config-verified. (Historical note, kept
   for context: every fix this session was verified at the network/config
   level only before this confirmation — `document.visibilityState:
   "hidden"` still blocks this session's own browser tool from real
   rendering; a documented attempt this session to force it via manual
   `scene.render()` pumping sometimes worked but was non-deterministic —
   see `docs/findings.md`.) Claude in Chrome remains unconnected — not
   needed now that the user confirmed directly, but still worth pursuing
   for future automated visual checks.
2. **Terrain/building vertical datum mismatch — root-caused, fixed,
   published, AND now visually confirmed (see point 1).** Root cause: PLATEAU's
   `bldg:lod1Solid` heights are referenced to Tokyo Bay mean sea level
   (orthometric), not the ellipsoid, despite EPSG:6697 being nominally
   ellipsoidal — confirmed against PLATEAU's own documentation and by
   testing that even Eukarya's official PLATEAU-Terrain service doesn't
   fix it on its own (the terrain side was always correct). Fixed with a
   new build-time staging step, `tools/geoid_correct.py`, using the
   `japan-geoid` package (GSIGEO2011, the same model PLATEAU's own FME
   workflow uses) — this project's first third-party Python dependency,
   approved by the user first (`DECISIONS.md` D21). Verified on the
   small_file, rebuilt all 4 full-profile combinations (tile counts
   unchanged, `make validate` shows no new error type), and published
   all 4 (user approved) — origin confirmed correct via cache-busting
   (`cf-cache-status: MISS` returns the new height ranges). **What's
   left:** the same visual reconfirmation as point 1 — plus be aware the
   canonical `/latest/` URLs may still serve Cloudflare's stale,
   pre-fix cache for up to ~4h after this publish (see "Real elevation
   added" below for the exact cache-busting workaround). Full detail:
   `docs/findings.md` "Cross-phase follow-up: terrain/building vertical
   datum mismatch."
3. Remaining measurement gap from `docs/test-plan.md`'s Phase 4/6 lists:
   peak process memory, navigation responsiveness, geographic-jump
   convergence, browser long-session memory trend — still unmeasured.
   **First-useful-render time and initial request count/bytes were
   attempted 2026-08-27** (at the user's direct request) but abandoned as
   unreliable — see `docs/findings.md`'s "Cross-phase follow-up: does
   Implicit actually show a benefit over Explicit?" for the full account
   and a real, partially-working lead (manual `scene.render()` pumping)
   worth retrying from a genuinely visible browser.
4. ~~Check whether the concurrency=4 tile set is stable run-to-run~~
   **Done 2026-08-27** (at the user's request): 3 more Muroran Implicit
   full builds each at concurrency=1 and =4. Concurrency=1's 5-tile
   baseline reconfirmed exactly (3rd independent pair, zero variation,
   even across the geoid-fix pipeline change). Concurrency=4 has a
   stable 19-tile core across all 3 pairs, plus some build-specific
   extra instability at the edges (7 tiles traced to one specific
   build) — real, but not as clean as concurrency=1. Caught a real
   methodological trap along the way: comparing builds across the
   geoid-fix boundary (different `git_commit`, different pipeline
   version) produces near-total apparent divergence that's actually the
   *intentional* Z-shift, not non-determinism — future determinism
   comparisons should check build manifests' `git_commit` matches
   before trusting a result. Full detail: `docs/findings.md`
   "Cross-phase follow-up: additional determinism sampling." Not yet
   done: pushing past n=3 to the originally-floated 5+ pairs, and
   checking whether the 7-tile "extra instability" pattern is typical
   or was specific to that one build. **Update 2026-08-28**: pushed to
   n=4 pairs at concurrency=4 — refined finding, not just more
   confirmation: the 19-tile "core" turns out to be size-stable but NOT
   identity-stable across independent samples (16/19 tiles shared
   between the old and new 4-pair intersections, 3 unique to each) —
   concurrency=4's non-determinism is a broad pool of ~19-32
   individually-high-probability-unstable tiles, not a fixed guaranteed
   set the way concurrency=1's exact 5 tiles are. This is now
   well-evidenced for Muroran; Sarabetsu hasn't been sampled this deeply
   yet (only Phase 4's original single pair) — the natural next
   extension if this is revisited. Full detail: `docs/findings.md`
   "Cross-phase follow-up: the 19-tile core survives a real pipeline
   change."
5. Phase 7 (optional higher-detail/LOD2+/texture tests) remains untouched
   and explicitly optional per `docs/scope.md` — the only phase not yet
   run in some form. Note: Phase 7, if ever pursued, would need to
   deliberately *bypass* `tools/strip_higher_lod.py` (which now runs
   unconditionally in `scripts/build.sh` for every Phase 1-6 build) since
   Phase 7 is specifically about the higher-LOD content that script now
   strips — that bypass doesn't exist yet.

Lower-priority, tracked but not blocking:

- ~~Pin `validators.tiles_validator_version` for real~~ **Done
  2026-08-28**: `scripts/validate.sh` now reads it from
  `config/common.yml` and runs `npx --yes 3d-tiles-validator@<version>`
  instead of the unpinned form. Re-verified against an existing build:
  same known 687-error `METADATA_INVALID_LENGTH` result, unchanged.
- ~~`tools/inspect_subtree.py`/`tools/normalize.py` still duplicate
  subtree-parsing logic~~ **Done 2026-08-28**: extracted
  `tools/subtree_common.py` (bit-counting, `find_subtree_levels()`,
  `is_subtree_json()`, binary/JSON+bin container parsing, availability
  counting) — both tools now import from it. Verified byte-identical
  output before/after on 4 real builds (Sarabetsu/Muroran, small/full,
  with/without the new non-default `subtreeLevels`) — pure refactor, no
  behavior change. One real gotcha hit and fixed along the way: a bare
  `import subtree_common` only resolves when the script's own directory
  is on `sys.path` (true for direct `python3 tools/foo.py` execution,
  false for `tests/run-tests.sh`'s `import tools.foo` style) — fixed by
  explicitly adding the script's own directory to `sys.path` before the
  import, in both files.
- ~~`config/common.yml`'s `tiling.subtree_levels: 3` isn't wired into
  `scripts/build.sh`~~ **Done 2026-08-28**: Mago does expose a real flag,
  `-isl`/`--implicitSubtreeLevels` (confirmed via `docker run <image>
  --help`, marked "[Experimental]" by Mago itself), now passed through
  for implicit-mode builds. Verified end-to-end: a fresh small-profile
  Sarabetsu Implicit build's `tileset.json` now declares
  `subtreeLevels: 3` (was 4), correctly produces 2 subtree files instead
  of 1 (levels 0-2 in the root subtree, level 3 in a child), and
  `make validate` decodes both correctly. **Not yet applied to the live
  published full-profile builds** — this only affects *future* builds;
  the 4 currently-published combinations still use Mago's default of 4
  and were not rebuilt/republished for this change (out of scope for a
  "small, safe fix").
- Optionally bisect which CesiumJS release between 1.117 and 1.144 fixed
  the implicit-tiling bug — still not done, still genuinely low priority.

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
| LOD1-baseline enforcement (strips LOD0/LOD3 before Mago sees it) | `tools/strip_higher_lod.py` |
| Architecture decisions and why (D1–D19+) | `DECISIONS.md` |
| Agent working conventions | `CLAUDE.md` |
| Live GitHub Pages viewer | https://dwg7.github.io/plateau-mago-implicit/ |
| Live published tiles | https://tunnel.optgeo.org/plateau-mago-implicit/ |

## Open questions for the user

- **Resolved:** the geoid/datum fix-path question (build-time correction
  via `japan-geoid`, D21) and the publish question — both approved by the
  user 2026-08-27; the fix is built, verified, rebuilt, and published.
  Nothing blocking here now except the Cloudflare cache TTL (~4h, see
  above) before a live visual check will show the corrected result.
- Worth a decision eventually, not urgent: switch to the Docker Hub
  `gaia3d/mago-3d-tiler` public image instead of the local JAR build? The
  JAR path already works and is arguably more transparent.
