# Approximate ACS margins of error for derived counts and subset percentages.
sum_housing_components <- function(x, variables) {
  estimates <- as.matrix(x[paste0(variables, "_estimate")])
  moes <- as.matrix(x[paste0(variables, "_moe")])
  estimate <- rowSums(estimates) # Missing source values propagate; never sum with na.rm.
  moe <- vapply(seq_len(nrow(x)), function(i) {
    if (anyNA(estimates[i, ]) || anyNA(moes[i, ])) return(NA_real_)
    # Census guidance: multiple zero-estimate cells contribute only their largest MOE.
    tidycensus::moe_sum(moes[i, ], estimate = estimates[i, ], na.rm = FALSE)
  }, numeric(1))
  data.frame(estimate = estimate, moe = moe)
}

derive_housing_percentage <- function(x, definition) {
  numerator <- sum_housing_components(x, definition$numerator)
  denominator <- sum_housing_components(x, definition$denominator)
  missing <- is.na(numerator$estimate) | is.na(denominator$estimate)
  zero <- !missing & denominator$estimate == 0
  exceeds <- !missing & !zero & numerator$estimate > denominator$estimate
  valid <- !missing & !zero & !exceeds
  estimate <- moe <- rep(NA_real_, nrow(x))
  estimate[valid] <- 100 * numerator$estimate[valid] / denominator$estimate[valid]
  valid_moe <- valid & !is.na(numerator$moe) & !is.na(denominator$moe)
  moe[valid_moe] <- 100 * tidycensus::moe_prop(
    numerator$estimate[valid_moe], denominator$estimate[valid_moe],
    numerator$moe[valid_moe], denominator$moe[valid_moe]
  )
  method <- rep("not_computed", nrow(x))
  # moe_prop uses the ratio approximation if the subset variance is nonpositive.
  subset_variance <- numerator$moe^2 -
    (numerator$estimate / denominator$estimate)^2 * denominator$moe^2
  method[valid_moe] <- ifelse(subset_variance[valid_moe] > 0,
                             "subset_proportion", "ratio_fallback")
  data.frame(
    estimate = estimate, moe = moe,
    numerator_estimate = numerator$estimate, numerator_moe = numerator$moe,
    denominator_estimate = denominator$estimate, denominator_moe = denominator$moe,
    estimate_status = ifelse(missing, "missing_source_estimate",
      ifelse(zero, "zero_denominator", ifelse(exceeds, "numerator_exceeds_denominator", "ok"))),
    moe_status = ifelse(!valid, "estimate_not_defined",
                        ifelse(!valid_moe, "missing_source_moe", "ok")),
    moe_method = method
  )
}

validate_housing_partitions <- function(x) {
  # Validate identities within tables, rather than mixing universes across tables.
  partitions <- list(
    occupied_units = c("owner_occupied_units", "tenure_renter_units"),
    burden_total = names(housing_variable_groups$burden)[-1]
  )
  for (total in names(partitions)) {
    components <- as.matrix(x[paste0(partitions[[total]], "_estimate")])
    summed <- rowSums(components)
    published <- x[[paste0(total, "_estimate")]]
    complete <- !is.na(summed) & !is.na(published)
    stopifnot(all(summed[complete] == published[complete]))
  }
}
