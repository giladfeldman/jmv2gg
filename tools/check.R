args <- commandArgs(trailingOnly=TRUE)
if (length(args)) setwd(args[1])
Sys.setenv(NOT_CRAN = "true") # run the code snapshots
for (file in list.files("R",full.names=TRUE)) source(file)
results <- as.data.frame(testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = FALSE))
cat("Checks:", sum(results$nb), "failures:", sum(results$failed), "errors:", sum(results$error),
  "skips:", sum(results$skipped), "\n")
# The 0.2.0 floor: never lower it to make a run pass.
if (sum(results$nb) < 470L || any(results$failed > 0) || any(results$error)) {
  stop("jmv2gg validation failed; do not lower the test floor.")
}
