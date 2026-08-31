# Tile hosting plan

**Status: accepted, executed, and — as of 2026-08-31 — migrated to a new
host.** This file's body below is largely the original 2026-08-25 design
document for the first target, `tunnel.optgeo.org` (see D19); most of it
(rsync mechanism, directory layout convention, "no credentials in the
repo" constraints) is unchanged and still accurate. **The live target is
now `depot.optgeo.org`** (SSH: `spacex.optgeo.org`), not
`tunnel.optgeo.org` — the original host went offline (GitHub issue #4)
and all 6 dataset/mode full-profile combinations were rebuilt and
re-published to the new host the same day. Full rationale: `DECISIONS.md`
D23. Read "Target" below as describing the *original* host for context;
current real values live in `.env`/`.env.example` and
`viewer/viewer.js`'s `VIEWPOINTS`.

## Why

Right now, "practical consumption" (Claim 4 — see `docs/hypothesis.md`)
can't be tested at all: the only way to view real build output is
`make serve` on the same machine that built it. Hosting a real build
somewhere public and reachable is what actually lets Claim 4 be evaluated,
and lets the GitHub Pages viewer (`https://dwg7.github.io/plateau-mago-implicit/`)
load something real instead of only accepting a manually-pasted URL.

## Target: tunnel.optgeo.org

Per the user's own public writeup (dev.to, "UN Smart Maps Group ポータブル
ウェブの進捗まとめ 2025-09") and the site's own front page, this instance
is:

- **Hardware:** Raspberry Pi 4B + USB-attached SSD (a home device, not a
  commercial CDN origin — see "Constraints" below).
- **Stack, front page ← back:** Cloudflare CDN → Cloudflared (Cloudflare
  Tunnel; no forwarded ports needed) → Caddy (reverse proxy + static file
  hosting) → Martin (tile server for PMTiles).
- **Currently exposed:** the site root links to `/martin/catalog` — Martin
  is serving PMTiles/vector-tile content today. **Martin has no 3D Tiles
  support** (confirmed: it's a PMTiles/PostGIS vector-tile server, per
  MapLibre's own docs — no mention of glTF/GLB/3D Tiles anywhere in its
  source list handling). Our output must go through **Caddy's static file
  serving**, not Martin, since 3D Tiles here is exactly "ordinary static
  files" by design (`docs/scope.md`: no dynamic tile server required).

This detail matters: it means hosting our tiles doesn't need a new
service on the Pi, just a new static-file route in the existing Caddy
config, alongside whatever else it already serves.

## What to publish (recommend: start smallest, prove the path, then decide about more)

1. **First: Sarabetsu small-profile Explicit + Implicit** — the exact
   builds already verified in `docs/findings.md` Phase 1/2. Tiny (a few
   KB), already known-correct, lowest risk. This is a "does the publish
   path actually work" test, not a real dataset delivery.
2. **Not yet, and not without a separate decision:** full-profile output
   (whole-municipality). Phase 4/6 haven't started; full-profile builds
   have never been run even locally. Don't bundle "set up hosting" with
   "also do the first full build" — different scope, different risk (much
   larger transfer, first real test of Mago at scale).

## Proposed URL / directory layout

Mirror the existing local convention exactly, so publishing is a
predictable, mechanical copy — not a redesign:

```
https://tunnel.optgeo.org/plateau-mago-implicit/<dataset>/<mode>/<profile>/<build-id>/tileset.json
https://tunnel.optgeo.org/plateau-mago-implicit/<dataset>/<mode>/<profile>/latest/tileset.json   ← symlink, same idea as scripts/build.sh's local "latest"
```

`/plateau-mago-implicit/` as the top-level path keeps this project's
files clearly namespaced on what's shared infrastructure hosting other
things too (Martin's catalog, presumably other UN Smart Maps Group work).
Final path is the user's call — this is just the proposed default,
matching the repo name.

## Caddy config addition — written, not applied: `config/tunnel-optgeo.Caddyfile`

The full draft config now lives in
[`config/tunnel-optgeo.Caddyfile`](../config/tunnel-optgeo.Caddyfile) as a
reviewable, standalone file (same treatment as `config/nginx.conf`) rather
than only prose here. It mirrors `config/nginx.conf`'s existing MIME/CORS
design exactly (same Content-Types, same `.subtree`/`.bin`-is-binary fix
from this project's own history) — no new policy invented, just the same
rules on a different server. `Access-Control-Allow-Origin` is scoped to
the GitHub Pages origin specifically rather than `*`, since this is
someone's personal infrastructure, not a project-owned CDN.

**This file must be reviewed and applied by the user (or with the user's
explicit go-ahead) directly on that machine — Claude has no access to it
and won't attempt to.**

## Publish mechanism — written, not executed: `scripts/publish.sh`

`scripts/publish.sh <dataset> <mode> <profile> [--execute]` (also
reachable as `make publish DATASET=... MODE=... PROFILE=... [EXECUTE=1]`)
now exists and does what was planned:

1. Resolves the local `latest` build under
   `data/output/<dataset>/<mode>/<profile>/`.
2. `rsync`s that build's directory to the remote host, then updates a
   `latest` symlink on the remote side too via `ssh`. Target
   host/path/user come from `PUBLISH_HOST`/`PUBLISH_PATH`/`PUBLISH_USER`
   in the environment (see `.env.example`) — never hardcoded, so no
   credentials or host details live in the repo. Auth is whatever the
   invoking machine's own SSH config already provides; the script never
   handles a password or key itself.
3. Writes `manifests/reports/published-<build-id>.json` (published host,
   remote path, timestamp, SHA-256 of the root `tileset.json`, which local
   build manifest it came from) — same "record everything" discipline as
   the rest of this project's manifests.

**Safe by default:** without `--execute`, it only prints the exact `rsync`
command it would run and exits — nothing is transferred. Verified
2026-08-25 against the real Sarabetsu Implicit build: correctly refuses
to run without `PUBLISH_HOST`/`PUBLISH_PATH` set, and correctly no-ops
(dry run only) with a fake host until `--execute` is passed.

**Still requires:** real SSH access to the Pi, which Claude does not have
and will not ask the user to hand over. The actual first real publish
(`--execute` against the real `tunnel.optgeo.org`) is a manual step the
user runs themselves, or explicitly asks Claude to run only once access is
arranged in a way that doesn't involve sharing secrets with Claude.

## Once real data is actually hosted (follow-up, separate step)

- Update `viewer/viewer.js`'s `VIEWPOINTS[*].tilesetUrl` from the current
  same-origin `/tiles/...` paths to the real
  `https://tunnel.optgeo.org/plateau-mago-implicit/...` URLs, so the
  GitHub Pages-hosted viewer's dataset dropdown actually resolves instead
  of requiring the custom-URL field.
- Verify with `curl -I` (Content-Type, CORS, Accept-Ranges headers) and
  then in a real browser via the GitHub Pages viewer — same verification
  pattern already used for the local nginx setup in `docs/findings.md`.
- Record this as a real Claim 4 (practical consumption) data point in
  `docs/findings.md`, not just as infrastructure setup.

## Constraints and things to flag to the user before executing anything

- This is a **home Raspberry Pi behind a personal Cloudflare Tunnel**, not
  provisioned infrastructure for this project. Treat availability/bandwidth
  as best-effort — matches `docs/limitations.md`'s existing "no production
  reliability, SLA, or scale testing" stance; don't let hosting here imply
  otherwise in any docs/findings write-up.
- It's **shared** infrastructure (Martin's catalog already lives there,
  presumably other UN Smart Maps Group work too) — namespacing under
  `/plateau-mago-implicit/` and scoping CORS to the specific GitHub Pages
  origin are both about being a good neighbor on shared infra, not just
  technical defaults.
- No credentials, tokens, or SSH keys should be typed into or handled by
  Claude at any point in this flow — deployment execution is either done
  by the user directly, or via a mechanism (e.g. a GitHub Actions secret)
  that never exposes the secret to Claude.
- Confirm before first execution: exact remote path, whether
  `Access-Control-Allow-Origin` should be scoped to the Pages origin only
  or left open, and whether small-profile-only is the right starting
  scope (recommended above) or the user wants something else.
