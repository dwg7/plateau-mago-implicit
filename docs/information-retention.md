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

| Property | Source | Expected | Actual | Notes |
|---|---|---|---|---|
| `gml:id` | CityGML | retained or traceable | TBD | |
| Building identifier | `bldg:Building/@gml:id` | retained | TBD | |
| Building part identifier | `bldg:BuildingPart/@gml:id` | retained | TBD | |
| Measured height | `bldg:measuredHeight` | used-for-geometry or retained | TBD | |
| Usage | `bldg:usage` | retained | TBD | |
| Storeys above ground | `bldg:storeysAboveGround` | retained | TBD | |
| Construction year | `bldg:yearOfConstruction` | retained | TBD | |
| LOD1 solid geometry | `bldg:lod1Solid` | used-for-geometry | TBD | |
| LOD2 geometry | `bldg:lod2Solid` | used-for-geometry | TBD | Phase 7 only |
| Appearance | `app:Appearance` | unsupported or retained | TBD | Phase 7 only |
| Texture references | `app:ParameterizedTexture` | unsupported or retained | TBD | Phase 7 only |
| CRS / `srsName` | CityGML header | used-during-conversion | TBD | |
| Source filename | filesystem | not-in-source | TBD | Check if Mago adds |
| Municipality | config | not-in-source | TBD | Check if Mago adds |
| Dataset version | config | not-in-source | TBD | Check if Mago adds |
| PLATEAU extensions | `uro:*` | unsupported or retained | TBD | |

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

*Not yet evaluated. This section will be filled after Phase 1.*
