# Shared peer geography definitions and cached Census extraction.
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

