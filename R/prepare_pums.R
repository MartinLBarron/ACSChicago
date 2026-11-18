# Local preparation only: retain the selected whole PUMAs and all housing tenures.
source("R/pums_config.R")
source("R/pums_helpers.R")
config <- pums_config
raw_path <- file.path(config$raw_dir, "illinois_housing.rds")
if (!file.exists(raw_path)) stop("Run R/download_pums.R first.")
manifest <- readr::read_csv(file.path(config$raw_dir, "manifest.csv"), show_col_types = FALSE)
stopifnot(all(file.exists(manifest$path)), all(unname(tools::md5sum(manifest$path)) == manifest$md5))
raw <- readRDS(raw_path)
lookup <- pums_puma_lookup(config)
x <- prepare_chicago_pums(raw, lookup, config)
dir.create(config$analytic_dir, recursive = TRUE, showWarnings = FALSE)
saveRDS(x, file.path(config$analytic_dir, "chicago_housing.rds"))
readr::write_csv(x, file.path(config$analytic_dir, "chicago_housing.csv"), na = "")
readr::write_csv(lookup, file.path(config$analytic_dir, "retained_pumas.csv"))
counts <- x |>
  dplyr::count(puma_geoid, puma_name, is_vacant, name = "sample_housing_units")
readr::write_csv(counts, file.path(config$analytic_dir, "sample_counts.csv"))
catalog <- readr::read_csv(file.path(config$raw_dir, "value_labels.csv"), show_col_types = FALSE)
readr::write_csv(catalog |> dplyr::distinct(var_code, var_label, data_type, level),
  file.path(config$analytic_dir, "source_codebook.csv"))
summary <- data.frame(geography = c("Illinois", "Retained Chicago PUMAs"),
  sample_housing_units = c(nrow(raw), nrow(x)),
  occupied = c(sum(!as.character(raw$VACS) %in% as.character(1:7)), sum(!x$is_vacant)),
  vacant = c(sum(as.character(raw$VACS) %in% as.character(1:7)), sum(x$is_vacant)),
  pumas = c(length(unique(raw$PUMA)), length(unique(x$puma_geoid))),
  housing_replicate_weights = 80L, synthetic_data = SYNTHETIC_DATA)
readr::write_csv(summary, file.path(config$analytic_dir, "validation_summary.csv"))
jsonlite::write_json(list(
  raw_input = raw_path, raw_input_md5 = unname(tools::md5sum(raw_path)),
  puma_boundaries = config$boundary_path,
  puma_boundaries_md5 = unname(tools::md5sum(config$boundary_path)),
  retained_puma_geoids = lookup$GEOID, year = config$year, survey = config$survey,
  dollar_adjustment_applied = FALSE, model_sample_filter_applied = FALSE,
  housing_replicate_weights = 80L, synthetic_data = SYNTHETIC_DATA
), file.path(config$analytic_dir, "preparation_metadata.json"),
  auto_unbox = TRUE, pretty = TRUE)
# Log aggregate QA counts only, never individual microdata records.
message("Prepared ", nrow(x), " housing records in ", nrow(lookup), " PUMAs; ",
        sum(x$is_vacant), " vacant units retained.")
