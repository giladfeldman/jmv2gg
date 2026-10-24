test_that("generated figure code is readable: named objects, numbered steps, layer comments, captions (d-b89957)", {
  src <- 'jmv::ANOVA(formula = len ~ supp * dose, data = d, effectSize = "partEta")'
  code <- convert_code(src, engine = "ggplot2")$text
  # objects are named after the analysis, not tmp1/tmp2
  expect_match(code, "anova_1_plot <- ggplot2::ggplot(", fixed = TRUE)
  expect_match(code, "anova_1_means <-", fixed = TRUE)
  # numbered steps and a comment on each kind of layer
  for (step in c("# 1. Data", "# 2. Model means", "# 3. Positions", "# 4. The figure")) {
    expect_match(code, step, fixed = TRUE)
  }
  expect_match(code, "# estimated marginal means with 95% confidence intervals", fixed = TRUE)
  # every line fits a code window (no generated one-liners hundreds of characters wide)
  expect_lt(max(nchar(strsplit(code, "\n", fixed = TRUE)[[1]])), 200)
  # an R Markdown figure chunk carries a caption
  rmd <- paste0("```{r}\n", src, "\n```\n")
  out <- convert_rmd(rmd, engine = "ggplot2")$text
  expect_match(out, "[{]r jmv2gg-anova-1[^}]*fig[.]cap=")
  # control: the source chunk itself had no caption
  expect_false(grepl("fig.cap", rmd, fixed = TRUE))
})
