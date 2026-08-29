# Decisions

A running log of the significant decisions behind this experiment: what was
chosen, why, and what it rules out. Most of these are already documented at
length in `docs/*.md` — this file is the short, chronological index; follow
the links for full rationale. Add a new entry here whenever a decision is made
that would otherwise only live in someone's memory or a buried commit message.

Format: **ID — Title** · Status · one-paragraph Context/Decision/Consequence.

---

## D1 — Two municipalities, chosen for contrast, not coverage

**Status:** Accepted (docs/data-selection.md, docs/scope.md)

Sarabetsu Village (更別村) and Muroran City (室蘭市), both in Hokkaido, were
chosen specifically because they're different in the ways that matter for this
experiment: Sarabetsu is small/rural (cheap iteration, clean determinism
baseline), Muroran is coastal/urban with terrain variation and denser building
distribution (stress-tests subtree organization and CRS/height handling). This
is a **deliberate pair for contrast**, not a claim of representative coverage.
Consequence: do not add a third municipality to "increase confidence" — if
broader coverage is ever wanted, that's a new, explicitly scoped decision, not
scope creep on this one. See D9.

## D2 — Mago 3DTiler as the converter under test, pinned by digest

**Status:** Accepted (docs/architecture.md, docs/reproducibility.md)

Mago 3DTiler (Gaia3D) was selected as the CityGML → 3D Tiles converter.
Reproducibility requires it be pinned immutably — by Docker image digest or
JAR SHA-256, recorded in `config/common.yml` — not by a floating tag or
`latest`. Consequence: `Dockerfile` and `scripts/build.sh` refuse to run
(`TBD_VERIFIED_SOURCE_REQUIRED` guard) until a specific version is resolved
and pinned; upgrading Mago is a deliberate act of editing `config/common.yml`,
not an incidental side effect of a rebuild.

## D3 — Explicit tiling as baseline control, Implicit as the actual research target

**Status:** Accepted (docs/architecture.md, docs/test-plan.md)

The research question is specifically about **Implicit** 3D Tiles. Explicit
tiling output is generated first (Phase 1) purely as a control baseline — to
separate "did CityGML parse and place correctly" from "does Implicit Tiling
specifically work" (Phase 2). Consequence: Phase 1 failures block Phase 2 from
being meaningful; don't skip straight to Implicit output to save time.

## D4 — Static HTTP + CesiumJS delivery; explicitly no backend, no spatial database

**Status:** Accepted (docs/scope.md, docs/respectful-positioning.md)

The whole premise is that pre-generated Implicit 3D Tiles can be served from
ordinary static HTTP (nginx here) and consumed by an off-the-shelf client
(CesiumJS) with no PostGIS/3DCityDB/dynamic tile server in between.
Consequence: `compose.yml`'s `server` service is plain nginx with no
application logic; adding a backend or database to "make it easier" would
invalidate the experiment's premise, not improve it.

## D5 — Building features only, LOD1 in the baseline; higher detail is optional and isolated

**Status:** Accepted (docs/scope.md, docs/limitations.md)

Roads, terrain, bridges, vegetation, land use, water bodies, and underground
structures are excluded from baseline scope. LOD2+/textures are Phase 7,
explicitly separated so that "Phase 7 failed" never invalidates the Phase 1–6
conclusions. Consequence: `tools/inspect_citygml.py` and the fixture
(`data/fixtures/test_building.gml`) only need to understand `bldg:Building`
elements — don't expand them speculatively to handle other CityGML feature
types.

## D6 — Four claims evaluated independently; never collapsed to one verdict

**Status:** Accepted (docs/hypothesis.md, docs/test-plan.md)

Conversion feasibility, determinism, reproducibility, and practical
consumption are tracked as four separate claims with independent pass
criteria (`docs/findings.md`'s summary table has one row per claim). This was
a deliberate choice to avoid the trap of a single "it works" / "it doesn't"
headline that would hide, e.g., "conversion works but isn't deterministic."
Consequence: any tool or report that touches findings (`compare_manifests.py`,
`docs/findings.md`) must preserve this separation — don't add a rollup
pass/fail field.

## D7 — Determinism threshold: Level 2 (structural, post-normalization) required; Level 1 (byte-identical) is a bonus, not the bar

**Status:** Accepted (docs/determinism.md)

Three repeatability levels are defined; only Level 2 or better counts as a
determinism pass. Non-semantic differences (JSON key order, embedded
timestamps, binary padding, compression details) are normalized away by
`tools/normalize.py` before comparison; anything structural (paths, subtree
boundaries, availability, feature-to-tile assignment, bounding volumes) must
not change between builds. Consequence: `tools/normalize.py` is
determinism-critical infrastructure — treat gaps in what it normalizes (e.g.
its current lack of GLB mesh/accessor-level comparison, see HANDOVER.md) as
directly undermining the D7 claim, not as a minor tooling nit.

## D8 — Source data policy: never fabricate; unresolved values must fail loudly

**Status:** Accepted (docs/data-selection.md)

Every source-data field (dataset identifier, download URL, checksum, version,
feature counts) must be either a real, verified value or the literal sentinel
`TBD_VERIFIED_SOURCE_REQUIRED`. Every script that consumes such a field
(`scripts/fetch.sh`, `scripts/build.sh`, `Dockerfile`'s build-time `RUN`) is
required to detect the sentinel and `exit 1` with a clear message rather than
proceeding. Consequence: this is a hard constraint on any future script that
reads config — "just try it and see if it downloads something" is not an
acceptable fallback for an unresolved URL.

## D9 — Respectful positioning toward commercial services and upstream tools

**Status:** Accepted (docs/respectful-positioning.md, CONTRIBUTING.md)

This experiment deliberately does not name, rank, or criticize commercial 3D
city data conversion/delivery services, and reports any Mago 3DTiler or
CesiumJS limitations as specific, reproducible, version-pinned findings rather
than negative characterizations. A preferred/avoided term list is maintained
in `docs/respectful-positioning.md`. Consequence: PRs or docs that frame this
project as an "alternative to X" or "escape from vendor lock-in" are a tone
violation, not a style nit — ask before merging language like that.

## D10 — CC0 for repository code; PLATEAU/Mago attribution preserved separately

**Status:** Accepted (LICENSE, NOTICE)

Scripts, config, tools, viewer, and docs in this repo are released under CC0
1.0 Universal. PLATEAU CityGML datasets remain CC BY 4.0 (attribution: 国土交通省
Project PLATEAU) and are never committed to the repo — only download scripts
and a small synthetic fixture are. Mago 3DTiler and CesiumJS are credited to
their respective projects in `NOTICE`. Consequence: don't commit real PLATEAU
archives to git even "temporarily"; `data/source/` and `data/output/` are
gitignored by design (D8/D5 territory too — reproducibility depends on
re-fetching from the authoritative source, not from a repo copy).

## D11 — Grep/sed-based YAML field extraction in shell scripts, no `yq` dependency

**Status:** Accepted, revisit if it keeps causing bugs

`scripts/fetch.sh` and `scripts/build.sh` extract single YAML field values
with `grep`/`sed` rather than depending on `yq` (not guaranteed present) or
shelling out to Python/PyYAML for every field lookup. This keeps the
dependency footprint minimal (`docs/scope.md`'s "portable Bash scripts"
requirement) but is fragile: it assumes fixed 2-space indentation and
non-overlapping key names across YAML sections. The PR #1 review found this
already causing a real bug — `scripts/build.sh`'s `grep "^  image:"` matches
both `mago.image:` and `java.image:` in `config/common.yml` and only resolves
correctly because of section ordering (see HANDOVER.md). Consequence: if a
second instance of this fragility surfaces, promote to a shared
`scripts/lib/yaml.sh` helper (as suggested in the PR #1 review) rather than
patching each script's grep pattern independently — don't relitigate "add a
real YAML parser dependency" without raising it with the user first, since the
zero-dependency constraint was a deliberate scope choice.

## D12 — CI runs lint + fixture tests only; no live pipeline execution in CI

**Status:** Accepted (`.github/workflows/ci.yml`, `CONTRIBUTING.md`)

`.github/workflows/ci.yml` runs fixture tests, shellcheck, flake8, YAML
validation, and doc-existence checks on every PR — all reachable without
Docker or network access. It deliberately does **not** run `make build` or
`make experiment` against real PLATEAU data, since that needs Docker, a
multi-hundred-MB download, and isn't reproducible on shared CI runners.
Consequence: **a green CI run proves the scaffolding is internally
consistent, not that the pipeline works end-to-end.** Bugs that only manifest
when `make build`/`make experiment` actually runs (several were found in the
PR #1 review — see HANDOVER.md) are invisible to CI by design. Don't treat
"CI is green" as equivalent to "the pipeline works" when reviewing future PRs
against this repo.

## D13 — PR #1 (bootstrap scaffold) merged first, pipeline bugs fixed immediately after on `main`

**Status:** Accepted, 2026-08-24/25

PR #1 added the entire experiment scaffold to what was previously an empty
stub repo. A review surfaced 6 confirmed and 4 plausible bugs in the
pipeline scripts/tools (a Muroran config key mismatch that broke its
small-profile build, an `eval`-based Docker command construction with
unsanitized `$DATASET`, a viewer that 404'd against any real build, a
YAML/JSON manifest corruption bug, an off-by-one in the build-comparison
script, and an ambiguous config grep — plus two lower-severity issues).
Because this PR only added scaffolding to an otherwise-empty repo (no risk to
any running system) and CI passed, the decision was to merge it first and
fix the known bugs immediately afterward as direct commits to `main`
(commits `a046e8c`..`e07f092`, same day), rather than block the merge on
fixing them inline or route the fixes through a separate PR. All 6 confirmed
bugs and 2 of the plausible ones are fixed as of that push; see HANDOVER.md's
"Bugs fixed after PR #1" section for the itemized list and what's still
outstanding. Consequence: this repo's convention for a solo-maintainer
experiment is direct-to-`main` commits with clear, atomic commit messages
(one bug per commit) rather than a PR-per-fix workflow — reserve PRs for
larger or externally-contributed changes (see `CONTRIBUTING.md`'s
fork/branch/PR flow, which still applies to outside contributors).

## D14 — Mago 3DTiler CLI invocation corrected against the real tool, not just its docs

**Status:** Accepted, 2026-08-25

The pipeline as merged in PR #1 used CLI flags (`--outputType 3dtiles`,
`--tileType implicit`, `--thread`) that do not exist in mago-3d-tiler's
actual command line (confirmed by triggering
`UnrecognizedOptionException` and cross-checking `--help`/`MANUAL.md`) —
every `make build` invocation crashed immediately, in both modes, before
this was found and fixed. The real flags are `--tilingMode
explicit|implicit` (no flag needed for explicit, it's the default) and
`--multiThreadCount`; no `--outputType` is needed for CityGML input
(defaults to `b3dm`). Separately, `--input` must be a *writable* directory
(Mago throws `IOException` under a read-only mount) and PLATEAU's
`gml:pos` axis order (lat, lon, height) is incompatible with Mago's
`--crs <EPSG code>` path (silently produces wrong coordinates) — an
explicit `--proj "+proj=longlat +datum=WGS84 +axis=neu +no_defs"` is
required instead, recorded per-dataset in `config/*.yml`'s `crs.mago_proj`
field. Consequence: **trust nothing about a third-party CLI tool's flags
from documentation alone once real usage is possible** — this project's
own `docs/test-plan.md` Phase 1 exists specifically to catch exactly this
class of assumption before it propagates further; the fixes here are the
direct product of actually running Phase 1, not of re-reading the code
more carefully. See `docs/findings.md` Phase 1 for exact error text and
verification commands.

## D15 — "small" profile builds a single isolated file, staged outside the source tree

**Status:** Accepted, 2026-08-25

mago-3d-tiler's `--input` takes a directory and converts every CityGML
file found in it — there is no single-file input mode. `scripts/build.sh`
originally mounted the selected `small_file`'s *parent directory*
(`udx/bldg/`, containing all ~100–190 of that municipality's building mesh
files) directly, so every "small" build actually converted the entire
municipality (confirmed: 202 tile contents from a "one file" build).
Fixed by copying just the selected file into an isolated
`data/.build-staging/<dataset>/<build-id>/` directory before mounting it —
gitignored, since it's derived/regenerable. Consequence: if a future
change needs multiple (but not all) input files for a build profile, reuse
this staging-directory pattern rather than mounting a shared directory and
hoping Mago only picks up the intended subset.

## D16 — Pin Mago 3DTiler via JAR SHA-256 + local Docker build, not a pulled image

**Status:** Accepted, 2026-08-25 (supersedes an earlier same-session
mistake — see below)

No public Docker image exists on GHCR for mago-3d-tiler (confirmed:
`ghcr.io/gaia3d/mago-3d-tiler` → not found), so `config/common.yml`'s
original `mago.image`/`image_digest` fields were unfillable without
fabricating a value. `scripts/build.sh` was changed to build a local image
from the pinned JAR (`mago.version`/`jar_url`/`jar_sha256`) via the
existing `Dockerfile`, which independently re-verifies the JAR's SHA-256
at build time (`sha256sum --check --strict`) — this ran for real and
passed, so the pinned checksum is doubly confirmed, not just
self-reported. **Correction:** during this same investigation, a public
image was found to exist after all, but on **Docker Hub**
(`docker.io/gaia3d/mago-3d-tiler`, both `:latest` and `:1.16.2` tags,
multi-arch) — GHCR was checked, not Docker Hub, and that gap produced an
incorrect statement to the user mid-session. Decision: keep the JAR-based
local build rather than switching, since it was already implemented and
verified end-to-end, and per D2 either pinning mechanism is equally valid.
Revisit only if the local build step becomes an actual bottleneck (it
currently isn't — Docker layer caching makes repeat builds near-instant).

## D17 — Determinism/validation tooling gaps are tracked, not silently worked around

**Status:** Accepted, 2026-08-25

Running the real pipeline surfaced two tooling gaps that could have been
quietly papered over but weren't: (1) `tools/inspect_subtree.py` and
`tools/normalize.py` only decode the combined-binary `.subtree` format,
while mago-3d-tiler 1.16.2 actually emits a `.json`+`.bin` pair — both are
3D Tiles 1.1-legal, but this project's tooling only handles one, so
`make validate` currently reports "Subtree files: 0" against real output
rather than actually validating anything; and (2) `tools/normalize.py`
doesn't redact the random UUID mago-3d-tiler embeds in every GLB's
structural metadata, so a real two-build comparison reported
Repeatability L3/FAIL even though `tileset.json` and the subtree were
byte-identical and only that one embedded string differed between builds.
Decision: record both precisely in `docs/findings.md` and `HANDOVER.md`
with exact reproduction steps, rather than either (a) declaring
determinism/validation "passed" on the strength of a tool that isn't
actually checking the real content, or (b) quietly hand-waving the L3
result into a "probably fine." `docs/findings.md`'s own template already
has "Not confirmed" and "Next smallest experiment" sections for exactly
this situation — use them rather than inventing a workaround under time
pressure.

## D18 — Closed the D17 tooling gaps quickly, judged low-depth relative to their value

**Status:** Accepted, 2026-08-25

D17 flagged two tooling gaps (subtree format, GLB UUID) without fixing
them, to avoid inventing a workaround under time pressure. Revisited the
same day: the user's read was that the GLB-UUID fix specifically was
solving a problem that barely existed in substance — `tileset.json` and
the subtree were already byte-identical between builds; only a benign,
non-geometric per-run identifier differed, which `docs/determinism.md`
had already pre-classified as normalizable. The decision was still to fix
it (not skip it), on the reasoning that whether or not the *underlying*
non-determinism is "real," the *tooling's* job is to give a trustworthy
verdict — and while unfixed, every future build comparison would report
FAIL regardless of whether a real regression occurred, making the
determinism tooling useless for its actual purpose. Implemented both
fixes compactly (detect UUID-shaped property values generically via the
property table rather than hardcoding a property name; detect subtree
JSON by content shape rather than filename) and re-verified against the
same real build pair: L3/FAIL → L2/PASS, and `make validate` went from
silently passing a real Mago defect to correctly failing on it. Also
fixed while in the area: `scripts/validate.sh` wasn't gating on the
validator's own `numErrors` field, printing "VALIDATION PASSED" over a
real `METADATA_INVALID_LENGTH` error. Consequence: when a "is this worth
fixing" doubt comes up again, the standard to apply is whether leaving it
unfixed corrupts the *tooling's* verdicts going forward, not just whether
the underlying issue is severe in isolation.

## D19 — Publish real build output to tunnel.optgeo.org (Caddy static hosting), no config changes needed

**Status:** Accepted and executed, 2026-08-25

Practical consumption (Claim 4) couldn't be tested at all without a real
public host to load tiles from — `make serve` only proves same-machine
delivery. The user's own infrastructure (`tunnel.optgeo.org`: Raspberry
Pi 4B, Cloudflare Tunnel, Caddy, Martin) was offered for this. Investigated
first (`docs/tile-hosting-plan.md`) assuming Caddy config changes would be
needed; the user then supplied the actual running Caddyfile, which turned
out to already do open static file serving (`root * ./data`,
`Access-Control-Allow-Origin: *`) — no changes needed, so the drafted
`config/tunnel-optgeo.Caddyfile` was never applied. Two real,
infrastructure-specific facts had to be learned before publishing could
work: the SSH/rsync target (`jaxa.optgeo.org`) differs from the public
HTTPS host (`tunnel.optgeo.org` — a Cloudflare Tunnel detail), and files
must land under a `plateau-mago-implicit/` subdirectory of the shared
`data/` folder to avoid colliding with the many other large datasets
already there (verified read-only via `ssh`/`ls` before any write).
`scripts/publish.sh` (`PUBLISH_HOST`/`PUBLISH_URL_BASE` as separate env
vars for exactly this SSH-vs-public-host split) was built safe-by-default
(dry run unless `--execute`), verified end-to-end, then actually run for
both Sarabetsu small-profile builds — both are live and were confirmed
rendering correctly in the real GitHub Pages viewer. Consequence: treat
`PUBLISH_HOST` (SSH) and `PUBLISH_URL_BASE` (public) as independently
necessary for any future publish target with a similar tunnel/CDN front —
don't assume they're always the same hostname.

## D20 — CesiumJS pinned to latest (1.144), not the version originally shipped in the scaffold

**Status:** Accepted, 2026-08-25

`viewer/index.html` originally pinned CesiumJS 1.117 (whatever the
original PR #1 scaffold happened to use). Live debugging of "the real
published build loads but never renders" traced to CesiumJS 1.117's
implicit-tiling tile traversal never visiting the root tile — reproduced
identically with the official `CesiumGS/3d-tiles-samples` reference
tileset, confirming it's a CesiumJS defect rather than something about
Mago's output. Rather than work around it (e.g. special-casing something
in `tools/`/`scripts/` to accommodate an old, buggy viewer), the fix was
to bump to 1.144 (current latest, confirmed via the CesiumGS releases
API) — real fix, not a workaround, and directly requested by the user
("CesiumJSもMago 3DTilerも最新版を使いましょう"). Also confirmed Mago
3DTiler needed no such bump: `main` branch HEAD and the `v1.16.2` tag are
the exact same commit (`ahead_by: 0, behind_by: 0`), so v1.16.2 already is
the latest possible code, not behind an unreleased snapshot. Consequence:
default to pinning the latest release of both the viewer library and the
converter for this project, not "whatever the scaffold happened to ship
with" — re-verify both are still current at the start of any future
session that touches the viewer or the conversion pipeline.

## D21 — Approved one new Python dependency (`japan-geoid`) to fix a real vertical-datum bug, not worked around with a viewer-side hack

**Status:** Accepted, 2026-08-27

Real elevation sampling (`Cesium.sampleTerrain` against two independent,
correctly-ellipsoidal terrain services — Re:Earth Terrain and PLATEAU's
own official PLATEAU-Terrain) found buildings sitting a tight, systematic
28-34m below the real terrain surface in both municipalities. Root cause:
PLATEAU's `bldg:lod1Solid` heights are referenced to Tokyo Bay mean sea
level (confirmed against PLATEAU's own documentation), not the ellipsoid,
even though EPSG:6697 is nominally an ellipsoidal-height CRS — and
neither `scripts/build.sh`'s `--proj` CRS fix nor Mago 3DTiler itself
(confirmed via its own build log: "Geoid Model(Height Reference):
Ellipsoid" — it takes input height as already ellipsoidal) corrects for
this. Full measurement detail: `docs/findings.md` "Cross-phase follow-up:
terrain/building vertical datum mismatch."

Considered and rejected a viewer-side fix (a per-dataset constant
`modelMatrix` offset in `viewer/viewer.js`) as the "obvious" low-risk
option requiring no new dependency — rejected because (a) it's imprecise
at a municipality's edges, where the true geoid undulation drifts by
multiple meters across a single dataset's extent (confirmed: Sarabetsu's
own 5 sample points already span a 1.9m range), and (b) it only fixes
*this* viewer, not the underlying GLB data any other consumer would load.

Instead, added `tools/geoid_correct.py` (a new build-time staging step,
same shape as `tools/strip_higher_lod.py`) using the `japan-geoid`
package (MIT license, https://github.com/ciscorn/japan-geoid) — chosen
specifically because it embeds GSI's own GSIGEO2011 grid, the same geoid
model PLATEAU-Terrain and PLATEAU's officially-recommended FME
"Vertical Transformation with GSIGEO2011" workflow both use, rather than
a generic global model (EGM2008) that would introduce its own small
regional discrepancy against PLATEAU's own tooling. Per-call cost is
~0.1μs (benchmarked), so no batching/numpy dependency was needed despite
some source files having 30,000+ coordinate values.

This is the first third-party Python dependency in this project,
crossing CLAUDE.md's "standard library only" default — flagged to the
user explicitly (via `AskUserQuestion`, offering the viewer-side
alternative and a "do nothing yet" option too) before installing
anything, per CLAUDE.md's requirement to discuss new dependencies first.
Approved. Recorded in `requirements.txt` (new file) and checked (not
auto-installed) by `scripts/bootstrap.sh`. Consequence: `make build` now
has a real Python package prerequisite beyond the interpreter itself —
`docs/reproducibility.md` and any future "what does a clean clone need"
documentation should list `pip3 install -r requirements.txt` alongside
Docker/Node/etc.

Verified before rebuilding real data: ran the small-profile Muroran build
end-to-end with the new staging step wired in — the output tileset's
bounding region height (34.79-39.01m) matched the geoid-corrected source
value exactly, and independently landed in the same range as real
terrain sampled at that coastal location (~34-37m), confirming Mago
passes the corrected Z through losslessly. Rebuilt all 4 full-profile
combinations; tile content counts were unchanged from the pre-fix builds
(198/760/1259/553) — confirming the fix only shifts vertical placement,
not tiling structure — and `make validate` on all 4 shows only the
already-documented, unrelated `METADATA_INVALID_LENGTH` alignment-padding
pattern, no new error type.

## D22 — Adopted "PLATEAU Kai" as the project's display identity and a broader purpose; the GitHub repo itself is not renamed

**Status:** Accepted, 2026-08-29

The user gave this project a new display name and a broader motivating
purpose, on top of the existing narrow, rigorous research question
(D1-D21 territory), rather than replacing it. Name: **PLATEAU Kai** —
三重の意味 (three meanings): 開 (open, from open-source), 北海道の
「カイ」(Hokkaido's "kai"), and 快速の「快」(fast/speedy). Purpose
(user's own Japanese, verbatim): *"2026年最新のオープンソース技術を北海道
PLATEAU データに施し、より快速な PLATEAU 表示を目指すことで、三次元ウェブ
地図の現在位置をテストする"* — applying 2026's latest open-source
technology to Hokkaido PLATEAU data, aiming for faster PLATEAU display,
as a way to test where 3D web mapping currently stands.

Explicitly asked and confirmed via `AskUserQuestion`: the actual GitHub
repository stays at `dwg7/plateau-mago-implicit` — no rename. A repo
rename would have broken the live GitHub Pages URL
(`dwg7.github.io/plateau-mago-implicit`) and every link already recorded
in `docs/findings.md`/`HANDOVER.md`/published build records, for a
purely cosmetic gain; the user chose to keep the URL stable and treat
"PLATEAU Kai" as a display/branding name layered on top, not a literal
rename.

Design choice for how the broader purpose relates to the existing
narrow research question: additive, not a replacement. The four claims
(conversion feasibility, determinism, reproducibility, practical
consumption), the hard scope boundaries in `CLAUDE.md` (three
municipalities, LOD1 baseline, Mago-only, CesiumJS-only, no spatial
database), and the respectful-positioning guardrails in
`docs/respectful-positioning.md` are all unchanged — the new purpose
explains *why* this work matters now, the existing structure remains
*how* it continues to be evaluated rigorously. Applied consistently:
`README.md`, `CLAUDE.md`, `docs/hypothesis.md`,
`docs/respectful-positioning.md`, `CONTRIBUTING.md`, and
`CITATION.cff` all now lead with the PLATEAU Kai name/purpose, then
explicitly frame the pre-existing narrow question as the specific
methodology underneath it — not two disconnected framings competing on
the same page.

A concrete piece of "latest open-source technology": incorporating
terrain from `hfu/mapterhorn-japan-bridge` (a GSI-DEM-to-Mapterhorn-
PMTiles bridge, priority-merging Japan's best available DEM including
1m GSI DEM1A airborne-laser data) once it stabilizes — see
`docs/architecture.md`'s new "Viewer terrain" section. Checked its
actual recent commit history via `gh api` before writing this down as a
future item rather than immediate work: as of 2026-08-29 it's still
actively bug-fixing (orphaned tiles, a downsampling convergence issue),
genuinely not stable yet, consistent with the user's own "once it
stabilizes" framing. Consequence: no technical integration work is
planned now, and this isn't tracked as an open task to proactively
re-check — revisit when the user raises it again, the same way D9's
"ask before" pattern already governs unprompted scope changes.
