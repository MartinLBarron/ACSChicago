# Equal-area observational models of published block-group median contract rent.
source("R/bg_model_config.R")
source("R/bg_model_helpers.R")
cfg <- bg_model_config
for (package in c("sandwich", "lmtest", "spdep", "sf", "dplyr", "readr")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Install ", package, " first")
}
dir.create(cfg$output_dir, recursive = TRUE, showWarnings = FALSE)
d <- readRDS(file.path(cfg$analytic_dir, "model_sample.rds"))
all_data <- readRDS(file.path(cfg$analytic_dir, "all_bg_model_data.rds"))
models <- lapply(bg_formulas, function(formula) stats::lm(formula, data = d, na.action = stats::na.fail))
stopifnot(all(vapply(models, function(m) m$rank == length(stats::coef(m)), logical(1))))
metrics <- dplyr::bind_rows(lapply(names(models), function(name) bg_fit_summary(models[[name]], name)))
coefficients <- dplyr::bind_rows(lapply(names(models), function(name) {
  bg_coefficient_table(models[[name]], name, d, cfg$confidence)
}))
rsq <- stats::setNames(metrics$r_squared, metrics$model)
comparisons <- data.frame(from = c("M0", "M1", "M2a", "M2", "M1", "M4"),
                          to = c("M1", "M2a", "M2", "M3", "M4", "M3"))
comparisons$incremental_R2 <- unname(rsq[comparisons$to] - rsq[comparisons$from])
comparisons$partial_R2 <- comparisons$incremental_R2 / (1 - unname(rsq[comparisons$from]))
partition <- data.frame(component = c("Housing composition + renter profile", "Context unique beyond housing + community",
  "Community unique beyond housing + context", "Shared context/community association", "Unexplained"),
  proportion = c(rsq["M1"], rsq["M3"] - rsq["M4"], rsq["M3"] - rsq["M2"],
    rsq["M2"] + rsq["M4"] - rsq["M3"] - rsq["M1"], 1 - rsq["M3"]))
rownames(partition) <- NULL

diagnostic_tests <- dplyr::bind_rows(lapply(c("M1", "M2a", "M2", "M3", "M4"), function(name) {
  fit <- models[[name]]
  bp <- lmtest::bptest(fit, studentize = TRUE)
  reset_fit <- fit
  if (name %in% c("M3", "M4") && any(table(d$community_id) == 1)) {
    keep <- table(d$community_id)[as.character(d$community_id)] > 1
    reset_fit <- stats::lm(bg_formulas[[name]], data = droplevels(d[keep, ]))
  }
  reset <- lmtest::resettest(reset_fit, power = 2:3, type = "fitted",
                           vcov = function(m) sandwich::vcovHC(m, type = "HC3"))
  data.frame(model = name, test = c("Studentized Breusch–Pagan", "RESET (HC3; powers 2–3)"),
    statistic = c(unname(bp$statistic), unname(reset$statistic)),
    p_value = c(bp$p.value, reset$p.value))
}))
vif <- dplyr::bind_rows(lapply(c("M1", "M2", "M3", "M4"), function(name) bg_vif(models[[name]], name)))
influence <- data.frame(GEOID = d$GEOID, community = d$community,
  fitted = stats::fitted(models$M3), residual = stats::residuals(models$M3),
  studentized = stats::rstudent(models$M3), leverage = stats::hatvalues(models$M3),
  cooks_D = stats::cooks.distance(models$M3),
  max_abs_DFBETA = apply(abs(stats::dfbetas(models$M3)), 1, function(x) if (all(!is.finite(x))) NA_real_ else max(x[is.finite(x)])),
  rent_relative_moe = d$rent_relative_moe)
singleton <- table(d$community_id)[as.character(d$community_id)] == 1
influence[singleton, c("studentized", "cooks_D", "max_abs_DFBETA")] <- NA_real_
spatial <- bg_spatial_diagnostics(d, models[c("M1", "M2a", "M2", "M3", "M4")], cfg)
cv <- bg_cross_validation(d, cfg)

# These change the target population/estimand; no specification is selected by p-value.
sensitivities <- list(bg_sensitivity_fit(d, "Equal BGs (primary)"),
  bg_sensitivity_fit(d, "Cash-rent-unit weighting", d$cash_units))
valid_precision <- is.finite(d$log_rent_se) & d$log_rent_se > 0
pdata <- d[valid_precision, ]
precision <- 1 / pdata$log_rent_se^2
cap <- unname(stats::quantile(precision, .99))
sensitivities[[length(sensitivities) + 1L]] <- bg_sensitivity_fit(pdata,
  "Precision weighting (99th-percentile cap)", pmin(precision, cap))
sensitivities[[length(sensitivities) + 1L]] <- bg_sensitivity_fit(pdata,
  "Precision weighting (uncapped)", precision)
subsets <- list(
  "Exclude open-ended median-rent categories" = which(is.finite(d$rent_moe)),
  "Rent MOE <= 50% of estimate" = which(is.finite(d$rent_relative_moe) & d$rent_relative_moe <= .5),
  "At least 50 estimated cash-rent units" = which(d$cash_units >= 50),
  "At least 99% of polygon inside city" = which(d$city_fraction >= cfg$strict_city_share),
  "At least 80% dominant-community overlap" = which(d$community_dominance >= cfg$unambiguous_community_share),
  "Exclude highest 1% Cook's distances" = which(!is.finite(influence$cooks_D) | influence$cooks_D <= stats::quantile(influence$cooks_D, .99, na.rm = TRUE)))
for (name in names(subsets)) {
  sensitivities[[length(sensitivities) + 1L]] <- bg_sensitivity_fit(d[subsets[[name]], ], name)
}
broader <- all_data[!is.na(all_data$community_id) & is.finite(all_data$log_rent) &
  is.finite(all_data$cash_units) & all_data$cash_units > 0 &
  stats::complete.cases(all_data[bg_predictors]), ]
sensitivities[[length(sensitivities) + 1L]] <- bg_sensitivity_fit(broader, "All positive-city-overlap BGs")
sensitivity_metrics <- dplyr::bind_rows(lapply(sensitivities, `[[`, "metrics"))
sensitivity_coefficients <- dplyr::bind_rows(lapply(sensitivities, `[[`, "coefficients"))

# Leave one community out: how strongly does a single area drive contextual slopes?
loco <- dplyr::bind_rows(lapply(levels(d$community_id), function(id) {
  sub <- droplevels(d[as.character(d$community_id) != id, ])
  dplyr::bind_rows(lapply(c("M2", "M3"), function(name) {
    fit <- stats::lm(bg_formulas[[name]], data = sub, na.action = stats::na.fail)
    data.frame(omitted_community = id, model = name, term = bg_context_terms,
               estimate = unname(stats::coef(fit)[bg_context_terms]))
  }))
}))
# Center the fixed effects over the primary sample, rather than privilege area 01.
effect <- stats::coef(models$M3)[paste0("community_id", levels(d$community_id))]
effect[1] <- 0
counts <- table(d$community_id)
effect <- unname(effect) - stats::weighted.mean(unname(effect), as.numeric(counts))
communities <- unique(d[c("community_id", "community")])
communities <- communities[match(levels(d$community_id), communities$community_id), ]
communities$BGs <- as.numeric(counts)
communities$centered_log_effect <- effect
communities$percent_difference <- 100 * expm1(effect)

description <- dplyr::bind_rows(lapply(c("rent", "rent_relative_moe", "cash_units", "income",
  paste0(names(bg_share_definitions), "_pct")), function(variable) {
  values <- d[[variable]]
  q <- stats::quantile(values, c(.05, .25, .5, .75, .95), na.rm = TRUE)
  data.frame(variable = variable, n = sum(is.finite(values)), mean = mean(values, na.rm = TRUE),
    sd = stats::sd(values, na.rm = TRUE), p05 = unname(q[1]), p25 = unname(q[2]),
    median = unname(q[3]), p75 = unname(q[4]), p95 = unname(q[5]))
}))
read_table <- function(name) readr::read_csv(file.path(cfg$analytic_dir, name), show_col_types = FALSE)
results <- list(config = cfg, synthetic_data = SYNTHETIC_DATA, data = d, all_data = all_data,
  models = models, metrics = metrics, coefficients = coefficients, comparisons = comparisons,
  partition = partition, diagnostic_tests = diagnostic_tests, vif = vif, influence = influence,
  spatial = spatial, cv = cv, sensitivity_metrics = sensitivity_metrics,
  sensitivity_coefficients = sensitivity_coefficients, loco = loco, communities = communities,
  description = description, sample_flow = read_table("sample_flow.csv"),
  missingness = read_table("missingness.csv"), source_codebook = read_table("source_codebook.csv"),
  predictor_correlations = stats::cor(d[bg_predictors]), precision_weight_cap = cap)
previous_path <- file.path(cfg$analytic_dir, "history/before_movers_age/model_results.rds")
if (file.exists(previous_path)) {
  previous <- readRDS(previous_path)
  stopifnot(identical(previous$data$GEOID, d$GEOID))
  comparison <- dplyr::left_join(
    previous$metrics[c("model", "r_squared")], metrics[c("model", "r_squared")],
    by = "model", suffix = c("_before", "_after")) |>
    dplyr::left_join(previous$cv$metrics[c("model", "predictive_R2")], by = "model") |>
    dplyr::rename(CV_R2_before = predictive_R2) |>
    dplyr::left_join(cv$metrics[c("model", "predictive_R2")], by = "model") |>
    dplyr::rename(CV_R2_after = predictive_R2)
  results$previous_comparison <- comparison
  readr::write_csv(comparison, file.path(cfg$output_dir, "renter_profile_update.csv"))
}
saveRDS(results, file.path(cfg$analytic_dir, "model_results.rds"))
for (name in c("metrics", "coefficients", "comparisons", "partition", "diagnostic_tests", "vif",
               "influence", "sensitivity_metrics", "sensitivity_coefficients", "loco", "communities", "description")) {
  readr::write_csv(results[[name]], file.path(cfg$output_dir, paste0(name, ".csv")))
}
readr::write_csv(cv$metrics, file.path(cfg$output_dir, "tract_blocked_cv.csv"))
readr::write_csv(cv$assignments, file.path(cfg$output_dir, "cv_assignments.csv"))
readr::write_csv(spatial$results, file.path(cfg$output_dir, "spatial_diagnostics.csv"))
inputs <- c(cfg$core_path, cfg$shape_path, cfg$city_path, cfg$community_path,
  file.path(cfg$analytic_dir, "source_counts.rds"), file.path(cfg$analytic_dir, "model_sample.rds"))
jsonlite::write_json(list(year = cfg$year, seed = cfg$seed, synthetic_data = SYNTHETIC_DATA,
  formulas = lapply(bg_formulas, function(x) paste(deparse(x), collapse = " ")),
  input_md5 = as.list(tools::md5sum(inputs)), confidence_model = cfg$confidence,
  confidence_ACS = .9, precision_cap = cap, geography = "Whole BG; >=50% polygon area in City; dominant community"),
  file.path(cfg$output_dir, "provenance.json"), auto_unbox = TRUE, pretty = TRUE)
print(metrics[c("model", "n", "r_squared", "adjusted_r_squared")], row.names = FALSE)
message("Saved block-group model results and diagnostics in ", cfg$output_dir)
