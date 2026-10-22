# Capabilities, validation evidence, and limits

Recorded for release 0.2.0 on 2026-10-22 (0.1.0 results are in the git history of
this file). Rerun relevant checks after changes. Feature names do not establish
universal statistical equivalence.

## Execution matrix

| Capability | Native R | Browser/WebR 0.6.0 |
|---|---|---|
| Pasted code and Rmd conversion | Yes | Yes, the actual installed R package (BetterGG recipes included) |
| ggplot2 / BetterGG / both code generation | Yes | Yes |
| ggplot2 figure preview | With plotting dependencies | Prepared CSV/SAV, bundled synthetic data or labelled simulation |
| Report rendering | rmarkdown + Pandoc (reference) | knitr + markdown preview in a fresh worker, after a risk scan and confirmation |
| BetterGG figures | Yes | In the report preview; ggstatsplot's parametric/nonparametric pairwise tests need Rmpfr, which WebR lacks |
| PNG / PDF / TIFF exports | Yes (ragg, cairo_pdf) | PNG previews; the generated code writes all formats in native R |

## Mapping contract

See README "Figures per analysis" and R/map-groups.R, R/map-other.R. Statistics on
figures (style stats = TRUE) are computed in the generated code; each one is tested
against jmv's own result object (tests/testthat/test-figure-statistics*.R). Where a
figure could not match the source (e.g. type II sums of squares in factorial designs,
an uncorrected repeated-measures table with three or more levels, unequal expected
proportions), no statistics are drawn and a note says why. Case weights follow jmv:
applied in descriptives, contingency tables, linear and logistic regression; not used
by jmv's ANOVA and ANCOVA, hence not by these figures; refused for correlations,
t-tests, repeated measures and reliability.

## Recorded release checks (0.2.0)

- Native Windows R 4.6.1: 496+ assertions at the final BetterGG pin (see the release
  commit's tools/check.R run), zero failures/errors/skips (oxipng on PATH); earlier run 477,
  including 68 figure-statistic comparisons with jmv 2.7.7, 7 regression tests from a
  second-model review (Sonnet, 2026-10-22, tier 2), an argument-form matrix with code
  snapshots, the adversarial browser-render set and the bundled examples (the complex
  report knits natively with every figure embedded). Test floor in tools/check.R: 470.
- BetterGG 0.2.0 (released at d9db9cf, tag v0.2.0): 271 checks (floor 148), zero
  failures/errors/skips; R CMD check one NOTE, by design: ggstatsplot stays in Depends
  without being imported, so BetterGG's namespace loads with rlang alone in WebR
  (documented in BetterGG's R/imports.R). Its original tests also pass with
  ggstatsplot 1.1.2 (the WebR version); 5 recipe look-alike checks differ there because
  1.1.2 draws within-subject clouds and bars slightly differently.
- Private corpus (local only, never committed): 625 R Markdown files with jmv or
  ggstatsplot calls, 599 after removing version chains, 11,682 analyses; 10,865 (93%)
  convert. AI review limited to the 21 projects that the owner's CV lists as published.
- WebR build: jmv2gg and BetterGG binaries built in the pinned ghcr.io/r-wasm/webr:v0.6.0
  container; the manifest records BetterGG's commit and both checksums. Rmpfr could not
  be built there (MPFR system library unavailable).

## Real-browser checks (local production build, production headers, 2026-10-22)

- Conversion of the complex R Markdown example in WebR: complete; the progress panel shows
  the step, counted package installs ("39 of 50"), elapsed time and an estimate; the setup
  block lists versions (pinned web-app versions for packages not installed in WebR).
- Full in-browser render of the complex example with the bundled synthetic data: all 21
  chunks, 27 embedded figures, about 2.8 minutes after installs, with per-chunk progress.
  This needed three fixes found by this check: the exported render functions were missing
  from NAMESPACE; YAML `params` were not provided; the knitted YAML header broke the
  markdown step (`toc: true`).
- jamovi contingency tables in the browser: `jmv::contTables` -> vcdExtra -> webshot2 ->
  chromote -> websocket, and websocket has no WebR build (checked against the WebR 4.6
  repository index). With the app's labelled placeholder (`tools/webr/placeholders/
  websocket`, owner decision 2026-10-22) the chain loads; the browser report printed
  chi-squared 5.611, df 2, p .060, N 234 for the example's table, the same as native jmv
  (5.611454, 2, 0.06046279, 234; pinned in tests/testthat/test-render-safety.R). The
  placeholder errors on any use (tested).
- jmvcore 28.3's knitr HTML printer fails on the reliability result in WebR ("invalid
  argument type"); the preview now prints such a result as plain text instead of failing
  (tested with a failing printer). Render errors now name the chunk.
- Adversarial: R `download.file`/`readLines(url())` to an outside host were blocked by
  the page's Content-Security-Policy (connect-src violations logged); `webr::eval_js` is
  refused by the pre-render scan; the output frame has `sandbox=""` (no scripts, no same
  origin) and contains no script, event handler, `javascript:` link or outside image
  address (outside `src`/`srcset` are now removed in R as a second layer).

## Private corpus render and figure review (counts only; files stay private)

- 21 published projects (owner's CV list): native renders of the converted reports
  mostly stop for reasons in the original documents (packages missing on this machine,
  data files outside the copied folder, RStudio-only calls); the two ambiguous failures
  were re-run on the unconverted originals and fail identically, so neither is jmv2gg's.
- Figure review (Claude Sonnet, cross-model, 26 figures from 4 projects that drew
  figures): correct variables 26/26; notes 26/26 after fixing two "nothing known" notes
  (jamovi box/violin/dot plots drawn as histograms; ggstatsplot pairwise comparisons not
  drawn); labels 24/26 and overlap 22/26 (clipped facet titles fixed in BetterGG 0.2.0;
  scatter marginal ticks, label boxes and the correlation-matrix cross logged as BetterGG
  issues).

## Explicit verification boundaries

Results not listed above were not run for this release. The real-browser checks of
conversion and preview are recorded in the release notes of the deployment; the
browser report preview's network/DOM isolation relies on the page CSP and the empty
iframe sandbox, verified in a real browser before release.
