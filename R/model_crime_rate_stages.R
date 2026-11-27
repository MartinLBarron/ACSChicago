# Analysis-only refinement of the current reduced M0–M4 contract-rent models.
# Run from the project root with Rscript R/model_crime_rate_stages.R.
source("R/bg_model_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")

counts <- readRDS("data/analytic/crime_stages_reduced_2024/model_results.rds")
baseline <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
population <- readRDS("data/analytic/model_display_2024/block_group_display.rds")
areas <- counts$data
index <- match(areas$GEOID, population$GEOID)
stopifnot(!anyDuplicated(population$GEOID), !anyNA(index),
          identical(areas$GEOID, baseline$data$GEOID),
          all(population$acs_start_year[index] == 2020 & population$acs_end_year[index] == 2024),
          all(areas$violent_crime_count == population$violent_crime_count_estimate[index]))
areas$total_population <- population$total_population_estimate[index]
stopifnot(all(is.finite(areas$total_population) & areas$total_population > 0),
          identical(areas$total_population, areas$race_total_estimate))
areas$crime_rate <- 1000 * areas$violent_crime_count / areas$total_population

formulas <- counts$formulas
for (stage in names(formulas)[-1]) {
  formulas[[stage]] <- update(formulas[[stage]], . ~ . - violent_crime_count + crime_rate)
}
models <- lapply(formulas, lm, data = areas, na.action = na.fail)
stopifnot(all(vapply(models, nobs, integer(1)) == nrow(areas)),
          all(vapply(models, function(fit) fit$rank == length(coef(fit)), logical(1))),
          identical(coef(models$M0), coef(counts$models$M0)))

cv <- ex_cv(areas, formulas, baseline$cv$assignments)
keys <- c("model", "fold", "GEOID", "observed")
stopifnot(nrow(cv$failures) == 0, identical(cv$predictions[keys], counts$cv$predictions[keys]))
fit <- dplyr::bind_rows(lapply(names(models), function(stage) bg_fit_summary(models[[stage]], stage))) |>
  dplyr::left_join(cv$metrics, by = "model")
metrics <- dplyr::inner_join(counts$metrics, fit, by = "model", suffix = c("_count", "_rate"))

labels <- c(bg_term_labels, crime_rate = "Recorded violent crimes per 1,000 residents over five years")
coefficients <- dplyr::bind_rows(lapply(names(models), function(stage) {
  bg_coefficient_table(models[[stage]], stage, areas, term_labels = labels)
}))
# Same percentile contrast for predictors with different units.
crime_effects <- function(table, term, values) {
  rows <- table[table$term == term, ]
  rows$interquartile_range <- IQR(values)
  for (field in c("estimate", "hc3_conf_low", "hc3_conf_high", "cluster_conf_low", "cluster_conf_high")) {
    rows[[paste0("iqr_pct_", field)]] <- 100 * expm1(rows$interquartile_range * rows[[field]])
  }
  rows
}
effects <- dplyr::bind_rows(
  crime_effects(counts$coefficients, "violent_crime_count", areas$violent_crime_count),
  crime_effects(coefficients, "crime_rate", areas$crime_rate)
)
control_comparison <- dplyr::inner_join(counts$coefficients, coefficients,
  by = c("model", "term"), suffix = c("_count", "_rate"))
diagnostics <- dplyr::bind_rows(lapply(names(models)[-1], function(stage) {
  cbind(model = stage, ex_diagnostic(models[[stage]], areas, baseline$spatial$queen))
}))
out <- "output/models/block_group_crime_rate_2024"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
saveRDS(list(data = areas, models = models, formulas = formulas, cv = cv,
             synthetic_data = counts$synthetic_data), file.path(out, "models.rds"))
for (name in c("metrics", "coefficients", "effects", "control_comparison", "diagnostics")) {
  readr::write_csv(get(name), file.path(out, paste0(name, ".csv")))
}
print(metrics[c("model", "r_squared_count", "r_squared_rate", "predictive_R2_count", "predictive_R2_rate")])
print(effects[c("model", "term", "interquartile_range", "iqr_pct_estimate", "iqr_pct_hc3_conf_low",
                "iqr_pct_hc3_conf_high", "iqr_pct_cluster_conf_low", "iqr_pct_cluster_conf_high")])
