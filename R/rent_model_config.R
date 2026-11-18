# First descriptive rent models, agreed with Martin. No automatic variable selection.
source("R/pums_config.R")
rent_model_config <- list(
  input = file.path(pums_config$analytic_dir, "chicago_housing.rds"),
  sample_path = file.path(pums_config$analytic_dir, "contract_rent_model_sample.rds"),
  audit_path = file.path(pums_config$analytic_dir, "contract_rent_sample_audit.csv"),
  output_dir = "output/models/contract_rent_2024",
  confidence = 0.95,
  # Standard ACS successive-difference replication: 4/80, centered at full estimate.
  replicate_scale = 4 / 80,
  formulas = list(
    housing = log_contract_rent ~ bedrooms + rooms + building_size + year_built + household_size,
    housing_puma = log_contract_rent ~ bedrooms + rooms + building_size + year_built + household_size + puma
  )
)
