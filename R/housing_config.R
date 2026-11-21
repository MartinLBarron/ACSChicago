# Source counts for rent burden and renter share of occupied housing.
# Bedroom and utility-payment summary measures are retired.
housing_variable_groups <- list(
  tenure = c(occupied_units = "B25003_001", owner_occupied_units = "B25003_002",
             tenure_renter_units = "B25003_003"),
  burden = stats::setNames(paste0("B25070_", sprintf("%03d", 1:11)), c(
    "burden_total", "burden_lt10", "burden_10_14", "burden_15_19", "burden_20_24",
    "burden_25_29", "burden_30_34", "burden_35_39", "burden_40_49",
    "burden_50plus", "burden_not_computed"
  ))
)
housing_variables <- do.call(c, unname(housing_variable_groups))
known_burden <- names(housing_variable_groups$burden)[2:10]
housing_derivations <- list(
  renter_occupied_pct = list(numerator = "tenure_renter_units", denominator = "occupied_units"),
  rent_burden_30plus_pct = list(numerator = c("burden_30_34", "burden_35_39", "burden_40_49", "burden_50plus"), denominator = known_burden),
  rent_burden_50plus_pct = list(numerator = "burden_50plus", denominator = known_burden)
)
housing_display_variables <- function(core_variables) {
  c(names(core_variables), names(housing_derivations))
}
