source("R/crime_config.R")
source("R/crime_helpers.R")
cfg <- crime_config
crime_validate_manifest(cfg$raw_dir)
dir.create(cfg$analytic_dir, recursive = TRUE, showWarnings = FALSE)
requests <- crime_read_csv(file.path(cfg$raw_dir, "requests.csv"))
source_counts <- jsonlite::read_json(file.path(cfg$raw_dir, "source_year_counts.json"), simplifyVector = TRUE)
lookup <- crime_iucr_map(jsonlite::read_json(file.path(cfg$raw_dir, "iucr_lookup.json"), simplifyVector = TRUE))
readr::write_csv(lookup, file.path(cfg$analytic_dir, "iucr_definition.csv"))
rows <- dplyr::bind_rows(lapply(requests$path, crime_read_csv))
stopifnot(!anyDuplicated(rows$id), nrow(rows) == sum(as.integer(source_counts$rows)))
rows$occurrence_year <- as.integer(substr(rows$date, 1, 4))
stopifnot(all(rows$occurrence_year %in% cfg$years))
rows <- dplyr::left_join(rows, lookup[c("iucr", "violent_group", "included")], by = "iucr")
unknown <- rows |> dplyr::filter(is.na(included)) |>
  dplyr::count(iucr, primary_type, description, fbi_code, name = "rows")
readr::write_csv(unknown, file.path(cfg$analytic_dir, "unknown_iucr.csv"))
relevant <- c("HOMICIDE", "CRIM SEXUAL ASSAULT", "CRIMINAL SEXUAL ASSAULT", "ROBBERY", "ASSAULT", "BATTERY")
if (any(unknown$primary_type %in% relevant)) stop("Unmapped potentially violent IUCR codes require review; see unknown_iucr.csv")
rows$included[is.na(rows$included)] <- FALSE
fbi_violent <- rows$fbi_code %in% c("01A", "02", "03", "04A", "04B")
fbi_mismatch <- rows[fbi_violent != rows$included, ] |>
  dplyr::count(iucr, primary_type, description, fbi_code, included, name = "rows")
readr::write_csv(fbi_mismatch, file.path(cfg$analytic_dir, "fbi_definition_crosscheck.csv"))
if (nrow(fbi_mismatch)) stop("IUCR mapping and recorded FBI violent categories disagree; review fbi_definition_crosscheck.csv")
readr::write_csv(rows |> dplyr::count(occurrence_year, primary_type, included, name = "rows"),
  file.path(cfg$analytic_dir, "offense_selection_audit.csv"))
violent <- rows[rows$included, ]
rm(rows)
coordinates <- crime_coordinates(violent$latitude, violent$longitude, cfg$coordinate_bounds)
violent$latitude <- coordinates$latitude
violent$longitude <- coordinates$longitude
violent$coordinate_status <- coordinates$coordinate_status
violent$GEOID <- NA_character_
violent$spatial_matches <- 0L
violent$assignment_rule <- "no_usable_coordinates"
violent$point_inside_city <- NA
g <- sf::st_read(file.path(bg_model_config$analytic_dir, "geographic_assignment.gpkg"), quiet = TRUE)
g <- sf::st_make_valid(g) |> sf::st_transform(cfg$crs)
stopifnot(!anyDuplicated(g$GEOID))
valid <- which(violent$coordinate_status == "usable")
points <- sf::st_as_sf(violent[valid, c("id", "latitude", "longitude")], coords = c("longitude", "latitude"), crs = 4326) |>
  sf::st_transform(cfg$crs)
assigned <- crime_assign_points(points, g)
violent[valid, c("GEOID", "spatial_matches", "assignment_rule")] <- assigned
city <- sf::st_read(bg_model_config$city_path, quiet = TRUE) |> sf::st_make_valid() |> sf::st_transform(cfg$crs)
violent$point_inside_city[valid] <- lengths(sf::st_intersects(points, sf::st_union(sf::st_geometry(city)))) > 0
violent$assignment_status <- ifelse(violent$coordinate_status != "usable", violent$coordinate_status,
  ifelse(is.na(violent$GEOID), "outside_selected_block_groups", "assigned"))
base <- readRDS(file.path(bg_model_config$analytic_dir, "model_sample.rds"))
violent$in_model_sample <- !is.na(violent$GEOID) & violent$GEOID %in% base$GEOID
matched <- violent[!is.na(violent$GEOID), ]
year_counts <- matched |> dplyr::count(GEOID, occurrence_year, violent_group, name = "recorded_rows")
grid <- tidyr::expand_grid(GEOID = g$GEOID, occurrence_year = cfg$years,
  violent_group = c("homicide", "sexual_assault", "robbery", "aggravated_assault", "aggravated_battery")) |>
  dplyr::left_join(year_counts, by = c("GEOID", "occurrence_year", "violent_group")) |>
  dplyr::mutate(recorded_rows = dplyr::coalesce(recorded_rows, 0L))
totals <- grid |> dplyr::group_by(GEOID) |>
  dplyr::summarise(violent_crime_count = sum(recorded_rows), .groups = "drop")
data <- dplyr::left_join(base, totals, by = "GEOID")
stopifnot(identical(data$GEOID, base$GEOID), !anyNA(data$violent_crime_count))
coverage <- violent |> dplyr::group_by(occurrence_year, violent_group) |>
  dplyr::summarise(violent_rows = dplyr::n(), usable_coordinates = sum(coordinate_status == "usable"),
    assigned_to_mapped_BG = sum(!is.na(GEOID)), assigned_to_model_BG = sum(in_model_sample),
    coordinate_coverage = mean(coordinate_status == "usable"), .groups = "drop")
community_coverage <- violent |> dplyr::group_by(community_area) |>
  dplyr::summarise(violent_rows = dplyr::n(), missing_or_invalid_coordinates = sum(coordinate_status != "usable"),
    coordinate_coverage = mean(coordinate_status == "usable"), .groups = "drop")
status <- violent |> dplyr::count(assignment_status, name = "rows")
readr::write_csv(coverage, file.path(cfg$analytic_dir, "coverage_by_year_offense.csv"))
readr::write_csv(community_coverage, file.path(cfg$analytic_dir, "coverage_by_reported_community.csv"))
readr::write_csv(status, file.path(cfg$analytic_dir, "assignment_status.csv"))
readr::write_csv(grid, file.path(cfg$analytic_dir, "counts_by_year_offense.csv"))
readr::write_csv(totals, file.path(cfg$analytic_dir, "block_group_counts.csv"))
# The point-level audit stays local. No case narrative, addresses or victim details.
saveRDS(violent, file.path(cfg$analytic_dir, "violent_record_assignment.rds"))
saveRDS(data, file.path(cfg$analytic_dir, "model_sample.rds"))
snapshot <- jsonlite::read_json(file.path(cfg$raw_dir, "snapshot.json"), simplifyVector = TRUE)
audit <- list(source_rows = sum(as.integer(source_counts$rows)), violent_rows = nrow(violent),
  mapped_rows = nrow(matched), model_rows = sum(violent$in_model_sample),
  missing_or_invalid_coordinates = sum(violent$coordinate_status != "usable"),
  unmatched_usable_coordinates = sum(violent$coordinate_status == "usable" & is.na(violent$GEOID)),
  multiple_polygon_matches = sum(violent$spatial_matches > 1),
  boundary_assignments = sum(violent$assignment_rule == "boundary_GEOID_tiebreak"),
  assigned_outside_city_mask = sum(!is.na(violent$GEOID) & !violent$point_inside_city, na.rm = TRUE),
  model_BGs = nrow(data), zero_assigned_BGs = sum(data$violent_crime_count == 0),
  unknown_iucr_rows = sum(unknown$rows), snapshot = snapshot,
  interpretation = "Zero means zero assigned geocoded rows, not verified absence of violence. Missing points cannot be allocated to BGs.")
saveRDS(audit, file.path(cfg$analytic_dir, "geographic_audit.rds"))
jsonlite::write_json(audit, file.path(cfg$analytic_dir, "geographic_audit.json"), pretty = TRUE, auto_unbox = TRUE)
readr::write_csv(data.frame(variable = "violent_crime_count", unit = "recorded rows over 2020–2024",
  definition = "Untransformed sum of spatially assigned included CPD rows; no denominator, annualization or case deduplication",
  uncertainty = "Administrative count; no ACS MOE. Reporting, missing-location and classification errors remain."),
  file.path(cfg$analytic_dir, "crime_codebook.csv"))
message("Prepared crime exposure: ", nrow(violent), " violent rows; ", sum(violent$in_model_sample),
  " assigned to the ", nrow(data), " unchanged modeling areas")
