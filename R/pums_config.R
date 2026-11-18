# Latest requested five-year PUMS release; intentionally independent of ACS waves.
source("R/acs_config.R")
pums_config <- list(
  year = 2024L,
  survey = "acs5",
  state = "IL",
  state_fips = "17",
  puma_definition_year = 2020L,
  variables = c("PUMA", "RNTP", "GRNTP", "TEN", "VACS", "TYPEHUGQ",
                "BDSP", "RMSP", "BLD", "YRBLT", "NP", "ADJHSG", "FRNTP", "FGRNTP"),
  # One occupied housing record, rather than one row for every household member.
  # get_pums(return_vacant = TRUE) retrieves vacant units in a separate request.
  variables_filter = list(SPORDER = 1L, TYPEHUGQ = 1L),
  rep_weights = "housing",
  raw_dir = "data/raw_data/pums_2024/housing_basic_v1",
  analytic_dir = "data/analytic/pums_2024",
  boundary_path = "data/shape/puma_2024/chicago_pumas.gpkg"
)
