#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${DIST_DIR:-dist}"
required_files=(
    resume.pdf
    resume.html
    resume.tex
    metadata.json
    index.html
    favicon.ico
)

for file in "${required_files[@]}"; do
    path="${DIST_DIR}/${file}"
    if [[ ! -s "${path}" ]]; then
        printf 'Missing or empty dist artifact: %s\n' "${path}" >&2
        exit 1
    fi
done

jq -e '
    .updated_at
    and .git_sha
    and .release_tag
    and .pdf_url
    and .html_url
    and .tex_url
    and .metadata_url
' "${DIST_DIR}/metadata.json" >/dev/null

jq -er '.release_tag' "${DIST_DIR}/metadata.json" | grep -Eq '^resume-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}$'
jq -er '.pdf_url' "${DIST_DIR}/metadata.json" | grep -Fx 'https://ryancswallace.github.io/resume/resume.pdf' >/dev/null
jq -er '.html_url' "${DIST_DIR}/metadata.json" | grep -Fx 'https://ryancswallace.github.io/resume/resume.html' >/dev/null
jq -er '.tex_url' "${DIST_DIR}/metadata.json" | grep -Fx 'https://ryancswallace.github.io/resume/resume.tex' >/dev/null
jq -er '.metadata_url' "${DIST_DIR}/metadata.json" | grep -Fx 'https://ryancswallace.github.io/resume/metadata.json' >/dev/null

pdfinfo "${DIST_DIR}/resume.pdf" >/dev/null
grep -qi '<html' "${DIST_DIR}/resume.html"
grep -q '\\documentclass' "${DIST_DIR}/resume.tex"
grep -q '<title>Resume - Ryan Wallace</title>' "${DIST_DIR}/index.html"
grep -qi 'resume.html' "${DIST_DIR}/index.html"
grep -qi 'resume.pdf' "${DIST_DIR}/index.html"
grep -qi 'resume.tex' "${DIST_DIR}/index.html"
grep -qi 'metadata.json' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/index.html"
grep -qi 'href="favicon.ico"' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/resume.html"
grep -qi 'href="favicon.ico"' "${DIST_DIR}/resume.html"
if grep -Eiq '<meta[^>]+http-equiv=.refresh' "${DIST_DIR}/index.html"; then
    printf 'Index page must not redirect to the HTML resume.\n' >&2
    exit 1
fi

if [[ -f "${DIST_DIR}/SHA256SUMS" ]]; then
    (cd "${DIST_DIR}" && sha256sum --check SHA256SUMS)
fi

printf 'Dist artifacts passed validation.\n'
