#!/usr/bin/env bash
# cspell:ignore pageshow
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

export TEXINPUTS="${PDF_BUILD_DIR}//:${SRC_DIR}//:${TEXINPUTS:-}"

rm -rf "${DIST_DIR}" "${PDF_BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${PDF_BUILD_DIR}"
cp "${FAVICON_SOURCE}" "${DIST_DIR}/${FAVICON_FILE}"

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

cat > "${DIST_DIR}/index.html" <<HTML
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Resume - Ryan Wallace</title>
    <meta name="description" content="Ryan Wallace's resume in PDF, RTF, Markdown, and TeX formats.">
    <link rel="canonical" href="${PAGES_BASE_URL}/">
    <meta property="og:url" content="${PAGES_BASE_URL}/">
    <meta name="theme-color" content="#fdfdfd">
    <link rel="icon" href="favicon.ico" sizes="any">
    <script>
      (() => {
        const storageKey = "theme";
        const sharedCookieName = "rw-theme";
        const sharedCookieDomain = "ryancswallace.dev";
        const sharedCookieMaxAge = 60 * 60 * 24 * 365;

        function isTheme(value) {
          return value === "light" || value === "dark";
        }

        function getSharedTheme() {
          const cookie = document.cookie
            .split(";")
            .map((value) => value.trim())
            .find((value) => value.startsWith(sharedCookieName + "="));
          const value = cookie?.slice(sharedCookieName.length + 1);
          return isTheme(value) ? value : null;
        }

        function getLocalTheme() {
          try {
            const value = localStorage.getItem(storageKey);
            return isTheme(value) ? value : null;
          } catch {
            return null;
          }
        }

        function setLocalTheme(theme) {
          try {
            localStorage.setItem(storageKey, theme);
          } catch {
            // The shared cookie still preserves the preference when storage is unavailable.
          }
        }

        function setSharedTheme(theme) {
          document.cookie =
            sharedCookieName +
            "=" +
            theme +
            "; Path=/; Domain=" +
            sharedCookieDomain +
            "; Max-Age=" +
            sharedCookieMaxAge +
            "; SameSite=Lax; Secure";
        }

        function getSavedTheme() {
          return getSharedTheme() || getLocalTheme();
        }

        function saveTheme(theme) {
          setLocalTheme(theme);
          setSharedTheme(theme);
        }

        const sharedTheme = getSharedTheme();
        const localTheme = getLocalTheme();

        if (sharedTheme) {
          setLocalTheme(sharedTheme);
        } else if (localTheme) {
          saveTheme(localTheme);
        }

        const preferredTheme = window.matchMedia("(prefers-color-scheme: dark)").matches
          ? "dark"
          : "light";
        document.documentElement.dataset.theme = getSavedTheme() || preferredTheme;

        window.rwThemePreference = {
          getSavedTheme,
          getSharedTheme,
          saveTheme,
          setLocalTheme,
        };
      })();
    </script>
    <style>
      :root,
      html[data-theme="light"] {
        color-scheme: light;
        --background: #fdfdfd;
        --foreground: #282728;
        --accent: #006cac;
        --muted: #e6e6e6;
        --border: #ece9e9;
      }

      html[data-theme="dark"] {
        color-scheme: dark;
        --background: #212737;
        --foreground: #eaedf3;
        --accent: #ff6b01;
        --muted: #343f60;
        --border: #ab4b08;
      }

      * {
        box-sizing: border-box;
        scrollbar-color: var(--muted) transparent;
      }

      ::selection {
        background: var(--accent);
        color: var(--background);
      }

      html {
        min-width: 20rem;
        overflow-y: scroll;
        scroll-behavior: smooth;
      }

      body {
        min-height: 100svh;
        margin: 0;
        display: flex;
        flex-direction: column;
        background: var(--background);
        color: var(--foreground);
        font-family:
          ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas,
          "Liberation Mono", "Courier New", monospace;
        font-size: 1rem;
        line-height: 1.65;
      }

      a,
      button {
        color: inherit;
        font: inherit;
        outline-color: var(--accent);
        outline-offset: 0.25rem;
      }

      a:focus-visible,
      button:focus-visible {
        text-decoration: none;
        outline: 2px dashed var(--accent);
      }

      button:not(:disabled) {
        cursor: pointer;
      }

      .shell {
        width: min(100%, 48rem);
        margin-inline: auto;
        padding-inline: 1rem;
      }

      .site-header {
        width: 100%;
      }

      .skip-link {
        position: fixed;
        top: 1rem;
        left: 1rem;
        z-index: 10;
        padding: 0.5rem 0.75rem;
        transform: translateY(-200%);
        background: var(--background);
        color: var(--accent);
        transition: transform 150ms ease;
      }

      .skip-link:focus {
        transform: translateY(0);
      }

      .nav-bar {
        display: flex;
        min-height: 5rem;
        align-items: center;
        justify-content: space-between;
        gap: 1.5rem;
      }

      .brand {
        flex: 0 0 auto;
        padding-block: 0.25rem;
        font-size: 1.5rem;
        font-weight: 600;
        line-height: 1;
        text-decoration: none;
        white-space: nowrap;
      }

      .brand:hover,
      .nav-link:hover,
      .icon-link:hover,
      .theme-toggle:hover {
        color: var(--accent);
      }

      .nav-links {
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 1.25rem;
        margin: 0;
        padding: 0;
        list-style: none;
      }

      .nav-link {
        padding-block: 0.25rem;
        font-weight: 500;
        text-decoration: none;
      }

      .icon-link,
      .theme-toggle {
        display: grid;
        width: 2rem;
        height: 2rem;
        place-items: center;
        padding: 0.375rem;
        border: 0;
        background: transparent;
      }

      .icon-link svg,
      .theme-toggle svg {
        width: 1.25rem;
        height: 1.25rem;
        fill: none;
        stroke: currentColor;
        stroke-linecap: round;
        stroke-linejoin: round;
        stroke-width: 2;
      }

      html[data-theme="light"] .sun-icon,
      html[data-theme="dark"] .moon-icon {
        display: none;
      }

      .rule {
        width: 100%;
        margin: 0;
        border: 0;
        border-top: 1px solid var(--border);
      }

      main {
        flex: 1;
        padding-block: 2rem 3rem;
      }

      .breadcrumb {
        margin: 0 0 1rem;
        font-weight: 300;
        opacity: 0.8;
      }

      .breadcrumb a {
        text-decoration: none;
      }

      .breadcrumb a:hover {
        opacity: 1;
      }

      h1,
      h2,
      p {
        overflow-wrap: anywhere;
      }

      h1 {
        margin: 0;
        font-size: clamp(1.5rem, 4vw, 1.875rem);
        line-height: 1.25;
        font-weight: 600;
      }

      .intro {
        margin: 0.5rem 0 2.5rem;
        font-style: italic;
      }

      h2 {
        margin: 0;
        font-size: 1.5rem;
        font-weight: 600;
        letter-spacing: 0.025em;
      }

      .file-list {
        margin: 0;
        padding: 0;
        list-style: none;
      }

      .file-item {
        margin-block: 1.5rem;
      }

      .file-link {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
        color: var(--accent);
        font-size: 1.125rem;
        font-weight: 500;
        text-decoration-line: underline;
        text-decoration-style: dashed;
        text-decoration-thickness: 1px;
        text-underline-offset: 0.25rem;
      }

      .file-link:hover {
        text-decoration-style: solid;
      }

      .file-type {
        flex: 0 0 auto;
        color: var(--foreground);
        font-size: 0.8rem;
        font-weight: 400;
        letter-spacing: 0.08em;
        opacity: 0.75;
        text-transform: uppercase;
      }

      .file-description {
        margin: 0.25rem 0 0;
      }

      .metadata {
        margin-top: 2.75rem;
        padding-top: 2rem;
        border-top: 1px solid var(--border);
      }

      .site-footer {
        width: 100%;
      }

      .footer-row {
        display: flex;
        min-height: 4.75rem;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
        font-size: 0.875rem;
      }

      .footer-links {
        display: flex;
        flex-wrap: wrap;
        justify-content: flex-end;
        gap: 0.75rem;
      }

      .footer-links a {
        text-decoration: none;
      }

      .footer-links a:hover {
        color: var(--accent);
      }

      @media (max-width: 40rem) {
        .nav-bar {
          min-height: auto;
          flex-direction: column;
          align-items: flex-start;
          gap: 0.75rem;
          padding-block: 1rem;
        }

        .brand {
          font-size: 1.25rem;
        }

        .nav-links {
          width: 100%;
          justify-content: flex-start;
          gap: 1rem;
        }

        .nav-link {
          font-size: 0.875rem;
        }

        .footer-row {
          flex-direction: column;
          padding-block: 1.5rem;
          text-align: center;
        }

        .footer-links {
          justify-content: center;
        }
      }
    </style>
  </head>
  <body>
    <a class="skip-link" href="#main-content">Skip to content</a>
    <header class="site-header">
      <div class="shell nav-bar">
        <a class="brand" href="https://ryancswallace.dev/">Ryan Wallace</a>
        <nav aria-label="Primary navigation">
          <ul class="nav-links">
            <li><a class="nav-link" href="https://ryancswallace.dev/posts/">Posts</a></li>
            <li><a class="nav-link" href="https://ryancswallace.dev/tags/">Tags</a></li>
            <li><a class="nav-link" href="https://ryancswallace.dev/about/">About</a></li>
            <li>
              <a class="icon-link" href="https://ryancswallace.dev/search/" aria-label="Search" title="Search">
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <circle cx="11" cy="11" r="7"></circle>
                  <path d="m20 20-4-4"></path>
                </svg>
              </a>
            </li>
            <li>
              <button class="theme-toggle" type="button" aria-label="Switch to dark theme" title="Toggle light and dark theme">
                <svg class="moon-icon" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M20.5 14.2A8.5 8.5 0 0 1 9.8 3.5 8.5 8.5 0 1 0 20.5 14.2Z"></path>
                </svg>
                <svg class="sun-icon" viewBox="0 0 24 24" aria-hidden="true">
                  <circle cx="12" cy="12" r="4"></circle>
                  <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path>
                </svg>
              </button>
            </li>
          </ul>
        </nav>
      </div>
      <div class="shell"><hr class="rule"></div>
    </header>

    <main id="main-content" class="shell">
      <p class="breadcrumb"><a href="https://ryancswallace.dev/">Home</a> <span aria-hidden="true">&raquo;</span> <span aria-current="page">Resume</span></p>
      <h1>Resume</h1>
      <p class="intro">Ryan Wallace (@ryancswallace)</p>

      <section aria-labelledby="formats-heading">
        <h2 id="formats-heading">Formats</h2>
        <ul class="file-list">
          <li class="file-item">
            <a class="file-link" href="${PDF_FILE}" target="_blank" rel="noopener" download>
              <span>Download PDF</span><span class="file-type">PDF</span>
            </a>
            <p class="file-description">The primary, print-ready version.</p>
          </li>
          <li class="file-item">
            <a class="file-link" href="${RTF_FILE}" target="_blank" rel="noopener" download>
              <span>Download RTF</span><span class="file-type">RTF</span>
            </a>
            <p class="file-description">An editable rich-text version.</p>
          </li>
          <li class="file-item">
            <a class="file-link" href="${TEX_FILE}" target="_blank" rel="noopener" download>
              <span>Download TeX source</span><span class="file-type">TeX</span>
            </a>
            <p class="file-description">The source used to generate the resume.</p>
          </li>
          <li class="file-item">
            <a class="file-link" href="${MD_FILE}" target="_blank" rel="noopener">
              <span>View AI-readable Markdown</span><span class="file-type">Markdown</span>
            </a>
            <p class="file-description">A plain-text-friendly version for automated readers.</p>
          </li>
        </ul>
      </section>

      <section class="metadata" aria-labelledby="metadata-heading">
        <h2 id="metadata-heading">Metadata</h2>
        <ul class="file-list">
          <li class="file-item">
            <a class="file-link" href="metadata.json" target="_blank" rel="noopener">
              <span>Build metadata</span><span class="file-type">JSON</span>
            </a>
          </li>
          <li class="file-item">
            <a class="file-link" href="SHA256SUMS" target="_blank" rel="noopener">
              <span>File checksums</span><span class="file-type">Text</span>
            </a>
          </li>
        </ul>
      </section>
    </main>

    <footer class="site-footer">
      <div class="shell"><hr class="rule"></div>
      <div class="shell footer-row">
        <span>Copyright &copy; $(date -u +%Y) Ryan Wallace</span>
        <nav class="footer-links" aria-label="Social links">
          <a href="https://github.com/ryancswallace">GitHub</a>
          <a href="https://www.linkedin.com/in/ryancswallace/">LinkedIn</a>
          <a href="mailto:ryan@ryancswallace.dev">Email</a>
        </nav>
      </div>
    </footer>

    <script>
      const themeButton = document.querySelector(".theme-toggle");
      const themeColor = document.querySelector('meta[name="theme-color"]');
      const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");

      function applyTheme(theme, persist = false) {
        document.documentElement.dataset.theme = theme;
        themeButton.setAttribute(
          "aria-label",
          theme === "dark" ? "Switch to light theme" : "Switch to dark theme",
        );
        themeColor.setAttribute("content", theme === "dark" ? "#212737" : "#fdfdfd");
        if (persist) window.rwThemePreference.saveTheme(theme);
      }

      applyTheme(document.documentElement.dataset.theme);

      themeButton.addEventListener("click", () => {
        const nextTheme = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
        applyTheme(nextTheme, true);
      });

      function syncSharedTheme() {
        const sharedTheme = window.rwThemePreference.getSharedTheme();

        if (sharedTheme && sharedTheme !== document.documentElement.dataset.theme) {
          window.rwThemePreference.setLocalTheme(sharedTheme);
          applyTheme(sharedTheme);
        }
      }

      window.addEventListener("focus", syncSharedTheme);
      window.addEventListener("pageshow", syncSharedTheme);

      systemTheme.addEventListener("change", (event) => {
        if (!window.rwThemePreference.getSavedTheme()) {
          applyTheme(event.matches ? "dark" : "light");
        }
      });
    </script>
  </body>
</html>
HTML

(
    cd "${DIST_DIR}"
    sha256sum "${PDF_FILE}" "${RTF_FILE}" "${MD_FILE}" "${TEX_FILE}" metadata.json index.html favicon.ico > SHA256SUMS
)

printf 'Built resume artifacts in %s for %s\n' "${DIST_DIR}" "${RELEASE_TAG}"
