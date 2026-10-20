test_that("conversion does not execute expressions", {
  marker <- tempfile()
  code <- paste0('jmv::ANOVA(data=d, dep="y", factors={writeLines("bad", ',
    encodeString(marker, quote='"'), '); "x"})')
  out <- convert_code(code)
  expect_false(file.exists(marker))
  expect_identical(out$status, "failed")
})

test_that("the real source call shapes are inventoried and converted", {
  code <- 'res_102 <- jmv::ANOVA(data=d, dep="Preference(continuous)", factors="group", modelTerms=list("group"), ss="3")'
  out <- convert_code(code, engine="ggplot2")
  expect_identical(out$status, "complete")
  expect_length(out$analyses, 1)
  expect_match(out$text, "res_102 <-", fixed=TRUE)
  expect_match(out$text, "Preference(continuous)", fixed=TRUE)
  expect_match(out$text, "ggplot2::ggsave", fixed=TRUE)
  expect_silent(parse(text=out$text))
})

test_that("empty input and malformed code are never false successes", {
  expect_identical(convert_code("")$status, "failed")
  expect_identical(convert_code("jmv::ANOVA(")$status, "failed")
  expect_identical(convert_code("# jmv::ANOVA(data=d)")$manifest$detected, 0L)
  expect_error(convert_code("", style=list(typo=TRUE)), "Unknown")
})
