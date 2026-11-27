# Population-weight sensitivity of the 2020–2024 five-year crime-rate models.
# After R/model_crime_rate_stages.R, run Rscript R/check_crime_rate_population_weights.R.
source("R/bg_model_config.R")
source("R/bg_model_helpers.R")

base_dir <- "output/models/block_group_crime_rate_2024"
reference <- readRDS(file.path(base_dir, "models.rds"))
areas <- reference$data
stopifnot(!anyDuplicated(areas$GEOID), all(is.finite(areas$total_population)),
          all(areas$total_population > 0))
weighted <- lapply(reference$formulas, function(f) {
  lm(f, data = areas, weights = total_population, na.action = na.fail)
})
# Hold the exposure contrast fixed at the original block-group IQR.
contrast <- IQR(areas$crime_rate)
labels <- c(bg_term_labels, crime_rate = "Five-year recorded violent crimes per 1,000 residents")
summarize_models <- function(models, weighting) {
  dplyr::bind_rows(lapply(names(models), function(stage) {
    fit <- models[[stage]]
    stopifnot(nobs(fit) == nrow(areas), fit$rank == length(coef(fit)))
    bg_coefficient_table(fit, stage, areas, term_labels = labels)
  })) |> dplyr::mutate(weighting = weighting)
}
coefficients <- dplyr::bind_rows(summarize_models(reference$models, "Equal"),
                                 summarize_models(weighted, "Population"))
effects <- subset(coefficients, term == "crime_rate")
for (field in c("estimate", "hc3_conf_low", "hc3_conf_high", "cluster_conf_low", "cluster_conf_high")) {
  effects[[paste0("iqr_pct_", field)]] <- 100 * expm1(contrast * effects[[field]])
}
# Score both sets of fits under each loss on exactly the same observations.
fit_scores <- function(models, weighting) {
  dplyr::bind_rows(lapply(names(models), function(stage) {
    residual <- residuals(models[[stage]])
    y <- areas$log_rent
    w <- areas$total_population
    data.frame(model = stage, weighting = weighting,
      equal_R2 = 1 - sum(residual^2) / sum((y - mean(y))^2),
      population_R2 = 1 - sum(w * residual^2) / sum(w * (y - weighted.mean(y, w))^2))
  }))
}
scores <- dplyr::bind_rows(fit_scores(reference$models, "Equal"), fit_scores(weighted, "Population"))
# Independently check the weighted M4 HC3 slope SE using its partial regression.
controls <- update(reference$formulas$M4, crime_rate ~ . - crime_rate)
partial_rate <- residuals(lm(controls, data = areas, weights = total_population))
fit <- weighted$M4
keep <- hatvalues(fit) < 1 - 1e-10
influence <- (areas$total_population * partial_rate * residuals(fit))[keep] / (1 - hatvalues(fit)[keep])
se <- sqrt(sum(influence^2)) / sum(areas$total_population * partial_rate^2)
reported <- subset(effects, model == "M4" & weighting == "Population")
stopifnot(isTRUE(all.equal(se, reported$hc3_se, tolerance = 1e-8)))
out <- file.path(base_dir, "population_weight_check")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(effects, file.path(out, "crime_effects.csv"))
readr::write_csv(coefficients, file.path(out, "coefficients.csv"))
readr::write_csv(scores, file.path(out, "fit.csv"))
print(effects[c("model","weighting","iqr_pct_estimate","iqr_pct_hc3_conf_low","iqr_pct_hc3_conf_high",
                "iqr_pct_cluster_conf_low","iqr_pct_cluster_conf_high","hc3_p_value")])
print(subset(scores, model == "M4"))
