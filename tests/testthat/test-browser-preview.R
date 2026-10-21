test_that("browser preview resolves generated functions in its restricted environment", {
  skip_if_not_installed("ragg");skip_if_not_installed("emmeans")
  work<-tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  request<-list(action="preview",mode="code",engine="ggplot2",source='jmv::ANOVA(data=d,dep="y",factors="x")',
    analysis_id="a0001",data_kind="simulate",n=30,figures=list(dpi=72,width=3,height=2))
  out<-jsonlite::fromJSON(browser_request(jsonlite::toJSON(request,auto_unbox=TRUE)))
  expect_identical(out$kind,"preview")
  expect_true(file.exists(out$files$path))
})
