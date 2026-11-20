# Approved first crime study: raw row counts, no rates/transforms or nearby events.
source("R/bg_model_config.R")
crime_config <- list(
  years = 2020:2024, seed = bg_model_config$seed, crs = acs_config$crs,
  resource = "https://data.cityofchicago.org/resource/ijzp-q8t2",
  lookup = "https://data.cityofchicago.org/resource/c7ck-438e.json",
  metadata = "https://data.cityofchicago.org/api/views/ijzp-q8t2.json",
  raw_dir = "data/raw_data/cpd_crime_2020_2024_v1",
  analytic_dir = "data/analytic/crime_2020_2024",
  output_dir = "output/models/block_group_crime_2024",
  page_size = 50000L,
  fields = c("id", "date", "iucr", "primary_type", "description", "fbi_code",
    "arrest", "domestic", "latitude", "longitude", "community_area", "year", "updated_on"),
  # Coarse regional validity screen, not a substitute for polygon matching.
  coordinate_bounds = c(lon_min = -88.1, lon_max = -87.3, lat_min = 41.5, lat_max = 42.1)
)
crime_formula <- stats::reformulate(c(bg_predictors, "community_id", "violent_crime_count"), "log_rent")
