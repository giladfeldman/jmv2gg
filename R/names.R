# Readable object names for the generated code: anova_1, ttest_2, ... The
# generated objects are <name>_input, <name>_data, <name>_plot and so on.
analysis_kind <- function(fn) {
  switch(fn,
    ANOVA = , ancova = , anovaOneW = , anovaNP = "anova",
    anovaRM = "rm_anova",
    ttestIS = , ttestPS = , ttestOneS = "ttest",
    corrMatrix = , corrPart = "correlation",
    descriptives = "descriptives",
    contTables = , contTablesPaired = , propTest2 = , propTestN = "table",
    logRegBin = "logistic",
    linReg = "regression",
    reliability = "reliability",
    sub("^grouped_", "grouped_", sub("^gg", "", fn))
  )
}

# Give each record a name that cannot clash with an object in the source:
# when any source symbol is the name itself or starts with "<name>_", the
# name gets a "jmv2gg_" prefix (and a number suffix if that still clashes).
assign_analysis_names <- function(records, symbols, counts = list()) {
  symbols <- unique(as.character(symbols))
  clashes <- function(name) any(symbols == name | startsWith(symbols, paste0(name, "_")))
  for (i in seq_along(records)) {
    kind <- analysis_kind(records[[i]]$function_name)
    counts[[kind]] <- (counts[[kind]] %||% 0L) + 1L
    name <- paste0(kind, "_", counts[[kind]])
    if (clashes(name)) name <- paste0("jmv2gg_", name)
    extra <- 1L
    base <- name
    while (clashes(name)) {
      extra <- extra + 1L
      name <- paste0(base, "_v", extra)
    }
    records[[i]]$name <- name
  }
  attr(records, "counts") <- counts
  records
}

analysis_name <- function(a) a$name %||% paste0("analysis_", sub("^[a-z]0*", "", a$id))
