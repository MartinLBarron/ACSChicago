# Standalone ACS pipeline: Rscript R/download_acs_rent.R
source("R/acs_config.R")
source("R/acs_helpers.R")
require_acs_packages()
if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY in .Renviron.")
options(timeout = max(600, getOption("timeout")))
run_acs_period <- function(config) {
  for (directory in config[c("raw_dir", "shape_dir", "analytic_dir")]) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  }
  city_path <- "data/raw_data/chicago_city.geojson"
  cache_download("https://data.cityofchicago.org/resource/qqq8-j68g.geojson?$limit=50000", city_path)
  city <- sf::st_read(city_path, quiet = TRUE) |>
    sf::st_make_valid() |>
    sf::st_transform(config$crs)
  city_mask <- sf::st_union(sf::st_geometry(city))

  # Check previously recorded inputs before using their cached bytes.
  manifest_path <- file.path(config$raw_dir, "manifest.csv")
  if (file.exists(manifest_path)) {
    previous <- readr::read_csv(manifest_path, show_col_types = FALSE)
    stopifnot(all(file.exists(previous$path)),
              all(unname(tools::md5sum(previous$path)) == previous$md5))
  }
  reports <- lapply(c("tract", "block group"), function(kind) {
    message("Preparing ACS ", config$year - 4L, "–", config$year, " ", kind, " rent data")
    boundaries <- select_chicago_geography(kind, config, city_mask)
    build_rent_dataset(kind, boundaries, config)
  })
  report <- dplyr::bind_rows(reports)
  readr::write_csv(report, file.path(config$analytic_dir, "validation_summary.csv"))
  inputs <- c(city_path, list.files(config$raw_dir, full.names = TRUE,
                                  pattern = "\\.(zip|json|rds)$"))
  manifest <- data.frame(path = inputs, md5 = unname(tools::md5sum(inputs)),
                         cached_at_utc = format(file.info(inputs)$mtime, tz = "UTC", usetz = TRUE))
  readr::write_csv(manifest, manifest_path)
  readr::write_csv(data.frame(package = c("sf", "tidycensus", "dplyr", "tidyr", "readr", "httr", "jsonlite"),
    version = vapply(c("sf", "tidycensus", "dplyr", "tidyr", "readr", "httr", "jsonlite"),
                     function(p) as.character(utils::packageVersion(p)), character(1))),
    file.path(config$analytic_dir, "package_versions.csv"))
  message("ACS ", config$year, " pipeline complete; validation summary saved.")
}
for (year in acs_years) run_acs_period(acs_config_for_year(year))
source("R/combine_acs_periods.R")
