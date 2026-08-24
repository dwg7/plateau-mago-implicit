# Tile hosting plan (draft — not executed)

**Status: planning only.** Nothing in this document has been carried out.
No files have been transferred to any external host, no remote
configuration has been changed, and no DNS/tunnel settings have been
touched. This is a design for review; execution requires the user's
explicit go-ahead, action by action (per the project's action-permission
rules — publishing to a public host is not something to do unprompted).

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

## Proposed Caddy config addition (draft, not applied)

```caddyfile
tunnel.optgeo.org {
	# ... existing Martin / other routes unchanged ...

	handle_path /plateau-mago-implicit/* {
		root * /path/on/the/pi/plateau-mago-implicit-tiles
		file_server {
			precompressed gzip
		}
		header {
			Access-Control-Allow-Origin "https://dwg7.github.io"
			Access-Control-Allow-Methods "GET, HEAD, OPTIONS"
			Access-Control-Allow-Headers "Range"
			Accept-Ranges "bytes"
		}
		@json path *.json
		header @json Content-Type "application/json"
		header @json Cache-Control "public, max-age=3600"

		@bin path *.bin *.subtree
		header @bin Content-Type "application/octet-stream"
		header @bin Cache-Control "public, max-age=3600"

		@glb path *.glb
		header @glb Content-Type "model/gltf-binary"
		header @glb Cache-Control "public, max-age=86400"
	}
}
```

Mirrors `config/nginx.conf`'s existing MIME/CORS design exactly (same
Content-Types, same `.subtree`-is-binary fix from this project's own
history) — no new policy invented, just the same rules on a different
server. `Access-Control-Allow-Origin` is scoped to the GitHub Pages origin
specifically rather than `*`, since this is someone's personal
infrastructure, not a project-owned CDN — worth the user confirming that
choice rather than defaulting to wide-open.

**This file must be reviewed and applied by the user (or with the user's
explicit go-ahead) directly on that machine — Claude has no access to it
and won't attempt to.**

## Proposed publish mechanism (draft — new script, not yet written)

A `scripts/publish.sh <dataset> <mode> <profile>` that:

1. Resolves the local `latest` build under
   `data/output/<dataset>/<mode>/<profile>/`.
2. `rsync`s that build's directory to the remote host, into both its
   `<build-id>/` path and an updated `latest` symlink — target
   host/path/user read from environment variables (e.g.
   `PUBLISH_HOST`, `PUBLISH_PATH`), never hardcoded, so no credentials or
   host details live in the repo.
3. Writes a small `manifests/reports/published-<build-id>.json` record
   (published URL, timestamp, SHA-256 of the root `tileset.json`, which
   local build manifest it came from) — same "record everything"
   discipline as the rest of this project's manifests.

**Requires:** SSH access to the Pi, which Claude does not have and will
not ask the user to hand over (per this project's standing safety rules —
credentials are handled by the user, never typed in by Claude). The
script would be built and tested locally against a harmless dry-run
target first; the actual first real publish is a manual step the user
runs themselves, or explicitly asks Claude to run only once access is
arranged in a way that doesn't involve sharing secrets with Claude (e.g.
the user runs it, or a CI secret scoped to GitHub Actions rather than
handed to Claude directly).

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
