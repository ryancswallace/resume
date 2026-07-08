#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${DIST_DIR:-dist}"
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-resume_ryan-wallace}"
PAGES_BASE_URL="${PAGES_BASE_URL:-https://ryancswallace.github.io/resume}"
PDF_FILE="${ARTIFACT_BASENAME}.pdf"
HTML_FILE="${ARTIFACT_BASENAME}.html"
TEX_FILE="${ARTIFACT_BASENAME}.tex"
required_files=(
    "${PDF_FILE}"
    "${HTML_FILE}"
    "${TEX_FILE}"
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

jq -er '.release_tag' "${DIST_DIR}/metadata.json" | grep -Eq "^${ARTIFACT_BASENAME}-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}$"
jq -er '.pdf_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${PDF_FILE}" >/dev/null
jq -er '.html_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${HTML_FILE}" >/dev/null
jq -er '.tex_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${TEX_FILE}" >/dev/null
jq -er '.metadata_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/metadata.json" >/dev/null

pdfinfo "${DIST_DIR}/${PDF_FILE}" >/dev/null
grep -qi '<html' "${DIST_DIR}/${HTML_FILE}"
grep -q '\\documentclass' "${DIST_DIR}/${TEX_FILE}"
grep -q '<title>Resume - Ryan Wallace</title>' "${DIST_DIR}/index.html"
grep -Fqi "${HTML_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${PDF_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${TEX_FILE}" "${DIST_DIR}/index.html"
grep -qi 'metadata.json' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/index.html"
grep -qi 'href="favicon.ico"' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/${HTML_FILE}"
grep -qi 'href="favicon.ico"' "${DIST_DIR}/${HTML_FILE}"
if grep -Eiq '<meta[^>]+http-equiv=.refresh' "${DIST_DIR}/index.html"; then
    printf 'Index page must not redirect to the HTML artifact.\n' >&2
    exit 1
fi

if [[ -f "${DIST_DIR}/SHA256SUMS" ]]; then
    (cd "${DIST_DIR}" && sha256sum --check SHA256SUMS)
fi

printf 'Dist artifacts passed validation.\n'
