# New crime-centered numbering; prior housing-centered M0–M5 remain separate.
source("R/crime_config.R")
crime_stages_config <- crime_config
crime_stages_config$analytic_dir <- "data/analytic/crime_stages_2024"
crime_stages_config$output_dir <- "output/models/block_group_crime_stages_2024"
crime_stage_formulas <- list(
  M0 = log_rent ~ 1,
  M1 = log_rent ~ violent_crime_count,
  M2 = stats::reformulate(c("violent_crime_count", bg_housing_terms), "log_rent"),
  M3 = stats::reformulate(c("violent_crime_count", bg_predictors), "log_rent"),
  M4 = stats::reformulate(c("violent_crime_count", bg_predictors, "community_id"), "log_rent"))
crime_stage_labels <- c(M0 = "Intercept only", M1 = "Violent crime only",
  M2 = "+ Housing and renter profile", M3 = "+ Socioeconomic context", M4 = "+ Community-area location")
