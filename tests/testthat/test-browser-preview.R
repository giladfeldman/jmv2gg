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

test_that("a browser conversion asked for progress reports each R chunk as it starts", {
  source <- paste("---", "title: t", "---", "", "```{r}", "x <- 1", "```", "",
    "```{r second}", 'jmv::descriptives(data = d, vars = "y")', "```", sep = "\n")
  request <- list(action = "convert", mode = "rmd", engine = "ggplot2", source = source, progress = TRUE,
    style = list(styler = FALSE))
  messages <- character()
  out <- withCallingHandlers(browser_request(jsonlite::toJSON(request, auto_unbox = TRUE)),
    message = function(m) { messages <<- c(messages, conditionMessage(m)); invokeRestart("muffleMessage") })
  expect_identical(trimws(grep("^jmv2gg-progress ", messages, value = TRUE)),
    c("jmv2gg-progress 1 2 chunk", "jmv2gg-progress 2 2 chunk"))
  expect_false(isTRUE(getOption("jmv2gg.progress")))
  # Without the request flag nothing is written.
  request$progress <- NULL
  expect_silent(browser_request(jsonlite::toJSON(request, auto_unbox = TRUE)))
})

test_that("the identifier scan gives the same names for a long document not marked UTF-8", {
  text <- paste(rep("café <- jmv::descriptives(data = d, vars = 'y') # naïve", 400), collapse = "\n")
  native <- text; Encoding(native) <- "unknown"
  expected <- unique(unlist(regmatches(strsplit(text, "\n")[[1]], gregexpr("[A-Za-z.][A-Za-z0-9._]*", strsplit(text, "\n")[[1]]))))
  got <- unique(regmatches(native, gregexpr("[A-Za-z.][A-Za-z0-9._]*", native, useBytes = TRUE))[[1]])
  expect_setequal(got, expected)
})

test_that("the browser skips styler for large generated code, with a note giving the reason", {
  small <- list(setup = paste(rep("x <- 1", 10), collapse = "\n"))
  expect_null(styler_skip_note(small))
  large <- list(setup = paste(rep("x <- 1", 1500), collapse = "\n"), a = paste(rep("y <- 2", 600), collapse = "\n"))
  note <- styler_skip_note(large)
  expect_identical(note$code, "styler_skipped_large")
  expect_match(note$message, "2,100 lines", fixed = TRUE)
  expect_match(note$message, "about 2 min more", fixed = TRUE)
  expect_match(note$message, "styler::style_file()", fixed = TRUE)
  # Native R is not limited: style_generated() checks the size only on the WebR platform.
  # Not skip_if_not_installed(): loading styler here loads R.utils, which breaks jmv's options (LESSONS.md).
  skip_if(!nzchar(system.file(package = "styler")), "styler is not installed")
  options <- conversion_options(list(styler = TRUE), list())
  expect_identical(style_generated(large, options)$diagnostics, list())
})
