anova_source <- 'jmv::ANOVA(data = d, dep = "trust_score", factors = c("framing", "default"), modelTerms = list("framing", "default", c("framing", "default")))'

anova_data <- function(per_cell = 8) {
  set.seed(4)
  d <- expand.grid(framing = c("Gain", "Loss", "Neutral"), default = c("Loss", "Neutral", "Gain"), rep = seq_len(per_cell))
  d$trust_score <- sample(1:7, nrow(d), replace = TRUE)
  d[c("framing", "default", "trust_score")]
}

test_that("variable names become tidy figure labels", {
  expect_identical(tidy_label("trust_score"), "Trust score")
  expect_identical(tidy_label("framing"), "Framing")
  expect_identical(tidy_label("Preference(continuous)"), "Preference (continuous)")
  expect_identical(tidy_label("soc.class"), "Soc class")
  expect_identical(tidy_label("Choice (Dichotomous)"), "Choice (Dichotomous)")
  expect_identical(tidy_label("age"), "Age")
})

test_that("the converted document starts with one editable block of figure labels", {
  out <- convert_code(anova_source, engine = "ggplot2")
  expect_match(out$text, "figure_labels <- c(", fixed = TRUE)
  expect_match(out$text, 'trust_score = "Trust score"', fixed = TRUE)
  expect_match(out$text, 'framing = "Framing"', fixed = TRUE)
  expect_match(out$text, "figure_level_labels <- list()", fixed = TRUE)
  expect_identical(out$manifest$labels,
    list(trust_score = "Trust score", framing = "Framing", default = "Default"))
  expect_silent(parse(text = out$text))
})

test_that("labels typed by the user and category labels are written into the block", {
  out <- convert_code(anova_source, engine = "ggplot2", style = list(
    label_text = list(framing = "Message framing", default = "Default option"),
    level_text = list(framing = list(Gain = "Gain frame", Neutral = "Neutral frame"))))
  expect_match(out$text, 'framing = "Message framing"', fixed = TRUE)
  expect_match(out$text, 'default = "Default option"', fixed = TRUE)
  expect_match(out$text, 'framing = c(Gain = "Gain frame", Neutral = "Neutral frame")', fixed = TRUE)
  expect_identical(out$manifest$labels$framing, "Message framing")
})

test_that("the names option keeps the column names on the figures", {
  out <- convert_code(anova_source, engine = "ggplot2", style = list(labels = "names"))
  expect_match(out$text, "figure_labels <- c()", fixed = TRUE)
  expect_error(convert_code(anova_source, style = list(labels = "fancy")), "labels must be")
  expect_error(convert_code(anova_source, style = list(label_text = list("x"))), "label_text")
  expect_error(convert_code(anova_source, style = list(level_text = list(framing = list(1)))), "level_text")
})

test_that("figure_relabel puts the labels into titles, legend titles, statistics lines and categories", {
  skip_if_not_installed("ggplot2")
  env <- new.env(parent = globalenv())
  eval(parse(text = figure_setup_code(conversion_options(list(
    level_text = list(framing = list(Gain = "Gain frame"))), list()), "ggplot2",
    labels = c(framing = "Message framing", default = "Default option", y_val = "Endorsement"))), envir = env)
  d <- data.frame(framing = factor(c("Gain", "Loss", "Gain", "Loss")), default = factor(c("x", "x", "y", "y")), y_val = 1:4)
  p <- ggplot2::ggplot(d, ggplot2::aes(framing, y_val, fill = default)) + ggplot2::geom_col() +
    ggplot2::geom_point(data = d) +
    ggplot2::guides(fill = ggplot2::guide_legend(title = "default")) +
    ggplot2::labs(x = "framing", subtitle = "framing × default: F(1, 2) = 3.00; defaults: 2",
      caption = "framing / default")
  q <- env$figure_relabel(p)
  labs <- ggplot2::get_labs(q)
  expect_identical(labs$x, "Message framing")
  expect_identical(labs$y, "Endorsement")
  expect_identical(labs$subtitle, "Message framing × Default option: F(1, 2) = 3.00; defaults: 2")
  expect_identical(labs$caption, "Message framing / Default option")
  expect_identical(q$guides$guides$fill$params$title, "Default option")
  expect_silent(ggplot2::ggplot_build(q))
  expect_identical(levels(q$data$framing), c("Gain frame", "Loss"))
  expect_identical(levels(q$layers[[2]]$data$framing), c("Gain frame", "Loss"))
  # the figure the user already had is unchanged
  expect_identical(levels(d$framing), c("Gain", "Loss"))
  expect_identical(p$guides$guides$fill$params$title, "default")
  expect_identical(env$figure_relabel("not a plot"), "not a plot")

  # tick labels fixed from levels(), and a combined "a / b" panel column
  d$x_position <- as.integer(d$framing)
  d[["framing / default"]] <- interaction(d[c("framing", "default")], sep = " / ", drop = TRUE)
  p2 <- ggplot2::ggplot(d, ggplot2::aes(x_position, y_val)) + ggplot2::geom_point() +
    ggplot2::scale_x_continuous(breaks = 1:2, labels = levels(d$framing)) +
    ggplot2::facet_wrap(ggplot2::vars(.data[["framing / default"]]))
  q2 <- env$figure_relabel(p2)
  expect_identical(ggplot2::ggplot_build(q2)$layout$panel_params[[1]]$x$get_labels(), c("Gain frame", "Loss"))
  expect_identical(levels(q2$data[["framing / default"]]), c("Gain frame / x", "Loss / x", "Gain frame / y", "Loss / y"))
  expect_identical(ggplot2::ggplot_build(p2)$layout$panel_params[[1]]$x$get_labels(), c("Gain", "Loss"))
})

test_that("generated figures carry the labels when they are drawn", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("emmeans")
  env <- run_generated(anova_source, anova_data())
  plot <- env[[grep("_plot$", ls(env), value = TRUE)[1]]]
  labs <- ggplot2::get_labs(plot)
  expect_identical(labs$x, "Framing")
  expect_identical(labs$y, "Trust score")
  expect_identical(labs$colour, "Default")
  expect_identical(labs$fill, "Default")
})

test_that("the converter reports the version in DESCRIPTION", {
  description <- if (file.exists("DESCRIPTION")) "DESCRIPTION" else test_path("..", "..", "DESCRIPTION")
  skip_if_not(file.exists(description), "DESCRIPTION is not next to the tests (installed package)")
  expect_identical(jmv2gg_version, unname(read.dcf(description, fields = "Version")[1, 1]))
})
