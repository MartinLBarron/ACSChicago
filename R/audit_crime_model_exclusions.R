# Audit 2020–2024 block-group exclusions against the fitted crime-rate sample.
source("R/bg_model_config.R")
all_areas <- readRDS(file.path(bg_model_config$analytic_dir, "all_bg_model_data.rds"))
out <- "output/models/block_group_crime_rate_2024"
fitted_ids <- readRDS(file.path(out, "models.rds"))$data$GEOID
stopifnot(!anyDuplicated(all_areas$GEOID), !anyDuplicated(fitted_ids),
          setequal(all_areas$GEOID[all_areas$model_included], fitted_ids))
audit <- all_areas |>
  dplyr::transmute(GEOID, community, city_fraction, majority_city,
    included = GEOID %in% fitted_ids, exclusion_reason,
    population = race_total_estimate, households = occupied_units_estimate,
    rental_units = renter_occupied_units_estimate, cash_rent_units = cash_units,
    median_contract_rent = rent, median_household_income = income,
    rent_annotation = median_contract_rent_estimate_annotation,
    income_annotation = area_median_income_estimate_annotation,
    missing_median = dplyr::case_when(
      is.na(rent) & is.na(income) ~ "Both",
      is.na(rent) ~ "Rent only", is.na(income) ~ "Income only",
      TRUE ~ "Neither"))
eligible <- subset(audit, majority_city)
stopifnot(all(eligible$included == (eligible$missing_median == "Neither")),
          all(eligible$rent_annotation[is.na(eligible$median_contract_rent)] == "-"),
          all(eligible$income_annotation[is.na(eligible$median_household_income)] == "-"))
readr::write_csv(audit, file.path(out, "block_group_inclusion_audit.csv"))
print(eligible |> dplyr::group_by(missing_median) |>
  dplyr::summarise(areas = dplyr::n(), zero_population = sum(population == 0),
    zero_households = sum(households == 0), zero_rentals = sum(rental_units == 0),
    zero_cash_rent_units = sum(cash_rent_units == 0), median_cash_rent_units = median(cash_rent_units)))
