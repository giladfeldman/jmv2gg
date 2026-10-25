# jmv2gg 0.2.5

- Uses BetterGG 0.2.2. Generated figure code changes accordingly (statistics unchanged):
  many or long category names are angled instead of overlapping; faceted histograms put the
  mean label beside its line with whole-number count axes; reliability figures keep a
  constant item and label it "not estimable" (0.2.1 dropped it without a word), with
  labels near the panel edge no longer cut off; non-significant correlation crosses are grey
  and drawn under the coefficient; raincloud dots are filled with their outline colour;
  pie charts have no empty axes. Bayesian rainclouds with three or more groups draw a bar
  per pair with its Bayes factor, and a grouping column named `g` no longer stops them.
- The report preview installs jmv only when the report uses it (49 instead of about 175
  packages for a report without jmv).
- The workbench starts a fresh R session after the browser R engine aborts, so the next
  request no longer hangs.
- The browser build reuses the published BetterGG and websocket binaries while their source
  is unchanged (the manifest records a line-ending-independent source fingerprint).

# jmv2gg 0.2.4

- Figure previews on simulated data printed "F(0, 98) = NA, p NA" for factorial designs:
  every simulated factor had the same A/B pattern, so the factors were confounded. Simulated
  factors are now fully crossed (every cell observed), scores share a common component (so
  correlations, reliability and paired differences are neither zero nor perfect), repeated
  and paired measures are simulated (they were refused), and so are split-by, layer and
  grouping variables; a logistic outcome is random instead of determined by a factor, and
  simulated factors and outcomes use the reference levels the source names ("'ref' must be
  an existing level" before).
- Simulated previews of logistic regressions and contingency tables always failed ("could
  not find function family", "object 'na.pass' not found"): the preview ran the figure code
  without R's standard packages attached. It now runs as a report does.
- Figure statistics never show NA (BetterGG 0.2.1): a test that cannot be computed from the
  data (an empty cell, a confounded term, no variation) reads "not estimable from these
  data", with a warning that names it.
- Repeated-measures figures with a within-subject level containing a space or other
  non-name characters ("High Control") were not drawn: afex renames such levels
  ("High.Control"), so the model means did not match the data. The data's own level names
  are now restored.
- The browser report preview no longer writes the figure export files (PNG/PDF/TIFF at the
  chosen dpi), which nobody receives there; the page shows every figure, and the files are
  written when the report is knitted in R.
- The browser report preview stops after a limit chosen before rendering (15, 30, 60 or
  120 minutes; 60 is suggested for reports with more than 40 chunks or figures, which are
  named as large, with the native R command). R's own limit inside the render, a fixed
  10 minutes, now equals the chosen limit.
- Contingency-table figures printed the bias-corrected Cramer's V of ggbarstats (for
  example .00 where jamovi reports .16). The ggplot2 figure now prints Cramer's V as jamovi
  computes it, sqrt(chi-squared / (n (k - 1))) from the same test and without an interval
  (jamovi gives none); the BetterGG figure keeps ggbarstats' bias-corrected V, and its note
  says so.
- Browser conversions and figure previews with statistics on could take many minutes and
  then fail ("A non-local transfer of control occurred during evaluation"), leaving R busy:
  styler, which tidied the generated code in the browser, took 36-57 s per figure block of
  the bundled complex example in WebR. The browser no longer runs or installs styler; it
  keeps jmv2gg's own code layout, with a note on how to tidy it (the R package still runs
  styler).
- A repeated-measures analysis that maps a measure to a cell that is not one of the declared
  levels (left over after a level was removed) failed to draw. jamovi ignores such a measure
  (checked against jmv::anovaRM); the figure now does too, with a note naming it.
- The contingency-table note about case weights no longer reads as "statistics not shown"
  for unweighted data: it applies only when the data carry jamovi case weights.

# jmv2gg 0.2.3

- Figure chunks with many figures were not run: their header (`fig.cap=c(...)`) was
  split over two lines, so knitr showed the chunk as text and drew none of its figures,
  without a warning (a descriptives analysis of 7 variables with both engines). Chunk
  headers are now always one line.
- Converting long documents is faster: the name scan that took up to 82 s on one
  replication report now takes well under a second, with identical output.
- The web app shows conversion progress: each R chunk as it is read, then each part of
  the generated code as styler tidies it, with a time estimate.
- In the browser, generated code over 2,000 lines keeps jmv2gg's own layout instead of
  being tidied with styler, which would take minutes there; a note says so and how to
  tidy it in R. Native R is unchanged.

# jmv2gg 0.2.2

- The 0.2.1 fallback for jmvcore 28.3 was missing from converted reports whenever the
  generated code was formatted with styler (the default, including the web app): the
  formatter kept only the first part of a setup chunk built from several parts. It now
  formats the whole piece, and the setup chunk is passed as one text. (A report with
  jamovi analyses and no figures kept only the block's first comment line.) Tested with
  styler on and off; no earlier generated code was affected (every other piece was
  already one text).

# jmv2gg 0.2.1

- Converted R Markdown reports with jamovi analyses now knit with the current CRAN
  jmvcore (28.3). Its HTML printer fails on some results (`jmv::reliability`:
  "invalid argument type") and stopped the whole knit, original jamovi reports
  included. The generated setup chunk now has a commented fallback that prints such a
  result as plain text, as in the R console, under a note saying so (shown even where
  the report turns warnings off);
  results that print correctly are unchanged. Re-running the setup chunk in the same R
  session is safe (found in review: the first version then printed every jamovi result
  as text). The browser preview labels its own text fallback the same way. Checked by knitting the bundled complex report with jmvcore 28.3 and
  jmv 2.8.0 (reliability printed as text, all 27 figures embedded), and by a test
  that runs the generated block against a failing printer.

# jmv2gg 0.2.0

Figures
- The ggplot2 figures now follow the BetterGG design for each test and are written by
  BetterGG's code recipes (BetterGG >= 0.2.0 is now required to convert): rainclouds for
  group comparisons, factorial rainclouds with the model's estimated marginal means for
  factorial designs and covariates, within-subject rainclouds, ggcorrmat-style
  correlation matrices, stacked percentage bars and pies, histograms, odds-ratio and
  coefficient forests, and a new reliability figure. The generated code still runs
  without BetterGG.
- Statistics on figures (`style = list(stats = TRUE)`, off by default). Each printed
  statistic is computed in the generated code and tested to equal jmv's own table
  (ANOVA and ANCOVA type III F, means and intervals; Student/Welch/one-sided t-tests;
  Welch/Fisher/Kruskal-Wallis; repeated measures with Greenhouse-Geisser; Pearson,
  Spearman, Kendall and partial correlations, one-sided hypotheses, exact small-sample
  rank tests; chi-squared and McNemar; odds ratios with jamovi's Wald intervals; linear
  regression; Cronbach's alpha and item-rest correlations). Where a figure could not
  match the source, no statistics are drawn and a note says why.
- Exports: PNG and LZW TIFF at the chosen dpi and vector PDF with embedded fonts;
  journal sizes `size = "single"` (3.5 in) and `"double"` (7.2 in); palettes NEJM,
  Okabe-Ito, grey and viridis.

Readable output
- One setup block (packages with versions, the figure style written out, export
  settings, helpers) and, per analysis, a commented block with readable names
  (`anova_1_input`, `anova_1_model`, `anova_1_plot`) saying what it mirrors, what is
  plotted and how it differs from jamovi. Code is formatted with styler.
- R Markdown: one setup chunk, `fig.cap` for every figure, optional headings one level
  below the document's (`style = list(headings = TRUE)`), YAML edited in place so
  comments are kept.

Coverage
- New: linear regression, reliability, one-way ANOVA (Welch/Fisher), Kruskal-Wallis,
  partial correlations, Kendall's tau, several pairs in paired t-tests, several variables
  in t-tests and proportion tests, t-test formulas, contingency-table layers, factorial
  repeated measures, grouped ggstatsplot calls (BetterGG figure).

Fixed
- jmv's ANOVA and ANCOVA do not apply case weights; 0.1.0 weighted their models, so the
  plotted means could differ from jamovi's. The figures now use the unweighted model.
- emmeans::joint_tests() stores F rounded to three decimals; F tests now use drop1().
- `logRegBin` with several `blocks` fits the cumulative model, as jmv does.
- `ancova(formula = ...)` treats numeric predictors as covariates, as jmv does.
- YAML tags such as `!r` or `!expr` are kept verbatim.
- SPSS (haven) value labels name the groups.
- BetterGG's ggstatsplot tests are always Welch; 0.1.0 passed `var.equal = TRUE` as if
  they were not. The notes now say so, and the ggplot2 figures use Student's test when
  the source does.

Changed
- A figure that cannot be drawn produces a visible warning naming the figure and the
  reason; the other figures and the report still run.
- Style options `show_violin`, `show_jitter`, `jitter_width` and `jitter_height` are
  retired (accepted with a note; they no longer change the figures).

Browser
- Report previews install a clearly labelled placeholder for the `websocket` package (no
  WebR build exists) so jamovi contingency tables can run; it opens no connections and
  errors on use. Render errors name the chunk; YAML `params` work; a jmv result whose
  HTML printing fails is printed as text; outside image addresses are removed from the
  preview.
- A progress panel shows the current step, counted package installs, elapsed time and an
  estimate for installs, conversion, previews and report rendering.
- In-browser report rendering (knitr + markdown in a fresh WebR worker) with a risk scan
  and confirmation, refusal of other languages, child documents and page access,
  sanitised HTML in a script-free sandboxed frame, a time limit, Cancel, and an
  adversarial test set.
- Complex R and R Markdown examples on a bundled synthetic replication-study dataset.
- The app's interface was split into components; the CSS is readable again.

# jmv2gg 0.1.0

- Added structural conversion without evaluating input expressions.
- Added assigned-call support and metadata-preserving Rmd conversion.
- Added editable model-based figures, explicit PNG exports, and separate BetterGG calls.
- Added browser-local workbench, diagnostics, simulations, and data previews.
- Added numerical regression tests and a private native-report validation harness.

See README for the tested execution boundaries. Full HTML rendering and BetterGG
previews use native R; browser conversion and supported ggplot2 previews use WebR.
BetterGG is pinned to the public, tested 0.1.0 source commit.
