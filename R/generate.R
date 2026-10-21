generate_analysis <- function(a, engine, options) {
  if (a$status == "unsupported") stop("This function or argument signature is not supported: ", a$function_name)
  fn <- a$function_name
  engines <- if (engine == "both") c("ggplot2", "bettergg") else engine
  data_expr <- a$args$data
  if (is.null(data_expr) || !is.symbol(data_expr)) stop("Use a stable named data frame in data=; dynamic data expressions are preserved without conversion.")
  data <- as.character(data_expr)
  stem <- paste0(".jmv2gg_", a$id)
  d <- paste0(stem, "_data")
  head <- c(if (options$style$verbose) paste0("# ", a$id, ": ", a$package, "::", fn),
    paste0(d, " <- ", r_text(data_expr)),
    paste0("if (!is.data.frame(", d, ")) stop(\"The analysis data must be a data frame.\")"))
  w <- paste0(stem,"_weights")
  mapped <- paste0(stem,"_mapped")
  head <- c(head,paste0(w," <- attr(",d,", \"jmv-weights\", exact = TRUE)"),
    paste0("if (is.null(",w,")) ",w," <- rep(1, nrow(",d,"))"),
    paste0("if (!is.numeric(",w,")) { ",mapped," <- attr(",w,", \"values\", exact = TRUE); if (is.null(",mapped,")) stop(\"Weights must be numeric or have an explicit numeric values mapping.\"); ",w," <- ",mapped,"[as.integer(",w,")] }"),
    paste0("if (length(",w,") != nrow(",d,") || any(",w," < 0, na.rm = TRUE)) stop(\"Invalid case weights.\")"))
  plots <- list(); bodies <- character(); diagnostics <- list(); mapping <- "visualization_only"
  publish <- function(code, suffix, engine_name, caption = NULL) {
    plot <- paste0(stem, "_", engine_name, "_", gsub("-", "_", safe_id(suffix), fixed=TRUE))
    filename <- paste0(a$id, "-", engine_name, "-", safe_id(suffix), ".png")
    intro <- if (engine_name == "bettergg") c(
      'if (!requireNamespace("BetterGG", quietly = TRUE)) stop("Install the public BetterGG package before running BetterGG plots.")',
      'if (grepl("emscripten", R.version$platform)) stop("BetterGG preview is local-only in this release. Run this code in native R.")') else character()
    figure <- options$figures
    output <- c(intro, if (!is.null(caption)) paste0("# ", caption),
      paste0(plot, " <- ", code),
      if (options$style$grayscale && engine_name == "ggplot2") paste0(plot, " <- ", plot, " + ggplot2::scale_fill_grey() + ggplot2::scale_colour_grey()"),
      paste0("if (interactive() || isTRUE(getOption(\"knitr.in.progress\"))) print(",plot,")"),
      paste0("ggplot2::ggsave(filename = ", r_string(paste0("figures/", filename)), ", plot = ", plot, ","),
      '  device = if (grepl("emscripten", R.version$platform)) grDevices::png else ragg::agg_png,',
      paste0("  width = ", figure$width, ", height = ", figure$height,
        ", units = \"in\", dpi = ", figure$dpi, ", bg = ", r_string(figure$background), ")"),
      if(isTRUE(figure$optimize_png))paste0("jmv2gg::optimize_png(",r_string(paste0("figures/",filename)),")"))
    plots[[length(plots) + 1L]] <<- list(id = plot, analysis_id = a$id, engine = engine_name,
      filename = paste0("figures/", filename), preview = if(engine_name == "bettergg") "local_only" else "requires_runtime_test",
      statistical_note = caption)
    bodies <<- c(bodies, paste(output, collapse = "\n"))
  }
  note <- function(message, code = "alternative_analysis") {
    diagnostics <<- c(diagnostics, list(diag_record("warning", code, message, a$id, a$line)))
    mapping <<- "alternative_analysis"
    message
  }
  q <- function(x) r_string(x)
  check_columns <- function(vars) {
    vars <- unique(vars)
    head <<- c(head, paste0("stopifnot(all(", r_text(vars), " %in% names(", d, ")))"))
  }
  factorize <- function(vars) {
    for (v in vars) head <<- c(head, paste0(d, "[[", q(v), "]] <- factor(", d, "[[", q(v), "]])"))
  }
  numeric_columns <- function(vars) {
    for(v in vars) head <<- c(head,paste0("if (!is.numeric(",d,"[[",q(v),"]])) {"),
      paste0("  ",mapped," <- attr(",d,"[[",q(v),"]], \"values\", exact = TRUE)"),
      paste0("  if (is.null(",mapped,") || !is.numeric(",mapped,")) stop(",q(paste0("Numeric outcome/covariate '",v,"' requires numeric data or an explicit numeric values mapping.")),")"),
      paste0("  ",d,"[[",q(v),"]] <- ",mapped,"[as.integer(",d,"[[",q(v),"]])]"),"}",
      paste0(d,"[[",q(v),"]] <- as.numeric(",d,"[[",q(v),"]])"))
  }
  theme <- "ggplot2::theme_classic(base_size = 12) + ggplot2::theme(plot.title.position = \"plot\", legend.position = \"bottom\")"
  error_level <- as.numeric(arg_value(a,"conf.level",as.numeric(arg_value(a,"ciWidthEmm",arg_value(a,"ciWidth",95)))/100))
  if (!is.finite(error_level) || error_level <= 0 || error_level >= 1) stop("CI width must be between 0 and 100.")
  finish <- function() list(code=paste(c("# jmv2gg generated block",
    paste0(stem,"_rng <- if (exists(\".Random.seed\", envir = .GlobalEnv, inherits = FALSE)) get(\".Random.seed\", envir = .GlobalEnv) else NULL"),
    paste0(stem,"_rng_kind <- RNGkind()"),
    "tryCatch({", 'dir.create("figures", showWarnings = FALSE, recursive = TRUE)',head,bodies,
    "}, finally = {",paste0("  do.call(RNGkind, as.list(",stem,"_rng_kind))"),
    paste0("  if (is.null(",stem,"_rng)) { if (exists(\".Random.seed\", envir = .GlobalEnv, inherits = FALSE)) rm(\".Random.seed\", envir = .GlobalEnv) } else assign(\".Random.seed\", ",stem,"_rng, envir = .GlobalEnv)"),"})"),collapse="\n\n"),
    plots=plots,diagnostics=diagnostics,mapping=mapping)
  if(a$package %in% c("ggstatsplot","BetterGG") && "bettergg" %in% engines) {
    source_data<-paste0(stem,"_source_data")
    head<-append(head,paste0(source_data," <- ",d),after=2L)
    source_args<-a$args;source_args$data<-as.name(source_data)
    source_call<-as.call(c(list(call("::",as.name("BetterGG"),as.name(fn))),source_args))
    publish(r_text(source_call),"source","bettergg")
    mapping<-"equivalent"
    engines<-setdiff(engines,"bettergg")
    if(!length(engines))return(finish())
  }

  if (fn %in% c("ANOVA", "ancova", "ggbetweenstats")) {
    factors <- arg_variable(a, "factors", character())
    covs <- arg_variable(a, "covs", character())
    dv <- arg_variable(a, "dep")
    formula_expr <- a$args$formula
    if (!is.null(formula_expr)) {
      validate_formula_syntax(formula_expr)
      if (!is.call(formula_expr) || !identical(formula_expr[[1]], as.name("~")) || length(formula_expr) != 3) stop("Use an explicit outcome ~ predictors formula.")
      dv <- all.vars(formula_expr[[2]])
      factors <- setdiff(all.vars(formula_expr[[3]]), covs)
      rhs <- r_text(formula_expr[[3]])
    } else {
      if (fn == "ggbetweenstats") { dv <- arg_variable(a, "y"); factors <- arg_variable(a, "x") }
      terms <- arg_value(a,"modelTerms")
      rhs <- if(is.null(terms) && length(factors)>1L) paste(c(paste(r_name(factors),collapse=" * "),r_name(covs)),collapse=" + ") else model_terms(terms,c(factors,covs))
    }
    if (length(dv) != 1 || !length(factors)) stop("ANOVA needs one outcome and at least one factor.")
    if (length(intersect(dv, c(factors,covs)))) stop("The outcome cannot also be a predictor.")
    check_columns(c(dv, factors, covs)); numeric_columns(c(dv,covs)); factorize(factors)
    model <- paste0(stem, "_model"); emm <- paste0(stem, "_means")
    for (v in factors) head <- c(head, paste0("if (nlevels(", d, "[[", q(v), "]]) < 2L) stop(\"A factor has fewer than two observed levels.\")"),
      paste0(d,"[[",q(v),"]] <- stats::`contrasts<-`(",d,"[[",q(v),"]], value = stats::contr.sum(nlevels(",d,"[[",q(v),"]])))"))
    formula <- paste(r_name(dv), "~", rhs)
    head <- c(head, paste0(model, " <- stats::lm(", formula, ", data = ", d, ", weights = ",w,", na.action = stats::na.omit)"))
    weights <- if (isTRUE(arg_value(a, "emmWeights", TRUE))) "equal" else "proportional"
    head <- c(head, paste0(emm, " <- as.data.frame(stats::confint(emmeans::emmeans(", model, ", specs = ~ ",
      paste(r_name(factors), collapse = " * "), ", weights = ", q(weights), "), level = ", error_level, "))"))
    x <- factors[1]
    if ("ggplot2" %in% engines) {
      layers <- c(paste0("ggplot2::ggplot(", d, ", ggplot2::aes(x = .data[[", q(x), "]], y = .data[[", q(dv), "]]))"))
      if (options$style$show_violin) layers <- c(layers, 'ggplot2::geom_violin(fill = "grey85", colour = "grey55", alpha = .5, na.rm = TRUE)')
      if (options$style$show_jitter) layers <- c(layers, paste0("ggplot2::geom_point(position = ggplot2::position_jitter(width = ", options$style$jitter_width,
        ", height = ", options$style$jitter_height, ", seed = 1123), alpha = .25, size = 1, na.rm = TRUE)"))
      layers <- c(layers, paste0("ggplot2::geom_errorbar(data = ", emm, ", ggplot2::aes(x = .data[[", q(x), "]], ymin = lower.CL, ymax = upper.CL), inherit.aes = FALSE, width = .12)"),
        paste0("ggplot2::geom_point(data = ", emm, ", ggplot2::aes(x = .data[[", q(x), "]], y = emmean), inherit.aes = FALSE, size = 3)"),
        paste0("ggplot2::labs(x = ", q(x), ", y = ", q(dv), ", subtitle = \"Estimated marginal means and confidence intervals\")"), theme)
      if (length(factors) > 1) layers <- c(layers, paste0("ggplot2::facet_wrap(~ ", paste(r_name(factors[-1]), collapse=" + "), ")"))
      publish(paste(layers, collapse = " +\n  "), "means", "ggplot2")
    }
    if ("bettergg" %in% engines) {
      msg <- note(if(length(factors) > 1 || length(covs))
        "BetterGG shows a separate one-way comparison. It does not test the original factorial interaction or adjust for covariates."
        else "BetterGG calculates its own comparison and pairwise tests; these are additional to the original jamovi results.")
      msg <- paste(msg,"This additional BetterGG comparison does not apply case weights.")
      diagnostics[[length(diagnostics)]]$message <- msg
      bd <- paste0(stem,"_bettergg_data")
      publish(paste0("{\n  ",bd," <- data.frame(group = ",d,"[[",q(x),"]], outcome = ",d,"[[",q(dv),"]])\n  ",
        "BetterGG::ggbetweenstats(data = ",bd,", x = group, y = outcome, xlab = ",q(x),", ylab = ",q(dv),
        ", type = ",q(arg_value(a,"type","parametric")),", var.equal = ",if(isTRUE(arg_value(a,"var.equal",TRUE)))"TRUE" else "FALSE",", bf.message = FALSE, conf.level = ",error_level,
        ", title = ",q(paste(dv,"by",x)),")\n}"),"comparison","bettergg",msg)
    }
  } else if (fn %in% c("descriptives", "gghistostats")) {
    vars <- arg_variable(a, "vars", arg_variable(a, "x"))
    if (!length(vars)) stop("No descriptive variables supplied.")
    split <- arg_variable(a, "splitBy", character())
    check_columns(c(vars, split))
    for (i in seq_along(vars)) {
      v <- vars[i]
      if ("ggplot2" %in% engines) {
        numeric <- paste0("ggplot2::ggplot(", d, ", ggplot2::aes(x = .data[[", q(v), "]], weight = ",w,")) + ggplot2::geom_histogram(bins = 30, fill = \"#176b74\", colour = \"white\", na.rm = TRUE)")
        categorical <- paste0("ggplot2::ggplot(", d, ", ggplot2::aes(x = factor(.data[[", q(v), "]]), weight = ",w,")) + ggplot2::geom_bar(fill = \"#176b74\", na.rm = TRUE) + ggplot2::labs(x = ", q(v), ", y = \"Count\")")
        suffix <- if(length(split)) paste0(" + ggplot2::facet_wrap(~ ",paste(r_name(split),collapse=" + "),")") else ""
        publish(paste0("(if (is.numeric(",d,"[[",q(v),"]]) && !inherits(", d,"[[",q(v),"]], \"haven_labelled\")) {\n  ",numeric,"\n} else {\n  ",categorical,"\n}) + ",theme,suffix), paste0("variable-",i), "ggplot2")
      }
      if ("bettergg" %in% engines) {
        msg <- note(paste("The BetterGG descriptive plot may add a distribution/proportion test absent from the original descriptive analysis. It does not apply case weights.",
          if(length(split))"This additional plot pools the source splitBy strata; the ggplot2 figure preserves them." else ""))
        bd<-paste0(stem,"_bettergg_variable_",i)
        pie<-paste0(bd,"_plot")
        publish(paste0("{\n",bd," <- data.frame(value = ",d,"[[",q(v),"]])\nif (is.numeric(",bd,"$value) && !inherits(",bd,"$value, \"haven_labelled\")) {\n",
          "  BetterGG::gghistostats(data = ",bd,", x = value, xlab = ",q(v),", bf.message = FALSE)\n} else {\n",
          "  ",pie," <- BetterGG::ggpiestats(data = ",bd,", x = value, title = ",q(v),", palette = if (nlevels(factor(",bd,"$value)) <= 8L) \"ggsci::default_nejm\" else \"palettesForR::Named\", bf.message = FALSE) +\n",
          "    ggplot2::guides(fill = ggplot2::guide_legend(ncol = 4, byrow = TRUE)) +\n",
          "    ggplot2::theme(legend.position = \"bottom\", legend.text = ggplot2::element_text(size = 6), legend.key.size = grid::unit(.12, \"in\"), plot.subtitle = ggplot2::element_text(size = 8))\n",
          "  # Retain every category in the legend; omit overlapping slice labels above 12 categories.\n",
          "  if (nlevels(factor(",bd,"$value)) > 12L) ",pie,"$layers <- Filter(function(layer) !inherits(layer$geom, c(\"GeomLabel\", \"GeomLabelRepel\")), ",pie,"$layers)\n",
          "  ",pie,"\n}\n}"),paste0("variable-",i),"bettergg",msg)
      }
    }
  } else if (fn %in% c("contTables", "contTablesPaired", "propTest2", "propTestN", "ggbarstats", "ggpiestats")) {
    rows <- arg_variable(a,"rows",arg_variable(a,"x",arg_variable(a,"var",arg_variable(a,"vars"))))
    cols <- arg_variable(a,"cols",arg_variable(a,"y"))
    if (!length(rows)) stop("Categorical plot needs row variables.")
    if (length(rows) != 1 || length(cols) > 1) stop("Use one categorical row and optional column variable per analysis.")
    counts <- arg_variable(a,"counts")
    layers <- arg_variable(a,"layers",character())
    check_columns(c(rows,cols,counts,layers))
    keep<-paste0(stem,"_complete")
    head<-c(head,paste0(keep," <- stats::complete.cases(",d,"[, ",r_text(c(rows,cols,counts,layers)),", drop = FALSE])"),
      paste0(w," <- ",w,"[",keep,"]"),paste0(d," <- ",d,"[",keep,", , drop = FALSE]"))
    if ("ggplot2" %in% engines) {
      aes <- paste0("x = factor(.data[[",q(rows),"]])",if(length(cols)) paste0(", fill = factor(.data[[",q(cols),"]])") else "",
        if(length(counts)) paste0(", weight = .data[[",q(counts),"]] * ",w) else paste0(", weight = ",w))
      code <- paste0("ggplot2::ggplot(",d,", ggplot2::aes(",aes,")) + ggplot2::geom_bar(position = \"dodge\", na.rm = TRUE) + ",
        "ggplot2::labs(x = ",q(rows),", y = \"Count\", fill = ",if(length(cols))q(cols) else "NULL",
        ") + ",theme,if(length(layers)) paste0(" + ggplot2::facet_wrap(~ ",paste(r_name(layers),collapse=" + "),")") else "")
      publish(code,"counts","ggplot2")
    }
    if ("bettergg" %in% engines) {
      if (length(counts) || fn == "contTablesPaired") {
        diagnostics <- c(diagnostics,list(diag_record("warning","bettergg_mapping_unavailable",
          "No faithful BetterGG mapping is provided for weighted or paired categorical data. Keep the ggplot2 count plot and original inference.",a$id,a$line)))
      } else {
        msg <- note(paste("BetterGG runs its own unweighted categorical test; inspect its test choice and denominators against the original analysis.",
          if(length(layers))"This additional test pools the source layers; the ggplot2 figure preserves them." else ""))
        bd<-paste0(stem,"_bettergg_data")
        publish(paste0("{\n",bd," <- data.frame(category = ",d,"[[",q(rows),"]]",if(length(cols))paste0(", group = ",d,"[[",q(cols),"]]")else "",")\nBetterGG::",
          if(length(cols))"ggbarstats" else "ggpiestats","(data = ",bd,", x = category",if(length(cols))", y = group"else "",
          ", title = ",q(paste(c(rows,cols),collapse=" by ")),", palette = \"palettesForR::Named\", bf.message = FALSE)\n}"),"categorical","bettergg",msg)
      }
    }
  } else if(fn=="ggscatterstats") {
    x<-arg_variable(a,"x");y<-arg_variable(a,"y")
    if(length(x)!=1L || length(y)!=1L)stop("Scatterplots need explicit x and y columns.")
    check_columns(c(x,y));numeric_columns(c(x,y))
    if("ggplot2" %in% engines)publish(paste0("ggplot2::ggplot(",d,", ggplot2::aes(x = .data[[",q(x),"]], y = .data[[",q(y),"]])) + ",
      "ggplot2::geom_point(alpha = .5, na.rm = TRUE) + ggplot2::labs(x = ",q(x),", y = ",q(y),") + ",theme),"scatter","ggplot2")
  } else if (fn %in% c("corrMatrix","corrPart","ggcorrmat")) {
    vars <- arg_variable(a,"vars",c(arg_variable(a,"x"),arg_variable(a,"y")))
    controls <- arg_variable(a,"controls",character())
    if (length(vars) < 2) stop("Correlation visualization needs at least two variables.")
    if (length(controls)) stop("Partial correlation mapping requires explicit adjusted-data handling; original inference is preserved.")
    check_columns(vars)
    method <- if(isTRUE(arg_value(a,"spearman",FALSE))) "spearman" else if(isTRUE(arg_value(a,"kendall",FALSE))) "kendall" else "pearson"
    cor_data <- paste0(stem,"_correlation_data")
    head <- c(head,paste0("if (any(",w," != 1, na.rm = TRUE)) stop(\"Weighted correlation mapping is unavailable. Keep the original analysis rather than substituting an unweighted correlation.\")"))
    head <- c(head,"# Match jamovi's explicit numeric values mapping; ordinary nominal Pearson cells stay undefined.",
      paste0(cor_data," <- as.data.frame(lapply(",d,"[, ",r_text(vars),", drop = FALSE], function(x) {"),
      "  if (is.numeric(x)) return(x)",
      "  mapped <- attr(x, \"values\", exact = TRUE)",
      "  if (!is.null(mapped)) return(mapped[as.integer(x)])",
      if(method=="pearson") "  rep(NA_real_, length(x))" else "  as.numeric(x)",
      "}), check.names = FALSE)")
    if ("ggplot2" %in% engines) {
      mat <- paste0(stem,"_correlations"); tab <- paste0(stem,"_correlation_table")
      head <- c(head,paste0(mat," <- stats::cor(",cor_data,", use = \"pairwise.complete.obs\", method = ",q(method),")"),
        paste0(tab," <- as.data.frame(as.table(",mat,"), stringsAsFactors = FALSE)"))
      publish(paste0("ggplot2::ggplot(",tab,", ggplot2::aes(x = Var1, y = Var2, fill = Freq)) + ggplot2::geom_tile() + ",
        "ggplot2::scale_fill_gradient2(low = \"#ac3d48\", mid = \"white\", high = \"#176b74\", limits = c(-1, 1), na.value = \"grey85\", name = ",q(method),") + ggplot2::coord_equal() + ",theme,
        " + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) + ggplot2::labs(x = NULL, y = NULL)"),"matrix","ggplot2")
    }
    if ("bettergg" %in% engines) {
      msg <- note("BetterGG computes additional correlation tests/corrections and omits undefined nonnumeric Pearson variables. This differs from the original matrix presentation.")
      publish(paste0("BetterGG::ggcorrmat(data = ",cor_data,"[, vapply(",cor_data,", function(x) sum(!is.na(x)) > 1L, logical(1)), drop = FALSE], type = ",q(if(method=="pearson")"parametric" else "nonparametric"),")"),"matrix","bettergg",msg)
    }
  } else if (fn == "logRegBin") {
    dv <- arg_variable(a,"dep"); factors <- arg_variable(a,"factors",character()); covs <- arg_variable(a,"covs",character())
    if (length(dv)!=1) stop("Logistic regression needs one outcome.")
    blocks <- arg_value(a,"blocks")
    terms <- if(length(blocks)) blocks[[length(blocks)]] else NULL
    rhs <- model_terms(terms,c(factors,covs))
    check_columns(c(dv,factors,covs)); numeric_columns(covs); factorize(c(dv,factors))
    refs <- arg_value(a,"refLevels",list())
    for(ref in refs) if(is.list(ref) && length(ref$var)==1 && length(ref$ref)==1)
      head <- c(head,paste0(d,"[[",q(ref$var),"]] <- stats::relevel(factor(",d,"[[",q(ref$var),"]]), ref = ",q(ref$ref),")"))
    model <- paste0(stem,"_model"); tab <- paste0(stem,"_coefficients")
    head <- c(head,paste0("if (nlevels(",d,"[[",q(dv),"]]) != 2L) stop(\"The logistic outcome must have exactly two levels.\")"),
      paste0(model," <- stats::glm(",r_name(dv)," ~ ",rhs,", data = ",d,", weights = ",w,", family = stats::binomial(), na.action = stats::na.omit)"),
      paste0("if (!isTRUE(",model,"$converged) || any(!is.finite(stats::coef(",model,")))) stop(\"Logistic model did not converge or has unestimable coefficients.\")"),
      paste0(tab," <- as.data.frame(summary(",model,")$coefficients)"),
      paste0(tab,"$term <- rownames(",tab,")"),
      paste0(tab,"$estimate <- ",tab,"[[\"Estimate\"]]"),
      paste0(tab,"$conf.low <- ",tab,"$estimate - stats::qnorm(",(1+error_level)/2,") * ",tab,"[[\"Std. Error\"]]"),
      paste0(tab,"$conf.high <- ",tab,"$estimate + stats::qnorm(",(1+error_level)/2,") * ",tab,"[[\"Std. Error\"]]"))
    if ("ggplot2" %in% engines) publish(paste0("ggplot2::ggplot(",tab,", ggplot2::aes(x = estimate, y = term)) + ",
      "ggplot2::geom_vline(xintercept = 0, linetype = 2, colour = \"grey65\") + ggplot2::geom_errorbar(ggplot2::aes(xmin = conf.low, xmax = conf.high), orientation = \"y\", width = .15) + ggplot2::geom_point(size = 2.5) + ",
      "ggplot2::labs(x = \"Log odds coefficient (Wald confidence interval)\", y = NULL) + ",theme),"coefficients","ggplot2")
    if ("bettergg" %in% engines) {
      msg <- note("BetterGG uses its own coefficient extraction and interval method. Compare these intervals with the explicitly Wald-based ggplot2 plot.")
      publish(paste0("BetterGG::ggcoefstats(x = ",model,", conf.level = ",error_level,", bf.message = FALSE)"),"coefficients","bettergg",msg)
    }
  } else if(fn %in% c("ttestPS","anovaRM","ggwithinstats")) {
    long <- paste0(stem,"_long"); model <- paste0(stem,"_model"); emm <- paste0(stem,"_means")
    bs <- arg_variable(a,"bs",character()); covs <- arg_variable(a,"cov",character())
    rm_names <- character()
    if(fn=="ggwithinstats") {
      subject <- arg_variable(a,"subject.id")
      x <- arg_variable(a,"x"); y <- arg_variable(a,"y")
      if(length(subject)!=1L || length(x)!=1L || length(y)!=1L) stop("Long-form paired data requires explicit subject.id, x and y names.")
      check_columns(c(subject,x,y)); rm_names<-x
      head<-c(head,paste0(long," <- ",d),paste0(long,"$.jmv2gg_subject <- factor(",long,"[[",q(subject),"]])"),paste0(long,"$.jmv2gg_value <- ",long,"[[",q(y),"]]"))
    } else {
      if(fn=="ttestPS") {
        pairs<-arg_value(a,"pairs")
        if(length(pairs)!=1L || !is.list(pairs[[1]])) stop("Use one explicit i1/i2 pair per paired t-test for this mapping.")
        pair<-pairs[[1]]
        measures<-as.character(c(pair$i1 %||% pair[[1]],pair$i2 %||% pair[[2]]))
        rm_names<-".jmv2gg_condition"; rm_defs<-list(list(label=rm_names,levels=measures))
        cells<-lapply(measures,function(v)list(measure=v,cell=v))
      } else {
        rm_defs<-arg_value(a,"rm");cells<-arg_value(a,"rmCells")
        if(!length(rm_defs) || !length(cells)) stop("Repeated-measures conversion needs literal rm and rmCells mappings.")
        rm_names<-vapply(rm_defs,function(x)x$label,character(1));measures<-vapply(cells,function(x)x$measure,character(1))
        if(anyDuplicated(measures)) stop("Repeated measure columns are duplicated.")
      }
      check_columns(c(measures,bs,covs)); numeric_columns(c(measures,covs))
      head<-c(head,paste0(d," <- ",d,"[stats::complete.cases(",d,"[, ",r_text(c(measures,bs,covs)),", drop = FALSE]), , drop = FALSE]"))
      pieces<-character()
      for(i in seq_along(cells)) {
        cell<-cells[[i]]
        if(length(cell$cell)!=length(rm_names)) stop("Each repeated-measures cell must identify every within-subject factor.")
        values<-paste0(r_text(".jmv2gg_value")," = ",d,"[[",q(cell$measure),"]], .jmv2gg_subject = factor(seq_len(nrow(",d,")))")
        for(j in seq_along(rm_names))values<-paste0(values,", ",r_name(rm_names[j])," = ",q(cell$cell[j]))
        for(v in c(bs,covs))values<-paste0(values,", ",r_name(v)," = ",d,"[[",q(v),"]]")
        pieces<-c(pieces,paste0("data.frame(",values,", check.names = FALSE)"))
      }
      head<-c(head,paste0(long," <- rbind(\n",paste(pieces,collapse=",\n"),"\n)"))
    }
    for(i in seq_along(rm_names)) {
      levels <- if(fn=="ggwithinstats") NULL else rm_defs[[i]]$levels
      head<-c(head,paste0(long,"[[",q(rm_names[i]),"]] <- factor(",long,"[[",q(rm_names[i]),"]]",if(length(levels))paste0(", levels = ",r_text(levels))else "",")"))
    }
    for(v in bs)head<-c(head,paste0(long,"[[",q(v),"]] <- factor(",long,"[[",q(v),"]])"))
    within_rhs<-paste(r_name(rm_names),collapse=" * ")
    if(!is.null(a$args$rmTerms)) {
      validate_formula_syntax(a$args$rmTerms)
      within_rhs<-r_text(a$args$rmTerms[[length(a$args$rmTerms)]])
    }
    between_rhs<-paste(r_name(bs),collapse=" * ")
    if(!is.null(a$args$bsTerms)) {
      validate_formula_syntax(a$args$bsTerms)
      between_rhs<-r_text(a$args$bsTerms[[length(a$args$bsTerms)]])
    }
    rhs<-if(nzchar(between_rhs))paste0("(",between_rhs,") * (",within_rhs,")") else within_rhs
    if(length(covs)) rhs<-paste(rhs,paste(r_name(covs),collapse=" + "),sep=" + ")
    head<-c(head,'if (grepl("emscripten", R.version$platform)) stop("This repeated-measures preview requires local R and afex. Conversion is still available.")',
      paste0("if (any(",w," != 1, na.rm = TRUE)) stop(\"Weighted repeated-measures mapping is not supported. Original inference is preserved.\")"),
      paste0(model," <- afex::aov_car(.jmv2gg_value ~ ",rhs," + Error(.jmv2gg_subject/(",paste(r_name(rm_names),collapse=" * "),")), data = ",long,", factorize = FALSE)"),
      paste0(emm," <- as.data.frame(stats::confint(emmeans::emmeans(",model,", ~ ",paste(r_name(c(rm_names,bs)),collapse=" * "),"), level = ",error_level,"))"))
    x<-rm_names[1]
    if("ggplot2" %in% engines) {
      code<-paste0("ggplot2::ggplot(",long,", ggplot2::aes(x = .data[[",q(x),"]], y = .jmv2gg_value)) + ggplot2::geom_line(ggplot2::aes(group = .jmv2gg_subject), alpha = .12) + ",
        "ggplot2::geom_point(position = ggplot2::position_jitter(width = .06, seed = 1123), alpha = .25) + ",
        "ggplot2::geom_errorbar(data = ",emm,", ggplot2::aes(x = .data[[",q(x),"]], ymin = lower.CL, ymax = upper.CL), inherit.aes = FALSE, width = .1) + ",
        "ggplot2::geom_point(data = ",emm,", ggplot2::aes(x = .data[[",q(x),"]], y = emmean), inherit.aes = FALSE, size = 3) + ",theme)
      facets<-c(rm_names[-1],bs)
      if(length(facets))code<-paste0(code," + ggplot2::facet_wrap(~ ",paste(r_name(facets),collapse=" + "),")")
      publish(code,"paired-means","ggplot2")
    }
    if("bettergg" %in% engines) {
      msg<-note("BetterGG shows a separate paired comparison on complete cases. Higher-order within/between interactions or covariate adjustments are not reproduced.")
      if(length(rm_names)>1L || length(bs) || length(covs)) {
        diagnostics<-c(diagnostics,list(diag_record("warning","bettergg_mapping_unavailable","Use the model-based ggplot2 figure for this factorial repeated-measures design; no pooled paired comparison is generated.",a$id,a$line)))
      } else publish(paste0("BetterGG::ggwithinstats(data = ",long,", x = ",r_name(x),", y = .jmv2gg_value, subject.id = .jmv2gg_subject, bf.message = FALSE)"),"paired","bettergg",msg)
    }
  } else if(fn %in% c("ttestIS","ttestOneS")) {
    vars <- arg_variable(a,"vars"); group <- arg_variable(a,"group")
    check_columns(c(vars,group)); numeric_columns(vars)
    for(i in seq_along(vars)) {
      v <- vars[i]
      if("ggplot2" %in% engines) {
        if(length(group)) code <- paste0("ggplot2::ggplot(",d,", ggplot2::aes(x = factor(.data[[",q(group),"]]), y = .data[[",q(v),"]])) + ggplot2::geom_boxplot(outlier.shape = NA) + ggplot2::geom_point(position = ggplot2::position_jitter(width = .12, seed = 1123), alpha = .3) + ",theme)
        else code <- paste0("ggplot2::ggplot(",d,", ggplot2::aes(x = .data[[",q(v),"]])) + ggplot2::geom_histogram(bins = 30, fill = \"#176b74\", colour = \"white\") + ggplot2::geom_vline(xintercept = ",arg_value(a,"testValue",0),", linetype = 2) + ",theme)
        publish(code,paste0("variable-",i),"ggplot2")
      }
      if("bettergg" %in% engines) {
        msg <- note("BetterGG supplies an additional unweighted comparison. Review case weights, variance, direction, and multiplicity settings against the source t-test.")
        code <- if(length(group)) paste0("BetterGG::ggbetweenstats(data = ",d,", x = ",r_name(group),", y = ",r_name(v),", var.equal = ",if(isTRUE(arg_value(a,"welchs",FALSE)))"FALSE" else "TRUE",", bf.message = FALSE)") else
          paste0("BetterGG::gghistostats(data = ",d,", x = ",r_name(v),", test.value = ",arg_value(a,"testValue",0),", bf.message = FALSE)")
        publish(code,paste0("variable-",i),"bettergg",msg)
      }
    }
  } else stop("Mapping is not yet implemented for ",fn,". Original code and inference are preserved.")
  if(!length(plots)) stop("No faithful requested plot mapping is available for this analysis.")
  finish()
}

validate_formula_syntax <- function(x) {
  if(is.symbol(x) || is.numeric(x) || is.null(x)) return(invisible(TRUE))
  if(!is.call(x) || !is.symbol(x[[1]]) || !as.character(x[[1]]) %in% c("~","+","-","*",":","^","("))
    stop("Formula contains a computed expression. Use explicit outcome/predictor names and modelTerms; the source is preserved without execution.")
  for(arg in as.list(x)[-1]) validate_formula_syntax(arg)
  invisible(TRUE)
}
