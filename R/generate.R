# One analysis -> one commented figure block.
#
# Each mapping (R/map-*.R) fills a context: the data-preparation steps, the
# figures (code from BetterGG's recipes for the ggplot2 engine, or a real
# BetterGG call), plain-language notes and diagnostics. assemble_block()
# turns that into the generated code.

generate_analysis <- function(a, engine, options) {
  if (a$status == "unsupported") stop("This function or argument signature is not supported: ", a$function_name)
  ctx <- new_context(a, engine, options)
  mapper <- analysis_mapper(a$function_name)
  if (is.null(mapper)) stop("Mapping is not yet implemented for ", a$function_name, ". Original code and inference are preserved.")
  mapper(ctx)
  if (!length(ctx$figures)) stop("No faithful requested plot mapping is available for this analysis.")
  assemble_block(ctx)
}

analysis_mapper <- function(fn) {
  switch(fn,
    ANOVA = , ancova = , anovaOneW = , anovaNP = , ggbetweenstats = map_between,
    ttestIS = map_ttest_independent,
    ttestPS = , anovaRM = , ggwithinstats = map_within,
    ttestOneS = , gghistostats = map_histogram,
    descriptives = map_descriptives,
    contTables = , contTablesPaired = , propTest2 = , propTestN = , ggbarstats = , ggpiestats = map_categorical,
    corrMatrix = , corrPart = , ggcorrmat = map_correlation,
    logRegBin = , linReg = , ggcoefstats = map_regression,
    ggscatterstats = map_scatter,
    reliability = map_reliability,
    grouped_ggbetweenstats = , grouped_ggwithinstats = , grouped_gghistostats = , grouped_ggscatterstats = ,
    grouped_ggbarstats = , grouped_ggpiestats = , grouped_ggcorrmat = map_grouped_ggstatsplot,
    NULL
  )
}

new_context <- function(a, engine, options) {
  ctx <- new.env(parent = emptyenv())
  ctx$a <- a
  ctx$fn <- a$function_name
  ctx$name <- analysis_name(a)
  ctx$engines <- if (engine == "both") c("ggplot2", "bettergg") else engine
  ctx$options <- options
  ctx$stats <- isTRUE(options$style$stats)
  ctx$prep <- character()
  ctx$figures <- list()
  ctx$diagnostics <- list()
  ctx$describe <- character()
  ctx$differs <- character()
  ctx$mapping <- "visualization_only"
  ctx$packages <- character()
  ctx$vars <- character()
  data_expr <- a$args$data
  if (a$package %in% c("jmv", "ggstatsplot", "BetterGG") && !identical(ctx$fn, "ggcoefstats")) {
    if (is.null(data_expr) || !is.symbol(data_expr)) {
      stop("Use a stable named data frame in data=; dynamic data expressions are preserved without conversion.")
    }
    ctx$data <- as.character(data_expr)
    ctx$input <- paste0(ctx$name, "_input")
  }
  level <- as.numeric(arg_value(a, "conf.level", as.numeric(arg_value(a, "ciWidthEmm", arg_value(a, "ciWidth", 95))) / 100))
  if (!is.finite(level) || level <= 0 || level >= 1) stop("CI width must be between 0 and 100.")
  ctx$level <- level
  ctx
}

# ---- small helpers used by the mappings ------------------------------------

add_prep <- function(ctx, ...) ctx$prep <- c(ctx$prep, ...)

add_note <- function(ctx, message, code = "alternative_analysis", severity = "warning") {
  ctx$diagnostics <- c(ctx$diagnostics, list(diag_record(severity, code, message, ctx$a$id, ctx$a$line)))
  if (code == "alternative_analysis") ctx$mapping <- "alternative_analysis"
  invisible(message)
}

unavailable <- function(ctx, message) {
  ctx$diagnostics <- c(ctx$diagnostics, list(diag_record("warning", "bettergg_mapping_unavailable", message, ctx$a$id, ctx$a$line)))
}

# A figure: `code` creates `object`; the block shows and saves it.
add_figure <- function(ctx, engine, code, object, caption, suffix = NULL, packages = character(), note = NULL) {
  stem <- paste(c(ctx$name, engine, if (!is.null(suffix)) safe_id(suffix)), collapse = "-")
  ctx$figures[[length(ctx$figures) + 1L]] <- list(engine = engine, code = code, object = object,
    caption = caption, stem = stem, note = note)
  ctx$packages <- c(ctx$packages, engine_packages(engine, packages))
  invisible(stem)
}

wants <- function(ctx, engine) engine %in% ctx$engines

q <- function(x) r_string(x)

# The source call's options, written for the header comment.
source_summary <- function(a) {
  text <- gsub("\\s+", " ", a$original)
  if (nchar(text) > 300L) text <- paste0(substr(text, 1L, 297L), "...")
  text
}

comment_wrap <- function(prefix, text, width = 78L) {
  if (!length(text) || !nzchar(paste(text, collapse = ""))) return(character())
  wrapped <- strwrap(paste(text, collapse = " "), width = width - nchar(prefix) - 2L)
  c(paste0("# ", prefix, wrapped[1]), if (length(wrapped) > 1L) paste0("#", strrep(" ", nchar(prefix) + 1L), wrapped[-1]))
}

indent <- function(code, by = "  ") {
  lines <- strsplit(paste(code, collapse = "\n"), "\n", fixed = TRUE)[[1]]
  ifelse(nzchar(lines), paste0(by, lines), lines)
}

assemble_block <- function(ctx) {
  a <- ctx$a
  name <- ctx$name
  verbose <- isTRUE(ctx$options$style$verbose)
  title <- paste0("# ---- ", name, ": ", a$package, "::", ctx$fn, " (line ", a$line, ") ")
  header <- c(
    paste0(title, strrep("-", max(4L, 78L - nchar(title)))),
    if (verbose) c(
      comment_wrap("Source: ", source_summary(a)),
      comment_wrap("Figure: ", ctx$describe),
      comment_wrap("Differs from jamovi: ", if (length(ctx$differs)) ctx$differs else "nothing known.")
    )
  )
  prep <- c(
    paste0(name, "_ready <- figure_try(", q(name), ", {"),
    indent(ctx$prep),
    "})"
  )
  figures <- character()
  for (f in ctx$figures) {
    file <- paste0("figures/", f$stem)
    figures <- c(figures, "",
      paste0("# ", if (f$engine == "bettergg") "BetterGG figure" else "ggplot2 figure", ": ", f$caption),
      if (!is.null(f$note)) comment_wrap("Note: ", f$note),
      paste0("if (", name, "_ready) figure_try(", q(f$stem), ", {"),
      indent(f$code),
      indent(paste0(f$object, " <- figure_relabel(", f$object, ")")),
      indent(paste0("figure_show(", f$object, ")")),
      indent(paste0("figure_save(", f$object, ", ", q(file), ")")),
      "})"
    )
  }
  code <- paste(c(header, prep, figures), collapse = "\n")
  formats <- ctx$options$figures$formats
  plots <- lapply(ctx$figures, function(f) list(id = paste0(name, "_", f$engine, "_", f$stem),
    analysis_id = a$id, name = name, engine = f$engine,
    filename = paste0("figures/", f$stem, ".png"),
    files = paste0("figures/", f$stem, ".", formats),
    caption = f$caption, object = f$object, packages = unique(ctx$packages),
    preview = if (f$engine == "bettergg") "local_only" else "requires_runtime_test",
    statistical_note = f$note))
  list(code = code, plots = plots, diagnostics = ctx$diagnostics, mapping = ctx$mapping,
    packages = unique(ctx$packages), name = name, labels = figure_label_values(ctx$vars, ctx$options$style))
}

# Tidyverse style via 'styler', for all generated code of a document at once.
# Loading styler also loads R.utils, whose names() method for "Options"
# objects breaks jmv for the rest of an R session, so styler runs in a separate
# R process (callr). Returns NULL when styler cannot run.
style_codes <- function(codes) {
  if (!length(codes)) return(codes)
  style_one <- function(codes) {
    stats::setNames(lapply(seq_along(codes), function(k) {
      # A piece may be one string or a vector of lines; style all of it (0.2.1 dropped every line after the first).
      paste(as.character(suppressMessages(suppressWarnings(styler::style_text(strsplit(paste(codes[[k]], collapse = "
"), "
", fixed = TRUE)[[1]])))),
        collapse = "
")
    }), names(codes))
  }
  if (!requireNamespace("callr", quietly = TRUE)) return(NULL)
  tryCatch(callr::r(function(codes, style_one) {
    if (!requireNamespace("styler", quietly = TRUE)) return(NULL)
    style_one(codes)
  }, args = list(codes = codes, style_one = style_one), libpath = .libPaths()), error = function(e) NULL)
}

# The browser keeps jmv2gg's own layout. In WebR 0.6.0 styler took 36-57 s for each
# ~100-line figure block of the bundled complex example (about 0.4 s per line), and a
# conversion of that example stopped after several minutes with "A non-local transfer of
# control occurred during evaluation".
styler_browser_note <- function() {
  diag_record("info", "styler_browser", paste0("The browser keeps jmv2gg's own code layout: tidying it with ",
    "styler takes about a minute per analysis here. To tidy it, convert with the jmv2gg R package, ",
    "or run styler::style_file() on the downloaded file."))
}

# Style the generated pieces in place; a note says when styler was unavailable or not run.
style_generated <- function(pieces, options, browser = grepl("emscripten", R.version$platform)) {
  if (!isTRUE(options$style$styler) || !length(pieces)) return(list(pieces = pieces, diagnostics = list()))
  if (browser) return(list(pieces = pieces, diagnostics = list(styler_browser_note())))
  styled <- style_codes(pieces)
  if (is.null(styled)) {
    return(list(pieces = pieces, diagnostics = list(diag_record("info", "styler_unavailable",
      "The styler package was not available, so the generated code keeps jmv2gg's own layout."))))
  }
  list(pieces = stats::setNames(styled, names(pieces)), diagnostics = list())
}

# ---- data preparation code -------------------------------------------------

# Copy the analysis data as it is at this point of the source.
prep_input <- function(ctx) {
  if (identical(ctx$data, ctx$input)) {
    add_prep(ctx, paste0("# Analysis data: ", ctx$input, " is a copy of the analysis data taken right after the source analysis."))
  } else {
    add_prep(ctx, paste0("# Analysis data: a copy of ", ctx$data, " as it is at this point."),
      paste0(ctx$input, " <- ", r_sym(ctx$data)))
  }
  add_prep(ctx, paste0("if (!is.data.frame(", ctx$input, ")) stop(\"The analysis data must be a data frame.\")"))
}

prep_columns <- function(ctx, vars) {
  vars <- unique(vars)
  ctx$vars <- unique(c(ctx$vars, vars))
  add_prep(ctx,
    paste0(ctx$name, "_missing <- setdiff(", r_text(vars), ", names(", ctx$input, "))"),
    paste0("if (length(", ctx$name, "_missing)) stop(\"Column(s) not found: \", toString(", ctx$name, "_missing))"))
}

# jamovi case weights (the "jmv-weights" attribute); every row counts once
# when there are none.
prep_weights <- function(ctx) {
  w <- paste0(ctx$name, "_weights")
  add_prep(ctx,
    "# Case weights set in jamovi; without them every row counts once.",
    paste0(w, " <- attr(", ctx$input, ", \"jmv-weights\", exact = TRUE)"),
    paste0("if (is.null(", w, ")) ", w, " <- rep(1, nrow(", ctx$input, "))"),
    paste0("if (!is.numeric(", w, ")) ", w, " <- attr(", w, ", \"values\", exact = TRUE)[as.integer(", w, ")]"),
    paste0("if (length(", w, ") != nrow(", ctx$input, ") || anyNA(", w, ") || any(", w, " < 0)) stop(\"Invalid case weights.\")"))
  w
}

# Families without a weighted mapping refuse weighted data visibly.
prep_refuse_weights <- function(ctx, what) {
  add_prep(ctx, paste0("if (!is.null(attr(", ctx$input, ", \"jmv-weights\", exact = TRUE))) {"),
    paste0("  stop(", q(paste0("Weighted ", what, " mapping is unavailable. Keep the original analysis rather than substituting an unweighted one.")), ")"),
    "}")
}

prep_numeric <- function(ctx, vars) {
  if (!length(vars)) return(invisible())
  add_prep(ctx, "# Numeric columns: jamovi's stored values replace factor codes.")
  add_prep(ctx, paste0("for (column in ", r_text(unique(vars)), ") {"),
    paste0("  values <- ", ctx$input, "[[column]]"),
    "  if (!is.numeric(values)) {",
    "    mapped <- attr(values, \"values\", exact = TRUE)",
    "    if (is.null(mapped) || !is.numeric(mapped)) stop(\"Column \", column, \" must be numeric or have a numeric values mapping.\")",
    "    values <- mapped[as.integer(values)]",
    "  }",
    paste0("  ", ctx$input, "[[column]] <- as.numeric(values)"),
    "}")
}

# Factors: SPSS value labels (haven) become the level names.
prep_factor <- function(ctx, vars) {
  if (!length(vars)) return(invisible())
  add_prep(ctx, "# Grouping columns become factors (SPSS value labels name the levels).")
  add_prep(ctx, paste0("for (column in ", r_text(unique(vars)), ") {"),
    paste0("  values <- ", ctx$input, "[[column]]"),
    paste0("  ", ctx$input, "[[column]] <- if (inherits(values, \"haven_labelled\")) haven::as_factor(values) else factor(values)"),
    "}")
}

prep_labelled_to_factor <- function(ctx, vars) {
  if (!length(vars)) return(invisible())
  add_prep(ctx, paste0("for (column in ", r_text(unique(vars)), ") {"),
    paste0("  if (inherits(", ctx$input, "[[column]], \"haven_labelled\")) ", ctx$input,
      "[[column]] <- haven::as_factor(", ctx$input, "[[column]])"),
    "}")
}

# Recipe code from BetterGG, without its setup (the document has one).
recipe <- function(fun, ...) {
  if (!requireNamespace("BetterGG", quietly = TRUE)) stop("BetterGG is needed to write the ggplot2 figures.")
  f <- getExportedValue("BetterGG", fun)
  f(..., setup = FALSE)
}

validate_formula_syntax <- function(x) {
  if(is.symbol(x) || is.numeric(x) || is.null(x)) return(invisible(TRUE))
  if(!is.call(x) || !is.symbol(x[[1]]) || !as.character(x[[1]]) %in% c("~","+","-","*",":","^","("))
    stop("Formula contains a computed expression. Use explicit outcome/predictor names and modelTerms; the source is preserved without execution.")
  for(arg in as.list(x)[-1]) validate_formula_syntax(arg)
  invisible(TRUE)
}
