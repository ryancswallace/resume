#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${DIST_DIR:-dist}"
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-resume_ryan-wallace}"
PAGES_BASE_URL="${PAGES_BASE_URL:-https://ryancswallace.github.io/resume}"
PDF_FILE="${ARTIFACT_BASENAME}.pdf"
HTML_FILE="${ARTIFACT_BASENAME}.html"
RTF_FILE="${ARTIFACT_BASENAME}.rtf"
MD_FILE="${ARTIFACT_BASENAME}.md"
TEX_FILE="${ARTIFACT_BASENAME}.tex"
required_files=(
    "${PDF_FILE}"
    "${HTML_FILE}"
    "${RTF_FILE}"
    "${MD_FILE}"
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
    and .rtf_url
    and .markdown_url
    and .tex_url
    and .metadata_url
' "${DIST_DIR}/metadata.json" >/dev/null

jq -er '.release_tag' "${DIST_DIR}/metadata.json" | grep -Eq "^${ARTIFACT_BASENAME}-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}$"
jq -er '.pdf_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${PDF_FILE}" >/dev/null
jq -er '.html_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${HTML_FILE}" >/dev/null
jq -er '.rtf_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${RTF_FILE}" >/dev/null
jq -er '.markdown_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${MD_FILE}" >/dev/null
jq -er '.tex_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${TEX_FILE}" >/dev/null
jq -er '.metadata_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/metadata.json" >/dev/null

pdfinfo "${DIST_DIR}/${PDF_FILE}" >/dev/null
grep -qi '<html' "${DIST_DIR}/${HTML_FILE}"
grep -q '{\\rtf' "${DIST_DIR}/${RTF_FILE}"
grep -q '^# Ryan Wallace$' "${DIST_DIR}/${MD_FILE}"
grep -q '^Boston, MA | \[ryan@ryancswallace.dev\](mailto:ryan@ryancswallace.dev) | 617-852-9239$' "${DIST_DIR}/${MD_FILE}"
grep -q '^\[github.com/ryancswallace\](https://github.com/ryancswallace) | \[ryancswallace.dev\](https://ryancswallace.dev) | \[linkedin.com/in/ryancswallace\](https://linkedin.com/in/ryancswallace)$' "${DIST_DIR}/${MD_FILE}"
grep -q '^## Education$' "${DIST_DIR}/${MD_FILE}"
grep -q '^## Experience$' "${DIST_DIR}/${MD_FILE}"
grep -q '^## Skills$' "${DIST_DIR}/${MD_FILE}"
grep -q '^- \*\*Harvard University\*\* | Cambridge, MA$' "${DIST_DIR}/${MD_FILE}"
grep -q '^- \*\*Federal Reserve Bank of Boston\*\* | Boston, MA$' "${DIST_DIR}/${MD_FILE}"
if grep -Eq '<[^>]+>|^[[:space:]]*\|' "${DIST_DIR}/${MD_FILE}"; then
    printf 'Markdown artifact must not contain HTML tags or table syntax.\n' >&2
    exit 2
fi
if grep -Eq '^[[:space:]]*-[[:space:]]{3}' "${DIST_DIR}/${MD_FILE}"; then
    printf 'Markdown artifact must use one space after bullet markers.\n' >&2
    exit 3
fi
awk '
    blank_after_deepest && /^        - / {
        exit 1
    }
    {
        blank_after_deepest = previous_deepest && $0 == ""
        previous_deepest = $0 ~ /^        - /
    }
' "${DIST_DIR}/${MD_FILE}" || {
    printf 'Markdown artifact must not contain blank lines between deepest nested bullets.\n' >&2
    exit 4
}
if grep -Fq '\fs36 Resume\par' "${DIST_DIR}/${RTF_FILE}"; then
    printf 'RTF artifact must not render a generic Resume title.\n' >&2
    exit 5
fi
grep -F '\qc \f0 \b \fs36 Ryan Wallace\par' "${DIST_DIR}/${RTF_FILE}" >/dev/null
grep -F '\qc \f0 \b0 \fs24 Boston, MA | ' "${DIST_DIR}/${RTF_FILE}" >/dev/null
grep -F 'github.com/ryancswallace}}} | ' "${DIST_DIR}/${RTF_FILE}" >/dev/null
if grep -q '\\trowd' "${DIST_DIR}/${RTF_FILE}"; then
    printf 'RTF artifact must not contain visible table structures.\n' >&2
    exit 6
fi
if grep -q '\\tab' "${DIST_DIR}/${RTF_FILE}"; then
    printf 'RTF artifact must not contain tab controls after list markers.\n' >&2
    exit 7
fi
if grep -Eq '^ +' "${DIST_DIR}/${RTF_FILE}"; then
    printf 'RTF artifact must not contain lines with leading spaces.\n' >&2
    exit 8
fi
grep -q '\\documentclass' "${DIST_DIR}/${TEX_FILE}"
grep -q '<title>Resume - Ryan Wallace</title>' "${DIST_DIR}/index.html"
grep -Fqi "${HTML_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${PDF_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${RTF_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${MD_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${TEX_FILE}" "${DIST_DIR}/index.html"
grep -qi 'metadata.json' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/index.html"
grep -qi 'href="favicon.ico"' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/${HTML_FILE}"
grep -qi 'href="favicon.ico"' "${DIST_DIR}/${HTML_FILE}"
if grep -Eiq '<meta[^>]+http-equiv=.refresh' "${DIST_DIR}/index.html"; then
    printf 'Index page must not redirect to the HTML artifact.\n' >&2
    exit 9
fi

if [[ -f "${DIST_DIR}/SHA256SUMS" ]]; then
    (cd "${DIST_DIR}" && sha256sum --check SHA256SUMS)
fi

printf 'Dist artifacts passed validation.\n'
