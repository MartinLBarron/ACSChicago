source("R/model_display_config.R")
cfg<-model_display_config
base<-readRDS(file.path(bg_model_config$analytic_dir,"all_bg_model_data.rds"))
crime<-readRDS("data/analytic/crime_2020_2024/model_results.rds")
for(tag in c("block_group","tract","chicago_city")) {
  x<-readRDS(file.path(cfg$analytic_dir,paste0(tag,"_display.rds")))
  web<-jsonlite::read_json(file.path(cfg$site_dir,paste0(tag,"_model_measures_2024.json")),simplifyVector=TRUE)
  core<-readRDS(file.path(acs_config$analytic_dir,paste0(tag,"_housing.rds")))
  stopifnot(setequal(x$GEOID,core$GEOID),!anyDuplicated(x$GEOID),identical(x$GEOID,web$GEOID))
  for(measure in model_display_measures) {
    value<-paste0(measure,"_estimate");moe<-paste0(measure,"_moe")
    equal_value<-isTRUE(all.equal(x[[value]],as.numeric(web[[value]])))
    stopifnot(all(c(value,moe)%in%names(web)),equal_value,
      all(is.na(x[[value]])|x[[value]]>=0))
    if(grepl("_pct$",measure))stopifnot(all(is.na(x[[value]])|x[[value]]<=100+1e-8))
    if(measure=="violent_crime_count")stopifnot(all(is.na(web[[moe]]))) else
      stopifnot(isTRUE(all.equal(x[[moe]],as.numeric(web[[moe]]))))
  }
  if(tag=="block_group") {
    index<-match(crime$data$GEOID,x$GEOID)
    stopifnot(identical(as.integer(x$violent_crime_count_estimate[index]),as.integer(crime$data$violent_crime_count)))
    for(term in bg_predictors) {
      name<-if(term=="log_income")"area_median_income" else sub("_10pp$","_pct",term)
      expected<-if(term=="log_income")crime$data$income else crime$data[[sub("_10pp$","_pct",term)]]
      stopifnot(isTRUE(all.equal(x[[paste0(name,"_estimate")]][index],expected)))
    }
    stopifnot(sum(x$violent_crime_count_estimate)==crime$audit$mapped_rows)
  }
  if(tag=="tract")stopifnot(sum(x$violent_crime_count_estimate)==crime$audit$mapped_rows)
  if(tag=="chicago_city") {
    source<-readRDS(file.path(cfg$analytic_dir,"chicago_city_source.rds"))
    expected<-100*(source$poverty_below_half_estimate+source$poverty_half_to_one_estimate)/source$poverty_universe_estimate
    stopifnot(abs(x$poverty_pct_estimate-expected)<1e-10,
      x$area_median_income_estimate==source$area_median_income_estimate,
      x$violent_crime_count_estimate==crime$audit$violent_rows)
  }
}
annual<-jsonlite::read_json(file.path(cfg$site_dir,"chicago_annual_violent_crime.json"),simplifyVector=TRUE)
stopifnot(setequal(annual$acs_end_year,2020:2024),sum(annual$violent_crime_count_estimate)==crime$audit$violent_rows)
message("PASS: all mapped tract/BG IDs, model-variable values, city source ratios, ACS MOEs, crime count conservation and annual totals")
