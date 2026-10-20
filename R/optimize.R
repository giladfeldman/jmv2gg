#' Losslessly optimize a publication PNG
#' @param file Existing PNG file.
#' @return Invisibly, a list with success, byte counts and verified pixel equality.
#' @details Requires the native oxipng executable and the png R package.
#'   Optimization runs on a temporary copy. The original is retained unless the
#'   decoded pixels, dimensions and resolution metadata are unchanged and the
#'   output is no larger. There is no color quantization or downsampling.
#' @export
optimize_png <- function(file) {
  if(!is.character(file) || length(file)!=1L || !file.exists(file)) stop("Supply one existing PNG path.")
  before_bytes<-unname(file.info(file)$size)
  unchanged<-function(reason) {warning(reason,call.=FALSE);invisible(list(success=FALSE,before=before_bytes,after=before_bytes,pixels_verified=FALSE))}
  executable<-Sys.which("oxipng")
  if(!nzchar(executable) || !requireNamespace("png",quietly=TRUE))
    return(unchanged("PNG kept unchanged: lossless optimization requires native oxipng and the png package."))
  temporary<-tempfile(fileext=".png");on.exit(unlink(temporary))
  if(!file.copy(file,temporary))stop("Could not prepare optimizer scratch file.")
  before<-png::readPNG(file,native=TRUE,info=TRUE)
  output<-system2(executable,c("-o","4","--",shQuote(temporary)),stdout=TRUE,stderr=TRUE)
  if(!is.null(attr(output,"status")) && attr(output,"status")!=0L) return(unchanged("PNG kept unchanged: optimizer failed."))
  after<-tryCatch(png::readPNG(temporary,native=TRUE,info=TRUE),error=identity)
  if(inherits(after,"error") || !identical(dim(before),dim(after)) ||
    !identical(as.integer(before),as.integer(after)) ||
    !isTRUE(all.equal(attr(before,"info")$dpi,attr(after,"info")$dpi)))
    return(unchanged("PNG kept unchanged: optimizer output did not preserve decoded pixels and resolution."))
  after_bytes<-unname(file.info(temporary)$size)
  if(after_bytes>before_bytes) return(invisible(list(success=TRUE,before=before_bytes,after=before_bytes,pixels_verified=TRUE)))
  if(!file.copy(temporary,file,overwrite=TRUE))stop("Could not replace the verified optimized PNG.")
  invisible(list(success=TRUE,before=before_bytes,after=after_bytes,pixels_verified=TRUE))
}
