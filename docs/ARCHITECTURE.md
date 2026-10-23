# Architecture and source map

## R pipeline

R source -> structural parse -> analysis records (with readable names) -> one mapping
per analysis family -> commented figure blocks + one figure setup block, diagnostics
and an export manifest. Rmd additionally preserves document/chunk order and inserts
generated chunks. Input source is parsed, never executed to guess its meaning.

| File | Responsibility / first functions to inspect |
|---|---|
| R/contracts.R | convert_code(), conversion_options(), result/diagnostic contracts, r_sym(), runtime_capabilities() |
| R/parser.R | supported_signatures(), analysis_target(), inspect_code(), literals, model_terms() |
| R/names.R | assign_analysis_names(): anova_1, ttest_2, ...; jmv2gg_ prefix when the source uses the name |
| R/generate.R | generate_analysis(), the mapping context, prep_*() data-preparation code, assemble_block(), style_codes() |
| R/map-groups.R | ANOVA/ANCOVA, one-way, Kruskal-Wallis, t-tests, repeated measures, ggbetweenstats/ggwithinstats |
| R/map-other.R | one-sample t-test, descriptives, tables/proportions, correlations, regression, scatter, reliability |
| R/setup.R | figure_setup_code(): packages, BetterGG style (recipe_setup), export settings, figure_try/show/save |
| R/rmd.R | convert_rmd(), in-place YAML editing, hide_chunk_output(), native render_report() |
| R/render-browser.R | scan_rmd_risks(), render_browser_preview() (knitr + markdown in WebR), HTML sanitising |
| R/browser.R | browser_request() JSON bridge (convert, preview, scan) |
| R/optimize.R | optimize_png(): decoded pixel/dimension/DPI/file-size verification |
| inst/examples, inst/adversarial | Showcase R/Rmd/CSV; the adversarial Rmd set for browser rendering |
| tests/testthat/ | Includes test-figure-statistics*.R (figure statistics vs jmv), test-argument-matrix.R (+ snapshots) |
| tools/validation/ | Private acceptance and corpus harnesses (outputs outside the repository), deployment checks |
| tools/webr/build.R | Builds jmv2gg and BetterGG for WebR in the pinned official container |

The ggplot2 figures are written by BetterGG's recipe functions (`BetterGG::recipe_*`,
data-independent code generators); jmv2gg supplies the jamovi-equivalent data
preparation and model (means, intervals, coefficient tables). Statistics on figures
(style stats = TRUE) are computed in the generated code and tested against jmv's
result objects. styler formats the output in a separate R process (callr), because
loading styler (R.utils) breaks jmv's option objects in the same session. The
browser does not run styler (about a minute per analysis in WebR); it keeps
jmv2gg's own layout and adds a note.

Generated code: one setup block (packages, style, export settings, figure_try(),
figure_show(), figure_save()); per analysis a header comment, a guarded
data/model step and one guarded step per figure. figure_try() turns an error into a
visible warning and restores the random-number state.

Rmd: one setup chunk after the YAML, snapshots `<name>_input <- data` after each
analysis line, a figure chunk with fig.cap per figure, optional headings one level
below the document's. The YAML header is edited line by line (comments kept);
executable YAML tags are kept verbatim. Generated-block markers prevent duplicate
conversion.

## Browser pipeline

App.tsx wires state; components/ hold the editor, options, results, figures, render
panel and the sandboxed report frame; lib/ holds request builders, file limits,
the render state machine and the ZIP bundle. runtime.ts runs the conversion worker
(pinned WebR, jsonlite/yaml/rlang from the lock, BetterGG and jmv2gg from the
app's own repository without the ggstatsplot stack) and figure previews.
reportRuntime.ts runs each in-browser render in a fresh WebR instance.

WebR 0.6.0 loads from the official versioned origin. Dependency metadata is pinned
in web/public/locks/ (missing from the WebR repository and documented there: Rmpfr,
deSolve, websocket). Artifacts, index and manifest are in web/public/r-packages/.
prepare-runtime.mjs rejects stale source hashes and binary checksums. There is no
application server, upload endpoint, database, account system or analytics.

Rendering in the browser: the risk scan runs first (other engines, child documents
and page access are refused; the rest must be confirmed); the document runs only on
the user's chosen files in the WebR virtual file system; the fixed-origin CSP blocks
outside requests; HTML is sanitised and shown in an iframe with an empty sandbox
attribute (no scripts, no same-origin); time limit and Cancel close the worker.

write-build-info.mjs emits release identity; web/tests/check-build-info.mjs tests
clean/local dirty/hosted metadata/unknown source/invalid revision cases. Deployment
probes check identity/assets/headers; real-browser testing checks CSP/CORS/graphics.
See DEPLOYMENT.md for operations.
