# Download authoritative Illinois TIGER/Line PUMAs for each map period.
# Run from the project root. No ACS observations are collected in this stage.
source("R/acs_config.R")
source("R/acs_helpers.R")
if (!requireNamespace("sf", quietly = TRUE)) stop("Install sf first.")
options(timeout = max(600, getOption("timeout")))
for (year in acs_years) {
  definition_year <- if (year < 2022L) 2010L else 2020L
  suffix <- if (definition_year == 2010L) "10" else "20"
  folder <- if (definition_year == 2010L) "PUMA" else "PUMA20"
  stem <- sprintf("tl_%d_17_puma%s", year, suffix)
  raw_dir <- file.path("data", "raw_data", paste0("puma_", year))
  shape_dir <- file.path("data", "shape", paste0("puma_", year))
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(shape_dir, recursive = TRUE, showWarnings = FALSE)
  archive <- file.path(raw_dir, paste0(stem, ".zip"))
  url <- sprintf("https://www2.census.gov/geo/tiger/TIGER%d/%s/%s.zip", year, folder, stem)
  cache_download(url, archive)
  # Use city limits from the SAME TIGER release to avoid false sliver overlaps
  # between the City portal boundary and TIGER PUMA boundary linework.
  place_stem <- sprintf("tl_%d_17_place", year)
  city_archive <- file.path(raw_dir, paste0(place_stem, ".zip"))
  city_url <- sprintf("https://www2.census.gov/geo/tiger/TIGER%d/PLACE/%s.zip", year, place_stem)
  cache_download(city_url, city_archive)
  record <- data.frame(year = year, definition_year = definition_year, url = url,
    path = archive, md5 = unname(tools::md5sum(archive)))
  record <- rbind(record, data.frame(year = year, definition_year = NA_integer_,
    url = city_url, path = city_archive, md5 = unname(tools::md5sum(city_archive))))
  manifest_path <- file.path(raw_dir, "manifest.csv")
  if (file.exists(manifest_path)) {
    previous <- utils::read.csv(manifest_path)
    matched <- match(previous$path, record$path)
    stopifnot(!anyNA(matched), identical(previous$md5, record$md5[matched]))
  }
  utils::write.csv(record, manifest_path, row.names = FALSE)
  utils::unzip(archive, exdir = shape_dir)
  place_dir <- file.path(shape_dir, "places")
  dir.create(place_dir, recursive = TRUE, showWarnings = FALSE)
  utils::unzip(city_archive, exdir = place_dir)
  places <- sf::st_read(file.path(place_dir, paste0(place_stem, ".shp")), quiet = TRUE)
  city <- places[places$GEOID == "1714000", ]
  stopifnot(nrow(city) == 1L, all(sf::st_is_valid(city)))
  x <- sf::st_read(file.path(shape_dir, paste0(stem, ".shp")), quiet = TRUE)
  stopifnot(all(sf::st_is_valid(x)), sf::st_crs(x) == sf::st_crs(city))
  # Normalize attribute names across the two decennial definitions.
  field <- function(base) {
    name <- intersect(c(paste0(base, suffix), base), names(x))
    if (!length(name)) stop("Missing TIGER attribute: ", base)
    x[[name[1]]]
  }
  x <- sf::st_sf(GEOID = as.character(field("GEOID")), NAME = field("NAMELSAD"),
    puma_code = as.character(field("PUMACE")), boundary_year = year,
    puma_definition_year = definition_year, geometry = sf::st_geometry(x))
  stopifnot(!anyDuplicated(x$GEOID), all(nchar(x$GEOID) == 7L))
  # Test polygon INTERIORS in their native, shared TIGER coordinates. This
  # excludes edge/point contact and avoids creating slivers by reprojection.
  # Dropping CRS only for this GEOS topology test leaves output CRS unchanged.
  native_pumas <- sf::st_set_crs(sf::st_geometry(x), NA)
  native_city <- sf::st_set_crs(sf::st_geometry(city), NA)
  keep <- lengths(sf::st_relate(native_pumas, native_city, pattern = "2********")) > 0L
  exclusions <- acs_config$excluded_puma_geoids[[as.character(definition_year)]]
  stopifnot(length(exclusions) == 5L, all(exclusions %in% x$GEOID[keep]))
  explicitly_excluded <- x$GEOID %in% exclusions
  audit <- sf::st_drop_geometry(x)
  audit$city_overlap <- keep
  audit$excluded_place <- names(exclusions)[match(x$GEOID, exclusions)]
  audit$retained <- keep & !explicitly_excluded
  utils::write.csv(audit, file.path(shape_dir, "puma_selection.csv"), row.names = FALSE)
  keep <- keep & !explicitly_excluded
  # Retain whole PUMAs with genuine positive city overlap, not clipped pieces.
  selected <- x[keep, ] |> sf::st_transform(acs_config$crs)
  selected <- selected[order(selected$GEOID), ]
  stopifnot(nrow(selected) > 0L, all(sf::st_is_valid(selected)),
    !any(sf::st_is_empty(selected)), !anyDuplicated(selected$GEOID))
  sf::st_write(selected, file.path(shape_dir, "chicago_pumas.gpkg"),
    delete_dsn = TRUE, quiet = TRUE)
  web <- sf::st_transform(selected, 4326)
  for (directory in c("data/web", "html/data/web")) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    output <- file.path(directory, sprintf("chicago_pumas_%d.geojson", year))
    sf::st_write(web, output, driver = "GeoJSON", delete_dsn = TRUE,
      layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=6"), quiet = TRUE)
    check <- sf::st_read(output, quiet = TRUE)
    stopifnot(identical(check$GEOID, selected$GEOID), all(sf::st_is_valid(check)))
  }
  message("PUMAs ", year, " (", definition_year, " definition): ", nrow(selected), " whole areas")
}
