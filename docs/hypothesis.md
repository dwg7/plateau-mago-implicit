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

**Current status:** Not evaluated

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

**Current status:** Not evaluated

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

**Current status:** Not evaluated

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

**Current status:** Not evaluated

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
