#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/pdf build/html dist site

tools=(
    biber
    chktex
    cspell
    gh
    git
    latexmk
    latexml
    latexmlpost
    make
    markdownlint-cli2
    node
    npm
    pandoc
    pdflatex
    prettier
    python3
    rg
    shellcheck
    tidy
    xelatex
)

missing=()
for tool in "${tools[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        missing+=("${tool}")
    fi
done

if ((${#missing[@]} > 0)); then
    printf 'Missing expected devcontainer tools: %s\n' "${missing[*]}" >&2
    exit 1
fi

git config --global --add safe.directory "${PWD}" >/dev/null 2>&1 || true

printf 'Resume devcontainer is ready.\n'
