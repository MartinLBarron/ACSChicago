# City-proper peers and the US benchmark; run from the project root.
# No spatial aggregation: each observation is a direct ACS geography estimate.
source("R/acs_config.R")
source("R/acs_helpers.R")
source("R/housing_config.R")
source("R/housing_derivation_helpers.R")
require_acs_packages()
if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY in .Renviron.")
options(timeout = max(600, getOption("timeout")))

comparison_places <- data.frame(
  comparison_id = c("chicago", "philadelphia", "milwaukee", "detroit", "minneapolis",
                    "boston", "houston", "new_york", "los_angeles", "miami", "united_states"),
  state = c("17", "42", "55", "26", "27", "25", "48", "36", "06", "12", NA),
  place = c("14000", "60000", "53000", "22000", "43000", "07000", "35000",
            "51000", "44000", "45000", NA),
  stringsAsFactors = FALSE
)
comparison_places$GEOID <- ifelse(is.na(comparison_places$state), "1",
  paste0(comparison_places$state, comparison_places$place))

# Cache both tidycensus values and unmodified API values/annotations.
get_comparison_variables <- function(peer, config, group) {
  kind <- if (peer$comparison_id == "united_states") "us" else "place"
  config$state <- peer$state
  config$chicago_place <- peer$place
  stem <- file.path(config$raw_dir, paste0(peer$comparison_id, "_", group))
  cache_api_response(kind, NULL, config, paste0(stem, "_api.json"))
  tidy_path <- paste0(stem, "_tidycensus.rds")
  if (!file.exists(tidy_path)) {
    args <- list(geography = kind, variables = config$variables,
      year = config$year, survey = config$survey, geometry = FALSE,
      output = "tidy", moe_level = 90, key = Sys.getenv("CENSUS_API_KEY"), show_call = FALSE)
    if (kind == "place") args$state <- peer$state
    tidy <- do.call(tidycensus::get_acs, args) |>
      dplyr::filter(GEOID == peer$GEOID)
    stopifnot(nrow(tidy) == length(config$variables))
    saveRDS(tidy, tidy_path)
  }
  prepare_acs_dataset(readRDS(tidy_path), read_api_response(paste0(stem, "_api.json")),
    peer["GEOID"], kind, config)
}

combined <- source_rows <- derived_rows <- list()
for (year in acs_years) {
  config <- acs_config_for_year(year)
  config$raw_dir <- file.path(config$raw_dir, "comparisons")
  dir.create(config$raw_dir, recursive = TRUE, showWarnings = FALSE)
  manifest_path <- file.path(config$raw_dir, "manifest.csv")
  if (file.exists(manifest_path)) {
    previous <- readr::read_csv(manifest_path, show_col_types = FALSE)
    stopifnot(all(file.exists(previous$path)),
      all(unname(tools::md5sum(previous$path)) == previous$md5))
  }
  annual <- list()
  for (i in seq_len(nrow(comparison_places))) {
    peer <- comparison_places[i, ]
    message("ACS comparisons: ", year, " ", peer$comparison_id)
    core <- get_comparison_variables(peer, config, "rent")
    burden_config <- config
    burden_config$variables <- housing_variables
    source <- get_comparison_variables(peer, burden_config, "burden")
    validate_housing_partitions(source$wide)
    derived <- derive_housing_percentage(source$wide, housing_derivations$rent_burden_50plus_pct)
    x <- dplyr::left_join(core$wide,
      source$wide[c("GEOID", setdiff(names(source$wide), names(core$wide)))], by = "GEOID")
    names(derived) <- paste0("rent_burden_50plus_pct_", names(derived))
    x <- dplyr::bind_cols(x, derived)
    x$comparison_id <- peer$comparison_id
    annual[[i]] <- x
    source_rows[[length(source_rows) + 1L]] <- dplyr::bind_rows(core$long, source$long) |>
      dplyr::mutate(comparison_id = peer$comparison_id)
    derived_rows[[length(derived_rows) + 1L]] <- dplyr::bind_cols(
      core$wide[c("GEOID", "NAME", "acs_end_year", "period", "geography")], derived) |>
      dplyr::mutate(comparison_id = peer$comparison_id)
  }
  annual <- dplyr::bind_rows(annual)
  dir.create(config$analytic_dir, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(annual, file.path(config$analytic_dir, "comparison_housing.csv"))
  saveRDS(annual, file.path(config$analytic_dir, "comparison_housing.rds"))
  combined[[as.character(year)]] <- annual
  paths <- list.files(config$raw_dir, pattern = "_(api\\.json|tidycensus\\.rds)$", full.names = TRUE)
  readr::write_csv(data.frame(path = paths, md5 = unname(tools::md5sum(paths)),
    cached_at_utc = format(file.info(paths)$mtime, tz = "UTC", usetz = TRUE)), manifest_path)
}
output_dir <- "data/analytic/acs_combined"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
outputs <- list(comparison_housing = dplyr::bind_rows(combined),
  comparison_housing_source_long = dplyr::bind_rows(source_rows),
  comparison_housing_derived = dplyr::bind_rows(derived_rows))
x <- outputs$comparison_housing
stopifnot(nrow(x) == nrow(comparison_places) * length(acs_years),
  !anyDuplicated(x[c("GEOID", "acs_end_year")]),
  nrow(outputs$comparison_housing_source_long) == nrow(x) *
    (length(acs_config$variables) + length(housing_variables)))
for (measure in housing_display_variables(acs_config$variables)) {
  stopifnot(all(is.finite(x[[paste0(measure, "_estimate")]])),
    all(is.finite(x[[paste0(measure, "_moe")]])),
    all(x[[paste0(measure, "_moe")]] >= 0))
}
# Chicago must agree exactly with the independently collected dashboard data.
chicago <- readRDS(file.path(output_dir, "chicago_city_housing.rds"))
for (measure in housing_display_variables(acs_config$variables)) {
  for (suffix in c("estimate", "moe")) {
    field <- paste0(measure, "_", suffix)
    check <- x[x$comparison_id == "chicago", ]
    stopifnot(isTRUE(all.equal(check[[field]][match(chicago$acs_end_year, check$acs_end_year)], chicago[[field]])))
  }
}
for (name in names(outputs)) {
  readr::write_csv(outputs[[name]], file.path(output_dir, paste0(name, ".csv")))
  saveRDS(outputs[[name]], file.path(output_dir, paste0(name, ".rds")))
}
# Publish a compact data asset for a future comparison interface.
fields <- c("comparison_id", "GEOID", "NAME", "geography", "acs_start_year", "acs_end_year",
  "period", "dollar_year", "boundary_year", "moe_confidence", "synthetic_data",
  as.vector(outer(housing_display_variables(acs_config$variables),
    c("estimate", "moe", "estimate_raw", "moe_raw", "estimate_annotation", "moe_annotation",
      "estimate_status", "moe_status", "moe_method"), paste, sep = "_")))
for (directory in c("data/web", "html/data/web")) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x[intersect(fields, names(x))],
    file.path(directory, "comparison_statistics.json"), dataframe = "rows", na = "null", digits = NA, pretty = TRUE)
  published <- jsonlite::read_json(file.path(directory, "comparison_statistics.json"), simplifyVector = TRUE)
  stopifnot(identical(published$GEOID, x$GEOID), nrow(published) == nrow(x))
  for (measure in housing_display_variables(acs_config$variables)) {
    for (suffix in c("estimate", "moe")) {
      field <- paste0(measure, "_", suffix)
      stopifnot(isTRUE(all.equal(published[[field]], x[[field]])))
    }
  }
}
message("Saved ", nrow(x), " city/national period observations with estimates and MOEs.")
