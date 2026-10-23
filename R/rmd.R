#' Convert an R Markdown document without executing it
#'
#' Adds one figure setup chunk after the YAML header and, after each chunk
#' with converted analyses, a figure chunk with a caption for every figure.
#' The YAML header is edited in place, so its comments and layout are kept.
#' @param text UTF-8 R Markdown source as one character string.
#' @param engine Selected plotting engine.
#' @param original_output Include existing output or hide analysis chunk output.
#' @param html_preset Enhanced HTML presentation or preserve existing settings.
#' @param style Named style options, as in [convert_code()]; `headings = TRUE`
#'   adds a heading before each figure chunk, one level below the source's.
#' @param figures Named publication figure options.
#' @return A `jmv2gg_result` with preserved original source and generated chunks.
#' @export
convert_rmd <- function(text, engine = c("both", "ggplot2", "bettergg"),
                        original_output = c("include", "hide"),
                        html_preset = c("enhanced", "preserve"),
                        style = list(), figures = list()) {
  assert_text(text)
  engine <- match.arg(engine); original_output <- match.arg(original_output); html_preset <- match.arg(html_preset)
  options <- conversion_options(style, figures)
  if (grepl("<!-- jmv2gg:converted v[12] -->", text)) {
    return(new_result(text, list(), list(diag_record("warning", "already_converted",
      "This document already contains jmv2gg conversion markers; no duplicate blocks were added.")), engine))
  }
  lines <- strsplit(gsub("\r\n", "\n", text, fixed=TRUE), "\n", fixed=TRUE)[[1]]
  if (!length(lines)) lines <- ""
  diagnostics <- options$diagnostics; analyses <- list(); plots <- list(); packages <- character()
  header <- tryCatch(merge_html_yaml(lines, html_preset), error=identity)
  if (inherits(header,"error")) return(new_result(text,list(),list(diag_record("error","invalid_yaml",conditionMessage(header))),engine))
  # Every identifier in the document, so generated names never clash with the author's.
  symbols <- unique(regmatches(text, gregexpr("[A-Za-z.][A-Za-z0-9._]*", text))[[1]])
  reserved <- reserved_name_clash(symbols)
  if (!is.null(reserved)) return(new_result(text, list(), c(diagnostics, list(reserved)), engine))
  output <- c(header$lines, "<!-- jmv2gg:converted v2 -->")
  if(html_preset=="enhanced") {
    css<-system.file("report","report.css",package="jmv2gg")
    if(nzchar(css))output<-c(output,"<style>",readLines(css,warn=FALSE),"</style>")
  }
  setup_at <- length(output)
  diagnostics <- c(diagnostics,header$diagnostics)
  i <- header$next_line
  heading <- "Analysis"
  heading_level <- 1L
  counts <- list()
  blocks <- list()
  while (i <= length(lines)) {
    line <- lines[i]
    if (grepl("^#{1,6} ",line)) {
      heading <- sub("^#+ +","",line)
      heading_level <- nchar(sub(" .*$", "", line))
    }
    fence <- regmatches(line,regexec("^([ \t]*)(`{3,}|~{3,})\\{[rR]([ ,}].*)$",line))[[1]]
    if (!length(fence)) {output <- c(output,line); i <- i+1L; next}
    chunk_start <- i
    delimiter <- fence[3]
    end <- i+1L
    while(end <= length(lines) && !grepl(paste0("^[ \\t]*",substr(delimiter,1,1),"{",nchar(delimiter),",}[ \\t]*$"),lines[end])) end <- end+1L
    if (end > length(lines)) {
      output <- c(output,lines[i:length(lines)])
      diagnostics <- c(diagnostics,list(diag_record("error","unclosed_chunk","An R chunk has no closing fence.",line=i)))
      break
    }
    chunk_lines <- if(end>i+1L) lines[(i+1L):(end-1L)] else character()
    chunk_code <- paste(chunk_lines,collapse="\n")
    label <- trimws(sub("[,}].*$","",sub("^.*\\{[rR] *","",line)))
    parsed <- inspect_code(chunk_code,offset=length(analyses))
    if(!is.null(parsed$error)) {
      diagnostics <- c(diagnostics,list(diag_record("error","invalid_r",parsed$error,line=i,chunk=label)))
      output <- c(output,lines[i:end]); i <- end+1L; next
    }
    records <- assign_analysis_names(parsed$analyses, symbols, counts)
    counts <- attr(records, "counts")
    diagnostics <- c(diagnostics,lapply(parsed$diagnostics,function(dg) {dg$chunk<-label; dg$line<-(dg$line %||% 1L)+chunk_start; dg}))
    generated <- character(); snapshots <- list()
    for (j in seq_along(records)) {
      record <- records[[j]]; original_record <- record
      record$chunk <- label; record$heading <- heading
      snapshot <- paste0(record$name, "_input")
      data_expr <- record$args$data
      if(is.symbol(data_expr)) record$args$data <- as.name(snapshot)
      generated_result <- tryCatch(generate_analysis(record,engine,options),error=identity)
      records[[j]]$line <- original_record$line+chunk_start
      records[[j]]$chunk <- label; records[[j]]$heading <- heading
      if(inherits(generated_result,"error")) {
        records[[j]]$status <- "unsupported"
        diagnostics <- c(diagnostics,list(diag_record("warning","unsupported_analysis",conditionMessage(generated_result),record$id,original_record$line+chunk_start,label)))
        next
      }
      # Only insert snapshots after complete, separate source statements.
      following <- Filter(function(r) r$line == original_record$end_line && r$expression_index != record$expression_index, parsed$analyses)
      if(length(following)) {
        records[[j]]$status <- "unsupported"
        diagnostics <- c(diagnostics,list(diag_record("warning","same_line_analyses","Put analyses on separate lines to preserve input snapshots safely.",record$id,original_record$line+chunk_start,label)))
        next
      }
      records[[j]]$status <- "converted"; records[[j]]$mapping <- generated_result$mapping
      if (is.symbol(data_expr)) {
        snapshots[[as.character(original_record$end_line)]] <- c(snapshots[[as.character(original_record$end_line)]],
          paste0(snapshot," <- ",r_text(data_expr), " # data for the jmv2gg figures of ", record$name))
      }
      disabled <- grepl("eval\\s*=\\s*(FALSE|F|0)([,} ]|$)",line)
      if(grepl("eval\\s*=",line) && !disabled && !grepl("eval\\s*=\\s*TRUE([,} ]|$)",line)) {
        disabled <- TRUE
        diagnostics <- c(diagnostics,list(diag_record("warning","conditional_execution","Generated chunk is disabled because the source eval option is dynamic. Review before enabling.",record$id,chunk_start,label)))
      }
      statistical_notes <- vapply(generated_result$diagnostics,function(dg) paste0("> **Figure note:** ",dg$message),character(1))
      captions <- vapply(generated_result$plots, function(p) p$caption, character(1))
      heading_lines <- if (isTRUE(options$style$headings)) {
        c("", paste0(strrep("#", min(6L, heading_level + 1L)), " Figures: ", heading))
      } else character()
      code_key <- paste0("\001jmv2gg-code-", length(blocks) + 1L)
      blocks[[code_key]] <- generated_result$code
      generated <- c(generated, heading_lines, "", statistical_notes, if (length(statistical_notes)) "",
        paste0(delimiter,"{r jmv2gg-",gsub("_", "-", record$name),", fig.cap=", r_text(captions), ", cache=FALSE",
          if(disabled)", eval=FALSE" else "","}"),
        code_key,delimiter)
      plots <- c(plots,generated_result$plots)
      packages <- c(packages, generated_result$packages)
      diagnostics <- c(diagnostics,lapply(generated_result$diagnostics,function(dg){dg$line<-(dg$line %||% 1L)+chunk_start;dg$chunk<-label;dg}))
    }
    if(original_output=="hide" && length(records)) {
      # Explicit options occur last so the intended presentation setting wins.
      line <- hide_chunk_output(line)
      diagnostics <- c(diagnostics,list(diag_record("info","hidden_original_chunk",
        "Existing output from this complete analysis chunk is hidden; its calculations and side effects still run.",line=chunk_start,chunk=label)))
    }
    preserved <- character()
    for(k in seq_along(chunk_lines)) preserved <- c(preserved,chunk_lines[k],snapshots[[as.character(k)]])
    output <- c(output,line,preserved,lines[end],generated)
    analyses <- c(analyses,records)
    i <- end+1L
  }
  # jamovi results need the print fallback (jmv_print_fallback_code) even without new figures.
  has_jmv <- any(vapply(analyses, function(a) identical(a$package, "jmv"), logical(1)))
  if (length(plots) || has_jmv) {
    setup_code <- c(if (length(plots)) c(figure_setup_code(options, packages), ""), if (has_jmv) jmv_print_fallback_code())
    styled <- style_generated(c(list(setup = setup_code), blocks), options)
    diagnostics <- c(diagnostics, styled$diagnostics)
    for (key in names(blocks)) output[output == key] <- styled$pieces[[key]]
    setup <- c("", "```{r jmv2gg-setup, include=FALSE}", styled$pieces$setup, "```")
    output <- append(output, setup, after = setup_at)
  }
  new_result(paste(output,collapse="\n"),analyses,diagnostics,engine,plots)
}

hide_chunk_output <- function(header) {
  open <- regexpr("\\{[rR]",header)
  content <- sub("}\\s*$","",substring(header,open+2L))
  label <- trimws(sub(",.*$","",content))
  has_label <- nzchar(label) && !grepl("=",label,fixed=TRUE)
  options_content <- if(has_label) if(grepl(",",content,fixed=TRUE)) sub("^[^,]*,","",content) else "" else content
  parsed <- tryCatch(parse(text=paste0("alist(",options_content,")"))[[1]],error=identity)
  if(inherits(parsed,"error")) stop("Cannot safely update this chunk's display options; use include existing output.")
  args <- as.list(parsed)[-1L]
  nms <- names(args) %||% rep("",length(args))
  keep <- !nms %in% c("results","fig.show","echo")
  args <- args[keep]; nms <- nms[keep]
  options <- vapply(seq_along(args),function(i) paste0(if(nzchar(nms[i])) paste0(nms[i],"=") else "",r_text(args[[i]])),character(1))
  paste0(substring(header,1L,open),"r ",paste(c(if(has_label)label,options,"results='hide'","fig.show='hide'","echo=FALSE"),collapse=", "),"}")
}

# The enhanced HTML settings jmv2gg adds to html_document.
html_settings <- list(
  toc = "true", toc_depth = "3", toc_float = c("collapsed: false", "smooth_scroll: true"),
  code_folding = "hide", self_contained = "true", df_print = "paged"
)

merge_html_yaml <- function(lines,preset) {
  yaml_end <- 0L; diagnostics <- list()
  has_yaml <- length(lines) && identical(trimws(lines[1]),"---")
  if(has_yaml) {
    closing <- which(seq_along(lines)>1L & trimws(lines) %in% c("---","..."))
    if(!length(closing)) stop("The initial YAML header is not closed.")
    yaml_end <- closing[1]
    content <- paste(lines[seq.int(2L,yaml_end-1L)],collapse="\n")
    # Tags such as !r and !expr would be lost by re-serializing the YAML, so keep it verbatim.
    if(grepl("(^|[[:space:]:,\\[-])![A-Za-z]",content)) {
      return(list(lines=lines[seq_len(yaml_end)],next_line=yaml_end+1L,
        diagnostics=list(diag_record("warning","yaml_expression_preserved","YAML contains tags such as !r or !expr and was kept verbatim without execution. Apply enhanced HTML settings locally if needed."))))
    }
    metadata <- yaml::yaml.load(content,eval.expr=FALSE) %||% list()
    if(!is.list(metadata) || is.null(names(metadata))) stop("YAML metadata must be a named mapping.")
  }
  if(preset=="preserve") return(list(lines=if(has_yaml)lines[seq_len(yaml_end)] else character(),next_line=yaml_end+1L,diagnostics=diagnostics))
  body <- if (has_yaml && yaml_end > 2L) lines[seq.int(2L, yaml_end - 1L)] else character()
  edited <- tryCatch(edit_yaml_lines(body), error = identity)
  if (inherits(edited, "error")) {
    return(list(lines = if (has_yaml) lines[seq_len(yaml_end)] else character(), next_line = yaml_end + 1L,
      diagnostics = list(diag_record("warning", "yaml_not_edited", paste("The YAML header was kept unchanged:",
        conditionMessage(edited), "Add the enhanced HTML settings yourself if you want them.")))))
  }
  list(lines = c("---", edited, "---"), next_line = yaml_end + 1L, diagnostics = diagnostics)
}

# Add the enhanced html_document settings by editing lines, so comments,
# order and quoting of everything else stay as the author wrote them.
edit_yaml_lines <- function(body) {
  top_key <- function(l) if (grepl("^[A-Za-z_][A-Za-z0-9_.-]*:", l)) sub(":.*$", "", l) else NA_character_
  keys <- vapply(body, top_key, character(1), USE.NAMES = FALSE)
  indent_of <- function(l) nchar(l) - nchar(sub("^ +", "", l))
  value_of <- function(l) trimws(sub("#.*$", "", sub("^[^:]*:", "", l)))
  comment_of <- function(l) if (grepl(" #", l, fixed = TRUE)) paste0(" #", sub("^.*? #", "", l)) else ""
  settings_block <- function(indent) {
    pad <- strrep(" ", indent)
    out <- character()
    for (k in names(html_settings)) {
      v <- html_settings[[k]]
      out <- c(out, if (length(v) > 1L) c(paste0(pad, k, ":"), paste0(pad, "  ", v)) else paste0(pad, k, ": ", v))
    }
    out
  }
  if (!"title" %in% keys) body <- c("title: \"Editable analysis figures\"", body)
  keys <- vapply(body, top_key, character(1), USE.NAMES = FALSE)
  at <- which(keys == "output")
  if (!length(at)) {
    body <- c(body, "output:", "  html_document:", settings_block(4L))
  } else {
    at <- at[1]
    value <- value_of(body[at])
    block_end <- at
    while (block_end < length(body) && (indent_of(body[block_end + 1L]) > 0L || !nzchar(trimws(body[block_end + 1L])))) {
      block_end <- block_end + 1L
    }
    if (nzchar(value)) {
      if (grepl("^[\\[{]", value)) stop("the output field is written inline ([...] or {...}).")
      format <- gsub("^[\"']|[\"']$", "", value)
      new <- c(paste0("output:", comment_of(body[at])),
        if (format != "html_document") paste0("  ", format, ": default"),
        "  html_document:", settings_block(4L))
      body <- c(body[seq_len(at - 1L)], new, body[-seq_len(at)])
    } else {
      children <- if (block_end > at) seq.int(at + 1L, block_end) else integer()
      child_indent <- if (length(children)) min(vapply(body[children][nzchar(trimws(body[children]))], indent_of, numeric(1))) else 2
      html <- children[indent_of(body[children]) == child_indent & grepl("^ *html_document *:", body[children])]
      if (!length(html)) {
        body <- append(body, c(paste0(strrep(" ", child_indent), "html_document:"), settings_block(child_indent + 2L)), after = block_end)
      } else {
        h <- html[1]
        h_value <- value_of(body[h])
        if (nzchar(h_value) && h_value != "default") stop("html_document is written inline.")
        h_end <- h
        while (h_end < length(body) && indent_of(body[h_end + 1L]) > child_indent && nzchar(trimws(body[h_end + 1L]))) h_end <- h_end + 1L
        body[h] <- paste0(strrep(" ", child_indent), "html_document:", comment_of(body[h]))
        own <- if (h_end > h) seq.int(h + 1L, h_end) else integer()
        grand <- if (length(own)) min(vapply(body[own], indent_of, numeric(1))) else child_indent + 2
        settings <- body[own]
        for (k in names(html_settings)) {
          v <- html_settings[[k]]
          pad <- strrep(" ", grand)
          hit <- which(indent_of(settings) == grand & grepl(paste0("^ *", k, " *:"), settings))
          replacement <- if (length(v) > 1L) c(paste0(pad, k, ":"), paste0(pad, "  ", v)) else paste0(pad, k, ": ", v)
          if (length(hit)) {
            stop_at <- hit[1]
            while (stop_at < length(settings) && indent_of(settings[stop_at + 1L]) > grand) stop_at <- stop_at + 1L
            if (length(v) == 1L) replacement <- paste0(replacement, comment_of(settings[hit[1]]))
            settings <- c(settings[seq_len(hit[1] - 1L)], replacement, settings[-seq_len(stop_at)])
          } else {
            settings <- c(settings, replacement)
          }
        }
        body <- c(body[seq_len(h)], settings, body[-seq_len(h_end)])
      }
    }
  }
  check <- yaml::yaml.load(paste(body, collapse = "\n"), eval.expr = FALSE)
  html <- check$output$html_document
  if (!is.list(html) || !isTRUE(html$toc) || !identical(html$code_folding, "hide")) {
    stop("the edited header did not contain the html_document settings.")
  }
  body
}

#' Render a converted document in a clean native R process
#' @param input Path to the converted Rmd.
#' @param output_dir Directory for rendered output.
#' @param params Optional parameter overrides.
#' @param overwrite Whether to overwrite existing HTML.
#' @return The rendered HTML path.
#' @export
render_report <- function(input, output_dir=dirname(input), params=NULL, overwrite=FALSE) {
  if(grepl("emscripten",R.version$platform)) stop("Full HTML knitting requires native R and Pandoc.")
  if(!file.exists(input)) stop("Input Rmd does not exist.")
  for(p in c("rmarkdown","callr")) if(!requireNamespace(p,quietly=TRUE)) stop("Install package ",p," before rendering.")
  if(!rmarkdown::pandoc_available()) stop("Pandoc was not found. Install RStudio, Quarto, or Pandoc and expose it to R.")
  dir.create(output_dir,recursive=TRUE,showWarnings=FALSE)
  output <- file.path(output_dir,paste0(tools::file_path_sans_ext(basename(input)),".html"))
  if(file.exists(output) && !isTRUE(overwrite)) stop("Output already exists. Choose another directory or set overwrite=TRUE.")
  input <- normalizePath(input,winslash="/",mustWork=TRUE)
  output_dir <- normalizePath(output_dir,winslash="/",mustWork=TRUE)
  result <- callr::r(function(input,output_dir,params) {
    path<-rmarkdown::render(input,output_format="html_document",output_dir=output_dir,params=params,
      envir=new.env(parent=globalenv()),quiet=TRUE)
    list(path=path,session=utils::capture.output(utils::sessionInfo()))
  },args=list(input=input,output_dir=output_dir,params=params),libpath=.libPaths())
  writeLines(result$session,file.path(output_dir,"session-info.txt"))
  result$path
}
