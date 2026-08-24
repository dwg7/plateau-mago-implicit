# Performance

## Overview

Performance measurements are collected from the declared test environment.
Do not invent universal thresholds before collecting evidence.
Record baseline values; label later thresholds as experiment-specific.

## Test environments

### Development profile

- Hardware: local machine (record CPU, RAM, OS, browser)
- Server: local static HTTP server
- Network: loopback only
- Browser: record browser and version

### Reference web profile

- Hardware class: TBD (to be documented after baseline)
- Browser: TBD
- Viewport: TBD
- Network assumption: TBD
- Camera path: predefined viewpoints (see dataset config)

## Conversion performance

Measurements for each build:

| Dataset | Profile | Mode | Source size | Build time | Peak memory | Output size | File count |
|---|---|---|---|---|---|---|---|
| sarabetsu | small | explicit | TBD | TBD | TBD | TBD | TBD |
| sarabetsu | small | implicit | TBD | TBD | TBD | TBD | TBD |
| sarabetsu | full | implicit | TBD | TBD | TBD | TBD | TBD |
| muroran | small | explicit | TBD | TBD | TBD | TBD | TBD |
| muroran | small | implicit | TBD | TBD | TBD | TBD | TBD |
| muroran | full | implicit | TBD | TBD | TBD | TBD | TBD |

## CesiumJS consumption measurements

### Initial use

- Time to first visible building
- Time to first useful view
- Transferred bytes (initial)
- Request count (initial)
- Blank period duration

### Navigation (pan, orbit, zoom, tilt)

- Approximate frame time during motion
- Gaps, popping, duplicates, or missing geometry
- Time for detail to settle after motion stops

### Geographic jump

- Time to begin rendering
- Subtree and content request count
- Convergence behavior

### Revisit

- Cache hit behavior
- Repeated request count

### Long session (30+ minutes)

- Memory trend (JavaScript heap)
- Responsiveness
- Request failures
- Browser or rendering errors

## Obvious failure criteria

Any of these constitutes an obvious failure:

- No useful view after reasonable wait
- Persistent missing subtrees or visible holes
- Request activity that never settles
- Browser failure or crash
- Continual unexplained memory growth
- Severe interaction stalls (>5 s for common operations)
- Incorrect geographic placement
- Invalid tile content
- Unexplained differences between repeated builds

## Results

*Not yet evaluated. This section will be filled as phases complete.*
