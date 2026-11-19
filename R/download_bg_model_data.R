# New aggregate inputs for the latest-year BG models; original caches are untouched.
source("R/bg_model_config.R")
source("R/acs_helpers.R")
require_acs_packages()
if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY in .Renviron.")
cfg <- bg_model_config
config <- acs_config_for_year(cfg$year)
config$raw_dir <- cfg$raw_dir
dir.create(config$raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$analytic_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = max(600, getOption("timeout")))
core <- readRDS(cfg$core_path)
counties <- sort(unique(substr(core$GEOID, 3, 5)))
manifest_path <- file.path(cfg$raw_dir, "manifest.csv")
if (file.exists(manifest_path)) {
  previous <- readr::read_csv(manifest_path, show_col_types = FALSE)
  stopifnot(all(file.exists(previous$path)), all(unname(tools::md5sum(previous$path)) == previous$md5))
}
responses <- codebook <- list()
for (group in names(bg_variable_groups)) {
  variables <- bg_variable_groups[[group]]
  table <- substr(unname(variables)[1], 1, 6)
  message("Block-group model inputs: ", table, " (", group, ")")
  metadata_path <- file.path(cfg$raw_dir, paste0(table, "_metadata.json"))
  cache_download(sprintf("https://api.census.gov/data/%d/acs/acs5/groups/%s.json", cfg$year, table), metadata_path)
  metadata <- jsonlite::read_json(metadata_path)$variables
  stopifnot(all(paste0(unname(variables), "E") %in% names(metadata)))
  codebook[[group]] <- data.frame(variable = names(variables), variable_code = unname(variables),
    table = table, group = group,
    label = vapply(paste0(unname(variables), "E"), function(v) metadata[[v]]$label, character(1)))
  county_data <- lapply(counties, function(county) {
    # E/M/EA/MA plus NAME: batches of 12 never exceed the API's 50-field limit.
    parts <- split(variables, ceiling(seq_along(variables) / 12))
    api_parts <- lapply(seq_along(parts), function(i) {
      part_config <- config
      part_config$variables <- parts[[i]]
      path <- file.path(cfg$raw_dir, sprintf("%s_%s_part%d_api.json", table, county, i))
      cache_api_response("block group", county, part_config, path)
      read_api_response(path)
    })
    api <- api_parts[[1]]
    for (part in api_parts[-1]) {
      stopifnot(setequal(api$GEOID, part$GEOID), !anyDuplicated(part$GEOID))
      api <- dplyr::left_join(api, part[c("GEOID", setdiff(names(part), names(api)))], by = "GEOID")
    }
    path <- file.path(cfg$raw_dir, sprintf("%s_%s_tidycensus.rds", table, county))
    fallback_path <- file.path(cfg$raw_dir, sprintf("%s_%s_api_tidy.rds", table, county))
    if (file.exists(fallback_path)) {
      tidy <- readRDS(fallback_path)
    } else if (file.exists(path)) {
      tidy <- readRDS(path)
    } else {
      tidy <- tryCatch({
        result <- tidycensus::get_acs(geography = "block group", state = config$state,
          county = county, table = table, year = cfg$year, survey = "acs5", geometry = FALSE,
          output = "tidy", moe_level = 90, key = Sys.getenv("CENSUS_API_KEY"), show_call = FALSE) |>
          dplyr::filter(variable %in% unname(variables)) |>
          dplyr::mutate(variable = names(variables)[match(variable, unname(variables))])
        saveRDS(result, path)
        result
      }, error = function(error) {
        if (!grepl("524|502|503|504|timeout|timed out|temporarily unavailable|Unable to connect",
                   conditionMessage(error), ignore.case = TRUE)) stop(error)
        message("Recovering ", table, " county ", county, " from its preserved official API response")
        result <- puma_api_batch(api, variables) # Generic E/M reshaping; no PUMA assumptions.
        saveRDS(result, fallback_path)
        result
      })
    }
    list(tidy = tidy, api = api)
  })
  group_config <- config
  group_config$variables <- variables
  prepared <- prepare_acs_dataset(dplyr::bind_rows(lapply(county_data, `[[`, "tidy")),
    dplyr::bind_rows(lapply(county_data, `[[`, "api")), core["GEOID"], "block group", group_config)
  responses[[group]] <- prepared
}
long <- dplyr::bind_rows(lapply(responses, `[[`, "long"))
long <- long |> dplyr::left_join(dplyr::bind_rows(codebook)[c("variable", "group")], by = "variable") |>
  dplyr::mutate(unit = dplyr::case_when(group == "income" ~ "2024 household-income dollars",
    group == "education" ~ "adults age 25+", group %in% c("poverty", "race") ~ "persons",
    TRUE ~ "renter-occupied housing units"))
wide <- responses[[1]]$wide
metadata_fields <- c("GEOID", "NAME", "geography", "acs_start_year", "acs_end_year", "period",
                     "dollar_year", "boundary_year", "moe_confidence", "synthetic_data")
for (response in responses[-1]) wide <- dplyr::left_join(wide,
  response$wide[c("GEOID", setdiff(names(response$wide), metadata_fields))], by = "GEOID")
stopifnot(nrow(wide) == nrow(core), !anyDuplicated(wide$GEOID))
saveRDS(wide, file.path(cfg$analytic_dir, "source_counts.rds"))
saveRDS(long, file.path(cfg$analytic_dir, "source_counts_long.rds"))
readr::write_csv(wide, file.path(cfg$analytic_dir, "source_counts.csv"))
readr::write_csv(long, file.path(cfg$analytic_dir, "source_counts_long.csv"))
readr::write_csv(dplyr::bind_rows(codebook), file.path(cfg$analytic_dir, "source_codebook.csv"))
paths <- list.files(cfg$raw_dir, full.names = TRUE)
paths <- paths[basename(paths) != "manifest.csv" & !grepl("\\.part$", paths)]
readr::write_csv(data.frame(path = paths, md5 = unname(tools::md5sum(paths)),
  cached_at_utc = format(file.info(paths)$mtime, tz = "UTC", usetz = TRUE)), manifest_path)
message("Block-group source data prepared: ", nrow(wide), " areas")
