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
