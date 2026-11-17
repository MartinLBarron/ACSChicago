# Shared settings for the rent analysis. Run scripts from the project root.
.libPaths(c(normalizePath(".R-library", mustWork = FALSE), .libPaths()))
acs_config <- list(
  year = 2024L,
  survey = "acs5",
  state = "17",
  chicago_place = "14000",
  crs = 26916L,
  # Cook County's Lake Michigan water-only tract and its block group.
  excluded_tract_geoids = "17031990000",
  variables = c(median_contract_rent = "B25058_001",
                median_gross_rent = "B25064_001",
                cash_rent_units = "B25063_002",
                renter_occupied_units = "B25003_003"),
  raw_dir = "data/raw_data/acs_2024",
  shape_dir = "data/shape/acs_2024",
  analytic_dir = "data/analytic/acs_2024"
)
# These are official public observations, not synthetic data.
SYNTHETIC_DATA <- FALSE

# Non-overlapping five-year releases supported by the current tidycensus API.
acs_years <- c(2014L, 2019L, 2024L)
acs_config_for_year <- function(year) {
  stopifnot(length(year) == 1L, year %in% acs_years)
  config <- acs_config
  config$year <- as.integer(year)
  config$raw_dir <- file.path("data", "raw_data", paste0("acs_", year))
  config$shape_dir <- file.path("data", "shape", paste0("acs_", year))
  config$analytic_dir <- file.path("data", "analytic", paste0("acs_", year))
  config
}
