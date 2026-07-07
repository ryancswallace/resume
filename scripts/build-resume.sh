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
  "tex_url": "${PAGES_BASE_URL}/resume.tex",
  "metadata_url": "${PAGES_BASE_URL}/metadata.json"
}
JSON

cat > "${DIST_DIR}/index.html" <<HTML
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Resume - Ryan Wallace</title>
    <style>
      :root {
        color-scheme: light dark;
        --bg: #f7f3ea;
        --card: #fffaf0;
        --ink: #24211d;
        --muted: #6d665d;
        --line: #d8cfc0;
        --accent: #9b3d2e;
        --accent-ink: #ffffff;
      }

      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #181715;
          --card: #22201d;
          --ink: #f2eadf;
          --muted: #b8aa99;
          --line: #3a352f;
          --accent: #d97b62;
          --accent-ink: #181715;
        }
      }

      * {
        box-sizing: border-box;
      }

      body {
        min-height: 100vh;
        margin: 0;
        display: grid;
        place-items: center;
        padding: 2rem;
        background:
          linear-gradient(135deg, rgba(155, 61, 46, 0.12), transparent 38%),
          var(--bg);
        color: var(--ink);
        font-family:
          ui-serif, Georgia, Cambria, "Times New Roman", Times, serif;
      }

      main {
        width: min(100%, 42rem);
        padding: clamp(2rem, 5vw, 3.5rem);
        border: 1px solid var(--line);
        border-radius: 8px;
        background: var(--card);
        box-shadow: 0 24px 60px rgba(0, 0, 0, 0.12);
      }

      h1 {
        margin: 0;
        font-size: clamp(2rem, 7vw, 4rem);
        line-height: 0.95;
        font-weight: 700;
      }

      p {
        margin: 1rem 0 0;
        color: var(--muted);
        font-size: 1.05rem;
      }

      ul {
        display: grid;
        gap: 0.75rem;
        margin: 2rem 0 0;
        padding: 0;
        list-style: none;
      }

      a {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 1rem;
        min-height: 3.25rem;
        padding: 0.85rem 1rem;
        border: 1px solid var(--line);
        border-radius: 8px;
        color: var(--ink);
        text-decoration: none;
        transition:
          background-color 160ms ease,
          border-color 160ms ease,
          color 160ms ease,
          transform 160ms ease;
      }

      a::after {
        content: attr(data-format);
        color: var(--muted);
        font-size: 0.8rem;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      a:focus,
      a:hover {
        border-color: var(--accent);
        background: var(--accent);
        color: var(--accent-ink);
        transform: translateY(-1px);
      }

      a:focus::after,
      a:hover::after {
        color: currentColor;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Resume - Ryan Wallace</h1>
      <p>Available formats for the latest published resume.</p>
      <ul>
        <li><a href="resume.html" data-format="HTML">Read online</a></li>
        <li><a href="resume.pdf" data-format="PDF">Download PDF</a></li>
        <li><a href="resume.tex" data-format="TeX">View TeX source</a></li>
        <li><a href="metadata.json" data-format="JSON">Build metadata</a></li>
      </ul>
    </main>
  </body>
</html>
HTML

(
    cd "${DIST_DIR}"
    sha256sum resume.pdf resume.html resume.tex metadata.json index.html > SHA256SUMS
)

printf 'Built resume artifacts in %s for %s\n' "${DIST_DIR}" "${RELEASE_TAG}"
