#' JSON transport for the browser workbench
#' @param request_json A JSON request with action, mode, source and options.
#' @return A JSON conversion/preview result. Input source is never executed.
#' @export
browser_request <- function(request_json) {
  request <- jsonlite::fromJSON(request_json,simplifyVector=FALSE)
  source <- request$source %||% ""
  if(identical(request$action,"scan")) {
    # The risk scan before an in-browser render; nothing is executed.
    scan <- scan_rmd_risks(source)
    scan$packages <- rmd_packages(source)
    return(jsonlite::toJSON(scan,auto_unbox=TRUE,null="null"))
  }
  engine <- request$engine %||% "both"
  options <- list(style=request$style %||% list(),figures=request$figures %||% list())
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
    env <- new.env(parent=baseenv())
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

simulate_for_analysis <- function(a,n) {
  if(!is.numeric(n) || length(n)!=1L || !is.finite(n) || n<10 || n>5000) stop("Simulation size must be 10-5000.")
  n <- as.integer(n)
  factors <- unique(c(arg_variable(a,"factors",character()),arg_variable(a,"group",character()),
    arg_variable(a,"rows",character()),arg_variable(a,"cols",character())))
  factors <- unique(c(factors, arg_variable(a,"group",character())))
  numeric <- unique(c(arg_variable(a,"dep",character()),arg_variable(a,"deps",character()),arg_variable(a,"vars",character()),arg_variable(a,"covs",character()),
    arg_variable(a,"x",character()),arg_variable(a,"y",character())))
  if(!is.null(a$args$formula)) {
    validate_formula_syntax(a$args$formula)
    numeric <- unique(c(numeric,all.vars(a$args$formula[[2]])))
    factors <- unique(c(factors,all.vars(a$args$formula[[3]])))
  }
  numeric <- setdiff(numeric,factors)
  if(!length(c(factors,numeric))) stop("The source does not provide variables for simulation.")
  had_seed <- exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE)
  if(had_seed) old_seed <- get(".Random.seed",envir=.GlobalEnv)
  on.exit(if(had_seed)assign(".Random.seed",old_seed,envir=.GlobalEnv) else if(exists(".Random.seed",envir=.GlobalEnv,inherits=FALSE))rm(".Random.seed",envir=.GlobalEnv))
  set.seed(1123)
  data <- data.frame(row.names=seq_len(n))
  for(v in factors) data[[v]] <- factor(rep(c("Group A","Group B"),length.out=n))
  for(v in numeric) data[[v]] <- stats::rnorm(n)
  if(identical(a$function_name,"logRegBin")) {
    data[[arg_variable(a,"dep")]] <- factor(rep(c("0","1"),length.out=n))
    for(ref in arg_value(a,"refLevels",list())) data[[ref$var]] <- factor(rep(c(ref$ref,"Other"),length.out=n))
  }
  data
}
