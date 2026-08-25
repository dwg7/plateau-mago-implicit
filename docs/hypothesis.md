# Hypothesis

## Research question

> Can building data from Project PLATEAU CityGML for Muroran City (室蘭市) and
> Sarabetsu Village (更別村) be converted into Implicit 3D Tiles using Mago 3DTiler
> in a deterministic and reproducible manner, and then consumed comfortably with
> CesiumJS from ordinary static HTTP storage?

## Four claims under evaluation

### Claim 1: Conversion feasibility

**Statement:** Mago 3DTiler can parse selected PLATEAU building CityGML, produce
valid 3D Tiles 1.1 with Implicit Tiling, and achieve reasonable geometry, geographic
placement, bounding volumes, and heights.

**Evaluation criteria:**
- CityGML parses without unexplained fatal loss
- Implicit output is generated and validates independently
- CesiumJS loads the output
- Buildings appear in the expected geographic location
- Vertical placement is reasonable or explained

**Current status:** Partially confirmed (2026-08-25, Sarabetsu small_file
only). CityGML parses without fatal loss; Explicit output fully verified
(correct geographic placement and height, once a CRS/axis-order fix was
applied). Implicit output generated and geographically correct.
**CesiumJS loads and renders it correctly** — but only after upgrading
the viewer from CesiumJS 1.117 to 1.144, since 1.117 has an implicit-tiling
traversal bug reproduced with both this project's own data and the
official CesiumGS sample tileset (see `docs/findings.md` Phase 2). The one
still-unmet criterion is "validates independently": `3d-tiles-validator`
reports a real `METADATA_INVALID_LENGTH` finding whose severity is itself
ambiguous pending a spec-conformance check (see Phase 1/2). See
`docs/findings.md` Phase 1/2 for full detail.

---

### Claim 2: Determinism

**Statement:** Repeated builds from identical source data, converter version,
configuration, and environment produce stable output paths and logical content.
Non-semantic differences are separated from structural differences.

**Evaluation criteria:**
- Repeated builds reach Level 2 (structurally identical after documented
  normalization) or better
- Paths, hierarchy, availability, and identifiers are stable
- Unexplained structural changes do not occur

**Repeatability levels:**
- **Level 1:** Byte-identical
- **Level 2:** Structurally identical after documented normalization
- **Level 3:** Semantically equivalent but structurally different
- A deterministic pass requires Level 2 or better

**Current status:** Not evaluated formally — a preliminary, informal
two-build comparison (2026-08-24) returned Level 3/FAIL, but was
root-caused to a single non-semantic artifact (a random UUID Mago embeds
in GLB metadata) that this project's own normalization tooling doesn't yet
handle. Believed to be a tooling false-negative, not evidence of genuine
non-determinism, but not yet confirmed by fixing the tooling and
re-running the formal procedure. See `docs/findings.md` Phase 3.

---

### Claim 3: Reproducibility

**Statement:** A third party can reproduce the experiment from public source data
and repository instructions. Source versions, checksums, converter digest, options,
logs, and manifests are recorded.

**Evaluation criteria:**
- Source and tool versions are immutable and recorded
- Checksums and commands are recorded in build manifests
- A clean environment can reproduce the build
- Manifests and reports are generated automatically

**Current status:** Partially confirmed (2026-08-25). Source archive
checksums are independently re-verified by `scripts/fetch.sh` on every
run (not just recorded); the Mago 3DTiler JAR's checksum is independently
re-verified by `Dockerfile`'s own build-time check. Commands and output
checksums are recorded in real build manifests under `manifests/builds/`.
Not yet tested: reproducing this repo's Phase 1 build from a genuinely
clean environment (all verification so far has been on the machine that
also did the original fetch).

---

### Claim 4: Practical consumption

**Statement:** Outputs work through ordinary static HTTP delivery. CesiumJS can
traverse and render them without a custom backend. Loading, navigation, geographic
jumps, refinement, and memory behavior are acceptable for the declared test
environment.

**Evaluation criteria:**
- Static HTTP works without a custom backend
- Relative URIs, CORS, and MIME types are correct
- No persistent missing subtrees or content requests
- The viewer reaches a useful view
- Navigation is responsive for the declared profile
- Geographic jumps converge
- No persistent geometry gaps
- Long-session test completes without browser failure
- Metrics and observations are recorded

**Current status:** Partially confirmed (2026-08-25). Static HTTP delivery
works without a custom backend: a real Explicit+Implicit build was
published to a real public static host (tunnel.optgeo.org, via Caddy +
Cloudflare Tunnel) and loaded correctly over real HTTPS/CORS by the
GitHub Pages-hosted viewer, in a real browser, with no console errors.
Correct MIME types confirmed by `curl -I` (`.json`→application/json,
`.glb`→model/gltf-binary). **"The viewer reaches a useful view" now has
real, user-confirmed evidence**: an initial version of the predefined
geographic-jump viewpoint was miscalibrated (14.2 km/2.7 km off the real
building), so the page loaded but showed nothing — caught by the user
directly, fixed, and re-confirmed by the user in their own browser
(single building now visible). Only tested against the smallest possible
dataset (one building) — navigation responsiveness beyond the initial
jump, long-session memory behavior, and timing metrics are all still
untested at any real scale. See `docs/findings.md` Phase 2.

---

## Approach

1. Test Sarabetsu Village (更別村) first (smaller, simpler)
2. Establish Explicit output as the control before testing Implicit
3. Validate independently, not only through CesiumJS rendering
4. Record all tool versions, checksums, commands, and outputs
5. Test Muroran City (室蘭市) after Sarabetsu workflow is stable

## What is not claimed

- No planet-scale capability is claimed
- No comparison to or evaluation of commercial services
- No claim that 3D Tiles are an archival format
- No claim that CesiumJS is the only legitimate client
- No pre-filled positive conclusions
