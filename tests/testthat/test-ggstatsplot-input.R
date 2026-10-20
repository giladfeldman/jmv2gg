test_that("BetterGG preserves explicit source statistical arguments", {
  out<-convert_code('ggstatsplot::ggbetweenstats(data=d,x=group,y=score,type="nonparametric",alternative="greater",conf.level=.9,p.adjust.method="bonferroni")',engine="bettergg")
  expect_identical(out$status,"complete")
  expect_match(out$text,'type = "nonparametric"',fixed=TRUE)
  expect_match(out$text,'alternative = "greater"',fixed=TRUE)
  expect_match(out$text,'p.adjust.method = "bonferroni"',fixed=TRUE)
  expect_match(out$text,'BetterGG::ggbetweenstats',fixed=TRUE)
})

test_that("scatter input produces a scatterplot rather than a correlation matrix", {
  out<-convert_code('ggstatsplot::ggscatterstats(data=d,x=a,y=b)',engine="ggplot2")
  expect_identical(out$status,"complete")
  expect_match(out$text,"ggplot2::geom_point",fixed=TRUE)
  expect_false(grepl("geom_tile",out$text,fixed=TRUE))
})
