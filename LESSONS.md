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
- BetterGG's categorical palette must cover observed levels. Use explicit
  readable alias columns where an upstream plot cannot handle a column name.
- WebR's official runtime distribution must be tested with an actual PNG
  export. Successful initialization alone does not verify a graphics device.
- Results returned by WebR function execution do not belong to its root
  shelter. Destroying them there can discard a successful conversion.
- Compile the browser package after R changes. Production builds verify its
  source hashes and binary checksum before accepting the artifact.
- PNG optimization is optional and lossless: verify decoded pixels, dimensions,
  and resolution before replacing an export, and retain the smaller file.
