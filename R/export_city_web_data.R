# Publish directly estimated Chicago place statistics for cards and D3 charts.
source("R/acs_config.R")
source("R/housing_config.R")
input <- "data/analytic/acs_combined/chicago_city_housing.rds"
if (!file.exists(input)) stop("Run the core and supplementary ACS pipeline stages first.")
x <- readRDS(input)
x <- x[order(x$acs_end_year), ]
measures <- c(names(acs_config$variables), names(housing_derivations))
suffixes <- c("estimate", "moe", "estimate_raw", "moe_raw", "estimate_annotation", "moe_annotation", "estimate_status", "moe_status", "moe_method")
fields <- c("GEOID", "NAME", "geography", "acs_start_year", "acs_end_year", "period", "dollar_year", "boundary_year", "moe_confidence", "synthetic_data", as.vector(outer(measures, suffixes, paste, sep = "_")))
x <- x[intersect(fields, names(x))]
stopifnot(nrow(x) == length(acs_years), setequal(x$acs_end_year, acs_years),
          all(x$GEOID == "1714000"), !anyDuplicated(x$acs_end_year))
for (directory in c("data/web", "html/data/web")) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
}
output <- "data/web/chicago_city_statistics.json"
jsonlite::write_json(x, output, dataframe = "rows", na = "null", digits = NA, pretty = TRUE)
check <- jsonlite::read_json(output, simplifyVector = TRUE)
stopifnot(identical(check$GEOID, x$GEOID))
for (measure in measures) {
  for (suffix in c("estimate", "moe")) {
    column <- paste0(measure, "_", suffix)
    stopifnot(isTRUE(all.equal(check[[column]], x[[column]])))
  }
}
site_output <- "html/data/web/chicago_city_statistics.json"
stopifnot(file.copy(output, site_output, overwrite = TRUE),
          unname(tools::md5sum(output)) == unname(tools::md5sum(site_output)))
message("Exported Chicago citywide statistics for ", nrow(x), " periods")
