# jmv2gg

Convert jamovi analysis code into explicit, editable ggplot2 and BetterGG figures.
Conversion runs in native R or in a browser using the same R package through WebR.

Use the [browser workbench](https://jmv2gg.vercel.app/) without installing R.

This is version 0.2.2. Check the capability notes before using generated
figures in research. Unsupported analyses are preserved and reported; numerical
equivalence is never inferred from a visually similar plot.

## Use in R

```r
install.packages("remotes")
remotes::install_github("giladfeldman/BetterGG@v0.2.0", upgrade = "never")
remotes::install_github("giladfeldman/jmv2gg@v0.2.2", upgrade = "never")

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
with the actual dataset. The ggplot2 figures are written by BetterGG's code
recipes, so they look like the matching BetterGG plot, but the generated code
runs without BetterGG (it needs ggplot2 and a few plotting packages, listed at
the top of the output). BetterGG output calls the separate BetterGG package.

For native rendering, install `rmarkdown`, `callr`, Pandoc, and the packages used
by your original report and selected plotting engines. Keep the source data
paths valid. Then use:

```r
jmv2gg::render_report("converted.Rmd", output_dir = "report")
```

The web app can also render a converted report in the browser (knitr and
markdown in WebR, on your device): it first lists risky constructs for you to
confirm, refuses documents that run other languages or reach the page, and shows
the result in a frame that runs no scripts. That is a preview; the reference
report is rendered in native R.

## What the generated code looks like

- One setup block at the top: the packages used (with the versions it was
  generated with), the figure style written out in full, the export settings and
  four small helpers (`figure_try()`, `figure_show()`, `figure_save()`, and the
  APA p-value helper when statistics are on).
- For each analysis, a commented block with readable names (`anova_1_input`,
  `anova_1_model`, `anova_1_plot`): what it mirrors, what is plotted and from which
  model, and how it differs from jamovi; then the data preparation, the
  jamovi-equivalent model, and one guarded step per figure. A figure that cannot
  be drawn becomes a visible warning; the rest still runs.
- Code is formatted with styler (tidyverse style), in a separate R process,
  because loading styler breaks jmv for the rest of an R session.

## Figures per analysis

| jamovi analysis | Figure (looks like) |
|---|---|
| ANOVA, ANCOVA, one-way ANOVA, Kruskal-Wallis, t-tests | raincloud (`ggbetweenrain`); factorial designs and covariates: `ggfactorialrain` with the model's estimated marginal means |
| Paired t-test, repeated measures | `ggwithinrain`; factorial repeated measures: `ggfactorialrain` with emmeans on the afex model |
| Correlations, partial correlations | `ggcorrmat` lower triangle, crosses on coefficients with p >= .05 (unadjusted, as jamovi flags them) |
| Contingency tables, proportion tests | `ggbarstats` / `ggpiestats` |
| Descriptives | `gghistostats` (numeric) or `ggpiestats` / `ggbarstats` (categories) |
| Linear and logistic regression | `ggcoefstats` (logistic: odds ratios with jamovi's Wald intervals, log axis) |
| Reliability | `ggreliability` (item responses, item-rest correlations) |
| ggstatsplot calls | the same plot as editable code, and the BetterGG call |

## Output choices

- `engine = "ggplot2"`, `"bettergg"`, or `"both"` (default).
- `style = list(stats = TRUE)` prints the test statistics on the figures (off by
  default). They are recomputed in the code and tested to equal jmv's own tables;
  where they could not match, no statistics are printed and a note says why.
- `style = list(palette = "okabe_ito")` (also `"nejm"`, default, `"grey"`,
  `"viridis"`); `headings = TRUE` adds a heading before each figure chunk, one
  level below the document's own heading.
- `original_output = "include"` or `"hide"`: show existing jamovi tables/figures
  alongside new plots, or hide original analysis-chunk output. Calculations and
  result bindings remain available in both modes.
- `html_preset = "enhanced"` adds a floating table of contents and folded code;
  the YAML header is edited in place, so its comments stay. `"preserve"` keeps
  existing presentation choices. YAML containing `!r`/`!expr` is kept verbatim.
- `figures = list(size = "single")` (3.5 in) or `"double"` (7.2 in, default
  width); `formats = c("png", "pdf", "tiff")` (PNG and LZW TIFF at `dpi`,
  default 600; PDF as vector graphics with fonts embedded). Every figure gets a
  caption in R Markdown.

For verified native lossless postprocessing, set
`figures = list(optimize_png = TRUE)` with the `oxipng` executable on PATH.
The optimizer retains the original unless decoded pixels, dimensions, and
resolution match and the optimized file is no larger.

## Analysis coverage and statistical notes

The engine recognizes assigned calls, formula syntax, jamovi's `dep`/`factors`
arguments, `vars()`, bare names and literal vectors/lists. It handles ANOVA and
ANCOVA (up to three factors), one-way ANOVA, Kruskal-Wallis, t-tests (several
variables and pairs), repeated measures, descriptives, contingency tables and
proportion tests, correlation and partial correlation matrices, linear and
logistic regression, reliability, and the ggstatsplot plots.

Explicit model terms, cumulative regression blocks and reference levels are
preserved. Case weights are applied exactly where jmv applies them
(descriptives, contingency tables, linear and logistic regression); jmv's ANOVA
and ANCOVA do not use them, and neither do these figures. Weighted correlations,
t-tests and repeated measures are refused rather than drawn unweighted.

BetterGG may introduce additional tests. Its notes say when it differs from the
jamovi analysis. In the browser, BetterGG's parametric and nonparametric pairwise
comparisons are unavailable (their PMCMRplus dependency needs Rmpfr, which WebR
lacks); use native R for those figures.

jamovi's contingency tables (`jmv::contTables`) always call the vcdExtra
package, whose dependencies reach the `websocket` package, which has no WebR
build. For the browser report preview only, the app installs its own clearly
labelled placeholder named `websocket` (version 1.2.0.9000, source in
`tools/webr/placeholders/websocket`) so that chain can load. It is not the real
package: it opens no connections, and any attempt to use it stops with "WebSocket
connections are not available in the jmv2gg browser preview". The contingency
table statistics themselves are computed by jmv as usual (tested to equal native
jmv). Native R uses the real package.

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
R CMD check --no-manual jmv2gg_0.2.2.tar.gz
npm --prefix web ci
npm --prefix web run build
npm --prefix web run dev
```

Use R 4.5+ (BetterGG requires it). Run the native
package checks and browser tests on the exact R/WebR/package versions being
released. `tools/webr/build.R` builds the browser artifact with the pinned
official WebR 0.6.0 container with the BetterGG source mounted at `/bettergg`; it
documents the package-resolver workaround.

Private acceptance fixtures are supplied only through environment variables to
`tools/validation/private-report.R`. Never commit participant data or rendered
research reports.

Synthetic examples are in `inst/examples` (a complex R example and a complex R
Markdown report on a simulated replication-study dataset) and `web/public/examples`. A short report for the Rmd input mode is in
`web/public/examples/report.Rmd`. Browser ZIP exports include the exact browser
dependency index and compiled converter checksums. Native rendering records the
actual R session; retain that record and restore those package versions before
reproducing a report.

Production builds emit `/build-info.json` with the Git revision, build time,
package/runtime versions and compiled converter checksum. Local builds disclose
uncommitted changes. After deployment, compare the live revision and checksum
with the release artifacts; an HTTP success alone does not identify the build.

## Continue development

Read [CONTRIBUTING.md](CONTRIBUTING.md), [architecture](docs/ARCHITECTURE.md),
[capabilities/validation](docs/VALIDATION.md), [deployment](docs/DEPLOYMENT.md),
and [LESSONS.md](LESSONS.md). Claude Code can start at [CLAUDE.md](CLAUDE.md).
The validation record distinguishes runtime support and recorded tests from
optional skips, deferred review and checks not run.
