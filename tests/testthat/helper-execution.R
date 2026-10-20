run_generated <- function(code,data) {
  a <- inspect_code(code)$analyses[[1]]
  generated <- generate_analysis(a,"ggplot2",conversion_options(list(),list(dpi=72,width=3,height=2)))
  env <- new.env(parent=globalenv()); assign(as.character(a$args$data),data,envir=env)
  work <- tempfile();dir.create(work);old<-setwd(work);on.exit(setwd(old))
  eval(parse(text=generated$code),envir=env)
  env
}
