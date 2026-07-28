# Audit Protocol: Availability of Shiny Applications Published in *Behavior Research Methods* (2015–2025)

**Version:** 1.0 (drafted 2026-07-27, before data collection)
**Status:** To be registered on OSF prior to link classification.

## 1. Objective

Quantify the current availability of interactive Shiny web applications whose URLs were published in *Behavior Research Methods* (BRM) articles between 2015 and 2025, and identify predictors of survival. Methodological template: Kern, Fehlmann, & Keller (2020, *Nucleic Acids Research*, 48:12523), adapted from bioinformatics web services to psychology research tools.

## 2. Sampling frame

- **Source:** Full-text search of *Behavior Research Methods* (Springer Link; supplemented by the Europe PMC full-text API for open-access articles).
- **Search strings:** `"shinyapps.io"` (primary); `"shiny application"` and `"Shiny app"` (secondary, manually screened for app URLs hosted elsewhere, e.g., institutional servers).
- **Publication window:** 2015-01-01 to 2025-12-31 (issue publication date).
- **Inclusion:** The article body or supplementary material states a URL to a live, interactive web application intended for reader use.
- **Exclusion:** Articles that only link a code repository or CRAN package with no hosted application URL; links to generic platforms (OSF project pages, GitHub repos) that are not themselves applications.
- **Unit of analysis:** the application URL (an article can contribute multiple URLs; article-level summaries reported separately).

## 3. Automated probing

- Script: `audit/check_links.R` (R, httr2). Configuration is fixed and reported: 30-second total timeout, redirects followed (libcurl default limit), desktop User-Agent string, one probe per URL per run.
- **Repeated measurement:** all URLs probed daily for a minimum of 14 consecutive days via a scheduled GitHub Actions workflow (`.github/workflows/probe.yml`). Each run appends a dated CSV under `audit/probes/`.
- Automated fields per probe: HTTP status, response time, final URL after redirects, redirect flag, TLS/DNS/timeout error class, and presence of known *soft-failure* text markers in the response body.
- **Known trap (pre-specified):** shinyapps.io serves sleeping/suspended/quota-exhausted pages with HTTP **200**. Automated status alone therefore only pre-screens; every URL that ever returns 2XX is classified manually.
- **Pilot observation (2026-07-27):** shinyapps.io returns HTTP **202** with a "starting up" interstitial while a sleeping app wakes. The probe records 202 as a distinct class (`waking_202`); it indicates a deployed (possibly intermittent) app, not a dead one.

## 4. Outcome: graded availability scale (manual classification)

Each application is classified on the most complete level it achieves during the observation window, following Mangul et al. (2019) and Escamilla et al. (2024):

| Level | Criterion |
|---|---|
| A1 | URL resolves (any 2XX after redirects) |
| A2 | The intended application renders (not a sleep/suspended/error/parked page) |
| A3 | The application accepts input (e.g., file upload or form interaction) |
| A4 | The application returns plausible output for a standard test interaction |
| R (recoverability) | If dead: source code recoverable? (GitHub/GitLab/CRAN/OSF/Zenodo/Software Heritage), recorded separately |
| W (web archive) | Any functional or partial capture in web archives (checked via Memento aggregator / Wayback Machine), recorded separately |

Temporal availability over the probing window is additionally coded as **always / intermittently / never** reachable (Kern et al., 2020).

Manual classification rules:
- Redirects to a different application or a successor tool are coded as *content drift*, not success (Klein et al., 2014).
- A 200 response bearing any soft-failure marker (e.g., "application has been suspended", usage-limit or sleeping pages that require a wake that then fails) is at most A1.
- A sleeping app that successfully wakes within 60 s and then functions is A2+ (temporal status will reflect intermittency).
- If a second coder is available, a random 20% subsample is double-coded and percentage agreement plus Cohen's kappa reported.

## 5. Predictors (per URL)

Publication year; citation count of the source article (Crossref, retrieved at analysis date); hosting type (shinyapps.io / institutional server / other); whether source code was deposited anywhere citable; article published before vs. after BRM's 2020 TOP Level 2 policy adoption.

## 6. Analysis plan

- Headline descriptive: percentage of applications at each availability level, overall and by publication year.
- Survival analysis: Kaplan–Meier curve of availability by years-since-publication (event = first classified dead at audit; right-censored if alive), with published half-life benchmarks overlaid as reference lines (Ősz et al., 2019: 10.39 years; Hennessey & Ge, 2013: 9.3 years).
- Logistic regression of alive (A2+) on predictors in §5. Exploratory given expected N (~100–150 URLs).
- All raw probe data, the manual coding sheet, and analysis code will be deposited on OSF.

## 7. Deviations

Any deviation from this protocol after registration will be documented in a dated `audit/deviations.md` and disclosed in the manuscript.
