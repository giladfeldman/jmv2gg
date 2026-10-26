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

## Recorded release checks (0.2.6, before release)

- Pinned BetterGG 0.2.3 (tag v0.2.3, commit 90228b1). Its own checks: 508 tests passed,
  R CMD check with one deliberate note; a second-model check (Sonnet) confirmed the Wilson
  score interval of the new proportion chart.
- R suite (tools/check.R): 808 checks, 0 failures, 1 skip (no native oxipng). The changed
  code snapshot (argument matrix) adds only BetterGG 0.2.3's two weight checks.
- `R CMD check --no-manual`: Status OK. vitest 50 passed; typecheck and production build
  passed; browser package rebuilt in the pinned WebR 0.6.0 container, manifest names BetterGG
  commit 90228b1, hash guard passed.
- Found during release and fixed with tests: a column named like a statistic symbol (p, t,
  F) rewrote statistics text ("p = .041" became "Price = .041"); now statistical notation is
  left alone (a second-model check confirmed the pattern; its realistic cases are tests).
  A PNG height test that passed for any size now checks the real size (7.65 in for 51 bars).
- Local production build in a real browser (WebR): an ANOVA on columns p and t with labels
  drew "Pain score" and "Time point" as axis titles and left the statistics subtitle
  ("F(2, 33) = 25.47, p < .001, ...") and pairwise labels unchanged, with no error.
- The owner reviewed before/after sheets of a 60-figure R Markdown re-render (labels, 0/1
  proportions, percentage bars, ordered palettes, tall bar charts) and approved them.

## Recorded release checks (0.2.5, before release)

- Pinned BetterGG 0.2.2 (tag v0.2.2, commit 3ac5fe0). Its own checks: 409 tests passed,
  R CMD check with one deliberate note; the owner approved a side-by-side gallery of its
  visual changes (same data, statistics unchanged).
- R suite (tools/check.R) against BetterGG 0.2.2: 715 checks, 0 failures, 1 skip (no
  native oxipng). The 8 changed code snapshots (argument matrix) were read line by line:
  every change is BetterGG 0.2.2 figure code (angled labels, histogram label headroom and
  whole-number counts, reliability constant-item guard and unclipped labels, grey
  correlation crosses, raincloud dot fill); Cronbach's alpha and item-rest formulas are
  unchanged apart from the constant-item guard.
- Browser package rebuilt in the pinned WebR 0.6.0 container; the manifest names BetterGG
  commit 3ac5fe0 (a test now requires it to equal the DESCRIPTION pin) and websocket was
  reused unchanged. Hash guard passed; vitest 45 passed; production build passed.
- Local production build in a real browser, complex R Markdown example: 11 of 11 analyses
  converted (26 figures), the generated code carries the BetterGG 0.2.2 changes, a
  simulated reliability preview drew, and the report preview rendered all 21 chunks with
  27 figures and no error or warning output.
- `R CMD check --no-manual` with the C locales of tools/check.ps1: Status OK after the
  non-ASCII column-name cases were moved into a test that skips outside a UTF-8 session
  (tools/check.R runs them); the first run had 6 failures, all from those two cases.

## Recorded release checks (0.2.4, before release)

- Owner report: the browser render of a private report took about 15 minutes and stopped;
  previews on simulated data printed NA. Causes found and fixed: simulated factors had one
  shared pattern (confounded, so F(0, df) = NA); the browser render also wrote every figure
  file at 600 dpi and stopped at fixed limits; and styler, which tidied the generated code
  in the browser, took 36-57 s per figure block with statistics on (WebR 0.6.0, Node
  harness), after which the conversion of the complex example failed with "A non-local
  transfer of control occurred during evaluation". The browser no longer runs styler.
- Local production build, complex R Markdown example, statistics on: conversion of 11 of
  11 analyses (26 figures) in under 40 s (it had failed after several minutes); the styler
  note shown; a simulated contingency-table preview printed chi-squared(1) = 0.17,
  p = .683, V = 0.04, n = 100; the report preview (limit selector, 15 minutes suggested for
  21 chunks) rendered all 21 chunks in about 5 minutes with 27 figures, no NA or NaN in
  any output, and the note that figure files are written only when knitting in R.
- Every statistic printed on those figures equals jmv's result for the same call on the
  bundled data (n = 234): ANOVA F = 32.33, 16.66, 0.75 (partial eta-squared .13, .13, .01);
  ANCOVA F = 30.85 and 8.28; paired t(233) = -11.63; Student and Welch t = -1.64, p = .103;
  linear regression b = 0.42, 0.01, -0.07 with t = 7.10, 2.76, -0.52; logistic OR = 1.98
  and 1.18 (z = 4.89, 0.55); chi-squared(2) = 5.61, p = .060, Cramer's V = .15 (ggplot2;
  BetterGG prints the bias-corrected .12, as its note says); alpha = .77; correlations.
- Contingency figures: Cramer's V found bias-corrected (.00 against jamovi's .16) by a
  cross-model review; the ggplot2 figure now prints jamovi's uncorrected V (tested equal to
  jmv's v[cra]). A private corpus recheck of 61 flagged files: 908 analyses, 881 drawn
  cleanly, no NA; the rest were informational messages. The sweep of the other 370 files
  did not finish (all R jobs stopped together) and is logged as debt.

## Recorded release checks (0.2.3)

- A private replication report (37 analyses, 158 KB; not in this repository) took
  minutes to convert in the web app with no estimate. Natively, the identifier scan took
  82.6 s of it when the text was not marked UTF-8; with `useBytes` the conversion
  without styler takes 1.2 s, and the converted text is byte-identical (styler off and
  on). styler took about 28 ms per generated line in WebR (about 9 ms natively).
- A private corpus of 625 jamovi R Markdown files converted without an error (styler
  off; slowest 3 s, median 0.2 s); its generated code reached 40,660 lines, so the
  browser now skips styler above 2,000 lines, with a note (checked in a browser on a
  local production build: a 4,044-line conversion took 16 s and showed the note).
- Figure chunk headers: with 0.2.2, 430 of 11,287 figure chunks in 85 of the 625 files
  had a header split over two lines, which knitr shows as text without drawing the
  figures; with 0.2.3, 0. The private report then rendered natively with all 120
  figures, 9 generated models matching the original jamovi inference, and identical
  original result records (it had drawn 106 of 120).
- Conversion progress (chunks, then styler parts, with estimates) and the report render
  were checked in a browser on a local production build: 27 figures, the jmvcore note
  once, Cronbach's alpha 0.7722. Native suite: 535 assertions, zero failures/errors/skips;
  web tests 40.
- Live, https://jmv2gg.vercel.app at revision 415d06b (footer and build info 0.2.3),
  2026-10-23: `tools/validation/deployment.mjs` passed. Converting the complex R Markdown
  example (11 of 11 analyses, 26 requested figures) showed "Tidying the generated code:
  part k of 12" with a whole-job estimate counting down ("about 50 s left" to "about
  10 s left"). The browser render ran 21 of 21 chunks in about 2 minutes with an
  estimate, 27 figures, the jmvcore note once and Cronbach's alpha 0.7722; the output
  frame has `sandbox=""`. The private report itself was not converted in a browser.

## Recorded release checks (0.2.2)

- Live check of 0.2.1 in a real browser showed the converted report without the jmvcore
  fallback: styler (on by default) kept only the first part of the setup chunk. Fixed in
  0.2.2 and covered by a test with styler on; 0.2.1's QA and knit checks had run with
  styler off. With 0.2.2's default settings the converted complex example knits with
  jmvcore 28.3 / jmv 2.8.0: one note above the reliability text, 27 figures. Native
  suite: 521 assertions, zero failures/errors/skips.
- Live, https://jmv2gg.vercel.app at revision 1f66376 (footer and build info 0.2.2),
  2026-10-23: converting the complex R Markdown example with default settings gives
  code containing the fallback block; the browser render ran 21 of 21 chunks with 27
  figures, and the reliability chunk shows the note once, then Cronbach's alpha 0.7722
  as text, the same value as the native jmvcore 28.3 knit. GitHub CI on that revision
  (jmvcore 28.3): 516 assertions, zero failures/errors, one skip (no oxipng there); the
  0.2.1 run had failed on this report.

## Recorded release checks (0.2.1)

- jmvcore 28.3 / jmv 2.8.0 (current CRAN): a document printing `jmv::reliability` failed
  to knit to HTML ("invalid argument type" in jmvcore's knitr printer), for the original
  example report as well as the converted one; GitHub CI showed it first (local R had
  jmvcore 2.7.7). With 0.2.1's setup-chunk fallback the converted complex report knits
  with jmvcore 28.3: reliability printed as text under the note "jmvcore could not
  print this jamovi result as HTML (invalid argument type)" (Cronbach's alpha 0.7722), the
  contingency table 5.611, all 27 figures embedded; the unconverted original still fails
  there (control). Review found that re-running the setup chunk in one session made
  the first version print every jamovi result as text; fixed and tested. Native suite:
  519 assertions, zero failures/errors/skips.

## Recorded release checks (0.2.0)

- Native Windows R 4.6.1: 514 assertions at the final BetterGG pin (see the release
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

## Live deployment checks (https://jmv2gg.vercel.app, revision 5194849, 2026-10-23)

- `tools/validation/deployment.mjs` against the live site: passed (revision, clean source,
  versions 0.2.0, artifact checksum, package index, headers, crawler denies).
- Real browser (Chromium in the Claude desktop app): the complex R Markdown example
  converted (11 of 11 analyses, 26 requested figures, about 1.5 minutes including R
  start and installs); the pre-render check found nothing to review; the full browser
  render with the bundled synthetic data finished all 21 chunks with 27 embedded figures
  in about 3 minutes, with per-chunk progress and estimates. The contingency table printed
  chi-squared 5.611, df 2, p .060, N 234 (same as native jmv), and the preview note states
  that 'websocket' is the labelled placeholder. The output frame has `sandbox=""`.
- A `fetch` to an outside host from the live page was refused by the
  Content-Security-Policy (`connect-src 'self' https://webr.r-wasm.org
  https://repo.r-wasm.org`).
- The first production build of 0.2.0 (623ba8e, tag v0.2.0) stopped at the stale-package
  guard: a CRLF working copy of the example CSV had been hashed. Rebuilt from LF sources
  (5194849); `web/tests/build-sources.test.ts` now checks this. The v0.2.0 tag was kept;
  the R sources at the tag are unchanged; only the browser binaries were rebuilt.

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
