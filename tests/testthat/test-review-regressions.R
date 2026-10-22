# Regressions for defects found in the 2026-10-22 code review.

test_that("logistic blocks are cumulative, as in jmv", {
  skip_if_not_installed("jmv"); skip_if_not_installed("ragg")
  set.seed(1)
  d <- data.frame(y = factor(sample(c("no", "yes"), 200, TRUE)), a = rnorm(200), b = rnorm(200))
  original <- jmv::logRegBin(data = d, dep = "y", covs = c("a", "b"), blocks = list(list("a"), list("b")))
  expected <- original$models[[2]]$coef$asDF$est
  env <- run_generated('jmv::logRegBin(data=d, dep="y", covs=c("a","b"), blocks=list(list("a"), list("b")))', d)
  expect_identical(names(stats::coef(env$logistic_1_model)), c("(Intercept)", "a", "b"))
  expect_equal(unname(stats::coef(env$logistic_1_model)), expected, tolerance = 1e-10)
})

test_that("ancova formulas keep numeric predictors as covariates, as in jmv", {
  skip_if_not_installed("jmv"); skip_if_not_installed("emmeans"); skip_if_not_installed("ragg")
  set.seed(2)
  d <- data.frame(y = rnorm(60), g = factor(rep(c("A", "B", "C"), 20)), age = runif(60, 20, 60))
  original <- jmv::ancova(formula = y ~ g + age, data = d, emMeans = ~ g)
  expected <- original$emm[[1]]$emmTable$asDF$mean
  env <- run_generated("jmv::ancova(formula = y ~ g + age, data = d)", d)
  expect_true(is.numeric(env$anova_1_input$age))
  expect_identical(env$anova_1_factors, "g")
  expect_identical(env$anova_1_covariates, "age")
  expect_length(stats::coef(env$anova_1_model), 4L)
  expect_equal(env$anova_1_means$emmean, expected, tolerance = 1e-8)
  expect_s3_class(env$anova_1_plot, "ggplot")
  layers <- ggplot2::ggplot_build(env$anova_1_plot)$data
  expect_equal(sort(layers[[length(layers)]]$y), sort(expected), tolerance = 1e-8)
})

test_that("ANOVA formulas still treat every predictor as a factor, as in jmv", {
  skip_if_not_installed("emmeans"); skip_if_not_installed("ragg")
  d <- data.frame(y = sin(1:40), dose = rep(c(1, 2), 20))
  env <- run_generated("jmv::ANOVA(formula = y ~ dose, data = d)", d)
  expect_true(is.factor(env$anova_1_input$dose))
})

test_that("YAML tags such as !r are kept verbatim", {
  rmd <- "---\ntitle: T\nparams:\n  day: !r Sys.Date()\n---\n\n```{r}\njmv::descriptives(data = d, vars = 'y')\n```\n"
  out <- convert_rmd(rmd, engine = "ggplot2")
  expect_match(out$text, "day: !r Sys.Date()", fixed = TRUE)
  expect_true(any(vapply(out$diagnostics, function(x) x$code == "yaml_expression_preserved", logical(1))))
})

test_that("SPSS value labels name the plotted groups", {
  skip_if_not_installed("haven"); skip_if_not_installed("emmeans"); skip_if_not_installed("ragg")
  d <- data.frame(y = sin(1:40))
  d$g <- haven::labelled(rep(c(1, 2), 20), c(Control = 1, Treatment = 2))
  env <- run_generated('jmv::ANOVA(data = d, dep = "y", factors = "g")', d)
  expect_identical(levels(env$anova_1_input$g), c("Control", "Treatment"))
})

test_that("SPSS value labels name categories in count, t-test and descriptive plots", {
  skip_if_not_installed("haven"); skip_if_not_installed("ragg")
  d <- data.frame(y = sin(1:40))
  d$g <- haven::labelled(rep(c(1, 2), 20), c(Control = 1, Treatment = 2))
  d$h <- haven::labelled(rep(c(1, 2, 2, 1), 10), c(No = 1, Yes = 2))
  env <- run_generated('jmv::contTables(data = d, rows = "g", cols = "h")', d)
  expect_identical(levels(env$table_1_input$g), c("Control", "Treatment"))
  expect_identical(levels(env$table_1_cells$g), c("Control", "Treatment"))
  env <- run_generated('jmv::ttestIS(data = d, vars = "y", group = "g")', d)
  expect_identical(levels(env$ttest_1_input$g), c("Control", "Treatment"))
  env <- run_generated('jmv::descriptives(data = d, vars = "h")', d)
  expect_identical(as.character(env$descriptives_1_cells$h), c("No", "Yes"))
})

test_that("one figure that cannot be drawn does not stop the others or the report", {
  skip_if_not_installed("ragg")
  code <- generated_code('jmv::descriptives(data=d, vars="y")', engine = "both")
  # Simulate a BetterGG figure that fails (for example BetterGG not installed).
  code <- gsub("BetterGG::gghistostats(", "broken_bettergg(", code, fixed = TRUE)
  work <- tempfile(); dir.create(work); old <- setwd(work); on.exit(setwd(old))
  env <- new.env(parent = globalenv())
  env$d <- data.frame(y = 1:30)
  env$broken_bettergg <- function(...) stop("there is no package called 'BetterGG'")
  expect_warning(eval(parse(text = code), envir = env), "figure descriptives_1-bettergg was not drawn", fixed = TRUE)
  expect_true(file.exists("figures/descriptives_1-ggplot2.png"))
  expect_false(file.exists("figures/descriptives_1-bettergg.png"))
})
