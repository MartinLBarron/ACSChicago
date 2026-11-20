source("R/crime_stages_config.R")
r <- readRDS(file.path(crime_stages_config$analytic_dir, "model_results.rds"))
old <- readRDS(file.path(crime_config$analytic_dir, "model_results.rds"))
base <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
d <- r$data
stopifnot(!r$synthetic_data, identical(names(r$models), paste0("M", 0:4)),
  identical(d$GEOID, old$data$GEOID), identical(d$GEOID, base$data$GEOID),
  is.factor(d$community_id), nlevels(d$community_id) == 77,
  all(vapply(r$models, stats::nobs, numeric(1)) == nrow(d)),
  all(vapply(r$models, function(f) f$rank == length(stats::coef(f)), logical(1))),
  all(diff(r$metrics$r_squared) >= -1e-10))
stopifnot(length(attr(stats::terms(r$models$M0), "term.labels")) == 0,
  identical(attr(stats::terms(r$models$M1), "term.labels"), "violent_crime_count"),
  setequal(attr(stats::terms(r$models$M2), "term.labels"), c("violent_crime_count", bg_housing_terms)),
  setequal(attr(stats::terms(r$models$M3), "term.labels"), c("violent_crime_count", bg_predictors)),
  setequal(attr(stats::terms(r$models$M4), "term.labels"), c("violent_crime_count", bg_predictors, "community_id")))
for (name in names(r$models)[-1]) {
  fit <- r$models[[name]]
  stopifnot(identical(as.numeric(stats::model.matrix(fit)[,"violent_crime_count"]), as.numeric(d$violent_crime_count)))
  data <- d
  if (name == "M4") {
    keep <- table(data$community_id)[as.character(data$community_id)] > 1
    data <- droplevels(data[keep,])
  }
  independent <- stats::lm(crime_stage_formulas[[name]], data = data)
  X <- stats::model.matrix(independent); bread <- solve(crossprod(X))
  adjusted <- stats::residuals(independent)/(1 - stats::hatvalues(independent))
  manual <- bread %*% crossprod(X * adjusted) %*% bread
  row <- r$effects[r$effects$model == name,]
  stopifnot(abs(sqrt(manual["violent_crime_count","violent_crime_count"]) - row$hc3_se) < 1e-9,
    abs(100 * expm1(100 * row$estimate) - row$percent_per100_estimate) < 1e-9)
}
stopifnot(abs(stats::cor(d$log_rent,d$violent_crime_count)^2 - r$metrics$r_squared[r$metrics$model=="M1"]) < 1e-10,
  abs(stats::cov(d$log_rent,d$violent_crime_count)/stats::var(d$violent_crime_count) - stats::coef(r$models$M1)["violent_crime_count"]) < 1e-10,
  max(abs(stats::fitted(r$models$M4) - stats::fitted(old$models$M5))) < 1e-8,
  abs(stats::coef(r$models$M4)["violent_crime_count"] - stats::coef(old$models$M5)["violent_crime_count"]) < 1e-10,
  all(r$crime_unique$crime_incremental_R2 >= -1e-10),
  nrow(r$cv$failures) == 0, length(unique(r$metrics$test_BGs)) == 1)
predictions <- r$cv$predictions
sets <- split(predictions$GEOID,predictions$model)
stopifnot(all(vapply(sets,function(ids)setequal(ids,sets[[1]]),logical(1))),
  all(is.finite(predictions$predicted)),
  all(predictions$fold == base$cv$assignments$fold[match(predictions$GEOID,base$cv$assignments$GEOID)]))
hashes <- unlist(jsonlite::read_json(file.path(crime_stages_config$output_dir,"provenance.json"),simplifyVector=TRUE)$input_md5)
stopifnot(identical(unname(tools::md5sum(names(hashes))),unname(hashes)))
message("PASS: staged formulas, unchanged common sample, raw count, nested fit, bivariate identities, old-M5 equivalence, independent HC3 at every stage, paired tract CV and source hashes")
