# Private fixture locations and output belong in environment variables, not git.
fixture <- Sys.getenv("JMV2GG_PRIVATE_RMD")
output <- Sys.getenv("JMV2GG_PRIVATE_OUTPUT")
if (!nzchar(fixture) || !file.exists(fixture) || !nzchar(output)) stop("Set JMV2GG_PRIVATE_RMD and JMV2GG_PRIVATE_OUTPUT.")
library(jmv2gg)
dir.create(output,recursive=TRUE,showWarnings=FALSE)
data_parameter <- rmarkdown::yaml_front_matter(fixture)$params$data
if(is.list(data_parameter)) data_parameter <- data_parameter$value
data <- file.path(dirname(fixture),data_parameter)
if(!file.exists(data)) stop("The adjacent fixture data is missing.")
before <- tools::md5sum(c(fixture,data))
source <- paste(readLines(fixture,warn=FALSE,encoding="UTF-8"),collapse="\n")
params <- list(data=normalizePath(data,winslash="/"),results_json=file.path(output,"original-results.json"))
cat("Original baseline render starting\n")
baseline <- rmarkdown::render(fixture,output_format="html_document",output_file="original.html",
  output_dir=output,intermediates_dir=output,knit_root_dir=output,params=params,
  envir=new.env(parent=globalenv()),quiet=TRUE)
cat("Original baseline render complete\n")
engines <- strsplit(Sys.getenv("JMV2GG_TEST_ENGINES","ggplot2"),",",fixed=TRUE)[[1]]
for(engine in engines) {
  dir <- file.path(output,engine); dir.create(dir,recursive=TRUE,showWarnings=FALSE)
  converted <- convert_rmd(source,engine=engine)
  stopifnot(converted$manifest$detected==37L,converted$manifest$converted==37L)
  path <- file.path(dir,"converted.Rmd"); writeLines(converted$text,path,useBytes=TRUE)
  params$results_json <- file.path(dir,"original-results.json")
  cat("Converted render starting:",engine,"expected figures",length(converted$manifest$plots),"\n")
  render_env<-new.env(parent=globalenv())
  rmarkdown::render(path,output_format="html_document",output_dir=dir,intermediates_dir=dir,
    knit_root_dir=dir,params=params,envir=render_env,quiet=TRUE)
  reference <- jsonlite::read_json(file.path(output,"original-results.json"),simplifyVector=FALSE)
  actual <- jsonlite::read_json(params$results_json,simplifyVector=FALSE)
  comparison <- all.equal(reference,actual,tolerance=1e-10)
  if(!isTRUE(comparison)) stop("Original reproduction records changed: ",paste(comparison,collapse="; "))
  verified_models<-0L
  for(a in converted$analyses) {
    if(!a$function_name %in% c("ANOVA","logRegBin") || is.null(a$binding)) next
    original<-get(a$binding,envir=render_env)
    model<-get(paste0(".jmv2gg_",a$id,"_model"),envir=render_env)
    if(a$function_name=="ANOVA") {
      reference_table<-original$main$asDF
      reference_table<-reference_table[reference_table$name != "Overall model",,drop=FALSE]
      type<-if(is.null(a$args$ss))3L else as.integer(a$args$ss)
      actual_table<-as.data.frame(car::Anova(model,type=type))
      actual_table<-actual_table[rownames(actual_table)!="(Intercept)",,drop=FALSE]
      for(pair in list(c("ss","Sum Sq"),c("df","Df"),c("F","F value"),c("p","Pr(>F)"))) {
        cmp<-all.equal(as.numeric(reference_table[[pair[1]]]),as.numeric(actual_table[[pair[2]]]),tolerance=1e-8)
        if(!isTRUE(cmp)) { print(reference_table);print(actual_table);stop("Generated ANOVA differs from original for ",a$id," column ",pair[1],": ",paste(cmp,collapse="; ")) }
      }
    } else {
      n_models<-if(is.null(a$args$blocks))1L else max(1L,length(a$args$blocks)-1L)
      reference_estimates<-original$models[[n_models]]$coef$asDF$est
      reference_estimates<-reference_estimates[!is.na(reference_estimates)]
      cmp<-all.equal(reference_estimates,unname(stats::coef(model)),tolerance=1e-8)
      if(!isTRUE(cmp))stop("Generated logistic coefficients differ for ",a$id,": ",paste(cmp,collapse="; "))
    }
    verified_models<-verified_models+1L
  }
  stopifnot(verified_models==9L)
  files <- list.files(file.path(dir,"figures"),pattern="[.]png$",full.names=TRUE)
  stopifnot(length(files)==length(converted$manifest$plots),all(file.info(files)$size>1000))
  cat("Converted render and numerical preservation PASS:",engine,length(files),"figures;",verified_models,"generated models match original inference\n")
}
stopifnot(identical(unname(before),unname(tools::md5sum(c(fixture,data)))))
cat("Private fixture source/data hashes unchanged\n")
