# Validate actual PUMA outputs after all ACS collection/derivation/export stages.
source("R/acs_config.R")
source("R/housing_config.R")
source("R/acs_helpers.R")
for (year in acs_years) {
  config <- acs_config_for_year(year)
  boundaries <- sf::st_read(sprintf("data/shape/puma_%d/chicago_pumas.gpkg", year), quiet = TRUE)
  core <- readRDS(file.path(config$analytic_dir, "puma_rent.rds"))
  housing <- readRDS(file.path(config$analytic_dir, "puma_housing.rds"))
  definition <- if (year < 2022L) "2010" else "2020"
  stopifnot(nrow(housing) == 18L, setequal(housing$GEOID, boundaries$GEOID),
    !any(housing$GEOID %in% config$excluded_puma_geoids[[definition]]),
    all(housing$geography == "puma"), all(housing$acs_end_year == year))
  for (field in names(core)) stopifnot(identical(core[[field]], housing[[field]]))
  # Direct medians/counts must equal the original PUMA API response, not tract averages.
  api <- read_puma_api(config)
  matched <- match(housing$GEOID, api$GEOID)
  for (variable in names(config$variables)) for (suffix in c("estimate", "moe")) {
    code <- paste0(config$variables[[variable]], if (suffix == "estimate") "E" else "M")
    expected <- as.numeric(api[[code]][matched])
    expected[expected < 0] <- NA_real_
    stopifnot(isTRUE(all.equal(housing[[paste0(variable, "_", suffix)]], expected)))
  }
  expected_share <- 100 * housing$tenure_renter_units_estimate / housing$occupied_units_estimate
  stopifnot(isTRUE(all.equal(housing$renter_occupied_pct_estimate, expected_share)))
  for (directory in c("data/web", "html/data/web")) {
    web <- sf::st_read(file.path(directory, sprintf("puma_rent_%d.geojson", year)), quiet = TRUE)
    stopifnot(identical(web$GEOID, housing$GEOID), all(web$puma_definition_year == as.integer(definition)))
    for (variable in housing_display_variables(config$variables)) for (suffix in c("estimate", "moe")) {
      field <- paste0(variable, "_", suffix)
      stopifnot(isTRUE(all.equal(web[[field]], housing[[field]])))
    }
  }
  message("Verified PUMA ", year, ": membership, published values/MOEs, derived share, and exports")
}
combined <- readRDS("data/analytic/acs_combined/puma_housing.rds")
stopifnot(nrow(combined) == 54L, !anyDuplicated(combined[c("GEOID", "acs_end_year")]))
