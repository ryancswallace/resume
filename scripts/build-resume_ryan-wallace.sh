#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${SRC_DIR:-src}"
ARTIFACT_BASENAME="${ARTIFACT_BASENAME:-resume_ryan-wallace}"
ENTRYPOINT="${RESUME_TEX:-${SRC_DIR}/${ARTIFACT_BASENAME}.tex}"
BUILD_DIR="${BUILD_DIR:-build}"
DIST_DIR="${DIST_DIR:-dist}"
PDF_BUILD_DIR="${BUILD_DIR}/pdf"
PAGES_BASE_URL="${PAGES_BASE_URL:-https://ryancswallace.github.io/resume}"
UPDATED_AT="${UPDATED_AT:-$(date -u +%Y-%m-%dT%H-%M-%S)}"
RELEASE_TAG="${RELEASE_TAG:-${ARTIFACT_BASENAME}-${UPDATED_AT}}"
GIT_SHA="${GIT_SHA:-${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || printf 'unknown')}}"
FAVICON_SOURCE="${FAVICON_SOURCE:-assets/rw_favicons/favicon.ico}"
FAVICON_FILE="favicon.ico"
ENTRYPOINT_BASENAME="$(basename "${ENTRYPOINT}" .tex)"
PDF_FILE="${ARTIFACT_BASENAME}.pdf"
RTF_FILE="${ARTIFACT_BASENAME}.rtf"
MD_FILE="${ARTIFACT_BASENAME}.md"
TEX_FILE="${ARTIFACT_BASENAME}.tex"

if [[ ! -f "${ENTRYPOINT}" ]]; then
    printf 'Resume entrypoint not found: %s\n' "${ENTRYPOINT}" >&2
    exit 1
fi

if [[ ! -f "${FAVICON_SOURCE}" ]]; then
    printf 'Favicon source not found: %s\n' "${FAVICON_SOURCE}" >&2
    exit 1
fi

export TEXINPUTS="${SRC_DIR}//:${TEXINPUTS:-}"

rm -rf "${DIST_DIR}" "${PDF_BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${PDF_BUILD_DIR}"
cp "${FAVICON_SOURCE}" "${DIST_DIR}/${FAVICON_FILE}"

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

if command -v latexpand >/dev/null 2>&1; then
    latexpand --empty-comments "${ENTRYPOINT}" | sanitize_tex /dev/stdin > "${DIST_DIR}/${TEX_FILE}"
else
    sanitize_tex "${ENTRYPOINT}" > "${DIST_DIR}/${TEX_FILE}"
fi

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

cat > "${DIST_DIR}/index.html" <<HTML
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Resume - Ryan Wallace</title>
    <link rel="icon" href="favicon.ico" sizes="any">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Roboto+Mono:wght@400;500;700&display=swap" rel="stylesheet">
    <style>
      :root {
        color-scheme: dark;
        --background: #212737;
        --foreground: #eaedf3;
        --accent: #ff6b01;
        --muted: #343f60;
        --border: #ab4b08;
        --accent-ink: #212737;
        --subtle: rgba(234, 237, 243, 0.72);
        --glow: rgba(255, 107, 1, 0.18);
        --shadow: rgba(33, 39, 55, 0.42);
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
        background: var(--background);
        color: var(--foreground);
        font-family:
          "Roboto Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas,
          "Liberation Mono", "Courier New", monospace;
      }

      main {
        width: min(100%, 42rem);
        padding: clamp(2rem, 5vw, 3.5rem);
        border: 1px solid var(--border);
        border-radius: 8px;
        background: var(--muted);
        box-shadow: 0 24px 60px var(--shadow);
      }

      h1 {
        margin: 0;
        font-size: clamp(2rem, 7vw, 4rem);
        line-height: 0.95;
        font-weight: 700;
      }

      p {
        margin: 1rem 0 0;
        color: var(--subtle);
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
        border: 1px solid var(--border);
        border-radius: 8px;
        color: var(--foreground);
        text-decoration: none;
        transition:
          background-color 160ms ease,
          border-color 160ms ease,
          color 160ms ease,
          transform 160ms ease;
      }

      a::after {
        content: attr(data-format);
        color: var(--subtle);
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
      <h1>Resume</h1>
      <h2>Ryan Wallace (@ryancswallace)</h2>
      <br>
      <p>Formats:</p><ul>
        <li><a href="${PDF_FILE}" target="_blank" download data-format="PDF">Download PDF</a></li>
        <li><a href="${RTF_FILE}" target="_blank" download data-format="RTF">Download RTF</a></li>
        <li><a href="${TEX_FILE}" target="_blank" download data-format="TeX">Download TeX source</a></li>
        <li><a href="${MD_FILE}" target="_blank" data-format="Markdown">View AI-readable Markdown</a></li>
      </ul>
      <br>
      <p>Metadata:</p><ul>
        <li><a href="metadata.json" target="_blank" data-format="JSON">Build metadata</a></li>
        <li><a href="SHA256SUMS" target="_blank" data-format="Text">File checksums</a></li>
      </ul>
    </main>
  </body>
</html>
HTML

(
    cd "${DIST_DIR}"
    sha256sum "${PDF_FILE}" "${RTF_FILE}" "${MD_FILE}" "${TEX_FILE}" metadata.json index.html favicon.ico > SHA256SUMS
)

printf 'Built resume artifacts in %s for %s\n' "${DIST_DIR}" "${RELEASE_TAG}"
