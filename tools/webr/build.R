# Run inside the official pinned WebR build container with the package at /src.
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
status <- system2(file.path(R.home("bin"),"R"), c("CMD","build","--no-build-vignettes","--no-manual","/src"))
if(status != 0L) stop("Source package build failed.")
archive <- list.files(src,pattern="^jmv2gg_.*[.]tar[.]gz$",full.names=TRUE)
if(length(archive) != 1L) stop("Expected exactly one source archive.")
getFromNamespace("wasm_build","rwasm")("jmv2gg",archive,bin,TRUE)
rwasm::write_packages(repo)
files<-sort(c(list.files("/src/R",full.names=TRUE,recursive=TRUE),list.files("/src/man",full.names=TRUE,recursive=TRUE),
  list.files("/src/inst",full.names=TRUE,recursive=TRUE),file.path("/src",c("DESCRIPTION","NAMESPACE","LICENSE"))))
hash<-function(path)strsplit(system2("sha256sum",shQuote(path),stdout=TRUE)," ",fixed=TRUE)[[1]][1]
sources<-stats::setNames(lapply(files,hash),substring(files,6L))
artifact<-file.path(bin,"jmv2gg_0.1.0.9000.tgz")
jsonlite::write_json(list(webR="0.6.0",sources=sources,artifact=substring(artifact,nchar(repo)+2L),sha256=hash(artifact)),
  file.path(repo,"build-manifest.json"),auto_unbox=TRUE,pretty=TRUE)
