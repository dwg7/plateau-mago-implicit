# Data selection

## Policy

For each municipality, select a specific, versioned PLATEAU release.
Record all fields below. Never fabricate or estimate values.
Use `TBD_VERIFIED_SOURCE_REQUIRED` for unresolved values.

## Sarabetsu Village (更別村)

| Field | Value |
|---|---|
| Municipality name (English) | Sarabetsu Village |
| Municipality name (Japanese) | 更別村 |
| Municipality code | 01639 |
| Prefecture | Hokkaido (北海道) |
| PLATEAU dataset identifier | TBD_VERIFIED_SOURCE_REQUIRED |
| Source catalog URL | https://www.geospatial.jp/ckan/organization/mlit-plateau |
| Download URL | TBD_VERIFIED_SOURCE_REQUIRED |
| Dataset year | TBD_VERIFIED_SOURCE_REQUIRED |
| PLATEAU spec version | TBD_VERIFIED_SOURCE_REQUIRED |
| CityGML version | TBD_VERIFIED_SOURCE_REQUIRED |
| Archive name | TBD_VERIFIED_SOURCE_REQUIRED |
| Archive SHA-256 | TBD_VERIFIED_SOURCE_REQUIRED |
| Archive size (bytes) | TBD_VERIFIED_SOURCE_REQUIRED |
| License | CC BY 4.0 |
| Attribution | 国土交通省 Project PLATEAU |
| Selected building files | TBD_VERIFIED_SOURCE_REQUIRED |
| Reason for file selection | TBD_VERIFIED_SOURCE_REQUIRED |

### Selection rationale

Sarabetsu Village (更別村) is selected because:
- It is a small rural municipality with a limited building count
- Smaller datasets establish parsing and workflow before scaling
- It provides a repeatable, low-cost baseline for determinism testing

## Muroran City (室蘭市)

| Field | Value |
|---|---|
| Municipality name (English) | Muroran City |
| Municipality name (Japanese) | 室蘭市 |
| Municipality code | 01205 |
| Prefecture | Hokkaido (北海道) |
| PLATEAU dataset identifier | TBD_VERIFIED_SOURCE_REQUIRED |
| Source catalog URL | https://www.geospatial.jp/ckan/organization/mlit-plateau |
| Download URL | TBD_VERIFIED_SOURCE_REQUIRED |
| Dataset year | TBD_VERIFIED_SOURCE_REQUIRED |
| PLATEAU spec version | TBD_VERIFIED_SOURCE_REQUIRED |
| CityGML version | TBD_VERIFIED_SOURCE_REQUIRED |
| Archive name | TBD_VERIFIED_SOURCE_REQUIRED |
| Archive SHA-256 | TBD_VERIFIED_SOURCE_REQUIRED |
| Archive size (bytes) | TBD_VERIFIED_SOURCE_REQUIRED |
| License | CC BY 4.0 |
| Attribution | 国土交通省 Project PLATEAU |
| Selected building files | TBD_VERIFIED_SOURCE_REQUIRED |
| Reason for file selection | TBD_VERIFIED_SOURCE_REQUIRED |

### Selection rationale

Muroran City (室蘭市) is selected because:
- It is an urban coastal city with terrain variation, sloped areas, and denser buildings
- It tests more demanding subtree organization, height handling, and CesiumJS behavior
- It is in the same PLATEAU program and uses the same CityGML structure as Sarabetsu
- Comparing Sarabetsu and Muroran explains how spatial distribution affects tiling behavior

## Source data policy

- Prefer immutable or version-specific URLs
- If only a `latest` or redirecting URL is available, resolve and record the actual target
- Do not commit full PLATEAU datasets to Git
- Download scripts and manifests are provided
- Small fixtures may be committed only when licensing and size permit
- Never fabricate URLs, checksums, versions, or feature counts

All unresolved values must remain as `TBD_VERIFIED_SOURCE_REQUIRED`.
Scripts fail safely when these values are present.
