test_that("explicit model terms are preserved without adding interactions", {
  code <- 'jmv::ANOVA(data=d, dep="y", factors=c("a","b"), modelTerms=list("a","b"))'
  out <- convert_code(code,engine="ggplot2")
  expect_match(out$text,'stats::lm(y ~ a + b,',fixed=TRUE)
  expect_false(grepl('stats::lm(y ~ a * b',out$text,fixed=TRUE))
})

test_that("formula code cannot execute in preview", {
  out <- convert_code('jmv::ANOVA(data=d, formula=y ~ system("touch bad"))',engine="ggplot2")
  expect_identical(out$status,"failed")
  expect_match(out$diagnostics[[1]]$message,"computed expression")
})

test_that("transport carries diagnostics and does not evaluate source", {
  json <- jsonlite::toJSON(list(source='jmv::descriptives(data=d, vars="y")',engine="ggplot2"),auto_unbox=TRUE)
  out <- jsonlite::fromJSON(browser_request(json),simplifyVector=FALSE)
  expect_identical(out$status,"complete")
  expect_identical(out$analyses[[1]]$function_name,"descriptives")
})

test_that("multi-variable plot names are valid R bindings and execute", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("ragg")
  d <- data.frame(one=seq_len(30),two=factor(rep(c("a","b"),15)))
  env <- NULL
  expect_silent(env <- run_generated('jmv::descriptives(data=d, vars=c("one","two"))', d))
  expect_setequal(list.files(file.path(env$.work, "figures"), pattern="png$"),
    c("descriptives_1-ggplot2-one.png", "descriptives_1-ggplot2-two.png"))
  expect_s3_class(env$descriptives_1_1_plot, "ggplot")
  expect_s3_class(env$descriptives_1_2_plot, "ggplot")
})

test_that("Pearson mapping does not turn nominal codes into invented correlations", {
  skip_if_not_installed("ggplot2"); skip_if_not_installed("ragg")
  d <- data.frame(nominal=factor(rep(c("a","b"),15)),numeric=1:30,mapped=factor(rep(c("a","b"),15)))
  attr(d$mapped,"values") <- c(0,1)
  env <- run_generated('jmv::corrMatrix(data=d, vars=c("nominal","numeric","mapped"))', d)
  cells <- env$correlation_1_cells
  expect_true(all(is.na(cells$r[cells$Var1 == "nominal" | cells$Var2 == "nominal"])))
  expect_equal(cells$r[cells$Var1 == "numeric" & cells$Var2 == "mapped"], stats::cor(c(0,1)[as.integer(d$mapped)],d$numeric))
})
