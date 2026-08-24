# Reproducibility

## Goal

A third party should be able to reproduce this experiment from public source data
and this repository, obtaining structurally equivalent results.

## Requirements

### Source data

- Source versions must be immutable and recorded
- Checksums must be recorded and verified before conversion
- Only public source data is used
- Download scripts are provided

### Tool versions

- Mago 3DTiler: pinned by Docker image digest or JAR SHA-256
- Java: version recorded
- Python: version recorded
- Node.js: version recorded
- Validators: versions recorded

All versions are in `config/common.yml`.

### Commands

- Exact commands are recorded in build manifests
- No undocumented steps or manual interventions

### Environment

- OS, architecture, CPU count, and memory limits are recorded
- Environment variables affecting conversion are recorded
- No cloud-specific infrastructure required

### Manifests

Build manifests are generated automatically and stored in `manifests/builds/`.
They record everything needed to reproduce or audit a build run.

## Reproduction steps

```bash
# 1. Clone the repository
git clone https://github.com/dwg7/plateau-mago-implicit.git
cd plateau-mago-implicit

# 2. Install prerequisites
make bootstrap

# 3. Resolve TBD_VERIFIED_SOURCE_REQUIRED values
#    Edit data/input-manifest.yml and config/sarabetsu.yml
#    (and config/muroran.yml for Muroran City)

# 4. Run the experiment
make experiment DATASET=sarabetsu PROFILE=small
```

## Build manifest schema

Each manifest records:

```yaml
schema_version: "1"
build_id: "<uuid>"
municipality: "sarabetsu"
dataset_identifier: "<plateau-id>"
mode: "implicit"
profile: "small"
source_files:
  - path: "<relative-path>"
    sha256: "<checksum>"
mago_version: "<version>"
mago_image_digest: "<sha256:...>"
java_version: "<version>"
os: "<os>"
arch: "<arch>"
cpu_count: <n>
memory_limit_mb: <n>
command: "<exact command>"
env_vars: {}
started_at: "<iso8601>"
ended_at: "<iso8601>"
duration_seconds: <n>
return_code: <n>
output_mode: "implicit"
output_file_count: <n>
output_total_bytes: <n>
root_tileset_sha256: "<checksum>"
root_tileset_bytes: <n>
subtree_count: <n>
content_count: <n>
validation_status: "<pass|fail|not-run>"
validation_log: "<relative-path>"
normalized_manifest_sha256: "<checksum>"
git_commit: "<sha>"
git_dirty: <true|false>
warnings: []
```

## What "reproduced" means

A reproduction is successful when:
1. Source checksums match
2. Build completes without error
3. Output reaches Level 2 repeatability or better (see `docs/determinism.md`)
4. Validation passes
5. CesiumJS loads and renders the output

It is not required that output be byte-identical to a reference build
(Level 2 is sufficient).

## Known reproducibility limitations

- Non-deterministic behavior in Mago (if any) is documented in `docs/determinism.md`
- Platform-specific differences (if any) are recorded
- Timestamp fields in output are non-semantic and normalized away

## Record-keeping

All manifests, logs, and reports are preserved under `manifests/`.
Raw validator output is not suppressed.
