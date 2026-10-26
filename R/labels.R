# Figure labels: the text readers see in place of column names.
#
# jamovi titles its plots with the column names (jmv's .prepareEmmPlots passes the
# term and dependent names to labs()). Column names such as
# "perceived_task_effort" are not publication text, and SPSS/jamovi variable
# descriptions are often whole survey questions, so the default is a tidied name.
# The generated setup holds one editable block, figure_labels and
# figure_level_labels, and figure_relabel() applies it to every figure when it is
# drawn: titles, legend titles, statistics lines and category names.

# "perceived_task_effort" -> "Perceived task effort".
tidy_label <- function(name) {
  text <- gsub("[_.]+", " ", name)
  text <- gsub("([[:alnum:]])\\(", "\\1 (", text)
  text <- trimws(gsub("[[:space:]]+", " ", text))
  if (!nzchar(text)) return(name)
  paste0(toupper(substr(text, 1L, 1L)), substring(text, 2L))
}

# Validated label options: labels = "tidy" or "names"; label_text = list(column = "text");
# level_text = list(column = list(category = "text")).
check_label_options <- function(s, input = list()) {
  if (!is.character(s$labels) || length(s$labels) != 1L || !s$labels %in% c("tidy", "names"))
    stop("labels must be \"tidy\" or \"names\".", call. = FALSE)
  is_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x)
  named <- function(x) is.list(x) && (!length(x) || (!is.null(names(x)) && all(nzchar(names(x)))))
  # modifyList() drops unnamed entries, so the input is checked as given.
  for (n in c("label_text", "level_text")) if (!is.null(input[[n]])) s[[n]] <- input[[n]]
  if (!named(s$label_text) || !all(vapply(s$label_text, is_text, logical(1))))
    stop("label_text must be a named list of single strings (column = label).", call. = FALSE)
  if (!named(s$level_text) || !all(vapply(s$level_text, function(levels) named(levels) && length(levels) > 0L &&
    all(vapply(levels, is_text, logical(1))), logical(1))))
    stop("level_text must be a named list of named lists of strings (column = list(category = label)).", call. = FALSE)
  s
}

# The label of each column a figure uses: the user's text, else the tidied name
# (or the name itself when labels = "names").
figure_label_values <- function(columns, style) {
  columns <- unique(columns)
  values <- if (identical(style$labels, "names")) columns else vapply(columns, tidy_label, character(1), USE.NAMES = FALSE)
  names(values) <- columns
  typed <- intersect(names(style$label_text), columns)
  values[typed] <- unlist(style$label_text[typed], use.names = FALSE)
  values
}

# `name = "text"` lines of an R vector literal.
named_text <- function(values) paste0(r_sym(names(values)), " = ", vapply(values, r_string, character(1)))

figure_labels_code <- function(labels, style) {
  keep <- if (identical(style$labels, "names")) names(labels)[labels != names(labels)] else names(labels)
  labels <- labels[keep]
  levels <- style$level_text
  c(
    "# Figure labels: the text readers see instead of the column names, in titles,",
    "# legends and statistics lines. Edit the text on the right; the column names on",
    "# the left must stay as they are. A column left out keeps its name.",
    if (length(labels)) c("figure_labels <- c(", paste0("  ", named_text(labels), c(rep(",", length(labels) - 1L), ""))) else NULL,
    if (length(labels)) ")" else "figure_labels <- c()",
    "# Category labels: for a column, the text shown for each of its categories, e.g.",
    "#   figure_level_labels <- list(condition = c(ctrl = \"Control\", tx = \"Treatment\"))",
    if (length(levels)) c("figure_level_labels <- list(",
      paste0("  ", r_sym(names(levels)), " = c(", vapply(levels, function(l) paste(named_text(unlist(l)), collapse = ", "), character(1)), ")",
        c(rep(",", length(levels) - 1L), "")), ")") else "figure_level_labels <- list()",
    "",
    "# Replace column names in one piece of figure text by their labels.",
    "figure_relabel_text <- function(text) {",
    "  if (!is.character(text) || length(text) != 1L || is.na(text) || !length(figure_labels)) return(text)",
    "  if (text %in% names(figure_labels)) return(unname(figure_labels[[text]]))",
    "  columns <- names(figure_labels)[order(-nchar(names(figure_labels)))]",
    "  escaped <- gsub(\"([][{}()+*^$|\\\\\\\\?.])\", \"\\\\\\\\\\\\1\", columns)",
    "  # A column named like a statistic symbol (p, t, F, d, ...) is replaced only where it",
    "  # names the column: before \":\", \"x\" or \" / \", or at the end of the text. Any other",
    "  # name is left alone where an operator, (, [ or a dash follows it (\"Age >= 18\").",
    "  # The names are tried as one unit, so \"Age group = 1\" never falls back to \"Age\".",
    "  symbols <- c(\"p\", \"t\", \"F\", \"d\", \"g\", \"n\", \"N\", \"r\", \"R\", \"z\", \"W\", \"U\", \"V\", \"H\", \"df\", \"b\", \"B\", \"SE\", \"CI\", \"M\", \"SD\", \"OR\", \"BF\")",
    "  marks <- intToUtf8(c(215L, 8804L, 8805L, 8800L, 8776L, 8211L), multiple = TRUE)",
    "  is_symbol <- columns %in% symbols",
    "  general <- paste(escaped[!is_symbol], collapse = \"|\")",
    "  symbolic <- paste(escaped[is_symbol], collapse = \"|\")",
    "  after_general <- paste0(\"(?![[:alnum:]_.])(?!\\\\s*[=<>~\", paste(marks[2:5], collapse = \"\"), \"]|[-(\\\\[\", marks[6], \"])\")",
    "  after_symbol <- paste0(\"(?![[:alnum:]_.])(?=\\\\s*(?::|\", marks[1], \"|$)|\\\\s+/\\\\s)\")",
    "  pattern <- paste0(\"(*UCP)(?<![[:alnum:]_.])(?:\",",
    "    if (nzchar(general)) paste0(\"(?>\", general, \")\", after_general) else \"(*FAIL)\",",
    "    if (nzchar(symbolic)) paste0(\"|(?>\", symbolic, \")\", after_symbol), \")\")",
    "  found <- gregexpr(pattern, text, perl = TRUE)",
    "  if (found[[1]][1] == -1L) return(text)",
    "  regmatches(text, found) <- list(unname(figure_labels[regmatches(text, found)[[1]]]))",
    "  text",
    "}",
    "",
    "# Put figure_labels and figure_level_labels into a figure. The analysis data and",
    "# results are unchanged; only the text drawn on the figure changes.",
    "figure_relabel <- function(plot) {",
    "  if (!inherits(plot, \"ggplot\")) return(plot)",
    "  # The category labels of one column; a combined column such as \"a / b\" (one",
    "  # panel per combination) maps each part with the labels of its own column.",
    "  relabel_values <- function(values, column) {",
    "    parts <- strsplit(column, \" / \", fixed = TRUE)[[1]]",
    "    relabel <- function(x) {",
    "      if (length(parts) == 1L) {",
    "        map <- figure_level_labels[[column]]",
    "        hit <- x %in% names(map)",
    "        x[hit] <- unname(map[x[hit]])",
    "        return(x)",
    "      }",
    "      pieces <- strsplit(x, \" / \", fixed = TRUE)",
    "      vapply(pieces, function(piece) {",
    "        if (length(piece) != length(parts)) return(paste(piece, collapse = \" / \"))",
    "        for (k in seq_along(parts)) {",
    "          map <- figure_level_labels[[parts[k]]]",
    "          if (!is.null(map) && piece[k] %in% names(map)) piece[k] <- unname(map[[piece[k]]])",
    "        }",
    "        paste(piece, collapse = \" / \")",
    "      }, character(1))",
    "    }",
    "    if (is.factor(values)) levels(values) <- relabel(levels(values))",
    "    else if (is.character(values)) values <- relabel(values)",
    "    values",
    "  }",
    "  relabelled <- function(data) {",
    "    if (!is.data.frame(data)) return(character())",
    "    Filter(function(column) column %in% names(figure_level_labels) ||",
    "      any(strsplit(column, \" / \", fixed = TRUE)[[1]] %in% names(figure_level_labels)), names(data))",
    "  }",
    "  relabel_data <- function(data) {",
    "    for (column in relabelled(data)) data[[column]] <- relabel_values(data[[column]], column)",
    "    data",
    "  }",
    "  if (length(figure_level_labels)) {",
    "    # Tick labels a figure fixed from a column's categories (e.g. a numeric axis",
    "    # labelled with levels()); changed only when exactly one column matches them.",
    "    plot$scales <- plot$scales$clone()",
    "    for (i in seq_along(plot$scales$scales)) {",
    "      scale <- plot$scales$scales[[i]]",
    "      # Colours given by category name (scale_fill_manual(values = c(a = ...))) follow",
    "      # their renamed category; changed only when exactly one column renames them.",
    "      colours <- if (is.function(scale$palette)) tryCatch(scale$palette(1L), error = function(e) NULL)",
    "      if (is.character(colours) && !is.null(names(colours))) {",
    "        renamed <- unique(Filter(function(names) !identical(names, names(colours)),",
    "          lapply(relabelled(plot$data), function(column) relabel_values(names(colours), column))))",
    "        if (length(renamed) == 1L) {",
    "          names(colours) <- renamed[[1]]",
    "          scale <- scale$clone()",
    "          scale$palette <- local({ values <- colours; function(n) values })",
    "          # (the scale also keeps only categories named in its colours)",
    "          if (is.function(scale$limits)) scale$limits <- local({",
    "            keep <- names(colours)",
    "            function(x) intersect(x, c(keep, NA))",
    "          })",
    "          plot$scales$scales[[i]] <- scale",
    "        }",
    "      }",
    "      if (!is.character(scale$labels)) next",
    "      mapped <- unique(Filter(Negate(is.null), lapply(relabelled(plot$data), function(column) {",
    "        values <- plot$data[[column]]",
    "        categories <- if (is.factor(values)) levels(values) else unique(as.character(values))",
    "        if (identical(scale$labels, categories)) relabel_values(categories, column)",
    "      })))",
    "      if (length(mapped) != 1L) next",
    "      scale <- scale$clone()",
    "      scale$labels <- mapped[[1]]",
    "      plot$scales$scales[[i]] <- scale",
    "    }",
    "    plot$data <- relabel_data(plot$data)",
    "    # Copy each layer before changing its data: layers are shared with the original figure.",
    "    plot$layers <- lapply(plot$layers, function(layer) {",
    "      if (!is.data.frame(layer$data)) return(layer)",
    "      # (a new name: ggproto() reads its parent lazily, so `layer <- ggproto(NULL, layer)` loops)",
    "      copy <- ggplot2::ggproto(NULL, layer)",
    "      copy$data <- relabel_data(layer$data)",
    "      copy",
    "    })",
    "  }",
    "  if (!length(figure_labels)) return(plot)",
    "  current <- tryCatch(ggplot2::get_labs(plot), error = function(e) plot$labels)",
    "  changed <- list()",
    "  for (aesthetic in names(current)) {",
    "    text <- figure_relabel_text(current[[aesthetic]])",
    "    if (!identical(text, current[[aesthetic]])) changed[[aesthetic]] <- text",
    "  }",
    "  if (length(changed)) plot <- plot + do.call(ggplot2::labs, changed)",
    "  # Legend titles set with guides(); a copy of the guide carries the new title.",
    "  for (aesthetic in names(plot$guides$guides)) {",
    "    guide <- plot$guides$guides[[aesthetic]]",
    "    if (!inherits(guide, \"Guide\")) next",
    "    text <- figure_relabel_text(guide$params$title)",
    "    if (identical(text, guide$params$title)) next",
    "    copy <- ggplot2::ggproto(NULL, guide)",
    "    copy$params$title <- text",
    "    plot <- plot + do.call(ggplot2::guides, stats::setNames(list(copy), aesthetic))",
    "  }",
    "  # Column names in the tick labels of a discrete axis (a correlation matrix, the",
    "  # terms of a coefficient plot). An axis's own labels function is kept and applied",
    "  # to the relabelled text.",
    "  relabel_ticks <- function(x) vapply(as.character(x), figure_relabel_text, character(1), USE.NAMES = FALSE)",
    "  built <- NULL",
    "  for (axis in c(\"x\", \"y\")) {",
    "    scale <- plot$scales$get_scales(axis)",
    "    if (is.null(scale)) {",
    "      if (is.null(built)) built <- tryCatch(ggplot2::ggplot_build(plot)$layout, error = function(e) FALSE)",
    "      if (isFALSE(built)) break",
    "      trained <- built[[paste0(\"panel_scales_\", axis)]][[1]]",
    "      if (is.null(trained) || !trained$is_discrete()) next",
    "      plot <- plot + (if (axis == \"x\") ggplot2::scale_x_discrete else ggplot2::scale_y_discrete)(labels = relabel_ticks)",
    "      next",
    "    }",
    "    if (!scale$is_discrete()) next",
    "    plot$scales <- plot$scales$clone() # (shared with the original figure)",
    "    labels <- scale$labels",
    "    scale <- scale$clone()",
    "    scale$labels <- if (is.function(labels)) function(x) labels(relabel_ticks(x)) else",
    "      if (is.character(labels)) relabel_ticks(labels) else if (is.null(labels)) NULL else relabel_ticks",
    "    plot$scales$scales[[which(vapply(plot$scales$scales, function(s) axis %in% s$aesthetics, logical(1)))[1]]] <- scale",
    "  }",
    "  plot",
    "}"
  )
}
