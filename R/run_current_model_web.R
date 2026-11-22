# Current website model branch; keep original specification as an archived comparison.
source("R/model_reduced_crime_stages.R")
# Prepare the original/reduced spatial-comparison inputs, then refresh cached checks.
source("R/diagnose_building_college_vif.R")
source("R/run_spatial_sensitivity.R")
source("R/export_crime_stages_web.R")
source("R/check_current_model_web.R")
