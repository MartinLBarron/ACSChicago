# Shared settings for the rent analysis. Run scripts from the project root.
.libPaths(c(normalizePath(".R-library", mustWork = FALSE), .libPaths()))
acs_config <- list(
  year = 2024L,
  survey = "acs5",
  state = "17",
  crs = 26916L,
  variables = c(median_contract_rent = "B25058_001",
                median_gross_rent = "B25064_001"),
  raw_dir = "data/raw_data/acs_2024",
  shape_dir = "data/shape/acs_2024",
  analytic_dir = "data/analytic/acs_2024"
)
# These are official public observations, not synthetic data.
SYNTHETIC_DATA <- FALSE
