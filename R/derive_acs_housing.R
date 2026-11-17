# Derived stage: run after download_acs_housing.R. No network access required.
source("R/acs_config.R")
source("R/housing_config.R")
source("R/housing_derivation_helpers.R")
metadata_columns <- c("GEOID", "NAME", "geography", "acs_start_year", "acs_end_year",
                      "period", "dollar_year", "boundary_year", "moe_confidence", "synthetic_data")
reports <- list()
for (year in acs_years) {
  config <- acs_config_for_year(year)
  for (tag in c("tract", "block_group", "chicago_city")) {
    path <- file.path(config$analytic_dir, paste0(tag, "_housing_source.rds"))
    if (!file.exists(path)) stop("Run Rscript R/download_acs_housing.R first.")
    x <- readRDS(path)
    validate_housing_partitions(x)
    derived <- dplyr::bind_rows(lapply(names(housing_derivations), function(variable) {
      definition <- housing_derivations[[variable]]
      values <- derive_housing_percentage(x, definition)
      dplyr::bind_cols(x[metadata_columns], data.frame(
        variable = variable, unit = "percent", derived = TRUE,
        numerator_components = paste(definition$numerator, collapse = " + "),
        denominator_components = paste(definition$denominator, collapse = " + ")
      )[rep(1L, nrow(x)), ], values)
    })) |>
      dplyr::arrange(GEOID, variable)
    stopifnot(nrow(derived) == nrow(x) * length(housing_derivations),
              !anyDuplicated(derived[c("GEOID", "variable")]),
              all(is.na(derived$estimate) | (derived$estimate >= 0 & derived$estimate <= 100)),
              all(is.na(derived$moe) | (is.finite(derived$moe) & derived$moe >= 0)))
    derived_wide <- derived |>
      tidyr::pivot_wider(id_cols = dplyr::all_of(metadata_columns), names_from = variable,
        values_from = c(estimate, moe, estimate_status, moe_status, moe_method),
        names_glue = "{variable}_{.value}")
    core <- readRDS(file.path(config$analytic_dir, paste0(tag, "_rent.rds")))
    stopifnot(setequal(core$GEOID, x$GEOID), !anyDuplicated(x$GEOID))
    # Preserve core estimates and source components, then add derived percentages.
    extended <- core |>
      dplyr::left_join(x[c("GEOID", setdiff(names(x), metadata_columns))], by = "GEOID") |>
      dplyr::left_join(derived_wide[c("GEOID", setdiff(names(derived_wide), metadata_columns))], by = "GEOID")
    for (name in names(core)) stopifnot(identical(extended[[name]], core[[name]]))
    for (pair in list(list(name = "housing", value = extended),
                      list(name = "housing_derived_long", value = derived))) {
      stem <- paste0(tag, "_", pair$name)
      readr::write_csv(pair$value, file.path(config$analytic_dir, paste0(stem, ".csv")))
      saveRDS(pair$value, file.path(config$analytic_dir, paste0(stem, ".rds")))
    }
    if (tag != "chicago_city") {
      geometry <- sf::st_read(file.path(config$analytic_dir, paste0(tag, "_rent.gpkg")), quiet = TRUE)["GEOID"]
      spatial <- dplyr::left_join(geometry, extended, by = "GEOID")
      sf::st_write(spatial, file.path(config$analytic_dir, paste0(tag, "_housing.gpkg")),
                   delete_dsn = TRUE, quiet = TRUE)
    }
    reports[[length(reports) + 1L]] <- derived |>
      dplyr::count(acs_end_year, geography, variable, estimate_status, moe_status, name = "areas")
    message("Derived housing percentages: ", year, " ", tag, "; ", nrow(x), " areas")
  }
}

# Stack native-geography datasets, retaining year in the key.
output_dir <- "data/analytic/acs_combined"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
for (tag in c("tract", "block_group", "chicago_city")) {
  for (suffix in c("housing", "housing_source_long", "housing_derived_long")) {
    combined <- dplyr::bind_rows(lapply(acs_years, function(year) {
      readRDS(file.path(acs_config_for_year(year)$analytic_dir, paste0(tag, "_", suffix, ".rds")))
    })) |>
      dplyr::arrange(acs_end_year, GEOID)
    keys <- c("acs_end_year", "GEOID", if (suffix != "housing") "variable")
    stopifnot(!anyDuplicated(combined[keys]), setequal(combined$acs_end_year, acs_years))
    stem <- paste0(tag, "_", suffix)
    readr::write_csv(combined, file.path(output_dir, paste0(stem, ".csv")))
    saveRDS(combined, file.path(output_dir, paste0(stem, ".rds")))
  }
  if (tag != "chicago_city") for (year in acs_years) {
    x <- sf::st_read(file.path(acs_config_for_year(year)$analytic_dir, paste0(tag, "_housing.gpkg")), quiet = TRUE)
    sf::st_write(x, file.path(output_dir, paste0(tag, "_housing.gpkg")),
                 layer = paste0("acs_", year), delete_layer = TRUE, quiet = TRUE)
  }
}
readr::write_csv(dplyr::bind_rows(reports), file.path(output_dir, "housing_validation_summary.csv"))
message("Housing derivation pipeline complete.")
