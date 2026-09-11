#!/usr/bin/env bash
set -euo pipefail

DIST_DIR="${DIST_DIR:-dist}"
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-resume_ryan-wallace}"
PAGES_BASE_URL="${PAGES_BASE_URL:-https://resume.ryancswallace.dev}"
PDF_FILE="${ARTIFACT_BASENAME}.pdf"
RTF_FILE="${ARTIFACT_BASENAME}.rtf"
MD_FILE="${ARTIFACT_BASENAME}.md"
TEX_FILE="${ARTIFACT_BASENAME}.tex"
required_files=(
    "${PDF_FILE}"
    "${RTF_FILE}"
    "${MD_FILE}"
    "${TEX_FILE}"
    metadata.json
    index.html
    resume.css
    resume.js
    favicon.ico
    rw_favicons/favicon.ico
    rw_favicons/favicon-16x16.png
    rw_favicons/favicon-32x32.png
    rw_favicons/apple-touch-icon.png
    rw_favicons/android-chrome-192x192.png
    rw_favicons/android-chrome-512x512.png
    rw_favicons/site.webmanifest
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
    and .rtf_url
    and .markdown_url
    and .tex_url
    and .metadata_url
' "${DIST_DIR}/metadata.json" >/dev/null

jq -er '.release_tag' "${DIST_DIR}/metadata.json" | grep -Eq "^${ARTIFACT_BASENAME}-[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}$"
jq -er '.pdf_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${PDF_FILE}" >/dev/null
jq -er '.rtf_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${RTF_FILE}" >/dev/null
jq -er '.markdown_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${MD_FILE}" >/dev/null
jq -er '.tex_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/${TEX_FILE}" >/dev/null
jq -er '.metadata_url' "${DIST_DIR}/metadata.json" | grep -Fx "${PAGES_BASE_URL}/metadata.json" >/dev/null

pdf_page_count="$(LC_ALL=C pdfinfo "${DIST_DIR}/${PDF_FILE}" | awk '/^Pages:/ { print $2 }')"
if [[ "${pdf_page_count}" != 2 ]]; then
    printf 'PDF must contain exactly 2 pages; found %s in %s.\n' "${pdf_page_count:-unknown}" "${PDF_FILE}" >&2
    exit 10
fi

pdf_text="$(pdftotext -layout "${DIST_DIR}/${PDF_FILE}" -)"
required_pdf_text=(
    "Ryan Wallace"
    "ryan@ryancswallace.dev"
    "Professional Experience"
    "Selected Open Source Projects"
    "Earlier Experience"
    "Technical Skills"
    "Education"
)
for text in "${required_pdf_text[@]}"; do
    if ! grep -Fqi "${text}" <<< "${pdf_text}"; then
        printf 'PDF is missing expected extractable text in %s: %s\n' "${PDF_FILE}" "${text}" >&2
        exit 11
    fi
done

first_page_text="$(pdftotext -f 1 -l 1 -layout "${DIST_DIR}/${PDF_FILE}" -)"
required_first_page_projects=(
    "Jobman ecosystem"
    "benchmatrix"
    "Python Project Foundry"
)
for project in "${required_first_page_projects[@]}"; do
    if ! grep -Fqi "${project}" <<< "${first_page_text}"; then
        printf 'PDF page 1 is missing project %s in %s.\n' "${project}" "${PDF_FILE}" >&2
        exit 12
    fi
done

second_page_first_content="$(pdftotext -f 2 -l 2 -layout "${DIST_DIR}/${PDF_FILE}" - | awk '
    /^[[:space:]]*$/ { next }
    {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        print
        exit
    }
')"
if [[ "${second_page_first_content}" != "Earlier Experience" ]]; then
    printf 'PDF page 2 must begin with Earlier Experience in %s.\n' "${PDF_FILE}" >&2
    exit 13
fi

grep -q '{\\rtf' "${DIST_DIR}/${RTF_FILE}"
grep -q '^# Ryan Wallace$' "${DIST_DIR}/${MD_FILE}"
grep -q '^Boston, MA | \[ryan@ryancswallace.dev\](mailto:ryan@ryancswallace.dev) | 617-852-9239$' "${DIST_DIR}/${MD_FILE}"
grep -Fxq '[github.com/ryancswallace](https://github.com/ryancswallace) | **[ryancswallace.dev](https://ryancswallace.dev)** | [linkedin.com/in/ryancswallace](https://linkedin.com/in/ryancswallace)' "${DIST_DIR}/${MD_FILE}"
grep -q '^## Education$' "${DIST_DIR}/${MD_FILE}"
grep -Eq '^## (Professional )?Experience$' "${DIST_DIR}/${MD_FILE}"
grep -Eq '^## (Technical )?Skills$' "${DIST_DIR}/${MD_FILE}"
grep -q '^- \*\*Harvard University\*\* | Cambridge, MA$' "${DIST_DIR}/${MD_FILE}"
grep -q '^- \*\*Federal Reserve Bank of Boston .* Research Department\*\* | Boston, MA$' "${DIST_DIR}/${MD_FILE}"
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
grep -F 'github.com/ryancswallace}}} | {\b {\field{\*\fldinst{HYPERLINK "https://ryancswallace.dev"}}{\fldrslt{\ul ryancswallace.dev}}}} | ' "${DIST_DIR}/${RTF_FILE}" >/dev/null
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
grep -q '<title>Resume | Ryan Wallace</title>' "${DIST_DIR}/index.html"
grep -Fq "<link rel=\"canonical\" href=\"${PAGES_BASE_URL}/\" />" "${DIST_DIR}/index.html"
grep -Fq "<meta property=\"og:url\" content=\"${PAGES_BASE_URL}/\" />" "${DIST_DIR}/index.html"
grep -Fq 'const sharedCookieName = "rw-theme";' "${DIST_DIR}/resume.js"
grep -Fq 'const sharedCookieDomain = "ryancswallace.dev";' "${DIST_DIR}/resume.js"
grep -Fq 'SameSite=Lax; Secure' "${DIST_DIR}/resume.js"
grep -Fq -- '--background: #fdfdfd;' "${DIST_DIR}/resume.css"
grep -Fq -- '--background: #212737;' "${DIST_DIR}/resume.css"
grep -Fq -- '--accent: #006cac;' "${DIST_DIR}/resume.css"
grep -Fq -- '--accent: #ff6b01;' "${DIST_DIR}/resume.css"
grep -Fqi "${PDF_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${RTF_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${MD_FILE}" "${DIST_DIR}/index.html"
grep -Fqi "${TEX_FILE}" "${DIST_DIR}/index.html"
grep -qi 'metadata.json' "${DIST_DIR}/index.html"
grep -Fq 'id="menu-btn"' "${DIST_DIR}/index.html"
grep -Fq 'id="theme-btn"' "${DIST_DIR}/index.html"
grep -Fq 'aria-current="page">Resume</a>' "${DIST_DIR}/index.html"
grep -qi 'rel="icon"' "${DIST_DIR}/index.html"
grep -Fqi 'href="/rw_favicons/favicon.ico"' "${DIST_DIR}/index.html"
grep -Fqi 'rel="apple-touch-icon"' "${DIST_DIR}/index.html"
grep -Fqi 'rel="manifest"' "${DIST_DIR}/index.html"
if grep -Eiq '<meta[^>]+http-equiv=.refresh' "${DIST_DIR}/index.html"; then
    printf 'Index page must not redirect.\n' >&2
    exit 9
fi

if [[ -f "${DIST_DIR}/SHA256SUMS" ]]; then
    (cd "${DIST_DIR}" && sha256sum --check SHA256SUMS)
fi

printf 'Dist artifacts passed validation.\n'
