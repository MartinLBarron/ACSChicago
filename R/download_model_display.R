source("R/model_display_config.R")
source("R/acs_helpers.R")
require_acs_packages()
cfg <- model_display_config
acs_config <- acs_config_for_year(cfg$year)
dir.create(cfg$raw_dir,recursive=TRUE,showWarnings=FALSE)
dir.create(cfg$analytic_dir,recursive=TRUE,showWarnings=FALSE)
manifest <- file.path(cfg$raw_dir,"manifest.csv")
if(file.exists(manifest)) {
  old <- readr::read_csv(manifest,show_col_types=FALSE)
  stopifnot(all(file.exists(old$path)),all(unname(tools::md5sum(old$path))==old$md5))
}
for(tag in c("block_group","tract","chicago_city")) {
  if(tag=="block_group" && cfg$year==2024L) next # Reuse the existing full BG extraction.
  core <- readRDS(file.path(acs_config$analytic_dir,paste0(tag,"_housing.rds")))
  kind <- if(tag=="chicago_city")"place" else if(tag=="block_group")"block group" else tag
  counties <- if(tag!="chicago_city")sort(unique(substr(core$GEOID,3,5))) else NA_character_
  responses <- list()
  for(group in names(model_display_groups)) {
    variables <- model_display_groups[[group]]
    batches <- split(variables,ceiling(seq_along(variables)/12))
    prepared_parts <- list()
    for(county in counties) for(i in seq_along(batches)) {
      config <- acs_config_for_year(cfg$year)
      config$variables <- batches[[i]]
      stem<-file.path(cfg$raw_dir,paste(tag,group,ifelse(is.na(county),"state",county),i,sep="_"))
      cache_api_response(kind,county,config,paste0(stem,"_api.json"))
      api<-read_api_response(paste0(stem,"_api.json"))
      tidy_path<-paste0(stem,"_tidycensus.rds")
      if(!file.exists(tidy_path)) {
        args<-list(geography=kind,
          state=config$state,variables=config$variables,year=cfg$year,survey="acs5",geometry=FALSE,
          output="tidy",moe_level=90,key=Sys.getenv("CENSUS_API_KEY"),show_call=FALSE)
        if(tag!="chicago_city")args$county<-county
        message("Model display: ",tag," ",group," batch ",i)
        tidy<-do.call(tidycensus::get_acs,args)
        saveRDS(tidy,tidy_path)
      }
      selected<-core[core$GEOID %in% api$GEOID,"GEOID",drop=FALSE]
      prepared_parts[[length(prepared_parts)+1L]]<-prepare_acs_dataset(readRDS(tidy_path),api,selected,kind,config)
    }
    long<-dplyr::bind_rows(lapply(prepared_parts,`[[`,"long"))
    # A batch splits variables, counties split areas: pivot once after combining.
    metadata<-c("GEOID","NAME","geography","acs_start_year","acs_end_year","period","dollar_year","boundary_year","moe_confidence","synthetic_data")
    wide<-long|>tidyr::pivot_wider(id_cols=dplyr::all_of(metadata),names_from=variable,
      values_from=c(estimate,moe,estimate_raw,moe_raw,estimate_annotation,moe_annotation),names_glue="{variable}_{.value}")
    responses[[group]]<-list(long=long,wide=wide)
  }
  long<-dplyr::bind_rows(lapply(responses,`[[`,"long"))
  long$unit<-ifelse(long$variable=="area_median_income",paste(cfg$year,"annual household-income dollars"),"count in the published ACS table universe")
  wide<-responses[[1]]$wide
  for(part in responses[-1])wide<-dplyr::left_join(wide,part$wide[c("GEOID",setdiff(names(part$wide),metadata))],by="GEOID")
  stopifnot(setequal(wide$GEOID,core$GEOID),!anyDuplicated(wide$GEOID))
  saveRDS(wide,file.path(cfg$analytic_dir,paste0(tag,"_source.rds")))
  saveRDS(long,file.path(cfg$analytic_dir,paste0(tag,"_source_long.rds")))
}
paths<-list.files(cfg$raw_dir,full.names=TRUE)
paths<-paths[basename(paths)!="manifest.csv"]
readr::write_csv(data.frame(path=paths,md5=unname(tools::md5sum(paths))),manifest)
