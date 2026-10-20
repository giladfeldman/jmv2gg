test_that("explicit model terms are preserved without adding interactions", {
  code <- 'jmv::ANOVA(data=d, dep="y", factors=c("a","b"), modelTerms=list("a","b"))'
  out <- convert_code(code,engine="ggplot2")
  expect_match(out$text,'`y` ~ `a` + `b`',fixed=TRUE)
  expect_false(grepl('stats::lm\\(`y` ~ `a` \\*',out$text))
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
  a <- inspect_code('jmv::descriptives(data=d, vars=c("one","two"))')$analyses[[1]]
  generated <- generate_analysis(a,"ggplot2",conversion_options(list(),list(dpi=72,width=3,height=2)))
  work <- tempfile(); dir.create(work)
  old <- setwd(work); on.exit(setwd(old))
  d <- data.frame(one=seq_len(30),two=factor(rep(c("a","b"),15)))
  expect_silent(eval(parse(text=generated$code),envir=environment()))
  expect_length(list.files("figures",pattern="png$"),2)
})

test_that("Pearson mapping does not turn nominal codes into invented correlations", {
  skip_if_not_installed("ggplot2"); skip_if_not_installed("ragg")
  a <- inspect_code('jmv::corrMatrix(data=d, vars=c("nominal","numeric","mapped"))')$analyses[[1]]
  generated <- generate_analysis(a,"ggplot2",conversion_options(list(),list(dpi=72,width=3,height=2)))
  d <- data.frame(nominal=factor(rep(c("a","b"),15)),numeric=1:30,mapped=factor(rep(c("a","b"),15)))
  attr(d$mapped,"values") <- c(0,1)
  work <- tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  eval(parse(text=generated$code),envir=environment())
  mat <- get(".jmv2gg_a0001_correlations",inherits=FALSE)
  expect_true(all(is.na(mat["nominal",])))
  expect_equal(mat["mapped","numeric"],stats::cor(c(0,1)[as.integer(d$mapped)],d$numeric))
})
