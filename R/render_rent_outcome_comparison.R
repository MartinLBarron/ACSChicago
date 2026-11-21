source("R/acs_config.R")
root<-normalizePath(".")
out<-file.path(root,"output/models/rent_outcome_comparison_2024")
cache<-file.path(out,".cache");dir.create(cache,recursive=TRUE,showWarnings=FALSE)
Sys.setenv(XDG_CACHE_HOME=cache)
rmarkdown::render(file.path(root,"R/rent_outcome_comparison.Rmd"),output_file="report.html",output_dir=out,
  params=list(project_root=root),knit_root_dir=root,envir=new.env(parent=globalenv()),quiet=TRUE)
message("Rendered ",file.path(out,"report.html"))
