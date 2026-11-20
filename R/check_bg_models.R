# Scientific invariants and an independent HC3 slope-covariance calculation.
source("R/bg_model_config.R")
r <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
d <- r$data
history_path <- file.path(bg_model_config$analytic_dir, "history/before_movers_age/model_results.rds")
if (file.exists(history_path)) {
  previous <- readRDS(history_path)
  stopifnot(identical(previous$data$GEOID, d$GEOID),
    identical(previous$cv$assignments, r$cv$assignments))
}
for (name in c("M1", "M2a", "M2", "M3", "M4")) {
  stopifnot(all(bg_renter_terms %in% attr(stats::terms(r$models[[name]]), "term.labels")))
}
stopifnot(max(abs(d$recent_movers_pct - 100*(d$b25038_010_estimate + d$b25038_011_estimate)/d$b25038_009_estimate)) < 1e-8,
  max(abs(d$young_renters_pct - 100*(d$b25007_013_estimate + d$b25007_014_estimate)/d$b25007_012_estimate)) < 1e-8,
  max(abs(d$older_renters_pct - 100*(d$b25007_019_estimate + d$b25007_020_estimate + d$b25007_021_estimate)/d$b25007_012_estimate)) < 1e-8)
stopifnot(!r$synthetic_data, nrow(d) > 100, !anyDuplicated(d$GEOID),
  all(d$city_fraction >= bg_model_config$city_min_share),
  all(is.finite(d$log_rent)), all(d$rent > 0), all(d$cash_units > 0),
  all(is.finite(as.matrix(d[bg_predictors]))), nlevels(d$community_id) == 77,
  all(d$college_pct + d$no_high_school_pct <= 100 + 1e-8))
for (name in names(bg_share_definitions)) {
  stopifnot(all(d[[paste0(name, "_pct")]] >= 0), all(d[[paste0(name, "_pct")]] <= 100 + 1e-8))
}
expected_poverty <- 100 * (d$poverty_below_half_estimate + d$poverty_half_to_one_estimate) / d$poverty_universe_estimate
stopifnot(max(abs(expected_poverty - d$poverty_pct)) < 1e-8,
  all(d$median_contract_rent_moe[is.finite(d$median_contract_rent_moe)] >= 0), all(is.finite(d$poverty_below_half_moe)),
  all(is.finite(d$poverty_half_to_one_moe)))
for (fit in r$models) {
  stopifnot(stats::nobs(fit) == nrow(d), fit$rank == length(stats::coef(fit)))
  X <- stats::model.matrix(fit)
  independently_fitted <- as.numeric(X %*% stats::lm.fit(X, d$log_rent)$coefficients)
  stopifnot(max(abs(independently_fitted - stats::fitted(fit))) < 1e-8)
}
R2 <- stats::setNames(r$metrics$r_squared, r$metrics$model)
stopifnot(setequal(attr(stats::terms(r$models$M4), "term.labels"), c(bg_housing_terms, "community_id")),
  R2["M4"] >= R2["M1"] - 1e-10, R2["M3"] >= R2["M4"] - 1e-10,
  "M4" %in% r$cv$metrics$model,
  all(is.finite(r$coefficients$hc3_se[r$coefficients$model == "M4" & r$coefficients$term %in% bg_housing_terms])))
stopifnot(all(diff(R2[c("M0","M1","M2a","M2","M3")]) >= -1e-10),
  abs(sum(r$partition$proportion) - 1) < 1e-10,
  max(abs(tapply(stats::residuals(r$models$M3), d$community_id, mean))) < 1e-8)
keep <- table(d$community_id)[as.character(d$community_id)] > 1
fit <- stats::lm(bg_formulas$M3, data = droplevels(d[keep, ]))
X <- stats::model.matrix(fit)
bread <- solve(crossprod(X))
u <- stats::residuals(fit) / (1 - stats::hatvalues(fit))
manual <- bread %*% crossprod(X * u) %*% bread
reported <- r$coefficients[r$coefficients$model == "M3", ]
reported <- reported[match(bg_predictors, reported$term), ]
stopifnot(max(abs(sqrt(diag(manual))[bg_predictors] - reported$hc3_se)) < 1e-7)
a <- r$cv$assignments
stopifnot(all(vapply(split(a$fold, a$tract), function(x) length(unique(x)) == 1, logical(1))),
  all(is.finite(r$cv$predictions$predicted)), length(unique(r$cv$metrics$test_BGs)) == 1,
  identical(r$spatial$geometry$GEOID, d$GEOID), all(is.finite(r$spatial$results$Moran_I)),
  all(r$spatial$results$permutation_p >= 1 / (bg_model_config$moran_permutations + 1)),
  all(is.finite(r$sensitivity_coefficients$estimate)), all(is.finite(r$loco$estimate)))
p <- jsonlite::read_json(file.path(bg_model_config$output_dir, "provenance.json"), simplifyVector = TRUE)
hashes <- unlist(p$input_md5)
stopifnot(identical(unname(tools::md5sum(names(hashes))), unname(hashes)))
message("PASS: BG sample, source ratios/MOEs, full rank, nested fit, independent HC3, spatial alignment, tract CV, sensitivities and source hashes")
