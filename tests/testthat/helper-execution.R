# Convert one analysis, then run the figure setup and its figure block on
# `data` in a temporary folder. Returns the environment with every object the
# generated code created (and `.work`, the folder with the saved figures).
run_generated <- function(code, data, engine = "ggplot2", style = list(),
                          figures = list(dpi = 72, width = 3, height = 2)) {
  a <- assign_analysis_names(inspect_code(code)$analyses, character())[[1]]
  options <- conversion_options(style, figures)
  generated <- generate_analysis(a, engine, options)
  env <- new.env(parent = globalenv())
  assign(as.character(a$args$data), data, envir = env)
  work <- tempfile(); dir.create(work); old <- setwd(work); on.exit(setwd(old))
  eval(parse(text = c(figure_setup_code(options, generated$packages, generated$labels), generated$code)), envir = env)
  env$.work <- work
  env
}

# The generated code (setup + block) of one analysis, as one string.
generated_code <- function(code, engine = "ggplot2", style = list(),
                           figures = list(dpi = 72, width = 3, height = 2)) {
  a <- assign_analysis_names(inspect_code(code)$analyses, character())[[1]]
  options <- conversion_options(style, figures)
  generated <- generate_analysis(a, engine, options)
  paste(c(figure_setup_code(options, generated$packages, generated$labels), generated$code), collapse = "\n")
}
