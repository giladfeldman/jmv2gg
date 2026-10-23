# jmv2gg 0.2.2

- The 0.2.1 fallback for jmvcore 28.3 was missing from converted reports whenever the
  generated code was formatted with styler (the default, including the web app): the
  formatter kept only the first part of a setup chunk built from several parts. It now
  formats the whole piece, and the setup chunk is passed as one text. Tested with
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
