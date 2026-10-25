# Run inside the official pinned WebR build container with the package at
# /src and the BetterGG source at /bettergg (read-only mounts are fine for
# BetterGG). Builds both browser binaries into the app's own repository.
library(rwasm)
# The v0.6.0 image's pak resolver fails with duplicate current metadata rows.
# Use the very same pinned rwasm compiler, bypassing only remote resolution.
# Mandatory dependency binaries are supplied by the matching official repository.
repo <- "/src/web/public/r-packages"
src <- file.path(repo, "src/contrib")
bin <- file.path(repo, "bin/emscripten/contrib/4.6")
dir.create(src, recursive=TRUE, showWarnings=FALSE)
dir.create(bin, recursive=TRUE, showWarnings=FALSE)
old <- setwd(src)
on.exit(setwd(old))
hash<-function(path)strsplit(system2("sha256sum",shQuote(path),stdout=TRUE)," ",fixed=TRUE)[[1]][1]
build_one <- function(package, path) {
  status <- system2(file.path(R.home("bin"),"R"), c("CMD","build","--no-build-vignettes","--no-manual",path))
  if(status != 0L) stop("Source package build failed: ", package)
  version <- read.dcf(file.path(path, "DESCRIPTION"), fields="Version")[[1]]
  archive <- file.path(src, paste0(package, "_", version, ".tar.gz"))
  if(!file.exists(archive)) stop("Expected the source archive ", archive)
  getFromNamespace("wasm_build","rwasm")(package,archive,bin,TRUE)
  artifact <- file.path(bin,paste0(package,"_",version,".tgz"))
  list(version=version, artifact=substring(artifact,nchar(repo)+2L), sha256=hash(artifact))
}
# A dependency whose package source is unchanged since the last build keeps its published
# binary: builds are not byte-reproducible, and published files are cached as immutable,
# so a rebuilt file with new bytes under the same name would break browsers holding the old one.
previous <- tryCatch(jsonlite::read_json(file.path(repo, "build-manifest.json")), error = function(e) list())
# Line endings are ignored: a Windows checkout (CRLF) and a Linux one (LF) are the same source.
lf_hash <- function(path) {
  bytes <- readBin(path, "raw", file.size(path))
  copy <- tempfile(); writeBin(bytes[bytes != as.raw(13L)], copy); hash(copy)
}
source_fingerprint <- function(path) {
  files <- list.files(path, recursive = TRUE)
  files <- sort(files[grepl("^(DESCRIPTION|NAMESPACE|LICENSE|R/|inst/|man/|src/|data/)", files)], method = "radix")
  lines <- paste(files, vapply(file.path(path, files), lf_hash, ""))
  digest <- tempfile(); writeLines(lines, digest); hash(digest)
}
reuse_or_build <- function(package, path, last) {
  fingerprint <- source_fingerprint(path)
  version <- read.dcf(file.path(path, "DESCRIPTION"), fields = "Version")[[1]]
  archive <- file.path(src, paste0(package, "_", version, ".tar.gz"))
  binary <- if (!is.null(last$artifact)) file.path(repo, last$artifact) else ""
  if (identical(last$source, fingerprint) && identical(last$version, version) && file.exists(binary) &&
      file.exists(archive) && identical(hash(binary), last$sha256)) {
    message("Reusing the published ", package, " ", version, " binary (source unchanged).")
    return(last)
  }
  c(build_one(package, path), list(source = fingerprint))
}
if(!dir.exists("/bettergg")) stop("Mount the BetterGG source at /bettergg.")
# Building BetterGG's lazy-load database needs its R dependencies in the container
# (Linux binaries from the container's Posit repository); they are not shipped.
deps <- tools:::.split_dependencies(unlist(read.dcf("/bettergg/DESCRIPTION", fields=c("Depends","Imports"))))
deps <- setdiff(names(deps), c("R", rownames(installed.packages(priority="base"))))
missing <- setdiff(deps, rownames(installed.packages()))
if(length(missing)) install.packages(missing)
bettergg <- reuse_or_build("BetterGG", "/bettergg", previous$dependencies$BetterGG)
# jmv2gg's own install in the container needs its imports, including the BetterGG just built.
for (p in c("jsonlite", "yaml")) if (!p %in% rownames(installed.packages())) install.packages(p)
install.packages(file.path(src, paste0("BetterGG_", bettergg$version, ".tar.gz")), repos=NULL, type="source")
jmv2gg <- build_one("jmv2gg", "/src")
# Placeholder for websocket (no WebR build exists), installed only by the report preview so
# jmv::contTables -> vcdExtra -> chromote can load; it opens no connections. See its DESCRIPTION.
websocket <- reuse_or_build("websocket", "/src/tools/webr/placeholders/websocket", previous$placeholders$websocket)
rwasm::write_packages(repo)
files<-sort(c(list.files("/src/R",full.names=TRUE,recursive=TRUE),list.files("/src/man",full.names=TRUE,recursive=TRUE),
  list.files("/src/inst",full.names=TRUE,recursive=TRUE),file.path("/src",c("DESCRIPTION","NAMESPACE","LICENSE"))))
sources<-stats::setNames(lapply(files,hash),substring(files,6L))
commit <- tryCatch(suppressWarnings(system2("git", c("-C", "/bettergg", "rev-parse", "HEAD"), stdout=TRUE)), error=function(e) NA_character_)
# The manifest names the BetterGG commit it was built from; never record an unknown one.
if (is.null(bettergg$commit) && (!is.null(attr(commit, "status")) || !grepl("^[0-9a-f]{40}$", commit[1])))
  stop("Mount a git checkout of BetterGG at /bettergg: its commit could not be read.")
jsonlite::write_json(list(webR="0.6.0",sources=sources,artifact=jmv2gg$artifact,sha256=jmv2gg$sha256,
  dependencies=list(BetterGG=c(bettergg[setdiff(names(bettergg), "commit")], list(commit=bettergg$commit %||% commit[1]))), placeholders=list(websocket=websocket)),
  file.path(repo,"build-manifest.json"),auto_unbox=TRUE,pretty=TRUE)
