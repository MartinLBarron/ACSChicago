# Raw/source stage: run after R/download_acs_rent.R, from the project root.
source("R/acs_config.R")
source("R/acs_helpers.R")
source("R/housing_config.R")
require_acs_packages()
if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY in .Renviron.")
options(timeout = max(600, getOption("timeout")))
for (year in acs_years) {
  config <- acs_config_for_year(year)
  available_groups <- housing_groups_for_year(year)
  # A separate cache preserves the earlier rent responses and manifests unchanged.
  config$raw_dir <- file.path(config$raw_dir, "housing")
  dir.create(config$raw_dir, recursive = TRUE, showWarnings = FALSE)
  manifest_path <- file.path(config$raw_dir, "manifest.csv")
  if (file.exists(manifest_path)) {
    previous <- readr::read_csv(manifest_path, show_col_types = FALSE)
    stopifnot(all(file.exists(previous$path)),
              all(unname(tools::md5sum(previous$path)) == previous$md5))
  }
  # Preserve official labels and check codes for this specific release.
  metadata_rows <- lapply(names(available_groups), function(group) {
    variables <- available_groups[[group]]
    table <- substr(unname(variables)[1], 1, 6)
    path <- file.path(config$raw_dir, paste0(table, "_metadata.json"))
    cache_download(sprintf("https://api.census.gov/data/%d/acs/acs5/groups/%s.json", year, table), path)
    metadata <- jsonlite::read_json(path)$variables
    codes <- unname(variables)
    stopifnot(all(paste0(codes, "E") %in% names(metadata)),
              all(paste0(codes, "M") %in% names(metadata)))
    data.frame(variable = names(variables), variable_code = codes, table = table,
               label = vapply(paste0(codes, "E"), function(code) metadata[[code]]$label, character(1)))
  })
  readr::write_csv(dplyr::bind_rows(metadata_rows), file.path(config$analytic_dir, "housing_source_codebook.csv"))
  for (tag in c("tract", "block_group", "chicago_city")) {
    kind <- if (tag == "chicago_city") "place" else gsub("_", " ", tag)
    core_path <- file.path(config$analytic_dir, paste0(tag, "_rent.rds"))
    if (!file.exists(core_path)) stop("Run Rscript R/download_acs_rent.R first.")
    core <- readRDS(core_path)
    counties <- if (kind == "place") NA_character_ else sort(unique(substr(core$GEOID, 3, 5)))
    message("Downloading supplementary ACS ", year, " ", kind)
    groups <- lapply(names(available_groups), function(group) {
      group_config <- config
      group_config$variables <- available_groups[[group]]
      responses <- lapply(counties, function(county) {
        if (kind == "place") get_chicago_place_rent(group_config, paste0("_", group)) else
          get_county_variables(kind, county, group_config, paste0("_", group))
      })
      list(tidy = dplyr::bind_rows(lapply(responses, `[[`, "tidy")),
           api = dplyr::bind_rows(lapply(responses, `[[`, "api")))
    })
    tidy <- dplyr::bind_rows(lapply(groups, `[[`, "tidy"))
    api <- groups[[1]]$api
    for (group in groups[-1]) {
      stopifnot(setequal(api$GEOID, group$api$GEOID), !anyDuplicated(group$api$GEOID))
      columns <- c("GEOID", setdiff(names(group$api), names(api)))
      api <- dplyr::left_join(api, group$api[columns], by = "GEOID")
    }
    config$variables <- do.call(c, unname(available_groups))
    prepared <- prepare_acs_dataset(tidy, api, core["GEOID"], kind, config)
    prepared$long$source_status <- "published"
    unavailable <- setdiff(names(housing_variables), names(config$variables))
    if (length(unavailable)) {
      # Explicit structural gaps, not API missing-value codes or fabricated medians.
      template <- prepared$long[prepared$long$variable == names(config$variables)[1], ]
      placeholders <- lapply(unavailable, function(variable) {
        row <- template
        row$variable <- variable
        row$variable_code <- unname(housing_variables[[variable]])
        row$estimate <- row$moe <- NA_real_
        for (field in c("estimate_raw", "moe_raw", "estimate_annotation", "moe_annotation")) row[[field]] <- NA_character_
        row$unit <- paste("monthly", year, "dollars")
        row$source_status <- "table_not_published"
        row
      })
      prepared$long <- dplyr::bind_rows(prepared$long, dplyr::bind_rows(placeholders)) |>
        dplyr::arrange(GEOID, variable)
    }
    for (variable in names(housing_variables)) {
      if (variable %in% unavailable) {
        for (suffix in c("estimate", "moe")) prepared$wide[[paste0(variable, "_", suffix)]] <- NA_real_
        for (suffix in c("estimate_raw", "moe_raw", "estimate_annotation", "moe_annotation")) prepared$wide[[paste0(variable, "_", suffix)]] <- NA_character_
      }
      prepared$wide[[paste0(variable, "_source_status")]] <-
        if (variable %in% unavailable) "table_not_published" else "published"
    }
    stopifnot(all(is.na(prepared$long$estimate) | prepared$long$estimate == floor(prepared$long$estimate)))
    # Save source components separately; derived values are computed in the next stage.
    for (shape in c("long", "wide")) {
      name <- paste0(tag, "_housing_source", if (shape == "long") "_long" else "")
      readr::write_csv(prepared[[shape]], file.path(config$analytic_dir, paste0(name, ".csv")))
      saveRDS(prepared[[shape]], file.path(config$analytic_dir, paste0(name, ".rds")))
    }
  }
  inputs <- list.files(config$raw_dir, pattern = "\\.(json|rds)$", full.names = TRUE)
  manifest <- data.frame(path = inputs, md5 = unname(tools::md5sum(inputs)),
    cached_at_utc = format(file.info(inputs)$mtime, tz = "UTC", usetz = TRUE))
  readr::write_csv(manifest, manifest_path)
}
