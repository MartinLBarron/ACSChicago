# Run from the project root: Rscript R/download_boundaries.R
# Dependency: install.packages("sf")
if (!requireNamespace("sf", quietly = TRUE)) {
  stop("Install the spatial dependency first: install.packages('sf')")
}
if (!dir.exists("R") || !file.exists("R/download_boundaries.R")) {
  stop("Run this script from the ACSChicago project root.")
}

tiger_year <- 2025L
analysis_crs <- 26916L # NAD83 / UTM zone 16N; area calculations in square meters.
raw_dir <- file.path("data", "raw_data")
shape_dir <- file.path("data", "shape")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(shape_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = max(600, getOption("timeout")))

sources <- data.frame(
  name = c("chicago_city", "chicago_community_areas", "illinois_block_groups", "illinois_tracts"),
  url = c(
    "https://data.cityofchicago.org/resource/qqq8-j68g.geojson?$limit=50000",
    "https://data.cityofchicago.org/resource/igwz-8jzy.geojson?$limit=50000",
    sprintf("https://www2.census.gov/geo/tiger/TIGER%d/BG/tl_%d_17_bg.zip",
            tiger_year, tiger_year),
    sprintf("https://www2.census.gov/geo/tiger/TIGER%d/TRACT/tl_%d_17_tract.zip",
            tiger_year, tiger_year)
  ),
  filename = c("chicago_city.geojson", "chicago_community_areas.geojson",
               sprintf("tl_%d_17_bg.zip", tiger_year),
               sprintf("tl_%d_17_tract.zip", tiger_year))
)

# Never overwrite cached source bytes. Delete a cached file explicitly to refresh it.
for (i in seq_len(nrow(sources))) {
  destination <- file.path(raw_dir, sources$filename[i])
  if (!file.exists(destination)) {
    temporary <- paste0(destination, ".part")
    message("Downloading ", sources$name[i])
    tryCatch({
      status <- utils::download.file(sources$url[i], temporary, mode = "wb")
      if (status != 0 || file.info(temporary)$size == 0) stop("Empty/failed download")
      if (!file.rename(temporary, destination)) stop("Cannot finalize download")
    }, error = function(e) {
      unlink(temporary)
      stop("Download failed for ", sources$name[i], ": ", conditionMessage(e))
    })
  }
}

sources$md5 <- unname(tools::md5sum(file.path(raw_dir, sources$filename)))
sources$cached_at_utc <- format(
  file.info(file.path(raw_dir, sources$filename))$mtime,
  tz = "UTC", usetz = TRUE
)
manifest_path <- file.path(raw_dir, "source_manifest.csv")
if (file.exists(manifest_path)) {
  previous <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  matched <- match(sources$filename, previous$filename)
  changed <- !is.na(matched) & sources$md5 != previous$md5[matched]
  if (any(changed)) stop("Cached inputs changed. Archive/remove the old manifest to accept a refresh.")
}
utils::write.csv(sources, manifest_path, row.names = FALSE)

read_boundary <- function(path) {
  x <- sf::st_read(path, quiet = TRUE)
  if (is.na(sf::st_crs(x))) stop("Missing source CRS: ", path)
  x <- sf::st_transform(sf::st_make_valid(x), analysis_crs)
  if (any(sf::st_is_empty(x)) || !all(sf::st_is_valid(x))) {
    stop("Invalid or empty geometry: ", path)
  }
  x
}
city <- read_boundary(file.path(raw_dir, sources$filename[1]))
community_areas <- read_boundary(file.path(raw_dir, sources$filename[2]))
stopifnot(nrow(city) >= 1, nrow(community_areas) == 77L,
          "area_numbe" %in% names(community_areas),
          length(unique(community_areas$area_numbe)) == 77L)

# Extract the authoritative Illinois TIGER/Line archive beneath data/shape.
tiger_dir <- file.path(shape_dir, sprintf("tiger_%d_illinois", tiger_year))
dir.create(tiger_dir, recursive = TRUE, showWarnings = FALSE)
utils::unzip(file.path(raw_dir, sources$filename[3]), exdir = tiger_dir)
bg <- read_boundary(file.path(tiger_dir, sprintf("tl_%d_17_bg.shp", tiger_year)))
stopifnot("GEOID" %in% names(bg), !anyDuplicated(bg$GEOID),
          all(nchar(bg$GEOID) == 12L))

# Boundary contact alone is insufficient: require positive area overlap.
city_mask <- sf::st_union(sf::st_geometry(city))
candidates <- bg[lengths(sf::st_intersects(bg, city_mask)) > 0L, ]
overlap <- suppressWarnings(sf::st_intersection(candidates, city_mask))
overlap <- suppressWarnings(sf::st_collection_extract(overlap, "POLYGON"))
overlap <- overlap[as.numeric(sf::st_area(overlap)) > 0, ]
stopifnot(nrow(overlap) > 0L)
chicago_bg <- bg[bg$GEOID %in% overlap$GEOID, ]
chicago_bg <- chicago_bg[order(chicago_bg$GEOID), ]

write_shape <- function(x, name) {
  # DBF numeric field widths can truncate large Census land/water areas.
  for (field in intersect(c("ALAND", "AWATER"), names(x))) {
    x[[field]] <- format(x[[field]], scientific = FALSE, trim = TRUE)
  }
  directory <- file.path(shape_dir, name)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(directory, paste0(name, ".shp"))
  sf::st_write(x, path, delete_layer = TRUE, quiet = TRUE,
               layer_options = "ENCODING=UTF-8")
  check <- sf::st_read(path, quiet = TRUE)
  stopifnot(nrow(check) == nrow(x), !is.na(sf::st_crs(check)),
            all(sf::st_is_valid(check)), !any(sf::st_is_empty(check)))
}
# Tracts use the same positive-area Chicago selection as block groups.
utils::unzip(file.path(raw_dir, sources$filename[4]), exdir = tiger_dir)
tracts <- read_boundary(file.path(tiger_dir, sprintf("tl_%d_17_tract.shp", tiger_year)))
stopifnot("GEOID" %in% names(tracts), !anyDuplicated(tracts$GEOID),
          all(nchar(tracts$GEOID) == 11L))
tract_candidates <- tracts[lengths(sf::st_intersects(tracts, city_mask)) > 0L, ]
tract_overlap <- suppressWarnings(sf::st_intersection(tract_candidates, city_mask))
tract_overlap <- suppressWarnings(sf::st_collection_extract(tract_overlap, "POLYGON"))
tract_overlap <- tract_overlap[as.numeric(sf::st_area(tract_overlap)) > 0, ]
stopifnot(nrow(tract_overlap) > 0L)
chicago_tracts <- tracts[tracts$GEOID %in% tract_overlap$GEOID, ]
chicago_tracts <- chicago_tracts[order(chicago_tracts$GEOID), ]
write_shape(chicago_tracts, sprintf("chicago_tracts_%d", tiger_year))
write_shape(tract_overlap, sprintf("chicago_tracts_%d_clipped", tiger_year))
write_shape(city, "chicago_city")
write_shape(community_areas, "chicago_community_areas")
write_shape(chicago_bg, sprintf("chicago_block_groups_%d", tiger_year))
write_shape(overlap, sprintf("chicago_block_groups_%d_clipped", tiger_year))
capture.output(sessionInfo(), sf::sf_extSoftVersion(),
               file = file.path(shape_dir, "session_info.txt"))
message("Complete: ", nrow(community_areas), " community areas; ",
        nrow(chicago_bg), " block groups; ", nrow(chicago_tracts),
        " tracts with positive city overlap.")
