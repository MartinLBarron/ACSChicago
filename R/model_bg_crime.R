# M5 adds exactly one untransformed count to the current M3, on identical cases.
source("R/crime_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")
cfg <- crime_config
dir.create(cfg$output_dir, recursive = TRUE, showWarnings = FALSE)
baseline <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
d <- readRDS(file.path(cfg$analytic_dir, "model_sample.rds"))
stopifnot(identical(d$GEOID, baseline$data$GEOID), all(is.finite(d$violent_crime_count)),
  all(d$violent_crime_count >= 0), all(d$violent_crime_count == as.integer(d$violent_crime_count)))
formulas <- list(M3 = bg_formulas$M3, M5 = crime_formula)
models <- lapply(formulas, stats::lm, data = d, na.action = stats::na.fail)
stopifnot(all(vapply(models, function(m) m$rank == length(stats::coef(m)), logical(1))),
  max(abs(stats::fitted(models$M3) - stats::fitted(baseline$models$M3))) < 1e-8)
metrics <- dplyr::bind_rows(lapply(names(models), function(name) bg_fit_summary(models[[name]], name)))
cv <- ex_cv(d, formulas, baseline$cv$assignments)
metrics <- dplyr::left_join(metrics, cv$metrics, by = "model")
labels <- c(bg_term_labels, violent_crime_count = "Recorded violent crime rows (+1 row over 2020–2024)")
coefficients <- dplyr::bind_rows(lapply(names(models), function(name) {
  bg_coefficient_table(models[[name]], name, d, term_labels = labels)
}))
crime_effect <- coefficients[coefficients$term == "violent_crime_count", ]
# Presentation contrasts only. The predictor in lm remains the literal raw count.
for (name in c("estimate", "hc3_conf_low", "hc3_conf_high", "cluster_conf_low", "cluster_conf_high")) {
  crime_effect[[paste0("percent_per100_", name)]] <- 100 * expm1(100 * crime_effect[[name]])
}
vif <- bg_vif(models$M5, "M5", predictors = c(bg_predictors, "violent_crime_count"))
diagnostics <- dplyr::bind_rows(lapply(names(models), function(name) {
  cbind(data.frame(model = name), ex_diagnostic(models[[name]], d, baseline$spatial$queen))
}))
spatial_rows <- list()
i <- 0L
for (rule in c("queen", "knn4")) {
  weights <- baseline$spatial[[rule]]
  for (name in names(models)) {
    i <- i + 1L; set.seed(cfg$seed + 200L + i)
    moran <- spdep::moran.mc(stats::residuals(models[[name]]), weights,
      nsim = bg_model_config$moran_permutations, alternative = "two.sided", zero.policy = TRUE)
    simulated <- moran$res[seq_len(bg_model_config$moran_permutations)]
    observed <- unname(moran$statistic)
    p <- min(1, 2 * min((1 + sum(simulated >= observed))/(length(simulated) + 1),
                        (1 + sum(simulated <= observed))/(length(simulated) + 1)))
    spatial_rows[[i]] <- data.frame(weights = rule, model = name, Moran_I = observed, permutation_p = p)
  }
}
influence <- data.frame(GEOID = d$GEOID, community = d$community,
  violent_crime_count = d$violent_crime_count, fitted = stats::fitted(models$M5),
  residual = stats::residuals(models$M5), leverage = stats::hatvalues(models$M5),
  studentized = stats::rstudent(models$M5), cooks_D = stats::cooks.distance(models$M5))
singleton <- table(d$community_id)[as.character(d$community_id)] == 1
influence[singleton, c("studentized", "cooks_D")] <- NA_real_
strict <- droplevels(d[d$city_fraction >= bg_model_config$strict_city_share, ])
strict_models <- lapply(formulas, stats::lm, data = strict, na.action = stats::na.fail)
strict_metrics <- dplyr::bind_rows(lapply(names(strict_models), function(name) bg_fit_summary(strict_models[[name]], name)))
strict_coefficients <- bg_coefficient_table(strict_models$M5, "M5_strict_city", strict, term_labels = labels)
strict_effect <- strict_coefficients[strict_coefficients$term == "violent_crime_count", ]
strict_effect$percent_per100_estimate <- 100 * expm1(100 * strict_effect$estimate)
strict_effect$percent_per100_hc3_conf_low <- 100 * expm1(100 * strict_effect$hc3_conf_low)
strict_effect$percent_per100_hc3_conf_high <- 100 * expm1(100 * strict_effect$hc3_conf_high)
# Influence stability; no observation is removed from the primary specification.
loco <- dplyr::bind_rows(lapply(levels(d$community_id), function(id) {
  fit <- stats::lm(crime_formula, data = droplevels(d[as.character(d$community_id) != id, ]))
  data.frame(omitted_community = id, crime_coefficient = unname(stats::coef(fit)["violent_crime_count"]))
}))
rsq <- stats::setNames(metrics$r_squared, metrics$model)
comparison <- data.frame(from = "M3", to = "M5", incremental_R2 = unname(rsq["M5"] - rsq["M3"]),
  partial_R2 = unname((rsq["M5"] - rsq["M3"])/(1 - rsq["M3"])))
results <- list(config = cfg, synthetic_data = SYNTHETIC_DATA, data = d, models = models, metrics = metrics,
  coefficients = coefficients, crime_effect = crime_effect, comparisons = comparison, cv = cv, vif = vif,
  diagnostics = diagnostics, spatial = dplyr::bind_rows(spatial_rows), influence = influence,
  strict_models = strict_models, strict_metrics = strict_metrics, strict_effect = strict_effect, loco = loco,
  audit = readRDS(file.path(cfg$analytic_dir, "geographic_audit.rds")),
  coverage = readr::read_csv(file.path(cfg$analytic_dir, "coverage_by_year_offense.csv"), show_col_types = FALSE),
  status = readr::read_csv(file.path(cfg$analytic_dir, "assignment_status.csv"), show_col_types = FALSE),
  iucr = readr::read_csv(file.path(cfg$analytic_dir, "iucr_definition.csv"),
    col_types = readr::cols(iucr = readr::col_character())))
saveRDS(results, file.path(cfg$analytic_dir, "model_results.rds"))
for (name in c("metrics", "coefficients", "crime_effect", "comparisons", "vif", "diagnostics", "spatial",
               "influence", "strict_metrics", "strict_effect", "loco")) {
  readr::write_csv(results[[name]], file.path(cfg$output_dir, paste0(name, ".csv")))
}
readr::write_csv(cv$predictions, file.path(cfg$output_dir, "cv_predictions.csv"))
paths <- c(file.path(bg_model_config$analytic_dir, "model_results.rds"),
  file.path(cfg$analytic_dir, c("model_sample.rds", "iucr_definition.csv", "block_group_counts.csv")),
  file.path(cfg$raw_dir, "manifest.csv"))
jsonlite::write_json(list(formula = paste(deparse(crime_formula), collapse = " "),
  input_md5 = as.list(tools::md5sum(paths)), seed = cfg$seed, synthetic_data = SYNTHETIC_DATA,
  crime_predictor = "Literal 2020–2024 violent_crime_count; no log, rate, annualization or predictor rescaling",
  geography = "Whole 2024 BGs; >=50% inside city, with >=99% sensitivity"),
  file.path(cfg$output_dir, "provenance.json"), auto_unbox = TRUE, pretty = TRUE)
print(metrics[c("model", "n", "r_squared", "adjusted_r_squared", "predictive_R2")], row.names = FALSE)
print(crime_effect[c("estimate", "percent_per100_estimate", "percent_per100_hc3_conf_low", "percent_per100_hc3_conf_high")], row.names = FALSE)
