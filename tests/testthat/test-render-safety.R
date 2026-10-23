# The adversarial set for in-browser rendering (inst/adversarial). Each file
# tries one escape; every attempt must fail. Here: the R-side layers (scan,
# run-time refusal, time and size limits, HTML sanitising). The browser layers
# (fixed-origin CSP, script-free sandboxed frame) are checked in a real
# browser before release.

adversarial <- function(name) {
  dir <- system.file("adversarial", package = "jmv2gg")
  if (!nzchar(dir)) dir <- file.path(testthat::test_path(), "..", "..", "inst", "adversarial")
  file.path(dir, name)
}
read_doc <- function(name) paste(readLines(adversarial(name), warn = FALSE), collapse = "\n")
codes <- function(scan) vapply(scan$findings, function(f) f$code, "")

test_that("documents that reach outside R are refused before anything runs", {
  for (name in c("dom-eval-js.Rmd", "js-chunk.Rmd", "other-engines.Rmd", "child.Rmd")) {
    scan <- scan_rmd_risks(read_doc(name))
    expect_true(scan$refused, label = name)
  }
  expect_true("javascript_from_r" %in% codes(scan_rmd_risks(read_doc("dom-eval-js.Rmd"))))
  expect_true("other_engine" %in% codes(scan_rmd_risks(read_doc("js-chunk.Rmd"))))
  expect_true("child_document" %in% codes(scan_rmd_risks(read_doc("child.Rmd"))))
})

test_that("risky constructs are listed for confirmation, with their lines", {
  scan <- scan_rmd_risks(read_doc("network.Rmd"))
  expect_false(scan$refused)
  expect_true("source_or_download" %in% codes(scan))
  scan <- scan_rmd_risks(read_doc("navigation.Rmd"))
  expect_true("asis_output" %in% codes(scan))
  expect_identical(scan$findings[[which(codes(scan) == "asis_output")]]$lines, 5L)
  scan <- scan_rmd_risks(read_doc("benign.Rmd"))
  expect_length(scan$findings, 0L)
  expect_false(scan$refused)
  expect_identical(scan$chunks, 1L)
})

test_that("prose and YAML do not trigger code rules, inline R does", {
  text <- paste("---", "title: See https://doi.org/10.1/x", "p: !r Sys.Date()", "---",
    "A link https://osf.io in prose and `r source('x.R')` inline.", sep = "\n")
  scan <- scan_rmd_risks(text)
  expect_identical(sort(codes(scan)), c("source_or_download", "yaml_expression"))
  expect_identical(scan$inline_expressions, 1L)
})

test_that("rendering refuses unreviewed findings and refused documents", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  out <- tempfile(fileext = ".html")
  expect_error(render_browser_preview(adversarial("js-chunk.Rmd"), out), "not rendered in the browser")
  expect_error(render_browser_preview(adversarial("navigation.Rmd"), out), "Review these items")
  expect_false(file.exists(out))
})

test_that("rendered HTML keeps no scripts, handlers, frames, forms or navigation", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  work <- tempfile(); dir.create(work)
  for (name in c("navigation.Rmd", "cookies.Rmd")) {
    file.copy(adversarial(name), work)
    out <- file.path(work, sub("Rmd$", "html", name))
    render_browser_preview(file.path(work, name), out, confirmed = codes(scan_rmd_risks(read_doc(name))))
    html <- paste(readLines(out, warn = FALSE), collapse = "\n")
    tags <- regmatches(html, gregexpr("<[A-Za-z/][^>]*>", html, perl = TRUE))[[1]]
    expect_false(any(grepl("^</?(script|iframe|object|embed|form|base|link|noscript)\\b", tags, ignore.case = TRUE)), label = name)
    expect_false(any(grepl("http-equiv", tags, ignore.case = TRUE)), label = name)
    expect_false(any(grepl("\\son[a-z]+\\s*=", tags, ignore.case = TRUE)), label = name)
    expect_false(any(grepl("javascript:|target\\s*=\\s*.?_top|exfiltration", tags, ignore.case = TRUE)), label = name)
    # the code itself is still shown as written
    if (name == "navigation.Rmd") expect_match(html, "onerror=", fixed = TRUE)
  }
})

test_that("an endless loop stops at the time limit and huge output is refused", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  work <- tempfile(); dir.create(work)
  file.copy(c(adversarial("infinite-loop.Rmd"), adversarial("huge-output.Rmd")), work)
  started <- Sys.time()
  expect_error(render_browser_preview(file.path(work, "infinite-loop.Rmd"), file.path(work, "a.html"), time_limit = 2),
    "time limit|elapsed")
  expect_lt(as.numeric(difftime(Sys.time(), started, units = "secs")), 30)
  expect_error(render_browser_preview(file.path(work, "huge-output.Rmd"), file.path(work, "b.html")), "larger than 20 MB")
})

test_that("a benign report renders with a contents list, folded code and an embedded figure", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  work <- tempfile(); dir.create(work)
  file.copy(adversarial("benign.Rmd"), work)
  out <- render_browser_preview(file.path(work, "benign.Rmd"), file.path(work, "benign.html"))
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "<nav class=\"toc\">", fixed = TRUE)
  expect_match(html, "<a href=\"#section-1\">Results</a>", fixed = TRUE)
  expect_match(html, "<details class=\"code\"><summary>Show code</summary>", fixed = TRUE)
  expect_match(html, "<img src=\"data:image/png;base64,", fixed = TRUE)
  expect_match(html, "Browser preview rendered with knitr and markdown in WebR", fixed = TRUE)
})

test_that("rendering can report each chunk as knitr reaches it", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  work <- tempfile(); dir.create(work)
  file.copy(adversarial("benign.Rmd"), work)
  messages <- character()
  withCallingHandlers(
    render_browser_preview(file.path(work, "benign.Rmd"), file.path(work, "b.html"), progress = TRUE),
    message = function(m) { messages <<- c(messages, conditionMessage(m)); invokeRestart("muffleMessage") }
  )
  progress <- grep("^jmv2gg-progress ", messages, value = TRUE)
  expect_identical(trimws(progress), "jmv2gg-progress 1 1 unnamed-chunk-1")
  expect_null(knitr::opts_hooks$get("eval"))
})

test_that("YAML params reach the document, as rmarkdown provides them", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  work <- tempfile(); dir.create(work)
  writeLines(c("---", "title: Params", "params:", "  count: 3", "  label:", "    value: framed", "  twice: !r 2 * 21", "---", "",
    "```{r}", "cat('n', params$count, params$label, params$twice)", "```"), file.path(work, "p.Rmd"))
  expect_error(render_browser_preview(file.path(work, "p.Rmd"), file.path(work, "p.html")), "yaml_expression")
  out <- render_browser_preview(file.path(work, "p.Rmd"), file.path(work, "p.html"), confirmed = "yaml_expression")
  expect_match(paste(readLines(out, warn = FALSE), collapse = "\n"), "n 3 framed 42", fixed = TRUE)
})

test_that("the bundled complex example report renders in the browser previewer", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  examples <- system.file("examples", package = "jmv2gg")
  if (!nzchar(examples)) examples <- file.path(testthat::test_path(), "..", "..", "inst", "examples")
  source <- paste(readLines(file.path(examples, "replication-report.Rmd"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  converted <- convert_rmd(source, engine = "ggplot2", style = list(styler = FALSE))
  for (p in converted$manifest$packages) skip_if_not_installed(p)
  work <- tempfile(); dir.create(work)
  file.copy(file.path(examples, "replication-study.csv"), work)
  writeLines(converted$text, file.path(work, "report.Rmd"), useBytes = TRUE)
  scan <- scan_rmd_risks(converted$text)
  out <- render_browser_preview(file.path(work, "report.Rmd"), file.path(work, "report.html"), confirmed = codes(scan))
  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_gte(length(gregexpr("<img src=\"data:image/png;base64,", html, fixed = TRUE)[[1]]), length(converted$manifest$plots))
})

test_that("the browser preview's websocket placeholder opens no connection and errors on use", {
  root <- file.path(testthat::test_path(), "..", "..", "tools", "webr", "placeholders", "websocket")
  skip_if(!dir.exists(root), "placeholder sources are not part of the installed package")
  env <- new.env()
  sys.source(file.path(root, "R", "websocket.R"), envir = env)
  expect_error(env$WebSocket$new("wss://example.invalid/"), "not available in the jmv2gg browser preview")
  expect_true(env$is_jmv2gg_placeholder())
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  expect_match(description[, "Title"], "Not the 'websocket' Package", fixed = TRUE)
  # chromote imports websocket (>= 1.2.0); the .9000 suffix marks it as no real release
  expect_true(package_version(description[, "Version"]) >= "1.2.0")
  expect_match(description[, "Version"], ".9000", fixed = TRUE)
  # natively the real package (or none) is loaded, so the preview note does not mention a placeholder
  expect_false(placeholder_loaded())
})

test_that("a render error names the chunk where it happened", {
  skip_if_not_installed("knitr"); skip_if_not_installed("markdown")
  work <- tempfile(); dir.create(work)
  writeLines(c("---", "title: Broken", "---", "", "```{r first}", "x <- 1", "```", "", "```{r second}",
    "stop('boom')", "```"), file.path(work, "e.Rmd"))
  expect_error(render_browser_preview(file.path(work, "e.Rmd"), file.path(work, "e.html")), "Chunk 2 of 2 [(]second[)]: .*boom")
  expect_null(knitr::opts_hooks$get("eval"))
})

test_that("a jmv result whose knitr HTML printing fails is printed as text, not a failed preview", {
  skip_if_not_installed("knitr")
  knitr_ns <- asNamespace("knitr")
  before <- utils::getS3method("knit_print", "ResultsElement", optional = TRUE, envir = knitr_ns)
  failing <- function(x, ...) stop("invalid argument type")
  registerS3method("knit_print", "ResultsElement", failing, envir = knitr_ns)
  on.exit(if (is.null(before)) registerS3method("knit_print", "ResultsElement", function(x, ...) knitr::normal_print(x), envir = knitr_ns)
    else registerS3method("knit_print", "ResultsElement", before, envir = knitr_ns), add = TRUE)
  fake <- structure(list(), class = "ResultsElement")
  expect_error(knitr::knit_print(fake), "invalid argument type")
  restore <- guard_jmv_knit_print()
  expect_output(knitr::knit_print(fake), "Note: jmvcore could not print this jamovi result as HTML (invalid argument type); it is printed as text.", fixed = TRUE)
  restore()
  expect_error(knitr::knit_print(fake), "invalid argument type")
})

test_that("the example's contingency table (run through the websocket placeholder in the browser) keeps jmv's statistics", {
  skip_if_not_installed("jmv")
  # Browser preview 2026-10-22 (WebR, placeholder installed) printed chi2 5.611, df 2, p .060, N 234 for this
  # table; these are the native values it must keep matching.
  examples <- system.file("examples", package = "jmv2gg")
  if (!nzchar(examples)) examples <- file.path(testthat::test_path(), "..", "..", "inst", "examples")
  study <- utils::read.csv(file.path(examples, "replication-study.csv"))
  study$source <- factor(study$source, levels = c("expert", "peer", "none"))
  study$choice <- factor(study$choice, levels = c("reject", "accept"))
  study <- study[study$attention == "pass", ]
  chi <- jmv::contTables(data = study, rows = "choice", cols = "source")$chiSq$asDF
  expect_equal(chi[["value[chiSq]"]], 5.611454, tolerance = 1e-6)
  expect_identical(as.integer(chi[["df[chiSq]"]]), 2L)
  expect_equal(chi[["p[chiSq]"]], 0.06046279, tolerance = 1e-6)
  expect_identical(as.integer(chi[["value[N]"]]), 234L)
})

test_that("converted reports with jamovi analyses carry the jmvcore print fallback, and it works", {
  rmd <- function(code) paste("---", "title: t", "---", "", "```{r}", code, "```", sep = "\n")
  with_jmv <- convert_rmd(rmd('jmv::descriptives(data = d, vars = "y")'), engine = "ggplot2", style = list(styler = FALSE))
  expect_match(with_jmv$text, "# ---- jamovi results in the knitted report ----", fixed = TRUE)
  without <- convert_rmd(rmd("ggstatsplot::ggbetweenstats(data = d, x = g, y = y)"), engine = "ggplot2", style = list(styler = FALSE))
  expect_false(grepl("jamovi results in the knitted report", without$text, fixed = TRUE))
  # Run the generated block against a failing HTML printer (as jmvcore 28.3's is for reliability).
  skip_if_not_installed("knitr"); skip_if_not_installed("jmvcore")
  loadNamespace("jmvcore")
  knitr_ns <- asNamespace("knitr")
  before <- utils::getS3method("knit_print", "ResultsElement", optional = TRUE, envir = knitr_ns)
  on.exit(if (is.null(before)) registerS3method("knit_print", "ResultsElement", function(x, ...) knitr::normal_print(x), envir = knitr_ns)
    else registerS3method("knit_print", "ResultsElement", before, envir = knitr_ns), add = TRUE)
  registerS3method("knit_print", "ResultsElement", function(x, ...) stop("invalid argument type"), envir = knitr_ns)
  fake <- structure(list(), class = "ResultsElement")
  expect_error(knitr::knit_print(fake), "invalid argument type")
  eval(parse(text = jmv_print_fallback_code()), envir = new.env())
  expect_output(knitr::knit_print(fake), "Note: jmvcore could not print this jamovi result as HTML (invalid argument type); it is printed as text.", fixed = TRUE)
  # Running the chunk twice in the SAME environment (re-running setup in a session) must not make
  # the wrapper call itself; a working printer must still print as HTML afterwards.
  registerS3method("knit_print", "ResultsElement", function(x, ...) knitr::asis_output("<b>ok</b>"), envir = knitr_ns)
  same <- new.env()
  eval(parse(text = jmv_print_fallback_code()), envir = same)
  eval(parse(text = jmv_print_fallback_code()), envir = same)
  expect_match(as.character(knitr::knit_print(fake)), "<b>ok</b>", fixed = TRUE)
})
