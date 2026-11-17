# Functions used by download_acs_rent.R; settings live in acs_config.R.
require_acs_packages <- function() {
  packages <- c("sf", "tidycensus", "dplyr", "tidyr", "readr", "httr", "jsonlite")
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install missing packages: ", paste(missing, collapse = ", "))
}

cache_download <- function(url, path) {
  if (file.exists(path)) return(invisible(path))
  temporary <- paste0(path, ".part")
  on.exit(unlink(temporary), add = TRUE)
  status <- utils::download.file(url, temporary, mode = "wb", quiet = TRUE)
  if (status != 0 || file.info(temporary)$size == 0) stop("Download failed: ", basename(path))
  if (!file.rename(temporary, path)) stop("Cannot save ", path)
  invisible(path)
}

select_chicago_geography <- function(kind, config, city_mask) {
  code <- if (kind == "tract") "tract" else "bg"
  stem <- sprintf("tl_%d_%s_%s", config$year, config$state, code)
  archive <- file.path(config$raw_dir, paste0(stem, ".zip"))
  url <- sprintf("https://www2.census.gov/geo/tiger/TIGER%d/%s/%s.zip",
                 config$year, toupper(code), stem)
  cache_download(url, archive)
  directory <- file.path(config$shape_dir, paste0("illinois_", code))
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(archive, exdir = directory)
  all_areas <- sf::st_read(file.path(directory, paste0(stem, ".shp")), quiet = TRUE) |>
    sf::st_make_valid() |>
    sf::st_transform(config$crs)
  candidates <- all_areas[lengths(sf::st_intersects(all_areas, city_mask)) > 0L, ]
  overlap <- suppressWarnings(sf::st_intersection(candidates, city_mask))
  overlap <- suppressWarnings(sf::st_collection_extract(overlap, "POLYGON"))
  positive <- overlap$GEOID[as.numeric(sf::st_area(overlap)) > 0]
  selected <- candidates[candidates$GEOID %in% positive, ]
  excluded <- substr(selected$GEOID, 1, 11) %in% config$excluded_tract_geoids
  if (any(excluded)) {
    stopifnot(all(selected$ALAND[excluded] == 0))
    message("Excluding Lake Michigan water-only ", kind, ": ",
            paste(selected$GEOID[excluded], collapse = ", "))
  }
  selected <- selected[!excluded, ]
  stopifnot(!any(substr(selected$GEOID, 1, 11) %in% config$excluded_tract_geoids))
  selected <- selected[order(selected$GEOID), ]
  id_length <- if (kind == "tract") 11L else 12L
  stopifnot(nrow(selected) > 0L, !anyDuplicated(selected$GEOID),
            all(nchar(selected$GEOID) == id_length),
            all(sf::st_is_valid(selected)), !any(sf::st_is_empty(selected)))
  # GeoPackage preserves full column names and types, unlike shapefile DBF.
  sf::st_write(selected, file.path(config$shape_dir, paste0("chicago_", code, ".gpkg")),
               delete_dsn = TRUE, quiet = TRUE)
  selected
}

# Preserve unmodified API codes and annotations before tidycensus converts sentinels.
cache_api_response <- function(kind, county, config, path) {
  if (file.exists(path)) return(invisible(path))
  codes <- unname(config$variables)
  fields <- c("NAME", as.vector(outer(codes, c("E", "M", "EA", "MA"), paste0)))
  geography <- if (kind == "tract") "tract:*" else "block group:*"
  response <- tryCatch(httr::GET(
    sprintf("https://api.census.gov/data/%d/acs/acs5", config$year),
    query = list(get = paste(fields, collapse = ","), `for` = geography,
                 `in` = paste0("state:", config$state, " county:", county),
                 key = Sys.getenv("CENSUS_API_KEY")),
    httr::timeout(180)
  ), error = function(e) stop("Census API request failed; check connectivity."))
  if (httr::status_code(response) != 200L) {
    stop("Census API returned HTTP ", httr::status_code(response), ".")
  }
  bytes <- httr::content(response, as = "raw")
  parsed <- jsonlite::fromJSON(rawToChar(bytes))
  if (!is.matrix(parsed) || nrow(parsed) < 2L) stop("Unexpected Census API response")
  writeBin(bytes, path)
  invisible(path)
}

read_api_response <- function(path) {
  values <- jsonlite::fromJSON(path)
  result <- as.data.frame(values[-1, , drop = FALSE], stringsAsFactors = FALSE)
  names(result) <- values[1, ]
  result$GEOID <- paste0(result$state, result$county, result$tract,
                         if ("block group" %in% names(result)) result[["block group"]] else "")
  result
}

get_county_variables <- function(kind, county, config, cache_suffix = "") {
  tag <- paste0(gsub(" ", "_", kind), "_", county, cache_suffix)
  json_path <- file.path(config$raw_dir, paste0(tag, "_api.json"))
  cache_api_response(kind, county, config, json_path)
  rds_path <- file.path(config$raw_dir, paste0(tag, "_tidycensus.rds"))
  if (!file.exists(rds_path)) {
    result <- tidycensus::get_acs(
      geography = kind, variables = config$variables, year = config$year,
      survey = config$survey, state = config$state, county = county,
      geometry = FALSE, output = "tidy", moe_level = 90,
      key = Sys.getenv("CENSUS_API_KEY"), show_call = FALSE
    )
    saveRDS(result, rds_path)
  }
  list(tidy = readRDS(rds_path), api = read_api_response(json_path))
}

get_county_rent <- function(kind, county, config) {
  # Keep original rent downloads unchanged; cache the added counts separately.
  rent_config <- config
  rent_config$variables <- config$variables[c("median_contract_rent", "median_gross_rent")]
  count_config <- config
  count_config$variables <- config$variables[c("cash_rent_units", "renter_occupied_units")]
  rent <- get_county_variables(kind, county, rent_config)
  counts <- get_county_variables(kind, county, count_config, "_housing_counts")
  stopifnot(setequal(rent$api$GEOID, counts$api$GEOID),
            !anyDuplicated(rent$api$GEOID), !anyDuplicated(counts$api$GEOID))
  # Add only count fields, retaining geography identifiers from the rent response.
  count_columns <- c("GEOID", setdiff(names(counts$api), names(rent$api)))
  list(tidy = dplyr::bind_rows(rent$tidy, counts$tidy),
       api = dplyr::left_join(rent$api, counts$api[count_columns], by = "GEOID"))
}

build_rent_dataset <- function(kind, boundaries, config) {
  # County requests are inferred from selected geometries, including border areas.
  counties <- sort(unique(substr(boundaries$GEOID, 3, 5)))
  downloads <- lapply(counties, function(county) get_county_rent(kind, county, config))
  tidy <- dplyr::bind_rows(lapply(downloads, `[[`, "tidy"))
  api <- dplyr::bind_rows(lapply(downloads, `[[`, "api"))
  stopifnot(!anyDuplicated(api$GEOID),
            all(boundaries$GEOID %in% api$GEOID))
  selected <- tidy |> dplyr::filter(GEOID %in% boundaries$GEOID)
  stopifnot(!anyDuplicated(selected[c("GEOID", "variable")]),
            setequal(selected$GEOID, boundaries$GEOID),
            nrow(selected) == nrow(boundaries) * length(config$variables),
            setequal(selected$variable, names(config$variables)))
  # Keep raw codes alongside usable values; negative codes are not dollars or counts.
  for (measure in names(config$variables)) {
    code <- config$variables[[measure]]
    rows <- selected$variable == measure
    matched <- match(selected$GEOID[rows], api$GEOID)
    for (suffix in c("E", "M", "EA", "MA")) {
      column <- switch(suffix, E = "estimate_raw", M = "moe_raw",
                       EA = "estimate_annotation", MA = "moe_annotation")
      selected[rows, column] <- api[[paste0(code, suffix)]][matched]
    }
  }
  # Verify both E and M values from tidycensus against the original API response.
  for (field in c("estimate", "moe")) {
    raw <- as.numeric(selected[[paste0(field, "_raw")]])
    valid <- !is.na(raw) & raw >= 0
    stopifnot(all(!is.na(selected[[field]][valid])),
              all(selected[[field]][valid] == raw[valid]))
    selected[[field]][!valid] <- NA_real_
  }
  selected <- selected |>
    dplyr::mutate(variable_code = unname(config$variables[variable]),
                  unit = ifelse(variable %in% c("cash_rent_units", "renter_occupied_units"),
                                "housing units", paste("monthly", config$year, "dollars")),
                  acs_start_year = config$year - 4L, acs_end_year = config$year,
                  period = paste0(config$year - 4L, "–", config$year),
                  dollar_year = config$year,
                  boundary_year = config$year, moe_confidence = 90L,
                  geography = kind, synthetic_data = SYNTHETIC_DATA) |>
    dplyr::arrange(GEOID, variable)
  wide <- selected |>
    tidyr::pivot_wider(
      id_cols = c(GEOID, NAME, geography, acs_start_year, acs_end_year, period, dollar_year,
                  boundary_year, moe_confidence, synthetic_data),
      names_from = variable,
      values_from = c(estimate, moe, estimate_raw, moe_raw,
                      estimate_annotation, moe_annotation),
      names_glue = "{variable}_{.value}"
    )
  stopifnot(nrow(wide) == nrow(boundaries), !anyDuplicated(wide$GEOID))
  for (measure in c("cash_rent_units", "renter_occupied_units")) {
    values <- wide[[paste0(measure, "_estimate")]]
    stopifnot(all(is.na(values) | (values >= 0 & values == floor(values))))
  }
  tag <- gsub(" ", "_", kind)
  readr::write_csv(selected, file.path(config$analytic_dir, paste0(tag, "_rent_long.csv")))
  readr::write_csv(wide, file.path(config$analytic_dir, paste0(tag, "_rent.csv")))
  saveRDS(wide, file.path(config$analytic_dir, paste0(tag, "_rent.rds")))
  spatial <- boundaries[, "GEOID", drop = FALSE] |> dplyr::left_join(wide, by = "GEOID")
  sf::st_write(spatial, file.path(config$analytic_dir, paste0(tag, "_rent.gpkg")),
               delete_dsn = TRUE, quiet = TRUE)
  data.frame(acs_end_year = config$year, geography = kind, areas = nrow(wide),
             missing_estimates = sum(is.na(selected$estimate)),
             missing_moes = sum(is.na(selected$moe)))
}
