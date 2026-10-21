test_that("generated plot blocks appear in knitted HTML, not only saved files", {
  skip_if_not_installed("knitr");skip_if_not_installed("ragg")
  a<-inspect_code('jmv::descriptives(data=d,vars="y")')$analyses[[1]]
  code<-generate_analysis(a,"ggplot2",conversion_options(list(),list(dpi=72,width=3,height=2)))$code
  work<-tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  env<-new.env(parent=globalenv());env$d<-data.frame(y=1:30)
  doc<-paste0('```{r generated, echo=FALSE}\n',code,'\n```')
  rendered<-knitr::knit(text=doc,envir=env,quiet=TRUE)
  expect_match(rendered,'!\\[.*\\]\\(figure/generated-1[.]png\\)')
  expect_true(file.exists('figures/a0001-ggplot2-variable-1.png'))
})
