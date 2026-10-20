# jmv2gg

Convert jamovi analysis code into explicit, editable ggplot2 and BetterGG figures.
Conversion runs in native R or in a browser using the same R package through WebR.

This is a development release. Check the capability notes before using generated
figures in research. Unsupported analyses are preserved and reported; numerical
equivalence is never inferred from a visually similar plot.

## Use in R

```r
# Install from GitHub once a release is published:
# install.packages("remotes")
# remotes::install_github("giladfeldman/jmv2gg")

result <- jmv2gg::convert_code(
  'jmv::ANOVA(data = study, dep = "score", factors = "condition")',
  engine = "ggplot2"
)
writeLines(result$text, "editable-figures.R")
result$diagnostics

document <- paste(readLines("analysis.Rmd", warn = FALSE), collapse = "\n")
converted <- jmv2gg::convert_rmd(document, engine = "both")
writeLines(converted$text, "converted.Rmd")
```

Conversion does not execute the source or need its data. Run the generated code
with the actual dataset and required plotting packages. BetterGG output calls
the separate BetterGG package; it does not imitate that package.

For native rendering, install `rmarkdown`, `callr`, Pandoc, and the packages used
by your original report and selected plotting engines. Keep the source data
paths valid. Then use:

```r
jmv2gg::render_report("converted.Rmd", output_dir = "report")
```

Full HTML knitting requires native R. Browser conversion does not execute Rmd
setup code. Browser plot previews use a selected prepared dataset or explicitly
labelled simulated data. BetterGG and repeated-measures previews currently use
the native-R route.

## Output choices

- `engine = "ggplot2"`, `"bettergg"`, or `"both"` (default).
- `original_output = "include"` or `"hide"`: show existing jamovi tables/figures
  alongside new plots, or hide original analysis-chunk output. Calculations and
  result bindings remain available in both modes.
- `html_preset = "enhanced"` enables a floating level-3 table of contents and
  folded code while retaining YAML parameters and metadata. `"preserve"` keeps
  existing presentation choices. YAML containing `!expr` is preserved verbatim.
- Every generated plot has an explicit `ggsave()` to `figures/`. Defaults are
  white-background PNG, 600 dpi, and 7.2 × 5.4 inches. Sizes are configurable.

For example, `figures = list(dpi = 300, width = 3.5, height = 3)` selects a smaller
single-column export. Compression is lossless; no color quantization is applied.

## Analysis coverage and statistical notes

The engine recognizes assigned calls, formula syntax, jamovi's `dep`/`factors`
arguments, and literal vectors/lists. It handles ANOVA/ANCOVA, descriptive plots,
correlation matrices, categorical counts, logistic coefficients, ordinary
t-test visualizations, and supported repeated-measures cell mappings.

Explicit model terms and logistic reference levels are preserved. Model-based
ggplot2 figures use the fitted model and emmeans where relevant. Undefined
Pearson cells for ordinary nominal factors remain undefined; numeric value
mappings are handled explicitly.

BetterGG may introduce additional tests. In particular, a one-way/grouped
comparison does not reproduce a factorial interaction or covariate-adjusted
model. Warnings appear in the returned diagnostics and in the converted report,
outside folded code. Some paired/weighted categorical and complex repeated
designs have no faithful BetterGG mapping and are reported accordingly.

Dynamic expressions and analyses inside arbitrary control flow are not executed
to guess their meaning. Use stable named data frames and explicit arguments, or
keep the preserved source and complete the mapping in local R.

## Privacy

The static webapp has no accounts, database, upload endpoint, remote R server, or
application analytics. Selected files and results stay in the browser session.
Public WebR/runtime/package assets are downloaded from fixed application and
official distribution URLs. Clear workspace terminates the R worker. Download
your results before leaving the page.

Do not mistake "conversion complete" for "all statistical assumptions verified".
Review the source, conversion notes, and generated figures before publication.

## Development

The repository root is the R package; `web/` is a React/TypeScript/Vite frontend.
Use npm and commit `web/package-lock.json`.

PowerShell:

```powershell
Rscript tools/check.R
Rscript -e 'roxygen2::roxygenise()'
R CMD build .
R CMD check --no-manual jmv2gg_0.1.0.9000.tar.gz
npm --prefix web ci
npm --prefix web run build
npm --prefix web run dev
```

Use R 4.4+ for conversion. BetterGG's requirements can be higher. Run the native
package checks and browser tests on the exact R/WebR/package versions being
released. `tools/webr/build.R` builds the browser artifact with the pinned
official WebR 0.6.0 container; it documents the package-resolver workaround.

Private acceptance fixtures are supplied only through environment variables to
`tools/validation/private-report.R`. Never commit participant data or rendered
research reports.
