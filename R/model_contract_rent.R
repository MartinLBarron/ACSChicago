# Fit agreed descriptive cash-rent models using ACS housing/replicate weights.
source("R/rent_model_config.R")
source("R/rent_model_helpers.R")
if (!requireNamespace("survey", quietly = TRUE)) stop("Install survey; see packages.txt.")
config <- rent_model_config
if (!file.exists(config$input)) stop("Run the PUMS download/preparation stages first.")
x <- readRDS(config$input)
stopifnot(all(x$acs_end_year == 2024L), all(x$puma_definition_year == 2020L))
prepared <- prepare_rent_model_sample(x)
sample <- prepared$sample
saveRDS(sample, config$sample_path)
readr::write_csv(prepared$audit, config$audit_path)
dir.create(config$output_dir, recursive = TRUE, showWarnings = FALSE)
write_result <- function(x, name) readr::write_csv(x, file.path(config$output_dir, paste0(name, ".csv")))
write_result(prepared$waterfall, "sample_flow")
write_result(sample |> dplyr::count(puma_geoid, puma_name, name = "sample_units"), "sample_by_puma")
category_counts <- dplyr::bind_rows(lapply(c("building_size", "year_built"), function(variable) {
  data.frame(variable = variable, category = levels(sample[[variable]]),
    sample_units = as.integer(table(sample[[variable]])),
    weighted_units = as.numeric(tapply(sample$WGTP, sample[[variable]], sum)))
}))
category_counts$sparse_under_30 <- category_counts$sample_units < 30
write_result(category_counts, "category_counts")
replicate_weights <- as.matrix(sample[paste0("WGTP", 1:80)])
stopifnot(all(is.finite(replicate_weights)))
design <- survey::svrepdesign(data = sample, weights = ~WGTP,
  repweights = replicate_weights, type = "ACS", combined.weights = TRUE, mse = TRUE)
stopifnot(isTRUE(all.equal(design$scale, config$replicate_scale)))
stopifnot(isTRUE(design$mse), all(design$rscales == 1))
models <- list()
fit_rows <- list()
replicate_stats <- list()
for (name in names(config$formulas)) {
  message("Fitting contract-rent model: ", name)
  fit <- survey::svyglm(config$formulas[[name]], design = design,
    family = stats::gaussian(), na.action = stats::na.fail, return.replicates = TRUE)
  stopifnot(fit$converged, all(is.finite(stats::coef(fit))),
    all(is.finite(stats::vcov(fit))), fit$df.residual > 0,
    stats::nobs(fit) == nrow(sample))
  models[[name]] <- fit
  metrics <- weighted_fit(sample$log_contract_rent, stats::fitted(fit), sample$WGTP)
  fit_rows[[name]] <- data.frame(model = name, sample_units = nrow(sample),
    weighted_units = sum(sample$WGTP), parameters = length(stats::coef(fit)),
    design_df = survey::degf(design), residual_df = fit$df.residual, t(metrics))
  replicate_stats[[name]] <- replicate_fit_measures(fit, sample, replicate_weights)
}
fit_table <- dplyr::bind_rows(fit_rows)
write_result(fit_table, "model_fit")
write_result(dplyr::bind_rows(lapply(names(models), function(name) {
  coefficient_table(models[[name]], name, config$confidence)
})), "coefficients")
full <- models$housing_puma
beta_replicates <- replicate_coefficients(full)
# Independently verify the package's covariance scaling and MSE centering.
centered <- sweep(beta_replicates, 2, stats::coef(full), "-")
manual_covariance <- config$replicate_scale * crossprod(centered)
stopifnot(identical(dim(manual_covariance), dim(stats::vcov(full))),
  isTRUE(all.equal(as.numeric(manual_covariance), as.numeric(stats::vcov(full)), tolerance = 1e-7)))
reduced <- fit_table[fit_table$model == "housing", ]
expanded <- fit_table[fit_table$model == "housing_puma", ]
stopifnot(expanded$r_squared >= reduced$r_squared - 1e-10)
point <- c(r_squared_housing = reduced$r_squared, r_squared_housing_puma = expanded$r_squared,
  delta_r_squared = expanded$r_squared - reduced$r_squared,
  partial_r_squared_puma = 1 - expanded$sse / reduced$sse)
replicate_points <- cbind(
  r_squared_housing = replicate_stats$housing[, "r_squared"],
  r_squared_housing_puma = replicate_stats$housing_puma[, "r_squared"],
  delta_r_squared = replicate_stats$housing_puma[, "r_squared"] - replicate_stats$housing[, "r_squared"],
  partial_r_squared_puma = 1 - replicate_stats$housing_puma[, "sse"] / replicate_stats$housing[, "sse"])
comparison <- dplyr::bind_rows(lapply(names(point), function(metric) {
  values <- replicate_interval(point[[metric]], replicate_points[, metric],
    config$replicate_scale, full$df.residual, config$confidence)
  data.frame(metric = metric, as.list(values), confidence = config$confidence)
}))
write_result(comparison, "puma_incremental_fit")
test <- survey::regTermTest(full, ~puma, method = "Wald")
write_result(data.frame(term = "puma", F = unname(test$Ftest), numerator_df = test$df,
  denominator_df = test$ddf, p_value = unname(test$p)), "puma_joint_test")
contrasts <- puma_contrasts(full, sample, replicate_weights, config)
write_result(contrasts$table, "adjusted_puma_effects")
bins <- residual_bins(full, sample)
write_result(bins, "residual_diagnostics")
# Check rank and leverage without changing the agreed model or trimming units.
matrix <- stats::model.matrix(full)
weighted_matrix <- matrix * sqrt(sample$WGTP)
stopifnot(qr(weighted_matrix)$rank == ncol(matrix))
leverage <- rowSums((weighted_matrix %*% solve(crossprod(weighted_matrix))) * weighted_matrix)
diagnostic_summary <- data.frame(rank = ncol(matrix),
  weighted_condition_number = kappa(weighted_matrix), max_leverage = max(leverage),
  rent_allocation_records = sum(as.character(sample$FRNTP) == "1", na.rm = TRUE),
  sparse_categories_under_30 = sum(category_counts$sparse_under_30))
write_result(diagnostic_summary, "model_diagnostics")
saveRDS(list(models = models, puma_effect_replicates = contrasts$replicates,
  fit_replicates = replicate_stats, configuration = config),
  file.path(config$output_dir, "models.rds"))
jsonlite::write_json(list(
  input = config$input, input_md5 = unname(tools::md5sum(config$input)),
  sample_md5 = unname(tools::md5sum(config$sample_path)),
  formulas = lapply(config$formulas, function(f) paste(deparse(f), collapse = " ")),
  references = prepared$references, confidence = config$confidence,
  survey_version = as.character(utils::packageVersion("survey")),
  design = "ACS SDR, combined weights, MSE centered at full estimate, 4/80",
  dollar_adjustment = "RNTP * as.numeric(ADJHSG) / 1000000, applied once",
  synthetic_data = SYNTHETIC_DATA
), file.path(config$output_dir, "model_metadata.json"), auto_unbox = TRUE, pretty = TRUE)
source("R/report_contract_rent.R")
message("Contract-rent models complete: ", nrow(sample), " units, ", nlevels(sample$puma), " PUMAs")
