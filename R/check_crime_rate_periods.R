# Run after preparing the three display periods and R/model_crime_rate_stages.R.
source("R/bg_model_config.R")
source("R/bg_geography_helpers.R")
source("R/bg_model_helpers.R")
latest <- readRDS("output/models/block_group_crime_rate_2024/models.rds")
out <- "output/models/block_group_crime_rate_periods"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
contrast <- IQR(latest$data$crime_rate)
prepare_period <- function(year) {
  config <- bg_model_config
  config$shape_path <- sprintf("data/shape/acs_%d/chicago_bg.gpkg", year)
  geo <- bg_geographic_assignment(config, acs_config$crs)$audit
  core <- readRDS(sprintf("data/analytic/acs_%d/block_group_housing.rds", year))
  extra <- readRDS(sprintf("data/analytic/model_display_%d/block_group_display.rds", year))
  for (x in list(core, extra)) {
    stopifnot(!anyDuplicated(x$GEOID), setequal(x$GEOID, geo$GEOID),
              all(x$acs_start_year == year-4L & x$acs_end_year == year & x$boundary_year == year))
  }
  areas <- dplyr::inner_join(extra, core[c("GEOID","median_contract_rent_estimate","cash_rent_units_estimate")],
                             by = "GEOID") |>
    dplyr::inner_join(geo[c("GEOID","majority_city","community_id")], by = "GEOID") |>
    dplyr::filter(majority_city, !is.na(community_id), median_contract_rent_estimate > 0,
                  cash_rent_units_estimate > 0, area_median_income_estimate > 0, total_population_estimate > 0) |>
    dplyr::mutate(log_rent = log(median_contract_rent_estimate), log_income = log(area_median_income_estimate),
                  total_population = total_population_estimate,
                  crime_rate = crime_rate_estimate,
                  community_id = factor(community_id))
  # Preserve the original complete-case screen, including the two subsequently omitted shares.
  for (term in grep("_10pp$", bg_predictors, value = TRUE)) {
    areas[[term]] <- areas[[sub("_10pp$", "_pct_estimate", term)]] / 10
  }
  areas <- areas |> dplyr::filter(dplyr::if_all(dplyr::all_of(c(bg_predictors, "crime_rate")), is.finite))
  droplevels(areas)
}
fits <- list()
rows <- list()
period_data <- list()
for (year in acs_years) {
  areas <- prepare_period(year)
  period_data[[as.character(year)]] <- areas[c(all.vars(latest$formulas$M4), "total_population")]
  if (year == 2024L) stopifnot(setequal(areas$GEOID, latest$data$GEOID))
  for (weighting in c("Equal", "Population")) {
    areas$analysis_weight <- if (weighting == "Equal") rep(1, nrow(areas)) else areas$total_population
    fit <- lm(latest$formulas$M4, data = areas, weights = analysis_weight, na.action = na.fail)
    stopifnot(fit$rank == length(coef(fit)))
    if (year == 2024L && weighting == "Equal")
      stopifnot(isTRUE(all.equal(coef(fit), coef(latest$models$M4), tolerance = 1e-9)))
    estimates <- bg_coefficient_table(fit, "M4", areas)
    effect <- subset(estimates, term == "crime_rate")
    for (field in c("estimate","hc3_conf_low","hc3_conf_high","cluster_conf_low","cluster_conf_high")) {
      effect[[paste0("contrast_pct_", field)]] <- 100 * expm1(contrast * effect[[field]])
    }
    key <- paste(year, weighting)
    fits[[key]] <- fit
    rows[[key]] <- cbind(year, weighting, n = nrow(areas), communities = nlevels(areas$community_id),
      common_rate_difference = contrast, r_squared = summary(fit)$r.squared, effect)
  }
}
results <- dplyr::bind_rows(rows)
readr::write_csv(results, file.path(out, "m4_crime_associations.csv"))
saveRDS(fits, file.path(out, "m4_fits.rds"))
print(results[c("year","weighting","n","communities","r_squared","contrast_pct_estimate","contrast_pct_hc3_conf_low",
                "contrast_pct_hc3_conf_high","contrast_pct_cluster_conf_low","contrast_pct_cluster_conf_high")], row.names=FALSE)

# Fully interact the period with every slope and community intercept. This
# reproduces the separate fits and lets community clusters span all three periods.
pooled <- dplyr::bind_rows(period_data, .id = "period")
pooled$period <- factor(pooled$period, levels = as.character(acs_years))
pooled_formula <- update(latest$formulas$M4, . ~ period * (.))
tests <- lapply(c("Equal", "Population"), function(weighting) {
  pooled$w <- if (weighting == "Equal") 1 else pooled$total_population
  fit <- lm(pooled_formula, data = pooled, weights = w, na.action = na.fail)
  interactions <- paste0("period", acs_years[-1], ":crime_rate")
  b <- coef(fit)[interactions]
  slopes <- unname(coef(fit)["crime_rate"] + c(0, b))
  separate <- results$estimate[results$weighting == weighting]
  stopifnot(isTRUE(all.equal(slopes, separate, tolerance = 1e-9)))
  V <- sandwich::vcovCL(fit, cluster = pooled$community_id, type = "HC1")[interactions, interactions]
  df1 <- length(b)
  df2 <- nlevels(pooled$community_id) - 1
  F_stat <- drop(crossprod(b, solve(V, b))) / df1
  data.frame(weighting, F_stat, df1, df2, p_value = pf(F_stat, df1, df2, lower.tail = FALSE))
})
tests <- dplyr::bind_rows(tests)
readr::write_csv(tests, file.path(out, "crime_by_period_tests.csv"))
print(tests)
