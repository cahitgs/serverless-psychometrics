# Serverless psychometrics: Building privacy-preserving and sustainable web applications with webR and Shinylive

**Article type:** Tutorial (Behavior Research Methods, Tutorial Collection)
**Draft:** v0.1, 2026-07-29 — full working draft; items still to be completed before submission are marked **[TODO]**.

---

## Abstract

Interactive Shiny applications have become a standard vehicle for disseminating methodological innovations in behavioral research, yet the server-based architecture they rely on has three structural weaknesses: applications disappear when hosting lapses, users must upload their data — often sensitive — to third-party servers, and someone must pay for and maintain the server indefinitely. This tutorial shows that, for a large class of psychometric applications, the server can simply be removed. Using webR — a WebAssembly build of R that runs inside the browser — and the Shinylive export system, an ordinary single-file Shiny application becomes a folder of static files that any web server (e.g., GitHub Pages) can host indefinitely at no cost, with all computation performed on the user's own device and no data ever leaving the browser. We provide a step-by-step guide covering export, local testing, deployment, version pinning, and archival, and demonstrate it with two fully functional applications: OmegaLite (reliability analysis; McDonald's omega with bootstrap confidence intervals) and BiasDetectR Live (Mantel–Haenszel and logistic-regression differential item functioning analysis). Both apps depend only on base R, and their in-browser results match native R to machine precision — the DIF engine reproduces difR to a maximum absolute difference below 2 × 10⁻¹⁵, and identical bootstrap confidence intervals are obtained in both environments. Benchmarks show the browser analyzes 50,000 respondents × 20 items in under 10 seconds, approximately 1.2× native R runtime. We close with a decision guide on when server-based architectures remain necessary and a checklist for sustainable, privacy-preserving deployment.

**Keywords:** Shiny; webR; WebAssembly; Shinylive; reproducibility; open science; differential item functioning; reliability

---

## 1. Introduction

Over the past decade, the interactive web application has become one of behavioral research methodology's preferred dissemination formats. When a methodologist develops a new power-analysis procedure, a reliability estimator, or a differential item functioning (DIF) workflow, the accompanying paper increasingly ships with a Shiny application (Chang et al., 2024) so that readers can use the method without writing code. Shiny's uptake in research has been documented across disciplines (Kasprzak et al., 2021), and *Behavior Research Methods* is among the journals where the pattern is most visible: recent tutorials and method papers routinely direct readers to hosted applications — for example, a simulation-based power-analysis app for ROC analyses (Riesthuis et al., 2025) or a suite of at least six single-case-design tools hosted on shinyapps.io (Manolov, 2026).

This dissemination model has a structural weakness that is easy to overlook at publication time: a standard Shiny application is a *server process*. The R code does not run on the reader's machine; it runs on a remote computer that must remain switched on, funded, and maintained for as long as anyone wants to use the tool. This architecture creates three distinct problems.

**Problem 1: Tools die.** Link rot in the scholarly record is extensively documented: roughly one in five research articles citing web resources suffers reference rot (Klein et al., 2014), 38% of web pages that existed in 2013 were gone a decade later (Pew Research Center, 2024), and — most relevant here — *dynamic, database-driven content* decays far faster than static pages, remaining accessible in only 41% of cases versus 92% for static documents in a recent 20-year analysis (Sadatmoosavi et al., 2026). For research software specifically, bioinformatics has audited its web tools repeatedly, with sobering results: of 2,396 web tools published over a decade, only 31% were consistently reachable, and availability fell from about 90% for recent tools to about 50% for decade-old ones (Kern et al., 2020; see also Schultheiss et al., 2011; Wren et al., 2017; Ősz et al., 2019). Behavioral science has no comparable audit, but there is no reason to expect immunity: the journal's own reproducibility assessment found that research products degrade over time unless policy actively counteracts it (Ellis et al., 2024). Consistent with these expectations, a small availability spot-check we ran while preparing this tutorial (July 2026; 16 application URLs extracted from open-access *Behavior Research Methods* articles, 2017–2025) found only 4 URLs responding directly; 10 returned the shinyapps.io "waking up" interstitial that signals a dormant free-tier app, one returned HTTP 404, and one institutional Shiny server no longer existed in DNS. The raw probe data are in the accompanying repository. Notably, archived source code is not a functional substitute for a running tool: in a large-scale re-execution study, 74% of published R scripts failed to run in a clean environment (Trisovic et al., 2022) — and of our two dead example apps, one had no publicly findable source code at all.

**Problem 2: Data must travel.** With a hosted application, every dataset a user analyzes is uploaded to someone else's computer. For many psychometric use cases — item responses from clinical samples, school records, personnel selection data — this is not a mere inconvenience; it may violate data-protection rules or ethics protocols outright. The privacy argument for moving computation *to the user* rather than moving data *to the server* is already established in adjacent fields (Balasubramanian et al., 2024; Ge, 2025).

**Problem 3: Someone must pay.** Hosting is a recurring cost charged against non-recurring funding. Grant proposals rarely budget for keeping a web app alive beyond the project period (Saia et al., 2022; Coelho, 2024), and free hosting tiers — the de facto standard in academia — respond to this mismatch by putting apps to sleep, throttling them, and eventually deleting them.

### 1.1 The serverless alternative

All three problems share a single cause — the server — and therefore share a single remedy: remove it. WebAssembly (Wasm), a W3C-standardized binary format that all modern browsers execute, has made it possible to compile entire language runtimes for the browser, a development *Nature* has profiled as quietly transformative for scientific computing (Perkel, 2024). webR (Stagg et al., 2026) is a Wasm build of R itself; Shinylive builds on it so that an unmodified Shiny application can run with **zero server-side computation**: the "app" becomes a folder of static files — HTML, JavaScript, the webR runtime, and the R packages it needs — that any static file host can serve. After the initial page load, every computation happens on the user's device. The three problems dissolve simultaneously: static files on a free host do not die of neglect; data never leave the browser; and there is no server bill because there is no server.

Application notes using this stack have begun to appear in the life sciences (Ge, 2025), and a general Shiny reproducibility guide mentions Shinylive as a promising but — in the authors' 2024-era testing — "not stable nor fast enough" option (Brun et al., 2025). To our knowledge, however, no methods-oriented tutorial exists in psychology or behavioral science, and the stability concern deserves re-examination against current versions. This tutorial fills both gaps. We (a) explain how in-browser R works at the level of detail a methodologist needs; (b) provide a complete, tested workflow from `app.R` to a permanent, citable deployment; (c) demonstrate it with two fully functional psychometric applications — a reliability tool and a DIF tool — whose in-browser results we verify against the established native-R packages `psych` (Revelle, 2025) and `difR` (Magis et al., 2010) to machine precision; and (d) report benchmarks up to 50,000 respondents showing near-native speed, directly addressing the "not fast enough" objection. We close with a decision guide, because the serverless architecture is not universal: we state explicitly which application classes still need a server.

Both example applications are live now and will remain so:

- **OmegaLite** — https://cahitgs.github.io/serverless-psychometrics/omegalite/
- **BiasDetectR Live** — https://cahitgs.github.io/serverless-psychometrics/biasdetectr-live/

Source code, benchmark data, and all analysis scripts: https://github.com/cahitgs/serverless-psychometrics **[TODO: add Zenodo concept DOI at submission]**.

---

## 2. How an R application runs without a server

A conventional Shiny deployment splits the application in two: the browser renders the user interface, while a remote server executes the R code, with a continuous WebSocket connection carrying every slider movement and every result between them (Figure 1, left). Shinylive collapses this architecture into the browser (Figure 1, right). The R interpreter itself — compiled from C and Fortran sources to WebAssembly — is downloaded once as part of the page, then instantiated inside a web worker, a background thread that keeps the user interface responsive while R computes. The Shiny reactive engine runs unmodified on this in-browser R; a service worker intercepts the HTTP requests Shiny would normally send to a server and routes them to the in-browser session instead. From the perspective of your `app.R`, nothing has changed: `fileInput()` receives files (read locally from disk into the browser's virtual filesystem), `renderPlot()` draws plots, `downloadHandler()` produces downloads.

**[Figure 1 about here — architecture schematic: server-based vs. serverless. TODO: draw]**

Three properties of this design matter for research applications:

1. **The export is self-contained.** `shinylive::export()` copies the webR runtime, the Shinylive assets, and Wasm binaries of every R package your app uses into one folder. Our measured exports are 189 files / 68.4 MB for a base-R app. Nothing is fetched from a content-delivery network at run time, which is what makes an archived copy of the folder runnable decades from now.

2. **Computation happens on the user's device, verifiably.** Because the page needs no application server, the network tab of the browser's developer tools provides a direct privacy audit: once the app has loaded, analyzing an uploaded dataset generates *zero* outgoing network requests. We verified this instrumentally for both example apps (Section 6.3).

3. **The versions are frozen.** The exported bundle contains specific versions of R (4.6.0 in our exports), webR (0.6.0), and every package. The bundle is the reproducibility artifact: archive it, and the exact computational environment is preserved (cf. FAIR4RS principles; Barker et al., 2022).

The runtime environment is 32-bit WebAssembly, which caps R's memory at 4 GB (browsers, especially mobile ones, may grant less). For typical psychometric datasets — thousands to tens of thousands of respondents — this is not a practical constraint, as our benchmarks show.

---

## 3. Step-by-step guide: from app.R to a permanent application

This section is a complete, reproducible walkthrough. Every command was executed as written, on Windows 11 with R 4.4.1, shinylive 0.5.0 (Shinylive web assets 0.10.12, bundling webR 0.6.0 / R 4.6.0). Version details are recorded in `paper/versions.txt` in the repository.

### 3.1 Write the app as usual — with one design rule

A Shinylive app is an ordinary Shiny app. The single most consequential design decision is the dependency footprint. Every package you `library()` must exist as a WebAssembly binary; the webR repository currently compiles the large majority of CRAN (22,741 packages at the time of writing, including `psych`, `lavaan`, `mirt`, and `ggplot2`), so availability is rarely the obstacle it was in 2023–2024. But every dependency also inflates the download the user's browser must perform on first load. Our recommendation, which both example apps follow, is stricter than mere availability: **for statistical cores, prefer base R**. Base R ships inside the webR runtime at no additional download cost, and — as Sections 4–6 demonstrate — classical psychometrics (reliability coefficients, Mantel–Haenszel, logistic regression DIF) needs nothing more. Where you do need contributed packages, check availability by searching the package index at `repo.r-wasm.org` before writing code.

Two small compatibility adjustments belong in every Shinylive app:

```r
# 1. Raise the upload cap (default 5 MB) for realistic response matrices
options(shiny.maxRequestSize = 100 * 1024^2)

# 2. Chromium issue 468227: file downloads inside Shinylive fail on
#    Chrome unless the download attribute is stripped; harmless elsewhere
download_btn <- downloadButton("download", "Download results (CSV)")
download_btn$attribs$download <- NULL
```

### 3.2 Export

```r
install.packages("shinylive")
shinylive::export(appdir = "apps/omegalite", destdir = "site/omegalite")
```

The first export downloads the Shinylive assets (about 90 seconds on our connection); later exports reuse the cache and complete in seconds (measured: 88.1 s first, 3.1 s subsequent). Multi-file apps work: helper files in the app directory (e.g., our `dif_engine.R`) are bundled automatically.

### 3.3 Test locally — over HTTP, never file://

```r
httpuv::runStaticServer("site/omegalite")
```

Opening `index.html` directly from disk will not work: WebAssembly and service workers require an HTTP origin. This is the single most common beginner failure. (A minor observation from our testing: some development servers, including `httpuv`, serve `.wasm` files with a generic MIME type, which disables streaming compilation and slows the first load slightly; production hosts such as GitHub Pages serve the correct type.)

### 3.4 Deploy to GitHub Pages

Commit the exported folder to a public GitHub repository and add a standard `deploy-pages` workflow (the complete 30-line YAML file is in our repository at `.github/workflows/pages.yml`). Two practical notes from our deployment: (a) the workflow token cannot *enable* Pages on a repository the first time — run `gh api -X POST repos/OWNER/REPO/pages -f build_type=workflow` once, or click the equivalent switch in the repository settings; (b) GitHub Pages cannot send custom HTTP headers, so webR automatically falls back from its fastest communication channel (SharedArrayBuffer) to PostMessage — everything works, with the one limitation that a running computation cannot be interrupted mid-stream.

Measured cold load of the deployed OmegaLite over a residential connection: 16.4 s to a fully interactive app (7.2–10.7 s from a local server). Subsequent loads are faster because the browser caches the runtime.

### 3.5 Pin versions and archive the bundle

The Shinylive asset version can be pinned explicitly (`shinylive::export(..., assets_version = "0.10.12")` or the `SHINYLIVE_ASSETS_VERSION` environment variable). Because the wasm package binaries inside a bundle track the webR repository at export time, *rebuilding* an app later may silently produce different package versions. The reproducibility rule is therefore: **archive the exported bundle itself, not just the source.** Our recommended two-artifact archive, which satisfies TOP Level 2's trusted-repository requirement:

1. Tag a GitHub release; the Zenodo–GitHub integration archives the source and mints a DOI.
2. Deposit the exported `site/` folder as a zip in the same Zenodo record.

Anyone, at any future time, can then download the zip, unzip it, and run `httpuv::runStaticServer("site/omegalite")` — one command, no Shiny server, no internet dependency beyond the download itself. Optionally, trigger Software Heritage's "Save Code Now" for a third, source-level preservation layer with an ISO-standardized identifier (Di Cosmo & Zacchiroli, 2017).

### 3.6 Common pitfalls (all encountered and solved in this project)

| Pitfall | Symptom | Fix |
|---|---|---|
| Opening via `file://` | Blank page / service-worker error | Serve over HTTP (§3.3) |
| Chrome downloads | Download button does nothing | Strip `download` attribute (§3.1) |
| Upload cap | "Maximum upload size exceeded" | Raise `shiny.maxRequestSize` (§3.1) |
| First Pages deploy fails | `configure-pages` action error | One-time Pages enablement (§3.4) |
| Package missing in webR | Export or runtime error | Check `repo.r-wasm.org`; prefer base R |
| Rebuilt bundle differs | Package versions drift | Archive the exported bundle (§3.5) |
| Long computations | UI unresponsive while R runs | Show progress (`withProgress`); keep models modest; no interrupt under PostMessage |

---

## 4. Example 1: OmegaLite — reliability analysis in the browser

OmegaLite (Figure 2) is deliberately minimal — a complete, useful psychometric tool in roughly 140 lines of exclusively base-R-plus-shiny code, designed to be read as a template. The user uploads a CSV, selects item columns, and receives McDonald's omega-total with a bootstrap confidence interval as the headline metric — following the recommendation to prefer omega over alpha (McNeish, 2018) — alongside Cronbach's alpha for comparison, corrected item-total correlations, and alpha/omega-if-item-deleted tables, all downloadable as CSV.

**[Figure 2 about here — OmegaLite screenshot: figures/omegalite-e2e-test.png]**

The statistical core fits one paragraph. Omega-total is computed from a single-factor maximum-likelihood solution obtained with `stats::factanal()`: with standardized loadings λ, ω_t = (Σλ)² / [(Σλ)² + Σ(1 − λ²)] (McDonald, 1999). Alpha is computed from the covariance matrix. Confidence intervals use a nonparametric bootstrap (percentile method, fixed seed). No contributed package is involved, which is precisely why the app is guaranteed to behave identically in webR.

**Validation.** On a simulated one-factor dataset (N = 500, 8 items), OmegaLite's base-R implementations agree with the `psych` package (v2.5.6): alpha matches `psych::alpha`'s raw alpha exactly (difference 0), corrected item-total correlations and alpha-if-deleted match to machine precision (≤ 1.1 × 10⁻¹⁶), and omega differs from `psych::omega`'s one-factor ω_t by 1.0 × 10⁻⁴ — attributable to the two functions using different ML optimizers, not to the browser. Critically, running the *same data* in the deployed browser app reproduces the native-R results including the bootstrap confidence intervals digit-for-digit at reported precision, because webR is the same R (4.6.0) with the same random-number generator: ω_t = .868 [.851, .886], α = .865 [.846, .884] in both environments.

---

## 5. Example 2: BiasDetectR Live — DIF analysis in the browser

BiasDetectR Live (Figure 3) demonstrates that a research-grade analysis pipeline — not just a demo — fits in the browser. The app implements the two most widely used DIF procedures for dichotomous items, both in pure base R (file `dif_engine.R`, 120 lines):

- **Mantel–Haenszel** with total-score stratification (Holland & Thayer, 1988): common odds ratio α_MH, the ETS delta metric Δ_MH = −2.35 ln(α_MH), the MH chi-square with continuity correction, and the ETS A/B/C effect-size classification (|Δ| < 1: A/negligible; 1–1.5: B/moderate; ≥ 1.5: C/large).
- **Logistic regression DIF** (Swaminathan & Rogers, 1990): three nested models (total score; + group; + group × score), likelihood-ratio tests for overall, uniform, and non-uniform DIF, and Nagelkerke ΔR² effect sizes with the Jodoin and Gierl (2001) thresholds.

The user selects the group column, the focal group, and the item columns; output comprises both statistical tables, a Δ_MH plot with ETS thresholds drawn as reference lines, and a merged downloadable results table. IRT-based DIF methods (e.g., Lord's test, IRT-LR) are deliberately out of scope: their estimation burden and package dependencies make them better suited to server-based deployment, an explicit example of the decision guide in Section 7.

**[Figure 3 about here — BiasDetectR Live screenshot: figures/biasdetectr-e2e-test.png]**

**Validation against difR.** We simulated a 20-item, two-group 2PL dataset (N = 1,000; 500 per group; no impact) with DIF planted in three items: uniform DIF against the focal group in item 3 (+0.6 logits difficulty), uniform DIF favoring the focal group in item 12 (−0.5), and non-uniform DIF in item 7 (discrimination × 0.4, difficulty +0.3). Comparing our engine against `difR` v6.1.0 (`difMH`, `difLogistic`, matched settings, no purification) across all 20 items, the maximum absolute differences were: α_MH, 0; MH chi-square, 1.8 × 10⁻¹⁵; Δ_MH, 0; logistic LR statistic, 0; ΔR², 2.8 × 10⁻¹⁶ — machine precision throughout, with 100% agreement on ETS classifications (full table: `benchmark/equivalence_engine_vs_difR.csv`). The engine flags exactly the three planted items — items 3 and 12 by Mantel–Haenszel with correctly signed deltas, item 7 by the non-uniform logistic test (p = 3.1 × 10⁻⁷) — and the deployed browser app reproduces this flagging at every sample size tested.

---

## 6. Equivalence, performance, and the privacy audit

### 6.1 Statistical equivalence

Because webR *is* R — the same source code compiled for a different processor target — statistical equivalence is an architectural property, not a hope. The validations above bear this out empirically at two levels: our base-R engines versus the established native packages (`psych`, `difR`), and native execution versus in-browser execution of the same code, where even stochastic procedures (bootstrap CIs) reproduce exactly given a fixed seed. We recommend that authors report equivalence as a maximum-absolute-difference table, as we do, rather than as an assertion.

### 6.2 Speed

Table 1 reports analysis times for the full BiasDetectR pipeline (Mantel–Haenszel + three logistic models per item, 20 items), comparing native R (4.4.1, Windows laptop) with the deployed app in headless Chrome on the same machine.

**Table 1. Analysis time, native R versus in-browser (seconds).**

| Respondents | Native R | Browser | Ratio |
|---:|---:|---:|---:|
| 1,000 | 0.28 | 1.0 | 3.6× |
| 5,000 | 0.91 | 1.5 | 1.6× |
| 50,000 | 7.78 | 9.5 | 1.2× |

The browser's fixed reactive overhead dominates at small N; at realistic-to-large N the penalty shrinks to roughly 20%. A 50,000 × 20 DIF analysis completing in under ten seconds on a laptop browser should retire the "not fast enough for real data" objection (Brun et al., 2025), at least for this class of methods; OmegaLite's bootstrap (2 × 200 replications of a factor analysis, N = 500) completes in 1.5–1.6 s in the browser. App start-up is the real cost: 7–11 s from a local server, 16.4 s measured cold over the public internet, during which ~68 MB of runtime and assets are fetched (cached thereafter). **[TODO before submission: repeat the timing matrix on a mid-range phone and in Firefox/Edge, 3 replications per cell, report medians.]**

### 6.3 The privacy audit anyone can replicate

We instrumented a headless browser to log every network request while operating each deployed app: load the page, upload a dataset, run the full analysis, download results. For OmegaLite, the count of network requests between upload and results was **zero**, and at no point in either app's session was any host other than the page's own origin contacted — no CDNs, no telemetry, no third parties. (In BiasDetectR the analysis step generates a handful of same-origin requests — these are Shiny's plot images, produced and served *inside* the page by the service worker; they traverse no network.) Readers can replicate this audit in any browser: open developer tools → Network, load the app, then upload and analyze — the request log stays empty. We suggest this one-screenshot audit as a standard transparency practice for browser-based tools handling sensitive data. The airplane-mode variant — load the app, disconnect, analyze — demonstrates the same property physically; note it certifies *analysis-time* independence, not offline-first startup, which would additionally require the browser to have cached the app. **[TODO: airplane-mode screenshot series for the figure.]**

### 6.4 What dies and what survives: a recoverability note

Both dead applications from our spot check illustrate the archival argument of Section 3.5. For the app returning 404, we could find no publicly available source code (GitHub search, July 2026) — tool and code both gone, the outcome Trisovic et al. (2022) would predict is common. For the app whose institutional server vanished from DNS, source *is* recoverable from a public GitHub repository — but a repository is not a running tool, and reviving it is a project, not a click. Had either been deployed as an archived static bundle, "revival" would mean serving a folder.

---

## 7. Decision guide: when the server should stay

Serverless deployment is the right default for a specific — large — class of applications: self-contained statistical tools operating on user-supplied, modest-sized data. It is the wrong choice when the application requires:

- **Secrets.** All code and data in the bundle are visible to every user. API keys, proprietary item banks, or scoring keys cannot be protected.
- **Databases and persistence.** Browser apps cannot open arbitrary database connections, and nothing persists server-side; multi-user state, longitudinal data collection, and admin dashboards need a backend.
- **Heavy or long-running estimation.** MCMC (Stan-based models), large IRT calibrations, or anything measured in minutes: the 4 GB memory ceiling, absence of multiprocess parallelism, and inability to interrupt running code under the PostMessage channel all argue for a server.
- **Very large data.** As data approach the wasm32 memory ceiling (well under 4 GB in practice, especially on mobile), a server becomes necessary.
- **Guaranteed compute.** Performance on the user's device is the user's device's performance; a 2015 phone will be slow.

Conversely: classical test theory statistics, DIF screening, power analysis and simulation of moderate scale, effect-size calculators, plotting and diagnostics tools, and teaching demonstrations — essentially the entire genre of the methodological companion app — fit comfortably in the browser.

---

## 8. Limitations

The initial download is the price of self-containment: ~68 MB for a base-R app (once per user, then cached), more with heavy dependencies — keep the footprint lean. The wasm32 runtime caps memory at 4 GB with browser- and device-specific reductions. Long computations block the app's reactivity (though not the browser tab). The ecosystem moves quickly — webR released three minor versions in eighteen months — so pin and archive as in §3.5; our own exported bundles are the versioned artifacts backing this paper. Openness is structural: a serverless app cannot keep anything confidential, which is a feature for reproducibility and a constraint for proprietary instruments. Finally, our benchmarks cover one laptop and one browser engine; the phone and cross-browser matrix is pending **[TODO §6.2]**.

---

## 9. Concluding recommendations

For authors publishing methodological web applications, we propose a minimal sustainable-deployment checklist:

1. Prefer base R for statistical cores; check `repo.r-wasm.org` before adding dependencies.
2. Export with Shinylive; test over HTTP locally; deploy to a static host.
3. Pin the asset version; **archive the exported bundle** with a DOI (Zenodo), alongside the source (GitHub release + Software Heritage).
4. Print both the live URL and the archival DOI in the paper.
5. Include the one-screenshot network audit demonstrating that user data stay local.
6. State in the paper what the tool deliberately does not do, and whether a server-based variant exists for heavier use.

Journals could reinforce this practice by asking, at submission, where an interactive tool will live in ten years — a "maintenance and support statement" analogous to data-availability statements (Coelho, 2024) that a static, archived, serverless deployment satisfies almost trivially. The broader point of this tutorial is that for much of behavioral methodology, permanence, privacy, and zero cost are no longer competing goals requiring institutional infrastructure: they are one export command.

---

## Open Practices Statement

All source code (both applications, the DIF engine, simulation and benchmark scripts, and availability-probe tooling), the simulated datasets, benchmark results, version records, and this manuscript are openly available at https://github.com/cahitgs/serverless-psychometrics. **[TODO at submission: Zenodo concept DOI for the versioned archive including the exported application bundles; OSF deposit of benchmark raw data.]** The live applications are at the URLs given in Section 1.1. No human-participant data were used; all datasets are simulated. This tutorial was not preregistered.

## Declarations

- **Funding:** [TODO]
- **Conflicts of interest:** The authors declare no conflicts of interest.
- **Ethics approval:** Not applicable (no human participants; simulated data only).
- **Consent to participate / for publication:** Not applicable.
- **Availability of data and materials:** See Open Practices Statement.
- **Code availability:** See Open Practices Statement.
- **Authors' contributions:** [TODO]
- **AI-assistance disclosure:** Portions of the code and manuscript drafting were assisted by a large language model (Claude, Anthropic), with all analyses executed, verified, and approved by the authors. [Adjust wording to journal policy at submission.]

## References

*(APA 7. All entries verified against DOI where given; **[TODO: final citation-detail check before submission]**.)*

Balasubramanian, J. B., et al. (2024). Wasm-iCARE: A portable and privacy-preserving web module to build, validate, and apply absolute risk models. *JAMIA Open, 7*(2), ooae055. https://doi.org/10.1093/jamiaopen/ooae055

Barker, M., Chue Hong, N. P., Katz, D. S., et al. (2022). Introducing the FAIR principles for research software. *Scientific Data, 9*, 622. https://doi.org/10.1038/s41597-022-01710-x

Brun, C., Janée, G., & Curty, R. (2025). Ten quick tips for developing a reproducible Shiny application. *PLOS Computational Biology*. https://doi.org/10.1371/journal.pcbi.1013551

Chang, W., Cheng, J., Allaire, J. J., et al. (2024). *shiny: Web application framework for R* [R package]. https://CRAN.R-project.org/package=shiny

Coelho, L. P. (2024). For long-term sustainable software in bioinformatics. *PLOS Computational Biology, 20*(3), e1011920. https://doi.org/10.1371/journal.pcbi.1011920

Di Cosmo, R., & Zacchiroli, S. (2017). Software Heritage: Why and how to preserve software source code. *Proceedings of iPRES 2017*.

Ellis, D. A., Towse, J., Brown, O., et al. (2024). Assessing computational reproducibility in Behavior Research Methods. *Behavior Research Methods, 56*(8), 8745–8760. https://doi.org/10.3758/s13428-024-02501-5

Ge, X. (2025). DataMap: A browser-based app for visualizing high-dimensional data. *F1000Research, 14*, 1234.

Holland, P. W., & Thayer, D. T. (1988). Differential item performance and the Mantel–Haenszel procedure. In H. Wainer & H. I. Braun (Eds.), *Test validity* (pp. 129–145). Lawrence Erlbaum.

Jodoin, M. G., & Gierl, M. J. (2001). Evaluating Type I error and power rates using an effect size measure with the logistic regression procedure for DIF detection. *Applied Measurement in Education, 14*(4), 329–349.

Kasprzak, P., Mitchell, L., Kravchuk, O., & Timmins, A. (2021). Six years of Shiny in research — Collaborative development of web tools in R. *The R Journal, 13*(2). https://doi.org/10.32614/RJ-2021-004

Kern, F., Fehlmann, T., & Keller, A. (2020). On the lifetime of bioinformatics web services. *Nucleic Acids Research, 48*(22), 12523–12533. https://doi.org/10.1093/nar/gkaa1125

Klein, M., Van de Sompel, H., Sanderson, R., et al. (2014). Scholarly context not found: One in five articles suffers from reference rot. *PLOS ONE, 9*(12), e115253. https://doi.org/10.1371/journal.pone.0115253

Magis, D., Béland, S., Tuerlinckx, F., & De Boeck, P. (2010). A general framework and an R package for the detection of dichotomous differential item functioning. *Behavior Research Methods, 42*, 847–862. https://doi.org/10.3758/BRM.42.3.847

Manolov, R. (2026). A tutorial for software options to aid in assessing functional relations in single-case experimental designs. *Behavior Research Methods, 58*, 71. https://doi.org/10.3758/s13428-026-02951-z

McDonald, R. P. (1999). *Test theory: A unified treatment*. Lawrence Erlbaum.

McNeish, D. (2018). Thanks coefficient alpha, we'll take it from here. *Psychological Methods, 23*(3), 412–433.

Ősz, Á., Pongor, L. S., Szirmai, D., & Győrffy, B. (2019). A snapshot of 3649 web-based services published between 1994 and 2017 shows a decrease in availability after 2 years. *Briefings in Bioinformatics, 20*(3), 1004–1010. https://doi.org/10.1093/bib/bbx159

Perkel, J. M. (2024). No installation required: How WebAssembly is changing scientific computing. *Nature*. https://doi.org/10.1038/d41586-024-00725-1

Pew Research Center. (2024, May 17). *When online content disappears: Link rot and digital decay on government, news and other webpages*.

Revelle, W. (2025). *psych: Procedures for psychological, psychometric, and personality research* [R package]. https://CRAN.R-project.org/package=psych

Riesthuis, P., Otgaar, H., & Bücken, C. (2025). Ready to ROC? A tutorial on simulation-based power analyses for null hypothesis significance, minimum-effect, and equivalence testing for ROC curve analyses. *Behavior Research Methods, 57*. https://doi.org/10.3758/s13428-025-02646-x

Rubo, M. (2025). Creating a social virtual reality application for psychological research: A tutorial. *Behavior Research Methods, 57*. https://doi.org/10.3758/s13428-025-02693-4

Sadatmoosavi, A., Khasseh, A. A., & Tajedini, O. (2026). Link rot in LIS literature: A 20-year study of web citation decay, recovery and preservation challenges. *Aslib Journal of Information Management*. https://doi.org/10.1108/AJIM-05-2025-0286

Saia, S. M., Nelson, N. G., Young, S. N., Parham, S., & Vandegrift, M. (2022). Ten simple rules for researchers who want to develop web apps. *PLOS Computational Biology, 18*(1), e1009663. https://doi.org/10.1371/journal.pcbi.1009663

Schultheiss, S. J., Münch, M.-C., Andreeva, G. D., & Rätsch, G. (2011). Persistence and availability of web services in computational biology. *PLOS ONE, 6*(9), e24914. https://doi.org/10.1371/journal.pone.0024914

Stagg, G., et al. (2026). *webR: R in the browser via WebAssembly* (Version 0.6.0). https://docs.r-wasm.org/webr/

Swaminathan, H., & Rogers, H. J. (1990). Detecting differential item functioning using logistic regression procedures. *Journal of Educational Measurement, 27*(4), 361–370.

Trisovic, A., Lau, M. K., Pasquier, T., & Crosas, M. (2022). A large-scale study on research code quality and execution. *Scientific Data, 9*, 60. https://doi.org/10.1038/s41597-022-01143-6

Wren, J. D., Georgescu, C., Giles, C. B., & Hennessey, J. (2017). Use it or lose it: Citations predict the continued online availability of published bioinformatics resources. *Nucleic Acids Research, 45*(7), 3627–3633. https://doi.org/10.1093/nar/gkx182
