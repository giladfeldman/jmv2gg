# The bundled showcase: a complex R example and a complex R Markdown report on
# a synthetic replication-study dataset. Both must convert completely, and
# every figure must be drawn when the code runs.

example_file <- function(name) {
  path <- system.file("examples", name, package = "jmv2gg")
  if (!nzchar(path)) path <- file.path(testthat::test_path(), "..", "..", "inst", "examples", name)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

test_that("the complex R example converts every analysis and draws every figure", {
  skip_if_not_installed("ragg"); skip_if_not_installed("emmeans"); skip_if_not_installed("afex")
  skip_if_not_installed("BetterGG"); skip_if_not_installed("statsExpressions")
  code <- paste(readLines(example_file("replication-study.R"), warn = FALSE), collapse = "\n")
  out <- convert_code(code, engine = "both", figures = list(dpi = 72, width = 4, height = 3))
  expect_identical(out$status, "complete")
  expect_identical(out$manifest$detected, 12L)
  expect_identical(out$manifest$converted, 12L)
  work <- tempfile(); dir.create(work)
  file.copy(example_file("replication-study.csv"), work)
  old <- setwd(work); on.exit(setwd(old))
  env <- new.env(parent = globalenv())
  warnings <- character()
  suppressMessages(withCallingHandlers(eval(parse(text = out$text), envir = env),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }))
  expect_identical(grep("jmv2gg: figure", warnings, value = TRUE), character())
  expected <- vapply(out$manifest$plots, function(p) p$filename, "")
  expect_true(all(file.exists(expected)))
})

test_that("the complex report converts, and knits natively with every figure embedded", {
  skip_if_not_installed("rmarkdown"); skip_if_not_installed("callr"); skip_if_not(rmarkdown::pandoc_available())
  skip_if_not_installed("BetterGG"); skip_if_not_installed("jmv")
  text <- paste(readLines(example_file("replication-report.Rmd"), warn = FALSE), collapse = "\n")
  out <- convert_rmd(text, engine = "ggplot2", figures = list(dpi = 72, width = 4, height = 3))
  expect_identical(out$status, "complete")
  expect_identical(out$manifest$converted, 11L)
  expect_match(out$text, "toc: true # navigation for reviewers", fixed = TRUE)
  expect_match(out$text, "```{r jmv2gg-setup, include=FALSE}", fixed = TRUE)
  work <- tempfile(); dir.create(work)
  file.copy(example_file("replication-study.csv"), work)
  input <- file.path(work, "report.Rmd")
  writeLines(out$text, input, useBytes = TRUE)
  html <- render_report(input, output_dir = work)
  page <- paste(readLines(html, warn = FALSE), collapse = "\n")
  expect_false(grepl("jmv2gg: figure", page, fixed = TRUE))
  figures <- list.files(file.path(work, "figures"), pattern = "png$")
  expect_length(figures, length(out$manifest$plots))
  expect_gte(lengths(regmatches(page, gregexpr("data:image/png;base64", page, fixed = TRUE))), length(out$manifest$plots))
})
