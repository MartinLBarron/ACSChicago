source("R/crime_config.R")
source("R/crime_helpers.R")
cfg <- crime_config
dir.create(cfg$raw_dir, recursive = TRUE, showWarnings = FALSE)
crime_validate_manifest(cfg$raw_dir)
crime_get(cfg$metadata, file.path(cfg$raw_dir, "dataset_metadata_before.json"))
crime_get(cfg$lookup, file.path(cfg$raw_dir, "iucr_lookup.json"), query = list(`$limit` = 5000, `$order` = "iucr"))
all_years <- sprintf("date >= '%d-01-01T00:00:00' AND date < '%d-01-01T00:00:00'", min(cfg$years), max(cfg$years) + 1)
crime_get(paste0(cfg$resource, ".json"), file.path(cfg$raw_dir, "source_year_counts.json"),
  query = list(`$select` = "date_extract_y(date) as occurrence_year,count(*) as rows",
    `$where` = all_years, `$group` = "occurrence_year", `$order` = "occurrence_year"))
counts <- jsonlite::read_json(file.path(cfg$raw_dir, "source_year_counts.json"), simplifyVector = TRUE)
stopifnot(setequal(as.integer(counts$occurrence_year), cfg$years))
requests <- list()
for (year in cfg$years) {
  year_where <- sprintf("date >= '%d-01-01T00:00:00' AND date < '%d-01-01T00:00:00'", year, year + 1)
  expected <- as.integer(counts$rows[counts$occurrence_year == year])
  last_id <- 0; downloaded <- 0L; page <- 0L
  while (downloaded < expected) {
    page <- page + 1L
    path <- file.path(cfg$raw_dir, sprintf("crimes_%d_part%03d.csv", year, page))
    query <- list(`$select` = paste(cfg$fields, collapse = ","),
      `$where` = paste0(year_where, " AND id > ", format(last_id, scientific = FALSE, trim = TRUE)),
      `$order` = "id", `$limit` = cfg$page_size)
    crime_get(paste0(cfg$resource, ".csv"), path, query)
    chunk <- crime_read_csv(path)
    ids <- as.numeric(chunk$id)
    stopifnot(nrow(chunk) > 0, all(is.finite(ids)), all(diff(ids) > 0), min(ids) > last_id,
      all(as.integer(substr(chunk$date, 1, 4)) == year))
    downloaded <- downloaded + nrow(chunk); last_id <- max(ids)
    requests[[length(requests) + 1L]] <- data.frame(year = year, page = page, path = path,
      where = query$`$where`, select = query$`$select`, order = "id", limit = cfg$page_size, rows = nrow(chunk))
    message("CPD ", year, ": ", downloaded, "/", expected, " rows cached")
  }
  if (downloaded != expected) stop("Source changed during extraction for ", year, "; counts do not reconcile")
}
request_path <- file.path(cfg$raw_dir, "requests.csv")
if (!file.exists(request_path)) readr::write_csv(dplyr::bind_rows(requests), request_path)
crime_get(cfg$metadata, file.path(cfg$raw_dir, "dataset_metadata_after.json"))
before <- jsonlite::read_json(file.path(cfg$raw_dir, "dataset_metadata_before.json"))
after <- jsonlite::read_json(file.path(cfg$raw_dir, "dataset_metadata_after.json"))
snapshot_path <- file.path(cfg$raw_dir, "snapshot.json")
if (!file.exists(snapshot_path)) jsonlite::write_json(list(resource = cfg$resource, years = cfg$years,
  selection = all_years, rows_updated_before = before$rowsUpdatedAt, rows_updated_after = after$rowsUpdatedAt,
  source_changed_during_download = !identical(before$rowsUpdatedAt, after$rowsUpdatedAt),
  snapshot_policy = "Frozen first successful extraction; later reruns reuse/verify cache. Not a historical as-of-2024 snapshot.",
  row_unit = "CPD rows by unique ID, including murder victim rows; no case-number deduplication"),
  snapshot_path, pretty = TRUE, auto_unbox = TRUE)
crime_write_manifest(cfg$raw_dir)
message("CPD cache complete: ", sum(as.integer(counts$rows)), " rows in the requested occurrence years")
