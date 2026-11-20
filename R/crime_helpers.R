# Raw downloads are immutable after caching; dates/queries/checksums are recorded.
crime_get <- function(url, path, query = NULL) {
  if (file.exists(path)) return(invisible(path))
  part <- paste0(path, ".part")
  on.exit(unlink(part), add = TRUE)
  response <- httr::RETRY("GET", url, query = query, httr::timeout(180),
    httr::user_agent("ACSChicago research pipeline"), httr::write_disk(part, overwrite = TRUE),
    times = 5, pause_base = 2, pause_cap = 15, quiet = TRUE)
  httr::stop_for_status(response)
  if (!file.exists(part) || file.info(part)$size == 0) stop("Empty source response")
  if (!file.rename(part, path)) stop("Could not save ", path)
  invisible(path)
}

crime_read_csv <- function(path) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                 show_col_types = FALSE, progress = FALSE)
}

crime_validate_manifest <- function(directory) {
  path <- file.path(directory, "manifest.csv")
  if (file.exists(path)) {
    x <- crime_read_csv(path)
    stopifnot(all(file.exists(x$path)), identical(unname(tools::md5sum(x$path)), x$md5))
  }
}

crime_write_manifest <- function(directory) {
  paths <- list.files(directory, full.names = TRUE, recursive = TRUE)
  paths <- paths[!file.info(paths)$isdir & !grepl("manifest[.]csv$|[.]part$", paths)]
  readr::write_csv(data.frame(path = paths, md5 = unname(tools::md5sum(paths)),
    bytes = file.info(paths)$size, cached_at_utc = format(file.info(paths)$mtime, tz = "UTC", usetz = TRUE)),
    file.path(directory, "manifest.csv"))
}

crime_coordinates <- function(latitude, longitude, bounds) {
  lat <- suppressWarnings(as.numeric(latitude)); lon <- suppressWarnings(as.numeric(longitude))
  missing <- is.na(latitude) | is.na(longitude) | latitude == "" | longitude == ""
  status <- ifelse(missing, "missing_coordinates",
    ifelse(!is.finite(lat) | !is.finite(lon), "invalid_coordinates",
      ifelse(lat < bounds["lat_min"] | lat > bounds["lat_max"] |
             lon < bounds["lon_min"] | lon > bounds["lon_max"], "outside_regional_bounds", "usable")))
  data.frame(latitude = lat, longitude = lon, coordinate_status = status)
}

crime_iucr_map <- function(lookup) {
  stopifnot(!anyDuplicated(lookup$iucr),
    all(c("iucr", "primary_description", "secondary_description", "index_code") %in% names(lookup)))
  primary <- toupper(trimws(lookup$primary_description))
  indexed <- lookup$index_code == "I"
  # Use CPD's Index classification to exclude simple/minor-injury offenses even
  # where Illinois statutory descriptions use the word "aggravated".
  group <- rep(NA_character_, nrow(lookup))
  group[indexed & primary == "HOMICIDE" & grepl("MURDER", lookup$secondary_description)] <- "homicide"
  group[indexed & primary %in% c("CRIMINAL SEXUAL ASSAULT", "CRIM SEXUAL ASSAULT")] <- "sexual_assault"
  group[indexed & primary == "ROBBERY"] <- "robbery"
  group[indexed & primary == "ASSAULT"] <- "aggravated_assault"
  group[indexed & primary == "BATTERY"] <- "aggravated_battery"
  # These Index violent codes sit under broader CPD primary headings, so a
  # primary-type-only filter would wrongly omit child rape and ritual battery.
  group[indexed & lookup$iucr %in% c("1753", "1754")] <- "sexual_assault"
  group[indexed & lookup$iucr %in% c("0490", "0491", "0492", "0493", "0510")] <- "aggravated_battery"
  lookup$violent_group <- group
  lookup$included <- !is.na(group)
  lookup
}

crime_assign_points <- function(points, polygons) {
  # Strict interiors first. Shared-boundary ties resolve by smallest GEOID;
  # retain tie counts for an audit. Never snap unmatched points to nearby areas.
  inside <- sf::st_within(points, polygons)
  index <- vapply(inside, function(i) if (length(i)) i[order(polygons$GEOID[i])][1] else NA_integer_, integer(1))
  n_matches <- lengths(inside)
  rule <- ifelse(n_matches > 0, "interior", "unmatched")
  boundary <- which(n_matches == 0)
  if (length(boundary)) {
    touch <- sf::st_intersects(points[boundary, ], polygons)
    for (j in seq_along(boundary)) {
      i <- boundary[j]
      if (length(touch[[j]])) {
        matches <- touch[[j]]
        index[i] <- matches[order(polygons$GEOID[matches])][1]
        n_matches[i] <- length(matches)
        rule[i] <- "boundary_GEOID_tiebreak"
      }
    }
  }
  data.frame(GEOID = polygons$GEOID[index], spatial_matches = n_matches, assignment_rule = rule)
}
