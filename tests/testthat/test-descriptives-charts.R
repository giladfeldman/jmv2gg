has_layer <- function(plot, geom) any(vapply(plot$layers, function(layer) inherits(layer$geom, geom), logical(1)))

descriptives_data <- function() {
  set.seed(4)
  long <- sprintf("Long category %02d", 1:51)
  agree <- c("Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree")
  data.frame(
    passed = rep(c(0, 1, 1, 0, 1, 1), 34)[1:204],
    score = round(rnorm(204, 50, 10)),
    many = factor(rep(long, length.out = 204), levels = long),
    agreement = factor(sample(agree, 204, TRUE), levels = agree, ordered = TRUE),
    colour = factor(sample(c("red", "green", "blue"), 204, TRUE)),
    group = factor(rep(c("a", "b"), 102))
  )
}

test_that("a 0/1 variable is drawn as the proportion of 1s with Wilson intervals", {
  skip_if_not_installed("ragg")
  d <- descriptives_data()
  env <- run_generated('jmv::descriptives(data = d, vars = "passed")', d)
  p <- env$descriptives_1_plot
  expect_true(has_layer(p, "GeomErrorbar"))
  expect_equal(nrow(ggplot2::ggplot_build(p)$data[[1]]), 1L) # one bar, not histogram bins
  expect_equal(ggplot2::ggplot_build(p)$data[[1]]$y, mean(d$passed))
  # split: one bar per group
  env <- run_generated('jmv::descriptives(data = d, vars = "passed", splitBy = "group")', d)
  expect_equal(ggplot2::ggplot_build(env$descriptives_1_plot)$data[[1]]$y,
    as.numeric(tapply(d$passed, d$group, mean)))
})

test_that("numeric variables that are not 0/1 keep the histogram", {
  skip_if_not_installed("ragg")
  d <- descriptives_data()
  env <- run_generated('jmv::descriptives(data = d, vars = "score")', d)
  expect_false(has_layer(env$descriptives_1_plot, "GeomErrorbar"))
  expect_true(has_layer(env$descriptives_1_plot, "GeomBar"))
})

test_that("many or ordered categories are drawn as percentage bars, few unordered ones as a pie", {
  skip_if_not_installed("ragg")
  d <- descriptives_data()
  many <- run_generated('jmv::descriptives(data = d, vars = "many")', d)$descriptives_1_plot
  expect_s3_class(many$coordinates, "CoordFlip")
  expect_equal(nrow(ggplot2::ggplot_build(many)$data[[1]]), 51L)
  agree <- run_generated('jmv::descriptives(data = d, vars = "agreement")', d)$descriptives_1_plot
  built <- ggplot2::ggplot_build(agree)$data[[1]]
  expect_false(inherits(agree$coordinates, "CoordFlip"))
  expect_false(inherits(agree$coordinates, "CoordPolar"))
  expect_equal(nrow(built), 5L)
  expect_length(unique(built$fill), 5L) # scale-ordered colours, one per category
  pie <- run_generated('jmv::descriptives(data = d, vars = "colour")', d)$descriptives_1_plot
  expect_s3_class(pie$coordinates, "CoordPolar")
  # with a split, categories stay stacked bars
  split <- run_generated('jmv::descriptives(data = d, vars = "many", splitBy = "group")', d)$descriptives_1_plot
  expect_false(inherits(split$coordinates, "CoordPolar"))
  expect_true(has_layer(split, "GeomBar") || has_layer(split, "GeomCol"))
})

test_that("renamed categories keep their bar colours on percentage bars", {
  skip_if_not_installed("ragg")
  d <- descriptives_data()
  fills <- function(style) {
    p <- run_generated('jmv::descriptives(data = d, vars = "agreement")', d, style = style)$descriptives_1_plot
    ggplot2::ggplot_build(p)$data[[1]]$fill
  }
  renamed <- fills(list(level_text = list(agreement = list(Neutral = "Neither agree nor disagree"))))
  expect_identical(renamed, fills(list()))
  expect_false(anyNA(renamed))
})

test_that("the BetterGG engine draws 0/1 proportions and many-category bars too", {
  skip_if_not_installed("ragg")
  d <- descriptives_data()
  env <- run_generated('jmv::descriptives(data = d, vars = "passed")', d, engine = "bettergg")
  expect_true(has_layer(env$descriptives_1_bettergg, "GeomErrorbar"))
  env <- run_generated('jmv::descriptives(data = d, vars = "many")', d, engine = "bettergg")
  expect_s3_class(env$descriptives_1_bettergg$coordinates, "CoordFlip")
  env <- run_generated('jmv::descriptives(data = d, vars = "colour")', d, engine = "bettergg")
  expect_s3_class(env$descriptives_1_bettergg$coordinates, "CoordPolar")
})
