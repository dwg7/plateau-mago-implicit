# Data directory

This directory holds source data and generated outputs.

**Do not commit source data or generated output files.**

The `.gitignore` excludes `source/` and `output/` directories.
Use `make fetch DATASET=<name>` to download source data.
Use `make build DATASET=<name> MODE=<mode> PROFILE=<profile>` to generate outputs.

## Directory layout

```
data/
├── README.md          — this file
├── input-manifest.yml — source dataset declarations
├── fixtures/          — small committed test fixtures (licensed and sized appropriately)
├── source/            — downloaded source data (not committed)
└── output/            — generated 3D Tiles outputs (not committed)
```

## Fixtures

Small test fixtures may be committed to `data/fixtures/` when:
- Licensing permits (CC BY 4.0 or more permissive, attribution maintained)
- File size is small (a few hundred KB at most)
- The fixture serves a specific CI or unit test purpose

Do not commit municipal-scale datasets or outputs.

## Attribution

All PLATEAU source data used in this experiment is attributed to:

> 国土交通省 Project PLATEAU  
> https://www.mlit.go.jp/plateau/

See [../NOTICE](../NOTICE) for full attribution.
