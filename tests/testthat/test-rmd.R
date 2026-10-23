test_that("YAML parameters and original analyses survive conversion", {
  text <- paste(c('---','title: Test','params:','  data: sample.sav','output:','  html_document:','    toc_depth: 2','---',
    '## Result','```{r source}','res <- jmv::ANOVA(data=d, dep="y", factors="x", modelTerms=list("x"))','res','```'),collapse='\n')
  out <- convert_rmd(text,engine="ggplot2")
  expect_identical(out$status,"complete")
  expect_match(out$text,"sample.sav",fixed=TRUE)
  expect_match(out$text,"toc_depth: 3",fixed=TRUE)
  expect_match(out$text,'res <- jmv::ANOVA',fixed=TRUE)
  expect_match(out$text,'anova_1_input <- d # data for the jmv2gg figures of anova_1',fixed=TRUE)
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

test_that("a figure chunk with many captions keeps its header on one line, so knitr runs it", {
  vars <- paste0("item_with_a_long_descriptive_name_", 1:14)
  source <- paste("---", "title: t", "---", "", "```{r}",
    paste0("jmv::descriptives(data = d, vars = c(", paste0('"', vars, '"', collapse = ", "), "))"), "```", sep = "\n")
  out <- convert_rmd(source, engine = "both", style = list(styler = FALSE))
  lines <- strsplit(out$text, "\n", fixed = TRUE)[[1]]
  header <- grep("^```[{]r jmv2gg-descriptives", lines, value = TRUE)
  expect_length(header, 1L)
  expect_match(header, "cache=FALSE}$")
  expect_gt(nchar(header), 1000L)
  # knitr extracts the figure code only from a chunk it recognises.
  rmd <- tempfile(fileext = ".Rmd"); r <- tempfile(fileext = ".R")
  writeLines(out$text, rmd)
  knitr::purl(rmd, output = r, quiet = TRUE, documentation = 0L)
  expect_true(any(grepl("descriptives_1: jmv::descriptives", readLines(r), fixed = TRUE)))
})
