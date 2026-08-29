# Respectful positioning

## Purpose of this document

This document explains how this experiment is positioned relative to other
software, services, and standards. It is written to be clear about what is
not being claimed, evaluated, or criticized.

## What this experiment is

**PLATEAU Kai's** broader purpose is applying the latest open-source
technology to Hokkaido PLATEAU data toward faster display, as a way to
test where 3D web mapping currently stands (`DECISIONS.md` D22). That
purpose is pursued through a small, technical feasibility experiment
that asks:

> Can an independent open-source regeneration path for PLATEAU building CityGML
> to Implicit 3D Tiles be maintained under specific operational assumptions?

The guardrails below — what this experiment deliberately is not, and
the language conventions for describing it — apply just as much under
the broader purpose as they did under the narrower one.

The operational assumptions are:
- Only public source data
- A pinned open-source converter
- Static HTTP storage
- An open client (CesiumJS)

## What this experiment is not

This experiment is **not**:
- A new standard or 3D Tiles profile
- A replacement for PLATEAU CityGML
- An evaluation of commercial conversion and delivery services
- A claim that open-source tools are superior to commercial services
- A demonstration of planet-scale operation
- A production service or platform

## Specialized commercial services

Specialized commercial services for 3D city data conversion, hosting, and delivery
provide significant value:

- Engineering optimization for production workloads
- Reliability and operational support
- Integration with other commercial platforms
- Performance tuning at scale
- Professional support and SLAs

This experiment does not test, evaluate, compare, or criticize those services.
It addresses a complementary and narrower question about an independent path.

Do not read this experiment as:
- Implying commercial services are unnecessary
- Claiming that open-source tools achieve equal optimization
- Suggesting commercial services should be avoided
- Describing this path as superior to commercial alternatives

## Language preferences

Use these terms:

| Preferred | Avoided |
|---|---|
| independent regeneration path | vendor lock-in |
| open-source reference workflow | escape |
| reproducible derived delivery view | replacement |
| static delivery pattern | fake open |
| complementary implementation path | proprietary trap |
| inspectable conversion workflow | superior |
| different operational assumptions | obsolete |

## Upstream tools

Mago 3DTiler, CesiumJS, and other upstream tools are used respectfully.
If limitations are found during this experiment, they are reported as:
- Specific, reproducible findings
- Based on specific versions and commands
- Without negative characterization of the developers

Upstream issue reports, if any, will be prepared respectfully.

## Summary

This experiment tests a complementary path. It measures a specific, narrow set
of claims. It does not make broader claims about the relative merits of any
approach to 3D city data delivery.
