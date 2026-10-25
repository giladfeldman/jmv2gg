# (b) generated code matches its snapshot

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- anova_1: jmv::ANOVA (line 1) ------------------------------------------
      # Source: jmv::ANOVA(data = d, dep = "y", factors = "g")
      # Figure: every observation of y and its distribution in each group of g,
      #         with the estimated marginal means and their 95% confidence
      #         intervals from the model y ~ g (sum-to-zero contrasts, equal cell
      #         weights).
      # Differs from jamovi: nothing known.
      anova_1_ready <- figure_try("anova_1", {
        # Analysis data: a copy of d as it is at this point.
        anova_1_input <- d
        if (!is.data.frame(anova_1_input)) stop("The analysis data must be a data frame.")
        anova_1_missing <- setdiff(c("y", "g"), names(anova_1_input))
        if (length(anova_1_missing)) stop("Column(s) not found: ", toString(anova_1_missing))
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in "y") {
          values <- anova_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          anova_1_input[[column]] <- as.numeric(values)
        }
        # Case weights are not applied: jamovi's ANOVA and ANCOVA do not use them.
        anova_1_factors <- "g"
        anova_1_covariates <- character(0)
        # Factors (SPSS value labels name the levels) with sum-to-zero contrasts, as in jamovi.
        for (column in anova_1_factors) {
          values <- anova_1_input[[column]]
          anova_1_input[[column]] <- if (inherits(values, "haven_labelled")) haven::as_factor(values) else factor(values)
          if (nlevels(anova_1_input[[column]]) < 2L) stop("Factor ", column, " has fewer than two observed levels.")
        }
        anova_1_model_data <- anova_1_input
        for (column in anova_1_factors) {
          stats::contrasts(anova_1_model_data[[column]]) <- stats::contr.sum(nlevels(anova_1_model_data[[column]]))
        }
        # Model: the jamovi-equivalent linear model y ~ g.
        anova_1_model <- stats::lm(y ~ g, data = anova_1_model_data, na.action = stats::na.omit)
        # Estimated marginal means and 95% confidence intervals (equal cell weights).
        anova_1_means <- as.data.frame(stats::confint(emmeans::emmeans(anova_1_model, specs = anova_1_factors, weights = "equal"), level = 0.95))
      })
      
      # ggplot2 figure: y: observations, their distribution and model-based means with 95% CIs.
      if (anova_1_ready) figure_try("anova_1-ggplot2", {
        # 1. Data: rows with both "g" and "y"; the groups become a factor.
        anova_1_data <- anova_1_input[!is.na(anova_1_input[["g"]]) & !is.na(anova_1_input[["y"]]), , drop = FALSE]
        anova_1_data[["g"]] <- droplevels(as.factor(anova_1_data[["g"]]))
      
        # 2. Group sizes and the group mean shown as a labelled point.
        anova_1_groups <- split(anova_1_data[["y"]], anova_1_data[["g"]])
        anova_1_summary <- data.frame(
          level = factor(names(anova_1_groups), levels = levels(anova_1_data[["g"]])),
          value = vapply(anova_1_groups, function(values) mean(values), numeric(1)),
          n = lengths(anova_1_groups)
        )
        # Model-based means and confidence intervals replace the observed means.
        anova_1_match <- match(as.character(anova_1_summary$level), as.character(anova_1_means[["g"]]))
        if (anyNA(anova_1_match)) stop("The model means do not cover every group of g.")
        anova_1_summary$value <- anova_1_means$emmean[anova_1_match]
        anova_1_summary$lower <- anova_1_means$lower.CL[anova_1_match]
        anova_1_summary$upper <- anova_1_means$upper.CL[anova_1_match]
        anova_1_summary$label <- paste0("list(widehat(mu)['EMM']=='",
          formatC(anova_1_summary$value, format = "f", digits = 2), "')")
        anova_1_summary$axis_label <- paste0(anova_1_summary$level, "\n(n = ",
          prettyNum(anova_1_summary$n, big.mark = ","), ")")
      
        # 3. The figure
        anova_1_plot <- ggplot2::ggplot(anova_1_data, ggplot2::aes(x = g, y = y)) +
          # cloud: the distribution of each group (half density)
          ggdist::stat_slab(ggplot2::aes(fill = g, group = g), colour = NA, adjust = 1,
            width = 0.5, justification = -0.25, alpha = 0.5, normalize = "groups") +
          # rain: every observation as a dot at its exact value, filled with its outline colour
          ggdist::stat_dots(ggplot2::aes(colour = g, group = g, fill = ggplot2::after_scale(colour)),
            side = "left", justification = 1.2, scale = 0.45, alpha = 0.7, layout = "swarm", family = figure_font,
            show.legend = c(fill = FALSE)) +
          # box: median and quartiles
          ggplot2::geom_boxplot(ggplot2::aes(group = g), width = 0.12, alpha = 0.6, outlier.shape = NA, na.rm = TRUE) +
          # model-based confidence intervals
          ggplot2::geom_errorbar(data = anova_1_summary, ggplot2::aes(x = level, ymin = lower, ymax = upper),
            inherit.aes = FALSE, width = 0.08, linewidth = 0.6) +
          # group model means: point and label
          ggplot2::geom_point(data = anova_1_summary, ggplot2::aes(x = level, y = value),
            inherit.aes = FALSE, size = 4, colour = "black") +
          ggrepel::geom_label_repel(data = anova_1_summary, ggplot2::aes(x = level, y = value, label = label),
            inherit.aes = FALSE, parse = TRUE, size = 3, nudge_x = 0.4, segment.linetype = 4,
            min.segment.length = 0, family = figure_font) +
          ggplot2::scale_x_discrete(labels = anova_1_summary$axis_label) +
          ggplot2::scale_y_continuous(sec.axis = ggplot2::dup_axis(name = NULL, breaks = NULL, labels = NULL)) +
          ggplot2::scale_colour_manual(values = figure_colours) +
          ggplot2::scale_fill_manual(values = figure_fills) +
          ggplot2::labs(x = "g", y = "y", colour = "g", title = NULL, subtitle = NULL, caption = NULL) +
          theme_figure() +
          ggplot2::theme(legend.position = "none", panel.grid.major.x = ggplot2::element_blank())
        figure_show(anova_1_plot)
        figure_save(anova_1_plot, "figures/anova_1-ggplot2")
      })
      
      # BetterGG figure: y: observations, their distribution and model-based means with 95% CIs.
      # Note: BetterGG's ggbetweenrain() shows the observed group means; the
      #       ggplot2 figure shows the jamovi model's means.
      if (anova_1_ready) figure_try("anova_1-bettergg", {
        anova_1_bettergg <- BetterGG::ggbetweenrain(
          data = anova_1_input, x = g, y = y, type = "parametric",
          conf.level = 0.95, results.subtitle = FALSE, pairwise.display = "none", bf.message = FALSE
        )
        figure_show(anova_1_bettergg)
        figure_save(anova_1_bettergg, "figures/anova_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- anova_1: jmv::ANOVA (line 1) ------------------------------------------
      # Source: jmv::ANOVA(formula = y ~ g * h, data = d)
      # Figure: every observation of y and its distribution in each cell of the
      #         design, with the estimated marginal means and their 95% confidence
      #         intervals from the model y ~ g * h (sum-to-zero contrasts, equal
      #         cell weights).
      # Differs from jamovi: nothing known.
      anova_1_ready <- figure_try("anova_1", {
        # Analysis data: a copy of d as it is at this point.
        anova_1_input <- d
        if (!is.data.frame(anova_1_input)) stop("The analysis data must be a data frame.")
        anova_1_missing <- setdiff(c("y", "g", "h"), names(anova_1_input))
        if (length(anova_1_missing)) stop("Column(s) not found: ", toString(anova_1_missing))
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in "y") {
          values <- anova_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          anova_1_input[[column]] <- as.numeric(values)
        }
        # Case weights are not applied: jamovi's ANOVA and ANCOVA do not use them.
        anova_1_factors <- c("g", "h")
        anova_1_covariates <- character(0)
        # Factors (SPSS value labels name the levels) with sum-to-zero contrasts, as in jamovi.
        for (column in anova_1_factors) {
          values <- anova_1_input[[column]]
          anova_1_input[[column]] <- if (inherits(values, "haven_labelled")) haven::as_factor(values) else factor(values)
          if (nlevels(anova_1_input[[column]]) < 2L) stop("Factor ", column, " has fewer than two observed levels.")
        }
        anova_1_model_data <- anova_1_input
        for (column in anova_1_factors) {
          stats::contrasts(anova_1_model_data[[column]]) <- stats::contr.sum(nlevels(anova_1_model_data[[column]]))
        }
        # Model: the jamovi-equivalent linear model y ~ g * h.
        anova_1_model <- stats::lm(y ~ g * h, data = anova_1_model_data, na.action = stats::na.omit)
        # Estimated marginal means and 95% confidence intervals (equal cell weights).
        anova_1_means <- as.data.frame(stats::confint(emmeans::emmeans(anova_1_model, specs = anova_1_factors, weights = "equal"), level = 0.95))
      })
      
      # ggplot2 figure: y: observations, their distribution and model-based means with 95% CIs.
      if (anova_1_ready) figure_try("anova_1-ggplot2", {
        # 1. Data: complete cases of the outcome, factors and covariates.
        anova_1_data <- anova_1_input[stats::complete.cases(anova_1_input[, c("y", "g", "h"), drop = FALSE]), c("y", "g", "h"), drop = FALSE]
        for (factor_name in c("g", "h")) {
          anova_1_data[[factor_name]] <- droplevels(as.factor(anova_1_data[[factor_name]]))
          if (nlevels(anova_1_data[[factor_name]]) < 2L) stop("Factor ", factor_name, " needs two observed levels.")
        }
      
        # 2. Model means supplied by the analysis (from its own model).
        anova_1_means <- as.data.frame(anova_1_means)
        for (factor_name in c("g", "h")) {
          anova_1_means[[factor_name]] <- factor(as.character(anova_1_means[[factor_name]]),
            levels = levels(anova_1_data[[factor_name]]))
        }
        if (anyNA(anova_1_means[c("g", "h")])) stop("The model means have levels not in the data.")
      
        # 3. Positions: x levels at 1, 2, ...; colour groups side by side within each.
        anova_1_k <- nlevels(anova_1_data[["h"]])
        anova_1_slot <- 0.8 / anova_1_k
        anova_1_place <- function(df) {
          as.integer(df[["g"]]) + (as.integer(df[["h"]]) - (anova_1_k + 1) / 2) * anova_1_slot
        }
        anova_1_data$x_position <- anova_1_place(anova_1_data)
        anova_1_data$rain_position <- anova_1_data$x_position - 0.2 * anova_1_slot
        anova_1_data$cell <- interaction(anova_1_data[c("g", "h")], drop = TRUE, lex.order = TRUE)
        anova_1_means$x_position <- anova_1_place(anova_1_means)
      
        # 4. The figure
        anova_1_plot <- ggplot2::ggplot(anova_1_data, ggplot2::aes(x = x_position, y = .data[["y"]])) +
          # cloud: the distribution of each cell (half density)
          ggdist::stat_slab(ggplot2::aes(fill = .data[["h"]], group = cell), orientation = "vertical",
            side = "right", justification = 0, width = anova_1_slot, scale = 0.45, colour = NA, alpha = 0.5,
            normalize = "groups") +
          # rain: every observation, slightly jittered sideways
          ggplot2::geom_point(ggplot2::aes(x = rain_position, colour = .data[["h"]]),
            position = ggplot2::position_jitter(width = 0.06 * anova_1_slot, height = 0, seed = 1123),
            size = 1.4, alpha = 0.5, stroke = 0) +
          # model means of each colour group joined across the x levels
          ggplot2::geom_line(data = anova_1_means,
            ggplot2::aes(x = x_position, y = emmean, colour = .data[["h"]], group = .data[["h"]]), inherit.aes = FALSE, linewidth = 0.6) +
          # estimated marginal means with 95% confidence intervals
          ggplot2::geom_errorbar(data = anova_1_means, ggplot2::aes(x = x_position, ymin = lower.CL, ymax = upper.CL),
            inherit.aes = FALSE, width = 0.12 * anova_1_slot, linewidth = 0.6) +
          ggplot2::geom_point(data = anova_1_means, ggplot2::aes(x = x_position, y = emmean, fill = .data[["h"]]),
            inherit.aes = FALSE, shape = 21, size = 3, colour = "black", stroke = 0.6) +
          ggplot2::scale_x_continuous(breaks = seq_len(nlevels(anova_1_data[["g"]])), labels = levels(anova_1_data[["g"]])) +
          ggplot2::scale_colour_manual(values = figure_colours) +
          ggplot2::scale_fill_manual(values = figure_fills) +
          ggplot2::labs(x = "g", y = "y", title = NULL, colour = "h", fill = "h", subtitle = NULL) +
          theme_figure() +
          ggplot2::theme(legend.position = "bottom", panel.grid.major.x = ggplot2::element_blank()) +
          # many or long level names are angled so they do not overlap
          (if (nlevels(anova_1_data[["g"]]) > 6L || sum(nchar(levels(anova_1_data[["g"]]))) > 60L)
            ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)))
        figure_show(anova_1_plot)
        figure_save(anova_1_plot, "figures/anova_1-ggplot2")
      })
      
      # BetterGG figure: y: observations, their distribution and model-based means with 95% CIs.
      # Note: BetterGG's ggfactorialrain() fits the full factorial model; the
      #       ggplot2 figure uses the jamovi-equivalent model.
      if (anova_1_ready) figure_try("anova_1-bettergg", {
        anova_1_bettergg <- BetterGG::ggfactorialrain(
          data = anova_1_input, x = "g", y = "y", colour = "h",
          covariates = NULL, conf.level = 0.95, stats = FALSE
        )
        figure_show(anova_1_bettergg)
        figure_save(anova_1_bettergg, "figures/anova_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- anova_1: jmv::ancova (line 1) -----------------------------------------
      # Source: jmv::ancova(formula = y ~ g + h + age, data = d)
      # Figure: every observation of y and its distribution in each cell of the
      #         design, with the estimated marginal means and their 95% confidence
      #         intervals from the model y ~ g + h + age (sum-to-zero contrasts,
      #         equal cell weights, covariates at their mean).
      # Differs from jamovi: nothing known.
      anova_1_ready <- figure_try("anova_1", {
        # Analysis data: a copy of d as it is at this point.
        anova_1_input <- d
        if (!is.data.frame(anova_1_input)) stop("The analysis data must be a data frame.")
        anova_1_missing <- setdiff(c("y", "g", "h", "age"), names(anova_1_input))
        if (length(anova_1_missing)) stop("Column(s) not found: ", toString(anova_1_missing))
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in "y") {
          values <- anova_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          anova_1_input[[column]] <- as.numeric(values)
        }
        # Case weights are not applied: jamovi's ANOVA and ANCOVA do not use them.
        # jamovi's ANCOVA formula rule: numeric columns are covariates, the others factors.
        anova_1_predictors <- c("g", "h", "age")
        anova_1_is_numeric <- vapply(anova_1_input[anova_1_predictors], is.numeric, logical(1))
        anova_1_factors <- anova_1_predictors[!anova_1_is_numeric]
        anova_1_covariates <- anova_1_predictors[anova_1_is_numeric]
        if (!length(anova_1_factors)) stop("ANCOVA needs at least one factor.")
        if (length(anova_1_factors) > 3L) stop("Figures cover designs with up to three factors.")
        # Factors (SPSS value labels name the levels) with sum-to-zero contrasts, as in jamovi.
        for (column in anova_1_factors) {
          values <- anova_1_input[[column]]
          anova_1_input[[column]] <- if (inherits(values, "haven_labelled")) haven::as_factor(values) else factor(values)
          if (nlevels(anova_1_input[[column]]) < 2L) stop("Factor ", column, " has fewer than two observed levels.")
        }
        anova_1_model_data <- anova_1_input
        for (column in anova_1_factors) {
          stats::contrasts(anova_1_model_data[[column]]) <- stats::contr.sum(nlevels(anova_1_model_data[[column]]))
        }
        # Model: the jamovi-equivalent linear model y ~ g + h + age.
        anova_1_model <- stats::lm(y ~ g + h + age, data = anova_1_model_data, na.action = stats::na.omit)
        # Estimated marginal means and 95% confidence intervals (equal cell weights; covariates at their mean).
        anova_1_means <- as.data.frame(stats::confint(emmeans::emmeans(anova_1_model, specs = anova_1_factors, weights = "equal"), level = 0.95))
      })
      
      # ggplot2 figure: y: observations, their distribution and model-based means with 95% CIs.
      if (anova_1_ready) figure_try("anova_1-ggplot2", {
        if (length(anova_1_factors) == 1L) {
          # 1. Data: complete cases of the outcome, factors and covariates.
          anova_1_data <- anova_1_input[stats::complete.cases(anova_1_input[, c("y", anova_1_factors[1], anova_1_covariates), drop = FALSE]), c("y", anova_1_factors[1], anova_1_covariates), drop = FALSE]
          for (factor_name in anova_1_factors[1]) {
            anova_1_data[[factor_name]] <- droplevels(as.factor(anova_1_data[[factor_name]]))
            if (nlevels(anova_1_data[[factor_name]]) < 2L) stop("Factor ", factor_name, " needs two observed levels.")
          }
      
          # 2. Model means supplied by the analysis (from its own model).
          anova_1_means <- as.data.frame(anova_1_means)
          for (factor_name in anova_1_factors[1]) {
            anova_1_means[[factor_name]] <- factor(as.character(anova_1_means[[factor_name]]),
              levels = levels(anova_1_data[[factor_name]]))
          }
          if (anyNA(anova_1_means[anova_1_factors[1]])) stop("The model means have levels not in the data.")
      
          # 3. Positions: x levels at 1, 2, ...
          anova_1_k <- 1L
          anova_1_slot <- 0.8 / anova_1_k
          anova_1_place <- function(df) as.integer(df[[anova_1_factors[1]]])
          anova_1_data$x_position <- anova_1_place(anova_1_data)
          anova_1_data$rain_position <- anova_1_data$x_position - 0.2 * anova_1_slot
          anova_1_data$cell <- interaction(anova_1_data[anova_1_factors[1]], drop = TRUE, lex.order = TRUE)
          anova_1_means$x_position <- anova_1_place(anova_1_means)
      
          # 4. The figure
          anova_1_plot <- ggplot2::ggplot(anova_1_data, ggplot2::aes(x = x_position, y = .data[["y"]])) +
            # cloud: the distribution of each cell (half density)
            ggdist::stat_slab(ggplot2::aes(fill = .data[[anova_1_factors[1]]], group = cell), orientation = "vertical",
              side = "right", justification = 0, width = anova_1_slot, scale = 0.45, colour = NA, alpha = 0.5,
              normalize = "groups") +
            # rain: every observation, slightly jittered sideways
            ggplot2::geom_point(ggplot2::aes(x = rain_position, colour = .data[[anova_1_factors[1]]]),
              position = ggplot2::position_jitter(width = 0.06 * anova_1_slot, height = 0, seed = 1123),
              size = 1.4, alpha = 0.5, stroke = 0) +
            # estimated marginal means with 95% confidence intervals
            ggplot2::geom_errorbar(data = anova_1_means, ggplot2::aes(x = x_position, ymin = lower.CL, ymax = upper.CL),
              inherit.aes = FALSE, width = 0.12 * anova_1_slot, linewidth = 0.6) +
            ggplot2::geom_point(data = anova_1_means, ggplot2::aes(x = x_position, y = emmean, fill = .data[[anova_1_factors[1]]]),
              inherit.aes = FALSE, shape = 21, size = 3, colour = "black", stroke = 0.6) +
            ggplot2::scale_x_continuous(breaks = seq_len(nlevels(anova_1_data[[anova_1_factors[1]]])), labels = levels(anova_1_data[[anova_1_factors[1]]])) +
            ggplot2::scale_colour_manual(values = figure_colours) +
            ggplot2::scale_fill_manual(values = figure_fills) +
            ggplot2::labs(x = anova_1_factors[1], y = "y", title = NULL, colour = anova_1_factors[1], fill = anova_1_factors[1], subtitle = NULL) +
            theme_figure() +
            ggplot2::theme(legend.position = "none", panel.grid.major.x = ggplot2::element_blank()) +
            # many or long level names are angled so they do not overlap
            (if (nlevels(anova_1_data[[anova_1_factors[1]]]) > 6L || sum(nchar(levels(anova_1_data[[anova_1_factors[1]]]))) > 60L)
              ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)))
        } else if (length(anova_1_factors) == 2L) {
          # 1. Data: complete cases of the outcome, factors and covariates.
          anova_1_data <- anova_1_input[stats::complete.cases(anova_1_input[, c("y", anova_1_factors[1], anova_1_factors[2], anova_1_covariates), drop = FALSE]), c("y", anova_1_factors[1], anova_1_factors[2], anova_1_covariates), drop = FALSE]
          for (factor_name in c(anova_1_factors[1], anova_1_factors[2])) {
            anova_1_data[[factor_name]] <- droplevels(as.factor(anova_1_data[[factor_name]]))
            if (nlevels(anova_1_data[[factor_name]]) < 2L) stop("Factor ", factor_name, " needs two observed levels.")
          }
      
          # 2. Model means supplied by the analysis (from its own model).
          anova_1_means <- as.data.frame(anova_1_means)
          for (factor_name in c(anova_1_factors[1], anova_1_factors[2])) {
            anova_1_means[[factor_name]] <- factor(as.character(anova_1_means[[factor_name]]),
              levels = levels(anova_1_data[[factor_name]]))
          }
          if (anyNA(anova_1_means[c(anova_1_factors[1], anova_1_factors[2])])) stop("The model means have levels not in the data.")
      
          # 3. Positions: x levels at 1, 2, ...; colour groups side by side within each.
          anova_1_k <- nlevels(anova_1_data[[anova_1_factors[2]]])
          anova_1_slot <- 0.8 / anova_1_k
          anova_1_place <- function(df) {
            as.integer(df[[anova_1_factors[1]]]) + (as.integer(df[[anova_1_factors[2]]]) - (anova_1_k + 1) / 2) * anova_1_slot
          }
          anova_1_data$x_position <- anova_1_place(anova_1_data)
          anova_1_data$rain_position <- anova_1_data$x_position - 0.2 * anova_1_slot
          anova_1_data$cell <- interaction(anova_1_data[c(anova_1_factors[1], anova_1_factors[2])], drop = TRUE, lex.order = TRUE)
          anova_1_means$x_position <- anova_1_place(anova_1_means)
      
          # 4. The figure
          anova_1_plot <- ggplot2::ggplot(anova_1_data, ggplot2::aes(x = x_position, y = .data[["y"]])) +
            # cloud: the distribution of each cell (half density)
            ggdist::stat_slab(ggplot2::aes(fill = .data[[anova_1_factors[2]]], group = cell), orientation = "vertical",
              side = "right", justification = 0, width = anova_1_slot, scale = 0.45, colour = NA, alpha = 0.5,
              normalize = "groups") +
            # rain: every observation, slightly jittered sideways
            ggplot2::geom_point(ggplot2::aes(x = rain_position, colour = .data[[anova_1_factors[2]]]),
              position = ggplot2::position_jitter(width = 0.06 * anova_1_slot, height = 0, seed = 1123),
              size = 1.4, alpha = 0.5, stroke = 0) +
            # model means of each colour group joined across the x levels
            ggplot2::geom_line(data = anova_1_means,
              ggplot2::aes(x = x_position, y = emmean, colour = .data[[anova_1_factors[2]]], group = .data[[anova_1_factors[2]]]), inherit.aes = FALSE, linewidth = 0.6) +
            # estimated marginal means with 95% confidence intervals
            ggplot2::geom_errorbar(data = anova_1_means, ggplot2::aes(x = x_position, ymin = lower.CL, ymax = upper.CL),
              inherit.aes = FALSE, width = 0.12 * anova_1_slot, linewidth = 0.6) +
            ggplot2::geom_point(data = anova_1_means, ggplot2::aes(x = x_position, y = emmean, fill = .data[[anova_1_factors[2]]]),
              inherit.aes = FALSE, shape = 21, size = 3, colour = "black", stroke = 0.6) +
            ggplot2::scale_x_continuous(breaks = seq_len(nlevels(anova_1_data[[anova_1_factors[1]]])), labels = levels(anova_1_data[[anova_1_factors[1]]])) +
            ggplot2::scale_colour_manual(values = figure_colours) +
            ggplot2::scale_fill_manual(values = figure_fills) +
            ggplot2::labs(x = anova_1_factors[1], y = "y", title = NULL, colour = anova_1_factors[2], fill = anova_1_factors[2], subtitle = NULL) +
            theme_figure() +
            ggplot2::theme(legend.position = "bottom", panel.grid.major.x = ggplot2::element_blank()) +
            # many or long level names are angled so they do not overlap
            (if (nlevels(anova_1_data[[anova_1_factors[1]]]) > 6L || sum(nchar(levels(anova_1_data[[anova_1_factors[1]]]))) > 60L)
              ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)))
        } else {
          # 1. Data: complete cases of the outcome, factors and covariates.
          anova_1_data <- anova_1_input[stats::complete.cases(anova_1_input[, c("y", anova_1_factors[1], anova_1_factors[2], anova_1_factors[3], anova_1_covariates), drop = FALSE]), c("y", anova_1_factors[1], anova_1_factors[2], anova_1_factors[3], anova_1_covariates), drop = FALSE]
          for (factor_name in c(anova_1_factors[1], anova_1_factors[2], anova_1_factors[3])) {
            anova_1_data[[factor_name]] <- droplevels(as.factor(anova_1_data[[factor_name]]))
            if (nlevels(anova_1_data[[factor_name]]) < 2L) stop("Factor ", factor_name, " needs two observed levels.")
          }
      
          # 2. Model means supplied by the analysis (from its own model).
          anova_1_means <- as.data.frame(anova_1_means)
          for (factor_name in c(anova_1_factors[1], anova_1_factors[2], anova_1_factors[3])) {
            anova_1_means[[factor_name]] <- factor(as.character(anova_1_means[[factor_name]]),
              levels = levels(anova_1_data[[factor_name]]))
          }
          if (anyNA(anova_1_means[c(anova_1_factors[1], anova_1_factors[2], anova_1_factors[3])])) stop("The model means have levels not in the data.")
      
          # 3. Positions: x levels at 1, 2, ...; colour groups side by side within each.
          anova_1_k <- nlevels(anova_1_data[[anova_1_factors[2]]])
          anova_1_slot <- 0.8 / anova_1_k
          anova_1_place <- function(df) {
            as.integer(df[[anova_1_factors[1]]]) + (as.integer(df[[anova_1_factors[2]]]) - (anova_1_k + 1) / 2) * anova_1_slot
          }
          anova_1_data$x_position <- anova_1_place(anova_1_data)
          anova_1_data$rain_position <- anova_1_data$x_position - 0.2 * anova_1_slot
          anova_1_data$cell <- interaction(anova_1_data[c(anova_1_factors[1], anova_1_factors[2], anova_1_factors[3])], drop = TRUE, lex.order = TRUE)
          anova_1_means$x_position <- anova_1_place(anova_1_means)
      
          # 4. The figure
          anova_1_plot <- ggplot2::ggplot(anova_1_data, ggplot2::aes(x = x_position, y = .data[["y"]])) +
            # cloud: the distribution of each cell (half density)
            ggdist::stat_slab(ggplot2::aes(fill = .data[[anova_1_factors[2]]], group = cell), orientation = "vertical",
              side = "right", justification = 0, width = anova_1_slot, scale = 0.45, colour = NA, alpha = 0.5,
              normalize = "groups") +
            # rain: every observation, slightly jittered sideways
            ggplot2::geom_point(ggplot2::aes(x = rain_position, colour = .data[[anova_1_factors[2]]]),
              position = ggplot2::position_jitter(width = 0.06 * anova_1_slot, height = 0, seed = 1123),
              size = 1.4, alpha = 0.5, stroke = 0) +
            # model means of each colour group joined across the x levels
            ggplot2::geom_line(data = anova_1_means,
              ggplot2::aes(x = x_position, y = emmean, colour = .data[[anova_1_factors[2]]], group = .data[[anova_1_factors[2]]]), inherit.aes = FALSE, linewidth = 0.6) +
            # estimated marginal means with 95% confidence intervals
            ggplot2::geom_errorbar(data = anova_1_means, ggplot2::aes(x = x_position, ymin = lower.CL, ymax = upper.CL),
              inherit.aes = FALSE, width = 0.12 * anova_1_slot, linewidth = 0.6) +
            ggplot2::geom_point(data = anova_1_means, ggplot2::aes(x = x_position, y = emmean, fill = .data[[anova_1_factors[2]]]),
              inherit.aes = FALSE, shape = 21, size = 3, colour = "black", stroke = 0.6) +
            ggplot2::scale_x_continuous(breaks = seq_len(nlevels(anova_1_data[[anova_1_factors[1]]])), labels = levels(anova_1_data[[anova_1_factors[1]]])) +
            ggplot2::scale_colour_manual(values = figure_colours) +
            ggplot2::scale_fill_manual(values = figure_fills) +
            ggplot2::labs(x = anova_1_factors[1], y = "y", title = NULL, colour = anova_1_factors[2], fill = anova_1_factors[2], subtitle = NULL) +
            theme_figure() +
            ggplot2::theme(legend.position = "bottom", panel.grid.major.x = ggplot2::element_blank()) +
            # many or long level names are angled so they do not overlap
            (if (nlevels(anova_1_data[[anova_1_factors[1]]]) > 6L || sum(nchar(levels(anova_1_data[[anova_1_factors[1]]]))) > 60L)
              ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1))) +
            ggplot2::facet_wrap(ggplot2::vars(.data[[anova_1_factors[3]]]), labeller = ggplot2::label_wrap_gen(width = 30))
        }
        figure_show(anova_1_plot)
        figure_save(anova_1_plot, "figures/anova_1-ggplot2")
      })
      
      # BetterGG figure: y: observations, their distribution and model-based means with 95% CIs.
      # Note: BetterGG fits its own model for this figure; the ggplot2 figure uses
      #       the jamovi-equivalent model.
      if (anova_1_ready) figure_try("anova_1-bettergg", {
        anova_1_bettergg <- BetterGG::ggfactorialrain(
          data = anova_1_input, x = anova_1_factors[1], y = "y",
          colour = if (length(anova_1_factors) > 1L) anova_1_factors[2], facet = if (length(anova_1_factors) > 2L) anova_1_factors[3],
          covariates = if (length(anova_1_covariates)) anova_1_covariates, conf.level = 0.95, stats = FALSE
        )
        figure_show(anova_1_bettergg)
        figure_save(anova_1_bettergg, "figures/anova_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- ttest_1: jmv::ttestPS (line 1) ----------------------------------------
      # Source: jmv::ttestPS(data = d, pairs = list(list(i1 = "pre", i2 = "post"),
      #         list(i1 = "pre", i2 = "mid")))
      # Figure: each participant's two values (joined by a dashed line), their
      #         distribution, and the two means.
      # Differs from jamovi: nothing known.
      ttest_1_ready <- figure_try("ttest_1", {
        # Analysis data: a copy of d as it is at this point.
        ttest_1_input <- d
        if (!is.data.frame(ttest_1_input)) stop("The analysis data must be a data frame.")
        ttest_1_missing <- setdiff(c("pre", "post", "mid"), names(ttest_1_input))
        if (length(ttest_1_missing)) stop("Column(s) not found: ", toString(ttest_1_missing))
        if (!is.null(attr(ttest_1_input, "jmv-weights", exact = TRUE))) {
          stop("Weighted paired t-test mapping is unavailable. Keep the original analysis rather than substituting an unweighted one.")
        }
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in c("pre", "post", "mid")) {
          values <- ttest_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          ttest_1_input[[column]] <- as.numeric(values)
        }
        # Long format for the pair pre - post: one row per participant and measure.
        ttest_1_1_long <- data.frame(
          subject = factor(rep(seq_len(nrow(ttest_1_input)), 2L)),
          measure = factor(rep(c("pre", "post"), each = nrow(ttest_1_input)), levels = c("pre", "post")),
          value = c(ttest_1_input[["pre"]], ttest_1_input[["post"]])
        )
        # Long format for the pair pre - mid: one row per participant and measure.
        ttest_1_2_long <- data.frame(
          subject = factor(rep(seq_len(nrow(ttest_1_input)), 2L)),
          measure = factor(rep(c("pre", "mid"), each = nrow(ttest_1_input)), levels = c("pre", "mid")),
          value = c(ttest_1_input[["pre"]], ttest_1_input[["mid"]])
        )
      })
      
      # ggplot2 figure: pre and post (paired).
      if (ttest_1_ready) figure_try("ttest_1-ggplot2-pre-post", {
        # 1. Data (long format): subjects with a value of "value" in every condition.
        ttest_1_1_data <- ttest_1_1_long[!is.na(ttest_1_1_long[["measure"]]) & !is.na(ttest_1_1_long[["subject"]]), , drop = FALSE]
        ttest_1_1_data[["measure"]] <- droplevels(as.factor(ttest_1_1_data[["measure"]]))
        if (anyDuplicated(ttest_1_1_data[, c("measure", "subject")])) {
          stop("Each subject must appear at most once per condition; aggregate repeated rows first.")
        }
        ttest_1_1_data <- ttest_1_1_data[!is.na(ttest_1_1_data[["value"]]), , drop = FALSE]
        ttest_1_1_count <- table(ttest_1_1_data[["subject"]])
        ttest_1_1_complete <- names(ttest_1_1_count)[ttest_1_1_count == nlevels(ttest_1_1_data[["measure"]])]
        ttest_1_1_data <- ttest_1_1_data[as.character(ttest_1_1_data[["subject"]]) %in% ttest_1_1_complete, , drop = FALSE]
        ttest_1_1_data <- ttest_1_1_data[order(ttest_1_1_data[["subject"]], ttest_1_1_data[["measure"]], method = "radix"), , drop = FALSE]
      
        # The rain sits beside each box; with two conditions the first is mirrored so
        # each subject's line joins the two inner columns of points.
        ttest_1_1_levels <- levels(ttest_1_1_data[["measure"]])
        ttest_1_1_position <- match(as.character(ttest_1_1_data[["measure"]]), ttest_1_1_levels)
        ttest_1_1_mirror <- length(ttest_1_1_levels) == 2L
        ttest_1_1_data$rain_x <- ttest_1_1_position + ifelse(ttest_1_1_mirror & ttest_1_1_position == 1L, 0.22, -0.22)
      
        # 2. Condition sizes and the condition mean shown as a labelled point.
        ttest_1_1_groups <- split(ttest_1_1_data[["value"]], ttest_1_1_data[["measure"]])
        ttest_1_1_summary <- data.frame(
          level = factor(names(ttest_1_1_groups), levels = ttest_1_1_levels),
          value = vapply(ttest_1_1_groups, function(values) mean(values), numeric(1)),
          n = lengths(ttest_1_1_groups)
        )
        ttest_1_1_summary$label <- paste0("list(widehat(mu)[mean]=='",
          formatC(ttest_1_1_summary$value, format = "f", digits = 2), "')")
        ttest_1_1_summary$axis_label <- paste0(ttest_1_1_summary$level, "
        (n = ",
          prettyNum(ttest_1_1_summary$n, big.mark = ","), ")")
      
        # Clouds: with two conditions the first one opens to the left.
        if (ttest_1_1_mirror) {
          ttest_1_1_clouds <- list(
            ggdist::stat_slab(data = ttest_1_1_data[ttest_1_1_position == 1L, , drop = FALSE],
            ggplot2::aes(fill = measure, group = measure),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = 1.25, side = "left"),
            ggdist::stat_slab(data = ttest_1_1_data[ttest_1_1_position != 1L, , drop = FALSE],
            ggplot2::aes(fill = measure, group = measure),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = -0.25)
          )
        } else {
          ttest_1_1_clouds <- list(ggdist::stat_slab(ggplot2::aes(fill = measure, group = measure),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = -0.25))
        }
        # Subject lines are drawn only for two conditions.
        ttest_1_1_subject_lines <- if (ttest_1_1_mirror) {
          ggplot2::geom_path(ggplot2::aes(x = rain_x), alpha = 0.5, linetype = "dashed")
        }
      
        # 3. The figure
        ttest_1_1_plot <- ggplot2::ggplot(ttest_1_1_data, ggplot2::aes(x = measure, y = value, group = subject)) +
          # cloud: the distribution in each condition (half density)
          ttest_1_1_clouds +
          # rain: every observation
          ggplot2::geom_point(ggplot2::aes(x = rain_x, colour = measure), size = 2, alpha = 0.5, na.rm = TRUE) +
          # box: median and quartiles
          ggplot2::geom_boxplot(ggplot2::aes(group = measure), width = 0.12, alpha = 0.6, outlier.shape = NA, na.rm = TRUE) +
          # two conditions: each subject's values joined by a dashed line
          ttest_1_1_subject_lines +
          # condition means: joined by a line, labelled
          ggplot2::geom_path(data = ttest_1_1_summary, ggplot2::aes(x = level, y = value, group = 1L),
            inherit.aes = FALSE, linewidth = 1, colour = "red", alpha = 0.5) +
          ggplot2::geom_point(data = ttest_1_1_summary, ggplot2::aes(x = level, y = value),
            inherit.aes = FALSE, size = 4, colour = "black") +
          ggrepel::geom_label_repel(data = ttest_1_1_summary, ggplot2::aes(x = level, y = value, label = label),
            inherit.aes = FALSE, parse = TRUE, size = 3, nudge_x = 0.4, segment.linetype = 4,
            min.segment.length = 0, family = figure_font) +
          ggplot2::scale_x_discrete(labels = ttest_1_1_summary$axis_label) +
          ggplot2::scale_y_continuous(sec.axis = ggplot2::dup_axis(name = NULL, breaks = NULL, labels = NULL)) +
          ggplot2::scale_colour_manual(values = figure_colours) +
          ggplot2::scale_fill_manual(values = figure_fills) +
          ggplot2::labs(x = "measure", y = "value", colour = "measure", title = NULL, subtitle = NULL, caption = NULL) +
          theme_figure() +
          ggplot2::theme(legend.position = "none", panel.grid.major.x = ggplot2::element_blank())
        figure_show(ttest_1_1_plot)
        figure_save(ttest_1_1_plot, "figures/ttest_1-ggplot2-pre-post")
      })
      
      # BetterGG figure: pre and post (paired).
      if (ttest_1_ready) figure_try("ttest_1-bettergg-pre-post", {
        ttest_1_1_bettergg <- BetterGG::ggwithinrain(
          data = ttest_1_1_long, x = measure, y = value, subject.id = subject, type = "parametric",
          alternative = "two.sided", conf.level = 0.95, results.subtitle = FALSE, pairwise.display = "none", bf.message = FALSE
        )
        figure_show(ttest_1_1_bettergg)
        figure_save(ttest_1_1_bettergg, "figures/ttest_1-bettergg-pre-post")
      })
      
      # ggplot2 figure: pre and mid (paired).
      if (ttest_1_ready) figure_try("ttest_1-ggplot2-pre-mid", {
        # 1. Data (long format): subjects with a value of "value" in every condition.
        ttest_1_2_data <- ttest_1_2_long[!is.na(ttest_1_2_long[["measure"]]) & !is.na(ttest_1_2_long[["subject"]]), , drop = FALSE]
        ttest_1_2_data[["measure"]] <- droplevels(as.factor(ttest_1_2_data[["measure"]]))
        if (anyDuplicated(ttest_1_2_data[, c("measure", "subject")])) {
          stop("Each subject must appear at most once per condition; aggregate repeated rows first.")
        }
        ttest_1_2_data <- ttest_1_2_data[!is.na(ttest_1_2_data[["value"]]), , drop = FALSE]
        ttest_1_2_count <- table(ttest_1_2_data[["subject"]])
        ttest_1_2_complete <- names(ttest_1_2_count)[ttest_1_2_count == nlevels(ttest_1_2_data[["measure"]])]
        ttest_1_2_data <- ttest_1_2_data[as.character(ttest_1_2_data[["subject"]]) %in% ttest_1_2_complete, , drop = FALSE]
        ttest_1_2_data <- ttest_1_2_data[order(ttest_1_2_data[["subject"]], ttest_1_2_data[["measure"]], method = "radix"), , drop = FALSE]
      
        # The rain sits beside each box; with two conditions the first is mirrored so
        # each subject's line joins the two inner columns of points.
        ttest_1_2_levels <- levels(ttest_1_2_data[["measure"]])
        ttest_1_2_position <- match(as.character(ttest_1_2_data[["measure"]]), ttest_1_2_levels)
        ttest_1_2_mirror <- length(ttest_1_2_levels) == 2L
        ttest_1_2_data$rain_x <- ttest_1_2_position + ifelse(ttest_1_2_mirror & ttest_1_2_position == 1L, 0.22, -0.22)
      
        # 2. Condition sizes and the condition mean shown as a labelled point.
        ttest_1_2_groups <- split(ttest_1_2_data[["value"]], ttest_1_2_data[["measure"]])
        ttest_1_2_summary <- data.frame(
          level = factor(names(ttest_1_2_groups), levels = ttest_1_2_levels),
          value = vapply(ttest_1_2_groups, function(values) mean(values), numeric(1)),
          n = lengths(ttest_1_2_groups)
        )
        ttest_1_2_summary$label <- paste0("list(widehat(mu)[mean]=='",
          formatC(ttest_1_2_summary$value, format = "f", digits = 2), "')")
        ttest_1_2_summary$axis_label <- paste0(ttest_1_2_summary$level, "
        (n = ",
          prettyNum(ttest_1_2_summary$n, big.mark = ","), ")")
      
        # Clouds: with two conditions the first one opens to the left.
        if (ttest_1_2_mirror) {
          ttest_1_2_clouds <- list(
            ggdist::stat_slab(data = ttest_1_2_data[ttest_1_2_position == 1L, , drop = FALSE],
            ggplot2::aes(fill = measure, group = measure),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = 1.25, side = "left"),
            ggdist::stat_slab(data = ttest_1_2_data[ttest_1_2_position != 1L, , drop = FALSE],
            ggplot2::aes(fill = measure, group = measure),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = -0.25)
          )
        } else {
          ttest_1_2_clouds <- list(ggdist::stat_slab(ggplot2::aes(fill = measure, group = measure),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = -0.25))
        }
        # Subject lines are drawn only for two conditions.
        ttest_1_2_subject_lines <- if (ttest_1_2_mirror) {
          ggplot2::geom_path(ggplot2::aes(x = rain_x), alpha = 0.5, linetype = "dashed")
        }
      
        # 3. The figure
        ttest_1_2_plot <- ggplot2::ggplot(ttest_1_2_data, ggplot2::aes(x = measure, y = value, group = subject)) +
          # cloud: the distribution in each condition (half density)
          ttest_1_2_clouds +
          # rain: every observation
          ggplot2::geom_point(ggplot2::aes(x = rain_x, colour = measure), size = 2, alpha = 0.5, na.rm = TRUE) +
          # box: median and quartiles
          ggplot2::geom_boxplot(ggplot2::aes(group = measure), width = 0.12, alpha = 0.6, outlier.shape = NA, na.rm = TRUE) +
          # two conditions: each subject's values joined by a dashed line
          ttest_1_2_subject_lines +
          # condition means: joined by a line, labelled
          ggplot2::geom_path(data = ttest_1_2_summary, ggplot2::aes(x = level, y = value, group = 1L),
            inherit.aes = FALSE, linewidth = 1, colour = "red", alpha = 0.5) +
          ggplot2::geom_point(data = ttest_1_2_summary, ggplot2::aes(x = level, y = value),
            inherit.aes = FALSE, size = 4, colour = "black") +
          ggrepel::geom_label_repel(data = ttest_1_2_summary, ggplot2::aes(x = level, y = value, label = label),
            inherit.aes = FALSE, parse = TRUE, size = 3, nudge_x = 0.4, segment.linetype = 4,
            min.segment.length = 0, family = figure_font) +
          ggplot2::scale_x_discrete(labels = ttest_1_2_summary$axis_label) +
          ggplot2::scale_y_continuous(sec.axis = ggplot2::dup_axis(name = NULL, breaks = NULL, labels = NULL)) +
          ggplot2::scale_colour_manual(values = figure_colours) +
          ggplot2::scale_fill_manual(values = figure_fills) +
          ggplot2::labs(x = "measure", y = "value", colour = "measure", title = NULL, subtitle = NULL, caption = NULL) +
          theme_figure() +
          ggplot2::theme(legend.position = "none", panel.grid.major.x = ggplot2::element_blank())
        figure_show(ttest_1_2_plot)
        figure_save(ttest_1_2_plot, "figures/ttest_1-ggplot2-pre-mid")
      })
      
      # BetterGG figure: pre and mid (paired).
      if (ttest_1_ready) figure_try("ttest_1-bettergg-pre-mid", {
        ttest_1_2_bettergg <- BetterGG::ggwithinrain(
          data = ttest_1_2_long, x = measure, y = value, subject.id = subject, type = "parametric",
          alternative = "two.sided", conf.level = 0.95, results.subtitle = FALSE, pairwise.display = "none", bf.message = FALSE
        )
        figure_show(ttest_1_2_bettergg)
        figure_save(ttest_1_2_bettergg, "figures/ttest_1-bettergg-pre-mid")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- rm_anova_1: jmv::anovaRM (line 1) -------------------------------------
      # Source: jmv::anovaRM(data = d, rm = list(list(label = "time", levels =
      #         c("pre", "post"))), rmCells = list(list(measure = "pre", cell =
      #         "pre"), list(measure = "post", cell = "post")), bs = "h")
      # Figure: every observation and its distribution in each cell, with the
      #         estimated marginal means and 95% confidence intervals from the
      #         repeated-measures model (emmeans on afex; these intervals are
      #         model-based, not within-subject corrected).
      # Differs from jamovi: nothing known.
      rm_anova_1_ready <- figure_try("rm_anova_1", {
        # Analysis data: a copy of d as it is at this point.
        rm_anova_1_input <- d
        if (!is.data.frame(rm_anova_1_input)) stop("The analysis data must be a data frame.")
        rm_anova_1_missing <- setdiff(c("pre", "post", "h"), names(rm_anova_1_input))
        if (length(rm_anova_1_missing)) stop("Column(s) not found: ", toString(rm_anova_1_missing))
        if (!is.null(attr(rm_anova_1_input, "jmv-weights", exact = TRUE))) {
          stop("Weighted repeated-measures mapping is unavailable. Keep the original analysis rather than substituting an unweighted one.")
        }
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in c("pre", "post")) {
          values <- rm_anova_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          rm_anova_1_input[[column]] <- as.numeric(values)
        }
        # Complete cases of every measure, as jamovi uses.
        rm_anova_1_input <- rm_anova_1_input[stats::complete.cases(rm_anova_1_input[, c("pre", "post", "h"), drop = FALSE]), , drop = FALSE]
        # Long format: one row per participant and measure.
        rm_anova_1_long <- rbind(
          data.frame(subject = seq_len(nrow(rm_anova_1_input)), value = rm_anova_1_input[["pre"]], time = "pre", h = rm_anova_1_input[["h"]], check.names = FALSE),
          data.frame(subject = seq_len(nrow(rm_anova_1_input)), value = rm_anova_1_input[["post"]], time = "post", h = rm_anova_1_input[["h"]], check.names = FALSE)
        )
        rm_anova_1_long[["time"]] <- factor(rm_anova_1_long[["time"]], levels = c("pre", "post"))
        rm_anova_1_long[["h"]] <- if (inherits(rm_anova_1_long[["h"]], "haven_labelled")) haven::as_factor(rm_anova_1_long[["h"]]) else factor(rm_anova_1_long[["h"]])
        rm_anova_1_long[["subject"]] <- factor(rm_anova_1_long[["subject"]])
        # Model: repeated-measures ANOVA (afex) value ~ (h) * (time) + Error(subject/(time)).
        rm_anova_1_model <- afex::aov_car(value ~ (h) * (time) + Error(subject/(time)), data = rm_anova_1_long, factorize = FALSE)
        # Estimated marginal means and 95% confidence intervals (emmeans on the afex model).
        rm_anova_1_means <- as.data.frame(stats::confint(emmeans::emmeans(rm_anova_1_model, specs = c("time", "h")), level = 0.95))
        # afex names within-subject levels as R names ("High Control" becomes "High.Control");
        # the data's own level names are restored.
        for (column in "time") {
          rm_anova_1_levels <- levels(rm_anova_1_long[[column]])
          if (anyDuplicated(make.names(rm_anova_1_levels))) stop("Levels of ", column, " become identical as R names: ", toString(rm_anova_1_levels))
          rm_anova_1_means[[column]] <- factor(rm_anova_1_levels[match(as.character(rm_anova_1_means[[column]]), make.names(rm_anova_1_levels))], levels = rm_anova_1_levels)
        }
      })
      
      # ggplot2 figure: Repeated measures by time, h.
      if (rm_anova_1_ready) figure_try("rm_anova_1-ggplot2", {
        # 1. Data: complete cases of the outcome, factors and covariates.
        rm_anova_1_data <- rm_anova_1_long[stats::complete.cases(rm_anova_1_long[, c("value", "time", "h"), drop = FALSE]), c("value", "time", "h"), drop = FALSE]
        for (factor_name in c("time", "h")) {
          rm_anova_1_data[[factor_name]] <- droplevels(as.factor(rm_anova_1_data[[factor_name]]))
          if (nlevels(rm_anova_1_data[[factor_name]]) < 2L) stop("Factor ", factor_name, " needs two observed levels.")
        }
      
        # 2. Model means supplied by the analysis (from its own model).
        rm_anova_1_means <- as.data.frame(rm_anova_1_means)
        for (factor_name in c("time", "h")) {
          rm_anova_1_means[[factor_name]] <- factor(as.character(rm_anova_1_means[[factor_name]]),
            levels = levels(rm_anova_1_data[[factor_name]]))
        }
        if (anyNA(rm_anova_1_means[c("time", "h")])) stop("The model means have levels not in the data.")
      
        # 3. Positions: x levels at 1, 2, ...; colour groups side by side within each.
        rm_anova_1_k <- nlevels(rm_anova_1_data[["h"]])
        rm_anova_1_slot <- 0.8 / rm_anova_1_k
        rm_anova_1_place <- function(df) {
          as.integer(df[["time"]]) + (as.integer(df[["h"]]) - (rm_anova_1_k + 1) / 2) * rm_anova_1_slot
        }
        rm_anova_1_data$x_position <- rm_anova_1_place(rm_anova_1_data)
        rm_anova_1_data$rain_position <- rm_anova_1_data$x_position - 0.2 * rm_anova_1_slot
        rm_anova_1_data$cell <- interaction(rm_anova_1_data[c("time", "h")], drop = TRUE, lex.order = TRUE)
        rm_anova_1_means$x_position <- rm_anova_1_place(rm_anova_1_means)
      
        # 4. The figure
        rm_anova_1_plot <- ggplot2::ggplot(rm_anova_1_data, ggplot2::aes(x = x_position, y = .data[["value"]])) +
          # cloud: the distribution of each cell (half density)
          ggdist::stat_slab(ggplot2::aes(fill = .data[["h"]], group = cell), orientation = "vertical",
            side = "right", justification = 0, width = rm_anova_1_slot, scale = 0.45, colour = NA, alpha = 0.5,
            normalize = "groups") +
          # rain: every observation, slightly jittered sideways
          ggplot2::geom_point(ggplot2::aes(x = rain_position, colour = .data[["h"]]),
            position = ggplot2::position_jitter(width = 0.06 * rm_anova_1_slot, height = 0, seed = 1123),
            size = 1.4, alpha = 0.5, stroke = 0) +
          # model means of each colour group joined across the x levels
          ggplot2::geom_line(data = rm_anova_1_means,
            ggplot2::aes(x = x_position, y = emmean, colour = .data[["h"]], group = .data[["h"]]), inherit.aes = FALSE, linewidth = 0.6) +
          # estimated marginal means with 95% confidence intervals
          ggplot2::geom_errorbar(data = rm_anova_1_means, ggplot2::aes(x = x_position, ymin = lower.CL, ymax = upper.CL),
            inherit.aes = FALSE, width = 0.12 * rm_anova_1_slot, linewidth = 0.6) +
          ggplot2::geom_point(data = rm_anova_1_means, ggplot2::aes(x = x_position, y = emmean, fill = .data[["h"]]),
            inherit.aes = FALSE, shape = 21, size = 3, colour = "black", stroke = 0.6) +
          ggplot2::scale_x_continuous(breaks = seq_len(nlevels(rm_anova_1_data[["time"]])), labels = levels(rm_anova_1_data[["time"]])) +
          ggplot2::scale_colour_manual(values = figure_colours) +
          ggplot2::scale_fill_manual(values = figure_fills) +
          ggplot2::labs(x = "time", y = "value", title = NULL, colour = "h", fill = "h", subtitle = NULL) +
          theme_figure() +
          ggplot2::theme(legend.position = "bottom", panel.grid.major.x = ggplot2::element_blank()) +
          # many or long level names are angled so they do not overlap
          (if (nlevels(rm_anova_1_data[["time"]]) > 6L || sum(nchar(levels(rm_anova_1_data[["time"]]))) > 60L)
            ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1)))
        figure_show(rm_anova_1_plot)
        figure_save(rm_anova_1_plot, "figures/rm_anova_1-ggplot2")
      })
      
      # BetterGG figure: Repeated measures by time, h.
      if (rm_anova_1_ready) figure_try("rm_anova_1-bettergg", {
        rm_anova_1_bettergg <- BetterGG::ggfactorialrain(
          data = rm_anova_1_long, x = "time", y = "value", colour = "h",
          covariates = NULL, means = rm_anova_1_means, conf.level = 0.95
        )
        figure_show(rm_anova_1_bettergg)
        figure_save(rm_anova_1_bettergg, "figures/rm_anova_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- descriptives_1: jmv::descriptives (line 1) ----------------------------
      # Source: jmv::descriptives(data = d, vars = c("y", "c2"), splitBy = "h")
      # Figure: for each variable, a histogram (numeric) or pie chart (categories)
      #         of the case-weighted counts, split by h.
      # Differs from jamovi: nothing known.
      descriptives_1_ready <- figure_try("descriptives_1", {
        # Analysis data: a copy of d as it is at this point.
        descriptives_1_input <- d
        if (!is.data.frame(descriptives_1_input)) stop("The analysis data must be a data frame.")
        descriptives_1_missing <- setdiff(c("y", "c2", "h"), names(descriptives_1_input))
        if (length(descriptives_1_missing)) stop("Column(s) not found: ", toString(descriptives_1_missing))
        # Case weights set in jamovi; without them every row counts once.
        descriptives_1_weights <- attr(descriptives_1_input, "jmv-weights", exact = TRUE)
        if (is.null(descriptives_1_weights)) descriptives_1_weights <- rep(1, nrow(descriptives_1_input))
        if (!is.numeric(descriptives_1_weights)) descriptives_1_weights <- attr(descriptives_1_weights, "values", exact = TRUE)[as.integer(descriptives_1_weights)]
        if (length(descriptives_1_weights) != nrow(descriptives_1_input) || anyNA(descriptives_1_weights) || any(descriptives_1_weights < 0)) stop("Invalid case weights.")
        for (column in c("y", "c2", "h")) {
          if (inherits(descriptives_1_input[[column]], "haven_labelled")) descriptives_1_input[[column]] <- haven::as_factor(descriptives_1_input[[column]])
        }
        descriptives_1_input[["descriptives_1_case_weight"]] <- descriptives_1_weights
      })
      
      # ggplot2 figure: Distribution of y.
      if (descriptives_1_ready) figure_try("descriptives_1-ggplot2-y", {
        if (is.numeric(descriptives_1_input[["y"]])) {
          # 1. Data: rows with a value of "y".
          descriptives_1_1_data <- descriptives_1_input[stats::complete.cases(descriptives_1_input[, c("y", "descriptives_1_case_weight", "h"), drop = FALSE]), c("y", "descriptives_1_case_weight", "h"), drop = FALSE]
          descriptives_1_1_data[["h"]] <- droplevels(as.factor(descriptives_1_1_data[["h"]]))
          # The mean of each panel, drawn as a dashed line and labelled.
          descriptives_1_1_centres <- do.call(rbind, lapply(split(descriptives_1_1_data, descriptives_1_1_data[["h"]]), function(part) {
            values <- part[["y"]]
            weights <- part[["descriptives_1_case_weight"]]
            data.frame(level = part[["h"]][1], value = stats::weighted.mean(values, weights))
          }))
          names(descriptives_1_1_centres)[1] <- "h"
          descriptives_1_1_centres$label <- paste0("list(widehat(mu)[mean]=='", formatC(descriptives_1_1_centres$value, format = "f", digits = 2), "')")
          # each label beside its line, on the side with more room, so it stays inside the panel
          descriptives_1_1_centres$hjust <- ifelse(descriptives_1_1_centres$value < mean(range(descriptives_1_1_data[["y"]])), -0.05, 1.05)
          # Bin width: the ggstatsplot rule, range / square root of n.
          descriptives_1_1_binwidth <- diff(range(descriptives_1_1_data[["y"]])) / sqrt(nrow(descriptives_1_1_data))
          descriptives_1_1_total <- sum(descriptives_1_1_data[["descriptives_1_case_weight"]])
      
          # 2. The figure
          descriptives_1_1_plot <- ggplot2::ggplot(descriptives_1_1_data, ggplot2::aes(x = y, weight = descriptives_1_case_weight)) +
            # bars: counts per bin
            ggplot2::stat_bin(ggplot2::aes(y = ggplot2::after_stat(count), fill = ggplot2::after_stat(count)),
              binwidth = descriptives_1_1_binwidth, colour = "black", fill = "grey50", alpha = 0.7) +
            # right axis: the same counts as proportions
            # headroom above the tallest bar for the labels; counts are whole numbers
            ggplot2::scale_y_continuous(breaks = function(l) { b <- pretty(l); b[b == round(b)] },
              sec.axis = ggplot2::sec_axis(transform = ~ . / descriptives_1_1_total,
              labels = function(p) paste0(round(100 * p), "%"), name = "proportion"),
              expand = ggplot2::expansion(mult = c(0.05, 0.3))) +
            ggplot2::guides(fill = "none") +
            # the mean
            ggplot2::geom_vline(data = descriptives_1_1_centres, ggplot2::aes(xintercept = value), colour = "blue",
              linewidth = 1, linetype = "dashed") +
            ggplot2::geom_label(data = descriptives_1_1_centres, ggplot2::aes(x = value, y = Inf, label = label, hjust = hjust),
              inherit.aes = FALSE, parse = TRUE, vjust = 1.2, size = 3, family = figure_font) +
            ggplot2::facet_wrap(ggplot2::vars(.data[["h"]]), labeller = ggplot2::label_wrap_gen(width = 30)) +
            ggplot2::labs(x = "y", y = "count", title = NULL, subtitle = NULL, caption = NULL) +
            theme_figure()
        } else {
          # 1. Data: complete cases; the categories become factors.
          descriptives_1_1_data <- descriptives_1_input[stats::complete.cases(descriptives_1_input[, c("y", "h", "descriptives_1_case_weight"), drop = FALSE]), c("y", "h", "descriptives_1_case_weight"), drop = FALSE]
          for (column in c("y", "h")) descriptives_1_1_data[[column]] <- as.factor(descriptives_1_1_data[[column]])
          descriptives_1_1_weight <- descriptives_1_1_data[["descriptives_1_case_weight"]]
      
          # 2. Count (weighted) and percentage of each category within each bar.
          descriptives_1_1_cells <- as.data.frame(stats::xtabs(descriptives_1_1_weight ~ descriptives_1_1_data[["h"]] + descriptives_1_1_data[["y"]]), responseName = "counts")
          names(descriptives_1_1_cells)[seq_len(2)] <- c("h", "y")
          descriptives_1_1_cells$perc <- 100 * descriptives_1_1_cells$counts / stats::ave(descriptives_1_1_cells$counts, interaction(descriptives_1_1_cells[["h"]]), FUN = sum)
          descriptives_1_1_cells$perc[is.nan(descriptives_1_1_cells$perc)] <- 0
          descriptives_1_1_cells <- descriptives_1_1_cells[order(descriptives_1_1_cells[["h"]], descriptives_1_1_cells[["y"]]), ]
          # Group sizes, shown under the bars
          descriptives_1_1_sizes <- as.data.frame(stats::xtabs(descriptives_1_1_weight ~ descriptives_1_1_data[["h"]]), responseName = "counts")
          names(descriptives_1_1_sizes)[seq_len(1)] <- c("h")
          descriptives_1_1_sizes$N <- paste0("(n = ", prettyNum(round(descriptives_1_1_sizes$counts, 2), big.mark = ","), ")")
          descriptives_1_1_sizes <- descriptives_1_1_sizes[order(descriptives_1_1_sizes[["h"]], decreasing = TRUE), ]
          descriptives_1_1_cells$label <- ifelse(descriptives_1_1_cells$counts == 0, NA_character_, paste0(round(descriptives_1_1_cells$perc), "%"))
          # Fill colours: the palette, or a longer qualitative palette for many categories.
          descriptives_1_1_fills <- if (nlevels(descriptives_1_1_data[["y"]]) <= length(figure_fills)) figure_fills else
            grDevices::hcl.colors(nlevels(descriptives_1_1_data[["y"]]), "Dark 3")
      
          # 3. The figure
          # Many or long bar labels are angled; with many bars the group sizes get smaller, so they do not overlap.
          descriptives_1_1_ticks <- levels(factor(descriptives_1_1_cells[["h"]]))
          descriptives_1_1_many <- length(descriptives_1_1_ticks) > 6L || sum(nchar(descriptives_1_1_ticks)) > 60L
          descriptives_1_1_size <- max(2.5, min(4, 24 / length(descriptives_1_1_ticks)))
          # room on the left for the first angled label (about 4 pt per character)
          descriptives_1_1_left_room <- max(5.5, 4 * nchar(descriptives_1_1_ticks[1]) - 30)
          descriptives_1_1_plot <- ggplot2::ggplot(descriptives_1_1_cells, ggplot2::aes(x = h, y = perc, fill = y)) +
            # 100% stacked bars
            ggplot2::geom_col(position = "fill", colour = "black") +
            ggplot2::scale_y_continuous(labels = function(p) paste0(round(100 * p), "%"),
              breaks = seq(0, 1, by = 0.1), minor_breaks = seq(0.05, 0.95, by = 0.1)) +
            # percentage labels
            ggplot2::geom_label(ggplot2::aes(label = label, group = y), position = ggplot2::position_fill(vjust = 0.5),
              na.rm = TRUE, show.legend = FALSE, alpha = 1, fill = "white", family = figure_font) +
            theme_figure() +
            ggplot2::theme(panel.grid.major.x = ggplot2::element_blank()) +
            (if (descriptives_1_1_many) ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1),
              plot.margin = ggplot2::margin(5.5, 5.5, 5.5, descriptives_1_1_left_room))) +
            ggplot2::guides(fill = ggplot2::guide_legend(title = "y")) +
            ggplot2::scale_fill_manual(values = descriptives_1_1_fills, name = "", drop = FALSE) +
            # group sizes under the bars
            ggplot2::geom_text(data = descriptives_1_1_sizes, ggplot2::aes(x = h, y = -0.05, label = N, fill = NULL),
              size = descriptives_1_1_size, family = figure_font) +
            ggplot2::labs(x = "h", y = NULL, subtitle = NULL, title = NULL, caption = NULL)
        }
        figure_show(descriptives_1_1_plot)
        figure_save(descriptives_1_1_plot, "figures/descriptives_1-ggplot2-y")
      })
      
      # BetterGG figure: Distribution of y (BetterGG).
      if (descriptives_1_ready) figure_try("descriptives_1-bettergg-y", {
        if (is.numeric(descriptives_1_input[["y"]])) {
          descriptives_1_1_bettergg <- BetterGG::gghistostats(data = descriptives_1_input, x = y, results.subtitle = FALSE, bf.message = FALSE)
        } else {
          descriptives_1_1_bettergg_levels <- nlevels(factor(descriptives_1_input[["y"]]))
          descriptives_1_1_bettergg <- BetterGG::ggpiestats(
            data = descriptives_1_input, x = y, results.subtitle = FALSE, bf.message = FALSE,
            palette = if (descriptives_1_1_bettergg_levels <= 8L) "ggsci::default_nejm" else "palettesForR::Named"
          ) +
            ggplot2::guides(fill = ggplot2::guide_legend(ncol = 4, byrow = TRUE)) +
            ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(size = 6))
          # Keep every category in the legend; omit overlapping slice labels above 12 categories.
          if (descriptives_1_1_bettergg_levels > 12L) {
            descriptives_1_1_bettergg$layers <- Filter(function(layer) !inherits(layer$geom, c("GeomLabel", "GeomLabelRepel")), descriptives_1_1_bettergg$layers)
          }
        }
        figure_show(descriptives_1_1_bettergg)
        figure_save(descriptives_1_1_bettergg, "figures/descriptives_1-bettergg-y")
      })
      
      # ggplot2 figure: Distribution of c2.
      if (descriptives_1_ready) figure_try("descriptives_1-ggplot2-c2", {
        if (is.numeric(descriptives_1_input[["c2"]])) {
          # 1. Data: rows with a value of "c2".
          descriptives_1_2_data <- descriptives_1_input[stats::complete.cases(descriptives_1_input[, c("c2", "descriptives_1_case_weight", "h"), drop = FALSE]), c("c2", "descriptives_1_case_weight", "h"), drop = FALSE]
          descriptives_1_2_data[["h"]] <- droplevels(as.factor(descriptives_1_2_data[["h"]]))
          # The mean of each panel, drawn as a dashed line and labelled.
          descriptives_1_2_centres <- do.call(rbind, lapply(split(descriptives_1_2_data, descriptives_1_2_data[["h"]]), function(part) {
            values <- part[["c2"]]
            weights <- part[["descriptives_1_case_weight"]]
            data.frame(level = part[["h"]][1], value = stats::weighted.mean(values, weights))
          }))
          names(descriptives_1_2_centres)[1] <- "h"
          descriptives_1_2_centres$label <- paste0("list(widehat(mu)[mean]=='", formatC(descriptives_1_2_centres$value, format = "f", digits = 2), "')")
          # each label beside its line, on the side with more room, so it stays inside the panel
          descriptives_1_2_centres$hjust <- ifelse(descriptives_1_2_centres$value < mean(range(descriptives_1_2_data[["c2"]])), -0.05, 1.05)
          # Bin width: the ggstatsplot rule, range / square root of n.
          descriptives_1_2_binwidth <- diff(range(descriptives_1_2_data[["c2"]])) / sqrt(nrow(descriptives_1_2_data))
          descriptives_1_2_total <- sum(descriptives_1_2_data[["descriptives_1_case_weight"]])
      
          # 2. The figure
          descriptives_1_2_plot <- ggplot2::ggplot(descriptives_1_2_data, ggplot2::aes(x = c2, weight = descriptives_1_case_weight)) +
            # bars: counts per bin
            ggplot2::stat_bin(ggplot2::aes(y = ggplot2::after_stat(count), fill = ggplot2::after_stat(count)),
              binwidth = descriptives_1_2_binwidth, colour = "black", fill = "grey50", alpha = 0.7) +
            # right axis: the same counts as proportions
            # headroom above the tallest bar for the labels; counts are whole numbers
            ggplot2::scale_y_continuous(breaks = function(l) { b <- pretty(l); b[b == round(b)] },
              sec.axis = ggplot2::sec_axis(transform = ~ . / descriptives_1_2_total,
              labels = function(p) paste0(round(100 * p), "%"), name = "proportion"),
              expand = ggplot2::expansion(mult = c(0.05, 0.3))) +
            ggplot2::guides(fill = "none") +
            # the mean
            ggplot2::geom_vline(data = descriptives_1_2_centres, ggplot2::aes(xintercept = value), colour = "blue",
              linewidth = 1, linetype = "dashed") +
            ggplot2::geom_label(data = descriptives_1_2_centres, ggplot2::aes(x = value, y = Inf, label = label, hjust = hjust),
              inherit.aes = FALSE, parse = TRUE, vjust = 1.2, size = 3, family = figure_font) +
            ggplot2::facet_wrap(ggplot2::vars(.data[["h"]]), labeller = ggplot2::label_wrap_gen(width = 30)) +
            ggplot2::labs(x = "c2", y = "count", title = NULL, subtitle = NULL, caption = NULL) +
            theme_figure()
        } else {
          # 1. Data: complete cases; the categories become factors.
          descriptives_1_2_data <- descriptives_1_input[stats::complete.cases(descriptives_1_input[, c("c2", "h", "descriptives_1_case_weight"), drop = FALSE]), c("c2", "h", "descriptives_1_case_weight"), drop = FALSE]
          for (column in c("c2", "h")) descriptives_1_2_data[[column]] <- as.factor(descriptives_1_2_data[[column]])
          descriptives_1_2_weight <- descriptives_1_2_data[["descriptives_1_case_weight"]]
      
          # 2. Count (weighted) and percentage of each category within each bar.
          descriptives_1_2_cells <- as.data.frame(stats::xtabs(descriptives_1_2_weight ~ descriptives_1_2_data[["h"]] + descriptives_1_2_data[["c2"]]), responseName = "counts")
          names(descriptives_1_2_cells)[seq_len(2)] <- c("h", "c2")
          descriptives_1_2_cells$perc <- 100 * descriptives_1_2_cells$counts / stats::ave(descriptives_1_2_cells$counts, interaction(descriptives_1_2_cells[["h"]]), FUN = sum)
          descriptives_1_2_cells$perc[is.nan(descriptives_1_2_cells$perc)] <- 0
          descriptives_1_2_cells <- descriptives_1_2_cells[order(descriptives_1_2_cells[["h"]], descriptives_1_2_cells[["c2"]]), ]
          # Group sizes, shown under the bars
          descriptives_1_2_sizes <- as.data.frame(stats::xtabs(descriptives_1_2_weight ~ descriptives_1_2_data[["h"]]), responseName = "counts")
          names(descriptives_1_2_sizes)[seq_len(1)] <- c("h")
          descriptives_1_2_sizes$N <- paste0("(n = ", prettyNum(round(descriptives_1_2_sizes$counts, 2), big.mark = ","), ")")
          descriptives_1_2_sizes <- descriptives_1_2_sizes[order(descriptives_1_2_sizes[["h"]], decreasing = TRUE), ]
          descriptives_1_2_cells$label <- ifelse(descriptives_1_2_cells$counts == 0, NA_character_, paste0(round(descriptives_1_2_cells$perc), "%"))
          # Fill colours: the palette, or a longer qualitative palette for many categories.
          descriptives_1_2_fills <- if (nlevels(descriptives_1_2_data[["c2"]]) <= length(figure_fills)) figure_fills else
            grDevices::hcl.colors(nlevels(descriptives_1_2_data[["c2"]]), "Dark 3")
      
          # 3. The figure
          # Many or long bar labels are angled; with many bars the group sizes get smaller, so they do not overlap.
          descriptives_1_2_ticks <- levels(factor(descriptives_1_2_cells[["h"]]))
          descriptives_1_2_many <- length(descriptives_1_2_ticks) > 6L || sum(nchar(descriptives_1_2_ticks)) > 60L
          descriptives_1_2_size <- max(2.5, min(4, 24 / length(descriptives_1_2_ticks)))
          # room on the left for the first angled label (about 4 pt per character)
          descriptives_1_2_left_room <- max(5.5, 4 * nchar(descriptives_1_2_ticks[1]) - 30)
          descriptives_1_2_plot <- ggplot2::ggplot(descriptives_1_2_cells, ggplot2::aes(x = h, y = perc, fill = c2)) +
            # 100% stacked bars
            ggplot2::geom_col(position = "fill", colour = "black") +
            ggplot2::scale_y_continuous(labels = function(p) paste0(round(100 * p), "%"),
              breaks = seq(0, 1, by = 0.1), minor_breaks = seq(0.05, 0.95, by = 0.1)) +
            # percentage labels
            ggplot2::geom_label(ggplot2::aes(label = label, group = c2), position = ggplot2::position_fill(vjust = 0.5),
              na.rm = TRUE, show.legend = FALSE, alpha = 1, fill = "white", family = figure_font) +
            theme_figure() +
            ggplot2::theme(panel.grid.major.x = ggplot2::element_blank()) +
            (if (descriptives_1_2_many) ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1),
              plot.margin = ggplot2::margin(5.5, 5.5, 5.5, descriptives_1_2_left_room))) +
            ggplot2::guides(fill = ggplot2::guide_legend(title = "c2")) +
            ggplot2::scale_fill_manual(values = descriptives_1_2_fills, name = "", drop = FALSE) +
            # group sizes under the bars
            ggplot2::geom_text(data = descriptives_1_2_sizes, ggplot2::aes(x = h, y = -0.05, label = N, fill = NULL),
              size = descriptives_1_2_size, family = figure_font) +
            ggplot2::labs(x = "h", y = NULL, subtitle = NULL, title = NULL, caption = NULL)
        }
        figure_show(descriptives_1_2_plot)
        figure_save(descriptives_1_2_plot, "figures/descriptives_1-ggplot2-c2")
      })
      
      # BetterGG figure: Distribution of c2 (BetterGG).
      if (descriptives_1_ready) figure_try("descriptives_1-bettergg-c2", {
        if (is.numeric(descriptives_1_input[["c2"]])) {
          descriptives_1_2_bettergg <- BetterGG::gghistostats(data = descriptives_1_input, x = c2, results.subtitle = FALSE, bf.message = FALSE)
        } else {
          descriptives_1_2_bettergg_levels <- nlevels(factor(descriptives_1_input[["c2"]]))
          descriptives_1_2_bettergg <- BetterGG::ggpiestats(
            data = descriptives_1_input, x = c2, results.subtitle = FALSE, bf.message = FALSE,
            palette = if (descriptives_1_2_bettergg_levels <= 8L) "ggsci::default_nejm" else "palettesForR::Named"
          ) +
            ggplot2::guides(fill = ggplot2::guide_legend(ncol = 4, byrow = TRUE)) +
            ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(size = 6))
          # Keep every category in the legend; omit overlapping slice labels above 12 categories.
          if (descriptives_1_2_bettergg_levels > 12L) {
            descriptives_1_2_bettergg$layers <- Filter(function(layer) !inherits(layer$geom, c("GeomLabel", "GeomLabelRepel")), descriptives_1_2_bettergg$layers)
          }
        }
        figure_show(descriptives_1_2_bettergg)
        figure_save(descriptives_1_2_bettergg, "figures/descriptives_1-bettergg-c2")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- table_1: jmv::contTables (line 1) -------------------------------------
      # Source: jmv::contTables(data = d, rows = "c1", cols = "c2", layers = "h")
      # Differs from jamovi: nothing known.
      table_1_ready <- figure_try("table_1", {
        # Analysis data: a copy of d as it is at this point.
        table_1_input <- d
        if (!is.data.frame(table_1_input)) stop("The analysis data must be a data frame.")
        table_1_missing <- setdiff(c("c1", "c2", "h"), names(table_1_input))
        if (length(table_1_missing)) stop("Column(s) not found: ", toString(table_1_missing))
        # Case weights set in jamovi; without them every row counts once.
        table_1_weights <- attr(table_1_input, "jmv-weights", exact = TRUE)
        if (is.null(table_1_weights)) table_1_weights <- rep(1, nrow(table_1_input))
        if (!is.numeric(table_1_weights)) table_1_weights <- attr(table_1_weights, "values", exact = TRUE)[as.integer(table_1_weights)]
        if (length(table_1_weights) != nrow(table_1_input) || anyNA(table_1_weights) || any(table_1_weights < 0)) stop("Invalid case weights.")
        # Grouping columns become factors (SPSS value labels name the levels).
        for (column in c("c1", "c2", "h")) {
          values <- table_1_input[[column]]
          table_1_input[[column]] <- if (inherits(values, "haven_labelled")) haven::as_factor(values) else factor(values)
        }
        table_1_input[["table_1_case_weight"]] <- table_1_weights
      })
      
      # ggplot2 figure: c1 within each level of c2.
      if (table_1_ready) figure_try("table_1-ggplot2", {
        # 1. Data: complete cases; the categories become factors.
        table_1_data <- table_1_input[stats::complete.cases(table_1_input[, c("c1", "c2", "h", "table_1_case_weight"), drop = FALSE]), c("c1", "c2", "h", "table_1_case_weight"), drop = FALSE]
        for (column in c("c1", "c2", "h")) table_1_data[[column]] <- as.factor(table_1_data[[column]])
        table_1_weight <- table_1_data[["table_1_case_weight"]]
      
        # 2. Count (weighted) and percentage of each category within each bar.
        table_1_cells <- as.data.frame(stats::xtabs(table_1_weight ~ table_1_data[["h"]] + table_1_data[["c2"]] + table_1_data[["c1"]]), responseName = "counts")
        names(table_1_cells)[seq_len(3)] <- c("h", "c2", "c1")
        table_1_cells$perc <- 100 * table_1_cells$counts / stats::ave(table_1_cells$counts, interaction(table_1_cells[["h"]], table_1_cells[["c2"]]), FUN = sum)
        table_1_cells$perc[is.nan(table_1_cells$perc)] <- 0
        table_1_cells <- table_1_cells[order(table_1_cells[["h"]], table_1_cells[["c2"]], table_1_cells[["c1"]]), ]
        # Group sizes, shown under the bars
        table_1_sizes <- as.data.frame(stats::xtabs(table_1_weight ~ table_1_data[["h"]] + table_1_data[["c2"]]), responseName = "counts")
        names(table_1_sizes)[seq_len(2)] <- c("h", "c2")
        table_1_sizes$N <- paste0("(n = ", prettyNum(round(table_1_sizes$counts, 2), big.mark = ","), ")")
        table_1_sizes <- table_1_sizes[order(table_1_sizes[["c2"]], decreasing = TRUE), ]
        table_1_cells$label <- ifelse(table_1_cells$counts == 0, NA_character_, paste0(round(table_1_cells$perc), "%"))
        # Fill colours: the palette, or a longer qualitative palette for many categories.
        table_1_fills <- if (nlevels(table_1_data[["c1"]]) <= length(figure_fills)) figure_fills else
          grDevices::hcl.colors(nlevels(table_1_data[["c1"]]), "Dark 3")
      
        # 3. The figure
        # Many or long bar labels are angled; with many bars the group sizes get smaller, so they do not overlap.
        table_1_ticks <- levels(factor(table_1_cells[["c2"]]))
        table_1_many <- length(table_1_ticks) > 6L || sum(nchar(table_1_ticks)) > 60L
        table_1_size <- max(2.5, min(4, 24 / length(table_1_ticks)))
        # room on the left for the first angled label (about 4 pt per character)
        table_1_left_room <- max(5.5, 4 * nchar(table_1_ticks[1]) - 30)
        table_1_plot <- ggplot2::ggplot(table_1_cells, ggplot2::aes(x = c2, y = perc, fill = c1)) +
          # 100% stacked bars
          ggplot2::geom_col(position = "fill", colour = "black") +
          ggplot2::scale_y_continuous(labels = function(p) paste0(round(100 * p), "%"),
            breaks = seq(0, 1, by = 0.1), minor_breaks = seq(0.05, 0.95, by = 0.1)) +
          # percentage labels
          ggplot2::geom_label(ggplot2::aes(label = label, group = c1), position = ggplot2::position_fill(vjust = 0.5),
            na.rm = TRUE, show.legend = FALSE, alpha = 1, fill = "white", family = figure_font) +
          theme_figure() +
          ggplot2::theme(panel.grid.major.x = ggplot2::element_blank()) +
          (if (table_1_many) ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1),
            plot.margin = ggplot2::margin(5.5, 5.5, 5.5, table_1_left_room))) +
          ggplot2::guides(fill = ggplot2::guide_legend(title = "c1")) +
          ggplot2::scale_fill_manual(values = table_1_fills, name = "", drop = FALSE) +
          ggplot2::facet_wrap(ggplot2::vars(h), labeller = ggplot2::label_wrap_gen(width = 30)) +
          # group sizes under the bars
          ggplot2::geom_text(data = table_1_sizes, ggplot2::aes(x = c2, y = -0.05, label = N, fill = NULL),
            size = table_1_size, family = figure_font) +
          ggplot2::labs(x = "c2", y = NULL, subtitle = NULL, title = NULL, caption = NULL)
        figure_show(table_1_plot)
        figure_save(table_1_plot, "figures/table_1-ggplot2")
      })
      
      # BetterGG figure: c1 within each level of c2.
      if (table_1_ready) figure_try("table_1-bettergg", {
        table_1_bettergg <- BetterGG::ggbarstats(
          data = table_1_input, x = c1, y = c2,
          results.subtitle = FALSE, bf.message = FALSE,
          palette = if (nlevels(factor(table_1_input[["c1"]])) <= 8L) "ggsci::default_nejm" else "palettesForR::Named"
        )
        figure_show(table_1_bettergg)
        figure_save(table_1_bettergg, "figures/table_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- correlation_1: jmv::corrPart (line 1) ---------------------------------
      # Source: jmv::corrPart(data = d, vars = c("y", "x"), controls = "z")
      # Figure: the partial correlations of y, x controlling for z (pairwise
      #         complete cases), with a cross on each coefficient whose unadjusted
      #         p-value is .05 or more, as jamovi flags them.
      # Differs from jamovi: nothing known.
      correlation_1_ready <- figure_try("correlation_1", {
        # Analysis data: a copy of d as it is at this point.
        correlation_1_input <- d
        if (!is.data.frame(correlation_1_input)) stop("The analysis data must be a data frame.")
        correlation_1_missing <- setdiff(c("y", "x", "z"), names(correlation_1_input))
        if (length(correlation_1_missing)) stop("Column(s) not found: ", toString(correlation_1_missing))
        if (!is.null(attr(correlation_1_input, "jmv-weights", exact = TRUE))) {
          stop("Weighted correlation mapping is unavailable. Keep the original analysis rather than substituting an unweighted one.")
        }
        # jamovi's numeric values mapping; nominal columns without one stay undefined (empty cells).
        for (column in c("y", "x", "z")) {
          values <- correlation_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            values <- if (is.null(mapped)) rep(NA_real_, length(values)) else mapped[as.integer(values)]
          }
          correlation_1_input[[column]] <- as.numeric(values)
        }
      })
      
      # ggplot2 figure: Pearson correlations.
      if (correlation_1_ready) figure_try("correlation_1-ggplot2", {
        # 1. Correlations of every pair of variables (pairwise complete cases),
        #    Pearson's r controlling for z, p-values corrected by the none method.
        correlation_1_vars <- c("y", "x")
        correlation_1_pairs <- utils::combn(correlation_1_vars, 2L, simplify = FALSE)
        correlation_1_cells <- do.call(rbind, lapply(correlation_1_pairs, function(pair) {
          columns <- c(pair, c("z"))
          complete <- stats::complete.cases(correlation_1_input[, columns])
          part <- correlation_1_input[complete, columns, drop = FALSE]
          design <- cbind(1, as.matrix(part[, c("z"), drop = FALSE]))
          residual <- function(v) stats::lm.fit(design, part[[v]])$residuals
          r <- stats::cor(residual(pair[1]), residual(pair[2]))
          df <- nrow(part) - 2L - 1L
          t <- r * sqrt(df / (1 - r^2))
          data.frame(Var1 = pair[1], Var2 = pair[2], r = r, p = 2 * stats::pt(-abs(t), df), n = nrow(part))
        }))
        correlation_1_cells$p_adjusted <- stats::p.adjust(correlation_1_cells$p, method = "none")
        correlation_1_cells$Var1 <- factor(correlation_1_cells$Var1, levels = correlation_1_vars)
        correlation_1_cells$Var2 <- factor(correlation_1_cells$Var2, levels = correlation_1_vars)
        correlation_1_cells <- correlation_1_cells[order(correlation_1_cells$Var2, correlation_1_cells$Var1), ]
        correlation_1_cells$value <- round(correlation_1_cells$r, 2)
        correlation_1_crossed <- correlation_1_cells[!is.na(correlation_1_cells$p_adjusted) & correlation_1_cells$p_adjusted > 0.05, ]
      
        # Legend title: sample size and method.
        correlation_1_n_label <- if (length(unique(correlation_1_cells$n)) == 1L) {
          bquote(atop(scriptstyle(bold("sample sizes:")), italic(n) ~ "=" ~ .(prettyNum(correlation_1_cells$n[1], big.mark = ","))))
        } else {
          correlation_1_mode <- as.numeric(names(which.max(table(correlation_1_cells$n))))
          bquote(atop(atop(scriptstyle(bold("sample sizes:")), italic(n)[min] ~ "=" ~ .(prettyNum(min(correlation_1_cells$n), big.mark = ","))),
            atop(italic(n)[mode] ~ "=" ~ .(prettyNum(correlation_1_mode, big.mark = ",")), italic(n)[max] ~ "=" ~ .(prettyNum(max(correlation_1_cells$n), big.mark = ",")))))
        }
        correlation_1_legend <- bquote(atop(.(correlation_1_n_label), atop(scriptstyle(bold("correlation (partial):")), Pearson)))
      
        # 2. The figure
        correlation_1_plot <- ggplot2::ggplot(correlation_1_cells, ggplot2::aes(x = Var1, y = Var2, fill = value)) +
          # tiles coloured by the correlation
          ggplot2::geom_tile(colour = "black") +
          # crosses: not significant after correction (grey, under the numbers so they stay readable)
          ggplot2::geom_point(data = correlation_1_crossed, ggplot2::aes(x = Var1, y = Var2), inherit.aes = FALSE,
            shape = "cross", size = 14, colour = "grey60") +
          # the coefficient in each cell
          ggplot2::geom_text(ggplot2::aes(x = Var1, y = Var2), label = ifelse(is.na(correlation_1_cells$value), "", correlation_1_cells$value),
            colour = "black",
            size = 4, fontface = "plain", family = figure_font) +
          ggplot2::scale_fill_gradient2(low = "#EA4335", mid = "white", high = "#4285F4", midpoint = 0,
            limits = c(-1, 1), space = "Lab", na.value = "grey85", name = correlation_1_legend) +
          ggplot2::labs(x = NULL, y = NULL, title = NULL, subtitle = NULL,
            caption = quote(atop(displaystyle(NULL), expr = bold("X") ~ "= non-significant at" ~ (italic(p)[unadj.] ~ "< " ~ 0.05)))) +
          theme_figure() +
          ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, vjust = 1, size = 12, hjust = 1),
            axis.text.y = ggplot2::element_text(size = 12), panel.grid.major = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(), legend.title = ggplot2::element_text(size = 15)) +
          ggplot2::coord_fixed()
        figure_show(correlation_1_plot)
        figure_save(correlation_1_plot, "figures/correlation_1-ggplot2")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- logistic_1: jmv::logRegBin (line 1) -----------------------------------
      # Source: jmv::logRegBin(data = d, dep = "c1", covs = c("x", "z"), factors =
      #         "h", blocks = list(list("x"), list("z", "h")), refLevels =
      #         list(list(var = "h", ref = "Q")))
      # Figure: the odds ratio of each predictor of c1 (the intercept omitted) with
      #         its 95% Wald confidence interval, as jamovi computes them, on a log
      #         scale.
      # Differs from jamovi: odds ratios are shown (jamovi's table shows log-odds
      #                      unless OR is ticked).
      logistic_1_ready <- figure_try("logistic_1", {
        # Analysis data: a copy of d as it is at this point.
        logistic_1_input <- d
        if (!is.data.frame(logistic_1_input)) stop("The analysis data must be a data frame.")
        logistic_1_missing <- setdiff(c("c1", "h", "x", "z"), names(logistic_1_input))
        if (length(logistic_1_missing)) stop("Column(s) not found: ", toString(logistic_1_missing))
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in c("x", "z")) {
          values <- logistic_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          logistic_1_input[[column]] <- as.numeric(values)
        }
        # Grouping columns become factors (SPSS value labels name the levels).
        for (column in c("c1", "h")) {
          values <- logistic_1_input[[column]]
          logistic_1_input[[column]] <- if (inherits(values, "haven_labelled")) haven::as_factor(values) else factor(values)
        }
        logistic_1_input[["h"]] <- stats::relevel(factor(logistic_1_input[["h"]]), ref = "Q")
        # Case weights set in jamovi; without them every row counts once.
        logistic_1_weights <- attr(logistic_1_input, "jmv-weights", exact = TRUE)
        if (is.null(logistic_1_weights)) logistic_1_weights <- rep(1, nrow(logistic_1_input))
        if (!is.numeric(logistic_1_weights)) logistic_1_weights <- attr(logistic_1_weights, "values", exact = TRUE)[as.integer(logistic_1_weights)]
        if (length(logistic_1_weights) != nrow(logistic_1_input) || anyNA(logistic_1_weights) || any(logistic_1_weights < 0)) stop("Invalid case weights.")
        if (nlevels(logistic_1_input[["c1"]]) != 2L) stop("The logistic outcome must have exactly two levels.")
        # Model: the jamovi-equivalent logistic regression c1 ~ x + z + h (final block, with the case weights).
        logistic_1_model <- stats::glm(c1 ~ x + z + h, data = logistic_1_input, weights = logistic_1_weights, family = stats::binomial(), na.action = stats::na.omit)
        if (!isTRUE(logistic_1_model$converged) || any(!is.finite(stats::coef(logistic_1_model)))) {
          stop("The logistic model did not converge or has coefficients that cannot be estimated.")
        }
      })
      
      # ggplot2 figure: Odds ratios predicting c1.
      if (logistic_1_ready) figure_try("logistic_1-ggplot2", {
        # 1. Coefficient table: estimate, Wald (normal) confidence interval, test statistic, p-value.
        logistic_1_summary <- summary(logistic_1_model)$coefficients
        logistic_1_intervals <- stats::confint.default(logistic_1_model, level = 0.95)
        logistic_1_table <- data.frame(
          term = rownames(logistic_1_summary),
          estimate = logistic_1_summary[, 1],
          conf.low = logistic_1_intervals[rownames(logistic_1_summary), 1],
          conf.high = logistic_1_intervals[rownames(logistic_1_summary), 2],
          statistic = logistic_1_summary[, 3],
          p.value = logistic_1_summary[, 4],
          df.error = if (inherits(logistic_1_model, "glm") && !(family(logistic_1_model)$family %in% c("gaussian", "Gamma", "inverse.gaussian", "quasi"))) NA_real_ else stats::df.residual(logistic_1_model),
          row.names = NULL
        )
        logistic_1_table <- logistic_1_table[!grepl("(Intercept)", logistic_1_table$term, fixed = TRUE), , drop = FALSE]
        # Odds ratios: exponentiated estimates and interval limits.
        logistic_1_table[c("estimate", "conf.low", "conf.high")] <- exp(logistic_1_table[c("estimate", "conf.low", "conf.high")])
        # Readable names for factor coefficients, e.g. "framing: loss vs gain".
        for (factor_name in names(logistic_1_model$xlevels)) {
          levels <- logistic_1_model$xlevels[[factor_name]]
          coded <- logistic_1_table$term %in% paste0(factor_name, levels[-1])
          logistic_1_table$term[coded] <- paste0(factor_name, ": ", substring(logistic_1_table$term[coded], nchar(factor_name) + 1L),
            " vs ", levels[1])
        }
        # Terms listed top to bottom in model order.
        logistic_1_table$term <- factor(logistic_1_table$term, levels = rev(unique(logistic_1_table$term)))
      
        # 2. The figure
        logistic_1_plot <- ggplot2::ggplot(logistic_1_table, ggplot2::aes(x = estimate, y = term)) +
          # estimate
          ggplot2::geom_point(size = 3, colour = "blue", na.rm = TRUE) +
          # 95% confidence interval
          ggplot2::geom_errorbar(ggplot2::aes(xmin = conf.low, xmax = conf.high), orientation = "y", width = 0, na.rm = TRUE) +
          # no effect (1)
          ggplot2::geom_vline(xintercept = 1, linewidth = 1, linetype = "dashed") +
          ggplot2::scale_x_log10() +
          ggplot2::labs(x = "odds ratio", y = "term", caption = NULL, subtitle = NULL, title = NULL) +
          theme_figure() +
          ggplot2::theme(plot.caption = ggplot2::element_text(size = 10))
        figure_show(logistic_1_plot)
        figure_save(logistic_1_plot, "figures/logistic_1-ggplot2")
      })
      
      # BetterGG figure: Odds ratios predicting c1. (BetterGG)
      if (logistic_1_ready) figure_try("logistic_1-bettergg", {
        logistic_1_bettergg <- BetterGG::ggcoefstats(
          x = logistic_1_model, conf.level = 0.95, exclude.intercept = TRUE,
          stats.labels = FALSE, bf.message = FALSE
        )
        figure_show(logistic_1_bettergg)
        figure_save(logistic_1_bettergg, "figures/logistic_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- reliability_1: jmv::reliability (line 1) ------------------------------
      # Source: jmv::reliability(data = d, vars = c("q1", "q2", "q3"), revItems =
      #         "q2")
      # Figure: the responses to each item and each item's correlation with the sum
      #         of the other items (q2 reverse-scored as jamovi does); complete
      #         rows only, as jamovi.
      # Differs from jamovi: nothing known.
      reliability_1_ready <- figure_try("reliability_1", {
        # Analysis data: a copy of d as it is at this point.
        reliability_1_input <- d
        if (!is.data.frame(reliability_1_input)) stop("The analysis data must be a data frame.")
        reliability_1_missing <- setdiff(c("q1", "q2", "q3"), names(reliability_1_input))
        if (length(reliability_1_missing)) stop("Column(s) not found: ", toString(reliability_1_missing))
        if (!is.null(attr(reliability_1_input, "jmv-weights", exact = TRUE))) {
          stop("Weighted reliability mapping is unavailable. Keep the original analysis rather than substituting an unweighted one.")
        }
        # Numeric columns: jamovi's stored values replace factor codes.
        for (column in c("q1", "q2", "q3")) {
          values <- reliability_1_input[[column]]
          if (!is.numeric(values)) {
            mapped <- attr(values, "values", exact = TRUE)
            if (is.null(mapped) || !is.numeric(mapped)) stop("Column ", column, " must be numeric or have a numeric values mapping.")
            values <- mapped[as.integer(values)]
          }
          reliability_1_input[[column]] <- as.numeric(values)
        }
      })
      
      # ggplot2 figure: Item responses and item-rest correlations.
      if (reliability_1_ready) figure_try("reliability_1-ggplot2", {
        # 1. Data: the items, complete rows only (listwise), as numbers.
        reliability_1_items <- c("q1", "q2", "q3")
        reliability_1_data <- reliability_1_input[, reliability_1_items, drop = FALSE]
        reliability_1_data <- reliability_1_data[stats::complete.cases(reliability_1_data), , drop = FALSE]
        if (!all(vapply(reliability_1_data, is.numeric, logical(1)))) stop("Reliability items must be numeric.")
        reliability_1_reverse <- c("q2")
        # Reverse-scored items: (minimum + maximum) - value, as in jamovi.
        for (item in reliability_1_reverse) {
          reliability_1_data[[item]] <- min(reliability_1_data[[item]]) + max(reliability_1_data[[item]]) - reliability_1_data[[item]]
        }
        reliability_1_labels <- ifelse(reliability_1_items %in% reliability_1_reverse, paste0(reliability_1_items, " (R)"), reliability_1_items)
      
        # 2. Item-rest correlations and Cronbach's alpha.
        # A correlation with a constant (an item, or the sum of the other items) is not
        # estimable: it is labelled so and named in a warning, never shown as NA.
        reliability_1_rest <- vapply(reliability_1_items, function(item) {
          rest_sum <- rowSums(reliability_1_data[setdiff(reliability_1_items, item)])
          if (stats::sd(reliability_1_data[[item]]) == 0 || stats::sd(rest_sum) == 0) return(NA_real_)
          stats::cor(reliability_1_data[[item]], rest_sum)
        }, numeric(1))
        if (anyNA(reliability_1_rest)) {
          warning("BetterGG: item-rest correlation not estimable for ", paste(reliability_1_items[is.na(reliability_1_rest)], collapse = ", "),
            " (the item, or the sum of the other items, has the same value in every row).", call. = FALSE)
        }
        reliability_1_k <- length(reliability_1_items)
        reliability_1_total_var <- stats::var(rowSums(reliability_1_data))
        reliability_1_alpha <- if (reliability_1_total_var > 0) reliability_1_k / (reliability_1_k - 1) *
          (1 - sum(vapply(reliability_1_data, stats::var, numeric(1))) / reliability_1_total_var) else NA_real_
        if (is.na(reliability_1_alpha)) {
          warning("BetterGG: Cronbach's alpha not estimable (the total score has the same value in every row).",
            call. = FALSE)
        }
        reliability_1_correlations <- data.frame(item = factor(reliability_1_labels, levels = rev(reliability_1_labels)), r = unname(reliability_1_rest))
        reliability_1_correlations$label <- ifelse(is.na(reliability_1_correlations$r), "not estimable",
          sub("^(-?)0[.]", "\\1.", formatC(reliability_1_correlations$r, format = "f", digits = 2)))
        reliability_1_correlations$label_x <- ifelse(is.na(reliability_1_correlations$r), 0, reliability_1_correlations$r)
        reliability_1_correlations$label_hjust <- ifelse(is.na(reliability_1_correlations$r), 0, 0.5) # "not estimable" runs right from 0
      
        # 3. Responses in long format (one row per person and item).
        reliability_1_values <- sort(unique(unlist(reliability_1_data, use.names = FALSE)))
        reliability_1_long <- data.frame(
          item = factor(rep(reliability_1_labels, each = nrow(reliability_1_data)), levels = rev(reliability_1_labels)),
          value = unlist(reliability_1_data, use.names = FALSE)
        )
      
        # 4. The figure: responses (left) and item-rest correlations (right).
        if (length(reliability_1_values) <= 10L) {
          # Few distinct values (e.g. Likert items): 100% stacked bars per item.
          reliability_1_long$response <- factor(reliability_1_long$value, levels = reliability_1_values)
          reliability_1_responses <- ggplot2::ggplot(reliability_1_long, ggplot2::aes(y = item, fill = response)) +
            ggplot2::geom_bar(position = ggplot2::position_fill(reverse = TRUE), colour = "white", width = 0.7) +
            ggplot2::scale_x_continuous(labels = function(p) paste0(round(100 * p), "%"), expand = c(0, 0)) +
            ggplot2::scale_fill_manual(values = grDevices::hcl.colors(length(reliability_1_values), "viridis")) +
            ggplot2::labs(x = "responses", y = NULL, fill = "response") +
            theme_figure() +
            ggplot2::theme(legend.position = "bottom", plot.margin = ggplot2::margin(5.5, 14, 5.5, 5.5))
        } else {
          # Many distinct values: density with median and interquartile range per item.
          reliability_1_responses <- ggplot2::ggplot(reliability_1_long, ggplot2::aes(x = value, y = item)) +
            ggdist::stat_halfeye(fill = "grey70", point_colour = "black", interval_colour = "black",
              .width = 0.5, point_interval = "median_qi") +
            ggplot2::labs(x = "response", y = NULL) +
            theme_figure()
        }
        reliability_1_rest_plot <- ggplot2::ggplot(reliability_1_correlations, ggplot2::aes(x = r, y = item)) +
          ggplot2::geom_vline(xintercept = 0, colour = "grey60", linetype = "dashed") +
          ggplot2::geom_segment(ggplot2::aes(x = 0, xend = r, yend = item), colour = "grey40", na.rm = TRUE) +
          ggplot2::geom_point(size = 3, colour = "black", na.rm = TRUE) +
          ggplot2::geom_text(ggplot2::aes(x = label_x, label = label, hjust = label_hjust), nudge_y = 0.3, size = 3,
            family = figure_font) +
          ggplot2::scale_x_continuous(limits = c(min(0, reliability_1_correlations$r, na.rm = TRUE), 1), breaks = c(0, 0.5, 1)) +
          # labels near the panel edge (a negative r, "not estimable") are drawn, not cut off
          ggplot2::coord_cartesian(clip = "off") +
          ggplot2::labs(x = "item-rest correlation", y = NULL) +
          theme_figure() +
          ggplot2::theme(axis.text.y = ggplot2::element_blank())
        reliability_1_plot <- patchwork::wrap_plots(reliability_1_responses, reliability_1_rest_plot, widths = c(2, 1)) +
          patchwork::plot_annotation(title = NULL, subtitle = NULL, theme = theme_figure())
        figure_show(reliability_1_plot)
        figure_save(reliability_1_plot, "figures/reliability_1-ggplot2")
      })
      
      # BetterGG figure: Item responses and item-rest correlations.
      if (reliability_1_ready) figure_try("reliability_1-bettergg", {
        reliability_1_bettergg <- BetterGG::ggreliability(
          data = reliability_1_input, items = c("q1", "q2", "q3"), reverse = "q2",
          stats = FALSE
        )
        figure_show(reliability_1_bettergg)
        figure_save(reliability_1_bettergg, "figures/reliability_1-bettergg")
      })

---

    Code
      cat(generate_analysis(a, "both", options)$code)
    Output
      # ---- withinstats_1: ggstatsplot::ggwithinstats (line 1) --------------------
      # Source: ggstatsplot::ggwithinstats(data = long, x = cond, y = score,
      #         subject.id = id)
      # Figure: each subject's values of score in each condition of cond, their
      #         distribution and the condition centres.
      # Differs from jamovi: with three or more groups the source plot showed the
      #                      significant pairwise comparisons; the ggplot2 figure
      #                      draws none because statistics on figures are off.
      withinstats_1_ready <- figure_try("withinstats_1", {
        # Analysis data: a copy of long as it is at this point.
        withinstats_1_input <- long
        if (!is.data.frame(withinstats_1_input)) stop("The analysis data must be a data frame.")
        withinstats_1_missing <- setdiff(c("id", "cond", "score"), names(withinstats_1_input))
        if (length(withinstats_1_missing)) stop("Column(s) not found: ", toString(withinstats_1_missing))
      })
      
      # ggplot2 figure: score by cond (within subjects).
      if (withinstats_1_ready) figure_try("withinstats_1-ggplot2", {
        # 1. Data (long format): subjects with a value of "score" in every condition.
        withinstats_1_data <- withinstats_1_input[!is.na(withinstats_1_input[["cond"]]) & !is.na(withinstats_1_input[["id"]]), , drop = FALSE]
        withinstats_1_data[["cond"]] <- droplevels(as.factor(withinstats_1_data[["cond"]]))
        if (anyDuplicated(withinstats_1_data[, c("cond", "id")])) {
          stop("Each subject must appear at most once per condition; aggregate repeated rows first.")
        }
        withinstats_1_data <- withinstats_1_data[!is.na(withinstats_1_data[["score"]]), , drop = FALSE]
        withinstats_1_count <- table(withinstats_1_data[["id"]])
        withinstats_1_complete <- names(withinstats_1_count)[withinstats_1_count == nlevels(withinstats_1_data[["cond"]])]
        withinstats_1_data <- withinstats_1_data[as.character(withinstats_1_data[["id"]]) %in% withinstats_1_complete, , drop = FALSE]
        withinstats_1_data <- withinstats_1_data[order(withinstats_1_data[["id"]], withinstats_1_data[["cond"]], method = "radix"), , drop = FALSE]
      
        # The rain sits beside each box; with two conditions the first is mirrored so
        # each subject's line joins the two inner columns of points.
        withinstats_1_levels <- levels(withinstats_1_data[["cond"]])
        withinstats_1_position <- match(as.character(withinstats_1_data[["cond"]]), withinstats_1_levels)
        withinstats_1_mirror <- length(withinstats_1_levels) == 2L
        withinstats_1_data$rain_x <- withinstats_1_position + ifelse(withinstats_1_mirror & withinstats_1_position == 1L, 0.22, -0.22)
      
        # 2. Condition sizes and the condition mean shown as a labelled point.
        withinstats_1_groups <- split(withinstats_1_data[["score"]], withinstats_1_data[["cond"]])
        withinstats_1_summary <- data.frame(
          level = factor(names(withinstats_1_groups), levels = withinstats_1_levels),
          value = vapply(withinstats_1_groups, function(values) mean(values), numeric(1)),
          n = lengths(withinstats_1_groups)
        )
        withinstats_1_summary$label <- paste0("list(widehat(mu)[mean]=='",
          formatC(withinstats_1_summary$value, format = "f", digits = 2), "')")
        withinstats_1_summary$axis_label <- paste0(withinstats_1_summary$level, "
        (n = ",
          prettyNum(withinstats_1_summary$n, big.mark = ","), ")")
      
        # Clouds: with two conditions the first one opens to the left.
        if (withinstats_1_mirror) {
          withinstats_1_clouds <- list(
            ggdist::stat_slab(data = withinstats_1_data[withinstats_1_position == 1L, , drop = FALSE],
            ggplot2::aes(fill = cond, group = cond),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = 1.25, side = "left"),
            ggdist::stat_slab(data = withinstats_1_data[withinstats_1_position != 1L, , drop = FALSE],
            ggplot2::aes(fill = cond, group = cond),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = -0.25)
          )
        } else {
          withinstats_1_clouds <- list(ggdist::stat_slab(ggplot2::aes(fill = cond, group = cond),
            colour = NA, adjust = 1, width = 0.5, alpha = 0.5, normalize = "groups", justification = -0.25))
        }
        # Subject lines are drawn only for two conditions.
        withinstats_1_subject_lines <- if (withinstats_1_mirror) {
          ggplot2::geom_path(ggplot2::aes(x = rain_x), alpha = 0.5, linetype = "dashed")
        }
      
        # 3. The figure
        withinstats_1_plot <- ggplot2::ggplot(withinstats_1_data, ggplot2::aes(x = cond, y = score, group = id)) +
          # cloud: the distribution in each condition (half density)
          withinstats_1_clouds +
          # rain: every observation
          ggplot2::geom_point(ggplot2::aes(x = rain_x, colour = cond), size = 2, alpha = 0.5, na.rm = TRUE) +
          # box: median and quartiles
          ggplot2::geom_boxplot(ggplot2::aes(group = cond), width = 0.12, alpha = 0.6, outlier.shape = NA, na.rm = TRUE) +
          # two conditions: each subject's values joined by a dashed line
          withinstats_1_subject_lines +
          # condition means: joined by a line, labelled
          ggplot2::geom_path(data = withinstats_1_summary, ggplot2::aes(x = level, y = value, group = 1L),
            inherit.aes = FALSE, linewidth = 1, colour = "red", alpha = 0.5) +
          ggplot2::geom_point(data = withinstats_1_summary, ggplot2::aes(x = level, y = value),
            inherit.aes = FALSE, size = 4, colour = "black") +
          ggrepel::geom_label_repel(data = withinstats_1_summary, ggplot2::aes(x = level, y = value, label = label),
            inherit.aes = FALSE, parse = TRUE, size = 3, nudge_x = 0.4, segment.linetype = 4,
            min.segment.length = 0, family = figure_font) +
          ggplot2::scale_x_discrete(labels = withinstats_1_summary$axis_label) +
          ggplot2::scale_y_continuous(sec.axis = ggplot2::dup_axis(name = NULL, breaks = NULL, labels = NULL)) +
          ggplot2::scale_colour_manual(values = figure_colours) +
          ggplot2::scale_fill_manual(values = figure_fills) +
          ggplot2::labs(x = "cond", y = "score", colour = "cond", title = NULL, subtitle = NULL, caption = NULL) +
          theme_figure() +
          ggplot2::theme(legend.position = "none", panel.grid.major.x = ggplot2::element_blank())
        figure_show(withinstats_1_plot)
        figure_save(withinstats_1_plot, "figures/withinstats_1-ggplot2")
      })
      
      # BetterGG figure: BetterGG version of the source ggwithinstats() call.
      if (withinstats_1_ready) figure_try("withinstats_1-bettergg-source", {
        withinstats_1_bettergg <- BetterGG::ggwithinstats(data = withinstats_1_input, x = cond, y = score, subject.id = id)
        figure_show(withinstats_1_bettergg)
        figure_save(withinstats_1_bettergg, "figures/withinstats_1-bettergg-source")
      })

