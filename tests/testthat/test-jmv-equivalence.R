test_that("logistic coefficients preserve event coding, reference levels and weights", {
  skip_if_not_installed("jmv"); skip_if_not_installed("ragg")
  d <- data.frame(y=factor(rep(c("no","yes","no","no","yes"),20)),
    a=factor(rep(c("A","A","B","B"),25)),z=sin(1:100))
  attr(d,"jmv-weights") <- rep(c(1,2),50)
  original <- jmv::logRegBin(data=d,dep="y",factors="a",covs="z",blocks=list(list("a","z")),
    refLevels=list(list(var="y",ref="yes"),list(var="a",ref="B")))
  expected <- original$models[[1]]$coef$asDF$est
  expected <- expected[!is.na(expected)]
  env <- run_generated('jmv::logRegBin(data=d,dep="y",factors="a",covs="z",blocks=list(list("a","z")),refLevels=list(list(var="y",ref="yes"),list(var="a",ref="B")))',d)
  actual <- stats::coef(env$logistic_1_model)
  expect_equal(unname(actual),expected,tolerance=1e-10)
})

test_that("ANOVA means preserve explicit additive model terms", {
  skip_if_not_installed("jmv");skip_if_not_installed("emmeans");skip_if_not_installed("ragg")
  d <- data.frame(y=sin(1:40)+(1:40)/10,a=factor(rep(c("A","A","B","B"),10)),b=factor(rep(c("Q","R"),20)))
  env <- run_generated('jmv::ANOVA(data=d,dep="y",factors=c("a","b"),modelTerms=list("a","b"))',d)
  expected <- stats::predict(stats::lm(y~a+b,data=d),newdata=expand.grid(a=levels(d$a),b=levels(d$b)))
  expect_equal(env$anova_1_means$emmean,as.numeric(expected),tolerance=1e-10)
})

test_that("mapped factor outcomes use stored values instead of factor indexes", {
  skip_if_not_installed("ragg");skip_if_not_installed("emmeans")
  d<-data.frame(y=factor(rep(c("no","yes","yes","no","yes"),20)),x=factor(rep(c("a","b"),50)))
  attr(d$y,"values")<-c(0,1)
  expected<-tapply(c(0,1)[as.integer(d$y)],d$x,mean)
  env<-run_generated('jmv::ANOVA(data=d,dep="y",factors="x")',d)
  expect_equal(env$anova_1_means$emmean,as.numeric(expected),tolerance=1e-10)
  expect_identical(d$y,factor(rep(c("no","yes","yes","no","yes"),20)) |> structure(values=c(0,1)))
})
