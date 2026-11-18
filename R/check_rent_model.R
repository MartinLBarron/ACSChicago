# Validate stored model results against an independent weighted least-squares fit.
# Logs contain only aggregate checks, never individual microdata rows.
source("R/rent_model_config.R")
source("R/rent_model_helpers.R")
config <- rent_model_config
stored <- readRDS(file.path(config$output_dir, "models.rds"))
sample <- readRDS(config$sample_path)
audit <- readr::read_csv(config$audit_path, show_col_types = FALSE)
metadata <- jsonlite::read_json(file.path(config$output_dir, "model_metadata.json"))
stopifnot(metadata$input_md5 == unname(tools::md5sum(config$input)),
  metadata$sample_md5 == unname(tools::md5sum(config$sample_path)),
  !anyDuplicated(sample$SERIALNO), nrow(sample) == sum(audit$included),
  all(!sample$is_vacant), all(as.character(sample$TEN) == "3"),
  all(sample$RNTP > 0), all(sample$WGTP > 0), nlevels(sample$puma) == 18,
  isTRUE(all.equal(sample$contract_rent_2024,
    sample$RNTP * as.numeric(as.character(sample$ADJHSG)) / 1e6)),
  isTRUE(all.equal(sample$log_contract_rent, log(sample$contract_rent_2024))))
for (name in names(stored$models)) {
  fit <- stored$models[[name]]
  independently_fitted <- stats::lm(config$formulas[[name]], data = sample,
                                   weights = WGTP, na.action = stats::na.fail)
  stopifnot(isTRUE(all.equal(stats::coef(fit), stats::coef(independently_fitted), tolerance = 1e-9)),
    length(stats::fitted(fit)) == nrow(sample))
  beta <- replicate_coefficients(fit)
  covariance <- config$replicate_scale * crossprod(sweep(beta, 2, stats::coef(fit), "-"))
  stopifnot(isTRUE(all.equal(as.numeric(covariance), as.numeric(stats::vcov(fit)), tolerance = 1e-8)))
}
fits <- readr::read_csv(file.path(config$output_dir, "model_fit.csv"), show_col_types = FALSE)
stopifnot(all(fits$sample_units == nrow(sample)), fits$r_squared[2] > fits$r_squared[1],
  all(fits$r_squared >= 0 & fits$r_squared <= 1))
effects <- readr::read_csv(file.path(config$output_dir, "adjusted_puma_effects.csv"), show_col_types = FALSE)
stopifnot(nrow(effects) == 18, all(is.finite(effects$std_error)),
  abs(sum(effects$share * effects$estimate)) < 1e-10,
  all(effects$conf_low <= effects$estimate), all(effects$conf_high >= effects$estimate),
  isTRUE(all.equal(effects$percent_difference, 100 * expm1(effects$estimate))))
replicate_weights <- as.matrix(sample[paste0("WGTP", 1:80)])
# Centering must also hold separately within each replicate's area distribution.
for (i in seq_len(80)) {
  shares <- vapply(effects$puma_geoid, function(id) sum(replicate_weights[sample$puma_geoid == id, i]), numeric(1))
  shares <- shares / sum(shares)
  stopifnot(abs(sum(shares * stored$puma_effect_replicates[, i])) < 1e-9)
}
message("Rent-model checks passed: common sample, one dollar adjustment, WLS estimates, ",
        "ACS covariance, nested fit, and full/replicate PUMA centering.")
