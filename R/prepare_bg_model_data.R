# Build one audited modeling row per whole block group; never change map exports.
source("R/bg_model_config.R")
source("R/housing_derivation_helpers.R")
cfg <- bg_model_config
source_counts <- readRDS(file.path(cfg$analytic_dir, "source_counts.rds"))
core <- readRDS(cfg$core_path)
geo <- readr::read_csv(file.path(cfg$analytic_dir, "geographic_assignment.csv"),
  col_types = readr::cols(GEOID = readr::col_character(), community_id = readr::col_character()))
metadata <- c("GEOID", "NAME", "geography", "acs_start_year", "acs_end_year", "period",
              "dollar_year", "boundary_year", "moe_confidence", "synthetic_data")
x <- dplyr::left_join(core,
  source_counts[c("GEOID", setdiff(names(source_counts), metadata))], by = "GEOID") |>
  dplyr::left_join(geo, by = "GEOID")
stopifnot(nrow(x) == nrow(core), !anyDuplicated(x$GEOID))
# Validate complete renter-count partitions before deriving stock composition.
partitions <- list(
  bed_total = names(bg_variable_groups$bedrooms)[-1],
  structure_total = names(bg_variable_groups$structures)[-1],
  age_total = names(bg_variable_groups$age)[-1])
for (total in names(partitions)) {
  values <- rowSums(as.matrix(x[paste0(partitions[[total]], "_estimate")]))
  reported <- x[[paste0(total, "_estimate")]]
  valid <- is.finite(values) & is.finite(reported)
  stopifnot(all(values[valid] == reported[valid]))
  valid <- is.finite(reported) & is.finite(x$renter_occupied_units_estimate)
  stopifnot(all(reported[valid] == x$renter_occupied_units_estimate[valid]))
}
derived <- list()
for (variable in names(bg_share_definitions)) {
  definition <- bg_share_definitions[[variable]]
  values <- derive_housing_percentage(x, definition)
  derived[[variable]] <- data.frame(GEOID = x$GEOID, variable = variable,
    numerator = paste(definition$numerator, collapse = " + "),
    denominator = paste(definition$denominator, collapse = " + "), values)
  x[[paste0(variable, "_pct")]] <- values$estimate
  x[[paste0(variable, "_pct_moe")]] <- values$moe
  x[[paste0(variable, "_10pp")]] <- values$estimate / 10
}
# Shares describe all renter-occupied housing; median rent describes cash-rent units.
x$rent <- x$median_contract_rent_estimate
x$rent_moe <- x$median_contract_rent_moe
x$cash_units <- x$cash_rent_units_estimate
x$income <- x$area_median_income_estimate
x$log_rent <- ifelse(is.finite(x$rent) & x$rent > 0, log(pmax(x$rent, 1)), NA_real_)
x$log_income <- ifelse(is.finite(x$income) & x$income > 0, log(pmax(x$income, 1)), NA_real_)
x$rent_se <- x$rent_moe / stats::qnorm(.95) # ACS published 90% MOE.
x$log_rent_se <- x$rent_se / x$rent # Delta approximation, used only in sensitivities.
x$rent_relative_moe <- x$rent_moe / x$rent
x$tract <- substr(x$GEOID, 1, 11)
x$community_id <- factor(x$community_id, levels = sprintf("%02d", 1:77))
contrasts(x$community_id) <- stats::contr.treatment(levels(x$community_id))
checks <- list(
  majority_city = x$majority_city,
  assigned_community = !is.na(x$community_id),
  positive_published_rent = is.finite(x$rent) & x$rent > 0,
  positive_cash_rent_units = is.finite(x$cash_units) & x$cash_units > 0,
  valid_controls = stats::complete.cases(x[bg_predictors]) &
    apply(as.matrix(x[bg_predictors]), 1, function(row) all(is.finite(row)))
)
remaining <- rep(TRUE, nrow(x))
reason <- rep("included", nrow(x))
flow <- data.frame(stage = "mapped_positive_overlap_BGs", remaining = nrow(x), excluded_at_stage = 0L)
for (stage in names(checks)) {
  pass <- checks[[stage]]
  pass[is.na(pass)] <- FALSE
  reason[remaining & !pass] <- stage
  old <- sum(remaining)
  remaining <- remaining & pass
  flow <- rbind(flow, data.frame(stage = stage, remaining = sum(remaining), excluded_at_stage = old - sum(remaining)))
}
x$model_included <- remaining
x$exclusion_reason <- reason
sample <- droplevels(x[remaining, ])
rownames(sample) <- NULL
print(flow, row.names = FALSE)
stopifnot(nrow(sample) > 100, !anyDuplicated(sample$GEOID), all(is.finite(sample$log_rent)))
counts <- sample |> dplyr::count(community_id, community, name = "sample_BGs")
if (any(counts$sample_BGs < 2)) message("Singleton communities: fixed effects have no within-area residual information")
missingness <- dplyr::bind_rows(lapply(c("rent", "rent_moe", bg_predictors), function(variable) {
  data.frame(variable = variable, missing_all_mapped = sum(!is.finite(x[[variable]])),
    missing_majority_city = sum(x$majority_city & !is.finite(x[[variable]])))
}))
saveRDS(x, file.path(cfg$analytic_dir, "all_bg_model_data.rds"))
saveRDS(sample, file.path(cfg$analytic_dir, "model_sample.rds"))
saveRDS(dplyr::bind_rows(derived), file.path(cfg$analytic_dir, "derived_measures_long.rds"))
readr::write_csv(dplyr::bind_rows(derived), file.path(cfg$analytic_dir, "derived_measures_long.csv"))
readr::write_csv(flow, file.path(cfg$analytic_dir, "sample_flow.csv"))
readr::write_csv(missingness, file.path(cfg$analytic_dir, "missingness.csv"))
readr::write_csv(counts, file.path(cfg$analytic_dir, "sample_by_community.csv"))
readr::write_csv(x[c("GEOID", "community_id", "community", "city_fraction", "community_dominance",
  "rent", "rent_moe", "cash_units", "model_included", "exclusion_reason")],
  file.path(cfg$analytic_dir, "sample_audit.csv"))
message("Prepared BG common sample: ", nrow(sample), " areas in ", nlevels(sample$community_id), " communities")
