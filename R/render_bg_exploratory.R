source("R/bg_exploratory_config.R")
root <- normalizePath(".")
out <- file.path(root,bg_exploratory_config$output_dir)
cache <- file.path(out,".cache")
dir.create(cache,recursive=TRUE,showWarnings=FALSE)
Sys.setenv(XDG_CACHE_HOME=cache)
rmarkdown::render(file.path(root,"R/block_group_exploratory_report.Rmd"),output_file="report.html",output_dir=out,
  params=list(project_root=root),knit_root_dir=root,envir=new.env(parent=globalenv()),quiet=TRUE)
message("Rendered ",file.path(out,"report.html"))
