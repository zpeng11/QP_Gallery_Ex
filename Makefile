SHELL := /bin/bash

PROJECT_DIR := $(abspath .)
ORIGINAL_DIR := $(PROJECT_DIR)/original
SOURCE_URL_FILE ?= $(ORIGINAL_DIR)/stable.url
APK := $(shell ./scripts/resolve_source_apk_path.sh $(SOURCE_URL_FILE) $(ORIGINAL_DIR))
DECODED := $(PROJECT_DIR)/decoded
UNSIGNED := $(PROJECT_DIR)/build/stable-rebuilt-unsigned.apk
ALIGNED := $(PROJECT_DIR)/build/stable-rebuilt-aligned.apk
SIGNED := $(PROJECT_DIR)/build/stable-rebuilt-signed.apk
ANALYSIS_DIR := $(PROJECT_DIR)/analysis
JADX_ROOT := $(ANALYSIS_DIR)/jadx
PATCH_DIR := $(PROJECT_DIR)/patches
PATCH_SERIES := $(PATCH_DIR)/series
DOCKER_IMAGE ?= qp-apktool:local
DOCKERFILE ?= Dockerfile
DOCKER_BUILD_ARGS ?=

.PHONY: check-env toolchain-bootstrap toolchain-refresh toolchain-status fetch-apk refresh-apk baseline patch-apply build sign rebuild-patched verify-patch verify-cifs-stage1 analysis analysis-refresh analysis-prune analysis-clean jadx docker-image docker-run docker-check-env docker-rebuild docker-verify docker-analysis docker-all docker-all-with-analysis docker-shell all all-with-analysis clean

check-env:
	./scripts/check_system_deps.sh

toolchain-bootstrap:
	./scripts/bootstrap_toolchain.sh

toolchain-refresh:
	./scripts/bootstrap_toolchain.sh --force

toolchain-status:
	@set -e; \
	USE_SYSTEM_TOOLS="$${USE_SYSTEM_TOOLS:-0}"; \
	if [[ "$$USE_SYSTEM_TOOLS" != "1" ]]; then \
		PATH="$(PROJECT_DIR)/.tooling/bin:$$PATH"; \
	fi; \
	echo "USE_SYSTEM_TOOLS=$$USE_SYSTEM_TOOLS"; \
	echo "APKTOOL_FRAMEWORK_DIR=$${APKTOOL_FRAMEWORK_DIR:-$(PROJECT_DIR)/.tooling/apktool-framework}"; \
	echo "apktool : $$(command -v apktool || echo '<missing>')"; \
	echo "aapt2   : $$(command -v aapt2 || echo '<missing>')"; \
	echo "zipalign: $$(command -v zipalign || echo '<missing>')"; \
	echo "jadx    : $$(command -v jadx || echo '<missing>')"; \
	{ command -v apktool >/dev/null 2>&1 && apktool --version | head -n 1; } || true; \
	{ command -v aapt2 >/dev/null 2>&1 && aapt2 version 2>&1 | head -n 1; } || true; \
	{ command -v zipalign >/dev/null 2>&1 && zipalign 2>&1 | head -n 1; } || true; \
	{ command -v jadx >/dev/null 2>&1 && jadx --version | head -n 1; } || true

fetch-apk:
	./scripts/fetch_source_apk.sh $(SOURCE_URL_FILE) $(ORIGINAL_DIR)

refresh-apk:
	FORCE_DOWNLOAD=1 ./scripts/fetch_source_apk.sh $(SOURCE_URL_FILE) $(ORIGINAL_DIR)

baseline: fetch-apk
	./scripts/prepare_baseline.sh $(APK) $(DECODED)

patch-apply:
	./scripts/apply_patches.sh $(PROJECT_DIR) $(PATCH_SERIES)

build:
	./scripts/build.sh $(DECODED) $(UNSIGNED)

sign:
	./scripts/sign.sh $(UNSIGNED) $(ALIGNED) $(SIGNED)

rebuild-patched: fetch-apk
	./scripts/rebuild_from_patches.sh $(APK) $(DECODED) $(UNSIGNED) $(ALIGNED) $(SIGNED) $(PATCH_SERIES)

verify-patch:
	@test -d $(DECODED)
	@rg -n "const-string v1, \"image/x-webp\"" $(DECODED)/smali/com/alensw/ui/c/as.smali $(DECODED)/smali/com/alensw/ui/c/dp.smali >/dev/null
	@rg -n "const-string v0, \"image/x-webp\"" $(DECODED)/smali/com/alensw/a/at.smali >/dev/null
	@rg -n "ImageDecoder;->createSource\\(Ljava/io/File;\\)" $(DECODED)/smali/com/alensw/b/h/r.smali >/dev/null
	@if rg -n "AnimatedImageDrawable;->getDuration\\(\\)I" $(DECODED)/smali/com/alensw/b/h/r.smali >/dev/null; then \
		echo "Unexpected getDuration() call found in r.smali" >&2; \
		exit 1; \
	fi
	@echo "Patch markers verified from $(PATCH_SERIES)"

verify-cifs-stage1:
	@test -d $(DECODED)
	@rg -n "android.intent.action.OPEN_DOCUMENT_TREE" $(DECODED)/smali/com/alensw/ui/activity/PathListActivity.smali >/dev/null
	@rg -n "takePersistableUriPermission" $(DECODED)/smali/com/alensw/ui/activity/PathListActivity.smali >/dev/null
	@if [ -f $(DECODED)/smali/com/alensw/ui/activity/bm.smali ]; then \
		echo "Unexpected stage2 class found: bm.smali" >&2; \
		exit 1; \
	fi
	@if rg -n "Lcom/alensw/ui/activity/bm;" $(DECODED)/smali/com/alensw/ui/activity/PathListActivity.smali $(DECODED)/smali/com/alensw/ui/activity/bg.smali >/dev/null 2>&1; then \
		echo "Unexpected stage2 bm references found in stage1 build" >&2; \
		exit 1; \
	fi
	@echo "CIFS stage1 markers verified"

analysis: fetch-apk
	./scripts/run_jadx_analysis.sh $(APK) $(ANALYSIS_DIR) $(SOURCE_URL_FILE)

analysis-refresh: fetch-apk
	FORCE_ANALYSIS=1 ./scripts/run_jadx_analysis.sh $(APK) $(ANALYSIS_DIR) $(SOURCE_URL_FILE)

analysis-prune:
	./scripts/prune_jadx_runs.sh $(JADX_ROOT) $(if $(KEEP),$(KEEP),3)

analysis-clean:
	rm -rf $(JADX_ROOT)

jadx: analysis

docker-image:
	docker build $(DOCKER_BUILD_ARGS) -t $(DOCKER_IMAGE) -f $(DOCKERFILE) .

docker-run:
	@if [[ -z "$(CMD)" ]]; then \
		echo "Usage: make docker-run CMD='make rebuild-patched'"; \
		exit 1; \
	fi
	DOCKER_IMAGE=$(DOCKER_IMAGE) ./scripts/docker_run.sh bash -lc '$(CMD)'

docker-check-env:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh make check-env USE_SYSTEM_TOOLS=1

docker-rebuild:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh make rebuild-patched SOURCE_URL_FILE=$(SOURCE_URL_FILE) USE_SYSTEM_TOOLS=1

docker-verify:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh make verify-patch SOURCE_URL_FILE=$(SOURCE_URL_FILE) USE_SYSTEM_TOOLS=1

docker-analysis:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh make analysis SOURCE_URL_FILE=$(SOURCE_URL_FILE) USE_SYSTEM_TOOLS=1

docker-all:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh make all SOURCE_URL_FILE=$(SOURCE_URL_FILE) USE_SYSTEM_TOOLS=1

docker-all-with-analysis:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh make all-with-analysis SOURCE_URL_FILE=$(SOURCE_URL_FILE) USE_SYSTEM_TOOLS=1

docker-shell:
	USE_SYSTEM_TOOLS=1 DOCKER_IMAGE=$(DOCKER_IMAGE) SOURCE_URL_FILE=$(SOURCE_URL_FILE) ./scripts/docker_run.sh bash

all: rebuild-patched

all-with-analysis: rebuild-patched analysis

clean:
	rm -f $(UNSIGNED) $(ALIGNED) $(SIGNED)
