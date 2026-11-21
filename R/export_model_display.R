# Web-only supplements: all mapped areas, direct city estimates, no model-sample restriction.
source("R/model_display_config.R")
source("R/housing_derivation_helpers.R")
source("R/crime_helpers.R")
cfg<-model_display_config
acs_config<-acs_config_for_year(cfg$year)
dir.create(cfg$site_dir,recursive=TRUE,showWarnings=FALSE)
derive_display<-function(x) {
  out<-x["GEOID"]
  for(name in names(model_display_shares)) {
    values<-derive_housing_percentage(x,model_display_shares[[name]])
    for(field in c("estimate","moe","estimate_status","moe_status"))out[[paste0(name,"_pct_",field)]]<-values[[field]]
  }
  for(field in c("estimate","moe","estimate_raw","moe_raw","estimate_annotation","moe_annotation"))
    out[[paste0("area_median_income_",field)]]<-x[[paste0("area_median_income_",field)]]
  out
}
violent<-readRDS(file.path(cfg$crime_dir,if(cfg$year==2024L)"violent_record_assignment.rds" else "violent_records.rds"))
valid<-violent$coordinate_status=="usable"
points<-sf::st_as_sf(violent[valid,c("latitude","longitude")],coords=c("longitude","latitude"),crs=4326)|>sf::st_transform(acs_config$crs)
for(tag in c("block_group","tract","chicago_city")) {
  source_data<-if(tag=="block_group" && cfg$year==2024L)readRDS(file.path(bg_model_config$analytic_dir,"all_bg_model_data.rds")) else
    readRDS(file.path(cfg$analytic_dir,paste0(tag,"_source.rds")))
  out<-derive_display(source_data)
  if(tag=="chicago_city") {
    out$violent_crime_count_estimate<-nrow(violent)
  } else {
    geometry<-sf::st_read(file.path(acs_config$analytic_dir,paste0(tag,"_housing.gpkg")),quiet=TRUE)|>sf::st_transform(acs_config$crs)
    stopifnot(setequal(geometry$GEOID,out$GEOID))
    if(tag=="block_group" && cfg$year==2024L) {
      ids<-violent$GEOID[valid]
      out$model_community<-source_data$community[match(out$GEOID,source_data$GEOID)]
    } else ids<-crime_assign_points(points,geometry)$GEOID
    saveRDS(data.frame(GEOID=ids),file.path(cfg$analytic_dir,paste0(tag,"_crime_assignment.rds")))
    counts<-table(factor(ids,levels=out$GEOID))
    out$violent_crime_count_estimate<-as.integer(counts)
  }
  out$acs_start_year<-cfg$year-4L
  out$acs_end_year<-cfg$year
  out$boundary_year<-cfg$year
  out$recent_movers_cutoff<-cfg$year-4L
  out$violent_crime_count_moe<-NA_real_
  out$violent_crime_count_estimate_status<-"recorded_rows"
  out$violent_crime_count_moe_status<-"not_applicable_administrative_count"
  saveRDS(out,file.path(cfg$analytic_dir,paste0(tag,"_display.rds")))
  jsonlite::write_json(out,file.path(cfg$site_dir,paste0(tag,"_model_measures_",cfg$year,".json")),
    dataframe="rows",na="null",digits=NA)
  message("Exported model measures: ",tag," ",nrow(out)," areas")
}
annual<-violent|>dplyr::count(occurrence_year,name="violent_crime_count_estimate")|>
  dplyr::transmute(acs_start_year=occurrence_year,acs_end_year=occurrence_year,
    violent_crime_count_estimate=violent_crime_count_estimate,violent_crime_count_moe=NA_real_)
saveRDS(annual,file.path(cfg$analytic_dir,"annual_crime.rds"))
# Combine only after all three releases have been exported (the runner checks this).
paths<-vapply(acs_years,function(year)file.path(model_display_config_for_year(year)$analytic_dir,"annual_crime.rds"),character(1))
if(all(file.exists(paths))) {
  combined<-dplyr::bind_rows(lapply(paths,readRDS)) |> dplyr::arrange(acs_end_year)
  stopifnot(!anyDuplicated(combined$acs_end_year),setequal(combined$acs_end_year,2010:2024))
  jsonlite::write_json(combined,file.path(cfg$site_dir,"chicago_annual_violent_crime.json"),dataframe="rows",na="null",digits=NA)
}
