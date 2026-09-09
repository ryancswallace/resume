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

## Public resume

The [default resume](src/resume_ryan-wallace.tex) combines software engineering
and ML/AI experience for the resume page on my site. It emphasizes architecture,
performance, data systems, applied ML/AI, open source work, and technical
leadership.

Build and validate the public resume and its download page:

```bash
make dist
```

The outputs are `dist/resume_ryan-wallace.{pdf,rtf,md,tex}`. The existing GitHub
Pages workflow publishes this version when changes are pushed to `main`, using
the same public download URLs.

## Targeted resumes

Two additional resumes target senior and lead individual-contributor roles:

| Version              | Source                                                         | Build command                     |
| -------------------- | -------------------------------------------------------------- | --------------------------------- |
| Software engineering | [TeX source](src/resume_ryan-wallace_software-engineering.tex) | `make build-software-engineering` |
| ML/AI engineering    | [TeX source](src/resume_ryan-wallace_ml-ai-engineering.tex)    | `make build-ml-ai-engineering`    |

Build and validate both versions:

```bash
make build-variants
```

Each version produces PDF, RTF, Markdown, and standalone TeX artifacts, along
with a local download page, metadata, and checksums:

- Software engineering: `dist/software-engineering/resume_ryan-wallace_software-engineering.*`
- ML/AI engineering: `dist/ml-ai-engineering/resume_ryan-wallace_ml-ai-engineering.*`

The software version emphasizes architecture, performance, data systems, and
technical leadership. The ML/AI version emphasizes classification, fine-tuning,
model evaluation, GPU infrastructure, and RAG. Both put Boston Fed experience
before open source projects and retain the senior research title, GPA, and
Harvard Data Ventures experience.

All three versions omit a summary and use a two-page layout with name and email
in the second-page header. To generate all three versions under `dist/` locally,
run `make dist` followed by `make build-variants`; the default build clears
`dist/` first. Building locally does not publish the resumes.

## CI validation and publishing

GitHub Actions and local builds use the same CI command:

```bash
make ci
```

This runs source checks, builds all three resumes, and validates their PDF,
RTF, Markdown, and TeX artifacts, metadata, download pages, and checksums. PDF
checks require exactly two pages and extractable name, email, and section
headings. Builds finish before their output checks run, including with parallel
Make execution.

CI keeps the combined public resume in `dist/` and writes the specialized
versions to separate directories:

- `build/targeted-resumes/software-engineering/`
- `build/targeted-resumes/ml-ai-engineering/`

Each version is uploaded as a separate review artifact with 30-day retention.
Only the combined resume in `dist/` is included in GitHub Pages and archival
releases on pushes to `main`.
