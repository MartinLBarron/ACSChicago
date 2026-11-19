# Agreed 2020–2024 block-group study; independent of the housing-unit PUMS model.
source("R/acs_config.R")
bg_model_config <- list(
  year = 2024L, seed = 3300L, confidence = .95,
  city_min_share = .5, strict_city_share = .99, unambiguous_community_share = .8,
  moran_permutations = 999L, cv_folds = 5L,
  raw_dir = "data/raw_data/bg_model_2024_v1",
  analytic_dir = "data/analytic/bg_model_2024",
  output_dir = "output/models/block_group_rent_2024",
  core_path = "data/analytic/acs_2024/block_group_housing.rds",
  shape_path = "data/shape/acs_2024/chicago_bg.gpkg",
  city_path = "data/raw_data/chicago_city.geojson",
  community_path = "data/raw_data/chicago_community_areas.geojson"
)
bg_codes <- function(table, indices, aliases) stats::setNames(
  paste0(table, "_", sprintf("%03d", indices)), aliases)
bg_variable_groups <- list(
  bedrooms = bg_codes("B25042", 9:15,
    c("bed_total", "bed_studio", "bed_one", "bed_two", "bed_three", "bed_four", "bed_five_plus")),
  structures = bg_codes("B25032", 13:23,
    c("structure_total", "structure_detached", "structure_attached", "structure_two",
      "structure_three_four", "structure_five_nine", "structure_ten_nineteen",
      "structure_twenty_fortynine", "structure_fifty_plus", "structure_mobile", "structure_other")),
  age = bg_codes("B25036", 13:23,
    c("age_total", "age_2020_plus", "age_2010s", "age_2000s", "age_1990s", "age_1980s",
      "age_1970s", "age_1960s", "age_1950s", "age_1940s", "age_pre1940")),
  poverty = bg_codes("C17002", 1:3, c("poverty_universe", "poverty_below_half", "poverty_half_to_one")),
  income = c(area_median_income = "B19013_001"),
  education = bg_codes("B15003", c(1:16, 22:25),
    c("education_universe", paste0("education_lesshs_", 2:16), paste0("education_college_", 22:25))),
  race = bg_codes("B03002", c(1, 3, 4, 6, 12),
    c("race_total", "race_nh_white", "race_nh_black", "race_nh_asian", "race_hispanic"))
)
bg_share_definitions <- list(
  small_bedrooms = list(numerator = c("bed_studio", "bed_one"), denominator = "bed_total"),
  large_bedrooms = list(numerator = c("bed_three", "bed_four", "bed_five_plus"), denominator = "bed_total"),
  structure_2_4 = list(numerator = c("structure_two", "structure_three_four"), denominator = "structure_total"),
  structure_5_19 = list(numerator = c("structure_five_nine", "structure_ten_nineteen"), denominator = "structure_total"),
  structure_20_plus = list(numerator = c("structure_twenty_fortynine", "structure_fifty_plus"), denominator = "structure_total"),
  structure_other = list(numerator = c("structure_mobile", "structure_other"), denominator = "structure_total"),
  pre1940 = list(numerator = "age_pre1940", denominator = "age_total"),
  built2000_plus = list(numerator = c("age_2020_plus", "age_2010s", "age_2000s"), denominator = "age_total"),
  poverty = list(numerator = c("poverty_below_half", "poverty_half_to_one"), denominator = "poverty_universe"),
  college = list(numerator = paste0("education_college_", 22:25), denominator = "education_universe"),
  no_high_school = list(numerator = paste0("education_lesshs_", 2:16), denominator = "education_universe"),
  nh_black = list(numerator = "race_nh_black", denominator = "race_total"),
  hispanic = list(numerator = "race_hispanic", denominator = "race_total")
)
bg_housing_terms <- paste0(c("small_bedrooms", "large_bedrooms", "structure_2_4", "structure_5_19",
  "structure_20_plus", "pre1940", "built2000_plus"), "_10pp")
bg_economic_terms <- c("poverty_10pp", "log_income", "college_10pp", "no_high_school_10pp")
bg_race_terms <- c("nh_black_10pp", "hispanic_10pp")
bg_context_terms <- c(bg_economic_terms, bg_race_terms)
bg_predictors <- c(bg_housing_terms, bg_context_terms)
bg_formulas <- list(
  M0 = log_rent ~ 1,
  M1 = stats::reformulate(bg_housing_terms, "log_rent"),
  M2a = stats::reformulate(c(bg_housing_terms, bg_economic_terms), "log_rent"),
  M2 = stats::reformulate(bg_predictors, "log_rent"),
  M3 = stats::reformulate(c(bg_predictors, "community_id"), "log_rent"),
  H_CA = stats::reformulate(c(bg_housing_terms, "community_id"), "log_rent")
)
bg_term_labels <- c(
  small_bedrooms_10pp = "Studio/one-bedroom rental share (+10 pp)",
  large_bedrooms_10pp = "Three-plus-bedroom rental share (+10 pp)",
  structure_2_4_10pp = "Rentals in 2–4-unit buildings (+10 pp)",
  structure_5_19_10pp = "Rentals in 5–19-unit buildings (+10 pp)",
  structure_20_plus_10pp = "Rentals in 20+-unit buildings (+10 pp)",
  structure_other_10pp = "Rentals in mobile/other structures (+10 pp)",
  pre1940_10pp = "Rentals built before 1940 (+10 pp)",
  built2000_plus_10pp = "Rentals built since 2000 (+10 pp)",
  poverty_10pp = "Poverty rate (+10 pp)", log_income = "Median household income (+10%)",
  college_10pp = "Bachelor's degree or higher (+10 pp; age 25+)",
  no_high_school_10pp = "No high-school diploma/GED (+10 pp; age 25+)",
  nh_black_10pp = "Non-Hispanic Black population (+10 pp)",
  hispanic_10pp = "Hispanic/Latino population (+10 pp)")
