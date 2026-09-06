#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-src}"
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-resume_ryan-wallace}"
ENTRYPOINT="${RESUME_TEX:-${SRC_DIR}/${ARTIFACT_BASENAME}.tex}"
BUILD_DIR="${BUILD_DIR:-build}"
DIST_DIR="${DIST_DIR:-dist}"
PDF_BUILD_DIR="${BUILD_DIR}/pdf"
PAGES_BASE_URL="${PAGES_BASE_URL:-https://resume.ryancswallace.dev}"
UPDATED_AT="${UPDATED_AT:-$(date -u +%Y-%m-%dT%H-%M-%S)}"
UPDATED_DATE="${UPDATED_AT%%T*}"
RELEASE_TAG="${RELEASE_TAG:-${ARTIFACT_BASENAME}-${UPDATED_AT}}"
GIT_SHA="${GIT_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || printf 'unknown')}}"
FAVICON_DIR="${FAVICON_DIR:-assets/rw_favicons}"
SITE_SOURCE_DIR="${SITE_SOURCE_DIR:-src/site}"
SITE_TEMPLATE="${SITE_SOURCE_DIR}/index.html"
ENTRYPOINT_BASENAME="$(basename "${ENTRYPOINT}" .tex)"
PDF_FILE="${ARTIFACT_BASENAME}.pdf"
RTF_FILE="${ARTIFACT_BASENAME}.rtf"
MD_FILE="${ARTIFACT_BASENAME}.md"
TEX_FILE="${ARTIFACT_BASENAME}.tex"

required_sources=(
    "${ENTRYPOINT}"
    "${SITE_TEMPLATE}"
    "${SITE_SOURCE_DIR}/resume.css"
    "${SITE_SOURCE_DIR}/resume.js"
    "${FAVICON_DIR}/favicon.ico"
    "${FAVICON_DIR}/favicon-16x16.png"
    "${FAVICON_DIR}/favicon-32x32.png"
    "${FAVICON_DIR}/apple-touch-icon.png"
    "${FAVICON_DIR}/android-chrome-192x192.png"
    "${FAVICON_DIR}/android-chrome-512x512.png"
    "${FAVICON_DIR}/site.webmanifest"
)

for source in "${required_sources[@]}"; do
    if [[ ! -f "${source}" ]]; then
        printf 'Required source not found: %s\n' "${source}" >&2
        exit 1
    fi
done

export TEXINPUTS="${PDF_BUILD_DIR}//:${SRC_DIR}//:${TEXINPUTS:-}"

rm -rf "${DIST_DIR}" "${PDF_BUILD_DIR}"
mkdir -p "${DIST_DIR}/rw_favicons" "${PDF_BUILD_DIR}"

tex_escape() {
    sed \
        -e 's/[\\&%$#_{}]/\\&/g' \
        -e 's/~/\\textasciitilde{}/g' \
        -e 's/\^/\\textasciicircum{}/g'
}

printf '\\renewcommand{\\resumeUpdatedAt}{%s}\n' \
    "$(printf '%s' "${UPDATED_DATE}" | tex_escape)" \
    > "${PDF_BUILD_DIR}/resume-updated-at.tex"

latexmk \
    -pdf \
    -interaction=nonstopmode \
    -halt-on-error \
    -file-line-error \
    -outdir="${PDF_BUILD_DIR}" \
    "${ENTRYPOINT}"

cp "${PDF_BUILD_DIR}/${ENTRYPOINT_BASENAME}.pdf" "${DIST_DIR}/${PDF_FILE}"

sanitize_tex() {
    awk '
        /%[[:space:]]*BEGIN PRIVATE/ { private = 1; next }
        /%[[:space:]]*END PRIVATE/ { private = 0; next }
        private { next }
        /^[[:space:]]*%/ { next }
        /%[[:space:]]*PRIVATE/ { sub(/[[:space:]]*%[[:space:]]*PRIVATE.*/, "") }
        { print }
    ' "$1"
}

sanitize_tex "${ENTRYPOINT}" > "${DIST_DIR}/${TEX_FILE}"

strip_leading_spaces() {
    local file="$1"
    local tmp_file

    [[ -f "${file}" ]] || return 0
    tmp_file="$(mktemp)"
    awk '
        {
            sub(/^[[:space:]]+/, "")
            gsub(/\\bullet \\tx360\\tab /, "\\\\bullet  ")
            gsub(/\\endash \\tx360\\tab /, "\\\\endash  ")
            gsub(/\\tab/, "")
            print
        }
    ' "${file}" > "${tmp_file}"
    mv "${tmp_file}" "${file}"
}

normalize_markdown() {
    local file="$1"
    local tmp_file

    [[ -f "${file}" ]] || return 0
    tmp_file="$(mktemp)"
    awk '
        {
            if ($0 ~ /^[[:space:]]*-[[:space:]][[:space:]][[:space:]]/) {
                bullet = match($0, /-/)
                print substr($0, 1, bullet - 1) "- " substr($0, bullet + 4)
                next
            }
            print
        }
    ' "${file}" > "${tmp_file}"
    mv "${tmp_file}" "${file}"
}

command -v pandoc >/dev/null 2>&1 || {
    printf 'pandoc is required to build RTF and Markdown output.\n' >&2
    exit 1
}

pandoc "${DIST_DIR}/${TEX_FILE}" \
    --standalone \
    --lua-filter scripts/rtf-clean.lua \
    --output "${DIST_DIR}/${RTF_FILE}"
strip_leading_spaces "${DIST_DIR}/${RTF_FILE}"

pandoc "${DIST_DIR}/${TEX_FILE}" \
    --to commonmark \
    --wrap=none \
    --lua-filter scripts/md-clean.lua \
    --output "${DIST_DIR}/${MD_FILE}"
normalize_markdown "${DIST_DIR}/${MD_FILE}"

cat > "${DIST_DIR}/metadata.json" <<JSON
{
  "updated_at": "${UPDATED_AT}",
  "git_sha": "${GIT_SHA}",
  "release_tag": "${RELEASE_TAG}",
  "pdf_url": "${PAGES_BASE_URL}/${PDF_FILE}",
  "rtf_url": "${PAGES_BASE_URL}/${RTF_FILE}",
  "markdown_url": "${PAGES_BASE_URL}/${MD_FILE}",
  "tex_url": "${PAGES_BASE_URL}/${TEX_FILE}",
  "metadata_url": "${PAGES_BASE_URL}/metadata.json"
}
JSON

sed \
    -e "s|@@PAGES_BASE_URL@@|${PAGES_BASE_URL}|g" \
    -e "s|@@PDF_FILE@@|${PDF_FILE}|g" \
    -e "s|@@RTF_FILE@@|${RTF_FILE}|g" \
    -e "s|@@MD_FILE@@|${MD_FILE}|g" \
    -e "s|@@TEX_FILE@@|${TEX_FILE}|g" \
    -e "s|@@UPDATED_DATE@@|${UPDATED_DATE}|g" \
    -e "s|@@CURRENT_YEAR@@|$(date -u +%Y)|g" \
    "${SITE_TEMPLATE}" > "${DIST_DIR}/index.html"

cp "${SITE_SOURCE_DIR}/resume.css" "${DIST_DIR}/resume.css"
cp "${SITE_SOURCE_DIR}/resume.js" "${DIST_DIR}/resume.js"
cp "${FAVICON_DIR}/favicon.ico" "${DIST_DIR}/favicon.ico"
cp "${FAVICON_DIR}/favicon.ico" "${DIST_DIR}/rw_favicons/favicon.ico"
cp "${FAVICON_DIR}/favicon-16x16.png" "${DIST_DIR}/rw_favicons/favicon-16x16.png"
cp "${FAVICON_DIR}/favicon-32x32.png" "${DIST_DIR}/rw_favicons/favicon-32x32.png"
cp "${FAVICON_DIR}/apple-touch-icon.png" "${DIST_DIR}/rw_favicons/apple-touch-icon.png"
cp "${FAVICON_DIR}/android-chrome-192x192.png" "${DIST_DIR}/rw_favicons/android-chrome-192x192.png"
cp "${FAVICON_DIR}/android-chrome-512x512.png" "${DIST_DIR}/rw_favicons/android-chrome-512x512.png"
cp "${FAVICON_DIR}/site.webmanifest" "${DIST_DIR}/rw_favicons/site.webmanifest"

(
    cd "${DIST_DIR}"
    sha256sum \
        "${PDF_FILE}" \
        "${RTF_FILE}" \
        "${MD_FILE}" \
        "${TEX_FILE}" \
        metadata.json \
        index.html \
        resume.css \
        resume.js \
        favicon.ico \
        rw_favicons/favicon.ico \
        rw_favicons/favicon-16x16.png \
        rw_favicons/favicon-32x32.png \
        rw_favicons/apple-touch-icon.png \
        rw_favicons/android-chrome-192x192.png \
        rw_favicons/android-chrome-512x512.png \
        rw_favicons/site.webmanifest \
        > SHA256SUMS
)

printf 'Built resume artifacts in %s for %s\n' "${DIST_DIR}" "${RELEASE_TAG}"
