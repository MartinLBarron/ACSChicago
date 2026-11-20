# Crime association first, followed by prespecified blocks of adjustment.
source("R/crime_stages_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")
cfg <- crime_stages_config
dir.create(cfg$analytic_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cfg$output_dir, recursive = TRUE, showWarnings = FALSE)
baseline <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
previous_crime <- readRDS(file.path(crime_config$analytic_dir, "model_results.rds"))
d <- readRDS(file.path(crime_config$analytic_dir, "model_sample.rds"))
stopifnot(identical(d$GEOID, baseline$data$GEOID), !anyNA(d$violent_crime_count))
models <- lapply(crime_stage_formulas, stats::lm, data = d, na.action = stats::na.fail)
stopifnot(all(vapply(models, function(m) m$rank == length(stats::coef(m)), logical(1))))
metrics <- dplyr::bind_rows(lapply(names(models), function(name) bg_fit_summary(models[[name]], name)))
metrics$r_squared[abs(metrics$r_squared) < 1e-12] <- 0
metrics$adjusted_r_squared[abs(metrics$adjusted_r_squared) < 1e-12] <- 0
cv <- ex_cv(d, crime_stage_formulas, baseline$cv$assignments)
metrics <- dplyr::left_join(metrics, cv$metrics, by = "model")
metrics$predictive_R2[abs(metrics$predictive_R2) < 1e-12] <- 0
metrics$specification <- unname(crime_stage_labels[metrics$model])
labels <- c(bg_term_labels, violent_crime_count = "Recorded violent rows (+1 row over 2020–2024)")
coefficients <- dplyr::bind_rows(lapply(names(models), function(name) {
  bg_coefficient_table(models[[name]], name, d, term_labels = labels)
}))
effects <- coefficients[coefficients$term == "violent_crime_count", ]
for (name in c("estimate", "hc3_conf_low", "hc3_conf_high", "cluster_conf_low", "cluster_conf_high")) {
  effects[[paste0("percent_per100_", name)]] <- 100 * expm1(100 * effects[[name]])
}
# Isolate crime's remaining fitted association at each adjustment level.
controls <- list(M1 = bg_formulas$M0, M2 = bg_formulas$M1, M3 = bg_formulas$M2, M4 = bg_formulas$M3)
crime_unique <- dplyr::bind_rows(lapply(names(controls), function(name) {
  control_fit <- stats::lm(controls[[name]], data = d)
  control_r2 <- bg_fit_summary(control_fit, "controls_only")$r_squared
  full_r2 <- metrics$r_squared[metrics$model == name]
  data.frame(model = name, controls_only_R2 = max(0, control_r2), total_R2 = full_r2,
    crime_incremental_R2 = full_r2 - control_r2, crime_partial_R2 = (full_r2 - control_r2)/(1 - control_r2))
}))
diagnostics <- dplyr::bind_rows(lapply(names(models)[-1], function(name) {
  cbind(data.frame(model = name), ex_diagnostic(models[[name]], d, baseline$spatial$queen))
}))
vif <- dplyr::bind_rows(lapply(names(models)[-1], function(name) {
  bg_vif(models[[name]], name, predictors = c("violent_crime_count", bg_predictors))
}))
spatial <- list(); i <- 0L
for (rule in c("queen", "knn4")) for (name in names(models)) {
  i <- i + 1L; set.seed(cfg$seed + 500L + i)
  mc <- spdep::moran.mc(stats::residuals(models[[name]]), baseline$spatial[[rule]],
    nsim = bg_model_config$moran_permutations, alternative = "two.sided", zero.policy = TRUE)
  draws <- mc$res[seq_len(bg_model_config$moran_permutations)]; observed <- unname(mc$statistic)
  p <- min(1, 2 * min((1 + sum(draws >= observed))/(length(draws) + 1),
                     (1 + sum(draws <= observed))/(length(draws) + 1)))
  spatial[[i]] <- data.frame(weights = rule, model = name, Moran_I = observed, permutation_p = p)
}
influence <- dplyr::bind_rows(lapply(names(models)[-1], function(name) {
  fit <- models[[name]]
  out <- data.frame(model = name, GEOID = d$GEOID, community = d$community,
    count = d$violent_crime_count, fitted = stats::fitted(fit), residual = stats::residuals(fit),
    standardized = stats::rstandard(fit), studentized = stats::rstudent(fit),
    leverage = stats::hatvalues(fit), cooks_D = stats::cooks.distance(fit))
  if (name == "M4") out[out$leverage >= 1 - 1e-8, c("standardized", "studentized", "cooks_D")] <- NA_real_
  out
}))
strict <- droplevels(d[d$city_fraction >= bg_model_config$strict_city_share, ])
strict_models <- lapply(crime_stage_formulas, stats::lm, data = strict, na.action = stats::na.fail)
strict_metrics <- dplyr::bind_rows(lapply(names(strict_models), function(name) bg_fit_summary(strict_models[[name]], name)))
strict_effects <- dplyr::bind_rows(lapply(names(strict_models)[-1], function(name) {
  z <- bg_coefficient_table(strict_models[[name]], name, strict, term_labels = labels)
  z <- z[z$term == "violent_crime_count", ]
  for (field in c("estimate", "hc3_conf_low", "hc3_conf_high")) z[[paste0("percent_per100_", field)]] <- 100 * expm1(100 * z[[field]])
  z
}))
results <- list(config = cfg, synthetic_data = SYNTHETIC_DATA, data = d, models = models,
  metrics = metrics, effects = effects, coefficients = coefficients, crime_unique = crime_unique,
  diagnostics = diagnostics, vif = vif, spatial = dplyr::bind_rows(spatial), influence = influence,
  cv = cv, strict_metrics = strict_metrics, strict_effects = strict_effects,
  sample_flow = baseline$sample_flow,
  audit = previous_crime$audit, coverage = previous_crime$coverage, iucr = previous_crime$iucr)
saveRDS(results, file.path(cfg$analytic_dir, "model_results.rds"))
for (name in c("metrics", "effects", "coefficients", "crime_unique", "diagnostics", "vif", "spatial", "influence", "strict_metrics", "strict_effects")) {
  readr::write_csv(results[[name]], file.path(cfg$output_dir, paste0(name, ".csv")))
}
readr::write_csv(cv$predictions, file.path(cfg$output_dir, "cv_predictions.csv"))
paths <- c(file.path(crime_config$analytic_dir, c("model_sample.rds", "model_results.rds")),
  file.path(bg_model_config$analytic_dir, "model_results.rds"))
jsonlite::write_json(list(input_md5 = as.list(tools::md5sum(paths)), seed = cfg$seed,
  formulas = lapply(crime_stage_formulas, function(f) paste(deparse(f), collapse = " ")),
  labeling = "Crime-focused M0–M4; final M4 equals previous crime-study M5",
  crime_predictor = "Untransformed five-year row count; no rates or predictor rescaling"),
  file.path(cfg$output_dir, "provenance.json"), auto_unbox = TRUE, pretty = TRUE)
print(metrics[c("model", "n", "r_squared", "predictive_R2")], row.names = FALSE)
print(effects[c("model", "percent_per100_estimate", "percent_per100_hc3_conf_low", "percent_per100_hc3_conf_high")], row.names = FALSE)
