# Independent entry point: requires current baseline M3 and 2024 geography outputs.
source("R/download_crime.R")
source("R/prepare_crime.R")
source("R/model_bg_crime.R")
source("R/check_crime.R")
source("R/render_crime_report.R")
source("R/run_crime_stages.R")
