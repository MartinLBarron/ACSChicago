# Stack native-geography periods; do not imply GEOIDs are stable over time.
# Can also be run independently after download_acs_rent.R has completed.
source("R/acs_config.R")
output_dir <- file.path("data", "analytic", "acs_combined")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
for (kind in c("tract", "block_group", "chicago_city")) {
  tables <- lapply(acs_years, function(year) {
    config <- acs_config_for_year(year)
    path <- file.path(config$analytic_dir, paste0(kind, "_rent.rds"))
    if (!file.exists(path)) stop("Missing period dataset: ", path)
    readRDS(path)
  })
  combined <- dplyr::bind_rows(tables) |>
    dplyr::arrange(acs_end_year, GEOID)
  stopifnot(setequal(combined$acs_end_year, acs_years),
            !anyDuplicated(combined[c("acs_end_year", "GEOID")]),
            all(combined$acs_end_year - combined$acs_start_year == 4L),
            all(combined$boundary_year == combined$acs_end_year),
            all(combined$dollar_year == combined$acs_end_year),
            !any(substr(combined$GEOID, 1, 11) %in% acs_config$excluded_tract_geoids))
  readr::write_csv(combined, file.path(output_dir, paste0(kind, "_rent.csv")))
  saveRDS(combined, file.path(output_dir, paste0(kind, "_rent.rds")))
  # Read long outputs as text first so raw codes and annotations retain their form.
  long <- dplyr::bind_rows(lapply(acs_years, function(year) {
    path <- file.path(acs_config_for_year(year)$analytic_dir, paste0(kind, "_rent_long.csv"))
    readr::read_csv(path, col_types = readr::cols(
      .default = readr::col_character(), estimate = readr::col_double(),
      moe = readr::col_double(), acs_start_year = readr::col_integer(),
      acs_end_year = readr::col_integer(), dollar_year = readr::col_integer(),
      boundary_year = readr::col_integer(), moe_confidence = readr::col_integer(),
      synthetic_data = readr::col_logical()
    ))
  })) |> dplyr::arrange(acs_end_year, GEOID, variable)
  stopifnot(nrow(long) == nrow(combined) * length(acs_config$variables),
            !anyDuplicated(long[c("acs_end_year", "GEOID", "variable")]))
  readr::write_csv(long, file.path(output_dir, paste0(kind, "_rent_long.csv")))
  saveRDS(long, file.path(output_dir, paste0(kind, "_rent_long.rds")))
  # Preserve each period's full geometry in a separate layer of one GeoPackage.
  for (year in if (kind == "chicago_city") integer(0) else acs_years) {
    input <- file.path(acs_config_for_year(year)$analytic_dir, paste0(kind, "_rent.gpkg"))
    spatial <- sf::st_read(input, quiet = TRUE)
    sf::st_write(spatial, file.path(output_dir, paste0(kind, "_rent.gpkg")),
                 layer = paste0("acs_", year), delete_layer = TRUE, quiet = TRUE)
  }
  message("Combined ", kind, ": ", nrow(combined), " area-period rows across ",
          length(acs_years), " periods")
}
reports <- dplyr::bind_rows(lapply(acs_years, function(year) {
  readr::read_csv(file.path(acs_config_for_year(year)$analytic_dir, "validation_summary.csv"),
                  show_col_types = FALSE)
}))
readr::write_csv(reports, file.path(output_dir, "validation_summary.csv"))
