# The public test matrix: every supported function in the argument forms
# people write, checked three ways: (a) conversion status and diagnostics,
# (b) a snapshot of the generated code, (c) running the code on synthetic
# data (a figure object and a saved PNG). Statistics are checked against jmv
# in test-figure-statistics.R.

set.seed(11)
n <- 80
d <- data.frame(
  y = rnorm(n), x = rnorm(n), z = rnorm(n), age = runif(n, 18, 70),
  g = factor(rep(c("A", "B", "C", "D"), 20)), h = factor(rep(c("P", "Q"), each = 40)),
  k = factor(rep(c("u", "v"), 40)), pre = rnorm(n), mid = rnorm(n), post = rnorm(n),
  c1 = factor(sample(c("no", "yes"), n, TRUE)), c2 = factor(sample(c("lo", "mid", "hi"), n, TRUE)),
  q1 = sample(1:5, n, TRUE), q2 = sample(1:5, n, TRUE), q3 = sample(1:5, n, TRUE)
)
d$y[c(3, 17)] <- NA
odd <- stats::setNames(data.frame(rnorm(40), factor(rep(c("a", "b"), 20))), c("my score", "gro\u00dfe Gruppe"))
long <- data.frame(id = rep(1:20, 3), cond = factor(rep(c("c1", "c2", "c3"), each = 20)), score = rnorm(60))
fit <- lm(y ~ x + g, data = d)

cases <- list(
  anova_named = list('jmv::ANOVA(data = d, dep = "y", factors = "g")', "d", "complete"),
  anova_positional = list('jmv::ANOVA(d, "y", "g")', "d", "complete"),
  anova_formula = list("jmv::ANOVA(formula = y ~ g * h, data = d)", "d", "complete"),
  anova_terms = list('jmv::ANOVA(data = d, dep = "y", factors = c("g", "h"), modelTerms = list("g", "h"))', "d", "complete"),
  anova_three_way = list('jmv::ANOVA(data = d, dep = "y", factors = c("g", "h", "k"), emMeans = ~ g:h)', "d", "complete"),
  anova_unqualified = list('ANOVA(data = d, dep = "y", factors = "h")', "d", "complete"),
  ancova_named = list('jmv::ancova(data = d, dep = "y", factors = "g", covs = "age")', "d", "complete"),
  ancova_formula = list("jmv::ancova(formula = y ~ g + h + age, data = d)", "d", "complete"),
  oneway = list('jmv::anovaOneW(data = d, deps = c("y", "x"), group = "g")', "d", "complete"),
  kruskal = list('jmv::anovaNP(data = d, deps = "y", group = "g")', "d", "complete"),
  ttest_bare = list("jmv::ttestIS(data = d, vars = y, group = h)", "d", "complete"),
  ttest_vars = list('jmv::ttestIS(data = d, vars = vars(y, x), group = "h", welchs = TRUE)', "d", "complete"),
  ttest_formula = list("jmv::ttestIS(formula = y ~ h, data = d)", "d", "complete"),
  ttest_paired = list('jmv::ttestPS(data = d, pairs = list(list(i1 = "pre", i2 = "post"), list(i1 = "pre", i2 = "mid")))', "d", "complete"),
  ttest_one = list('jmv::ttestOneS(data = d, vars = "y", testValue = 0.2)', "d", "complete"),
  rm_one = list('jmv::anovaRM(data = d, rm = list(list(label = "time", levels = c("pre", "mid", "post"))), rmCells = list(list(measure = "pre", cell = "pre"), list(measure = "mid", cell = "mid"), list(measure = "post", cell = "post")))', "d", "complete"),
  rm_mixed = list('jmv::anovaRM(data = d, rm = list(list(label = "time", levels = c("pre", "post"))), rmCells = list(list(measure = "pre", cell = "pre"), list(measure = "post", cell = "post")), bs = "h")', "d", "complete"),
  descriptives = list('jmv::descriptives(data = d, vars = c("y", "c2"), splitBy = "h")', "d", "complete"),
  table = list('jmv::contTables(data = d, rows = "c1", cols = "c2")', "d", "complete"),
  table_layers = list('jmv::contTables(data = d, rows = "c1", cols = "c2", layers = "h")', "d", "complete"),
  table_paired = list('jmv::contTablesPaired(data = d, rows = "c1", cols = "h")', "d", "partial"),
  prop2 = list('jmv::propTest2(data = d, vars = c("c1", "c2"))', "d", "complete"),
  propn = list('jmv::propTestN(data = d, var = "c2")', "d", "complete"),
  corr = list('jmv::corrMatrix(data = d, vars = c("y", "x", "z"), spearman = TRUE)', "d", "complete"),
  corr_partial = list('jmv::corrPart(data = d, vars = c("y", "x"), controls = "z")', "d", "partial"),
  logistic = list('jmv::logRegBin(data = d, dep = "c1", covs = c("x", "z"), factors = "h", blocks = list(list("x"), list("z", "h")), refLevels = list(list(var = "h", ref = "Q")))', "d", "complete"),
  linear = list('jmv::linReg(data = d, dep = "y", covs = "x", factors = "g", blocks = list(list("x"), list("g")))', "d", "complete"),
  reliability = list('jmv::reliability(data = d, vars = c("q1", "q2", "q3"), revItems = "q2")', "d", "complete"),
  odd_names = list('jmv::ttestIS(data = odd, vars = "my score", group = "gro\u00dfe Gruppe")', "odd", "complete"),
  odd_formula = list("jmv::ANOVA(formula = `my score` ~ `gro\u00dfe Gruppe`, data = odd)", "odd", "complete"),
  gg_between = list("ggstatsplot::ggbetweenstats(data = d, x = g, y = y)", "d", "complete"),
  gg_within = list("ggstatsplot::ggwithinstats(data = long, x = cond, y = score, subject.id = id)", "long", "complete"),
  gg_scatter = list("ggstatsplot::ggscatterstats(data = d, x = x, y = y)", "d", "complete"),
  gg_histo = list("ggstatsplot::gghistostats(data = d, x = x, test.value = 1)", "d", "complete"),
  gg_bar = list("ggstatsplot::ggbarstats(data = d, x = c1, y = c2)", "d", "complete"),
  gg_pie = list("ggstatsplot::ggpiestats(data = d, x = c2)", "d", "complete"),
  gg_corrmat = list('ggstatsplot::ggcorrmat(data = d, cor.vars = c("x", "y", "z"))', "d", "complete"),
  gg_coef = list("ggstatsplot::ggcoefstats(x = fit)", NULL, "complete"),
  gg_grouped = list("ggstatsplot::grouped_ggbetweenstats(data = d, x = g, y = y, grouping.var = h)", "d", "partial")
)

status_of <- function(code) convert_code(code, engine = "both")$status

test_that("(a) every argument form converts with the expected status", {
  for (case in names(cases)) {
    expect_identical(status_of(cases[[case]][[1]]), cases[[case]][[3]], label = case)
  }
})

test_that("(a) unsupported, dynamic and invalid calls fail visibly", {
  out <- convert_code('jmv::ttest(data = d, vars = "y")')
  expect_identical(out$status, "failed")
  expect_true(any(vapply(out$diagnostics, function(x) x$code == "unsupported_analysis", logical(1))))
  out <- convert_code('jmv::ANOVA(data = d[d$y > 0, ], dep = "y", factors = "g")')
  expect_identical(out$status, "failed")
  expect_match(out$diagnostics[[1]]$message, "stable named data frame")
  out <- convert_code('jmv::ANOVA(data = d, dep = "y", factors = c("g", "h", "k", "c1"))')
  expect_match(out$diagnostics[[1]]$message, "up to three factors")
  out <- convert_code('theme_figure <- 1\njmv::ANOVA(data = d, dep = "y", factors = "g")')
  expect_identical(out$status, "failed")
  expect_true(any(vapply(out$diagnostics, function(x) x$code == "reserved_name", logical(1))))
})

test_that("(a) generated names never clash with the source's own objects", {
  out <- convert_code('anova_1_data <- d\njmv::ANOVA(data = d, dep = "y", factors = "g")', engine = "ggplot2")
  expect_identical(out$analyses[[1]]$name, "jmv2gg_anova_1")
  expect_match(out$text, "jmv2gg_anova_1_plot <-", fixed = TRUE)
  out <- convert_code('jmv::ANOVA(data = d, dep = "y", factors = "g")\njmv::ANOVA(data = d, dep = "x", factors = "h")', engine = "ggplot2")
  expect_identical(vapply(out$analyses, function(a) a$name, ""), c("anova_1", "anova_2"))
})

test_that("(b) generated code matches its snapshot", {
  options <- conversion_options(list(), list())
  for (case in c("anova_named", "anova_formula", "ancova_formula", "ttest_paired", "rm_mixed", "descriptives",
    "table_layers", "corr_partial", "logistic", "reliability", "gg_within")) {
    a <- assign_analysis_names(inspect_code(cases[[case]][[1]])$analyses, character())[[1]]
    expect_snapshot(cat(generate_analysis(a, "both", options)$code), variant = NULL)
  }
})

test_that("(c) every case runs and draws its ggplot2 figures", {
  skip_if_not_installed("ragg")
  for (case in names(cases)) {
    if (identical(cases[[case]][[3]], "failed") || case == "gg_grouped") next
    code <- cases[[case]][[1]]
    data_name <- cases[[case]][[2]]
    a <- assign_analysis_names(inspect_code(code)$analyses, character())[[1]]
    options <- conversion_options(list(), list(dpi = 72, width = 3, height = 2))
    generated <- generate_analysis(a, "ggplot2", options)
    env <- new.env(parent = globalenv())
    env$d <- d; env$odd <- odd; env$long <- long; env$fit <- fit
    work <- tempfile(); dir.create(work); old <- setwd(work)
    warnings <- character()
    withCallingHandlers(
      eval(parse(text = c(figure_setup_code(options, generated$packages), generated$code)), envir = env),
      warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
    )
    files <- list.files("figures", pattern = "png$")
    setwd(old)
    expect_identical(grep("jmv2gg: figure", warnings, value = TRUE), character(), label = case)
    expect_equal(length(files), sum(vapply(generated$plots, function(p) p$engine == "ggplot2", logical(1))), label = case)
    for (p in generated$plots) expect_s3_class(env[[p$object]], "ggplot")
  }
})

test_that("(c) the BetterGG engine runs for the main families", {
  skip_if_not_installed("BetterGG"); skip_if_not_installed("ragg")
  for (case in c("anova_named", "anova_formula", "ancova_formula", "ttest_bare", "rm_one", "rm_mixed",
    "descriptives", "table", "corr", "logistic", "reliability", "gg_grouped")) {
    code <- cases[[case]][[1]]
    a <- assign_analysis_names(inspect_code(code)$analyses, character())[[1]]
    options <- conversion_options(list(), list(dpi = 72, width = 3, height = 2))
    generated <- generate_analysis(a, "bettergg", options)
    env <- new.env(parent = globalenv())
    env$d <- d
    work <- tempfile(); dir.create(work); old <- setwd(work)
    warnings <- character()
    suppressMessages(withCallingHandlers(
      eval(parse(text = c(figure_setup_code(options, generated$packages), generated$code)), envir = env),
      warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
    ))
    setwd(old)
    expect_identical(grep("jmv2gg: figure", warnings, value = TRUE), character(), label = case)
  }
})

test_that("(c) weights, labelled data, missing values and empty groups are handled", {
  skip_if_not_installed("ragg"); skip_if_not_installed("haven"); skip_if_not_installed("emmeans")
  w <- d
  attr(w, "jmv-weights") <- rep(c(1, 2), n / 2)
  env <- run_generated('jmv::ANOVA(data = w, dep = "y", factors = "g")', w)
  expect_equal(unname(stats::weights(env$anova_1_model)), rep(c(1, 2), n / 2)[!is.na(d$y)])
  lab <- d
  lab$g <- haven::labelled(as.integer(d$g), c(First = 1, Second = 2, Third = 3, Fourth = 4))
  env <- run_generated('jmv::ANOVA(data = lab, dep = "y", factors = "g")', lab)
  expect_identical(levels(env$anova_1_data$g), c("First", "Second", "Third", "Fourth"))
  empty <- d
  empty$g <- factor(as.character(d$g), levels = c("A", "B", "C", "D", "never"))
  env <- run_generated('jmv::ttestIS(data = empty, vars = "y", group = "h")', empty)
  expect_equal(sum(env$ttest_1_summary$n), sum(!is.na(d$y)))
  env <- run_generated('jmv::ANOVA(data = empty, dep = "y", factors = "g")', empty)
  expect_identical(levels(env$anova_1_data$g), c("A", "B", "C", "D"))
  single <- d
  single$g <- factor("A")
  expect_warning(run_generated('jmv::ANOVA(data = single, dep = "y", factors = "g")', single), "fewer than two observed levels")
})

test_that("(c) export formats and journal sizes are written", {
  skip_if_not_installed("ragg")
  env <- run_generated('jmv::ttestIS(data = d, vars = "y", group = "h")', d,
    figures = list(size = "single", dpi = 100, formats = c("png", "pdf", "tiff")))
  files <- list.files(file.path(env$.work, "figures"))
  expect_setequal(files, c("ttest_1-ggplot2.png", "ttest_1-ggplot2.pdf", "ttest_1-ggplot2.tiff"))
  dims <- dim(png::readPNG(file.path(env$.work, "figures", "ttest_1-ggplot2.png")))
  expect_equal(dims[2], 350)
  expect_equal(dims[1], round(350 * 3 / 4))
  expect_identical(rawToChar(readBin(file.path(env$.work, "figures", "ttest_1-ggplot2.pdf"), "raw", 4)), "%PDF")
  expect_error(conversion_options(list(), list(formats = "gif")), "png, pdf, tiff")
})
