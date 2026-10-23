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
  R package; complete setup/HTML and BetterGG previews remain native-R paths.
- Documentation edits are not a deployment. Record uncommitted files, immutable
  release tags, deployed SHA and the next gate before publishing changes.
- Public docs use synthetic examples and generic paths. Keep owner decisions,
  private inputs, backups/history details and handoffs outside public source/archives.

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
