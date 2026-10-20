#' Convert an R Markdown document without executing it
#' @param text UTF-8 R Markdown source as one character string.
#' @param engine Selected plotting engine.
#' @param original_output Include existing output or hide analysis chunk output.
#' @param html_preset Enhanced HTML presentation or preserve existing settings.
#' @param style Named style options, as in [convert_code()].
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
  if (grepl("<!-- jmv2gg:converted v1 -->", text, fixed=TRUE)) {
    return(new_result(text, list(), list(diag_record("warning", "already_converted",
      "This document already contains jmv2gg conversion markers; no duplicate blocks were added.")), engine))
  }
  lines <- strsplit(gsub("\r\n", "\n", text, fixed=TRUE), "\n", fixed=TRUE)[[1]]
  if (!length(lines)) lines <- ""
  diagnostics <- list(); analyses <- list(); plots <- list()
  header <- tryCatch(merge_html_yaml(lines, html_preset), error=identity)
  if (inherits(header,"error")) return(new_result(text,list(),list(diag_record("error","invalid_yaml",conditionMessage(header))),engine))
  output <- c(header$lines, "<!-- jmv2gg:converted v1 -->")
  if(html_preset=="enhanced") {
    css<-system.file("report","report.css",package="jmv2gg")
    if(nzchar(css))output<-c(output,"<style>",readLines(css,warn=FALSE),"</style>")
  }
  diagnostics <- c(diagnostics,header$diagnostics)
  i <- header$next_line
  heading <- "Analysis"
  while (i <= length(lines)) {
    line <- lines[i]
    if (grepl("^#{1,6} ",line)) heading <- sub("^#+ +","",line)
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
    records <- parsed$analyses
    diagnostics <- c(diagnostics,lapply(parsed$diagnostics,function(dg) {dg$chunk<-label; dg$line<-(dg$line %||% 1L)+chunk_start; dg}))
    generated <- character(); snapshots <- list(); all_symbols <- all.names(parsed$expressions)
    for (j in seq_along(records)) {
      record <- records[[j]]; original_record <- record
      record$chunk <- label; record$heading <- heading
      snapshot <- paste0(".jmv2gg_input_",record$id)
      if(any(startsWith(all_symbols,".jmv2gg_"))) {
        generated_result <- simpleError("Source uses reserved .jmv2gg_ names. Rename those bindings before conversion.")
      } else {
        data_expr <- record$args$data
        if(is.symbol(data_expr)) record$args$data <- as.name(snapshot)
        generated_result <- tryCatch(generate_analysis(record,engine,options),error=identity)
      }
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
      snapshots[[as.character(original_record$end_line)]] <- c(snapshots[[as.character(original_record$end_line)]],
        paste0(snapshot," <- ",r_text(original_record$args$data)))
      disabled <- grepl("eval\\s*=\\s*(FALSE|F|0)([,} ]|$)",line)
      if(grepl("eval\\s*=",line) && !disabled && !grepl("eval\\s*=\\s*TRUE([,} ]|$)",line)) {
        disabled <- TRUE
        diagnostics <- c(diagnostics,list(diag_record("warning","conditional_execution","Generated chunk is disabled because the source eval option is dynamic. Review before enabling.",record$id,chunk_start,label)))
      }
      statistical_notes <- vapply(generated_result$diagnostics,function(dg) paste0("> **Conversion note:** ",dg$message),character(1))
      generated <- c(generated,"",paste0("### ",heading," \u2014 editable figures (",record$id,")"),"",statistical_notes,"",
        paste0(delimiter,"{r jmv2gg-",record$id,", cache=FALSE",if(disabled)", eval=FALSE" else "","}"),
        generated_result$code,delimiter)
      plots <- c(plots,generated_result$plots)
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

merge_html_yaml <- function(lines,preset) {
  yaml_end <- 0L; metadata <- list(); diagnostics <- list()
  has_yaml <- length(lines) && identical(trimws(lines[1]),"---")
  if(has_yaml) {
    closing <- which(seq_along(lines)>1L & trimws(lines) %in% c("---","..."))
    if(!length(closing)) stop("The initial YAML header is not closed.")
    yaml_end <- closing[1]
    content <- paste(lines[seq.int(2L,yaml_end-1L)],collapse="\n")
    if(grepl("!expr",content,fixed=TRUE)) {
      return(list(lines=lines[seq_len(yaml_end)],next_line=yaml_end+1L,
        diagnostics=list(diag_record("warning","yaml_expression_preserved","YAML contains !expr and was kept verbatim without execution. Apply enhanced HTML settings locally if needed."))))
    }
    metadata <- yaml::yaml.load(content,eval.expr=FALSE) %||% list()
    if(!is.list(metadata) || is.null(names(metadata))) stop("YAML metadata must be a named mapping.")
  }
  if(preset=="preserve") return(list(lines=if(has_yaml)lines[seq_len(yaml_end)] else character(),next_line=yaml_end+1L,diagnostics=diagnostics))
  output <- metadata$output
  if(is.null(output)) output <- list()
  if(is.character(output)) output <- stats::setNames(rep(list(list()),length(output)),output)
  if(!is.list(output)) stop("Unsupported output declaration. Select preserve HTML settings.")
  html <- output$html_document
  if(is.character(html) || is.null(html)) html <- list()
  if(!is.list(html)) stop("html_document options must be a mapping.")
  html <- utils::modifyList(html,list(toc=TRUE,toc_depth=3,toc_float=list(collapsed=FALSE,smooth_scroll=TRUE),
    code_folding="hide",self_contained=TRUE,df_print="paged"))
  output$html_document <- html; metadata$output <- output
  if(is.null(metadata$title)) metadata$title <- "Editable analysis figures"
  list(lines=c("---",strsplit(yaml::as.yaml(metadata),"\n",fixed=TRUE)[[1]],"---"),next_line=yaml_end+1L,diagnostics=diagnostics)
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
