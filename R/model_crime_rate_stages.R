# Primary four-stage website models, all on the same 2020–2024 block groups.
source("R/crime_stages_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")

baseline <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
areas <- readRDS(file.path(crime_config$analytic_dir, "model_sample.rds"))
population <- readRDS("data/analytic/model_display_2024/block_group_display.rds")
index <- match(areas$GEOID, population$GEOID)
stopifnot(identical(areas$GEOID, baseline$data$GEOID), !anyDuplicated(population$GEOID),
          !anyNA(index), all(population$acs_start_year[index] == 2020 & population$acs_end_year[index] == 2024),
          all(areas$violent_crime_count == population$violent_crime_count_estimate[index]))
areas$total_population <- population$total_population_estimate[index]
stopifnot(all(is.finite(areas$total_population) & areas$total_population > 0),
          identical(areas$total_population, areas$race_total_estimate))
areas$crime_rate <- population$crime_rate_estimate[index]
stopifnot(isTRUE(all.equal(areas$crime_rate, 1000 * areas$violent_crime_count / areas$total_population)))
contrast <- IQR(areas$crime_rate)

removed_terms <- c("structure_20_plus_10pp", "college_10pp")
housing <- setdiff(bg_housing_terms, removed_terms)
controls <- setdiff(bg_predictors, removed_terms)
formulas <- lapply(list(M1 = "crime_rate", M2 = c("crime_rate", housing),
  M3 = c("crime_rate", controls), M4 = c("crime_rate", controls, "community_id")),
  reformulate, response = "log_rent")
models <- lapply(formulas, lm, data = areas, na.action = na.fail)
stopifnot(all(vapply(models, nobs, integer(1)) == nrow(areas)),
          all(vapply(models, function(fit) fit$rank == length(coef(fit)), logical(1))))
fit_metrics <- function(fits) dplyr::bind_rows(lapply(names(fits), function(stage) bg_fit_summary(fits[[stage]], stage)))
cv <- ex_cv(areas, formulas, baseline$cv$assignments)
stopifnot(nrow(cv$failures) == 0, nrow(cv$metrics) == length(models))
metrics <- dplyr::left_join(fit_metrics(models), cv$metrics, by = "model")
coefficients <- dplyr::bind_rows(lapply(names(models), function(stage)
  bg_coefficient_table(models[[stage]], stage, areas, term_labels = c(bg_term_labels,
    crime_rate = "Five-year violent crime rate per 1,000 residents"))))
effects <- subset(coefficients, term == "crime_rate")
for (field in c("estimate","hc3_conf_low","hc3_conf_high","cluster_conf_low","cluster_conf_high"))
  effects[[paste0("percent_",field)]] <- 100 * expm1(contrast * effects[[field]])
diagnostics <- dplyr::bind_rows(lapply(names(models), function(stage)
  cbind(model = stage, ex_diagnostic(models[[stage]], areas, baseline$spatial$queen))))
vif <- dplyr::bind_rows(lapply(names(models), function(stage)
  bg_vif(models[[stage]], stage, c("crime_rate", controls))))
spatial <- dplyr::bind_rows(lapply(c("queen", "knn4"), function(rule)
  dplyr::bind_rows(lapply(names(models), function(stage) {
    test <- spdep::lm.morantest(models[[stage]], baseline$spatial[[rule]], alternative="two.sided", zero.policy=TRUE)
    data.frame(model=stage, weights=rule, Moran_I=unname(test$estimate[1]), p_value=test$p.value)
  }))))
subset_metrics <- function(keep) fit_metrics(lapply(formulas, lm, data=droplevels(areas[keep,]), na.action=na.fail))
out <- "output/models/block_group_crime_rate_2024"
dir.create(out, recursive=TRUE, showWarnings=FALSE)
results <- list(data=areas, models=models, formulas=formulas, cv=cv, metrics=metrics,
  coefficients=coefficients, effects=effects, contrast=contrast, removed_terms=removed_terms,
  diagnostics=diagnostics, vif=vif, spatial=spatial, sample_flow=baseline$sample_flow,
  strict_metrics=subset_metrics(areas$city_fraction >= bg_model_config$strict_city_share),
  closed_metrics=subset_metrics(is.finite(areas$rent_moe)), synthetic_data=baseline$synthetic_data)
saveRDS(results, file.path(out, "models.rds"))
for (field in c("metrics","coefficients","effects","diagnostics","vif","spatial","strict_metrics","closed_metrics"))
  readr::write_csv(results[[field]], file.path(out,paste0(field,".csv")))
