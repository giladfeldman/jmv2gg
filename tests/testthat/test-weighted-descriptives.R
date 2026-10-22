test_that("descriptive frequency plots preserve case-weighted counts", {
  skip_if_not_installed("ragg")
  d<-data.frame(y=factor(c("a","b","b")))
  attr(d,"jmv-weights")<-c(5,1,2)
  env<-run_generated('jmv::descriptives(data=d,vars="y")',d)
  expect_equal(env$descriptives_1_cells$counts,c(5,3))
})

test_that("numeric histograms preserve total case weight", {
  skip_if_not_installed("ragg")
  d<-data.frame(y=c(1,2,3));attr(d,"jmv-weights")<-c(5,1,2)
  env<-run_generated('jmv::descriptives(data=d,vars="y")',d)
  counts<-ggplot2::ggplot_build(env$descriptives_1_plot)$data[[1]]$count
  expect_equal(sum(counts),8)
  expect_equal(env$descriptives_1_centre,stats::weighted.mean(d$y,c(5,1,2)))
})

test_that("weighted correlations are rejected rather than substituted", {
  skip_if_not_installed("ragg")
  d<-data.frame(x=1:10,y=sin(1:10));attr(d,"jmv-weights")<-rep(2,10)
  # Refused visibly: the report keeps knitting, but no substitute figure is drawn.
  env<-NULL
  expect_warning(env<-run_generated('jmv::corrMatrix(data=d,vars=c("x","y"))',d),"Weighted correlation mapping is unavailable",fixed=TRUE)
  expect_false(exists("correlation_1_plot",envir=env,inherits=FALSE))
})

test_that("a refused analysis draws no figure file", {
  skip_if_not_installed("ragg")
  d<-data.frame(x=1:10,y=sin(1:10));attr(d,"jmv-weights")<-rep(2,10)
  env<-suppressWarnings(run_generated('jmv::corrMatrix(data=d,vars=c("x","y"))',d))
  expect_length(list.files(file.path(env$.work,"figures"),pattern="png$"),0L)
})
