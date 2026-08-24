# Performance

## Overview

Performance measurements are collected from the declared test environment.
Do not invent universal thresholds before collecting evidence.
Record baseline values; label later thresholds as experiment-specific.

## Test environments

### Development profile

- Hardware: Apple M1 (arm64), 8 GB RAM, macOS 26.6.2 (build 25G83) —
  recorded 2026-08-25 for the conversion-performance rows below
- Server: local static HTTP server
- Network: loopback only
- Browser: not yet recorded — CesiumJS viewer not yet exercised in a real
  browser against real build output

### Reference web profile

- Hardware class: TBD (to be documented after baseline)
- Browser: TBD
- Viewport: TBD
- Network assumption: TBD
- Camera path: predefined viewpoints (see dataset config)

## Conversion performance

Measurements for each build:

Real values below are from a single MacBook (Apple Silicon, arm64) run,
2026-08-25, `--multiThreadCount 1`, JAVA_OPTS default (`-Xmx4g`) — not a
declared reference environment, and peak memory was not measured (would
need `docker stats` or JVM flags not currently captured by
`scripts/build.sh`). Full-profile rows are genuinely untested — Phase 4/6
haven't started.

| Dataset | Profile | Mode | Source size | Build time | Peak memory | Output size | File count |
|---|---|---|---|---|---|---|---|
| sarabetsu | small | explicit | 8,455 bytes | 2s | not measured | 10,353 bytes | 3 |
| sarabetsu | small | implicit | 8,455 bytes | 1s | not measured | 5,671 bytes | 4 |
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
