# Private-tier corpus validation: run locally only; results stay outside the
# repository. Reads a list of R Markdown files, converts each (no execution),
# and optionally renders a subset natively from a temporary copy of its
# folder. Writes aggregate counts plus per-file records to the output folder.
#
# Environment:
#   JMV2GG_CORPUS_LIST     text file, one .Rmd path per line (required)
#   JMV2GG_CORPUS_OUTPUT   output folder outside the repository (required)
#   JMV2GG_CORPUS_RENDER   optional text file of paths to render natively
#   JMV2GG_RENDER_SECONDS  per-document time limit (default 900)

list_file <- Sys.getenv("JMV2GG_CORPUS_LIST")
output <- Sys.getenv("JMV2GG_CORPUS_OUTPUT")
if (!nzchar(list_file) || !nzchar(output)) stop("Set JMV2GG_CORPUS_LIST and JMV2GG_CORPUS_OUTPUT.")
if (startsWith(normalizePath(output, winslash = "/", mustWork = FALSE), normalizePath(getwd(), winslash = "/"))) {
  stop("The output folder must be outside the repository.")
}
dir.create(output, recursive = TRUE, showWarnings = FALSE)
library(jmv2gg)

read_text <- function(path) {
  lines <- tryCatch(readLines(path, warn = FALSE, encoding = "UTF-8"), error = function(e) NULL)
  if (is.null(lines)) return(NULL)
  text <- paste(lines, collapse = "\n")
  if (!validUTF8(text)) text <- iconv(text, "latin1", "UTF-8")
  text
}

# Version chains (report-v3.Rmd, report_v12.Rmd, report (1).Rmd): keep the
# most recently modified file of each chain in each folder.
chain_key <- function(path) {
  base <- tolower(tools::file_path_sans_ext(basename(path)))
  base <- gsub("[ _-]*(v|ver|version)[ _-]?[0-9]+([._][0-9]+)*$", "", base)
  base <- gsub("[ _-]*\\([0-9]+\\)$", "", base)
  base <- gsub("[ _-]*(final|copy|old|new|draft)$", "", base)
  paste(dirname(path), base, sep = "|")
}

paths <- unique(trimws(readLines(list_file, warn = FALSE)))
paths <- paths[nzchar(paths) & file.exists(paths)]
info <- data.frame(path = paths, key = vapply(paths, chain_key, ""), mtime = file.mtime(paths), stringsAsFactors = FALSE)
info <- info[order(info$key, -as.numeric(info$mtime)), ]
latest <- info[!duplicated(info$key), "path"]

records <- lapply(seq_along(latest), function(i) {
  path <- latest[i]
  text <- read_text(path)
  if (is.null(text)) return(list(path = path, status = "unreadable"))
  started <- Sys.time()
  out <- tryCatch(convert_rmd(text, engine = "both"), error = function(e) e)
  if (inherits(out, "error")) return(list(path = path, status = "converter_error", error = conditionMessage(out)))
  list(path = path, status = out$status, detected = out$manifest$detected, converted = out$manifest$converted,
    figures = length(out$manifest$plots), seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
    functions = vapply(out$analyses, function(a) a$function_name, ""),
    unconverted = vapply(Filter(function(a) !identical(a$status, "converted"), out$analyses), function(a) a$function_name, ""),
    codes = vapply(out$diagnostics, function(d) d$code, ""),
    messages = unique(vapply(Filter(function(d) d$code == "unsupported_analysis", out$diagnostics), function(d) d$message, "")))
})

tab <- function(x) { x <- unlist(x); if (!length(x)) return(list()); as.list(sort(table(x), decreasing = TRUE)) }
summary <- list(
  files_listed = length(paths), files_after_dedup = length(latest),
  status = tab(lapply(records, `[[`, "status")),
  analyses_detected = sum(unlist(lapply(records, `[[`, "detected")), na.rm = TRUE),
  analyses_converted = sum(unlist(lapply(records, `[[`, "converted")), na.rm = TRUE),
  figures = sum(unlist(lapply(records, `[[`, "figures")), na.rm = TRUE),
  functions = tab(lapply(records, `[[`, "functions")),
  unconverted_functions = tab(lapply(records, `[[`, "unconverted")),
  diagnostic_codes = tab(lapply(records, `[[`, "codes")),
  unsupported_reasons = tab(lapply(records, `[[`, "messages")),
  max_seconds = max(unlist(lapply(records, `[[`, "seconds")), na.rm = TRUE)
)

# Native rendering of a subset, each from a temporary copy of its folder.
render_list <- Sys.getenv("JMV2GG_CORPUS_RENDER")
renders <- list()
if (nzchar(render_list)) {
  limit <- as.numeric(Sys.getenv("JMV2GG_RENDER_SECONDS", "900"))
  targets <- trimws(readLines(render_list, warn = FALSE))
  targets <- targets[nzchar(targets) & file.exists(targets)]
  for (path in targets) {
    text <- read_text(path)
    record <- list(path = path)
    if (grepl("[\"'][A-Za-z]:[/\\\\]|[\"']~/|[\"']/(Users|home)/", text)) {
      renders[[length(renders) + 1L]] <- c(record, status = "skipped_absolute_paths")
      next
    }
    folder <- dirname(path)
    size <- sum(file.info(list.files(folder, recursive = TRUE, full.names = TRUE))$size, na.rm = TRUE)
    if (size > 300 * 1024^2) {
      renders[[length(renders) + 1L]] <- c(record, status = "skipped_folder_too_large")
      next
    }
    work <- file.path(tempdir(), paste0("corpus-", length(renders) + 1L))
    dir.create(work)
    file.copy(list.files(folder, full.names = TRUE, all.files = FALSE, no.. = TRUE), work, recursive = TRUE)
    converted <- convert_rmd(text, engine = "both")
    target <- file.path(work, paste0(tools::file_path_sans_ext(basename(path)), "-jmv2gg.Rmd"))
    writeLines(converted$text, target, useBytes = TRUE)
    started <- Sys.time()
    result <- tryCatch(callr::r(function(input) {
      warnings <- character()
      withCallingHandlers(
        rmarkdown::render(input, output_format = "html_document", quiet = TRUE, envir = new.env(parent = globalenv())),
        warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
      )
      warnings
    }, args = list(input = target), libpath = .libPaths(), timeout = limit), error = function(e) e)
    figures <- list.files(file.path(work, "figures"), pattern = "\\.png$")
    renders[[length(renders) + 1L]] <- c(record, list(
      status = if (inherits(result, "error")) "render_failed" else "rendered",
      error = if (inherits(result, "error")) conditionMessage(result) else NULL,
      not_drawn = if (inherits(result, "error")) NA else sum(grepl("jmv2gg: figure", result)),
      not_drawn_messages = if (inherits(result, "error")) NULL else unique(grep("jmv2gg: figure", result, value = TRUE)),
      planned_figures = length(converted$manifest$plots), figure_files = length(figures),
      seconds = as.numeric(difftime(Sys.time(), started, units = "secs")), work = work))
  }
  summary$render <- list(
    attempted = length(renders), status = tab(lapply(renders, `[[`, "status")),
    planned_figures = sum(unlist(lapply(renders, `[[`, "planned_figures")), na.rm = TRUE),
    figure_files = sum(unlist(lapply(renders, `[[`, "figure_files")), na.rm = TRUE),
    figures_not_drawn = sum(unlist(lapply(renders, `[[`, "not_drawn")), na.rm = TRUE)
  )
}

jsonlite::write_json(summary, file.path(output, "summary.json"), auto_unbox = TRUE, pretty = TRUE)
jsonlite::write_json(records, file.path(output, "records.json"), auto_unbox = TRUE, pretty = TRUE)
if (length(renders)) jsonlite::write_json(renders, file.path(output, "renders.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Converted", length(latest), "files; status:", paste(names(summary$status), unlist(summary$status), collapse = ", "), "\n")
