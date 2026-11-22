# Regression-aware diagnostics: distinct from unrestricted residual permutations.
source("R/crime_stages_config.R")
original <- readRDS(file.path(crime_stages_config$analytic_dir,"model_results.rds"))
reduced <- readRDS("data/analytic/building_college_vif_2024/diagnostic_models.rds")
baseline <- readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
stopifnot(identical(original$data$GEOID,baseline$data$GEOID),
  identical(reduced$data$GEOID,baseline$data$GEOID))
fits <- list(original_M3=original$models$M3,original_M4=original$models$M4,
  reduced_M3=reduced$fits[["M3 / Omit 20+ and college"]],
  reduced_M4=reduced$fits[["M4 / Omit 20+ and college"]])
results <- list()
for(rule in c("queen","knn4")) for(name in names(fits)) {
  fit <- fits[[name]]
  stopifnot(nobs(fit)==nrow(baseline$data))
  weights <- baseline$spatial[[rule]]
  moran <- spdep::lm.morantest(fit,weights,alternative="two.sided",zero.policy=TRUE)
  scores <- spdep::lm.RStests(fit,weights,test=c("adjRSerr","adjRSlag"),zero.policy=TRUE)
  results[[length(results)+1L]] <- data.frame(model=name,weights=rule,
    Moran_I=unname(moran$estimate[1]),null_expected_I=unname(moran$estimate[2]),
    regression_Moran_p=moran$p.value,
    adjusted_error_p=scores$adjRSerr$p.value,adjusted_lag_p=scores$adjRSlag$p.value)
}
results <- dplyr::bind_rows(results)
stopifnot(all(is.finite(as.matrix(results[-c(1,2)]))))
out <- "output/models/building_college_vif_2024"
readr::write_csv(results,file.path(out,"regression_spatial_diagnostics.csv"))
writeLines(c("# Regression-aware spatial diagnostics","",
  "Original and joint-omission M3/M4 models; identical 1,468-case sample and spatial weights.","",
  "Read regression_spatial_diagnostics.csv for Moran statistics, model-adjusted null expectations and adjusted Rao score tests.","",
  "The earlier report used ordinary residual permutations. Those do not reproduce the model-dependent null distribution of fitted OLS residuals, especially after community fixed effects. These tests adjust for model fitting, but still rely on conventional error assumptions; known heteroskedasticity limits definitive interpretation.","",
  "M4 Moran I is small and positive, while its regression-null expectation is about -0.04. Original queen M4 p=0.0000373; joint-omission M4 p=0.0000346. Community effects reduce spatial clustering substantially but do not establish residual independence.","",
  "The adjusted score tests are adjusted for the competing lag/error alternative, not arbitrary heteroskedasticity. Queen M3 favors error dependence; KNN4 M3 favors lag dependence. M4 evidence is weaker in those specification tests and sensitive to weights. Moran I alone cannot select lag versus error.","",
  "Treat spatial error and lag models as sensitivity analyses with the same covariates/sample, and examine crime coefficient or impact stability, spatial residual patterns and dependence on W. Do not automatically promote a spatial model solely because a test is significant.","",
  "Primary documentation: https://r-spatial.github.io/spdep/reference/lm.morantest.html and https://r-spatial.github.io/spdep/reference/lm.RStests.html.","",
  "Reproduce: Rscript R/diagnose_regression_spatial.R. Ordinary-permutation sensitivity: Rscript R/check_reduced_model_spatial.R. Main models/website remain unchanged."),
  file.path(out,"spatial_diagnostics.md"))
print(results,row.names=FALSE)
