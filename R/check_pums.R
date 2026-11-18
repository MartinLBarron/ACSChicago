# Local QA only. No microdata rows are printed or exported to the website.
source("R/pums_config.R")
source("R/pums_helpers.R")
config <- pums_config
raw <- readRDS(file.path(config$raw_dir, "illinois_housing.rds"))
x <- readRDS(file.path(config$analytic_dir, "chicago_housing.rds"))
lookup <- pums_puma_lookup(config)
validate_pums_housing(raw, config)
validate_pums_housing(x, config)
expected <- prepare_chicago_pums(raw, lookup, config)
stopifnot(identical(x, expected), nrow(x) < nrow(raw),
  all(x$acs_start_year == 2020L), all(x$acs_end_year == 2024L),
  all(x$puma_definition_year == 2020L), all(!x$synthetic_data))
excluded <- acs_config$excluded_puma_geoids[["2020"]]
stopifnot(!any(x$puma_geoid %in% excluded), length(unique(x$puma_geoid)) == 18L)
# These are extraction counts, not weighted population estimates or regression results.
message("PUMS checks passed: unique housing IDs, vacant units, 80 replicate weights, ",
        "18 retained PUMAs, exclusions, and unchanged source columns.")
