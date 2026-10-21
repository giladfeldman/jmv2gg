# Run after downloading the synthetic example's Rmd and ZIP from the browser.
downloads<-Sys.getenv("JMV2GG_DOWNLOAD_DIR")
if(!nzchar(downloads))stop("Set JMV2GG_DOWNLOAD_DIR to the browser download directory.")
library(jmv2gg)
source<-paste(readLines("web/public/examples/report.Rmd",warn=FALSE),collapse="\n")
expected<-convert_rmd(source,engine="both",original_output="hide")$text
rmd<-Sys.getenv("JMV2GG_BROWSER_RMD",file.path(downloads,"converted.Rmd"))
actual<-paste(readLines(rmd,warn=FALSE,encoding="UTF-8"),collapse="\n")
stopifnot(identical(enc2utf8(expected),enc2utf8(actual)))
cat("Browser/native Rmd conversion parity: exact text match\n")
bundle<-Sys.getenv("JMV2GG_BROWSER_BUNDLE",file.path(downloads,"jmv2gg-bundle.zip"))
members<-utils::unzip(bundle,list=TRUE)$Name
print(members)
stopifnot(all(c("converted.Rmd","conversion.json","browser-environment.json","render.R","README.txt") %in% members),
  !any(grepl("[.](csv|sav)$",members)))
cat("Browser ZIP provenance and data exclusion PASS\n")
