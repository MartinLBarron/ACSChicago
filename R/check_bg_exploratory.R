source("R/bg_exploratory_config.R")
cfg <- bg_exploratory_config
base <- readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
r <- readRDS(file.path(cfg$analytic_dir,"model_results.rds"))
x <- readRDS(file.path(cfg$analytic_dir,"exploratory_inputs.rds"))
stopifnot(!r$synthetic_data,identical(base$data$GEOID,x$GEOID),
  length(unique(unlist(bg_exploratory_domains)))==9,
  setequal(names(r$results),c(names(bg_exploratory_domains),"priority_available","all_available")),
  all(r$audit$status=="fit"),nrow(r$skipped)==3)
expected <- 100*x$b25004_002_estimate/(x$renter_occupied_units_estimate+x$b25004_002_estimate+x$b25004_003_estimate)
stopifnot(max(abs(x$rental_vacancy_pct-expected))<1e-10)
stopifnot(max(abs(x$recent_movers_pct-100*(x$b25038_010_estimate+x$b25038_011_estimate)/x$b25038_009_estimate))<1e-10,
  max(abs(x$studio_pct-100*x$bed_studio_estimate/x$bed_total_estimate))<1e-10,
  max(abs(x$four_plus_bedrooms_pct-100*(x$bed_four_estimate+x$bed_five_plus_estimate)/x$bed_total_estimate))<1e-10)
derived <- readRDS(file.path(cfg$analytic_dir,"derived_measures_long.rds"))
stopifnot(all(derived$estimate>=0),all(derived$estimate<=100+1e-8),
  all(is.finite(derived$moe)),all(derived$moe>=0))
for(name in names(r$results)) {
  result <- r$results[[name]]
  data <- x[match(result$data$GEOID,x$GEOID),]
  stopifnot(all(is.finite(as.matrix(data[result$terms]))),
    length(unique(result$metrics$n))==1,
    all(vapply(result$models,function(m)m$rank==length(stats::coef(m)),logical(1))))
  # Matched-case baselines must be genuine refits, not reused full-sample R².
  refit <- stats::lm(bg_formulas$M3,data=droplevels(data))
  stopifnot(max(abs(stats::fitted(refit)-stats::fitted(result$models$baseline_location)))<1e-10)
  metrics <- result$metrics
  R2 <- stats::setNames(metrics$r_squared,metrics$model)
  stopifnot(R2["expanded_location"]>=R2["baseline_location"]-1e-10,
    R2["expanded_location"]>=R2["expanded_no_location"]-1e-10,
    nrow(result$cv$failures)==0,length(unique(metrics$test_BGs))==1,
    all(is.finite(result$cv$predictions$predicted)))
  predictions <- result$cv$predictions
  ids <- split(predictions$GEOID,predictions$model)
  stopifnot(all(vapply(ids,function(v)setequal(v,ids[[1]]),logical(1))))
  assignments <- base$cv$assignments
  stopifnot(all(predictions$fold==assignments$fold[match(predictions$GEOID,assignments$GEOID)]))
  # Independently verify HC3 covariance for every new slope, dropping saturated
  # singleton indicators exactly as documented in the baseline inference.
  keep <- table(data$community_id)[as.character(data$community_id)]>1
  fit <- stats::lm(stats::formula(result$models$expanded_location),data=droplevels(data[keep,]))
  X <- stats::model.matrix(fit)
  bread <- solve(crossprod(X))
  adjusted <- stats::residuals(fit)/(1-stats::hatvalues(fit))
  manual <- bread%*%crossprod(X*adjusted)%*%bread
  coefficients <- result$coefficients[match(result$terms,result$coefficients$term),]
  stopifnot(max(abs(sqrt(diag(manual))[result$terms]-coefficients$hc3_se))<1e-7)
}
provenance <- jsonlite::read_json(file.path(cfg$output_dir,"provenance.json"),simplifyVector=TRUE)
hashes <- unlist(provenance$input_md5)
stopifnot(identical(unname(tools::md5sum(names(hashes))),unname(hashes)))
codebook <- readr::read_csv(file.path(cfg$analytic_dir,"source_codebook.csv"),show_col_types=FALSE)
stopifnot(!any(codebook$table %in% r$skipped$table))
message("PASS: exploratory source ratios/MOEs, skipped domains, matched-case baselines, nested fits, fixed paired CV, independent new-slope HC3 and source hashes")
