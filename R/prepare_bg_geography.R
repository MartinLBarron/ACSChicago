# Assign whole BGs to their largest area-overlap community; preserve map selection.
source("R/bg_model_config.R")
cfsource("R/bg_geography_helpers.R")
assignment <- bg_geographic_assignment(cfg, acs_config$crs)
audit <- assignment$audit
g <- assignment$geometry
communities <- assignment$communities
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
