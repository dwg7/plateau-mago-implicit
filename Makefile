.PHONY: bootstrap fetch inspect build validate compare serve viewer test clean experiment help

# Default target
.DEFAULT_GOAL := help

# Load environment overrides if .env exists
-include .env

DATASET     ?= sarabetsu
MODE        ?= implicit
PROFILE     ?= small
CONCURRENCY ?= 1

SCRIPTS     := scripts
TOOLS       := tools
CONFIG      := config
DATA        := data
MANIFESTS   := manifests

## bootstrap: Verify prerequisites and print environment information
bootstrap:
	@bash $(SCRIPTS)/bootstrap.sh

## fetch: Download and verify source data for DATASET
##   Usage: make fetch DATASET=sarabetsu
fetch:
	@bash $(SCRIPTS)/fetch.sh "$(DATASET)"

## inspect: Inspect source CityGML files for DATASET
##   Usage: make inspect DATASET=sarabetsu
inspect:
	@bash $(SCRIPTS)/inspect-source.sh "$(DATASET)"

## build: Convert CityGML to 3D Tiles
##   Usage: make build DATASET=sarabetsu MODE=explicit PROFILE=small
build:
	@bash $(SCRIPTS)/build.sh "$(DATASET)" "$(MODE)" "$(PROFILE)" "$(CONCURRENCY)"

## validate: Validate 3D Tiles output
##   Usage: make validate DATASET=sarabetsu MODE=implicit PROFILE=small
validate:
	@bash $(SCRIPTS)/validate.sh "$(DATASET)" "$(MODE)" "$(PROFILE)"

## compare: Compare two builds for determinism
##   Usage: make compare DATASET=sarabetsu MODE=implicit PROFILE=small
compare:
	@bash $(SCRIPTS)/compare-builds.sh "$(DATASET)" "$(MODE)" "$(PROFILE)"

## serve: Start static HTTP server for outputs
serve:
	@bash $(SCRIPTS)/serve.sh

## viewer: Open the CesiumJS viewer in a browser
viewer:
	@echo "Open viewer/index.html in a browser, or run: make serve"

## test: Run fixture tests (no network access required)
test:
	@bash tests/run-tests.sh

## clean: Remove generated outputs (preserves source data)
clean:
	@bash $(SCRIPTS)/clean.sh

## experiment: Run full small experiment for DATASET
##   Usage: make experiment DATASET=sarabetsu PROFILE=small
##   Steps: bootstrap, fetch, inspect, build (explicit+implicit),
##          validate, repeat build, compare, manifest
experiment:
	@echo "=== Running experiment: DATASET=$(DATASET) PROFILE=$(PROFILE) ==="
	@$(MAKE) bootstrap
	@$(MAKE) fetch DATASET=$(DATASET)
	@$(MAKE) inspect DATASET=$(DATASET)
	@$(MAKE) build DATASET=$(DATASET) MODE=explicit PROFILE=$(PROFILE)
	@$(MAKE) build DATASET=$(DATASET) MODE=implicit PROFILE=$(PROFILE)
	@$(MAKE) validate DATASET=$(DATASET) MODE=implicit PROFILE=$(PROFILE)
	@echo "--- Repeating implicit build for determinism check ---"
	@$(MAKE) build DATASET=$(DATASET) MODE=implicit PROFILE=$(PROFILE) CONCURRENCY=$(CONCURRENCY)
	@$(MAKE) compare DATASET=$(DATASET) MODE=implicit PROFILE=$(PROFILE)
	@bash $(SCRIPTS)/generate-manifest.sh "$(DATASET)" implicit "$(PROFILE)"
	@echo ""
	@echo "=== Experiment complete ==="
	@echo "To view results, run: make serve"
	@echo "Then open viewer/index.html in a browser."

## help: Show this help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
