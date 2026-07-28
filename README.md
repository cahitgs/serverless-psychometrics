# Serverless Psychometrics

Companion repository for the tutorial manuscript *Serverless psychometrics:
Building privacy-preserving and sustainable web applications with webR and
Shinylive* (in preparation for *Behavior Research Methods*).

## Contents

- `apps/omegalite/` — OmegaLite, a minimal reliability-analysis Shiny app
  (McDonald's omega + Cronbach's alpha with bootstrap CIs) that depends only on
  base R + shiny, so it runs unchanged as a server app or fully in the browser
  via Shinylive.
- `site/` — static Shinylive exports (`shinylive::export()` output; never
  edited by hand). Deployed to GitHub Pages by `.github/workflows/pages.yml`.
- `audit/` — availability audit of Shiny applications published in *Behavior
  Research Methods* 2015–2025: preregistration protocol (`protocol.md`),
  automated probe (`check_links.R`, run daily by
  `.github/workflows/probe.yml`), candidate harvest (`harvest_epmc.R`), and
  probe logs (`probes/`).
- `benchmark/` — equivalence and performance measurements (server vs. browser).
- `paper/` — manuscript sources (Quarto) and `versions.txt` (pinned R /
  shinylive / webR versions).

## Run the exported app locally

```r
httpuv::runStaticServer("site/omegalite")
```

Serving over HTTP is required; opening `index.html` via `file://` will not
work (WebAssembly + service worker restrictions).

## License

Code: MIT (see `LICENSE`). Manuscript text and figures: all rights reserved
until publication.
