# Descriptives, categorical tables, correlations, regressions, reliability.

# One-sample t-test (and gghistostats): histogram with the test value.
map_histogram <- function(ctx) {
  a <- ctx$a
  if (ctx$fn == "gghistostats") {
    x <- arg_variable(a, "x")
    if (length(x) != 1L) stop("gghistostats needs one x column.")
    prep_input(ctx)
    prep_columns(ctx, x)
    prep_numeric(ctx, x)
    ctx$describe <- paste0("the distribution of ", x, " with its centre marked.")
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_histostats", data = ctx$input, x = x, name = ctx$name, type = arg_value(a, "type", "parametric"),
        stats = ctx$stats, test.value = arg_value(a, "test.value", 0), conf.level = ctx$level,
        binwidth = arg_value(a, "binwidth"), xlab = arg_value(a, "xlab", x), title = arg_value(a, "title"))
      add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), paste0("Distribution of ", x, "."),
        packages = if (ctx$stats) "statsExpressions")
    }
    return(add_bettergg_source(ctx))
  }
  vars <- arg_variable(a, "vars")
  test_value <- as.numeric(arg_value(a, "testValue", 0))
  students <- isTRUE(arg_value(a, "students", TRUE))
  wilcoxon <- isTRUE(arg_value(a, "wilcoxon", FALSE))
  type <- if (!students && wilcoxon) "nonparametric" else "parametric"
  hypothesis <- arg_value(a, "hypothesis", "dt")
  if (!identical(hypothesis, "dt") && ctx$stats) {
    add_note(ctx, "The figure's one-sample test is two-sided; the source tests a one-sided hypothesis.", code = "statistics_not_shown")
  }
  prep_input(ctx)
  prep_columns(ctx, vars)
  prep_refuse_weights(ctx, "one-sample t-test")
  prep_numeric(ctx, vars)
  ctx$describe <- paste0("the distribution of each outcome with its ", if (type == "parametric") "mean" else "median",
    " marked; the test value is ", test_value, ".")
  if (ctx$stats) ctx$differs <- c(ctx$differs, if (type == "parametric")
    "the subtitle gives Hedges' g; jamovi reports Cohen's d." else "the subtitle is the Wilcoxon signed-rank test.")
  for (i in seq_along(vars)) {
    v <- vars[i]
    fig <- if (length(vars) > 1L) paste0(ctx$name, "_", i) else ctx$name
    suffix <- if (length(vars) > 1L) v
    caption <- paste0("Distribution of ", v, " (test value ", test_value, ").")
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_histostats", data = ctx$input, x = v, name = fig, type = type,
        stats = ctx$stats && identical(hypothesis, "dt"), test.value = test_value, conf.level = ctx$level)
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), caption, suffix = suffix,
        packages = if (ctx$stats) "statsExpressions")
    }
    if (wants(ctx, "bettergg")) {
      code <- c(paste0(fig, "_bettergg <- BetterGG::gghistostats("),
        paste0("  data = ", ctx$input, ", x = ", r_sym(v), ", test.value = ", test_value, ", type = ", q(type), ","),
        paste0("  conf.level = ", ctx$level, ", results.subtitle = ", if (ctx$stats) "TRUE" else "FALSE", ", bf.message = FALSE"), ")")
      add_figure(ctx, "bettergg", code, paste0(fig, "_bettergg"), caption, suffix = suffix, packages = "BetterGG")
    }
  }
}

# Descriptives: a histogram for numeric variables, a pie for categories.
map_descriptives <- function(ctx) {
  a <- ctx$a
  vars <- arg_variable(a, "vars")
  if (!length(vars)) stop("No descriptive variables supplied.")
  split <- arg_variable(a, "splitBy", character())
  prep_input(ctx)
  prep_columns(ctx, c(vars, split))
  w <- prep_weights(ctx)
  prep_labelled_to_factor(ctx, c(vars, split))
  weight_column <- paste0(ctx$name, "_case_weight")
  add_prep(ctx, paste0(ctx$input, "[[", q(weight_column), "]] <- ", w))
  panel <- NULL
  if (length(split)) {
    panel <- if (length(split) == 1L) split else paste(split, collapse = " / ")
    if (length(split) > 1L) {
      add_prep(ctx, paste0("# One panel per combination of ", paste(split, collapse = ", "), "."),
        paste0(ctx$input, "[[", q(panel), "]] <- interaction(", ctx$input, "[", r_text(split), "], sep = \" / \", drop = TRUE)"))
    }
  }
  ctx$describe <- paste0("for each variable, a histogram (numeric) or pie chart (categories) of the ",
    "case-weighted counts", if (length(split)) paste0(", split by ", paste(split, collapse = " and ")) else "", ".")
  for (i in seq_along(vars)) {
    v <- vars[i]
    fig <- if (length(vars) > 1L) paste0(ctx$name, "_", i) else ctx$name
    suffix <- if (length(vars) > 1L) v
    numeric_test <- paste0("is.numeric(", ctx$input, "[[", q(v), "]])")
    if (wants(ctx, "ggplot2")) {
      histo <- recipe("recipe_histostats", data = ctx$input, x = v, name = fig, weights = weight_column, facet = panel)
      categories <- if (is.null(panel)) {
        recipe("recipe_piestats", data = ctx$input, x = v, name = fig, weights = weight_column, max_labels = 12)
      } else {
        recipe("recipe_barstats", data = ctx$input, x = v, y = panel, name = fig, weights = weight_column)
      }
      code <- c(paste0("if (", numeric_test, ") {"), indent(histo), "} else {", indent(categories), "}")
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), paste0("Distribution of ", v, "."), suffix = suffix)
    }
    if (wants(ctx, "bettergg")) {
      bd <- paste0(fig, "_bettergg")
      code <- c(paste0("if (", numeric_test, ") {"),
        paste0("  ", bd, " <- BetterGG::gghistostats(data = ", ctx$input, ", x = ", r_sym(v),
          ", results.subtitle = FALSE, bf.message = FALSE)"),
        "} else {",
        paste0("  ", bd, "_levels <- nlevels(factor(", ctx$input, "[[", q(v), "]]))"),
        paste0("  ", bd, " <- BetterGG::ggpiestats("),
        paste0("    data = ", ctx$input, ", x = ", r_sym(v), ", results.subtitle = FALSE, bf.message = FALSE,"),
        paste0("    palette = if (", bd, "_levels <= 8L) \"ggsci::default_nejm\" else \"palettesForR::Named\""),
        "  ) +",
        "    ggplot2::guides(fill = ggplot2::guide_legend(ncol = 4, byrow = TRUE)) +",
        "    ggplot2::theme(legend.position = \"bottom\", legend.text = ggplot2::element_text(size = 6))",
        "  # Keep every category in the legend; omit overlapping slice labels above 12 categories.",
        paste0("  if (", bd, "_levels > 12L) {"),
        paste0("    ", bd, "$layers <- Filter(function(layer) !inherits(layer$geom, c(\"GeomLabel\", \"GeomLabelRepel\")), ", bd, "$layers)"),
        "  }",
        "}")
      add_figure(ctx, "bettergg", code, bd, paste0("Distribution of ", v, " (BetterGG)."), suffix = suffix, packages = "BetterGG")
    }
  }
  if (wants(ctx, "bettergg")) {
    add_note(ctx, paste("The BetterGG descriptive plot does not apply case weights.",
      if (length(split)) "It pools the splitBy groups; the ggplot2 figure keeps them." else ""))
  }
}

# Contingency tables and proportion tests: stacked bars or pies.
map_categorical <- function(ctx) {
  a <- ctx$a
  fn <- ctx$fn
  if (fn %in% c("ggbarstats", "ggpiestats")) return(map_gg_categorical(ctx))
  rows <- arg_variable(a, "rows", arg_variable(a, "var", arg_variable(a, "vars")))
  cols <- arg_variable(a, "cols", character())
  counts <- arg_variable(a, "counts", character())
  layers <- arg_variable(a, "layers", character())
  if (!length(rows)) stop("Categorical plot needs row variables.")
  if (fn %in% c("contTables", "contTablesPaired") && (length(rows) != 1L || length(cols) != 1L))
    stop("Use one rows and one cols variable per contingency table.")
  if (length(layers) > 1L) stop("Figures cover one layer variable.")
  prep_input(ctx)
  prep_columns(ctx, c(rows, cols, counts, layers))
  w <- prep_weights(ctx)
  prep_factor(ctx, c(rows, cols, layers))
  weight_column <- paste0(ctx$name, "_case_weight")
  add_prep(ctx, paste0(ctx$input, "[[", q(weight_column), "]] <- ", w))
  weighted_test <- paste0("any(", w, " != 1)")
  paired <- fn == "contTablesPaired"
  stats_ok <- ctx$stats && !length(layers)
  if (ctx$stats && length(layers)) add_note(ctx, "Statistics are not drawn on layered tables.", code = "statistics_not_shown")
  if (ctx$stats && stats_ok) {
    ctx$differs <- c(ctx$differs, switch(fn,
      contTables = "the subtitle is Pearson's chi-squared test with Cramer's V (as jamovi's default).",
      contTablesPaired = "the subtitle is McNemar's test.",
      propTest2 = "the subtitle is a chi-squared goodness-of-fit test; jamovi's propTest2 uses a binomial test.",
      propTestN = "the subtitle tests equal proportions; check the source's expected proportions."))
    add_prep(ctx, paste0("if (", weighted_test, ") stop(\"Statistics on the figure need unweighted data; draw it with stats = FALSE.\")"))
  }
  two_way <- length(cols) == 1L
  for (i in seq_along(rows)) {
    r <- rows[i]
    fig <- if (length(rows) > 1L) paste0(ctx$name, "_", i) else ctx$name
    suffix <- if (length(rows) > 1L) r
    caption <- if (two_way) paste0(r, " within each level of ", cols, ".") else paste0("Proportions of ", r, ".")
    if (wants(ctx, "ggplot2")) {
      code <- if (two_way) {
        recipe("recipe_barstats", data = ctx$input, x = r, y = cols, name = fig, counts = if (length(counts)) counts,
          stats = stats_ok, paired = paired, weights = if (!stats_ok) weight_column, facet = if (length(layers)) layers)
      } else {
        recipe("recipe_piestats", data = ctx$input, x = r, name = fig, counts = if (length(counts)) counts,
          stats = stats_ok, weights = if (!stats_ok) weight_column, max_labels = 12)
      }
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), caption, suffix = suffix,
        packages = if (stats_ok) "statsExpressions")
    }
    if (wants(ctx, "bettergg")) {
      if (length(counts) || paired) {
        unavailable(ctx, "No faithful BetterGG mapping is provided for counts-weighted or paired categorical data. Keep the ggplot2 figure and the original inference.")
        next
      }
      bd <- paste0(fig, "_bettergg")
      code <- c(paste0(bd, " <- BetterGG::", if (two_way) "ggbarstats" else "ggpiestats", "("),
        paste0("  data = ", ctx$input, ", x = ", r_sym(r), if (two_way) paste0(", y = ", r_sym(cols)), ","),
        paste0("  results.subtitle = ", if (stats_ok) "TRUE" else "FALSE", ", bf.message = FALSE,"),
        paste0("  palette = if (nlevels(factor(", ctx$input, "[[", q(r), "]])) <= 8L) \"ggsci::default_nejm\" else \"palettesForR::Named\""),
        ")")
      add_figure(ctx, "bettergg", code, bd, caption, suffix = suffix, packages = "BetterGG")
    }
  }
  if (wants(ctx, "bettergg") && !length(counts) && !paired) {
    add_note(ctx, paste("BetterGG runs its own unweighted categorical test.",
      if (length(layers)) "It pools the source layers; the ggplot2 figure keeps them." else ""))
  }
}

map_gg_categorical <- function(ctx) {
  a <- ctx$a
  x <- arg_variable(a, "x")
  y <- arg_variable(a, "y", character())
  counts <- arg_variable(a, "counts", character())
  if (length(x) != 1L) stop("The plot needs one x column.")
  prep_input(ctx)
  prep_columns(ctx, c(x, y, counts))
  bar <- ctx$fn == "ggbarstats"
  if (bar && length(y) != 1L) stop("ggbarstats needs x and y columns.")
  ctx$describe <- paste0("the percentage of each category of ", x, if (length(y)) paste0(" within ", y), ".")
  if (wants(ctx, "ggplot2")) {
    code <- if (bar) {
      recipe("recipe_barstats", data = ctx$input, x = x, y = y, name = ctx$name, counts = if (length(counts)) counts,
        stats = ctx$stats, type = arg_value(a, "type", "parametric"), paired = isTRUE(arg_value(a, "paired", FALSE)))
    } else {
      recipe("recipe_piestats", data = ctx$input, x = x, y = if (length(y)) y, name = ctx$name,
        counts = if (length(counts)) counts, stats = ctx$stats, type = arg_value(a, "type", "parametric"),
        paired = isTRUE(arg_value(a, "paired", FALSE)), max_labels = 12)
    }
    add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), paste0("Proportions of ", x, "."),
      packages = if (ctx$stats) "statsExpressions")
  }
  add_bettergg_source(ctx)
}

# Correlation matrices (and partial correlations).
map_correlation <- function(ctx) {
  a <- ctx$a
  if (ctx$fn == "ggcorrmat") {
    vars <- arg_variable(a, "cor.vars", character())
    if (!length(vars)) stop("Give the correlated columns in cor.vars= for the figure.")
    prep_input(ctx)
    prep_columns(ctx, vars)
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_corrmat", data = ctx$input, vars = vars, name = ctx$name, type = arg_value(a, "type", "parametric"),
        p.adjust.method = arg_value(a, "p.adjust.method", "holm"), sig.level = arg_value(a, "sig.level", 0.05))
      add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), "Correlation matrix.")
    }
    ctx$describe <- "the correlation matrix (lower triangle) with crosses on non-significant coefficients."
    return(add_bettergg_source(ctx))
  }
  vars <- arg_variable(a, "vars")
  controls <- arg_variable(a, "controls", character())
  if (length(vars) < 2L) stop("Correlation visualization needs at least two variables.")
  if (ctx$fn == "corrPart" && !length(controls)) stop("Partial correlations need control variables.")
  if (ctx$fn == "corrPart" && !identical(arg_value(a, "type", "part"), "part")) stop("Semi-partial correlations are not drawn.")
  methods <- c(pearson = isTRUE(arg_value(a, "pearson", TRUE)), spearman = isTRUE(arg_value(a, "spearman", FALSE)),
    kendall = isTRUE(arg_value(a, "kendall", FALSE)))
  methods <- names(methods)[methods]
  if (!length(methods)) stop("No correlation method is selected.")
  if (length(controls) && "kendall" %in% methods) stop("Partial Kendall correlations are not drawn.")
  prep_input(ctx)
  prep_columns(ctx, c(vars, controls))
  prep_refuse_weights(ctx, "correlation")
  add_prep(ctx, "# jamovi's numeric values mapping; nominal columns without one stay undefined (empty cells).",
    paste0("for (column in ", r_text(c(vars, controls)), ") {"),
    paste0("  values <- ", ctx$input, "[[column]]"),
    "  if (!is.numeric(values)) {",
    "    mapped <- attr(values, \"values\", exact = TRUE)",
    if ("pearson" %in% methods && length(methods) == 1L) "    values <- if (is.null(mapped)) rep(NA_real_, length(values)) else mapped[as.integer(values)]"
    else "    values <- if (is.null(mapped)) as.numeric(values) else mapped[as.integer(values)]",
    "  }",
    paste0("  ", ctx$input, "[[column]] <- as.numeric(values)"),
    "}")
  ctx$describe <- paste0("the ", if (length(controls)) "partial " else "", "correlations of ", paste(vars, collapse = ", "),
    if (length(controls)) paste0(" controlling for ", paste(controls, collapse = ", ")) else "",
    " (pairwise complete cases), with a cross on each coefficient whose unadjusted p-value is .05 or more, as jamovi flags them.")
  for (m in methods) {
    fig <- if (length(methods) > 1L) paste0(ctx$name, "_", m) else ctx$name
    suffix <- if (length(methods) > 1L) m
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_corrmat", data = ctx$input, vars = vars, name = fig, method = m,
        controls = if (length(controls)) controls, p.adjust.method = "none")
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), paste0(tools::toTitleCase(m), " correlations."), suffix = suffix)
    }
    if (wants(ctx, "bettergg")) {
      if (length(controls) || m == "kendall") {
        unavailable(ctx, "BetterGG's ggcorrmat() has no Kendall or partial-with-chosen-controls option; use the ggplot2 figure.")
        next
      }
      code <- c(paste0(fig, "_bettergg <- BetterGG::ggcorrmat("),
        paste0("  data = ", ctx$input, ", cor.vars = ", r_text(vars), ", type = ", q(if (m == "pearson") "parametric" else "nonparametric"), ","),
        "  p.adjust.method = \"none\"", ")")
      add_figure(ctx, "bettergg", code, paste0(fig, "_bettergg"), paste0(tools::toTitleCase(m), " correlations (BetterGG)."),
        suffix = suffix, packages = "BetterGG")
    }
  }
  if (wants(ctx, "bettergg")) add_note(ctx, "BetterGG's ggcorrmat() computes its own correlation tests with the correlation package.")
}

# Logistic and linear regression (and ggcoefstats).
map_regression <- function(ctx) {
  a <- ctx$a
  fn <- ctx$fn
  name <- ctx$name
  if (fn == "ggcoefstats") {
    model <- a$args$x
    if (!is.symbol(model)) stop("Give ggcoefstats() a model object by name.")
    model <- as.character(model)
    ctx$describe <- paste0("the coefficients of the model ", model, " with their confidence intervals.")
    ctx$prep <- paste0("# The model ", model, " is used as it is.")
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_coefstats", model = model, name = name, ci = "profile", conf.level = ctx$level,
        intercept = !isTRUE(arg_value(a, "exclude.intercept", FALSE)), stats = ctx$stats)
      add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), paste0("Coefficients of ", model, "."),
        packages = if (ctx$stats) "ggrepel")
    }
    if (wants(ctx, "bettergg")) {
      args <- a$args
      call <- as.call(c(list(call("::", as.name("BetterGG"), as.name("ggcoefstats"))), args))
      add_figure(ctx, "bettergg", paste0(name, "_bettergg <- ", r_text(call)), paste0(name, "_bettergg"),
        "BetterGG version of the source ggcoefstats() call.", suffix = "source", packages = "BetterGG")
      ctx$mapping <- "equivalent"
    }
    return(invisible())
  }
  logistic <- fn == "logRegBin"
  dv <- arg_variable(a, "dep")
  factors <- arg_variable(a, "factors", character())
  covs <- arg_variable(a, "covs", character())
  if (length(dv) != 1) stop("The regression needs one outcome.")
  blocks <- arg_value(a, "blocks")
  # jmv blocks are cumulative: the final model contains the terms of every block.
  terms <- if (length(blocks)) unique(unlist(blocks, recursive = FALSE)) else NULL
  rhs <- model_terms(terms, c(factors, covs))
  prep_input(ctx)
  prep_columns(ctx, c(dv, factors, covs))
  prep_numeric(ctx, c(covs, if (!logistic) dv))
  prep_factor(ctx, c(if (logistic) dv, factors))
  for (ref in arg_value(a, "refLevels", list())) if (is.list(ref) && length(ref$var) == 1 && length(ref$ref) == 1) {
    add_prep(ctx, paste0(ctx$input, "[[", q(ref$var), "]] <- stats::relevel(factor(", ctx$input, "[[", q(ref$var), "]]), ref = ", q(ref$ref), ")"))
  }
  w <- prep_weights(ctx)
  formula <- paste(r_sym(dv), "~", rhs)
  if (logistic) {
    add_prep(ctx, paste0("if (nlevels(", ctx$input, "[[", q(dv), "]]) != 2L) stop(\"The logistic outcome must have exactly two levels.\")"),
      paste0("# Model: the jamovi-equivalent logistic regression ", formula, " (final block, with the case weights)."),
      paste0(name, "_model <- stats::glm(", formula, ", data = ", ctx$input, ", weights = ", w,
        ", family = stats::binomial(), na.action = stats::na.omit)"),
      paste0("if (!isTRUE(", name, "_model$converged) || any(!is.finite(stats::coef(", name, "_model)))) {"),
      "  stop(\"The logistic model did not converge or has coefficients that cannot be estimated.\")",
      "}")
  } else {
    add_prep(ctx, paste0("# Model: the jamovi-equivalent linear regression ", formula, " (final block, with the case weights)."),
      paste0(name, "_model <- stats::lm(", formula, ", data = ", ctx$input, ", weights = ", w, ", na.action = stats::na.omit)"))
  }
  ctx$describe <- if (logistic) paste0("the odds ratio of each predictor of ", dv, " (the intercept omitted) with its ", 100 * ctx$level,
    "% Wald confidence interval, as jamovi computes them, on a log scale.") else
    paste0("each regression coefficient for ", dv, " (the intercept omitted) with its ", 100 * ctx$level, "% t-based confidence interval, as jamovi.")
  if (logistic) ctx$differs <- c(ctx$differs, "odds ratios are shown (jamovi's table shows log-odds unless OR is ticked).")
  if (!logistic && isTRUE(arg_value(a, "stdEst", FALSE))) ctx$differs <- c(ctx$differs, "unstandardised coefficients are shown; the source also requested standardised estimates.")
  caption <- paste0(if (logistic) "Odds ratios" else "Coefficients", " predicting ", dv, ".")
  if (wants(ctx, "ggplot2")) {
    code <- recipe("recipe_coefstats", model = paste0(name, "_model"), name = name, ci = if (logistic) "wald" else "t",
      conf.level = ctx$level, exponentiate = logistic, intercept = FALSE, stats = ctx$stats, readable_terms = TRUE)
    add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), caption, packages = if (ctx$stats) "ggrepel")
  }
  if (wants(ctx, "bettergg")) {
    code <- c(paste0(name, "_bettergg <- BetterGG::ggcoefstats("),
      paste0("  x = ", name, "_model, conf.level = ", ctx$level, ", exclude.intercept = TRUE,"),
      paste0("  stats.labels = ", if (ctx$stats) "TRUE" else "FALSE", ", bf.message = FALSE"), ")")
    add_figure(ctx, "bettergg", code, paste0(name, "_bettergg"), paste(caption, "(BetterGG)"), packages = "BetterGG")
    add_note(ctx, if (logistic) "BetterGG's ggcoefstats() shows log-odds with intervals from the parameters package; the ggplot2 figure shows jamovi's Wald intervals as odds ratios." else
      "BetterGG's ggcoefstats() uses its own coefficient extraction; compare with the ggplot2 figure.")
  }
}

map_scatter <- function(ctx) {
  a <- ctx$a
  x <- arg_variable(a, "x")
  y <- arg_variable(a, "y")
  if (length(x) != 1L || length(y) != 1L) stop("Scatterplots need explicit x and y columns.")
  prep_input(ctx)
  prep_columns(ctx, c(x, y))
  prep_numeric(ctx, c(x, y))
  ctx$describe <- paste0("each observation of ", x, " and ", y, " with the linear fit and its confidence band, and both distributions on the margins.")
  if (wants(ctx, "ggplot2")) {
    code <- recipe("recipe_scatterstats", data = ctx$input, x = x, y = y, name = ctx$name,
      type = arg_value(a, "type", "parametric"), stats = ctx$stats, conf.level = ctx$level,
      marginal = !identical(arg_value(a, "marginal", TRUE), FALSE),
      xlab = arg_value(a, "xlab", x), ylab = arg_value(a, "ylab", y), title = arg_value(a, "title"))
    add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), paste0(y, " against ", x, "."),
      packages = c("ggside", if (ctx$stats) "statsExpressions"))
  }
  add_bettergg_source(ctx)
}

map_reliability <- function(ctx) {
  a <- ctx$a
  items <- arg_variable(a, "vars")
  reverse <- arg_variable(a, "revItems", character())
  if (length(items) < 2L) stop("Reliability needs at least two items.")
  prep_input(ctx)
  prep_columns(ctx, items)
  prep_refuse_weights(ctx, "reliability")
  prep_numeric(ctx, items)
  ctx$describe <- paste0("the responses to each item and each item's correlation with the sum of the other items",
    if (length(reverse)) paste0(" (", paste(reverse, collapse = ", "), " reverse-scored as jamovi does)") else "",
    "; complete rows only, as jamovi.")
  caption <- "Item responses and item-rest correlations."
  if (wants(ctx, "ggplot2")) {
    code <- recipe("recipe_reliability", data = ctx$input, items = items, reverse = if (length(reverse)) reverse,
      name = ctx$name, stats = ctx$stats)
    add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), caption, packages = c("patchwork", "ggdist"))
  }
  if (wants(ctx, "bettergg")) {
    code <- c(paste0(ctx$name, "_bettergg <- BetterGG::ggreliability("),
      paste0("  data = ", ctx$input, ", items = ", r_text(items), ", reverse = ", if (length(reverse)) r_text(reverse) else "NULL", ","),
      paste0("  stats = ", if (ctx$stats) "TRUE" else "FALSE"), ")")
    add_figure(ctx, "bettergg", code, paste0(ctx$name, "_bettergg"), caption, packages = "BetterGG")
  }
}
