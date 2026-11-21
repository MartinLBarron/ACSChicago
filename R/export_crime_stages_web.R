# Publish aggregate model results, not R objects or PUMS housing-unit records.
source("R/crime_stages_config.R")
cfg <- crime_stages_config
r <- readRDS(file.path(cfg$analytic_dir, "model_results.rds"))
d <- r$data
baseline <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
model_names <- c(M0="Baseline", M1="Violent crime", M2="Crime + housing/profile",
  M3="Adding socioeconomic context", M4="Adding community location")
specifications <- c(M0="Intercept only", M1="Raw violent-crime count, 2020–2024",
  M2="M1 + bedrooms, building size/age, recent movers and renter householder age",
  M3="M2 + poverty, income, education and racial/ethnic composition",
  M4="M3 + indicators for the 77 community areas")
metrics <- r$metrics[r$metrics$model %in% names(model_names), ]
metrics$label <- unname(model_names[metrics$model])
metrics$specification <- unname(specifications[metrics$model])
metrics$r_squared[abs(metrics$r_squared) < 1e-12] <- 0
metrics$adjusted_r_squared[abs(metrics$adjusted_r_squared) < 1e-12] <- 0

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
  r$coefficients$model %in% c("M1", "M2a", "M2", "M3", "M4"), ]
fit <- r$models$M4
points <- data.frame(community = d$community, observed = d$rent,
  fitted = exp(stats::fitted(fit)), residual = stats::residuals(fit),
  relative_moe = d$rent_relative_moe)
standardized <- sort(stats::rstandard(fit)[stats::hatvalues(fit) < 1 - 1e-8])
qq <- data.frame(theoretical = stats::qnorm(stats::ppoints(length(standardized))),
                 observed = standardized)
quantiles <- stats::quantile(standardized, c(.25,.75))
slope <- unname(diff(quantiles) / diff(stats::qnorm(c(.25,.75))))
intercept <- unname(quantiles[1] - slope * stats::qnorm(.25))
sensitivities <- tidyr::pivot_wider(r$strict_metrics[c("model","n","r_squared")], names_from="model", values_from="r_squared")
sensitivities$sensitivity <- "At least 99% of area inside Chicago"
sensitivities$increment <- sensitivities$M4 - sensitivities$M3
crime_q <- unname(stats::quantile(d$violent_crime_count,c(.05,.25,.5,.75,.95)))
variables <- dplyr::bind_rows(data.frame(term="violent_crime_count",label="Recorded violent crimes",coefficient_label="Violent crime (+100 recorded rows)",unit="count",domain="Crime",p05=crime_q[1],p25=crime_q[2],median=crime_q[3],p75=crime_q[4],p95=crime_q[5]),variables)
crime_coef <- r$coefficients[r$coefficients$term=="violent_crime_count",]
crime_coef$label <- "Violent crime (+100 recorded rows)"
for (field in c("estimate","hc3_conf_low","hc3_conf_high","cluster_conf_low","cluster_conf_high"))
  crime_coef[[paste0("percent_",field)]] <- 100*expm1(100*crime_coef[[field]])
coefficients <- dplyr::bind_rows(crime_coef,coefficients)
diagnostic_rows <- dplyr::bind_rows(
  data.frame(model=r$diagnostics$model,test="Breusch–Pagan",statistic=r$diagnostics$BP_statistic,p_value=r$diagnostics$BP_p),
  data.frame(model=r$diagnostics$model,test="RESET (HC3)",statistic=NA_real_,p_value=r$diagnostics$RESET_p))
payload <- list(
  version = 2L, period = "2020–2024", sample_n = nrow(d), communities_n = nlevels(d$community_id),
  majority_city_n = sum(baseline$all_data$majority_city), missing_rent_n = sum(baseline$all_data$majority_city & !is.finite(baseline$all_data$log_rent)),
  missing_income_n = sum(baseline$all_data$majority_city & is.finite(baseline$all_data$log_rent) & !is.finite(baseline$all_data$log_income)),
  singleton_n = sum(table(d$community_id) == 1), open_ended_rent_n = sum(!is.finite(d$rent_moe)),
  cv_excluded_n = r$cv$excluded_unseen, models = metrics, variables = variables, coefficients = coefficients,
  effects = r$effects, diagnostics = diagnostic_rows,
  spatial = r$spatial, spatial_graph = baseline$spatial$graph, sensitivity = sensitivities,
  points = points, qq = qq, qq_reference = list(slope = slope, intercept = intercept),
  sample_flow = r$sample_flow, synthetic_data = r$synthetic_data,
  previous_comparison = list(),
  notes = list(confidence_model = .95, confidence_acs = .90, primary_weighting = "Equal block groups",
               outcome = "Log median monthly contract rent", model_version = "Crime-first M0–M4 · 2026-11-20"))
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
