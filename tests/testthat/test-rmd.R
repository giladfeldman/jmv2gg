test_that("YAML parameters and original analyses survive conversion", {
  text <- paste(c('---','title: Test','params:','  data: sample.sav','output:','  html_document:','    toc_depth: 2','---',
    '## Result','```{r source}','res <- jmv::ANOVA(data=d, dep="y", factors="x", modelTerms=list("x"))','res','```'),collapse='\n')
  out <- convert_rmd(text,engine="ggplot2")
  expect_identical(out$status,"complete")
  expect_match(out$text,"sample.sav",fixed=TRUE)
  expect_match(out$text,"toc_depth: 3",fixed=TRUE)
  expect_match(out$text,'res <- jmv::ANOVA',fixed=TRUE)
  expect_match(out$text,'.jmv2gg_input_a0001 <- d',fixed=TRUE)
  expect_identical(convert_rmd(out$text)$text,out$text)
})

test_that("YAML expressions never execute during conversion", {
  marker <- tempfile()
  text <- paste0('---\nx: !expr writeLines("bad", ',encodeString(marker,quote='"'),')\n---\ntext')
  out <- convert_rmd(text)
  expect_false(file.exists(marker))
  expect_match(out$text,'!expr',fixed=TRUE)
})

test_that("disabled source chunks stay disabled", {
  text <- '```{r example, eval=FALSE}\njmv::descriptives(data=d, vars="y")\n```'
  out <- convert_rmd(text,engine="ggplot2")
  expect_match(out$text,'cache=FALSE, eval=FALSE',fixed=TRUE)
})
