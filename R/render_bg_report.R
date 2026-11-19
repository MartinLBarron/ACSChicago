source("R/bg_model_config.R")
stopifnot(requireNamespace("rmarkdown", quietly = TRUE), rmarkdown::pandoc_available())
root <- normalizePath(".")
out <- file.path(root, bg_model_config$output_dir)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
cache <- file.path(out, ".cache")
dir.create(cache, showWarnings = FALSE)
Sys.setenv(XDG_CACHE_HOME = cache)
rmarkdown::render(file.path(root, "R/block_group_rent_report.Rmd"),
  output_file = "report.html", output_dir = out,
  params = list(project_root = root, results_path = file.path(bg_model_config$analytic_dir, "model_results.rds")),
  knit_root_dir = root, envir = new.env(parent = globalenv()), quiet = TRUE)
message("Rendered ", file.path(out, "report.html"))
