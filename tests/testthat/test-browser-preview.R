test_that("browser preview resolves generated functions in its restricted environment", {
  skip_if_not_installed("ragg");skip_if_not_installed("emmeans")
  work<-tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  request<-list(action="preview",mode="code",engine="ggplot2",source='jmv::ANOVA(data=d,dep="y",factors="x")',
    analysis_id="a0001",data_kind="simulate",n=30,figures=list(dpi=72,width=3,height=2))
  out<-jsonlite::fromJSON(browser_request(jsonlite::toJSON(request,auto_unbox=TRUE)))
  expect_identical(out$kind,"preview")
  expect_true(file.exists(out$files$path))
})

# Every text drawn on the preview's figures (titles, subtitles, captions, labels).
preview_texts <- function(env) {
  plots <- Filter(function(x) inherits(x, "ggplot"), mget(ls(env), envir = env))
  unlist(lapply(plots, function(p) {
    built <- ggplot2::ggplot_build(p)
    c(unlist(Filter(is.character, p$labels)),
      unlist(lapply(built$data, function(d) if ("label" %in% names(d)) as.character(d$label))))
  }))
}

test_that("simulated previews of every bundled example analysis draw complete statistics, never NA", {
  skip_if_not_installed("ragg"); skip_if_not_installed("emmeans"); skip_if_not_installed("ggdist")
  examples <- system.file("examples", package = "jmv2gg")
  if (!nzchar(examples)) examples <- file.path(testthat::test_path(), "..", "..", "inst", "examples")
  examples <- normalizePath(examples, mustWork = TRUE) # absolute: the test changes folder below
  work <- tempfile(); dir.create(work); old <- setwd(work); on.exit(setwd(old))
  for (file in c("replication-report.Rmd", "replication-study.R")) {
    source <- paste(readLines(file.path(examples, file), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    for (stats in c(TRUE, FALSE)) {
      style <- list(stats = stats, styler = FALSE)
      res <- if (endsWith(file, ".Rmd")) convert_rmd(source, "ggplot2", style = style) else convert_code(source, "ggplot2", style = style)
      opts <- conversion_options(style, list(dpi = 30)); opts$figures$formats <- "png"
      for (a in Filter(function(a) identical(a$status, "converted"), res$analyses)) {
        g <- generate_analysis(a, "ggplot2", opts)
        env <- new.env(parent = as.environment("package:stats"))
        assign(as.character(a$args$data), simulate_for_analysis(a, 100L), envir = env)
        problems <- character()
        withCallingHandlers(eval(parse(text = c(figure_setup_code(opts, g$packages), g$code)), envir = env),
          warning = function(w) { problems <<- c(problems, conditionMessage(w)); invokeRestart("muffleWarning") },
          message = function(m) invokeRestart("muffleMessage"))
        texts <- preview_texts(env)
        label <- paste(file, a$id, a$function_name, "stats", stats)
        expect_identical(problems, character(), label = label)
        expect_true(length(texts) > 0L, label = label)
        expect_false(any(grepl("(^|[^A-Za-z])(NA|NaN)([^A-Za-z]|$)", texts)), label = label)
      }
    }
  }
})

test_that("simulated factors are crossed, so every cell of the design is observed", {
  a <- convert_code('jmv::ANOVA(data = d, dep = "y", factors = c("a", "b", "c"))', engine = "ggplot2")$analyses[[1]]
  d <- simulate_for_analysis(a, 100L)
  expect_true(all(table(d$a, d$b, d$c) > 0L))
  expect_false(identical(d$a, d$b))
  fit <- stats::lm(y ~ a * b * c, data = d)
  expect_false(anyNA(stats::coef(fit)))
  # Paired measures are correlated, neither identical nor unrelated.
  p <- convert_code('jmv::ttestPS(data = d, pairs = list(list(i1 = "pre", i2 = "post")))', engine = "ggplot2")$analyses[[1]]
  d <- simulate_for_analysis(p, 100L)
  r <- stats::cor(d$pre, d$post)
  expect_true(r > 0.2 && r < 0.9)
  # The binary outcome of a logistic regression is not determined by its predictors.
  l <- convert_code('jmv::logRegBin(data = d, dep = "y", covs = "x", factors = "g", blocks = list(list("x", "g")), refLevels = list(list(var = "y", ref = "0"), list(var = "g", ref = "low")))', engine = "ggplot2")$analyses[[1]]
  d <- simulate_for_analysis(l, 100L)
  expect_setequal(levels(d$y), c("0", "1"))
  expect_true(all(table(d$y, d$g) > 0L))
  expect_identical(levels(d$g)[1], "low")
  # A reference level the source names for the outcome, or one equal to a default name, is used.
  l <- convert_code('jmv::logRegBin(data = d, dep = "y", covs = "x", factors = "g", blocks = list(list("x", "g")), refLevels = list(list(var = "y", ref = "No"), list(var = "g", ref = "Group B")))', engine = "ggplot2")$analyses[[1]]
  d <- simulate_for_analysis(l, 100L)
  expect_identical(levels(d$y), c("No", "0"))
  expect_identical(levels(d$g), c("Group B", "Group A"))
  expect_true(all(table(d$y) > 0L))
})

test_that("a browser preview never runs styler, even when the request asks for it", {
  skip_if_not_installed("ragg")
  work <- tempfile(); dir.create(work); old <- setwd(work); on.exit(setwd(old))
  styled <- FALSE
  # Swapped by hand where browser_request() looks it up (the package namespace, or the
  # global environment when tools/check.R sources R/), as local_mocked_bindings() needs a package.
  env <- environment(browser_request)
  original <- get("style_generated", envir = env)
  locked <- bindingIsLocked("style_generated", env)
  if (locked) unlockBinding("style_generated", env)
  assign("style_generated", function(pieces, options, ...) {
    if (isTRUE(options$style$styler)) styled <<- TRUE
    list(pieces = pieces, diagnostics = list())
  }, envir = env)
  withr::defer({ assign("style_generated", original, envir = env); if (locked) lockBinding("style_generated", env) })
  request <- list(action = "preview", mode = "code", engine = "both", analysis_id = "a0001", data_kind = "simulate", n = 30,
    source = 'jmv::contTables(data = d, rows = "a", cols = "b")', style = list(stats = TRUE, styler = TRUE),
    figures = list(dpi = 30, width = 3, height = 2))
  out <- jsonlite::fromJSON(browser_request(jsonlite::toJSON(request, auto_unbox = TRUE)))
  expect_identical(out$kind, "preview")
  expect_true(file.exists(out$files$path))
  expect_false(styled)
  # A conversion request still tidies its code.
  request$action <- "convert"
  browser_request(jsonlite::toJSON(request, auto_unbox = TRUE))
  expect_true(styled)
})

test_that("the browser scan request reports findings and the packages a document loads", {
  source <- paste("```{r}", "library(jmv)", "x <- ggplot2::ggplot()", "download.file('https://x.invalid', 'y')", "```", sep = "\n")
  out <- jsonlite::fromJSON(browser_request(jsonlite::toJSON(list(action = "scan", source = source), auto_unbox = TRUE)),
    simplifyVector = FALSE)
  expect_false(out$refused)
  expect_identical(out$findings[[1]]$code, "source_or_download")
  expect_setequal(unlist(out$packages), c("jmv", "ggplot2"))
})

test_that("the manifest lists the R packages the figures need", {
  out <- convert_code('jmv::ANOVA(data = d, dep = "y", factors = c("a", "b"))', engine = "ggplot2")
  expect_true(all(c("ggplot2", "ggdist", "emmeans") %in% out$manifest$packages))
  expect_false("BetterGG" %in% out$manifest$packages)
})

test_that("a browser conversion asked for progress reports each R chunk as it starts", {
  source <- paste("---", "title: t", "---", "", "```{r}", "x <- 1", "```", "",
    "```{r second}", 'jmv::descriptives(data = d, vars = "y")', "```", sep = "\n")
  request <- list(action = "convert", mode = "rmd", engine = "ggplot2", source = source, progress = TRUE,
    style = list(styler = FALSE))
  messages <- character()
  out <- withCallingHandlers(browser_request(jsonlite::toJSON(request, auto_unbox = TRUE)),
    message = function(m) { messages <<- c(messages, conditionMessage(m)); invokeRestart("muffleMessage") })
  expect_identical(trimws(grep("^jmv2gg-progress ", messages, value = TRUE)),
    c("jmv2gg-progress 1 2 chunk", "jmv2gg-progress 2 2 chunk"))
  expect_false(isTRUE(getOption("jmv2gg.progress")))
  # Without the request flag nothing is written.
  request$progress <- NULL
  expect_silent(browser_request(jsonlite::toJSON(request, auto_unbox = TRUE)))
})

test_that("the identifier scan gives the same names for a long document not marked UTF-8", {
  text <- paste(rep("café <- jmv::descriptives(data = d, vars = 'y') # naïve", 400), collapse = "\n")
  native <- text; Encoding(native) <- "unknown"
  expected <- unique(unlist(regmatches(strsplit(text, "\n")[[1]], gregexpr("[A-Za-z.][A-Za-z0-9._]*", strsplit(text, "\n")[[1]]))))
  got <- unique(regmatches(native, gregexpr("[A-Za-z.][A-Za-z0-9._]*", native, useBytes = TRUE))[[1]])
  expect_setequal(got, expected)
})

test_that("the browser keeps jmv2gg's layout and says how to tidy it; native R runs styler", {
  pieces <- list(setup = "x<-1", a = "y<-  2")
  options <- conversion_options(list(styler = TRUE), list())
  out <- style_generated(pieces, options, browser = TRUE)
  expect_identical(out$pieces, pieces)
  expect_identical(out$diagnostics[[1]]$code, "styler_browser")
  expect_match(out$diagnostics[[1]]$message, "styler::style_file()", fixed = TRUE)
  # styler off: no note.
  expect_identical(style_generated(pieces, conversion_options(list(styler = FALSE), list()), browser = TRUE)$diagnostics, list())
  # Not skip_if_not_installed(): loading styler here loads R.utils, which breaks jmv's options (LESSONS.md).
  skip_if(!nzchar(system.file(package = "styler")), "styler is not installed")
  native <- style_generated(pieces, options, browser = FALSE)
  expect_identical(native$diagnostics, list())
  expect_identical(unname(unlist(native$pieces)), c("x <- 1", "y <- 2"))
})
