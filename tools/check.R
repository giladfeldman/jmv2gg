args <- commandArgs(trailingOnly=TRUE)
if (length(args)) setwd(args[1])
for (file in list.files("R",full.names=TRUE)) source(file)
testthat::test_dir("tests/testthat",stop_on_failure=TRUE)
