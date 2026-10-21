test_that("many-category BetterGG figures retain categories without overlapping slice labels", {
  skip_if_not_installed("BetterGG");skip_if_not_installed("ragg")
  a<-inspect_code('jmv::descriptives(data=d,vars="category")')$analyses[[1]]
  code<-generate_analysis(a,"bettergg",conversion_options(list(),list(dpi=72,width=7.2,height=5.4)))$code
  env<-new.env(parent=globalenv())
  env$d<-data.frame(category=factor(rep(sprintf("Long category %02d",1:51),1:51)))
  work<-tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  eval(parse(text=code),envir=env)
  p<-env$.jmv2gg_a0001_bettergg_variable_1_plot
  expect_equal(length(unique(p$data$value)),51L)
  expect_false(any(vapply(p$layers,function(layer)inherits(layer$geom,c("GeomLabel","GeomLabelRepel")),logical(1))))
  expect_gt(file.info('figures/a0001-bettergg-variable-1.png')$size,1000)
})
