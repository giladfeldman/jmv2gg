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
if(!dir.exists("/bettergg")) stop("Mount the BetterGG source at /bettergg.")
# Building BetterGG's lazy-load database needs its R dependencies in the container
# (Linux binaries from the container's Posit repository); they are not shipped.
deps <- tools:::.split_dependencies(unlist(read.dcf("/bettergg/DESCRIPTION", fields=c("Depends","Imports"))))
deps <- setdiff(names(deps), c("R", rownames(installed.packages(priority="base"))))
missing <- setdiff(deps, rownames(installed.packages()))
if(length(missing)) install.packages(missing)
bettergg <- build_one("BetterGG", "/bettergg")
# jmv2gg's own install in the container needs its imports, including the BetterGG just built.
for (p in c("jsonlite", "yaml")) if (!p %in% rownames(installed.packages())) install.packages(p)
install.packages(file.path(src, paste0("BetterGG_", bettergg$version, ".tar.gz")), repos=NULL, type="source")
jmv2gg <- build_one("jmv2gg", "/src")
# Placeholder for websocket (no WebR build exists), installed only by the report preview so
# jmv::contTables -> vcdExtra -> chromote can load; it opens no connections. See its DESCRIPTION.
websocket <- build_one("websocket", "/src/tools/webr/placeholders/websocket")
rwasm::write_packages(repo)
files<-sort(c(list.files("/src/R",full.names=TRUE,recursive=TRUE),list.files("/src/man",full.names=TRUE,recursive=TRUE),
  list.files("/src/inst",full.names=TRUE,recursive=TRUE),file.path("/src",c("DESCRIPTION","NAMESPACE","LICENSE"))))
sources<-stats::setNames(lapply(files,hash),substring(files,6L))
commit <- tryCatch(system2("git", c("-C", "/bettergg", "rev-parse", "HEAD"), stdout=TRUE), error=function(e) NA_character_)
jsonlite::write_json(list(webR="0.6.0",sources=sources,artifact=jmv2gg$artifact,sha256=jmv2gg$sha256,
  dependencies=list(BetterGG=c(bettergg, list(commit=commit[1]))), placeholders=list(websocket=websocket)),
  file.path(repo,"build-manifest.json"),auto_unbox=TRUE,pretty=TRUE)
