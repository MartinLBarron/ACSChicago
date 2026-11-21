# Historical map/dashboard counts use the SAME frozen IUCR definition as 2024.
# Download only potentially included rows, while independently counting all rows.
source("R/model_display_config.R")
source("R/crime_config.R")
source("R/crime_helpers.R")
display_cfg <- model_display_config
if(display_cfg$year != 2024L) {
  cfg <- crime_config
  year_end <- display_cfg$year
  cfg$years <- seq.int(year_end-4L,year_end)
  cfg$raw_dir <- sprintf("data/raw_data/cpd_display_crime_%d_%d_v1",year_end-4L,year_end)
  dir.create(cfg$raw_dir,recursive=TRUE,showWarnings=FALSE)
  dir.create(display_cfg$crime_dir,recursive=TRUE,showWarnings=FALSE)
  crime_validate_manifest(cfg$raw_dir)
  lookup_path <- "data/raw_data/cpd_crime_2020_2024_v1/iucr_lookup.json"
  stopifnot(file.exists(lookup_path))
  lookup <- crime_iucr_map(jsonlite::read_json(lookup_path,simplifyVector=TRUE))
  definition_path <- file.path(cfg$raw_dir,"iucr_lookup.json")
  if(!file.exists(definition_path))stopifnot(file.copy(lookup_path,definition_path))
  stopifnot(identical(unname(tools::md5sum(lookup_path)),unname(tools::md5sum(definition_path))))
  codes <- paste(sprintf("'%s'",lookup$iucr[lookup$included]),collapse=",")
  # OR catches any FBI/IUCR classification disagreement rather than silently dropping it.
  selection <- sprintf("(iucr in (%s) OR fbi_code in ('01A','02','03','04A','04B'))",codes)
  date_where <- sprintf("date >= '%d-01-01T00:00:00' AND date < '%d-01-01T00:00:00'",min(cfg$years),max(cfg$years)+1)
  crime_get(cfg$metadata,file.path(cfg$raw_dir,"dataset_metadata_before.json"))
  for(kind in c("all","selected"))crime_get(paste0(cfg$resource,".json"),file.path(cfg$raw_dir,paste0(kind,"_year_counts.json")),
    query=list(`$select`="date_extract_y(date) as occurrence_year,count(*) as rows",
      `$where`=if(kind=="all")date_where else paste(date_where,"AND",selection),
      `$group`="occurrence_year",`$order`="occurrence_year"))
  counts <- jsonlite::read_json(file.path(cfg$raw_dir,"selected_year_counts.json"),simplifyVector=TRUE)
  stopifnot(setequal(as.integer(counts$occurrence_year),cfg$years))
  requests <- list()
  for(year in cfg$years) {
    year_where <- sprintf("date >= '%d-01-01T00:00:00' AND date < '%d-01-01T00:00:00' AND %s",year,year+1,selection)
    expected <- as.integer(counts$rows[counts$occurrence_year==year])
    last_id <- 0; downloaded <- 0L; page <- 0L
    while(downloaded < expected) {
      page <- page+1L
      path <- file.path(cfg$raw_dir,sprintf("violent_%d_part%03d.csv",year,page))
      query <- list(`$select`=paste(cfg$fields,collapse=","),`$where`=paste0(year_where," AND id > ",format(last_id,scientific=FALSE,trim=TRUE)),`$order`="id",`$limit`=cfg$page_size)
      crime_get(paste0(cfg$resource,".csv"),path,query)
      x <- crime_read_csv(path); ids <- as.numeric(x$id)
      stopifnot(nrow(x)>0,all(is.finite(ids)),all(diff(ids)>0),min(ids)>last_id,all(as.integer(substr(x$date,1,4))==year))
      downloaded <- downloaded+nrow(x); last_id <- max(ids)
      requests[[length(requests)+1L]] <- data.frame(year=year,path=path,rows=nrow(x),where=query$`$where`)
      message("Historical violent crime ",year,": ",downloaded,"/",expected)
    }
    stopifnot(downloaded==expected)
  }
  requests <- dplyr::bind_rows(requests)
  if(!file.exists(file.path(cfg$raw_dir,"requests.csv")))readr::write_csv(requests,file.path(cfg$raw_dir,"requests.csv"))
  violent <- dplyr::bind_rows(lapply(requests$path,crime_read_csv))
  violent <- dplyr::left_join(violent,lookup[c("iucr","violent_group","included")],by="iucr")
  crosscheck <- violent |> dplyr::count(iucr,primary_type,fbi_code,included,name="rows")
  readr::write_csv(crosscheck,file.path(display_cfg$crime_dir,"iucr_fbi_crosscheck.csv"))
  stopifnot(!anyDuplicated(violent$id),nrow(violent)==sum(as.integer(counts$rows)),
    !anyNA(violent$included),all(violent$included),all(violent$fbi_code %in% c("01A","02","03","04A","04B")))
  violent$occurrence_year <- as.integer(substr(violent$date,1,4))
  coords <- crime_coordinates(violent$latitude,violent$longitude,cfg$coordinate_bounds)
  violent$latitude <- coords$latitude; violent$longitude <- coords$longitude
  violent$coordinate_status <- coords$coordinate_status
  saveRDS(violent,file.path(display_cfg$crime_dir,"violent_records.rds"))
  readr::write_csv(violent |> dplyr::count(occurrence_year,violent_group,coordinate_status,name="rows"),file.path(display_cfg$crime_dir,"coordinate_coverage.csv"))
  crime_get(cfg$metadata,file.path(cfg$raw_dir,"dataset_metadata_after.json"))
  before <- jsonlite::read_json(file.path(cfg$raw_dir,"dataset_metadata_before.json"))
  after <- jsonlite::read_json(file.path(cfg$raw_dir,"dataset_metadata_after.json"))
  jsonlite::write_json(list(years=cfg$years,where=date_where,violent_selection=selection,
    source_changed_during_download=!identical(before$rowsUpdatedAt,after$rowsUpdatedAt),
    snapshot_policy="Frozen cached extraction of revised historical records, not an end-of-period archive",
    row_unit="CPD rows by unique ID, including separate murder victim rows"),file.path(cfg$raw_dir,"snapshot.json"),auto_unbox=TRUE,pretty=TRUE)
  crime_write_manifest(cfg$raw_dir)
}
