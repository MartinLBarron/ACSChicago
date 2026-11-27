# Display inputs for each ACS release; model fitting remains a separate 2024 study.
source("R/bg_model_config.R")
model_display_config_for_year <- function(year) {
  stopifnot(year %in% acs_years)
  list(year=as.integer(year), raw_dir=sprintf("data/raw_data/model_display_%d_v1",year),
    analytic_dir=sprintf("data/analytic/model_display_%d",year),site_dir="html/data/web",
    crime_dir=if(year==2024L)"data/analytic/crime_2020_2024" else sprintf("data/analytic/display_crime_%d_%d",year-4L,year))
}
model_display_config <- model_display_config_for_year(getOption("chicago.display_year",2024L))
model_display_groups <- bg_variable_groups
model_display_shares <- bg_share_definitions[setdiff(names(bg_share_definitions),"structure_other")]
# Complete the displayed bedroom/building categories without changing regressions.
model_display_shares$two_bedrooms <- list(numerator="bed_two",denominator="bed_total")
model_display_shares$structure_1_unit <- list(numerator=c("structure_detached","structure_attached"),denominator="structure_total")
if(model_display_config$year==2014L) {
  # B25036 has one fewer construction-era cell than the later releases.
  model_display_groups$age <- bg_codes("B25036",12:21,
    c("age_total","age_2010_plus","age_2000s","age_1990s","age_1980s",
      "age_1970s","age_1960s","age_1950s","age_1940s","age_pre1940"))
  model_display_shares$built2000_plus$numerator <- c("age_2010_plus","age_2000s")
  model_display_shares$recent_movers$numerator <- "b25038_010"
} else if(model_display_config$year==2019L) {
  model_display_groups$age <- bg_codes("B25036",13:23,
    c("age_total","age_2014_plus","age_2010_2013","age_2000s","age_1990s","age_1980s",
      "age_1970s","age_1960s","age_1950s","age_1940s","age_pre1940"))
  model_display_shares$built2000_plus$numerator <- c("age_2014_plus","age_2010_2013","age_2000s")
}
# Publish the total-population cell already collected for the two race/ethnicity shares.
display_direct_fields <- function(data) {
  suffixes <- c("estimate", "moe", "estimate_raw", "moe_raw", "estimate_annotation", "moe_annotation")
  fields <- function(variable) paste(variable, suffixes, sep = "_")
  population <- data[fields("race_total")]
  names(population) <- fields("total_population")
  dplyr::bind_cols(data[fields("area_median_income")], population)
}
model_display_measures <- c(paste0(names(model_display_shares),"_pct"),"area_median_income","total_population","violent_crime_count")
