# Source counts: each group is a separate API request, preserving original caches.
housing_variable_groups <- list(
  burden = stats::setNames(paste0("B25070_", sprintf("%03d", 1:11)), c(
    "burden_total", "burden_lt10", "burden_10_14", "burden_15_19", "burden_20_24",
    "burden_25_29", "burden_30_34", "burden_35_39", "burden_40_49",
    "burden_50plus", "burden_not_computed"
  )),
  bedrooms = stats::setNames(paste0("B25042_", sprintf("%03d", 9:15)), c(
    "bedrooms_renter_total", "bedrooms_0", "bedrooms_1", "bedrooms_2",
    "bedrooms_3", "bedrooms_4", "bedrooms_5plus"
  )),
  utilities = c(utilities_total = "B25069_001", utilities_extra = "B25069_002",
                utilities_included = "B25069_003")
)
housing_variables <- do.call(c, unname(housing_variable_groups))
known_burden <- names(housing_variable_groups$burden)[2:10]
# Each numerator must be a subset of its denominator. Percent units are 0–100.
housing_derivations <- list(
  rent_burden_30plus_pct = list(
    numerator = c("burden_30_34", "burden_35_39", "burden_40_49", "burden_50plus"),
    denominator = known_burden),
  rent_burden_50plus_pct = list(numerator = "burden_50plus", denominator = known_burden),
  rent_burden_not_computed_pct = list(numerator = "burden_not_computed", denominator = "burden_total"),
  renter_bedrooms_0_pct = list(numerator = "bedrooms_0", denominator = "bedrooms_renter_total"),
  renter_bedrooms_1_pct = list(numerator = "bedrooms_1", denominator = "bedrooms_renter_total"),
  renter_bedrooms_2_pct = list(numerator = "bedrooms_2", denominator = "bedrooms_renter_total"),
  renter_bedrooms_3_pct = list(numerator = "bedrooms_3", denominator = "bedrooms_renter_total"),
  renter_bedrooms_4_pct = list(numerator = "bedrooms_4", denominator = "bedrooms_renter_total"),
  renter_bedrooms_5plus_pct = list(numerator = "bedrooms_5plus", denominator = "bedrooms_renter_total"),
  renter_bedrooms_3plus_pct = list(numerator = c("bedrooms_3", "bedrooms_4", "bedrooms_5plus"),
                                 denominator = "bedrooms_renter_total"),
  utilities_included_pct = list(numerator = "utilities_included", denominator = "utilities_total"),
  utilities_extra_pct = list(numerator = "utilities_extra", denominator = "utilities_total")
)
