jmv2gg_version <- "0.2.0"

# Names the setup code defines. Source code that defines one of them would be
# overwritten, so conversion refuses it.
figure_setup_names <- c(
  "figure_font", "figure_colours", "figure_fills", "theme_figure", "figure_apa_p",
  "figure_dpi", "figure_width", "figure_height", "figure_formats", "figure_background",
  "figure_optimize", "figure_seed", "figure_packages", "figure_package", "figure_try",
  "figure_show", "figure_save"
)

# The packages a figure engine needs when the generated code runs.
engine_packages <- function(engine, extra = character()) {
  base <- if (engine == "bettergg") "BetterGG" else "ggplot2"
  unique(c(base, extra))
}

package_version_text <- function(package) {
  version <- tryCatch(as.character(utils::packageVersion(package)), error = function(e) NA_character_)
  if (is.na(version)) paste(package, "(not installed where this was converted)") else paste(package, version)
}

# One setup block for the whole document: package check, the figure style
# (from BetterGG's recipe_setup(), written out in full), export settings and
# the small helpers every figure block uses. It runs without jmv2gg or
# BetterGG installed.
figure_setup_code <- function(options, packages) {
  style <- options$style
  figures <- options$figures
  packages <- sort(unique(packages))
  palette <- if (isTRUE(style$grayscale)) "grey" else style$palette
  formats <- figures$formats
  if (grepl("emscripten", R.version$platform)) formats <- "png"
  size_note <- switch(figures$size,
    single = "one journal column (3.5 in)",
    double = "two journal columns (7.2 in)",
    "the chosen size")
  lines <- c(
    paste0("# ---- Figure setup (jmv2gg ", jmv2gg_version, ") ", strrep("-", 40)),
    "# Runs without jmv2gg or BetterGG installed. Packages the figures use, with",
    "# the versions they were generated with:",
    paste0("#   ", vapply(packages, package_version_text, character(1))),
    paste0("figure_packages <- ", r_text(packages)),
    "for (figure_package in figure_packages) {",
    "  if (!requireNamespace(figure_package, quietly = TRUE)) {",
    "    message(\"Install the R package \", figure_package, \" to draw the jmv2gg figures that use it.\")",
    "  }",
    "}",
    "",
    BetterGG::recipe_setup(palette = palette, stats = isTRUE(style$stats)),
    "",
    paste0("# Export settings: ", size_note, ", ", paste(toupper(formats), collapse = ", "),
      if ("png" %in% formats || "tiff" %in% formats) paste0(", ", figures$dpi, " dpi") else "", "."),
    paste0("figure_width <- ", figures$width),
    paste0("figure_height <- ", figures$height),
    paste0("figure_dpi <- ", figures$dpi),
    paste0("figure_formats <- ", r_text(formats)),
    paste0("figure_background <- ", r_string(figures$background)),
    paste0("figure_optimize <- ", if (isTRUE(figures$optimize_png)) "TRUE" else "FALSE",
      " # lossless PNG optimisation (needs jmv2gg and oxipng)"),
    "# Figures that need random numbers (jitter, Bayes factors) use this seed and",
    "# then restore your own random-number state.",
    "figure_seed <- 1123",
    "",
    "# Run one step of the figure code. An error becomes a visible warning and the",
    "# rest of the report still runs. Random numbers (jitter, Bayes factors) use",
    "# figure_seed, and your own random-number state is restored afterwards.",
    "figure_try <- function(label, code) {",
    "  had_seed <- exists(\".Random.seed\", envir = globalenv(), inherits = FALSE)",
    "  if (had_seed) old_seed <- get(\".Random.seed\", envir = globalenv())",
    "  old_kind <- RNGkind()",
    "  on.exit({",
    "    do.call(RNGkind, as.list(old_kind))",
    "    if (had_seed) {",
    "      assign(\".Random.seed\", old_seed, envir = globalenv())",
    "    } else if (exists(\".Random.seed\", envir = globalenv(), inherits = FALSE)) {",
    "      rm(\".Random.seed\", envir = globalenv())",
    "    }",
    "  })",
    "  set.seed(figure_seed)",
    "  tryCatch({",
    "    code",
    "    TRUE",
    "  }, error = function(e) {",
    "    warning(\"jmv2gg: figure \", label, \" was not drawn: \", conditionMessage(e), call. = FALSE)",
    "    FALSE",
    "  })",
    "}",
    "",
    "# Show a figure in RStudio and in the knitted report.",
    "figure_show <- function(plot) {",
    "  if (interactive() || isTRUE(getOption(\"knitr.in.progress\"))) print(plot)",
    "  invisible(plot)",
    "}",
    "",
    "# Save a figure in every chosen format: PNG and TIFF (LZW) at figure_dpi,",
    "# PDF as vector graphics with the fonts embedded.",
    "figure_save <- function(plot, file, width = figure_width, height = figure_height) {",
    "  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)",
    "  in_browser <- grepl(\"emscripten\", R.version$platform)",
    "  for (format in figure_formats) {",
    "    path <- paste0(file, \".\", format)",
    "    if (format == \"png\") {",
    "      device <- if (in_browser) grDevices::png else ragg::agg_png",
    "      ggplot2::ggsave(path, plot, device = device, width = width, height = height, units = \"in\",",
    "        dpi = figure_dpi, bg = figure_background)",
    "      if (isTRUE(figure_optimize)) jmv2gg::optimize_png(path)",
    "    } else if (format == \"pdf\") {",
    "      device <- if (capabilities(\"cairo\")) grDevices::cairo_pdf else grDevices::pdf",
    "      ggplot2::ggsave(path, plot, device = device, width = width, height = height, units = \"in\",",
    "        bg = figure_background)",
    "    } else if (format == \"tiff\") {",
    "      ggplot2::ggsave(path, plot, device = ragg::agg_tiff, compression = \"lzw\", width = width,",
    "        height = height, units = \"in\", dpi = figure_dpi, bg = figure_background)",
    "    }",
    "  }",
    "  invisible(file)",
    "}"
  )
  paste(lines, collapse = "\n")
}
