# Structural readers deliberately do not evaluate user expressions.
literal <- function(x) {
  if (is.null(x) || is.atomic(x)) return(x)
  # T and F, as commonly written for TRUE and FALSE
  if (is.symbol(x) && as.character(x) %in% c("T", "F")) return(identical(as.character(x), "T"))
  if (is.call(x) && is.symbol(x[[1]]) && as.character(x[[1]]) %in% c("c", "list")) {
    values <- lapply(as.list(x)[-1], literal)
    if (identical(x[[1]], as.name("c"))) return(unlist(values, recursive = FALSE))
    return(values)
  }
  if (is.call(x) && identical(x[[1]], as.name("-")) && length(x) == 2 && is.numeric(x[[2]])) return(-x[[2]])
  stop("Dynamic argument requires an explicit literal or stable data binding: ", r_text(x), call. = FALSE)
}

call_identity <- function(x) {
  if (!is.call(x)) return(NULL)
  fn <- x[[1]]
  if (is.symbol(fn)) return(list(package = NULL, name = as.character(fn)))
  if (is.call(fn) && identical(fn[[1]], as.name("::")))
    return(list(package = as.character(fn[[2]]), name = as.character(fn[[3]])))
  NULL
}

supported_signatures <- function() list(
  ANOVA = c("data", "dep", "factors"), ancova = c("data", "dep", "factors", "covs"),
  anovaRM = c("data", "rm", "rmCells"), ttestIS = c("data", "vars", "group"),
  ttestPS = c("data", "pairs"), ttestOneS = c("data", "vars"),
  propTest2 = c("data", "vars"), propTestN = c("data", "var"),
  contTables = c("data", "rows", "cols"), contTablesPaired = c("data", "rows", "cols"),
  corrMatrix = c("data", "vars"), corrPart = c("data", "vars", "controls"),
  descriptives = c("data", "vars"), logRegBin = c("data", "dep", "covs", "factors"),
  ggbetweenstats = c("data", "x", "y"), ggwithinstats = c("data", "x", "y"),
  ggscatterstats = c("data", "x", "y"), gghistostats = c("data", "x"),
  ggbarstats = c("data", "x", "y"), ggpiestats = c("data", "x", "y"),
  ggcorrmat = c("data"), ggcoefstats = c("x"),
  anovaOneW = c("data", "deps", "group"), anovaNP = c("data", "deps", "group"),
  linReg = c("data", "dep", "covs", "factors"), reliability = c("data", "vars"),
  grouped_ggbetweenstats = c("data", "x", "y"), grouped_ggwithinstats = c("data", "x", "y"),
  grouped_ggscatterstats = c("data", "x", "y"), grouped_gghistostats = c("data", "x"),
  grouped_ggbarstats = c("data", "x", "y"), grouped_ggpiestats = c("data", "x", "y"),
  grouped_ggcorrmat = c("data")
)

analysis_target <- function(expr) {
  binding <- NULL
  if (is.call(expr) && is.symbol(expr[[1]]) && as.character(expr[[1]]) %in% c("<-", "=")) {
    if (!is.symbol(expr[[2]])) return(NULL)
    binding <- as.character(expr[[2]])
    expr <- expr[[3]]
  }
  id <- call_identity(expr)
  if (is.null(id)) return(NULL)
  registry <- supported_signatures()
  if (!is.null(id$package) && !id$package %in% c("jmv", "ggstatsplot", "BetterGG")) return(NULL)
  if (is.null(id$package) && !id$name %in% names(registry)) return(NULL)
  list(call = expr, identity = id, binding = binding, supported = id$name %in% names(registry))
}

inspect_code <- function(code, prefix = "a", offset = 0L) {
  exprs <- tryCatch(parse(text = code, keep.source = TRUE), error = identity)
  if (inherits(exprs, "error")) return(list(error = conditionMessage(exprs)))
  if (any(startsWith(all.names(exprs), ".jmv2gg_"))) return(list(error = "Source uses reserved .jmv2gg_ names. Rename them before conversion."))
  refs <- attr(exprs, "srcref")
  analyses <- list(); diagnostics <- list()
  defined <- character()
  for (i in seq_along(exprs)) {
    ex <- exprs[[i]]
    if (is.call(ex) && is.symbol(ex[[1]]) && as.character(ex[[1]]) %in% c("<-", "=") && is.symbol(ex[[2]]) &&
        is.call(ex[[3]]) && identical(ex[[3]][[1]], as.name("function"))) defined <- c(defined, as.character(ex[[2]]))
    target <- analysis_target(ex)
    line <- if (length(refs) >= i) as.integer(refs[[i]][1]) else 1L
    if (is.null(target)) {
      if (grepl("(jmv|ggstatsplot|BetterGG)::", r_text(ex))) diagnostics <- c(diagnostics,
        list(diag_record("warning", "nested_analysis", "Analysis inside an unsupported expression was preserved without transformation.", line = line)))
      next
    }
    identity <- target$identity
    if (is.null(identity$package) && identity$name %in% defined) {
      diagnostics <- c(diagnostics, list(diag_record("warning", "shadowed_function", "A user-defined function shadows an analysis name; it was not converted.", line = line)))
      next
    }
    id <- paste0(prefix, sprintf("%04d", offset + length(analyses) + 1L))
    args <- as.list(target$call)[-1]
    # jamovi's syntax mode writes a trailing comma (`..., )`): an empty argument.
    empty <- vapply(args, function(x) identical(x, quote(expr = )), logical(1))
    args <- args[!empty]
    nm <- names(args) %||% rep("", length(args))
    signature <- supported_signatures()[[identity$name]] %||% character()
    for (j in seq_along(args)) if (!nzchar(nm[j])) {
      candidates <- setdiff(signature, nm)
      if (!length(candidates)) { nm[j] <- paste0("..", j); next }
      nm[j] <- candidates[1]
    }
    names(args) <- nm
    if (anyDuplicated(nm)) target$supported <- FALSE
    if (is.null(identity$package)) diagnostics <- c(diagnostics, list(diag_record("warning", "inferred_namespace",
      paste("Recognized unqualified function", identity$name, "by its registered signature."), id, line)))
    end_line <- if(length(refs) >= i) as.integer(refs[[i]][3]) else line
    shares_line <- any(vapply(seq_along(refs),function(j) j != i && as.integer(refs[[j]][1]) <= end_line && as.integer(refs[[j]][3]) >= line,logical(1)))
    if(shares_line) {
      target$supported <- FALSE
      diagnostics <- c(diagnostics,list(diag_record("warning","same_line_statements","Put each analysis on separate source lines so its input can be captured before subsequent changes.",id,line)))
    }
    analyses[[length(analyses) + 1L]] <- list(id = id, line = line, end_line = end_line,
      expression_index = i, function_name = identity$name,
      package = identity$package %||% if (grepl("^(grouped_)?gg", identity$name)) "ggstatsplot" else "jmv",
      original = r_text(target$call), binding = target$binding, args = args,
      status = if (target$supported) "pending" else "unsupported")
  }
  list(analyses = analyses, diagnostics = diagnostics, expressions = exprs)
}

arg_value <- function(a, name, default = NULL) {
  if (!name %in% names(a$args)) return(default)
  literal(a$args[[name]])
}
arg_variable <- function(a, name, default = NULL) {
  x <- a$args[[name]]
  if (is.null(x)) return(default)
  if (is.symbol(x)) return(as.character(x))
  if(is.call(x) && identical(x[[1]],as.name("vars"))) {
    values <- as.list(x)[-1]
    ok <- vapply(values, function(v) is.symbol(v) || (is.character(v) && length(v) == 1L), logical(1))
    if(!all(ok)) stop("vars() must contain only column names.")
    return(vapply(values,as.character,character(1)))
  }
  val <- literal(x)
  if (!is.character(val)) stop("Expected variable names in ", name, ".")
  val
}

model_terms <- function(terms, fallback) {
  if (is.null(terms)) return(paste(r_sym(fallback), collapse = " + "))
  if (!is.list(terms)) stop("Model terms must be a literal list.")
  terms <- Filter(function(x) length(x) > 0, terms)
  if (!length(terms)) stop("The source model contains no model terms.")
  paste(vapply(terms, function(x) paste(r_sym(as.character(x)), collapse = ":"), character(1)), collapse = " + ")
}
