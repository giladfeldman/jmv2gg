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

test_that("styling the generated code never loads styler into the converting session", {
  # skip_if_not_installed() would load styler (and R.utils) into this session
  skip_if(!nzchar(system.file(package = "styler")) || !nzchar(system.file(package = "callr")), "styler or callr not installed")
  skip_if("R.utils" %in% loadedNamespaces(), "R.utils was already loaded by another test")
  out <- convert_code('jmv::descriptives(data = d, vars = "y")', engine = "ggplot2")
  expect_false("styler" %in% loadedNamespaces())
  expect_false("R.utils" %in% loadedNamespaces())
  expect_false(any(vapply(out$diagnostics, function(x) x$code == "styler_unavailable", logical(1))))
  lines <- strsplit(out$text, "\n", fixed = TRUE)[[1]]
  restyled <- callr::r(function(x) as.character(styler::style_text(x)), args = list(x = lines))
  expect_identical(restyled, lines)
})

test_that("T and F are read as TRUE and FALSE in literal arguments", {
  out <- convert_code("ggstatsplot::ggbetweenstats(data = d, x = g, y = y, results.subtitle = F)", engine = "ggplot2")
  expect_identical(out$status, "complete")
  expect_identical(literal(quote(T)), TRUE)
  expect_error(literal(quote(other)), "Dynamic argument")
})

test_that("the setup block reports pinned web-app versions for packages that are not installed", {
  lock <- tempfile(fileext = ".dcf")
  writeLines(c("Package: notapkgxyz", "Version: 1.2.3", "", "Package: ggplot2", "Version: 9.9.9"), lock)
  versions <- locked_versions(lock)
  expect_identical(unname(versions["notapkgxyz"]), "1.2.3")
  expect_identical(package_version_text("notapkgxyz", versions), "notapkgxyz 1.2.3 (pinned version of the jmv2gg web app)")
  expect_identical(package_version_text("notapkgxyz2", versions), "notapkgxyz2 (not installed where this was converted)")
  # An installed package reports its own version, not the lock's
  expect_identical(package_version_text("jsonlite", versions), paste("jsonlite", utils::packageVersion("jsonlite")))
  expect_identical(locked_versions(tempfile()), character())
})

test_that("figure notes disclose plot types and pairwise comparisons the figure does not draw", {
  flat <- function(out) gsub("[ \t]*\n#[ \t]*", " ", out$text)
  out <- convert_code('jmv::descriptives(data = d, vars = "y", box = TRUE, violin = TRUE)', engine = "ggplot2")
  expect_match(flat(out), "the source asked jamovi for box, violin plots", fixed = TRUE)
  expect_match(flat(convert_code('jmv::descriptives(data = d, vars = "y")', engine = "ggplot2")),
    "Differs from jamovi: nothing known.", fixed = TRUE)
  src <- 'ggstatsplot::ggbetweenstats(data = d, x = g, y = y, pairwise.display = "all")'
  expect_match(flat(convert_code(src, engine = "ggplot2")), "draws none because statistics on figures are off", fixed = TRUE)
  expect_match(flat(convert_code(src, engine = "ggplot2", style = list(stats = TRUE))), "showed all pairwise comparisons; the ggplot2 figure draws only the significant ones", fixed = TRUE)
  # ggstatsplot 1.1.3, checked on drawn plots: "none" draws no comparisons, an unknown word such as "everything"
  # draws all, and the retired pairwise.comparisons = FALSE is ignored (comparisons drawn; before 0.12.0 none).
  style <- list(stats = TRUE)
  expect_false(grepl("pairwise comparisons", flat(convert_code('ggstatsplot::ggbetweenstats(data = d, x = g, y = y, pairwise.display = "none")',
    engine = "ggplot2")), fixed = TRUE))
  expect_match(flat(convert_code('ggstatsplot::ggbetweenstats(data = d, x = g, y = y, pairwise.display = "everything")', engine = "ggplot2", style = style)),
    "showed all pairwise comparisons", fixed = TRUE)
  expect_false(grepl("pairwise comparisons", flat(convert_code(sub('"all"', '"significant"', src, fixed = TRUE), engine = "ggplot2", style = style)), fixed = TRUE))
  retired <- flat(convert_code('ggstatsplot::ggbetweenstats(data = d, x = g, y = y, pairwise.comparisons = FALSE)', engine = "ggplot2", style = style))
  expect_match(retired, "ggstatsplot before 0.12.0 then showed no pairwise comparisons, while 0.12.0 and later ignore it and show the significant ones; the ggplot2 figure draws only the significant ones.", fixed = TRUE)
  within <- convert_code('ggstatsplot::ggwithinstats(data = d, x = g, y = y, subject.id = id)', engine = "ggplot2")
  expect_match(flat(within), "showed the significant pairwise comparisons; the ggplot2 figure draws none", fixed = TRUE)
})
