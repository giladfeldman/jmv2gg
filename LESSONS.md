# Implementation checks

- Preserve source statements, explicit model terms, case weights, and factor
  value mappings. A factor's internal index is not its numeric measurement.
- Compare generated models against the original jamovi implementation. Its
  ANOVA table can include an additional overall-model summary row; compare
  matching terms, degrees of freedom, sums of squares, F and p values.
- Use underscore-only generated R bindings. Hyphens in a file name are valid;
  hyphens in an unquoted variable name are subtraction.
- Preserve chunk labels verbatim when updating presentation options. Labels
  containing hyphens are not R expressions to deparse.
- Generated plots must restore the original random-number state, including
  errors, to avoid affecting subsequent analyses.
- Plots inside tryCatch must be printed explicitly for knitr to embed them.
  Saving PNG files alone does not verify that figures appear in the report;
  the knitting regression test checks the emitted image reference separately.
- BetterGG's categorical palette must cover observed levels. Use explicit
  readable alias columns where an upstream plot cannot handle a column name.
- Many-category pies need a compact bottom legend and no overlapping slice
  labels. Keep all categories and statistical output; check actual exported
  pixels because an upstream label argument can be overridden internally.
- Descriptive histogram and frequency counts must use the source case weights.
  Additional BetterGG tests must explicitly disclose unweighted or pooled
  comparisons. Reject weighted correlations rather than silently dropping weights.
- WebR's official runtime distribution must be tested with an actual PNG
  export. Successful initialization alone does not verify a graphics device.
- The pinned Emscripten runtime uses JavaScript eval while loading side modules.
  A wasm-unsafe-eval-only CSP stalled initialization in the production-header
  browser test. The static app therefore allows unsafe-eval with fixed script
  and connection origins; uploaded source is never evaluated by the preview.
- Results returned by WebR function execution do not belong to its root
  shelter. Destroying them there can discard a successful conversion.
- Browser preview uses baseenv as its parent; qualify stats replacement
  functions such as contrasts<- explicitly. Native tests with attached stats
  do not exercise that boundary; test the JSON preview bridge directly.
- Compile the browser package after R changes. Production builds verify its
  source hashes and binary checksum before accepting the artifact.
- PNG optimization is optional and lossless: verify decoded pixels, dimensions,
  and resolution before replacing an export, and retain the smaller file.

- Release packaging must explicitly exclude .env files even when Git ignores them. Inspect source archive members after linking hosting tools; Git ignore and R build ignore have different boundaries.

- Vercel modifies .vercel/project.json and creates an untracked root vercel.json during hosted builds (observed in production logs). Preserve the raw dirty flag, disclose these exact provider changes, and verify sourceTreeDirty separately; unexpected or local changes must still fail.

## Documentation and maintenance handoff

- Keep prototype assumptions out of current guidance. Explicit source terms must
  survive even if a historical generator always expanded interactions.
- Separate release evidence from current verification. Optional dependencies and
  platforms change assertion/skip counts; disclose NOT RUN checks explicitly.
- Explain the shared converter versus execution boundary: WebR runs the actual
  R package; full rmarkdown/Pandoc HTML is native-R only. BetterGG figures render in the
  browser report preview, except ggstatsplot's pairwise tests that need Rmpfr.
- Documentation edits are not a deployment. Record uncommitted files, immutable
  release tags, deployed SHA and the next gate before publishing changes.
- Public docs use synthetic examples and generic paths. Keep owner decisions,
  private inputs, backups/history details and handoffs outside public source/archives.

## 0.2.6: changing a finished ggplot

- `copy <- ggplot2::ggproto(NULL, layer)` copies a layer or guide; `layer <- ggproto(NULL,
  layer)` loops forever (the parent is read lazily, after the name points at the child).
- Renaming categories on a finished figure must also rename everything keyed by category
  name: a manual scale with named values (`scale_fill_manual(values = c(a = ...))`) maps by
  name and keeps a limits function built from those names, so both need the new names or
  the renamed category is drawn grey. Precomputed tick labels keyed by group need a column
  named after the variable and positional labels (BetterGG 0.2.3 `recipe_proportion`).
- Whole-word replacement of column names in figure text also hits statistical notation
  when a column is named like a symbol: with `p = "Price"`, "p = .041" became "Price = .041"
  and "t-test" "Time-test", with no test failing. An operator lookahead was not enough ("Cohen's d",
  "Pr(>F)", "n/a" still broke): a symbol-named column is relabelled only before ":", "×",
  " / " or at the end. Match the names in an atomic group, or a longer name that fails the
  lookahead backtracks to a shorter one ("Age group = 1" -> "<Age label> group = 1"). PCRE
  rejects code-point escapes above 255 outside UTF mode: paste the characters in with
  `intToUtf8()`, and add `(*UCP)` so letters such as Ö count as word characters.
- A BetterGG re-pin leaves other copies of the pin behind: README's install line stayed at v0.2.0 and the
  CI workflow at the 0.2.0 commit while DESCRIPTION required 0.2.3. After a re-pin, grep README, `.github/` and
  docs for `BetterGG@`.
- jamovi labels its plots with column names (`labels <- list(x = term[1], y = dep, ...)` in
  jmv's emmeans plots), not with variable descriptions; readable labels are jmv2gg's choice.

## 0.2.5: tests that need a UTF-8 session

- `tools/check.ps1` forces C locales, and R in a C locale cannot form non-ASCII names, so a
  test that builds a non-ASCII column name fails there ("6 failures" in the first
  `R CMD check --no-manual` run, from two argument-matrix cases that were already in 0.2.4).
  Keep such cases in their own `test_that()` that skips with a reason outside a UTF-8 session
  (check `l10n_info()[["UTF-8"]]`), and run them under `tools/check.R`; do not weaken the
  case or drop it from the matrix.

## 0.2.4: simulated data and NA statistics

- A simulation that gives every factor the same pattern confounds them: every factorial term
  became inestimable and the figure printed "F(0, 98) = NA". Simulated designs must cross
  their factors, and a test that previews every bundled analysis on simulated data must
  look for NA in the drawn text, not only for a drawn figure.
- A preview that evaluates generated code in an environment whose parent is baseenv()
  breaks model code that looks up stats functions through the formula's environment
  (family(), na.pass). Run it with the standard packages visible, as a report does.
- afex renames within-subject levels with make.names() ("High Control" -> "High.Control");
  emmeans on an afex model returns those names. Map them back before matching the data.
- Inf is a legitimate statistic (a one-sided confidence interval ends at Inf); only NA and
  NaN mean "not computed".
- statsExpressions' contingency_table() prints the bias-corrected Cramer's V
  (effectsize adjust = TRUE) with a hat but no "adjusted" label; jamovi reports the
  uncorrected V. Same name, different statistic: compare every effect size against the
  jamovi table, not only the test statistic and p (a cross-model review of the rendered
  figures found this; the jmv comparison tests had checked chi-squared and p only).
- Timing on a shared laptop is noisy (the same native render took 174 s and 338 s); compare
  before/after only in back-to-back runs, and report such numbers as rough.
- A per-line cost measured on one kind of code does not carry over: styler took about
  28 ms per line in WebR on the statistics-off example, but 36-57 s per ~100-line figure
  block with statistics on, and a full conversion then failed ("A non-local transfer of
  control"). Time the slow step per piece, on the settings users actually run, in the real
  runtime (a Node WebR harness reproduces the browser without a page).
- testthat's local_mocked_bindings() needs a package (pkgload or installed); tools/check.R
  sources R/ instead, so swap a binding in environment(fn) by hand there.

## 0.2.3: long documents in the browser

- Time a release on the largest real documents, not only the bundled examples. A
  replication report (37 analyses, 158 KB) took minutes to convert; the examples took
  seconds. In a real corpus of 625 jamovi R Markdown files the generated code reached
  40,000 lines.
- styler takes about 30 ms per generated line in WebR 0.6.0 (about 9 ms natively), so
  it is skipped in the browser above 2,000 lines, with a note; one call for the whole
  document is no faster than one per piece.
- regmatches() on one long string not marked UTF-8 cut each match out by walking the
  text from its start (82 s for one document); for ASCII patterns use useBytes = TRUE.
- knitr reads a chunk header from one line. deparse() wraps long vectors, so a figure
  chunk with many captions became plain text and its figures were silently not drawn;
  build header options as one line, and test that knitr::purl() extracts the chunk.
- A long silent step needs counted progress from R: write "jmv2gg-progress" lines with
  message() and stream them (captureStreams = FALSE), as the report render does.
- Validation scripts that look up generated object names go stale when the generator
  changes; run them each release, or they stop checking anything.

## 0.2.1: jmvcore 28.3 report printing

- Verify a generated-code change with the defaults users get (styler on, the web app),
  not only the fast test settings: 0.2.1 passed every check with styler off and shipped
  without its fix, because styler kept only the first element of a multi-element piece.

- jmvcore 28.3 (CRAN) prints jamovi results in HTML reports with a knitr method that
  fails for some results (`jmv::reliability`: "invalid argument type"), stopping the
  whole knit; local R had jmvcore 2.7.7, so only CI showed it. Check against the
  current CRAN jmvcore/jmv, not only the locally installed versions.
- A wrapper saved in a global variable in a generated setup chunk recurses when the
  chunk is run twice in one session (the saved "original" becomes the wrapper). Keep
  the saved printer inside `local()` and test by evaluating the block twice in one environment.
- A fallback must be visible: a warning is invisible when the report sets
  `knitr::opts_chunk$set(warning = FALSE)`; print a note into the output instead.

## 0.2.0: figures, statistics and the browser

- Loading styler loads R.utils, whose `names()` method for "Options" objects breaks
  jmv for the rest of the session ("options$.options does not exist"). Run styler in
  a separate process (callr) or in a worker that never runs jmv. `skip_if_not_installed()`
  loads the package it checks: test for styler with `system.file()` instead.
- `emmeans::joint_tests()` stores F rounded to three decimals. Use `drop1(scope = ~.)`
  on the sum-to-zero model for exact type III F (equal to `car::Anova(type = 3)`).
- jmv applies case weights only in contTables, descriptives, linReg and logRegBin
  (grep `jmv-weights` in the jmv classes). ANOVA and ANCOVA ignore them; check jmv's
  own behaviour before weighting a model "to match".
- statsExpressions reads `type` by its first letter, case-sensitively:
  "Non-parametric" is parametric. Mirror the rule; do not "fix" the user's intent.
- jamovi's syntax mode writes `..., )` (an empty trailing argument), formula forms
  (`descriptives(formula = a + b ~ g:h)`, `contTables(formula = ~ r:c)`,
  `propTestN(formula = ~ v)`) and `vars("a", "b")`. A real corpus finds these; a
  synthetic one does not.
- BetterGG's namespace loads with only rlang, so the browser conversion worker
  installs BetterGG and jmv2gg without the ggstatsplot stack. Building BetterGG for
  WebR needs its R dependencies inside the build container (Posit binaries).
- Statistics on figures: compare every printed value with the jmv result object for
  the same call; a second-model review found one-sided correlations, exact rank tests
  and one-sample hypotheses that the first test set missed.
