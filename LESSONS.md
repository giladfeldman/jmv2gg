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
