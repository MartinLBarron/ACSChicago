# Spatial sensitivity for the same-case, joint-omission diagnostic models.
source("R/crime_stages_config.R")
reduced <- readRDS("data/analytic/building_college_vif_2024/diagnostic_models.rds")
baseline <- readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
stopifnot(identical(reduced$data$GEOID,baseline$data$GEOID))
results <- list()
for(rule in c("queen","knn4")) for(model in c("M2","M3","M4")) {
  fit <- reduced$fits[[paste(model,"Omit 20+ and college",sep=" / ")]]
  # Use the same permutations as the corresponding original-model diagnostic.
  index <- match(model,names(crime_stage_formulas))+if(rule=="knn4")5L else 0L
  set.seed(crime_stages_config$seed+500L+index)
  mc <- spdep::moran.mc(residuals(fit),baseline$spatial[[rule]],
    nsim=bg_model_config$moran_permutations,alternative="two.sided",zero.policy=TRUE)
  draws <- mc$res[seq_len(bg_model_config$moran_permutations)]
  observed <- unname(mc$statistic)
  p <- min(1,2*min((1+sum(draws>=observed))/(length(draws)+1),
    (1+sum(draws<=observed))/(length(draws)+1)))
  results[[length(results)+1L]] <- data.frame(weights=rule,model=model,
    variant="Omit 20+ and college",Moran_I=observed,permutation_p=p)
}
results <- dplyr::bind_rows(results)
readr::write_csv(results,"output/models/building_college_vif_2024/spatial.csv")
print(results,row.names=FALSE)
message("Exploratory ordinary-residual permutations, as in the original study; not a choice test for lag vs error.")
