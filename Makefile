SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := help

RESUME_TEX ?= src/resume.tex
SRC_DIR ?= src
BUILD_DIR ?= build
DIST_DIR ?= dist
SITE_DIR ?= site
PAGES_BASE_URL ?= https://ryancswallace.github.io/resume
UPDATED_AT ?= $(shell date -u +%Y-%m-%dT%H-%M-%S)
RELEASE_TAG ?= resume-$(UPDATED_AT)
GIT_SHA ?= $(shell git rev-parse --verify HEAD 2>/dev/null || printf unknown)

DEV_IMAGE ?= resume-dev
DOCKER_RUN = docker run --rm -v "$(CURDIR):/workspace" -w /workspace --user node $(DEV_IMAGE)

MARKDOWN_FILES ?= "**/*.md"
PRETTIER_FILES ?= "*.json" ".devcontainer/*.json" ".github/workflows/*.yml" ".markdownlint-cli2.yaml" ".vscode/*.json" "*.md"
SHELL_FILES ?= scripts/*.sh

.PHONY: help
help: ## Show this help message.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build all dist/resume.* artifacts.
	SRC_DIR="$(SRC_DIR)" \
	RESUME_TEX="$(RESUME_TEX)" \
	BUILD_DIR="$(BUILD_DIR)" \
	DIST_DIR="$(DIST_DIR)" \
	PAGES_BASE_URL="$(PAGES_BASE_URL)" \
	UPDATED_AT="$(UPDATED_AT)" \
	RELEASE_TAG="$(RELEASE_TAG)" \
	GIT_SHA="$(GIT_SHA)" \
	scripts/build-resume.sh

.PHONY: pdf
pdf: ## Compile only the PDF into the build directory.
	mkdir -p "$(BUILD_DIR)/pdf"
	TEXINPUTS="$(SRC_DIR)//:$${TEXINPUTS:-}" \
	latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error \
		-outdir="$(BUILD_DIR)/pdf" "$(RESUME_TEX)"

.PHONY: dist
dist: build check-dist ## Build and validate publishable dist artifacts.

.PHONY: ci
ci: precheck build postcheck ## Run the local equivalent of the CI build job.

.PHONY: precheck
precheck: check-source ## Run checks that do not require generated artifacts.

.PHONY: postcheck
postcheck: check-dist ## Run checks against generated artifacts.

.PHONY: check
check: check-source check-dist ## Run source checks and validate existing dist artifacts.

.PHONY: check-source
check-source: lint-shell spell lint-markdown lint-format ## Run all source quality checks.

.PHONY: lint
lint: check-source ## Alias for source quality checks.

.PHONY: lint-shell
lint-shell: ## Lint shell scripts with ShellCheck.
	shellcheck $(SHELL_FILES)

.PHONY: spell
spell: ## Spell-check tracked project text with cspell.
	cspell .

.PHONY: lint-markdown
lint-markdown: ## Lint Markdown files.
	markdownlint-cli2 $(MARKDOWN_FILES)

.PHONY: lint-format
lint-format: ## Check formatting with Prettier.
	prettier --check $(PRETTIER_FILES)

.PHONY: format
format: ## Format supported text/config files with Prettier.
	prettier --write $(PRETTIER_FILES)

.PHONY: check-dist
check-dist: ## Validate generated dist artifacts.
	DIST_DIR="$(DIST_DIR)" scripts/check-dist.sh

.PHONY: checksums
checksums: ## Recompute SHA256SUMS for generated dist artifacts.
	cd "$(DIST_DIR)" && sha256sum resume.pdf resume.html resume.tex metadata.json index.html > SHA256SUMS

.PHONY: metadata
metadata: ## Print generated dist metadata.
	jq . "$(DIST_DIR)/metadata.json"

.PHONY: list-dist
list-dist: ## List generated dist files and checksums.
	find "$(DIST_DIR)" -maxdepth 1 -type f -print | sort
	@if [[ -f "$(DIST_DIR)/SHA256SUMS" ]]; then cat "$(DIST_DIR)/SHA256SUMS"; fi

.PHONY: serve
serve: build ## Serve dist locally at http://127.0.0.1:8000/.
	python3 -m http.server 8000 --bind 127.0.0.1 --directory "$(DIST_DIR)"

.PHONY: release-dry-run
release-dry-run: build check-dist ## Build with release metadata and print the release assets.
	@printf 'Release tag: %s\n' "$(RELEASE_TAG)"
	@printf 'Target SHA:  %s\n' "$(GIT_SHA)"
	@printf 'Assets:\n'
	@find "$(DIST_DIR)" -maxdepth 1 -type f -print | sort

.PHONY: pages-preview
pages-preview: build check-dist ## Build the GitHub Pages payload into the site directory.
	rm -rf "$(SITE_DIR)"
	mkdir -p "$(SITE_DIR)"
	cp -R "$(DIST_DIR)/." "$(SITE_DIR)/"
	@printf 'Prepared Pages preview in %s\n' "$(SITE_DIR)"

.PHONY: print-vars
print-vars: ## Print Makefile configuration values.
	@printf 'RESUME_TEX=%s\n' "$(RESUME_TEX)"
	@printf 'SRC_DIR=%s\n' "$(SRC_DIR)"
	@printf 'BUILD_DIR=%s\n' "$(BUILD_DIR)"
	@printf 'DIST_DIR=%s\n' "$(DIST_DIR)"
	@printf 'SITE_DIR=%s\n' "$(SITE_DIR)"
	@printf 'PAGES_BASE_URL=%s\n' "$(PAGES_BASE_URL)"
	@printf 'UPDATED_AT=%s\n' "$(UPDATED_AT)"
	@printf 'RELEASE_TAG=%s\n' "$(RELEASE_TAG)"
	@printf 'GIT_SHA=%s\n' "$(GIT_SHA)"

.PHONY: devcontainer-config
devcontainer-config: ## Validate devcontainer configuration.
	devcontainer read-configuration --workspace-folder . --log-level debug

.PHONY: devcontainer-build
devcontainer-build: ## Build the VS Code devcontainer image.
	devcontainer build --workspace-folder .

.PHONY: docker-image
docker-image: ## Build a reusable local development image.
	docker build -f .devcontainer/Dockerfile -t "$(DEV_IMAGE)" .

.PHONY: docker-shell
docker-shell: docker-image ## Open a shell in the local development image.
	$(DOCKER_RUN) bash

.PHONY: docker-ci
docker-ci: docker-image ## Run the local CI target in the development image.
	$(DOCKER_RUN) make ci

.PHONY: docker-check
docker-check: docker-image ## Run all checks in the development image.
	$(DOCKER_RUN) make check

.PHONY: clean
clean: ## Remove generated build outputs.
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)" "$(SITE_DIR)"

.PHONY: clean-aux
clean-aux: ## Remove LaTeX auxiliary files from the build directory.
	latexmk -C -outdir="$(BUILD_DIR)/pdf" "$(RESUME_TEX)"
