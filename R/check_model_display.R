# Validate every period against its own source counts and matching geometry.
source("R/model_display_config.R")
cfg<-model_display_config
core_config<-acs_config_for_year(cfg$year)
violent<-readRDS(file.path(cfg$crime_dir,if(cfg$year==2024L)"violent_record_assignment.rds" else "violent_records.rds"))
for(tag in c("block_group","tract","chicago_city")) {
  x<-readRDS(file.path(cfg$analytic_dir,paste0(tag,"_display.rds")))
  web<-jsonlite::read_json(file.path(cfg$site_dir,paste0(tag,"_model_measures_",cfg$year,".json")),simplifyVector=TRUE)
  core<-readRDS(file.path(core_config$analytic_dir,paste0(tag,"_housing.rds")))
  stopifnot(setequal(x$GEOID,core$GEOID),!anyDuplicated(x$GEOID),identical(x$GEOID,web$GEOID),
    all(web$acs_end_year==cfg$year),all(web$boundary_year==cfg$year))
  for(measure in model_display_measures) {
    value<-paste0(measure,"_estimate");moe<-paste0(measure,"_moe")
    stopifnot(all(c(value,moe)%in%names(web)),
      isTRUE(all.equal(x[[value]],as.numeric(web[[value]]))),all(is.na(x[[value]])|x[[value]]>=0))
    if(grepl("_pct$",measure))stopifnot(all(is.na(x[[value]])|x[[value]]<=100+1e-8))
    if(measure=="violent_crime_count")stopifnot(all(is.na(web[[moe]]))) else
      stopifnot(isTRUE(all.equal(x[[moe]],as.numeric(web[[moe]]))))
  }
  source<-if(tag=="block_group" && cfg$year==2024L)readRDS(file.path(bg_model_config$analytic_dir,"all_bg_model_data.rds")) else
    readRDS(file.path(cfg$analytic_dir,paste0(tag,"_source.rds")))
  # Independent ratio identities guard against wrong historical table positions.
  idx<-match(x$GEOID,source$GEOID)
  stopifnot(identical(x$total_population_estimate, source$race_total_estimate[idx]),
    identical(x$total_population_moe, source$race_total_moe[idx]))
  for(name in names(model_display_shares)) {
    definition<-model_display_shares[[name]]
    numerator<-rowSums(source[paste0(definition$numerator,"_estimate")])
    denominator<-rowSums(source[paste0(definition$denominator,"_estimate")])
    expected<-100*numerator/denominator
    good<-is.finite(expected)&denominator>0&numerator<=denominator
    stopifnot(isTRUE(all.equal(x[[paste0(name,"_pct_estimate")]][good[idx]],expected[idx][good[idx]])))
  }
  if(tag=="chicago_city")stopifnot(x$violent_crime_count_estimate==nrow(violent)) else {
    assignments<-readRDS(file.path(cfg$analytic_dir,paste0(tag,"_crime_assignment.rds")))
    stopifnot(sum(x$violent_crime_count_estimate)==sum(!is.na(assignments$GEOID)),
      sum(x$violent_crime_count_estimate)<=sum(violent$coordinate_status=="usable"))
  }
  if(tag=="block_group" && cfg$year==2024L) {
    crime<-readRDS("data/analytic/crime_2020_2024/model_results.rds")
    index<-match(crime$data$GEOID,x$GEOID)
    stopifnot(identical(as.integer(x$violent_crime_count_estimate[index]),as.integer(crime$data$violent_crime_count)))
    for(term in bg_predictors) {
      name<-if(term=="log_income")"area_median_income" else sub("_10pp$","_pct",term)
      expected<-if(term=="log_income")crime$data$income else crime$data[[sub("_10pp$","_pct",term)]]
      stopifnot(isTRUE(all.equal(x[[paste0(name,"_estimate")]][index],expected)))
    }
  }
}
annual<-readRDS(file.path(cfg$analytic_dir,"annual_crime.rds"))
stopifnot(setequal(annual$acs_end_year,seq.int(cfg$year-4L,cfg$year)),sum(annual$violent_crime_count_estimate)==nrow(violent))
message("PASS ",cfg$year,": geographic coverage, source ratios, ACS MOEs, latest-model equivalence and crime count conservation")
