# Sampling, fit summaries, and ACS replicate-weight calculations for the rent models.
model_category <- function(x, variable) {
  code <- as.character(x[[variable]])
  label <- as.character(x[[paste0(variable, "_label")]])
  label[is.na(code) | code %in% c("", "b", "N") | grepl("^N/A", label)] <- NA_character_
  factor(label, ordered = FALSE)
}

prepare_rent_model_sample <- function(x) {
  d <- x
  d$housing_adjustment <- suppressWarnings(as.numeric(as.character(d$ADJHSG))) / 1e6
  d$contract_rent_2024 <- d$RNTP * d$housing_adjustment
  d$bedrooms <- d$BDSP
  d$rooms <- d$RMSP
  d$household_size <- d$NP
  d$building_size <- model_category(d, "BLD")
  d$year_built <- model_category(d, "YRBLT")
  d$puma <- factor(d$puma_geoid, levels = sort(unique(d$puma_geoid)))
  checks <- list(
    occupied_housing = !d$is_vacant & as.character(d$TYPEHUGQ) == "1",
    paying_cash_rent = as.character(d$TEN) == "3",
    positive_reported_rent = is.finite(d$RNTP) & d$RNTP > 0,
    valid_dollar_adjustment = is.finite(d$housing_adjustment) & d$housing_adjustment > 0,
    valid_controls = is.finite(d$bedrooms) & d$bedrooms >= 0 &
      is.finite(d$rooms) & d$rooms > 0 & is.finite(d$household_size) & d$household_size > 0 &
      !is.na(d$building_size) & !is.na(d$year_built) & !is.na(d$puma),
    positive_housing_weight = is.finite(d$WGTP) & d$WGTP > 0
  )
  remaining <- rep(TRUE, nrow(d))
  reason <- rep("included", nrow(d))
  waterfall <- data.frame(stage = "all_retained_puma_housing", remaining = nrow(d), excluded_at_stage = 0L)
  for (stage in names(checks)) {
    pass <- checks[[stage]]
    pass[is.na(pass)] <- FALSE
    failed <- remaining & !pass
    reason[failed] <- stage
    remaining <- remaining & pass
    waterfall <- rbind(waterfall, data.frame(stage = stage, remaining = sum(remaining),
                                            excluded_at_stage = sum(failed)))
  }
  audit <- data.frame(SERIALNO = d$SERIALNO, puma_geoid = d$puma_geoid,
                      included = remaining, reason = reason)
  sample <- droplevels(d[remaining, ])
  sample$log_contract_rent <- log(sample$contract_rent_2024)
  references <- list()
  for (variable in c("building_size", "year_built")) {
    totals <- tapply(sample$WGTP, sample[[variable]], sum)
    reference <- names(which.max(totals))
    sample[[variable]] <- stats::relevel(sample[[variable]], ref = reference)
    references[[variable]] <- reference
  }
  references$puma <- levels(sample$puma)[1]
  for (variable in c("building_size", "year_built", "puma")) {
    contrasts(sample[[variable]]) <- stats::contr.treatment(levels(sample[[variable]]))
  }
  rownames(sample) <- NULL
  stopifnot(nrow(sample) > 0, !anyDuplicated(sample$SERIALNO),
    all(is.finite(sample$log_contract_rent)), nlevels(sample$puma) == 18L)
  list(sample = sample, audit = audit, waterfall = waterfall, references = references)
}

coefficient_table <- function(fit, model, confidence) {
  beta <- stats::coef(fit)
  se <- sqrt(diag(stats::vcov(fit)))
  df <- fit$df.residual
  critical <- stats::qt((1 + confidence) / 2, df)
  result <- data.frame(model = model, term = names(beta), estimate = unname(beta),
    std_error = unname(se), df = df,
    conf_low = unname(beta - critical * se), conf_high = unname(beta + critical * se),
    p_value = unname(2 * stats::pt(-abs(beta / se), df)), confidence = confidence)
  for (suffix in c("estimate", "conf_low", "conf_high")) {
    result[[paste0("percent_", suffix)]] <- ifelse(result$term == "(Intercept)", NA_real_,
                                                   100 * expm1(result[[suffix]]))
  }
  result
}

weighted_fit <- function(y, fitted, weights) {
  center <- stats::weighted.mean(y, weights)
  sse <- sum(weights * (y - fitted)^2)
  sst <- sum(weights * (y - center)^2)
  c(sse = sse, sst = sst, r_squared = 1 - sse / sst,
    rmse_log = sqrt(sse / sum(weights)))
}

replicate_coefficients <- function(fit) {
  beta <- as.matrix(fit$replicates)
  stopifnot(nrow(beta) == 80L, ncol(beta) == length(stats::coef(fit)),
            all(is.finite(beta)))
  # survey returns replicate coefficients in model-column order without names.
  colnames(beta) <- names(stats::coef(fit))
  beta
}

replicate_fit_measures <- function(fit, sample, replicate_weights) {
  matrix <- stats::model.matrix(fit)
  beta <- replicate_coefficients(fit)
  stopifnot(ncol(beta) == ncol(matrix))
  beta <- beta[, names(stats::coef(fit)), drop = FALSE]
  result <- vapply(seq_len(80), function(i) {
    prediction <- drop(matrix %*% beta[i, ])
    weighted_fit(sample$log_contract_rent, prediction, replicate_weights[, i])
  }, numeric(4))
  t(result)
}

replicate_interval <- function(estimate, replicates, scale, df, confidence) {
  estimate <- unname(estimate)
  stopifnot(all(is.finite(replicates)), is.finite(estimate))
  se <- sqrt(scale * sum((replicates - estimate)^2))
  critical <- stats::qt((1 + confidence) / 2, df)
  c(estimate = estimate, std_error = se, conf_low = estimate - critical * se,
    conf_high = estimate + critical * se)
}

puma_contrasts <- function(fit, sample, replicate_weights, config) {
  # Isolate the PUMA component with a common housing profile; the common
  # non-PUMA terms cancel on centering. Replicate centering includes uncertainty
  # in the weighted distribution of cash-rent units across the PUMAs.
  levels <- levels(sample$puma)
  profile <- sample[rep(1, length(levels)), ]
  profile$puma <- factor(levels, levels = levels)
  contrasts(profile$puma) <- stats::contr.treatment(levels)
  matrix <- stats::model.matrix(stats::delete.response(stats::terms(fit)), profile,
                                contrasts.arg = fit$contrasts)
  matrix <- matrix[, names(stats::coef(fit)), drop = FALSE]
  raw_effect <- drop(matrix %*% stats::coef(fit))
  full_totals <- vapply(levels, function(id) sum(sample$WGTP[sample$puma == id]), numeric(1))
  shares <- full_totals / sum(full_totals)
  centered <- raw_effect - sum(shares * raw_effect)
  replicate_beta <- replicate_coefficients(fit)
  estimates <- vapply(seq_len(80), function(i) {
    component <- drop(matrix %*% replicate_beta[i, ])
    totals <- vapply(levels, function(id) sum(replicate_weights[sample$puma == id, i]), numeric(1))
    stopifnot(all(totals > 0))
    component - stats::weighted.mean(component, totals)
  }, numeric(length(levels)))
  intervals <- t(vapply(seq_along(levels), function(i) {
    replicate_interval(centered[i], estimates[i, ], config$replicate_scale,
                       fit$df.residual, config$confidence)
  }, numeric(4)))
  result <- data.frame(puma_geoid = levels,
    puma_name = sample$puma_name[match(levels, sample$puma_geoid)],
    sample_units = as.integer(table(sample$puma)[levels]), weighted_units = full_totals,
    share = shares, intervals, row.names = NULL)
  result$percent_difference <- 100 * expm1(result$estimate)
  result$percent_conf_low <- 100 * expm1(result$conf_low)
  result$percent_conf_high <- 100 * expm1(result$conf_high)
  stopifnot(abs(sum(shares * result$estimate)) < 1e-10)
  list(table = result, replicates = estimates)
}

residual_bins <- function(fit, sample, bins = 20L) {
  fitted <- stats::fitted(fit)
  residual <- sample$log_contract_rent - fitted
  order <- order(fitted)
  cumulative <- cumsum(sample$WGTP[order]) / sum(sample$WGTP)
  cutpoints <- unique(stats::approx(c(0, cumulative), c(fitted[order[1]], fitted[order]),
    xout = seq(0, 1, length.out = bins + 1), method = "constant", f = 0)$y)
  group <- findInterval(fitted, cutpoints, all.inside = TRUE)
  dplyr::bind_rows(lapply(sort(unique(group)), function(bin) {
    included <- group == bin
    data.frame(bin = bin, sample_units = sum(included),
      fitted_log_rent = stats::weighted.mean(fitted[included], sample$WGTP[included]),
      mean_log_residual = stats::weighted.mean(residual[included], sample$WGTP[included]),
      rmse_log = sqrt(stats::weighted.mean(residual[included]^2, sample$WGTP[included])))
  }))
}
