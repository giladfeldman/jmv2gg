# Regressions for the mismatches a second-model review found (Sonnet,
# 2026-10-22), each confirmed against jmv before the fix.

skip_if_not_installed("jmv")
skip_if_not_installed("statsExpressions")

set.seed(3)
n <- 90
d <- data.frame(y = rnorm(n), g = factor(rep(c("A", "B", "C"), 30)), h = factor(rep(c("P", "Q"), each = 45)),
  x = rnorm(n), z = rnorm(n), c1 = factor(sample(c("no", "yes"), n, TRUE)),
  c2 = factor(sample(c("lo", "mid", "hi"), n, TRUE)))
on <- list(stats = TRUE)
tol <- 1e-8
quiet <- function(expr) suppressWarnings(suppressMessages(expr))

test_that("ANOVA ignores case weights, as jmv::ANOVA does", {
  w <- d
  attr(w, "jmv-weights") <- rep(c(1, 3), n / 2)
  ref <- jmv::ANOVA(w, dep = "y", factors = c("g", "h"), emMeans = ~ g:h)
  env <- quiet(run_generated('jmv::ANOVA(data = w, dep = "y", factors = c("g", "h"))', w, style = on))
  tests <- env$anova_1_tests
  expect_equal(tests$F.ratio[tests[["model term"]] == "g"], ref$main$asDF$F[1], tolerance = tol)
  emm <- ref$emm[[1]]$emmTable$asDF
  m <- env$anova_1_means
  expect_equal(sort(m$emmean), sort(emm$mean), tolerance = tol)
})

test_that("one-sided correlation hypotheses give jmv's one-sided p-values", {
  for (hyp in c("pos", "neg")) {
    ref <- jmv::corrMatrix(d, vars = c("x", "y"), hypothesis = hyp)$matrix$asDF
    rownames(ref) <- ref[[".name[r]"]]
    env <- quiet(run_generated(sprintf('jmv::corrMatrix(data = d, vars = c("x", "y"), hypothesis = "%s")', hyp), d))
    expect_equal(env$correlation_1_cells$p, as.numeric(ref["y", "x[rp]"]), tolerance = tol, label = hyp)
  }
})

test_that("Spearman and Kendall p-values use jmv's exact tests in small samples", {
  s <- d[1:20, ]
  ref <- jmv::corrMatrix(s, vars = c("x", "y"), pearson = FALSE, spearman = TRUE, kendall = TRUE)$matrix$asDF
  rownames(ref) <- ref[[".name[rho]"]]
  env <- quiet(run_generated('jmv::corrMatrix(data = s, vars = c("x", "y"), pearson = FALSE, spearman = TRUE, kendall = TRUE)', s))
  expect_equal(env$correlation_1_spearman_cells$p, as.numeric(ref["y", "x[rhop]"]), tolerance = tol)
  expect_equal(env$correlation_1_kendall_cells$p, as.numeric(ref["y", "x[taup]"]), tolerance = tol)
})

test_that("one-sided one-sample t-tests give jmv's p-value", {
  for (hyp in c("gt", "lt")) {
    ref <- jmv::ttestOneS(d, vars = "y", testValue = 0.1, hypothesis = hyp)$ttest$asDF
    env <- quiet(run_generated(sprintf('jmv::ttestOneS(data = d, vars = "y", testValue = 0.1, hypothesis = "%s")', hyp), d, style = on))
    expect_equal(env$ttest_1_test$p.value, ref[["p[stud]"]], tolerance = tol, label = hyp)
  }
})

test_that("statistics are not drawn when the figure could not match the source", {
  codes <- function(code) vapply(convert_code(code, engine = "ggplot2", style = on)$diagnostics, function(x) x$code, "")
  expect_true("statistics_not_shown" %in% codes('jmv::propTestN(data = d, var = "c2", ratio = c(1, 2, 3))'))
  out <- convert_code('jmv::propTestN(data = d, var = "c2", ratio = c(1, 2, 3))', engine = "ggplot2", style = on)
  expect_false(grepl("table_1_subtitle <-", out$text, fixed = TRUE))
  expect_true("statistics_not_shown" %in% codes('jmv::anovaOneW(data = d, deps = "y", group = "g", welchs = FALSE, fishers = FALSE)'))
})

test_that("weighted contingency tables still draw their figure, without statistics", {
  skip_if_not_installed("ragg")
  w <- d
  attr(w, "jmv-weights") <- rep(c(1, 2), n / 2)
  env <- quiet(run_generated('jmv::contTables(data = w, rows = "c1", cols = "c2")', w, style = on))
  expect_s3_class(env$table_1_plot, "ggplot")
  expect_null(env$table_1_plot$labels$subtitle)
  expect_equal(sum(env$table_1_cells$counts), sum(rep(c(1, 2), n / 2)))
})

test_that("weighted linear regression equals jmv::linReg with case weights", {
  w <- d
  attr(w, "jmv-weights") <- rep(c(1, 2), n / 2)
  ref <- jmv::linReg(w, dep = "y", covs = "x", blocks = list(list("x")), ci = TRUE)$models[[1]]$coef$asDF
  env <- quiet(run_generated('jmv::linReg(data = w, dep = "y", covs = "x", blocks = list(list("x")))', w, style = on))
  expect_equal(env$regression_1_table$estimate, ref$est[2], tolerance = tol)
  expect_equal(env$regression_1_table$p.value, ref$p[2], tolerance = tol)
})
