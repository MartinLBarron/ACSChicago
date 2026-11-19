# Publish aggregate model results, not R objects or PUMS housing-unit records.
source("R/bg_model_config.R")
cfg <- bg_model_config
r <- readRDS(file.path(cfg$analytic_dir, "model_results.rds"))
d <- r$data
model_names <- c(M0 = "Baseline", M1 = "Housing", M2a = "Housing + economic context",
                 M2 = "Housing + all context", M3 = "Adding community location")
specifications <- c(M0 = "Intercept only", M1 = "Bedrooms, building size and building age",
  M2a = "M1 + poverty, income and both education measures",
  M2 = "M2a + non-Hispanic Black and Hispanic/Latino population shares",
  M3 = "M2 + indicators for the 77 community areas")
metrics <- r$metrics[r$metrics$model %in% names(model_names), ]
metrics$label <- unname(model_names[metrics$model])
metrics$specification <- unname(specifications[metrics$model])
metrics$r_squared[abs(metrics$r_squared) < 1e-12] <- 0
metrics$adjusted_r_squared[abs(metrics$adjusted_r_squared) < 1e-12] <- 0
metrics <- dplyr::left_join(metrics, r$cv$metrics, by = "model")
metrics$predictive_R2[abs(metrics$predictive_R2) < 1e-12] <- 0
variables <- dplyr::bind_rows(lapply(bg_predictors, function(term) {
  income <- term == "log_income"
  source <- if (income) "income" else sub("_10pp$", "_pct", term)
  values <- d[[source]]
  q <- unname(stats::quantile(values, c(.05, .25, .5, .75, .95)))
  data.frame(term = term, label = sub(" \\(.+$", "", unname(bg_term_labels[term])),
    coefficient_label = unname(bg_term_labels[term]), unit = if (income) "dollars" else "percent",
    domain = if (term %in% bg_housing_terms) "Housing" else "Context",
    p05 = q[1], p25 = q[2], median = q[3], p75 = q[4], p95 = q[5])
}))
coefficients <- r$coefficients[r$coefficients$term %in% bg_predictors &
  r$coefficients$model %in% c("M1", "M2a", "M2", "M3"), ]
fit <- r$models$M3
points <- data.frame(community = d$community, observed = d$rent,
  fitted = exp(stats::fitted(fit)), residual = stats::residuals(fit),
  relative_moe = d$rent_relative_moe)
standardized <- sort(stats::rstandard(fit)[stats::hatvalues(fit) < 1 - 1e-8])
qq <- data.frame(theoretical = stats::qnorm(stats::ppoints(length(standardized))),
                 observed = standardized)
quantiles <- stats::quantile(standardized, c(.25,.75))
slope <- unname(diff(quantiles) / diff(stats::qnorm(c(.25,.75))))
intercept <- unname(quantiles[1] - slope * stats::qnorm(.25))
sensitivities <- r$sensitivity_metrics[c("sensitivity", "model", "n", "r_squared")]
sensitivities <- tidyr::pivot_wider(sensitivities, names_from = "model", values_from = "r_squared")
sensitivities$increment <- sensitivities$M3 - sensitivities$M2
payload <- list(
  version = 1L, period = "2020–2024", sample_n = nrow(d), communities_n = nlevels(d$community_id),
  majority_city_n = sum(r$all_data$majority_city), missing_rent_n = sum(r$all_data$majority_city & !is.finite(r$all_data$log_rent)),
  missing_income_n = sum(r$all_data$majority_city & is.finite(r$all_data$log_rent) & !is.finite(r$all_data$log_income)),
  singleton_n = sum(table(d$community_id) == 1), open_ended_rent_n = sum(!is.finite(d$rent_moe)),
  cv_excluded_n = r$cv$excluded_unseen, models = metrics, variables = variables, coefficients = coefficients,
  comparisons = r$comparisons, partition = r$partition, diagnostics = r$diagnostic_tests,
  spatial = r$spatial$results, spatial_graph = r$spatial$graph, sensitivity = sensitivities,
  points = points, qq = qq, qq_reference = list(slope = slope, intercept = intercept),
  sample_flow = r$sample_flow, synthetic_data = r$synthetic_data,
  notes = list(confidence_model = .95, confidence_acs = .90, primary_weighting = "Equal block groups",
               outcome = "Log median monthly contract rent", model_version = "Initial descriptive specification"))
out <- "html/data/web"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
path <- file.path(out, "block_group_model_2024.json")
jsonlite::write_json(payload, path, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = NA)
check <- jsonlite::read_json(path, simplifyVector = TRUE)
stopifnot(check$sample_n == stats::nobs(fit), !check$synthetic_data,
  nrow(check$coefficients) == nrow(coefficients),
  max(abs(check$models$r_squared - metrics$r_squared)) < 1e-12,
  max(abs(check$points$residual - stats::residuals(fit))) < 1e-12)
report <- file.path(cfg$output_dir, "report.html")
stopifnot(file.exists(report), file.copy(report, file.path(out, "block_group_model_report.html"), overwrite = TRUE))
message("Exported current block-group models, effects and diagnostics to ", path)
