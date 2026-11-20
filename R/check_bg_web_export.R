# Validate the actual web export against fitted R results and create independent
# contrast fixtures for the browser's calculation (including negative differences).
source("R/bg_model_config.R")
r <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
web <- jsonlite::read_json("html/data/web/block_group_model_2024.json", simplifyVector = TRUE)
stopifnot(web$sample_n == nrow(r$data), web$communities_n == nlevels(r$data$community_id),
  nrow(web$points) == nrow(r$data), !web$synthetic_data)
model_rows <- match(web$models$model, r$metrics$model)
stopifnot("M4" %in% web$models$model,
  setequal(web$coefficients$term[web$coefficients$model == "M4"], bg_housing_terms))
stopifnot(max(abs(web$models$r_squared-r$metrics$r_squared[model_rows])) < 1e-12,
  max(abs(web$points$fitted-exp(stats::fitted(r$models$M3)))) < 1e-10,
  all(is.finite(web$qq$observed)))
fixtures <- list()
for (term in bg_predictors) {
  v <- web$variables[web$variables$term == term, ]
  b <- web$coefficients[web$coefficients$model == "M3" & web$coefficients$term == term, ]
  coefficient <- stats::coef(r$models$M3)[term]
  ci <- r$coefficients[r$coefficients$model == "M3" & r$coefficients$term == term, ]
  for (target in c(v$p05,v$p25,v$median,v$p75,v$p95)) {
    change <- if (term == "log_income") log(target/v$median) else (target-v$median)/10
    bounds <- sort(100*expm1(c(ci$hc3_conf_low,ci$hc3_conf_high)*change))
    fixtures[[length(fixtures)+1L]] <- list(variable=as.list(v),coefficient=as.list(b),target=target,
      expected=list(estimate=unname(100*expm1(coefficient*change)),low=bounds[1],high=bounds[2]))
  }
}
fixtures_path <- file.path(tempdir(), "chicago_model_web_fixtures.json")
jsonlite::write_json(fixtures,fixtures_path,auto_unbox=TRUE,digits=NA)
status <- system2("node", c("tests/check_bg_web_effects.cjs", shQuote(fixtures_path)))
stopifnot(status == 0)
message("PASS: public model export agrees with R fits; browser contrasts agree with independent R calculations")
