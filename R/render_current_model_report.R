# Self-contained companion to the interactive model page.
report_dir <- normalizePath("html/data/web", mustWork=TRUE)
report_params <- list(model_data=file.path(report_dir, "block_group_model_2024.json"))
rmarkdown::render("R/current_model_report.Rmd", output_file="block_group_model_report.html",
  output_dir=report_dir,
  params=report_params,
  envir=new.env(parent=globalenv()), quiet=TRUE)
