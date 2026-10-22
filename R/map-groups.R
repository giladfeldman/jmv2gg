# Group comparisons: ANOVA family, t-tests, repeated measures.

bettergg_stats_args <- function(ctx) {
  if (ctx$stats) "results.subtitle = TRUE, pairwise.display = \"significant\", bf.message = FALSE"
  else "results.subtitle = FALSE, pairwise.display = \"none\", bf.message = FALSE"
}

# jamovi's ANOVA/ANCOVA (and ggbetweenstats, one-way ANOVA, Kruskal-Wallis).
map_between <- function(ctx) {
  a <- ctx$a
  fn <- ctx$fn
  if (fn %in% c("anovaOneW", "anovaNP")) return(map_oneway_family(ctx))
  if (fn == "ggbetweenstats") return(map_ggbetweenstats(ctx))
  factors <- arg_variable(a, "factors", character())
  covs <- arg_variable(a, "covs", character())
  dv <- arg_variable(a, "dep")
  formula_expr <- a$args$formula
  runtime_split <- FALSE
  if (!is.null(formula_expr)) {
    validate_formula_syntax(formula_expr)
    if (!is.call(formula_expr) || !identical(formula_expr[[1]], as.name("~")) || length(formula_expr) != 3)
      stop("Use an explicit outcome ~ predictors formula.")
    dv <- all.vars(formula_expr[[2]])
    # jmvcore::marshalFormula: ANOVA makes every predictor a factor; ancova makes
    # numeric columns covariates and the rest factors, which depends on the data.
    factors <- all.vars(formula_expr[[3]])
    covs <- character()
    runtime_split <- fn == "ancova"
    rhs <- r_text(formula_expr[[3]])
  } else {
    terms <- arg_value(a, "modelTerms")
    rhs <- if (is.null(terms) && length(factors) > 1L) {
      paste(c(paste(r_sym(factors), collapse = " * "), r_sym(covs)), collapse = " + ")
    } else model_terms(terms, c(factors, covs))
  }
  if (length(dv) != 1 || !length(factors)) stop("ANOVA needs one outcome and at least one factor.")
  if (length(intersect(dv, c(factors, covs)))) stop("The outcome cannot also be a predictor.")
  if (!runtime_split && length(factors) > 3L) stop("Figures cover designs with up to three factors.")
  name <- ctx$name
  input <- ctx$input
  prep_input(ctx)
  prep_columns(ctx, c(dv, factors, covs))
  prep_numeric(ctx, c(dv, covs))
  w <- prep_weights(ctx)
  fv <- paste0(name, "_factors")
  cv <- paste0(name, "_covariates")
  if (runtime_split) {
    add_prep(ctx,
      "# jamovi's ANCOVA formula rule: numeric columns are covariates, the others factors.",
      paste0(name, "_predictors <- ", r_text(factors)),
      paste0(name, "_is_numeric <- vapply(", input, "[", name, "_predictors], is.numeric, logical(1))"),
      paste0(fv, " <- ", name, "_predictors[!", name, "_is_numeric]"),
      paste0(cv, " <- ", name, "_predictors[", name, "_is_numeric]"),
      paste0("if (!length(", fv, ")) stop(\"ANCOVA needs at least one factor.\")"),
      paste0("if (length(", fv, ") > 3L) stop(\"Figures cover designs with up to three factors.\")"))
  } else {
    add_prep(ctx, paste0(fv, " <- ", r_text(factors)), paste0(cv, " <- ", r_text(covs)))
  }
  add_prep(ctx,
    "# Factors (SPSS value labels name the levels) with sum-to-zero contrasts, as in jamovi.",
    paste0("for (column in ", fv, ") {"),
    paste0("  values <- ", input, "[[column]]"),
    paste0("  ", input, "[[column]] <- if (inherits(values, \"haven_labelled\")) haven::as_factor(values) else factor(values)"),
    paste0("  if (nlevels(", input, "[[column]]) < 2L) stop(\"Factor \", column, \" has fewer than two observed levels.\")"),
    "}",
    paste0(name, "_model_data <- ", input),
    paste0("for (column in ", fv, ") {"),
    paste0("  stats::contrasts(", name, "_model_data[[column]]) <- stats::contr.sum(nlevels(", name, "_model_data[[column]]))"),
    "}")
  formula <- paste(r_sym(dv), "~", rhs)
  emm_weights <- if (isTRUE(arg_value(a, "emmWeights", TRUE))) "equal" else "proportional"
  add_prep(ctx,
    paste0("# Model: the jamovi-equivalent linear model ", formula, " (with the case weights)."),
    paste0(name, "_model <- stats::lm(", formula, ", data = ", name, "_model_data, weights = ", w, ", na.action = stats::na.omit)"),
    paste0("# Estimated marginal means and ", 100 * ctx$level, "% confidence intervals (", emm_weights,
      " cell weights", if (length(covs) || runtime_split) "; covariates at their mean" else "", ")."),
    paste0(name, "_means <- as.data.frame(stats::confint(emmeans::emmeans(", name, "_model, specs = ", fv,
      ", weights = ", q(emm_weights), "), level = ", ctx$level, "))"))
  ss <- as.character(arg_value(a, "ss", "3"))
  one_way <- !runtime_split && length(factors) == 1L && !length(covs)
  stats_ok <- ctx$stats
  if (ctx$stats && ss != "3" && !one_way) {
    add_note(ctx, paste0("The figure's F tests are type III; the source uses type ", ss,
      " sums of squares, so no statistics are shown on the figure."), code = "statistics_not_shown")
    stats_ok <- FALSE
  }
  if (ctx$stats) ctx$differs <- c(ctx$differs, if (one_way)
    "the subtitle gives omega-squared as the effect size (statsExpressions)." else
    "the subtitle gives partial eta-squared from F and its degrees of freedom.")
  ctx$describe <- paste0("every observation of ", dv, " and its distribution ",
    if (one_way) paste0("in each group of ", factors) else "in each cell of the design",
    ", with the estimated marginal means and their ", 100 * ctx$level,
    "% confidence intervals from the model ", formula, " (sum-to-zero contrasts, ", emm_weights, " cell weights",
    if (length(covs) || runtime_split) ", covariates at their mean" else "", ").")
  caption <- paste0(dv, ": observations, their distribution and model-based means with ", 100 * ctx$level, "% CIs.")
  if (wants(ctx, "ggplot2")) {
    pkgs <- c("ggdist", "emmeans", if (one_way) "ggrepel", if (stats_ok) c("statsExpressions", if (one_way) "ggsignif"))
    if (one_way) {
      code <- recipe("recipe_betweenrain", data = input, x = factors, y = dv, name = name, means = paste0(name, "_means"),
        stats = stats_ok, var.equal = TRUE, conf.level = ctx$level)
      add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), caption, packages = pkgs,
        note = if (stats_ok) "the subtitle is a Fisher (equal-variance) one-way ANOVA on the unweighted data; it equals jamovi's F when there are no case weights.")
    } else if (!runtime_split) {
      code <- recipe("recipe_factorialrain", data = input, x = factors[1], y = dv,
        colour = if (length(factors) > 1L) factors[2], facet = if (length(factors) > 2L) factors[3],
        covariates = if (length(covs)) covs, name = name, means = paste0(name, "_means"),
        model = paste0(name, "_model"), stats = stats_ok, conf.level = ctx$level)
      add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), caption, packages = pkgs)
    } else {
      # The factors are known only when the code runs: one branch per number of factors.
      variant <- function(k) recipe("recipe_factorialrain", data = input, x = I(paste0(fv, "[1]")), y = dv,
        colour = if (k > 1L) I(paste0(fv, "[2]")), facet = if (k > 2L) I(paste0(fv, "[3]")),
        covariates = I(cv), name = name, means = paste0(name, "_means"), model = paste0(name, "_model"),
        stats = stats_ok, conf.level = ctx$level)
      code <- c(paste0("if (length(", fv, ") == 1L) {"), indent(variant(1L)),
        paste0("} else if (length(", fv, ") == 2L) {"), indent(variant(2L)),
        "} else {", indent(variant(3L)), "}")
      add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), caption, packages = pkgs)
    }
  }
  if (wants(ctx, "bettergg")) {
    msg <- "BetterGG fits its own unweighted model for this figure; the ggplot2 figure uses the jamovi-equivalent model."
    if (one_way) {
      msg <- paste("BetterGG's ggbetweenrain() shows the observed group means",
        if (ctx$stats) "and Welch's ANOVA (ggstatsplot does not offer the equal-variance test)" else "",
        "and does not apply case weights; the ggplot2 figure shows the jamovi model's means.")
      code <- c(paste0(name, "_bettergg <- BetterGG::ggbetweenrain("),
        paste0("  data = ", input, ", x = ", r_sym(factors), ", y = ", r_sym(dv), ", type = \"parametric\","),
        paste0("  conf.level = ", ctx$level, ", ", bettergg_stats_args(ctx)),
        ")")
    } else if (!runtime_split) {
      msg <- paste("BetterGG's ggfactorialrain() fits the full factorial model", if (length(covs)) "with the covariates" else "",
        "without case weights", if (!is.null(arg_value(a, "modelTerms"))) "and without the source's custom model terms" else "",
        "; the ggplot2 figure uses the jamovi-equivalent model.")
      code <- c(paste0(name, "_bettergg <- BetterGG::ggfactorialrain("),
        paste0("  data = ", input, ", x = ", q(factors[1]), ", y = ", q(dv),
          if (length(factors) > 1L) paste0(", colour = ", q(factors[2])),
          if (length(factors) > 2L) paste0(", facet = ", q(factors[3])), ","),
        paste0("  covariates = ", if (length(covs)) r_text(covs) else "NULL", ", conf.level = ", ctx$level,
          ", stats = ", if (stats_ok) "TRUE" else "FALSE"),
        ")")
    } else {
      code <- c(paste0(name, "_bettergg <- BetterGG::ggfactorialrain("),
        paste0("  data = ", input, ", x = ", fv, "[1], y = ", q(dv), ","),
        paste0("  colour = if (length(", fv, ") > 1L) ", fv, "[2], facet = if (length(", fv, ") > 2L) ", fv, "[3],"),
        paste0("  covariates = if (length(", cv, ")) ", cv, ", conf.level = ", ctx$level,
          ", stats = ", if (stats_ok) "TRUE" else "FALSE"),
        ")")
    }
    add_note(ctx, gsub("\\s+;", ";", gsub("\\s+", " ", msg)))
    add_figure(ctx, "bettergg", code, paste0(name, "_bettergg"), caption, packages = "BetterGG",
      note = gsub("\\s+;", ";", gsub("\\s+", " ", msg)))
  }
  ctx$mapping <- if (wants(ctx, "bettergg")) "alternative_analysis" else "visualization_only"
}

# ggstatsplot::ggbetweenstats(): the ggplot2 figure mirrors the source call.
map_ggbetweenstats <- function(ctx) {
  a <- ctx$a
  x <- arg_variable(a, "x")
  y <- arg_variable(a, "y")
  if (length(x) != 1L || length(y) != 1L) stop("ggbetweenstats needs explicit x and y columns.")
  prep_input(ctx)
  prep_columns(ctx, c(x, y))
  prep_labelled_to_factor(ctx, x)
  type <- arg_value(a, "type", "parametric")
  ctx$describe <- paste0("every observation of ", y, " and its distribution in each group of ", x,
    ", with the group ", if (substr(type, 1, 1) == "n") "medians" else if (substr(type, 1, 1) == "r") "trimmed means" else "means", ".")
  if (isTRUE(arg_value(a, "var.equal", FALSE))) {
    ctx$differs <- c(ctx$differs, "ggstatsplot ignores var.equal; the figure keeps the Welch test the source plot showed.")
  }
  if (wants(ctx, "ggplot2")) {
    code <- recipe("recipe_betweenrain", data = ctx$input, x = x, y = y, name = ctx$name, type = type,
      stats = ctx$stats, conf.level = ctx$level, p.adjust.method = arg_value(a, "p.adjust.method", "holm"),
      alternative = arg_value(a, "alternative", "two.sided"), tr = arg_value(a, "tr", 0.2),
      xlab = arg_value(a, "xlab", x), ylab = arg_value(a, "ylab", y), title = arg_value(a, "title"))
    add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), paste0(y, " by ", x, ": raincloud."),
      packages = c("ggdist", "ggrepel", if (ctx$stats) c("statsExpressions", "ggsignif")))
  }
  add_bettergg_source(ctx)
}

# A ggstatsplot/BetterGG source call: the BetterGG figure is that call with BetterGG.
add_bettergg_source <- function(ctx) {
  if (!wants(ctx, "bettergg")) return(invisible())
  args <- ctx$a$args
  args$data <- as.name(ctx$input)
  call <- as.call(c(list(call("::", as.name("BetterGG"), as.name(ctx$fn))), args))
  add_figure(ctx, "bettergg", paste0(ctx$name, "_bettergg <- ", r_text(call)), paste0(ctx$name, "_bettergg"),
    paste0("BetterGG version of the source ", ctx$fn, "() call."), suffix = "source", packages = "BetterGG")
  ctx$mapping <- "equivalent"
}

# anovaOneW (Welch/Fisher) and anovaNP (Kruskal-Wallis): one figure per outcome.
map_oneway_family <- function(ctx) {
  a <- ctx$a
  deps <- arg_variable(a, "deps")
  group <- arg_variable(a, "group")
  if (!length(deps) || length(group) != 1L) stop("One-way ANOVA needs outcomes (deps) and one group.")
  prep_input(ctx)
  prep_columns(ctx, c(deps, group))
  prep_refuse_weights(ctx, "one-way ANOVA")
  prep_numeric(ctx, deps)
  prep_factor(ctx, group)
  np <- ctx$fn == "anovaNP"
  welch <- isTRUE(arg_value(a, "welchs", TRUE)) || !isTRUE(arg_value(a, "fishers", FALSE))
  type <- if (np) "nonparametric" else "parametric"
  ctx$describe <- paste0("every observation and its distribution in each group of ", group,
    ", with the group ", if (np) "medians" else "means", ".")
  if (ctx$stats) ctx$differs <- c(ctx$differs, if (np) "the subtitle's effect size is epsilon-squared (as jamovi) with a bootstrap CI." else
    "the subtitle gives omega-squared as the effect size.")
  for (i in seq_along(deps)) {
    dv <- deps[i]
    suffix <- if (length(deps) > 1L) dv
    fig <- if (length(deps) > 1L) paste0(ctx$name, "_", i) else ctx$name
    caption <- paste0(dv, " by ", group, ": ", if (np) "Kruskal-Wallis" else if (welch) "Welch's ANOVA" else "Fisher's ANOVA", " design.")
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_betweenrain", data = ctx$input, x = group, y = dv, name = fig, type = type,
        stats = ctx$stats, var.equal = !welch, conf.level = ctx$level)
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), caption, suffix = suffix,
        packages = c("ggdist", "ggrepel", if (ctx$stats) c("statsExpressions", "ggsignif")))
    }
    if (wants(ctx, "bettergg")) {
      code <- c(paste0(fig, "_bettergg <- BetterGG::ggbetweenrain("),
        paste0("  data = ", ctx$input, ", x = ", r_sym(group), ", y = ", r_sym(dv), ", type = ", q(type), ","),
        paste0("  conf.level = ", ctx$level, ", ", bettergg_stats_args(ctx)), ")")
      add_figure(ctx, "bettergg", code, paste0(fig, "_bettergg"), caption, suffix = suffix, packages = "BetterGG",
        note = if (ctx$stats && !np && !welch) "BetterGG's subtitle uses Welch's ANOVA; the source uses Fisher's." )
    }
  }
  if (wants(ctx, "bettergg") && ctx$stats && !np && !welch) {
    add_note(ctx, "BetterGG's subtitle uses Welch's ANOVA; the source uses Fisher's equal-variance ANOVA.")
  }
}

# Independent-samples t-test: one figure per outcome.
map_ttest_independent <- function(ctx) {
  a <- ctx$a
  vars <- arg_variable(a, "vars", character())
  group <- arg_variable(a, "group", character())
  formula_expr <- a$args$formula
  if (!is.null(formula_expr)) {
    validate_formula_syntax(formula_expr)
    if (!is.call(formula_expr) || length(formula_expr) != 3L) stop("Use an outcome ~ group formula.")
    vars <- all.vars(formula_expr[[2]])
    group <- all.vars(formula_expr[[3]])
  }
  if (!length(vars) || length(group) != 1L) stop("The t-test needs outcome(s) and one grouping column.")
  prep_input(ctx)
  prep_columns(ctx, c(vars, group))
  prep_refuse_weights(ctx, "t-test")
  prep_numeric(ctx, vars)
  prep_factor(ctx, group)
  add_prep(ctx, paste0("if (nlevels(", ctx$input, "[[", q(group), "]]) != 2L) stop(\"The grouping column must have exactly two levels.\")"))
  students <- isTRUE(arg_value(a, "students", TRUE))
  welchs <- isTRUE(arg_value(a, "welchs", FALSE))
  mann <- isTRUE(arg_value(a, "mann", FALSE))
  type <- if (!students && !welchs && mann) "nonparametric" else "parametric"
  var_equal <- students
  hypothesis <- arg_value(a, "hypothesis", "different")
  alternative <- switch(hypothesis, oneGreater = "greater", twoGreater = "less", "two.sided")
  ctx$describe <- paste0("every observation and its distribution in the two groups of ", group,
    ", with the group ", if (type == "parametric") "means" else "medians", ".")
  if (ctx$stats) ctx$differs <- c(ctx$differs, paste0("the subtitle is ",
    if (type == "nonparametric") "the Mann-Whitney test with the rank-biserial correlation" else
      paste0(if (var_equal) "Student's" else "Welch's", " t-test with Hedges' g (jamovi reports Cohen's d)"),
    if (students && welchs) "; jamovi also reports Welch's test" else "", "."))
  for (i in seq_along(vars)) {
    dv <- vars[i]
    suffix <- if (length(vars) > 1L) dv
    fig <- if (length(vars) > 1L) paste0(ctx$name, "_", i) else ctx$name
    caption <- paste0(dv, " by ", group, ".")
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_betweenrain", data = ctx$input, x = group, y = dv, name = fig, type = type,
        stats = ctx$stats, var.equal = var_equal, alternative = alternative, conf.level = ctx$level)
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), caption, suffix = suffix,
        packages = c("ggdist", "ggrepel", if (ctx$stats) "statsExpressions"))
    }
    if (wants(ctx, "bettergg")) {
      code <- c(paste0(fig, "_bettergg <- BetterGG::ggbetweenrain("),
        paste0("  data = ", ctx$input, ", x = ", r_sym(group), ", y = ", r_sym(dv), ", type = ", q(type), ","),
        paste0("  alternative = ", q(alternative), ", conf.level = ", ctx$level, ", ", bettergg_stats_args(ctx)), ")")
      add_figure(ctx, "bettergg", code, paste0(fig, "_bettergg"), caption, suffix = suffix, packages = "BetterGG")
    }
  }
  if (wants(ctx, "bettergg") && ctx$stats && type == "parametric" && var_equal) {
    add_note(ctx, "BetterGG's subtitle uses Welch's t-test (ggstatsplot does not offer Student's); the ggplot2 figure uses Student's, as the source.")
  }
}

# Paired t-tests, repeated-measures ANOVA and ggwithinstats().
map_within <- function(ctx) {
  a <- ctx$a
  fn <- ctx$fn
  name <- ctx$name
  input <- ctx$input
  if (fn == "ggwithinstats") return(map_ggwithinstats(ctx))
  if (fn == "ttestPS") return(map_ttest_paired(ctx))
  bs <- arg_variable(a, "bs", character())
  covs <- arg_variable(a, "cov", character())
  rm_defs <- arg_value(a, "rm")
  cells <- arg_value(a, "rmCells")
  if (!length(rm_defs) || !length(cells)) stop("Repeated-measures conversion needs literal rm and rmCells mappings.")
  rm_names <- vapply(rm_defs, function(x) x$label, character(1))
  measures <- vapply(cells, function(x) x$measure, character(1))
  if (anyDuplicated(measures)) stop("Repeated measure columns are duplicated.")
  if (length(rm_names) + length(bs) > 3L) stop("Figures cover designs with up to three factors.")
  value <- if ("value" %in% c(rm_names, bs, covs)) ".value" else "value"
  value_label <- as.character(arg_value(a, "depLabel", "value"))
  subject <- if ("subject" %in% c(rm_names, bs, covs)) ".subject" else "subject"
  prep_input(ctx)
  prep_columns(ctx, c(measures, bs, covs))
  prep_refuse_weights(ctx, "repeated-measures")
  prep_numeric(ctx, c(measures, covs))
  add_prep(ctx, paste0("# Complete cases of every measure, as jamovi uses."),
    paste0(input, " <- ", input, "[stats::complete.cases(", input, "[, ", r_text(c(measures, bs, covs)), ", drop = FALSE]), , drop = FALSE]"),
    "# Long format: one row per participant and measure.")
  pieces <- character()
  for (i in seq_along(cells)) {
    cell <- cells[[i]]
    if (length(cell$cell) != length(rm_names)) stop("Each repeated-measures cell must identify every within-subject factor.")
    values <- paste0(r_sym(subject), " = seq_len(nrow(", input, ")), ", r_sym(value), " = ", input, "[[", q(cell$measure), "]]")
    for (j in seq_along(rm_names)) values <- paste0(values, ", ", r_sym(rm_names[j]), " = ", q(cell$cell[j]))
    for (v in c(bs, covs)) values <- paste0(values, ", ", r_sym(v), " = ", input, "[[", q(v), "]]")
    pieces <- c(pieces, paste0("  data.frame(", values, ", check.names = FALSE)"))
  }
  long <- paste0(name, "_long")
  add_prep(ctx, paste0(long, " <- rbind("), paste0(pieces, c(rep(",", length(pieces) - 1L), "")), ")")
  for (i in seq_along(rm_names)) {
    add_prep(ctx, paste0(long, "[[", q(rm_names[i]), "]] <- factor(", long, "[[", q(rm_names[i]), "]], levels = ",
      r_text(as.character(rm_defs[[i]]$levels)), ")"))
  }
  for (v in bs) add_prep(ctx, paste0(long, "[[", q(v), "]] <- ", factor_code(paste0(long, "[[", q(v), "]]"))))
  add_prep(ctx, paste0(long, "[[", q(subject), "]] <- factor(", long, "[[", q(subject), "]])"))
  within_rhs <- paste(r_sym(rm_names), collapse = " * ")
  if (!is.null(a$args$rmTerms)) {
    validate_formula_syntax(a$args$rmTerms)
    within_rhs <- r_text(a$args$rmTerms[[length(a$args$rmTerms)]])
  }
  between_rhs <- paste(r_sym(bs), collapse = " * ")
  if (!is.null(a$args$bsTerms)) {
    validate_formula_syntax(a$args$bsTerms)
    between_rhs <- r_text(a$args$bsTerms[[length(a$args$bsTerms)]])
  }
  rhs <- if (nzchar(between_rhs)) paste0("(", between_rhs, ") * (", within_rhs, ")") else within_rhs
  if (length(covs)) rhs <- paste(rhs, paste(r_sym(covs), collapse = " + "), sep = " + ")
  factors <- c(rm_names, bs)
  formula <- paste0(r_sym(value), " ~ ", rhs, " + Error(", r_sym(subject), "/(", paste(r_sym(rm_names), collapse = " * "), "))")
  one_factor <- length(rm_names) == 1L && !length(bs) && !length(covs)
  if (!one_factor) {
    add_prep(ctx, paste0("# Model: repeated-measures ANOVA (afex) ", formula, "."),
      paste0(name, "_model <- afex::aov_car(", formula, ", data = ", long, ", factorize = FALSE)"),
      paste0("# Estimated marginal means and ", 100 * ctx$level, "% confidence intervals (emmeans on the afex model)."),
      paste0(name, "_means <- as.data.frame(stats::confint(emmeans::emmeans(", name, "_model, specs = ",
        r_text(factors), "), level = ", ctx$level, "))"))
  }
  ctx$describe <- if (one_factor) paste0("each participant's values in each condition of ", rm_names,
    ", their distribution, and the condition means joined by a line.") else
    paste0("every observation and its distribution in each cell, with the estimated marginal means and ", 100 * ctx$level,
      "% confidence intervals from the repeated-measures model (emmeans on afex; these intervals are model-based, not within-subject corrected).")
  if (ctx$stats && !one_factor) {
    add_note(ctx, "Statistics are not drawn on factorial repeated-measures figures; see the jamovi ANOVA table.", code = "statistics_not_shown")
  }
  # statsExpressions reports the Greenhouse-Geisser-corrected test for three or
  # more conditions; jamovi's default table is uncorrected.
  stats_ok <- ctx$stats
  if (ctx$stats && one_factor) {
    k <- length(rm_defs[[1]]$levels)
    corrections <- as.character(arg_value(a, "spherCorr", "none"))
    if (k > 2L && !"GG" %in% corrections) {
      add_note(ctx, paste("No statistics are drawn: the figure's test would be Greenhouse-Geisser corrected,",
        "while the source's table is uncorrected. Add spherCorr = \"GG\" to the source to compare them."),
        code = "statistics_not_shown")
      stats_ok <- FALSE
    } else {
      ctx$differs <- c(ctx$differs, if (k > 2L) "the subtitle is the Greenhouse-Geisser-corrected repeated-measures ANOVA with omega-squared." else
        "the subtitle is the paired t-test (t squared equals jamovi's F).")
    }
  }
  caption <- paste0("Repeated measures by ", paste(factors, collapse = ", "), ".")
  if (wants(ctx, "ggplot2")) {
    if (one_factor) {
      code <- recipe("recipe_withinrain", data = long, x = rm_names, y = value, subject = subject, name = name,
        stats = stats_ok, conf.level = ctx$level, xlab = rm_names, ylab = value_label)
      add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), caption,
        packages = c("ggdist", "ggrepel", if (stats_ok) c("statsExpressions", "ggsignif")))
    } else {
      code <- recipe("recipe_factorialrain", data = long, x = factors[1], y = value,
        colour = if (length(factors) > 1L) factors[2], facet = if (length(factors) > 2L) factors[3],
        covariates = if (length(covs)) covs, name = name, means = paste0(name, "_means"), conf.level = ctx$level,
        ylab = value_label)
      add_figure(ctx, "ggplot2", code, paste0(name, "_plot"), caption, packages = c("ggdist", "afex", "emmeans"))
    }
  }
  if (wants(ctx, "bettergg")) {
    if (one_factor) {
      code <- c(paste0(name, "_bettergg <- BetterGG::ggwithinrain("),
        paste0("  data = ", long, ", x = ", r_sym(rm_names), ", y = ", r_sym(value), ", subject.id = ", r_sym(subject), ","),
        paste0("  conf.level = ", ctx$level, ", ", bettergg_stats_args(ctx)), ")")
    } else {
      code <- c(paste0(name, "_bettergg <- BetterGG::ggfactorialrain("),
        paste0("  data = ", long, ", x = ", q(factors[1]), ", y = ", q(value),
          if (length(factors) > 1L) paste0(", colour = ", q(factors[2])),
          if (length(factors) > 2L) paste0(", facet = ", q(factors[3])), ","),
        paste0("  covariates = ", if (length(covs)) r_text(covs) else "NULL", ", means = ", name, "_means, conf.level = ", ctx$level),
        ")")
    }
    add_figure(ctx, "bettergg", code, paste0(name, "_bettergg"), caption, packages = "BetterGG")
    add_note(ctx, if (one_factor) "BetterGG computes its own paired comparison on complete cases; it is additional to the jamovi analysis." else
      "The BetterGG figure draws the repeated-measures model means computed above.")
  }
}

map_ttest_paired <- function(ctx) {
  a <- ctx$a
  pairs <- arg_value(a, "pairs")
  if (!length(pairs) || !all(vapply(pairs, is.list, logical(1)))) stop("Use explicit i1/i2 pairs for the paired t-test.")
  measures <- lapply(pairs, function(pair) as.character(c(pair$i1 %||% pair[[1]], pair$i2 %||% pair[[2]])))
  prep_input(ctx)
  prep_columns(ctx, unlist(measures))
  prep_refuse_weights(ctx, "paired t-test")
  prep_numeric(ctx, unlist(measures))
  students <- isTRUE(arg_value(a, "students", TRUE))
  wilcoxon <- isTRUE(arg_value(a, "wilcoxon", FALSE))
  type <- if (!students && wilcoxon) "nonparametric" else "parametric"
  hypothesis <- arg_value(a, "hypothesis", "different")
  alternative <- switch(hypothesis, oneGreater = "greater", twoGreater = "less", "two.sided")
  ctx$describe <- "each participant's two values (joined by a dashed line), their distribution, and the two means."
  if (ctx$stats) ctx$differs <- c(ctx$differs, if (type == "parametric")
    "the subtitle gives Hedges' g; jamovi reports Cohen's d." else "the subtitle is the Wilcoxon signed-rank test.")
  for (i in seq_along(measures)) {
    m <- measures[[i]]
    fig <- if (length(measures) > 1L) paste0(ctx$name, "_", i) else ctx$name
    long <- paste0(fig, "_long")
    add_prep(ctx, paste0("# Long format for the pair ", m[1], " - ", m[2], ": one row per participant and measure."),
      paste0(long, " <- data.frame("),
      paste0("  subject = factor(rep(seq_len(nrow(", ctx$input, ")), 2L)),"),
      paste0("  measure = factor(rep(", r_text(m), ", each = nrow(", ctx$input, ")), levels = ", r_text(m), "),"),
      paste0("  value = c(", ctx$input, "[[", q(m[1]), "]], ", ctx$input, "[[", q(m[2]), "]])"),
      ")")
    suffix <- if (length(measures) > 1L) paste(m, collapse = "-")
    caption <- paste0(m[1], " and ", m[2], " (paired).")
    if (wants(ctx, "ggplot2")) {
      code <- recipe("recipe_withinrain", data = long, x = "measure", y = "value", subject = "subject", name = fig,
        type = type, stats = ctx$stats, alternative = alternative, conf.level = ctx$level)
      add_figure(ctx, "ggplot2", code, paste0(fig, "_plot"), caption, suffix = suffix,
        packages = c("ggdist", "ggrepel", if (ctx$stats) "statsExpressions"))
    }
    if (wants(ctx, "bettergg")) {
      code <- c(paste0(fig, "_bettergg <- BetterGG::ggwithinrain("),
        paste0("  data = ", long, ", x = measure, y = value, subject.id = subject, type = ", q(type), ","),
        paste0("  alternative = ", q(alternative), ", conf.level = ", ctx$level, ", ", bettergg_stats_args(ctx)), ")")
      add_figure(ctx, "bettergg", code, paste0(fig, "_bettergg"), caption, suffix = suffix, packages = "BetterGG")
    }
  }
}

map_ggwithinstats <- function(ctx) {
  a <- ctx$a
  subject <- arg_variable(a, "subject.id")
  x <- arg_variable(a, "x")
  y <- arg_variable(a, "y")
  if (length(subject) != 1L || length(x) != 1L || length(y) != 1L)
    stop("Long-form paired data requires explicit subject.id, x and y names.")
  prep_input(ctx)
  prep_columns(ctx, c(subject, x, y))
  type <- arg_value(a, "type", "parametric")
  ctx$describe <- paste0("each subject's values of ", y, " in each condition of ", x, ", their distribution and the condition centres.")
  if (wants(ctx, "ggplot2")) {
    code <- recipe("recipe_withinrain", data = ctx$input, x = x, y = y, subject = subject, name = ctx$name,
      type = type, stats = ctx$stats, conf.level = ctx$level, p.adjust.method = arg_value(a, "p.adjust.method", "holm"),
      alternative = arg_value(a, "alternative", "two.sided"), tr = arg_value(a, "tr", 0.2),
      xlab = arg_value(a, "xlab", x), ylab = arg_value(a, "ylab", y), title = arg_value(a, "title"))
    add_figure(ctx, "ggplot2", code, paste0(ctx$name, "_plot"), paste0(y, " by ", x, " (within subjects)."),
      packages = c("ggdist", "ggrepel", if (ctx$stats) c("statsExpressions", "ggsignif")))
  }
  add_bettergg_source(ctx)
}

# grouped_gg*stats(): BetterGG runs the call; there is no ggplot2 recipe.
map_grouped_ggstatsplot <- function(ctx) {
  if (!wants(ctx, "bettergg")) stop("grouped_* plots are available as BetterGG figures only; choose the BetterGG engine.")
  prep_input(ctx)
  add_bettergg_source(ctx)
  ctx$describe <- "the source's grouped ggstatsplot figure, drawn by BetterGG (one panel per group)."
  if (wants(ctx, "ggplot2")) unavailable(ctx, "No editable ggplot2 recipe is provided for grouped_* plots; the BetterGG figure is generated.")
}

# Code that turns a column into a factor; SPSS value labels become the level names.
factor_code <- function(x) paste0("if (inherits(", x, ", \"haven_labelled\")) haven::as_factor(", x, ") else factor(", x, ")")
