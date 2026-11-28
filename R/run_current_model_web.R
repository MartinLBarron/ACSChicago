# Primary publication entry point. Requires all three period-specific display datasets.
publish_crime_rate_models <- function() {
  previous <- options(chicago.spatial_crime_rate = TRUE)
  on.exit(options(previous), add = TRUE)
  for (script in c("model_crime_rate_stages", "check_crime_rate_population_weights",
                   "check_crime_rate_periods", "model_spatial_sensitivity", "export_crime_stages_web",
                   "check_current_model_web", "render_current_model_report")) {
    sys.source(file.path("R", paste0(script, ".R")), envir = new.env(parent = globalenv()))
  }
}
publish_crime_rate_models()
