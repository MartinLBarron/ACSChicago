# Export ACS estimates with their matching 2024 geometry for the local web map.
source("R/acs_config.R")
if (!requireNamespace("sf", quietly = TRUE)) stop("Install sf first.")
dir.create("data/web", recursive = TRUE, showWarnings = FALSE)
site_data_dir <- file.path("html", "data", "web")
dir.create(site_data_dir, recursive = TRUE, showWarnings = FALSE)
for (kind in c("tract", "block_group")) {
  input <- file.path(acs_config$analytic_dir, paste0(kind, "_rent.gpkg"))
  if (!file.exists(input)) stop("Run Rscript R/download_acs_rent.R first.")
  x <- sf::st_read(input, quiet = TRUE) |> sf::st_transform(4326)
  output <- file.path("data/web", paste0(kind, "_rent_2024.geojson"))
  sf::st_write(x, output, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE,
               layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6"))
  check <- sf::st_read(output, quiet = TRUE)
  stopifnot(nrow(check) == nrow(x), identical(check$GEOID, x$GEOID))
  for (measure in names(acs_config$variables)) {
    for (suffix in c("estimate", "moe")) {
      column <- paste0(measure, "_", suffix)
      stopifnot(isTRUE(all.equal(check[[column]], x[[column]])))
    }
  }
  site_output <- file.path(site_data_dir, basename(output))
  stopifnot(file.copy(output, site_output, overwrite = TRUE),
            unname(tools::md5sum(output)) == unname(tools::md5sum(site_output)))
  message("Exported ", kind, ": ", nrow(x), " areas with estimates and MOEs")
}
