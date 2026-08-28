# Contributing

Thank you for your interest in this experiment. Contributions are welcome.

## Scope

This repository tests a specific, narrow question (see [README.md](README.md)).
Contributions should respect that scope.

Appropriate contributions include:

- Corrections to factual errors in documentation or manifests
- Bug fixes in scripts, tools, or the viewer
- Additional validation or inspection utilities
- Improved CI coverage with small fixtures
- Reproducibility improvements
- Clearer error messages or documentation

Out of scope:

- Adding new datasets beyond the three declared municipalities (Sarabetsu
  Village, Muroran City, Sapporo City)
- Adding support for feature types other than buildings (in the baseline)
- Replacing Mago 3DTiler with a different converter (without first establishing the baseline)
- Adding a spatial database or dynamic tile server
- Implementing MapLibre or other clients (not in the baseline)

## Development environment

```bash
make bootstrap
```

## Code style

- Shell scripts: POSIX-compatible Bash, `set -euo pipefail`
- Python: PEP 8, no new external dependencies without discussing it with
  the user first (`pip3 install -r requirements.txt` for the one
  currently in use — `japan-geoid`, for `tools/geoid_correct.py`'s
  GSIGEO2011 geoid correction; approved 2026-08-27, see `DECISIONS.md`)
- YAML: two-space indentation, quoted strings where ambiguous

## Testing

```bash
# Run fixture tests only (no network access required)
make test

# Run a full small experiment (requires network access for data download)
make experiment DATASET=sarabetsu PROFILE=small
```

CI runs fixture tests on every pull request.

## Submitting changes

1. Fork the repository.
2. Create a branch with a descriptive name.
3. Make your changes.
4. Run `make test` to verify.
5. Open a pull request with a clear description.

## Tone and language

Use English as the primary language. When a Japanese proper noun first appears
in a document, include its Japanese name in parentheses, for example:

- Muroran City (室蘭市)
- Sarabetsu Village (更別村)
- Sapporo City (札幌市)
- Ministry of Land, Infrastructure, Transport and Tourism (国土交通省)

After the first appearance, the English name may be used alone.

Use a calm, technical, empirically cautious tone. See
[docs/respectful-positioning.md](docs/respectful-positioning.md).

## Upstream issues

If you find a Mago 3DTiler behavior that appears incorrect or unexpected when
processing PLATEAU CityGML, please:

1. Create a minimal reproducible case.
2. Document expected and actual behavior.
3. Record exact version and command.
4. Open an issue on this repository describing the finding.
5. Consider preparing a respectful upstream issue for the Mago project.

Do not automatically fork the project.

## License

Contributions to repository code are released under CC0 1.0 Universal.
