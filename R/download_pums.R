# Download/cache the complete Illinois housing extract, including vacant units.
# Run independently: Rscript R/download_pums.R
source("R/pums_config.R")
source("R/acs_helpers.R")
source("R/pums_helpers.R")
require_acs_packages()
if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY in .Renviron.")
config <- pums_config
options(timeout = max(600, getOption("timeout")))
dir.create(config$raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config$analytic_dir, recursive = TRUE, showWarnings = FALSE)
lookup <- pums_puma_lookup(config)
manifest_path <- file.path(config$raw_dir, "manifest.csv")
if (file.exists(manifest_path)) {
  previous <- readr::read_csv(manifest_path, show_col_types = FALSE)
  stopifnot(all(file.exists(previous$path)),
    all(unname(tools::md5sum(previous$path)) == previous$md5))
}

# The package catalog supplies value labels; preserve the official API metadata too.
metadata_url <- sprintf("https://api.census.gov/data/%d/acs/%s/pums/variables.json",
                        config$year, config$survey)
metadata_path <- file.path(config$raw_dir, "variables.json")
cache_download(metadata_url, metadata_path)
metadata <- jsonlite::read_json(metadata_path)$variables
stopifnot(all(config$variables %in% names(metadata)))
catalog <- tidycensus::pums_variables |>
  dplyr::filter(year == as.character(config$year), survey == config$survey)
needed <- c(config$variables, "SERIALNO", "SPORDER", "STATE", "WGTP", "PWGTP", paste0("WGTP", 1:80))
stopifnot(all(needed %in% catalog$var_code))
request <- list(year = config$year, survey = config$survey, state = config$state,
  puma = NULL, variables = config$variables, variables_filter = config$variables_filter,
  recode = TRUE, return_vacant = TRUE, rep_weights = config$rep_weights,
  tidycensus_version = as.character(utils::packageVersion("tidycensus")),
  synthetic_data = SYNTHETIC_DATA)
request_path <- file.path(config$raw_dir, "request.json")
if (file.exists(request_path)) {
  # A changed request needs a new cache version, never an overwritten source extract.
  expected <- jsonlite::fromJSON(jsonlite::toJSON(request, auto_unbox = TRUE, null = "null"))
  if (!isTRUE(all.equal(jsonlite::fromJSON(request_path), expected))) {
    stop("PUMS request differs from the cached request. Choose a new raw cache version.")
  }
} else {
  jsonlite::write_json(request, request_path, auto_unbox = TRUE, null = "null", pretty = TRUE)
}
raw_path <- file.path(config$raw_dir, "illinois_housing.rds")
if (!file.exists(raw_path)) {
  message("Downloading Illinois 2020–2024 PUMS housing records, including vacant units")
  housing <- tidycensus::get_pums(
    variables = config$variables,
    state = config$state,
    puma = NULL,
    year = config$year,
    survey = config$survey,
    variables_filter = config$variables_filter,
    rep_weights = config$rep_weights,
    recode = TRUE,
    return_vacant = TRUE,
    key = Sys.getenv("CENSUS_API_KEY"),
    show_call = FALSE
  )
  temporary <- paste0(raw_path, ".part")
  saveRDS(housing, temporary)
  if (!file.rename(temporary, raw_path)) stop("Cannot finalize Illinois PUMS cache.")
  validate_pums_housing(housing, config)
  rm(housing)
} else {
  message("Using cached Illinois PUMS housing extract")
  validate_pums_housing(readRDS(raw_path), config)
}
# Keep the package's original coded columns and recode labels unaltered in this RDS.
readr::write_csv(catalog |> dplyr::filter(var_code %in% needed),
  file.path(config$raw_dir, "value_labels.csv"))
inputs <- list.files(config$raw_dir, full.names = TRUE)
inputs <- inputs[basename(inputs) != "manifest.csv" & !grepl("\\.part$", inputs)]
readr::write_csv(data.frame(path = inputs, md5 = unname(tools::md5sum(inputs)),
  cached_at_utc = format(file.info(inputs)$mtime, tz = "UTC", usetz = TRUE)), manifest_path)
message("Illinois PUMS cache validated; run R/prepare_pums.R to create the Chicago subset.")
