test_that("many-category BetterGG figures keep every category as horizontal percentage bars", {
  skip_if_not_installed("BetterGG");skip_if_not_installed("ragg")
  code<-generated_code('jmv::descriptives(data=d,vars="category")',engine="bettergg",figures=list(dpi=72,width=7.2,height=5.4))
  env<-new.env(parent=globalenv())
  env$d<-data.frame(category=factor(rep(sprintf("Long category %02d",1:51),1:51)))
  work<-tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  eval(parse(text=code),envir=env)
  p<-env$descriptives_1_bettergg
  expect_equal(nrow(ggplot2::ggplot_build(p)$data[[1]]),51L)
  expect_s3_class(p$coordinates,"CoordFlip")
  expect_false(any(vapply(p$layers,function(layer)inherits(layer$geom,c("GeomLabel","GeomLabelRepel")),logical(1))))
  expect_gt(file.info('figures/descriptives_1-bettergg.png')$size,1000)
})

test_that("many-category ggplot2 figures keep every category as horizontal percentage bars", {
  skip_if_not_installed("ragg");skip_if_not_installed("png")
  d<-data.frame(category=factor(rep(sprintf("Long category %02d",1:51),1:51)))
  env<-run_generated('jmv::descriptives(data=d,vars="category")',d,figures=list(dpi=72,width=7.2,height=5.4))
  built<-ggplot2::ggplot_build(env$descriptives_1_plot)
  expect_equal(nrow(built$data[[1]]),51L)
  expect_equal(sort(built$data[[1]]$y),sort(100*(1:51)/sum(1:51)))
  expect_s3_class(env$descriptives_1_plot$coordinates,"CoordFlip")
  # the saved figure is taller so 51 bars and their names do not overlap: 0.15 in per bar (7.65 in; at most 9 in)
  png_size<-function(path)dim(png::readPNG(path))[1:2]
  near<-function(actual,expected)expect_true(all(abs(actual-expected)<=1.5),info=paste(actual,collapse="x"))
  near(png_size(file.path(env$.work,"figures/descriptives_1-ggplot2.png")),c(0.15*51*72,7.2*72))
  # few categories keep the chosen height
  few<-data.frame(category=factor(rep(c("a","b","c"),c(3,5,7))))
  env2<-run_generated('jmv::descriptives(data=few,vars="category")',few,figures=list(dpi=72,width=7.2,height=5.4))
  near(png_size(file.path(env2$.work,"figures/descriptives_1-ggplot2.png")),c(5.4*72,7.2*72))
})
