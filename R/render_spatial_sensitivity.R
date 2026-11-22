source("R/acs_config.R")
root <- normalizePath(".")
out <- file.path(root,"output/models/spatial_sensitivity_2024")
dir.create(file.path(out,".cache"),recursive=TRUE,showWarnings=FALSE)
Sys.setenv(XDG_CACHE_HOME=file.path(out,".cache"))
rmarkdown::render(file.path(root,"R/spatial_sensitivity_report.Rmd"),output_file="report.html",output_dir=out,
  params=list(project_root=root),knit_root_dir=root,envir=new.env(parent=globalenv()),quiet=TRUE)
message("Rendered ",file.path(out,"report.html"))
