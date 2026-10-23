# Every statistic a figure can print (stats = TRUE) must equal jamovi's own
# result table for the same analysis. The references below come from the jmv
# result objects, never from jmv2gg's code.

skip_if_not_installed("jmv")
skip_if_not_installed("statsExpressions")

set.seed(3)
n <- 90
d <- data.frame(y = rnorm(n), g = factor(rep(c("A", "B", "C"), 30)), h = factor(rep(c("P", "Q"), each = 45)),
  age = runif(n, 20, 60), x = rnorm(n), z = rnorm(n), pre = rnorm(n), post = rnorm(n),
  c1 = factor(sample(c("no", "yes"), n, TRUE)), c2 = factor(sample(c("lo", "mid", "hi"), n, TRUE)))
d$y <- d$y + as.integer(d$g) * 0.3 + d$x * 0.4
d$post <- d$post + d$pre * 0.5 + 0.3
on <- list(stats = TRUE)
tol <- 1e-8

test_that("one-way ANOVA subtitle equals jmv::ANOVA", {
  ref <- jmv::ANOVA(d, dep = "y", factors = "g")$main$asDF
  env <- run_generated('jmv::ANOVA(data = d, dep = "y", factors = "g")', d, style = on)
  expect_equal(env$anova_1_test$statistic, ref$F[1], tolerance = tol)
  expect_equal(env$anova_1_test$p.value, ref$p[1], tolerance = tol)
  expect_equal(env$anova_1_test$df.error, ref$df[2], tolerance = tol)
})

test_that("factorial ANOVA F tests equal jmv::ANOVA (type III)", {
  ref <- jmv::ANOVA(d, dep = "y", factors = c("g", "h"))$main$asDF
  env <- run_generated('jmv::ANOVA(data = d, dep = "y", factors = c("g", "h"))', d, style = on)
  tests <- env$anova_1_tests
  for (term in c("g", "h", "g:h")) {
    expect_equal(tests$F.ratio[tests[["model term"]] == term], ref$F[ref$name == term], tolerance = tol)
    expect_equal(tests$p.value[tests[["model term"]] == term], ref$p[ref$name == term], tolerance = tol)
  }
  expect_match(env$anova_1_subtitle, "g × h: F(2, 84)", fixed = TRUE)
})

test_that("ANCOVA F tests and adjusted means equal jmv::ancova", {
  res <- jmv::ancova(d, dep = "y", factors = "g", covs = "age", emMeans = ~ g)
  ref <- res$main$asDF
  env <- run_generated('jmv::ancova(data = d, dep = "y", factors = "g", covs = "age")', d, style = on)
  tests <- env$anova_1_tests
  for (term in c("g", "age")) {
    expect_equal(tests$F.ratio[tests[["model term"]] == term], ref$F[ref$name == term], tolerance = tol)
  }
  emm <- res$emm[[1]]$emmTable$asDF
  expect_equal(env$anova_1_means$emmean, emm$mean, tolerance = tol)
  expect_equal(env$anova_1_means$lower.CL, emm$lower, tolerance = tol)
})

test_that("factorial model means and intervals equal jmv's estimated marginal means", {
  emm <- jmv::ANOVA(d, dep = "y", factors = c("g", "h"), emMeans = ~ g:h)$emm[[1]]$emmTable$asDF
  env <- run_generated('jmv::ANOVA(data = d, dep = "y", factors = c("g", "h"))', d)
  m <- env$anova_1_means
  key <- function(a, b) paste(a, b)
  ord <- match(key(emm$g, emm$h), key(m$g, m$h))
  expect_equal(m$emmean[ord], emm$mean, tolerance = tol)
  expect_equal(m$upper.CL[ord], emm$upper, tolerance = tol)
  built <- ggplot2::ggplot_build(env$anova_1_plot)
  expect_equal(sort(built$data[[4]]$ymin), sort(emm$lower), tolerance = tol)
})

test_that("independent t-tests equal jmv::ttestIS (Student, Welch, one-sided)", {
  ref <- jmv::ttestIS(d, vars = "y", group = "h", welchs = TRUE)$ttest$asDF
  env <- run_generated('jmv::ttestIS(data = d, vars = "y", group = "h")', d, style = on)
  expect_equal(env$ttest_1_test$statistic, ref[["stat[stud]"]], tolerance = tol)
  expect_equal(env$ttest_1_test$p.value, ref[["p[stud]"]], tolerance = tol)
  env <- run_generated('jmv::ttestIS(data = d, vars = "y", group = "h", students = FALSE, welchs = TRUE)', d, style = on)
  expect_equal(env$ttest_1_test$statistic, ref[["stat[welc]"]], tolerance = tol)
  expect_equal(env$ttest_1_test$df.error, ref[["df[welc]"]], tolerance = tol)
  one <- jmv::ttestIS(d, vars = "y", group = "h", hypothesis = "oneGreater")$ttest$asDF
  env <- run_generated('jmv::ttestIS(data = d, vars = "y", group = "h", hypothesis = "oneGreater")', d, style = on)
  expect_equal(env$ttest_1_test$p.value, one[["p[stud]"]], tolerance = tol)
  env <- run_generated('jmv::ttestIS(formula = y ~ h, data = d)', d, style = on)
  expect_equal(env$ttest_1_test$statistic, ref[["stat[stud]"]], tolerance = tol)
})

test_that("paired and one-sample t-tests equal jmv", {
  ref <- jmv::ttestPS(d, pairs = list(list(i1 = "pre", i2 = "post")))$ttest$asDF
  env <- run_generated('jmv::ttestPS(data = d, pairs = list(list(i1 = "pre", i2 = "post")))', d, style = on)
  expect_equal(env$ttest_1_test$statistic, ref[["stat[stud]"]], tolerance = tol)
  expect_equal(env$ttest_1_test$p.value, ref[["p[stud]"]], tolerance = tol)
  ref <- jmv::ttestOneS(d, vars = "y", testValue = 0.5)$ttest$asDF
  env <- run_generated('jmv::ttestOneS(data = d, vars = "y", testValue = 0.5)', d, style = on)
  expect_equal(env$ttest_1_test$statistic, ref[["stat[stud]"]], tolerance = tol)
  expect_equal(env$ttest_1_test$p.value, ref[["p[stud]"]], tolerance = tol)
})

test_that("one-way (Welch, Fisher) and Kruskal-Wallis equal jmv", {
  ref <- jmv::anovaOneW(d, deps = "y", group = "g", fishers = TRUE)$anova$asDF
  env <- run_generated('jmv::anovaOneW(data = d, deps = "y", group = "g")', d, style = on)
  expect_equal(env$anova_1_test$statistic, ref[["F[welch]"]], tolerance = tol)
  expect_equal(env$anova_1_test$df.error, ref[["df2[welch]"]], tolerance = tol)
  env <- run_generated('jmv::anovaOneW(data = d, deps = "y", group = "g", welchs = FALSE, fishers = TRUE)', d, style = on)
  expect_equal(env$anova_1_test$statistic, ref[["F[fisher]"]], tolerance = tol)
  ref <- jmv::anovaNP(d, deps = "y", group = "g")$table$asDF
  env <- run_generated('jmv::anovaNP(data = d, deps = "y", group = "g")', d, style = on)
  expect_equal(env$anova_1_test$statistic, ref$chiSq, tolerance = tol)
  expect_equal(env$anova_1_test$p.value, ref$p, tolerance = tol)
})

test_that("one-factor repeated-measures ANOVA equals jmv::anovaRM (Greenhouse-Geisser)", {
  wide <- data.frame(a = d$pre, b = d$post, c = d$x)
  ref <- jmv::anovaRM(wide, rm = list(list(label = "time", levels = c("a", "b", "c"))),
    rmCells = list(list(measure = "a", cell = "a"), list(measure = "b", cell = "b"), list(measure = "c", cell = "c")),
    spherCorr = "GG")$rmTable$asDF
  call <- 'jmv::anovaRM(data = wide, rm = list(list(label = "time", levels = c("a", "b", "c"))), rmCells = list(list(measure = "a", cell = "a"), list(measure = "b", cell = "b"), list(measure = "c", cell = "c"))%s)'
  env <- run_generated(sprintf(call, ', spherCorr = "GG"'), wide, style = on)
  expect_equal(env$rm_anova_1_test$statistic, ref[["F[GG]"]][1], tolerance = tol)
  expect_equal(env$rm_anova_1_test$p.value, ref[["p[GG]"]][1], tolerance = tol)
  expect_equal(env$rm_anova_1_test$df.error, ref[["df[GG]"]][2], tolerance = tol)
  # uncorrected source table: no statistics on the figure, with a note
  out <- convert_code(sprintf(call, ""), engine = "ggplot2", style = on)
  expect_true(any(vapply(out$diagnostics, function(x) x$code == "statistics_not_shown", logical(1))))
  expect_false(grepl("rm_anova_1_subtitle <-", out$text, fixed = TRUE))
})

test_that("within-subject levels with spaces keep their names and means (afex renames them)", {
  wide <- data.frame(hd = d$pre, ld = d$post, hp = d$x, lp = d$z)
  call <- paste0('jmv::anovaRM(data = wide, rm = list(list(label = "Seat", levels = c("Driver", "Passenger")), ',
    'list(label = "Level of Control", levels = c("High Control", "Low Control"))), rmCells = list(',
    'list(measure = "hd", cell = c("Driver", "High Control")), list(measure = "ld", cell = c("Driver", "Low Control")), ',
    'list(measure = "hp", cell = c("Passenger", "High Control")), list(measure = "lp", cell = c("Passenger", "Low Control"))))')
  env <- run_generated(call, wide)
  means <- env$rm_anova_1_means
  expect_false(anyNA(means[c("Seat", "Level of Control")]))
  expect_identical(levels(means[["Level of Control"]]), c("High Control", "Low Control"))
  expect_true(inherits(env$rm_anova_1_plot, "ggplot"))
  # In a fully within-subject design the model means are the cell means.
  cell <- function(seat, level) means$emmean[means$Seat == seat & means[["Level of Control"]] == level]
  expect_equal(cell("Driver", "High Control"), mean(wide$hd), tolerance = tol)
  expect_equal(cell("Passenger", "Low Control"), mean(wide$lp), tolerance = tol)
})

test_that("correlation cells and their crosses equal jmv::corrMatrix and jmv::corrPart", {
  res <- jmv::corrMatrix(d, vars = c("x", "y", "z"), kendall = TRUE)$matrix$asDF
  rownames(res) <- res[[".name[r]"]]
  env <- run_generated('jmv::corrMatrix(data = d, vars = c("x", "y", "z"), kendall = TRUE)', d)
  pearson <- env$correlation_1_pearson_cells
  kendall <- env$correlation_1_kendall_cells
  cell <- function(cells, a, b, col) cells[[col]][cells$Var1 == a & cells$Var2 == b]
  for (pair in list(c("x", "y"), c("x", "z"), c("y", "z"))) {
    expect_equal(cell(pearson, pair[1], pair[2], "r"), as.numeric(res[pair[2], paste0(pair[1], "[r]")]), tolerance = tol)
    expect_equal(cell(pearson, pair[1], pair[2], "p"), as.numeric(res[pair[2], paste0(pair[1], "[rp]")]), tolerance = tol)
    expect_equal(cell(kendall, pair[1], pair[2], "r"), as.numeric(res[pair[2], paste0(pair[1], "[tau]")]), tolerance = tol)
    expect_equal(cell(kendall, pair[1], pair[2], "p"), as.numeric(res[pair[2], paste0(pair[1], "[taup]")]), tolerance = tol)
  }
  # jmv flags unadjusted p-values, so no multiplicity correction is applied
  expect_identical(pearson$p_adjusted, pearson$p)
  part <- jmv::corrPart(d, vars = c("x", "y"), controls = "z")$matrix$asDF
  rownames(part) <- part[[".name[r]"]]
  env <- run_generated('jmv::corrPart(data = d, vars = c("x", "y"), controls = "z")', d)
  expect_equal(env$correlation_1_cells$r, as.numeric(part["y", "x[r]"]), tolerance = tol)
  expect_equal(env$correlation_1_cells$p, as.numeric(part["y", "x[rp]"]), tolerance = tol)
})

test_that("contingency-table and McNemar subtitles equal jmv", {
  ref <- jmv::contTables(d, rows = "c1", cols = "c2")$chiSq$asDF
  env <- run_generated('jmv::contTables(data = d, rows = "c1", cols = "c2")', d, style = on)
  expect_equal(env$table_1_test$statistic, ref[["value[chiSq]"]][1], tolerance = tol)
  expect_equal(env$table_1_test$p.value, ref[["p[chiSq]"]][1], tolerance = tol)
  # Cramer's V is jamovi's (uncorrected), not the bias-corrected V of ggbarstats.
  v <- jmv::contTables(d, rows = "c1", cols = "c2", phiCra = TRUE)$nom$asDF[["v[cra]"]][1]
  expect_equal(unname(env$table_1_v), v, tolerance = tol)
  expect_match(paste(deparse(env$table_1_subtitle), collapse = " "), formatC(v, format = "f", digits = 2), fixed = TRUE)
  ref <- jmv::contTablesPaired(d, rows = "c1", cols = "h")$test$asDF
  env <- run_generated('jmv::contTablesPaired(data = d, rows = "c1", cols = "h")', d, style = on)
  expect_equal(env$table_1_test$statistic, ref[["value[mcn]"]][1], tolerance = tol)
  expect_equal(env$table_1_test$p.value, ref[["p[mcn]"]][1], tolerance = tol)
})

test_that("odds ratios, Wald intervals and z tests equal jmv::logRegBin", {
  res <- jmv::logRegBin(d, dep = "c1", covs = "x", factors = "g", blocks = list(list("x", "g")), OR = TRUE, ciOR = TRUE)
  ref <- res$models[[1]]$coef$asDF
  ref <- ref[!is.na(ref$est) & ref$term != "Intercept", ]
  env <- run_generated('jmv::logRegBin(data = d, dep = "c1", covs = "x", factors = "g", blocks = list(list("x", "g")))', d, style = on)
  tab <- env$logistic_1_table
  expect_equal(tab$estimate, ref$odds, tolerance = tol)
  expect_equal(tab$conf.low, ref$oddsLower, tolerance = tol)
  expect_equal(tab$conf.high, ref$oddsUpper, tolerance = tol)
  expect_equal(tab$statistic, ref$z, tolerance = tol)
  expect_equal(tab$p.value, ref$p, tolerance = tol)
})

test_that("linear regression coefficients, t intervals and tests equal jmv::linReg", {
  res <- jmv::linReg(d, dep = "y", covs = "x", factors = "g", blocks = list(list("x", "g")), ci = TRUE)
  ref <- res$models[[1]]$coef$asDF
  ref <- ref[!is.na(ref$est) & ref$term != "Intercept", ]
  env <- run_generated('jmv::linReg(data = d, dep = "y", covs = "x", factors = "g", blocks = list(list("x", "g")))', d, style = on)
  tab <- env$regression_1_table
  expect_equal(tab$estimate, ref$est, tolerance = tol)
  expect_equal(tab$conf.low, ref$lower, tolerance = tol)
  expect_equal(tab$conf.high, ref$upper, tolerance = tol)
  expect_equal(tab$statistic, ref$t, tolerance = tol)
  expect_equal(tab$p.value, ref$p, tolerance = tol)
})

test_that("reliability alpha and item-rest correlations equal jmv::reliability", {
  items <- data.frame(q1 = round(d$x * 1.2 + 3), q2 = round(d$x + d$z * 0.5 + 3), q3 = round(-d$x + 3))
  res <- jmv::reliability(items, vars = c("q1", "q2", "q3"), revItems = "q3", itemRestCor = TRUE)
  env <- run_generated('jmv::reliability(data = items, vars = c("q1", "q2", "q3"), revItems = "q3")', items, style = on)
  expect_equal(env$reliability_1_alpha, res$scale$asDF$alpha, tolerance = tol)
  expect_equal(unname(env$reliability_1_rest), res$items$asDF$itemRestCor, tolerance = tol)
})

test_that("a measure mapped to an undeclared within-subject level is ignored, as jamovi does", {
  set.seed(2)
  wide <- data.frame(m1 = rnorm(60), m2 = rnorm(60) + 0.5, m3 = rnorm(60) + 1, g = factor(rep(c("Art", "Artifact"), 30)))
  call <- paste0('jmv::anovaRM(data = wide, rm = list(list(label = "Dup", levels = c("Same", "Other"))), ',
    'rmCells = list(list(measure = "m1", cell = "Same"), list(measure = "m2", cell = "Other"), list(measure = "m3", cell = "AI")), ',
    'bs = "g", rmTerms = ~ Dup, bsTerms = ~ g)')
  ref <- eval(parse(text = call))$rmTable$asDF
  out <- convert_code(call, engine = "ggplot2", style = on)
  expect_true("unused_measure" %in% vapply(out$diagnostics, function(x) x$code, character(1)))
  env <- run_generated(call, wide, style = on)
  tests <- as.data.frame(env$rm_anova_1_model$anova_table)
  expect_equal(tests["Dup", "F"], ref[["F[none]"]][1], tolerance = tol)
  expect_equal(tests["g:Dup", "Pr(>F)"], ref[["p[none]"]][2], tolerance = tol)
  expect_false(anyNA(env$rm_anova_1_means$emmean))
})
