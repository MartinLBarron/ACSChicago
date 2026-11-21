# All-period display pipeline. Does not refit the separately specified 2024 models.
source("R/acs_config.R")
run_model_display <- function() {
  previous <- getOption("chicago.display_year")
  on.exit(options(chicago.display_year=previous),add=TRUE)
  for(year in acs_years) {
    options(chicago.display_year=year)
    source("R/check_model_display_definitions.R")
    source("R/download_model_display.R")
    source("R/download_historical_display_crime.R")
    source("R/export_model_display.R")
    source("R/check_model_display.R")
  }
  annual<-jsonlite::read_json("html/data/web/chicago_annual_violent_crime.json",simplifyVector=TRUE)
  stopifnot(nrow(annual)==15L,setequal(annual$acs_end_year,2010:2024))
}
run_model_display()
