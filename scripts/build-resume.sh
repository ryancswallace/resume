#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-src}"
ENTRYPOINT="${RESUME_TEX:-${SRC_DIR}/resume.tex}"
BUILD_DIR="${BUILD_DIR:-build}"
DIST_DIR="${DIST_DIR:-dist}"
PDF_BUILD_DIR="${BUILD_DIR}/pdf"
HTML_BUILD_DIR="${BUILD_DIR}/html"
PAGES_BASE_URL="${PAGES_BASE_URL:-https://ryancswallace.github.io/resume}"
UPDATED_AT="${UPDATED_AT:-$(date -u +%Y-%m-%dT%H-%M-%S)}"
RELEASE_TAG="${RELEASE_TAG:-resume-${UPDATED_AT}}"
GIT_SHA="${GIT_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || printf 'unknown')}}"

if [[ ! -f "${ENTRYPOINT}" ]]; then
    printf 'Resume entrypoint not found: %s\n' "${ENTRYPOINT}" >&2
    exit 1
fi

export TEXINPUTS="${SRC_DIR}//:${TEXINPUTS:-}"

rm -rf "${DIST_DIR}" "${PDF_BUILD_DIR}" "${HTML_BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${PDF_BUILD_DIR}" "${HTML_BUILD_DIR}"

latexmk \
    -pdf \
    -interaction=nonstopmode \
    -halt-on-error \
    -file-line-error \
    -outdir="${PDF_BUILD_DIR}" \
    "${ENTRYPOINT}"

cp "${PDF_BUILD_DIR}/resume.pdf" "${DIST_DIR}/resume.pdf"

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

if command -v latexpand >/dev/null 2>&1; then
    latexpand --empty-comments "${ENTRYPOINT}" | sanitize_tex /dev/stdin > "${DIST_DIR}/resume.tex"
else
    sanitize_tex "${ENTRYPOINT}" > "${DIST_DIR}/resume.tex"
fi

inline_css() {
    local html_file="$1"
    local css_file="$2"
    local tmp_file

    [[ -f "${css_file}" ]] || return 0
    tmp_file="$(mktemp)"
    awk -v css_file="${css_file}" '
        BEGIN {
            while ((getline line < css_file) > 0) {
                css = css line "\n"
            }
            close(css_file)
        }
        /<link[^>]*href=.resume[.]css.[^>]*>/ {
            print "<style>"
            printf "%s", css
            print "</style>"
            next
        }
        { print }
    ' "${html_file}" > "${tmp_file}"
    mv "${tmp_file}" "${html_file}"
}

build_html_with_make4ht() {
    local tmp_work

    command -v make4ht >/dev/null 2>&1 || return 1
    tmp_work="$(mktemp -d)"
    cp -R "${SRC_DIR}" "${tmp_work}/${SRC_DIR}"
    (
        cd "${tmp_work}"
        export TEXINPUTS="${PWD}/${SRC_DIR}//:${TEXINPUTS:-}"
        make4ht -u -f html5 -d html "${ENTRYPOINT}"
    )
    if [[ ! -f "${tmp_work}/html/resume.html" ]]; then
        rm -rf "${tmp_work}"
        return 1
    fi
    inline_css "${tmp_work}/html/resume.html" "${tmp_work}/html/resume.css"
    cp "${tmp_work}/html/resume.html" "${DIST_DIR}/resume.html"
    find "${tmp_work}/html" -maxdepth 1 -type f ! -name 'resume.html' -exec cp {} "${DIST_DIR}/" \;
    rm -rf "${tmp_work}"
}

build_html_with_pandoc() {
    command -v pandoc >/dev/null 2>&1 || return 1
    pandoc "${ENTRYPOINT}" \
        --standalone \
        --metadata title="Resume" \
        --output "${DIST_DIR}/resume.html"
}

if ! build_html_with_make4ht; then
    build_html_with_pandoc
fi

cat > "${DIST_DIR}/metadata.json" <<JSON
{
  "updated_at": "${UPDATED_AT}",
  "git_sha": "${GIT_SHA}",
  "release_tag": "${RELEASE_TAG}",
  "pdf_url": "${PAGES_BASE_URL}/resume.pdf",
  "html_url": "${PAGES_BASE_URL}/resume.html",
  "tex_url": "${PAGES_BASE_URL}/resume.tex"
}
JSON

cat > "${DIST_DIR}/index.html" <<HTML
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="0; url=resume.html">
    <title>Resume</title>
  </head>
  <body>
    <main>
      <h1>Resume</h1>
      <p><a href="resume.html">HTML</a></p>
      <p><a href="resume.pdf">PDF</a></p>
      <p><a href="resume.tex">TeX source</a></p>
    </main>
  </body>
</html>
HTML

(
    cd "${DIST_DIR}"
    sha256sum resume.pdf resume.html resume.tex metadata.json index.html > SHA256SUMS
)

printf 'Built resume artifacts in %s for %s\n' "${DIST_DIR}" "${RELEASE_TAG}"
