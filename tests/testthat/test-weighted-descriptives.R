test_that("descriptive frequency plots preserve case-weighted counts", {
  skip_if_not_installed("ragg")
  d<-data.frame(y=factor(c("a","b","b")))
  attr(d,"jmv-weights")<-c(5,1,2)
  env<-run_generated('jmv::descriptives(data=d,vars="y")',d)
  counts<-ggplot2::ggplot_build(env$.jmv2gg_a0001_ggplot2_variable_1)$data[[1]]$count
  expect_equal(counts,c(5,3))
})

test_that("numeric histograms preserve total case weight", {
  skip_if_not_installed("ragg")
  d<-data.frame(y=c(1,2,3));attr(d,"jmv-weights")<-c(5,1,2)
  env<-run_generated('jmv::descriptives(data=d,vars="y")',d)
  counts<-ggplot2::ggplot_build(env$.jmv2gg_a0001_ggplot2_variable_1)$data[[1]]$count
  expect_equal(sum(counts),8)
})

test_that("weighted correlations are rejected rather than substituted", {
  skip_if_not_installed("ragg")
  d<-data.frame(x=1:10,y=sin(1:10));attr(d,"jmv-weights")<-rep(2,10)
  expect_error(run_generated('jmv::corrMatrix(data=d,vars=c("x","y"))',d),"Weighted correlation mapping is unavailable",fixed=TRUE)
})
