test_that("paired wide data uses a subject-preserving long representation", {
  skip_if_not_installed("ragg")
  d<-data.frame(before=sin(1:30),after=sin(1:30)+cos(1:30)/2+.2)
  env<-suppressMessages(run_generated('jmv::ttestPS(data=d,pairs=list(list(i1="before",i2="after")))',d))
  expect_equal(nrow(env$ttest_1_long),60)
  expect_equal(length(unique(env$ttest_1_long$subject)),30)
  expect_equal(unname(env$ttest_1_summary$value),unname(colMeans(d)),tolerance=1e-10)
})

test_that("absent ANOVA model terms use the verified jmv factorial default", {
  out<-convert_code('jmv::ANOVA(data=d,dep="y",factors=c("a","b"))',engine="ggplot2")
  expect_match(out$text,'stats::lm(y ~ a * b,',fixed=TRUE)
})

test_that("unsafe names round-trip as R identifiers", {
  values<-c('a b','a`b','a\\b','a\nb')
  for(v in values) expect_identical(as.character(parse(text=r_name(v))[[1]]),v)
  for(v in c(values, "plain", "if", "TRUE")) expect_identical(as.character(parse(text=r_sym(v))[[1]]),v)
  expect_identical(r_sym(c("plain", "a b")), c("plain", "`a b`"))
})
