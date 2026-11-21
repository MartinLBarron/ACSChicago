# Latest-period source measures for the model variables, in readable display units.
source("R/bg_model_config.R")
model_display_config <- list(year=2024L,raw_dir="data/raw_data/model_display_2024_v1",
  analytic_dir="data/analytic/model_display_2024",site_dir="html/data/web")
model_display_shares <- bg_share_definitions[setdiff(names(bg_share_definitions),"structure_other")]
model_display_measures <- c(paste0(names(model_display_shares),"_pct"),"area_median_income","violent_crime_count")
