# Download the baseline inputs without changing its variable definitions.
source("R/bg_model_config.R")
source("R/acs_helpers.R")
source("R/bg_download_helpers.R")
download_bg_inputs(bg_model_config, bg_variable_groups)
