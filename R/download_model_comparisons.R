# Extend every ACS card to peer cities and the US, using direct Census geographies.
source("R/acs_config.R")
source("R/acs_helpers.R")
source("R/housing_config.R")
source("R/housing_derivation_helpers.R")
source("R/comparison_helpers.R")
require_acs_packages()
if(!nzchar(Sys.getenv("CENSUS_API_KEY")))stop("Set CENSUS_API_KEY in .Renviron.")
comparison_model_frames <- comparison_model_sources <- comparison_model_derived <- list()
comparison_previous_option <- getOption("chicago.display_year")
for(comparison_year in acs_years) {
  options(chicago.display_year=comparison_year)
  source("R/model_display_config.R")
  display_cfg <- model_display_config
  config <- acs_config_for_year(comparison_year)
  config$raw_dir <- sprintf("data/raw_data/model_comparisons_%d_v1",comparison_year)
  dir.create(config$raw_dir,recursive=TRUE,showWarnings=FALSE)
  manifest_path <- file.path(config$raw_dir,"manifest.csv")
  if(file.exists(manifest_path)) {
    previous <- readr::read_csv(manifest_path,show_col_types=FALSE)
    stopifnot(all(file.exists(previous$path)),all(unname(tools::md5sum(previous$path))==previous$md5))
  }
  for(comparison_i in seq_len(nrow(comparison_places))) {
    peer <- comparison_places[comparison_i,]
    if(peer$comparison_id=="chicago") {
      # Reuse the independent direct Chicago-place extraction, never small-area averages.
      wide <- readRDS(file.path(display_cfg$analytic_dir,"chicago_city_source.rds"))
      long <- readRDS(file.path(display_cfg$analytic_dir,"chicago_city_source_long.rds"))
    } else {
      parts <- list()
      for(group in names(model_display_groups)) {
        variables <- model_display_groups[[group]]
        batches <- split(variables,ceiling(seq_along(variables)/12))
        for(batch in seq_along(batches)) {
          part_config <- config
          part_config$variables <- batches[[batch]]
          message("ACS extended comparisons: ",comparison_year," ",peer$comparison_id," ",group," ",batch)
          parts[[length(parts)+1L]] <- get_comparison_variables(peer,part_config,paste0(group,"_",batch))
        }
      }
      long <- dplyr::bind_rows(lapply(parts,`[[`,"long"))
      wide <- parts[[1]]$wide
      for(part in parts[-1])wide <- dplyr::left_join(wide,part$wide[c("GEOID",setdiff(names(part$wide),names(wide)))],by="GEOID")
    }
    stopifnot(nrow(wide)==1L,wide$GEOID==peer$GEOID,wide$acs_end_year==comparison_year,
      !anyDuplicated(long[c("GEOID","variable")]))
    derived <- dplyr::bind_cols(lapply(names(model_display_shares),function(name) {
      values <- derive_housing_percentage(wide,model_display_shares[[name]])
      names(values) <- paste0(name,"_pct_",names(values))
      values
    }))
    metadata <- c("GEOID","NAME","geography","acs_start_year","acs_end_year","period","dollar_year","boundary_year","moe_confidence","synthetic_data")
    x <- dplyr::bind_cols(wide[metadata], derived, display_direct_fields(wide))
    x$comparison_id <- peer$comparison_id
    key <- paste(comparison_year,peer$comparison_id,sep="_")
    comparison_model_frames[[key]] <- x
    comparison_model_sources[[key]] <- dplyr::mutate(long,comparison_id=peer$comparison_id)
    comparison_model_derived[[key]] <- dplyr::bind_cols(wide[metadata],derived) |>
      dplyr::mutate(comparison_id=peer$comparison_id)
  }
  paths <- list.files(config$raw_dir,pattern="_(api[.]json|tidycensus[.]rds)$",full.names=TRUE)
  readr::write_csv(data.frame(path=paths,md5=unname(tools::md5sum(paths))),manifest_path)
  jsonlite::write_json(list(year=comparison_year,
    direct_chicago_source=file.path(display_cfg$analytic_dir,"chicago_city_source.rds"),
    direct_chicago_source_md5=unname(tools::md5sum(file.path(display_cfg$analytic_dir,"chicago_city_source.rds"))),
    shares=model_display_shares),file.path(config$raw_dir,"definitions.json"),auto_unbox=TRUE,pretty=TRUE)
}
options(chicago.display_year=comparison_previous_option)
comparison_model_data <- dplyr::bind_rows(comparison_model_frames)
comparison_model_long <- dplyr::bind_rows(comparison_model_sources)
comparison_model_derivations <- dplyr::bind_rows(comparison_model_derived)
comparison_acs_measures <- setdiff(model_display_measures,c("violent_crime_count","crime_rate"))
stopifnot(nrow(comparison_model_data)==33L,!anyDuplicated(comparison_model_data[c("GEOID","acs_end_year")]))
for(measure in comparison_acs_measures)for(suffix in c("estimate","moe")) {
  values <- comparison_model_data[[paste0(measure,"_",suffix)]]
  if (measure == "total_population" && suffix == "moe") {
    controlled <- comparison_model_data$total_population_moe_annotation %in% "*****"
    stopifnot(all(is.na(values[controlled])))
    values <- values[!controlled]
  }
  stopifnot(all(is.finite(values)),all(values>=0))
  if(grepl("_pct$",measure)&&suffix=="estimate")stopifnot(all(values<=100+1e-8))
}
# Independently prepared Chicago cards must reproduce every added estimate/MOE.
for(year in acs_years) {
  card <- readRDS(sprintf("data/analytic/model_display_%d/chicago_city_display.rds",year))
  row <- comparison_model_data[comparison_model_data$comparison_id=="chicago"&comparison_model_data$acs_end_year==year,]
  for(measure in comparison_acs_measures)for(suffix in c("estimate","moe")) {
    field <- paste0(measure,"_",suffix)
    stopifnot(isTRUE(all.equal(row[[field]],card[[field]],check.attributes=FALSE)))
  }
}
out <- "data/analytic/acs_combined"
for(pair in list(c("comparison_model_measures","comparison_model_data"),c("comparison_model_source_long","comparison_model_long"),c("comparison_model_derived","comparison_model_derivations"))) {
  x <- get(pair[2]);saveRDS(x,file.path(out,paste0(pair[1],".rds")));readr::write_csv(x,file.path(out,paste0(pair[1],".csv")))
}
# Preserve every existing core comparison field, then add the new measures.
core <- readRDS(file.path(out,"comparison_housing.rds"))
extra <- comparison_model_data[c("GEOID","acs_end_year",setdiff(names(comparison_model_data),names(core)))]
combined <- dplyr::left_join(core,extra,by=c("GEOID","acs_end_year"))
stopifnot(nrow(combined)==nrow(core),!anyDuplicated(combined[c("GEOID","acs_end_year")]))
for(field in names(core))stopifnot(identical(combined[[field]],core[[field]]))
fields <- c("comparison_id","GEOID","NAME","geography","acs_start_year","acs_end_year","period","dollar_year","boundary_year","moe_confidence","synthetic_data")
all_measures <- c(housing_display_variables(acs_config$variables),comparison_acs_measures)
suffixes <- c("estimate","moe","estimate_raw","moe_raw","estimate_annotation","moe_annotation","estimate_status","moe_status","moe_method","moe_controlled_components")
fields <- c(fields,as.vector(outer(all_measures,suffixes,paste,sep="_")))
for(directory in c("data/web","html/data/web")) {
  jsonlite::write_json(combined[intersect(fields,names(combined))],file.path(directory,"comparison_statistics.json"),dataframe="rows",na="null",digits=NA,pretty=TRUE)
  exported <- jsonlite::read_json(file.path(directory,"comparison_statistics.json"),simplifyVector=TRUE)
  for(measure in all_measures)for(suffix in c("estimate","moe")) {
    field <- paste0(measure,"_",suffix)
    stopifnot(isTRUE(all.equal(exported[[field]],combined[[field]])))
  }
}
message("PASS: all 26 ACS comparisons, 33 city/national-period rows, MOEs and independent Chicago agreement")
