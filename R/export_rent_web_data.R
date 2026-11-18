# Export each ACS period with its matching geometry for the self-contained website.
source("R/acs_config.R")
source("R/housing_config.R")
if (!requireNamespace("sf", quietly = TRUE)) stop("Install sf first.")
dir.create("data/web", recursive = TRUE, showWarnings = FALSE)
site_data_dir <- file.path("html", "data", "web")
dir.create(site_data_dir, recursive = TRUE, showWarnings = FALSE)
for (year in acs_years) {
  config <- acs_config_for_year(year)
  for (kind in c("tract", "block_group", "puma")) {
    input <- file.path(config$analytic_dir, paste0(kind, "_housing.gpkg"))
    if (!file.exists(input)) stop("Run the core and supplementary ACS pipeline stages first.")
    x <- sf::st_read(input, quiet = TRUE) |> sf::st_transform(4326)
    if (kind == "puma") {
      boundaries <- sf::st_read(sprintf("data/shape/puma_%d/chicago_pumas.gpkg", year), quiet = TRUE)
      stopifnot(setequal(x$GEOID, boundaries$GEOID))
      for (field in c("puma_code", "puma_definition_year")) {
        x[[field]] <- boundaries[[field]][match(x$GEOID, boundaries$GEOID)]
      }
    }
    measures <- housing_display_variables(config$variables)
    suffixes <- c("estimate", "moe", "estimate_raw", "moe_raw", "estimate_annotation", "moe_annotation", "estimate_status", "moe_status", "moe_method", "source_status")
    fields <- c("GEOID", "NAME", "geography", "puma_code", "puma_definition_year", "acs_start_year", "acs_end_year", "period", "dollar_year", "boundary_year", "moe_confidence", "synthetic_data", as.vector(outer(measures, suffixes, paste, sep = "_")))
    x <- x[, intersect(fields, names(x))]
    output <- file.path("data/web", paste0(kind, "_rent_", year, ".geojson"))
    sf::st_write(x, output, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE,
                 layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6"))
    check <- sf::st_read(output, quiet = TRUE)
    stopifnot(nrow(check) == nrow(x), identical(check$GEOID, x$GEOID))
    for (measure in measures) {
      for (suffix in c("estimate", "moe")) {
        column <- paste0(measure, "_", suffix)
        if (all(is.na(x[[column]]))) {
          # GeoJSON has no numeric type information when every value is null.
          stopifnot(column %in% names(check), length(check[[column]]) == nrow(x),
                    all(is.na(check[[column]])))
        } else {
          stopifnot(isTRUE(all.equal(check[[column]], x[[column]])))
        }
      }
    }
    site_output <- file.path(site_data_dir, basename(output))
    stopifnot(file.copy(output, site_output, overwrite = TRUE),
              unname(tools::md5sum(output)) == unname(tools::md5sum(site_output)))
    message("Exported ", year, " ", kind, ": ", nrow(x), " areas with estimates and MOEs")
  }
}
