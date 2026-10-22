test_that("same-line mutations are preserved without unsafe conversion", {
  source <- 'jmv::descriptives(data=d,vars="y"); d <- other'
  expect_identical(convert_code(source,engine="ggplot2")$status,"failed")
  out <- convert_rmd(paste0('```{r test-chunk}\n',source,'\n```'),engine="ggplot2")
  expect_identical(out$status,"failed")
  expect_match(out$text,source,fixed=TRUE)
})

test_that("hyphenated chunk labels survive display option replacement", {
  expect_identical(hide_chunk_output('```{r a2-descriptives, echo=TRUE}'),
    "```{r a2-descriptives, results='hide', fig.show='hide', echo=FALSE}")
})

test_that("generated plots restore random state even on failure", {
  skip_if_not_installed("ragg")
  set.seed(958); before <- .Random.seed
  run_generated('jmv::descriptives(data=d,vars="y")',data.frame(y=1:12))
  expect_identical(.Random.seed,before)
  expect_warning(run_generated('jmv::ANOVA(data=d,dep="y",factors="x")',data.frame(y=1:12,x="a")),"fewer than two observed levels",fixed=TRUE)
  expect_identical(.Random.seed,before)
})

test_that("missing requested engine mappings report partial conversion", {
  out <- convert_code('jmv::contTablesPaired(data=d,rows="x",cols="y")',engine="both")
  expect_identical(out$status,"partial")
  expect_true(any(vapply(out$diagnostics,function(x)x$code=="bettergg_mapping_unavailable",logical(1))))
})
