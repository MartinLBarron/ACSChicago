# Assign whole BGs to their largest area-overlap community; preserve map selection.
source("R/bg_model_config.R")
cfg <- bg_model_config
dir.create(cfg$analytic_dir, recursive = TRUE, showWarnings = FALSE)
g <- sf::st_read(cfg$shape_path, quiet = TRUE) |> sf::st_make_valid() |> sf::st_transform(acs_config$crs)
city <- sf::st_read(cfg$city_path, quiet = TRUE) |> sf::st_make_valid() |> sf::st_transform(acs_config$crs)
communities <- sf::st_read(cfg$community_path, quiet = TRUE) |> sf::st_make_valid() |> sf::st_transform(acs_config$crs)
communities$community_id <- sprintf("%02d", as.integer(communities$area_numbe))
stopifnot(nrow(communities) == 77L, !anyDuplicated(communities$community_id), !anyDuplicated(g$GEOID))
area <- as.numeric(sf::st_area(g))
city_overlap <- suppressWarnings(sf::st_intersection(g["GEOID"], sf::st_union(sf::st_geometry(city))))
city_overlap$overlap_m2 <- as.numeric(sf::st_area(city_overlap))
city_area <- sf::st_drop_geometry(city_overlap) |>
  dplyr::group_by(GEOID) |> dplyr::summarise(city_area = sum(overlap_m2), .groups = "drop")
cross <- suppressWarnings(sf::st_intersection(g["GEOID"], communities[c("community_id", "community")]))
cross$overlap_m2 <- as.numeric(sf::st_area(cross))
cross <- sf::st_drop_geometry(cross) |>
  dplyr::group_by(GEOID, community_id, community) |>
  dplyr::summarise(overlap_m2 = sum(overlap_m2), .groups = "drop") |>
  dplyr::filter(overlap_m2 > 0) |>
  dplyr::group_by(GEOID) |>
  dplyr::mutate(community_dominance = overlap_m2 / sum(overlap_m2), communities_touched = dplyr::n()) |>
  dplyr::arrange(dplyr::desc(overlap_m2), community_id, .by_group = TRUE) |>
  dplyr::slice_head(n = 1) |> dplyr::ungroup()
audit <- data.frame(GEOID = g$GEOID, polygon_area_m2 = area) |>
  dplyr::left_join(city_area, by = "GEOID") |>
  dplyr::left_join(cross, by = "GEOID") |>
  dplyr::mutate(city_fraction = pmin(1, dplyr::coalesce(city_area, 0) / polygon_area_m2),
    majority_city = city_fraction >= cfg$city_min_share,
    strict_city = city_fraction >= cfg$strict_city_share,
    unambiguous_community = community_dominance >= cfg$unambiguous_community_share)
stopifnot(all(is.finite(audit$city_fraction)), all(audit$city_fraction >= 0),
  all(is.na(audit$community_dominance) | audit$community_dominance <= 1 + 1e-8))
readr::write_csv(audit, file.path(cfg$analytic_dir, "geographic_assignment.csv"))
geometry <- dplyr::left_join(g["GEOID"], audit, by = "GEOID")
sf::st_write(geometry, file.path(cfg$analytic_dir, "geographic_assignment.gpkg"), delete_dsn = TRUE, quiet = TRUE)
saveRDS(communities[c("community_id", "community")], file.path(cfg$analytic_dir, "community_boundaries.rds"))
jsonlite::write_json(list(crs = acs_config$crs, city_min_share = cfg$city_min_share,
  assignment = "Largest polygon-area overlap; ties resolved by community code",
  area_basis = "Entire BG polygon, including water; not population or land-only weighting",
  source_paths = c(cfg$shape_path, cfg$city_path, cfg$community_path),
  source_md5 = unname(tools::md5sum(c(cfg$shape_path, cfg$city_path, cfg$community_path)))),
  file.path(cfg$analytic_dir, "geography_metadata.json"), auto_unbox = TRUE, pretty = TRUE)
message("Geography: ", nrow(g), " map BGs; ", sum(audit$majority_city),
  " majority in Chicago; ", sum(audit$majority_city & audit$unambiguous_community, na.rm = TRUE),
  " with at least 80% community dominance")
