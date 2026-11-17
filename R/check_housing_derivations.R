# Small synthetic fixtures verify uncertainty calculations and undefined cases.
source("R/acs_config.R")
source("R/housing_derivation_helpers.R")
x <- data.frame(a_estimate = c(40, 40, 0, NA, 40, 110),
                a_moe = c(5, 2, 3, 2, NA, 5),
                total_estimate = c(100, 100, 0, 100, 100, 100),
                total_moe = rep(10, 6))
result <- derive_housing_percentage(x, list(numerator = "a", denominator = "total"))
stopifnot(result$estimate[1] == 40, isTRUE(all.equal(result$moe[1], 3)),
          result$moe_method[1] == "subset_proportion",
          isTRUE(all.equal(result$moe[2], sqrt(20))),
          result$moe_method[2] == "ratio_fallback",
          is.na(result$estimate[3]), result$estimate_status[3] == "zero_denominator",
          is.na(result$estimate[4]), result$estimate_status[4] == "missing_source_estimate",
          result$estimate[5] == 40, is.na(result$moe[5]),
          result$moe_status[5] == "missing_source_moe",
          is.na(result$estimate[6]), result$estimate_status[6] == "numerator_exceeds_denominator")
zeros <- data.frame(a_estimate = 0, a_moe = 3, b_estimate = 0, b_moe = 4,
                    c_estimate = 5, c_moe = 2)
summed <- sum_housing_components(zeros, c("a", "b", "c"))
stopifnot(summed$estimate == 5, isTRUE(all.equal(summed$moe, sqrt(20))))
zeros$b_moe <- NA_real_
stopifnot(is.na(sum_housing_components(zeros, c("a", "b", "c"))$moe))
message("Derived-percent, fallback, missing-data, zero-denominator, and zero-count MOE checks passed.")
