test_that("alternative-analysis notes remain visible when code is folded", {
  out <- convert_rmd('```{r a}\njmv::ANOVA(data=d,dep="y",factors="x")\n```')
  expect_match(out$text,"> **Figure note:** BetterGG",fixed=TRUE)
})

test_that("original output choices do not duplicate chunk options", {
  out <- convert_rmd('```{r a, results="asis", echo=TRUE}\njmv::descriptives(data=d,vars="y")\n```',engine="ggplot2",original_output="hide")
  expect_identical(out$status,"complete")
  header <- strsplit(out$text,"\n",fixed=TRUE)[[1]]
  header <- header[grepl('^```\\{r a',header)]
  expect_length(gregexpr("results=",header,fixed=TRUE)[[1]],1L)
  expect_match(header,"echo=FALSE",fixed=TRUE)
})

test_that("pasted-code generation occurs before later data reassignment", {
  out <- convert_code('jmv::descriptives(data=d,vars="y")\nd <- other',engine="ggplot2")
  expect_true(regexpr('figure_save(descriptives_1_plot',out$text,fixed=TRUE)[[1]] < regexpr('d <- other',out$text,fixed=TRUE)[[1]])
})

test_that("developer docs do not claim BetterGG figures need native R (they render in the browser preview)", {
  root <- testthat::test_path("..", "..")
  docs <- file.path(root, c("CLAUDE.md", "LESSONS.md", "README.md", file.path("docs", c("DEPLOYMENT.md", "VALIDATION.md", "ARCHITECTURE.md"))))
  skip_if_not(all(file.exists(docs)), "source tree docs not available")
  text <- unlist(lapply(docs, readLines, warn = FALSE))
  expect_false(any(grepl("BetterGG previews (use|remain) native", text)))
  expect_true(any(grepl("Rmpfr", text, fixed = TRUE))) # the real limit stays documented
})
