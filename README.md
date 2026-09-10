# Resume - Ryan Wallace (@ryancswallace)

My resume is:

- Written in TeX;
- Rendered to PDF, RTF, and Markdown;
- Released as versioned GitHub release assets;
- Deployed (current version only) to GitHub Pages.

**Current files:** `resume.ryancswallace.dev`

---

## Quickstart

```bash
make help
```

## Resume

The [resume](src/resume_ryan-wallace.tex) is the single version used for senior
and lead individual-contributor software engineering and ML/AI engineering
applications and the resume page on my site.

Build and validate the resume and its download page:

```bash
make dist
```

The outputs are `dist/resume_ryan-wallace.{pdf,rtf,md,tex}`. The existing GitHub
Pages workflow publishes this version when changes are pushed to `main`, using
the same public download URLs. Building locally does not publish the resume.

## CI validation and publishing

GitHub Actions and local builds use the same CI command:

```bash
make ci
```

This runs source checks, builds the resume, and validates its PDF,
RTF, Markdown, and TeX artifacts, metadata, download pages, and checksums. PDF
checks require exactly two pages, all three projects on page 1, Earlier
Experience at the start of page 2, and extractable name, email, and section
headings. Builds finish before their output checks run, including with
parallel Make execution.

CI uploads `dist/` as one review artifact with 30-day retention. On pushes to
`main`, GitHub Pages receives `dist/`, and an archival release stores the PDF,
RTF, Markdown, and TeX exports with metadata and checksums.
