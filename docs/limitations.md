# Limitations

## Declared scope limitations

- Tests two municipalities only (Sarabetsu Village and Muroran City)
- No planet-scale capability is claimed
- LOD1 buildings only in baseline
- Feature scope: building features only

## Excluded feature types

The following are excluded from the baseline:

- Roads and transportation infrastructure
- Terrain and digital elevation models
- Bridges
- Vegetation
- Urban facilities
- Land use
- Water bodies
- Underground structures
- Any other non-building feature types

Expanding feature scope requires separate investigation.

## Technical limitations

- CesiumJS is the only tested client in the baseline
- MapLibre and other clients are not tested
- No spatial database or dynamic tile server
- No production reliability, SLA, or scale testing
- No network shape testing (local loopback only in development profile)

## Data limitations

- Source data is limited to publicly available PLATEAU releases
- Source data checksums must be resolved before the experiment runs
- Source data is not committed to this repository
- Fixture files are small and may not represent full municipal complexity

## Mago 3DTiler limitations

*To be populated after Phase 0 inspection.*

Potential areas for investigation:
- PLATEAU CRS handling
- Axis order assumptions
- Height offset handling
- PLATEAU extension attribute support
- Implicit Tiling experimental status

If Mago Implicit Tiling is marked experimental in the version tested, this
will be stated accurately and neutrally.

## Validation limitations

- Validators may disagree with each other; both findings are retained
- Validator success is not proof of usability
- CesiumJS rendering success is not proof of specification conformance

## Reproducibility limitations

- Non-deterministic behavior in Mago (if any) will be documented
- Platform-specific differences (if any) will be recorded
- The experiment does not guarantee reproducibility across all platforms

## What cannot be concluded from this experiment

- That 3D Tiles are superior or inferior to other delivery formats
- That the tested approach is production-ready
- That Mago 3DTiler is the best or only suitable converter
- That CesiumJS is the only suitable client
- That two municipalities represent all PLATEAU data behavior
- That open-source tools equal commercial service quality at scale

## Non-goals

See [scope.md](scope.md) for the full non-goals list.
