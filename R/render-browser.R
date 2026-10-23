# Rendering an R Markdown document inside the browser (WebR), safely.
#
# Layers (each tested): the document runs only in a fresh WebR worker on the
# user's own files; the page's fixed-origin Content Security Policy refuses
# outside requests; this scan lists risky constructs before anything runs
# (non-R engines are refused); the HTML is shown in a sandboxed frame with no
# scripts; the browser enforces a time limit. The table of contents and code
# folding are plain HTML (<details>), so no script is needed.

# Patterns of constructs the user must see before rendering. `refuse = TRUE`
# means rendering is not offered at all. `where` says which lines are
# searched: chunk headers, R code (chunks and inline `r ...`), or the YAML.
rmd_risk_rules <- function() list(
  list(code = "other_engine", refuse = TRUE, where = "header", pattern = "\\{[ \t]*(?![rR][ ,}])[A-Za-z0-9_]+",
    message = "Chunks in other languages (JavaScript, Python, shell, ...) are not run in the browser."),
  list(code = "child_document", refuse = TRUE, where = "header", pattern = "\\bchild[ \t]*=",
    message = "Child documents (child=) are not run in the browser."),
  list(code = "child_document", refuse = TRUE, where = "code", pattern = "knit_child|knitr::knit\\(|rmarkdown::render",
    message = "Code that knits other documents is not run in the browser."),
  list(code = "javascript_from_r", refuse = TRUE, where = "code", pattern = "eval_js|webr::|\\.Call\\(|\\.External\\(",
    message = "Code that reaches the browser page or WebR internals (eval_js, webr::, .Call) is not run."),
  list(code = "asis_output", refuse = FALSE, where = "header", pattern = "results[ \t]*=[ \t]*['\"]asis['\"]",
    message = "Raw HTML output (results='asis'); it is shown without scripts."),
  list(code = "asis_output", refuse = FALSE, where = "code", pattern = "asis_output\\(|htmltools::|\\bHTML\\(",
    message = "Raw HTML output; it is shown without scripts."),
  list(code = "html_widget", refuse = FALSE, where = "code", pattern = "htmlwidgets|plotly|leaflet|DT::|datatable\\(|visNetwork|dygraphs",
    message = "Interactive HTML widgets; they are shown without their scripts and may appear empty."),
  list(code = "yaml_expression", refuse = FALSE, where = "yaml", pattern = "!r[ \t]|!expr[ \t]",
    message = "YAML parameters computed by R code (!r / !expr)."),
  list(code = "source_or_download", refuse = FALSE, where = "code",
    pattern = "\\bsource\\(|download\\.file|\\burl\\(|https?://|\\bcurl::|\\bhttr2?::|\\bsocketConnection|\\bgzcon\\(",
    message = "Code that reads other files or the internet (source(), downloads, URLs); outside requests are blocked."),
  list(code = "system_call", refuse = FALSE, where = "code", pattern = "\\bsystem2?\\(|\\bshell\\(|Sys\\.setenv|\\bsetwd\\(|\\bunlink\\(|file\\.remove",
    message = "System commands or file changes; they stay inside the browser's temporary files."),
  list(code = "knitr_hooks", refuse = FALSE, where = "code", pattern = "knit_hooks|opts_knit|knit_engines|render_markdown",
    message = "Changes to knitr's own behaviour.")
)

#' Scan an R Markdown document for constructs to review before rendering
#'
#' A deterministic, line-by-line scan; nothing is executed.
#' @param text R Markdown source as one character string.
#' @return A list with `refused` (logical), `findings` (code, message, lines,
#'   refuse) and the counts of chunks and inline R expressions.
#' @export
scan_rmd_risks <- function(text) {
  assert_text(text)
  lines <- strsplit(gsub("\r\n", "\n", text, fixed = TRUE), "\n", fixed = TRUE)[[1]]
  kind <- rep("prose", length(lines))
  if (length(lines) && trimws(lines[1]) == "---") {
    end <- which(seq_along(lines) > 1L & trimws(lines) %in% c("---", "..."))
    if (length(end)) kind[seq_len(end[1])] <- "yaml"
  }
  fence <- "^[ \t]*(`{3,}|~{3,})"
  inside <- FALSE
  for (i in seq_along(lines)) {
    if (kind[i] == "yaml") next
    if (!inside && grepl(paste0(fence, "[ \t]*\\{"), lines[i])) {
      kind[i] <- "header"
      inside <- TRUE
    } else if (inside && grepl(paste0(fence, "[ \t]*$"), lines[i])) {
      kind[i] <- "fence"
      inside <- FALSE
    } else if (inside) {
      kind[i] <- "code"
    }
  }
  # inline R in prose counts as code
  inline <- regmatches(lines, gregexpr("`r[ \t][^`]*`", lines))
  code_text <- ifelse(kind == "code", lines, ifelse(kind == "prose", vapply(inline, paste, "", collapse = " "), ""))
  where <- list(header = ifelse(kind == "header", lines, ""), code = code_text, yaml = ifelse(kind == "yaml", lines, ""))
  findings <- list()
  for (rule in rmd_risk_rules()) {
    hit <- which(grepl(rule$pattern, where[[rule$where]], perl = TRUE))
    if (length(hit)) {
      findings[[length(findings) + 1L]] <- list(code = rule$code, message = rule$message, lines = hit, refuse = rule$refuse)
    }
  }
  list(refused = any(vapply(findings, function(f) isTRUE(f$refuse), logical(1))),
    findings = findings, chunks = sum(kind == "header"), inline_expressions = sum(lengths(inline)))
}

# Packages a document loads (library, require, pkg::), for installing in WebR.
rmd_packages <- function(text) {
  calls <- regmatches(text, gregexpr("(library|require|requireNamespace)\\(\\s*['\"]?([A-Za-z][A-Za-z0-9.]*)", text, perl = TRUE))[[1]]
  named <- sub("^.*\\(\\s*['\"]?", "", calls)
  colons <- regmatches(text, gregexpr("\\b([A-Za-z][A-Za-z0-9.]*)::", text, perl = TRUE))[[1]]
  pkgs <- unique(c(named, sub("::$", "", colons)))
  setdiff(pkgs, c("base", "stats", "utils", "graphics", "grDevices", "methods", "tools", "parallel", "grid",
    "webr", "jmv2gg"))
}

#' Render an R Markdown document to self-contained HTML in this R session
#'
#' Used by the browser workbench inside a fresh WebR worker, with knitr and
#' markdown (WebR has no Pandoc). The page gets a table of contents and
#' folded code blocks as plain HTML, and every figure is embedded. Refused
#' constructs (see [scan_rmd_risks()]) stop before anything runs.
#' @param input Path to the .Rmd file (its folder holds the data files).
#' @param output Path of the HTML file to write.
#' @param confirmed Codes of the findings the user has reviewed and accepted.
#' @param time_limit Seconds the document may run.
#' @param progress Write one message per chunk as knitr reaches it
#'   ("jmv2gg-progress <done> <total> <label>"), so the browser can show how far
#'   the render is.
#' @return The path of the HTML file.
#' @export
render_browser_preview <- function(input, output, confirmed = character(), time_limit = 300, progress = FALSE) {
  for (p in c("knitr", "markdown")) if (!requireNamespace(p, quietly = TRUE)) stop("The ", p, " package is needed to render.")
  text <- paste(readLines(input, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  scan <- scan_rmd_risks(text)
  if (scan$refused) {
    refused <- Filter(function(f) isTRUE(f$refuse), scan$findings)
    stop("This document is not rendered in the browser: ", paste(vapply(refused, function(f) f$message, ""), collapse = " "),
      " Render it in native R instead.")
  }
  unreviewed <- setdiff(vapply(scan$findings, function(f) f$code, ""), confirmed)
  if (length(unreviewed)) stop("Review these items before rendering: ", paste(unreviewed, collapse = ", "), ".")
  old <- setwd(dirname(input))
  on.exit(setwd(old), add = TRUE)
  setTimeLimit(elapsed = time_limit, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  # Non-R engines are refused by the scan; refuse them again at run time.
  refuse <- function(options) stop("Chunks in other languages are not run in the browser.")
  for (engine in setdiff(names(knitr::knit_engines$get()), c("R", "r"))) knitr::knit_engines$set(stats::setNames(list(refuse), engine))
  # A chunk error stops the preview, as in rmarkdown (knit() alone would print it and go on).
  knitr::opts_chunk$set(dev = "png", dpi = 96, fig.width = 7, fig.height = 5, error = FALSE)
  total <- scan$chunks
  done <- 0L
  current <- NULL
  # An option hook runs once before each chunk (every chunk has an `eval` option):
  # it records the chunk for error messages and, if asked, reports progress.
  knitr::opts_hooks$set(eval = function(options) {
    done <<- done + 1L
    current <<- options$label
    if (isTRUE(progress)) message("jmv2gg-progress ", done, " ", total, " ", options$label)
    options
  })
  on.exit(knitr::opts_hooks$delete("eval"), add = TRUE)
  # The markdown sits next to the document so its figure files resolve.
  md <- file.path(dirname(input), paste0(tools::file_path_sans_ext(basename(input)), ".preview.md"))
  on.exit(unlink(md), add = TRUE)
  restore <- guard_jmv_knit_print()
  on.exit(restore(), add = TRUE)
  meta <- rmd_front_matter(text)
  envir <- new.env(parent = globalenv())
  # rmarkdown::render() would provide `params` from the YAML header; knit() alone does not.
  if (!is.null(meta$params)) assign("params", preview_params(meta$params, envir), envir = envir)
  tryCatch(knitr::knit(input, output = md, quiet = TRUE, envir = envir), error = function(e) {
    where <- if (is.null(current)) "" else paste0("Chunk ", done, " of ", total, " (", current, "): ")
    stop(where, conditionMessage(e), call. = FALSE)
  })
  if (file.size(md) > preview_size_limit) stop("The document's output is larger than 20 MB; render it in native R.")
  # knit() keeps the YAML header; markdown would read its rmarkdown output
  # options (for example `toc: true` under html_document) as its own and fail.
  writeLines(drop_front_matter(readLines(md, warn = FALSE, encoding = "UTF-8")), md, useBytes = TRUE)
  body <- markdown::mark(md, format = "html", options = list(embed_resources = TRUE, toc = FALSE))
  html <- preview_page(body, meta$title %||% "Report preview")
  writeLines(html, output, useBytes = TRUE)
  output
}

preview_size_limit <- 20 * 1024^2

# jmvcore prints its results in knitr as HTML (knit_print.ResultsElement ->
# htmlify), which fails for some results (jmv 2.8.0 / jmvcore 28.3: reliability
# gives "invalid argument type" in WebR). A failure there would stop the whole
# preview, so such a result is printed as plain text instead, as in the R
# console, under a note saying so (shown whatever the chunk's warning
# option). Returns a function that restores the original method.
guard_jmv_knit_print <- function() {
  knitr_ns <- asNamespace("knitr")
  # jmvcore registers its method when it loads, which a document does mid-render.
  if (requireNamespace("jmvcore", quietly = TRUE)) loadNamespace("jmvcore")
  original <- utils::getS3method("knit_print", "ResultsElement", optional = TRUE, envir = knitr_ns)
  if (is.null(original)) return(function() invisible())
  registerS3method("knit_print", "ResultsElement", envir = knitr_ns, function(x, ...) {
    tryCatch(original(x, ...), error = function(e) {
      cat("Note: jmvcore could not print this jamovi result as HTML (", conditionMessage(e),
        "); it is printed as text.\n", sep = "")
      knitr::normal_print(x)
    })
  })
  function() registerS3method("knit_print", "ResultsElement", original, envir = knitr_ns)
}

drop_front_matter <- function(lines) {
  if (!length(lines) || trimws(lines[1]) != "---") return(lines)
  end <- which(seq_along(lines) > 1L & trimws(lines) %in% c("---", "..."))
  if (!length(end)) lines else lines[-seq_len(end[1])]
}

# The `params` list rmarkdown builds from the YAML header: each entry is a value
# or a list with `value`. Values written as !r / !expr are R code; they run only
# after the user confirmed the "yaml_expression" finding (checked by the caller).
preview_params <- function(params, envir) {
  if (!is.list(params)) stop("The YAML `params` field must be a list of parameters.")
  value_of <- function(x) {
    if (is.list(x) && !inherits(x, "jmv2gg_r_expression") && "value" %in% names(x)) x <- x$value
    if (inherits(x, "jmv2gg_r_expression")) x <- eval(parse(text = unclass(x)), envir = new.env(parent = envir))
    x
  }
  structure(lapply(params, value_of), class = "knit_param_list")
}

rmd_front_matter <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  if (!length(lines) || trimws(lines[1]) != "---") return(list())
  end <- which(seq_along(lines) > 1L & trimws(lines) %in% c("---", "..."))
  if (!length(end)) return(list())
  as_expression <- function(x) structure(x, class = "jmv2gg_r_expression")
  meta <- tryCatch(yaml::yaml.load(paste(lines[2:(end[1] - 1L)], collapse = "\n"), eval.expr = FALSE,
    handlers = list(r = as_expression, expr = as_expression)), error = function(e) list())
  if (!is.list(meta)) list() else meta
}

# A second layer behind the script-free sandboxed frame: remove elements and
# attributes that run code, load other pages or navigate.
sanitize_preview_html <- function(html) {
  for (tag in c("script", "iframe", "object", "embed", "style", "form", "noscript", "template")) {
    html <- gsub(paste0("(?is)<", tag, "\\b[^>]*>.*?</", tag, "\\s*>"), "", html, perl = TRUE)
    html <- gsub(paste0("(?i)</?", tag, "\\b[^>]*>"), "", html, perl = TRUE)
  }
  html <- gsub("(?i)<(base|meta|link)\\b[^>]*>", "", html, perl = TRUE)
  # Attributes are cleaned inside real tags only, so displayed code is untouched.
  tags <- gregexpr("<[A-Za-z][^>]*>", html, perl = TRUE)
  regmatches(html, tags) <- lapply(regmatches(html, tags), function(tag) {
    tag <- gsub("(?i)\\s+on[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)", "", tag, perl = TRUE)
    tag <- gsub("(?i)\\b(href|src|action|formaction|xlink:href)\\s*=\\s*([\"']?)\\s*(javascript|vbscript|data:text/html)[^\"'>\\s]*\\2",
      "\\1=\"#\"", tag, perl = TRUE)
    # Outside addresses would let an image request carry data out; figures are embedded as data: URIs.
    tag <- gsub("(?i)\\s+srcset\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)", "", tag, perl = TRUE)
    tag <- gsub("(?i)\\s+(src|poster|background)\\s*=\\s*(\"\\s*(https?:|//)[^\"]*\"|'\\s*(https?:|//)[^']*'|(https?:|//)[^\\s>]*)",
      "", tag, perl = TRUE)
    gsub("(?i)\\s+target\\s*=\\s*([\"']?)_(top|parent|blank)\\1", "", tag, perl = TRUE)
  })
  html
}

# Wrap the knitted HTML: heading anchors, a table of contents (levels 1-3)
# and folded code blocks, all without scripts. Scripts in the body are kept
# out: the frame runs none, and they are removed here as a second layer.
# The browser preview installs a stand-in 'websocket' (tools/webr/placeholders); say so when it was loaded.
placeholder_loaded <- function() {
  "websocket" %in% loadedNamespaces() && isTRUE(tryCatch(getExportedValue("websocket", "is_jmv2gg_placeholder")(), error = function(e) FALSE))
}

preview_page <- function(body, title) {
  body <- sanitize_preview_html(paste(body, collapse = "\n"))
  heads <- gregexpr("<h([1-3])(?: id=\"[^\"]*\")?>(.*?)</h\\1>", body, perl = TRUE)
  found <- regmatches(body, heads)[[1]]
  toc <- character()
  for (i in seq_along(found)) {
    level <- as.integer(sub("^<h([1-3]).*$", "\\1", found[i]))
    label <- sub("^<h[1-3][^>]*>(.*)</h[1-3]>$", "\\1", found[i])
    id <- paste0("section-", i)
    body <- sub(found[i], paste0("<h", level, " id=\"", id, "\">", label, "</h", level, ">"), body, fixed = TRUE)
    toc <- c(toc, paste0("<li class=\"toc-", level, "\"><a href=\"#", id, "\">", gsub("<[^>]+>", "", label), "</a></li>"))
  }
  body <- gsub("<pre><code class=\"language-r\">", "<details class=\"code\"><summary>Show code</summary><pre><code class=\"language-r\">", body, fixed = TRUE)
  body <- gsub("(?s)(<details class=\"code\"><summary>Show code</summary><pre><code class=\"language-r\">.*?</code></pre>)", "\\1</details>", body, perl = TRUE)
  css <- system.file("report", "preview.css", package = "jmv2gg")
  style <- if (nzchar(css)) paste(readLines(css, warn = FALSE), collapse = "\n") else ""
  c("<!DOCTYPE html>", "<html lang=\"en\"><head><meta charset=\"utf-8\">",
    paste0("<title>", gsub("<", "&lt;", title, fixed = TRUE), "</title>"),
    "<style>", style, "</style></head><body>",
    "<p class=\"preview-note\">Browser preview rendered with knitr and markdown in WebR. The reference report is rendered in native R.",
    if (placeholder_loaded()) " The 'websocket' package here is jmv2gg's labelled placeholder (it opens no connections), so session information lists it.",
    "</p>",
    if (length(toc)) c("<nav class=\"toc\"><p>Contents</p><ul>", toc, "</ul></nav>"),
    "<main>", body, "</main></body></html>")
}
