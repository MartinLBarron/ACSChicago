# Publish aggregate model results, not R objects or PUMS housing-unit records.
source("R/crime_stages_config.R")
cfg <- crime_stages_config
cfg$analytic_dir <- "data/analytic/crime_stages_reduced_2024"
r <- readRDS(file.path(cfg$analytic_dir, "model_results.rds"))
d <- r$data
predictors <- setdiff(bg_predictors,r$removed_terms)
baseline <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
model_names <- c(M0="Baseline", M1="Violent crime", M2="Crime + housing/profile",
  M3="Adding socioeconomic context", M4="Adding community location")
specifications <- c(M0="Intercept only", M1="Violent-crime count",
  M2="M1 + bedrooms, building size/age, recent movers and renter householder age",
  M3="M2 + poverty, income, education and racial/ethnic composition",
  M4="M3 + indicators for the community areas")
metrics <- r$metrics[r$metrics$model %in% names(model_names), ]
metrics$label <- unname(model_names[metrics$model])
metrics$specification <- unname(specifications[metrics$model])
metrics$r_squared[abs(metrics$r_squared) < 1e-12] <- 0
metrics$adjusted_r_squared[abs(metrics$adjusted_r_squared) < 1e-12] <- 0

metrics$predictive_R2[abs(metrics$predictive_R2) < 1e-12] <- 0
# Conventional overall OLS F tests; keep log p-values to avoid numeric underflow.
overall_f <- dplyr::bind_rows(lapply(names(r$models),function(name) {
  statistic <- summary(r$models[[name]])$fstatistic
  if(is.null(statistic))return(data.frame(model=name,f_statistic=NA_real_,f_df1=NA_real_,f_df2=NA_real_,f_log10_p=NA_real_))
  data.frame(model=name,f_statistic=unname(statistic[1]),f_df1=unname(statistic[2]),f_df2=unname(statistic[3]),
    f_log10_p=unname(stats::pf(statistic[1],statistic[2],statistic[3],lower.tail=FALSE,log.p=TRUE)/log(10)))
}))
metrics <- dplyr::left_join(metrics,overall_f,by="model")
variables <- dplyr::bind_rows(lapply(predictors, function(term) {
  income <- term == "log_income"
  source <- if (income) "income" else sub("_10pp$", "_pct", term)
  values <- d[[source]]
  q <- unname(stats::quantile(values, c(.05, .25, .5, .75, .95)))
  data.frame(term = term, label = sub(" \\(.+$", "", unname(bg_term_labels[term])),
    coefficient_label = unname(bg_term_labels[term]), unit = if (income) "dollars" else "percent",
    domain = if (term %in% bg_housing_terms) "Housing" else "Context",
    p05 = q[1], p25 = q[2], median = q[3], p75 = q[4], p95 = q[5])
}))
coefficients <- r$coefficients[r$coefficients$term %in% predictors &
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
sensitivity_row <- function(metrics,label) {
  x<-tidyr::pivot_wider(metrics[c("model","n","r_squared")],names_from="model",values_from="r_squared")
  x$sensitivity<-label;x$increment<-x$M4-x$M3;x
}
sensitivities<-dplyr::bind_rows(sensitivity_row(r$strict_metrics,"At least 99% of area inside Chicago"),
  sensitivity_row(r$closed_metrics,"Exclude open-ended rent medians"))
crime_q <- unname(stats::quantile(d$violent_crime_count,c(.05,.25,.5,.75,.95)))
variables <- dplyr::bind_rows(data.frame(term="violent_crime_count",label="Recorded violent crimes",coefficient_label="Violent crime (+100 recorded crimes)",unit="count",domain="Crime",p05=crime_q[1],p25=crime_q[2],median=crime_q[3],p75=crime_q[4],p95=crime_q[5]),variables)
crime_coef <- r$coefficients[r$coefficients$term=="violent_crime_count",]
crime_coef$label <- "Violent crime (+100 recorded crimes)"
for (field in c("estimate","hc3_conf_low","hc3_conf_high","cluster_conf_low","cluster_conf_high"))
  crime_coef[[paste0("percent_",field)]] <- 100*expm1(100*crime_coef[[field]])
coefficients <- dplyr::bind_rows(crime_coef,coefficients)
diagnostic_rows <- dplyr::bind_rows(
  data.frame(model=r$diagnostics$model,test="Breusch–Pagan",statistic=r$diagnostics$BP_statistic,p_value=r$diagnostics$BP_p),
  data.frame(model=r$diagnostics$model,test="RESET (HC3)",statistic=NA_real_,p_value=r$diagnostics$RESET_p))
# Full raw log-rent coefficients for the academic model matrix, including intercepts/FE.
formal_coefficients <- r$coefficients[c("model","term","estimate","hc3_conf_low","hc3_conf_high","hc3_p_value","label")]
formal_coefficients$label[formal_coefficients$term=="(Intercept)"] <- "Intercept"
formal_coefficients$label[formal_coefficients$term=="log_income"] <- "Log median household income"
formal_coefficients$label[formal_coefficients$term=="violent_crime_count"] <- "Violent crime (one recorded row)"
reference_id <- r$models$M4$xlevels$community_id[1]
reference_community <- d$community[match(reference_id,as.character(d$community_id))]
community_rows <- grepl("^community_id",formal_coefficients$term)
community_ids <- sub("^community_id","",formal_coefficients$term[community_rows])
formal_coefficients$label[community_rows] <- paste("Community:",d$community[match(community_ids,as.character(d$community_id))])
stopifnot(!anyNA(formal_coefficients$label),!anyDuplicated(formal_coefficients[c("model","term")]))
# Publish only spatial comparisons matching the now-primary reduced specification.
spatial_models<-readRDS("data/analytic/spatial_sensitivity_2024/model_results.rds")
stopifnot(identical(spatial_models$data$GEOID,d$GEOID))
for(name in c("M3","M4"))for(rule in c("queen","knn4")) {
  comparison_fit<-spatial_models$fits[[paste("Drop both",name,rule,"OLS",sep=" / ")]]
  stopifnot(isTRUE(all.equal(coef(comparison_fit),coef(r$models[[name]]),check.attributes=FALSE)))
}
robustness<-list(metrics=spatial_models$metrics[spatial_models$metrics$spec=="Drop both",],
 effects=spatial_models$effects[spatial_models$effects$spec=="Drop both",],
 gmm=spatial_models$gmm[spatial_models$gmm$spec=="Drop both",])
payload <- list(
  version = 3L, period = "2020–2024", sample_n = nrow(d), communities_n = nlevels(d$community_id),
  majority_city_n = sum(baseline$all_data$majority_city), missing_rent_n = sum(baseline$all_data$majority_city & !is.finite(baseline$all_data$log_rent)),
  missing_income_n = sum(baseline$all_data$majority_city & is.finite(baseline$all_data$log_rent) & !is.finite(baseline$all_data$log_income)),
  singleton_n = sum(table(d$community_id) == 1), open_ended_rent_n = sum(!is.finite(d$rent_moe)),
  cv_excluded_n = r$cv$excluded_unseen, models = metrics, variables = variables, coefficients = coefficients,
  vif = r$vif, spatial_robustness = robustness, removed_terms = r$removed_terms, effects = r$effects, formal_coefficients = formal_coefficients, reference_community = reference_community, diagnostics = diagnostic_rows,
  spatial = r$spatial, spatial_graph = baseline$spatial$graph, sensitivity = sensitivities,
  points = points, qq = qq, qq_reference = list(slope = slope, intercept = intercept),
  sample_flow = r$sample_flow, synthetic_data = r$synthetic_data,
  previous_comparison = list(),
  notes = list(confidence_model = .95, confidence_acs = .90, primary_weighting = "Equal block groups",
               outcome = "Log median monthly contract rent", model_version = "Reduced crime-first M0–M4 · 2026-11-22"))
out <- "html/data/web"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
path <- file.path(out, "block_group_model_2024.json")
jsonlite::write_json(payload, path, dataframe = "rows", auto_unbox = TRUE, na = "null", digits = NA)
check <- jsonlite::read_json(path, simplifyVector = TRUE)
stopifnot(check$sample_n == stats::nobs(fit), !check$synthetic_data,
  nrow(check$coefficients) == nrow(coefficients),
  nrow(check$formal_coefficients) == nrow(r$coefficients),
  max(abs(check$formal_coefficients$estimate-r$coefficients$estimate)) < 1e-12,
  max(abs(check$models$r_squared - metrics$r_squared)) < 1e-12,
  max(abs(check$points$residual - stats::residuals(fit))) < 1e-12)
message("Exported current block-group models, effects and diagnostics to ", path)
