#' JSON transport for the browser workbench
#' @param request_json A JSON request with action, mode, source and options.
#' @return A JSON conversion/preview result. Input source is never executed.
#' @export
browser_request <- function(request_json) {
  request <- jsonlite::fromJSON(request_json,simplifyVector=FALSE)
  source <- request$source %||% ""
  if (isTRUE(request$progress)) {
    old <- options(jmv2gg.progress = TRUE)
    on.exit(options(old), add = TRUE)
  }
  if(identical(request$action,"scan")) {
    # The risk scan before an in-browser render; nothing is executed.
    scan <- scan_rmd_risks(source)
    scan$packages <- rmd_packages(source)
    return(jsonlite::toJSON(scan,auto_unbox=TRUE,null="null"))
  }
  engine <- request$engine %||% "both"
  options <- list(style=request$style %||% list(),figures=request$figures %||% list())
  # A preview draws figures and shows no code, so the code is not tidied (and has no styler note).
  if(identical(request$action,"preview")) options$style$styler <- FALSE
  result <- if(identical(request$mode,"rmd")) convert_rmd(source,engine,
    original_output=request$original_output %||% "include",html_preset=request$html_preset %||% "enhanced",
    style=options$style,figures=options$figures) else convert_code(source,engine,style=options$style,figures=options$figures)
  if(identical(request$action,"preview")) {
    candidates <- Filter(function(a) identical(a$status,"converted"),result$analyses)
    index <- which(vapply(candidates,function(a)identical(a$id,request$analysis_id),logical(1)))
    if(length(index)!=1L) stop("Select one converted analysis to preview.")
    a <- candidates[[index]]
    if(identical(request$data_kind,"simulate")) data <- simulate_for_analysis(a,request$n %||% 100L)
    else {
      path <- request$data_path
      if(!is.character(path) || length(path)!=1L || !path %in% c("/workspace/input.csv","/workspace/input.sav")) stop("Select a local CSV or SAV file.")
      data <- if(endsWith(path,".sav")) {
        if(!requireNamespace("haven",quietly=TRUE)) stop("The SAV reader is unavailable in this runtime.")
        haven::read_sav(path)
      } else utils::read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
    }
    if(!is.data.frame(data) || !nrow(data)) stop("The selected dataset has no rows.")
    overrides <- request$categorical %||% list()
    for(v in unlist(overrides,use.names=FALSE)) {
      if(!v %in% names(data)) stop("Categorical override names a missing variable: ",v)
      data[[v]] <- factor(data[[v]])
    }
    preview_options <- conversion_options(options$style,options$figures)
    preview_options$figures$formats <- "png"
    generated <- generate_analysis(a,"ggplot2",preview_options)
    # The standard attached packages (stats, utils, ...) are visible, as in a report: models
    # look up functions such as family() and na.pass in their formula's environment.
    env <- new.env(parent=as.environment("package:stats"))
    assign(as.character(a$args$data),data,envir=env)
    # Only jmv2gg-generated and structurally validated code executes here:
    # the figure setup and this analysis's figure block.
    # Generated blocks report an undrawn figure as a warning so reports keep knitting;
    # a preview has nothing to show in that case, so it fails with the same message.
    code <- c(figure_setup_code(preview_options, generated$packages), generated$code)
    withCallingHandlers(eval(parse(text=code),envir=env),warning=function(w)
      if(startsWith(conditionMessage(w),"jmv2gg: figure")) stop(conditionMessage(w),call.=FALSE))
    return(jsonlite::toJSON(list(kind="preview",simulated=identical(request$data_kind,"simulate"),
      files=lapply(generated$plots,function(p)list(path=p$filename,id=p$id))),auto_unbox=TRUE,null="null"))
  }
  # ASTs stay inside R. The browser receives a stable plain-data contract.
  result$analyses <- lapply(result$analyses,function(a) a[c("id","line","function_name","package","binding","status","mapping","chunk","heading")])
  class(result) <- "list"
  jsonlite::toJSON(result,auto_unbox=TRUE,null="null",digits=16)
}

# The role of each column the analysis names: a grouping factor, a numeric score, a
# repeated measure (one column per condition, in `measures`) or a count.
simulation_roles <- function(a) {
  fn <- sub("^grouped_", "", a$function_name)
  v <- function(name) arg_variable(a, name, character())
  factors <- c(v("factors"), v("group"), v("rows"), v("cols"), v("layers"), v("splitBy"), v("bs"), v("grouping.var"))
  numeric <- c(v("dep"), v("deps"), v("covs"), v("cov"), v("controls"), v("cor.vars"))
  measures <- character()
  if (fn %in% c("propTest2", "propTestN")) factors <- c(factors, v("vars"), v("var")) else numeric <- c(numeric, v("vars"))
  if (fn %in% c("ggscatterstats", "gghistostats")) numeric <- c(numeric, v("x"), v("y"))
  else if (fn %in% c("ggbarstats", "ggpiestats")) factors <- c(factors, v("x"), v("y"))
  else if (fn %in% c("ggbetweenstats", "ggwithinstats")) { factors <- c(factors, v("x")); numeric <- c(numeric, v("y")) }
  if (fn == "anovaRM") measures <- vapply(arg_value(a, "rmCells", list()), function(x) as.character(x$measure), character(1))
  if (fn == "ttestPS") measures <- unlist(lapply(arg_value(a, "pairs", list()), function(p)
    as.character(c(p$i1 %||% p[[1]], p$i2 %||% p[[2]]))))
  counts <- v("counts")
  if (!is.null(a$args$formula)) {
    validate_formula_syntax(a$args$formula)
    f <- a$args$formula
    lhs <- if (length(f) == 3L) all.vars(f[[2]]) else character()
    if (fn %in% c("contTables", "contTablesPaired", "propTest2", "propTestN")) counts <- c(counts, lhs)
    else numeric <- c(numeric, lhs)
    factors <- c(factors, all.vars(f[[length(f)]]))
  }
  if (fn == "logRegBin") factors <- setdiff(factors, v("dep"))
  factors <- unique(factors)
  measures <- unique(measures)
  counts <- setdiff(unique(counts), c(factors, measures))
  numeric <- setdiff(unique(numeric), c(factors, measures, counts))
  list(fn = fn, factors = factors, numeric = numeric, measures = measures, counts = counts)
}

# Simulated data for a figure preview, labelled as simulated in the app. Factors are fully
# crossed, so every cell of the design is observed (all-identical factor columns made
# every term of a factorial ANOVA inestimable: F(0, df) = NA); a quarter of each later
# factor's rows are then reassigned at random, so no association is exactly zero. Scores
# share a common component, so correlations, reliability and paired differences are
# neither zero nor perfect.
simulate_for_analysis <- function(a,n) {
  if(!is.numeric(n) || length(n)!=1L || !is.finite(n) || n<10 || n>5000) stop("Simulation size must be 10-5000.")
  n <- as.integer(n)
  roles <- simulation_roles(a)
  if(!length(c(roles$factors, roles$numeric, roles$measures, roles$counts)))
    stop("The source does not name the columns this analysis uses, so they cannot be simulated.")
  had_seed <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if(had_seed) old_seed <- get(".Random.seed",envir=.GlobalEnv)
  on.exit(if(had_seed)assign(".Random.seed",old_seed,envir=.GlobalEnv) else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv))
  set.seed(1123)
  data <- data.frame(row.names=seq_len(n))
  refs <- arg_value(a, "refLevels", list())
  ref_of <- function(column) {
    for (ref in refs) if (identical(as.character(ref$var), column)) return(as.character(ref$ref))
    NULL
  }
  # Two levels, the source's reference level (if it names one) first.
  two_levels <- function(column, default) {
    first <- ref_of(column) %||% default[1]
    c(first, setdiff(default, first)[1])
  }
  # Within-subject conditions (ggwithinstats pairs rows by their order in each condition) stay balanced.
  keep_balanced <- roles$fn == "ggwithinstats"
  period <- 1L
  for (i in seq_along(roles$factors)) {
    column <- roles$factors[i]
    levels <- two_levels(column, c("Group A", "Group B"))
    values <- rep(rep(levels, each = period), length.out = n)
    if (i > 1L && !keep_balanced) {
      moved <- sample.int(n, n %/% 4L)
      values[moved] <- sample(levels, length(moved), replace = TRUE)
    }
    data[[column]] <- factor(values, levels = levels)
    period <- period * length(levels)
  }
  common <- stats::rnorm(n)
  for (column in roles$numeric) data[[column]] <- 0.5 * common + sqrt(0.75) * stats::rnorm(n)
  for (i in seq_along(roles$measures))
    data[[roles$measures[i]]] <- 0.7 * common + sqrt(0.51) * stats::rnorm(n) + 0.2 * (i - 1)
  for (column in roles$counts) data[[column]] <- sample.int(20L, n, replace = TRUE)
  if (roles$fn == "logRegBin") {
    dep <- arg_variable(a, "dep")
    outcome <- stats::rbinom(n, 1L, stats::plogis(0.8 * common))
    outcome[1:2] <- c(0L, 1L)
    levels <- two_levels(dep, c("0", "1"))
    data[[dep]] <- factor(levels[outcome + 1L], levels = levels)
  }
  data
}

# One progress line for the browser, "jmv2gg-progress <done> <total> <label>", written
# with message() as item <done> starts; only when browser_request() was asked for progress.
report_progress <- function(done, total, label) {
  if (isTRUE(getOption("jmv2gg.progress"))) message("jmv2gg-progress ", done, " ", total, " ", label)
  invisible(NULL)
}
