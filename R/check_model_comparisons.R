# Independent publication checks for the 26 ACS comparison measures.
source("R/acs_config.R")
source("R/housing_config.R")
source("R/model_display_config.R")
comparison <- jsonlite::read_json("html/data/web/comparison_statistics.json",simplifyVector=TRUE)
measures <- c(housing_display_variables(acs_config$variables),setdiff(model_display_measures,c("violent_crime_count","crime_rate")))
stopifnot(length(measures)==26L,nrow(comparison)==33L,
  !anyDuplicated(comparison[c("GEOID","acs_end_year")]),!any(comparison$synthetic_data))
for(year in acs_years) {
  selected <- comparison[comparison$acs_end_year==year,]
  stopifnot(nrow(selected)==11L,setequal(selected$comparison_id,c("chicago","philadelphia","milwaukee","detroit","minneapolis","boston","houston","new_york","los_angeles","miami","united_states")))
  core <- jsonlite::read_json("html/data/web/chicago_city_statistics.json",simplifyVector=TRUE)
  core <- core[core$acs_end_year==year,]
  supplement <- jsonlite::read_json(sprintf("html/data/web/chicago_city_model_measures_%d.json",year),simplifyVector=TRUE)
  for(measure in measures)for(suffix in c("estimate","moe")) {
    field <- paste0(measure,"_",suffix)
    stopifnot(field %in% names(comparison))
    values <- selected[[field]]
    if (measure == "total_population" && suffix == "moe") {
      controlled <- selected$total_population_moe_annotation %in% "*****"
      stopifnot(all(is.na(values[controlled])))
      values <- values[!controlled]
    }
    stopifnot(all(is.finite(values)),all(values>=0))
    card <- if(field %in% names(supplement))supplement[[field]] else core[[field]]
    stopifnot(isTRUE(all.equal(selected[[field]][selected$comparison_id=="chicago"],card,check.attributes=FALSE)))
  }
}
# Check source-count identities without using the derivation helper.
long <- readRDS("data/analytic/acs_combined/comparison_model_source_long.rds")
for(year in acs_years)for(id in unique(comparison$comparison_id)) {
  source <- long[long$acs_end_year==year&long$comparison_id==id,]
  values <- stats::setNames(source$estimate,source$variable)
  row <- comparison[comparison$acs_end_year==year&comparison$comparison_id==id,]
  population <- source[source$variable == "race_total", ]
  stopifnot(isTRUE(all.equal(row$total_population_estimate, population$estimate)),
    isTRUE(all.equal(row$total_population_moe, population$moe)))
  stopifnot(abs(row$two_bedrooms_pct_estimate-100*values["bed_two"]/values["bed_total"])<1e-10,
    abs(row$structure_1_unit_pct_estimate-100*sum(values[c("structure_detached","structure_attached")])/values["structure_total"])<1e-10,
    abs(row$small_bedrooms_pct_estimate+row$two_bedrooms_pct_estimate+row$large_bedrooms_pct_estimate-100)<1e-10)
}
stopifnot(identical(unname(tools::md5sum("data/web/comparison_statistics.json")),unname(tools::md5sum("html/data/web/comparison_statistics.json"))))
message("PASS: all ACS comparison measures, peers, periods, MOEs, Chicago cards and source-count identities")
