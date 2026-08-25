# Information retention

## Policy

The project does not require every PLATEAU property to be reproduced in
3D Tiles output. It does require a precise account of what is retained,
transformed, simplified, or lost.

## Categories

Each property is assigned one of:

| Category | Meaning |
|---|---|
| `retained` | Present in output without change |
| `retained-encoded` | Present in output with encoding change (e.g. type conversion) |
| `normalized` | Present but normalized (e.g. string trimmed) |
| `used-for-geometry` | Used to generate geometry, not stored as attribute |
| `used-during-conversion` | Used only during conversion, not in output |
| `unsupported` | Not supported by converter |
| `intentionally-omitted` | Deliberately excluded from scope |
| `unexpectedly-lost` | Expected to be retained, found missing |
| `not-evaluated` | Not checked in this experiment |

## Properties to inspect

Checked 2026-08-25 by decoding `EXT_structural_metadata` in a real Explicit
build's GLB output (`data/RC0000.glb`, from
`udx/bldg/63437290_bldg_6697_op.gml`, default mago-3d-tiler 1.16.2
invocation, no `--attributeFilter` or attribute-mapping options passed).
The tool's default metadata schema has exactly 4 properties — `NodeName`,
`BatchId`, `FileName`, `id` — and nothing else, which is itself evidence
that any property not in that list is not retained by default, without
needing to check each one's per-feature value individually.

| Property | Source | Expected | Actual | Notes |
|---|---|---|---|---|
| `gml:id` | CityGML | retained or traceable | `unexpectedly-lost` | The `id` metadata property is a **freshly-generated random UUID per build** (e.g. `c6f4ee32-41c9-4842-b32d-2e3c68682184`), not the source `gml:id` (`bldg_c86b549e-78ae-4129-b7d5-717fa6968e57`). Also the direct cause of the Phase 3 determinism finding. |
| Building identifier | `bldg:Building/@gml:id` | retained | `unexpectedly-lost` | Same as above — no separate building-identifier property exists. |
| Measured height | `bldg:measuredHeight` | used-for-geometry or retained | `used-for-geometry` | Source value was `2` (metres); not present as a named metadata property, consistent with being consumed into the LOD1 solid's geometry instead. |
| Usage | `bldg:usage` | retained | `unsupported` (by default) | Not in the retained schema (which has only 4 generic fields); would need `--attributeFilter`/attribute-mapping options, not yet tested. |
| Storeys above ground | `bldg:storeysAboveGround` | retained | `unsupported` (by default) | Same as Usage. |
| Construction year | `bldg:yearOfConstruction` | retained | `unsupported` (by default) | Same as Usage. |
| LOD1 solid geometry | `bldg:lod1Solid` | used-for-geometry | `used-for-geometry` | Confirmed — output mesh geometry matches source envelope height range exactly (Phase 1). |
| LOD2 geometry | `bldg:lod2Solid` | used-for-geometry | `not-evaluated` | Phase 7 only; the small_file used for Phase 1/2 has LOD0+LOD1 geometry only. |
| Appearance | `app:Appearance` | unsupported or retained | `not-evaluated` | Phase 7 only. |
| Texture references | `app:ParameterizedTexture` | unsupported or retained | `not-evaluated` | Phase 7 only; source inspection (Phase 0) found 0 texture references dataset-wide anyway. |
| CRS / `srsName` | CityGML header | used-during-conversion | `used-during-conversion` | Confirmed — the source `srsName` string itself is not in the output; its meaning is consumed via `--proj` at conversion time (see `docs/findings.md` Phase 1). |
| Source filename | filesystem | not-in-source | `retained-encoded` | The `FileName` metadata property holds the exact source filename (`63437290_bldg_6697_op.gml`) — Mago does add it. |
| Municipality | config | not-in-source | `not-in-source` | Confirmed absent from the 4-property schema; not passed to Mago as an option at all currently. |
| Dataset version | config | not-in-source | `not-in-source` | Same as Municipality. |
| PLATEAU extensions | `uro:*` | unsupported or retained | `unsupported` (by default) | Not in the retained schema; the source small_file's minimal single-building record wasn't separately checked for which uro:* fields it even carries. |

## Provenance reference

If Mago does not preserve source provenance, document the result without
altering the baseline to force success.

Ideal per-feature provenance:
- Municipality code
- PLATEAU dataset identifier
- Source CityGML filename
- Original `gml:id`

## Machine-readable mapping report

`tools/inspect_citygml.py` generates a property mapping report saved to
`manifests/reports/information-retention-<dataset>.json`.

Format:

```json
{
  "schema_version": "1",
  "dataset": "sarabetsu",
  "generated_at": "<iso8601>",
  "properties": [
    {
      "name": "gml:id",
      "source_path": "@gml:id",
      "category": "not-evaluated",
      "actual_category": null,
      "notes": ""
    }
  ]
}
```

## Results

**Evaluated for Phase 1 (Explicit, Sarabetsu small_file), 2026-08-25 — see
table above.** Headline finding: mago-3d-tiler 1.16.2's default output
retains almost no PLATEAU semantic attributes. Geometry (via LOD1 solid)
and source filename are retained; `gml:id` is replaced by a random UUID
regenerated on every build (also the root cause of the Phase 3 determinism
finding); all `bldg:*` semantic attributes (usage, storeys, construction
year) and `uro:*` PLATEAU extensions are absent from the default schema.
Whether Mago has an attribute-mapping/filter option that would retain them
has not yet been tested (`--attributeFilter` exists per `--help` but is
documented as `[GISVector]`-scoped, not confirmed applicable to CityGML
input). Not yet evaluated for Implicit mode specifically (expected to
match, since the same underlying conversion logic applies, but not
independently checked) or for Muroran (Phase 5, not started).

## Reference material: what the `id` property costs in bytes (2026-08-26)

The user asked not for a decision, but for data to support one later — does
`id` (the freshly-generated random UUID discussed above, which carries no
semantic value: it isn't the source `gml:id`, and traceability back to the
source file is already fully covered by the separate `FileName` property)
justify its byte cost. Measured directly against the two real full-profile
Implicit builds, by summing the `bufferView.byteLength` of every property's
`values`/`stringOffsets`/`arrayOffsets` entries across every content GLB:

| Dataset | Files | Total raw bytes | `id` share of raw bytes | All 4 properties' share of raw bytes |
|---|---|---|---|---|
| Sarabetsu implicit full | 804 | 18,123,960 | 843,856 (**4.66%**) | 1,768,048 (9.76%) |
| Muroran implicit full | 553 | 73,333,240 | 2,238,452 (**3.05%**) | 4,681,520 (6.38%) |

That understates the real-world cost, because a random UUID is
high-entropy and compresses far worse than the geometry/repeated-string
data around it. Zeroed the `id` bufferViews in place (a proxy for removal
— actual removal would also drop the now-unused property/schema
declarations, saving marginally more) and gzip-compressed (level 6) both
versions of every file:

| Dataset | Files | gzip bytes (with `id`) | gzip bytes (`id` zeroed) | Compressed savings |
|---|---|---|---|---|
| Sarabetsu implicit full | 804 | 5,548,429 | 4,989,481 | **10.07%** |
| Muroran implicit full | 553 | 20,236,549 | 18,786,931 | **7.16%** |

So `id` costs roughly **2x its raw-byte share once compression is
accounted for** (10.07% vs 4.66% for Sarabetsu; 7.16% vs 3.05% for
Muroran) — because it's the one property in the schema that's
incompressible noise, while `NodeName`/`BatchId`/`FileName` are
low-cardinality or repeated and compress well. This is exactly what a
random UUID would be expected to do to a compressed payload; not a
surprise finding, but now a measured one. No action taken — this is
reference material for a future design decision (e.g. whether to
special-case `id` out via post-processing, or check whether Mago has a
way to omit it from the default schema), not a recommendation.
