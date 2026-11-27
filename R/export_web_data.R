# Run from the project root after R/download_boundaries.R.
if (!requireNamespace("sf", quietly = TRUE)) stop("Install sf first.")
output_dir <- file.path("data", "web")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
site_data_dir <- file.path("html", "data", "web")
dir.create(site_data_dir, recursive = TRUE, showWarnings = FALSE)
layers <- c("chicago_city", "chicago_community_areas", "chicago_zip_codes", "chicago_block_groups_2025",
            "chicago_tracts_2025")
for (layer in layers) {
  input <- file.path("data", "shape", layer, paste0(layer, ".shp"))
  if (!file.exists(input)) stop("Missing ", input, "; run R/download_boundaries.R first.")
  x <- sf::st_read(input, quiet = TRUE) |> sf::st_transform(4326)
  output <- file.path(output_dir, paste0(layer, ".geojson"))
  sf::st_write(x, output, driver = "GeoJSON", delete_dsn = TRUE,
               layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6"), quiet = TRUE)
  check <- sf::st_read(output, quiet = TRUE)
  stopifnot(nrow(x) == nrow(check))
  if (layer %in% c("chicago_city", "chicago_community_areas", "chicago_zip_codes")) {
    site_output <- file.path(site_data_dir, basename(output))
    stopifnot(file.copy(output, site_output, overwrite = TRUE),
              unname(tools::md5sum(output)) == unname(tools::md5sum(site_output)))
  }
  message(layer, ": ", nrow(check), " features")
}
