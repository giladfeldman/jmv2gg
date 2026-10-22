test_that("browser preview resolves generated functions in its restricted environment", {
  skip_if_not_installed("ragg");skip_if_not_installed("emmeans")
  work<-tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  request<-list(action="preview",mode="code",engine="ggplot2",source='jmv::ANOVA(data=d,dep="y",factors="x")',
    analysis_id="a0001",data_kind="simulate",n=30,figures=list(dpi=72,width=3,height=2))
  out<-jsonlite::fromJSON(browser_request(jsonlite::toJSON(request,auto_unbox=TRUE)))
  expect_identical(out$kind,"preview")
  expect_true(file.exists(out$files$path))
})

test_that("the browser scan request reports findings and the packages a document loads", {
  source <- paste("```{r}", "library(jmv)", "x <- ggplot2::ggplot()", "download.file('https://x.invalid', 'y')", "```", sep = "\n")
  out <- jsonlite::fromJSON(browser_request(jsonlite::toJSON(list(action = "scan", source = source), auto_unbox = TRUE)),
    simplifyVector = FALSE)
  expect_false(out$refused)
  expect_identical(out$findings[[1]]$code, "source_or_download")
  expect_setequal(unlist(out$packages), c("jmv", "ggplot2"))
})

test_that("the manifest lists the R packages the figures need", {
  out <- convert_code('jmv::ANOVA(data = d, dep = "y", factors = c("a", "b"))', engine = "ggplot2")
  expect_true(all(c("ggplot2", "ggdist", "emmeans") %in% out$manifest$packages))
  expect_false("BetterGG" %in% out$manifest$packages)
})
