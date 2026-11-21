# Paired-outcome comparison: same rows, predictors, weights and tract folds.
source("R/crime_stages_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")
out_dir <- "output/models/rent_outcome_comparison_2024"
analytic_dir <- "data/analytic/rent_outcome_comparison_2024"
dir.create(out_dir,recursive=TRUE,showWarnings=FALSE)
dir.create(analytic_dir,recursive=TRUE,showWarnings=FALSE)
original <- readRDS(file.path(crime_config$analytic_dir,"model_sample.rds"))
base <- readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
valid <- is.finite(original$median_contract_rent_estimate) & original$median_contract_rent_estimate>0 &
  is.finite(original$median_gross_rent_estimate) & original$median_gross_rent_estimate>0
d <- droplevels(original[valid,])
stopifnot(nrow(d)>100)
weights <- suppressWarnings(spdep::subset.listw(base$spatial$queen,subset=valid,zero.policy=TRUE))
results <- list()
for(outcome in c("contract","gross")) {
  data <- d
  data$log_rent <- log(data[[paste0("median_",outcome,"_rent_estimate")]])
  models <- lapply(crime_stage_formulas,stats::lm,data=data,na.action=stats::na.fail)
  stopifnot(all(vapply(models,function(m)m$rank==length(stats::coef(m)),logical(1))))
  metrics <- dplyr::bind_rows(lapply(names(models),function(name)bg_fit_summary(models[[name]],name)))
  metrics$r_squared[abs(metrics$r_squared)<1e-12]<-0
  metrics$adjusted_r_squared[abs(metrics$adjusted_r_squared)<1e-12]<-0
  cv <- ex_cv(data,crime_stage_formulas,base$cv$assignments)
  metrics <- dplyr::left_join(metrics,cv$metrics,by="model")
  metrics$predictive_R2[abs(metrics$predictive_R2)<1e-12]<-0
  metrics$outcome <- outcome
  coefficients <- dplyr::bind_rows(lapply(names(models)[-1],function(name)
    bg_coefficient_table(models[[name]],name,data,term_labels=c(bg_term_labels,violent_crime_count="Recorded violent rows (+1 row)"))))
  effects <- coefficients[coefficients$term=="violent_crime_count",]
  effects$outcome<-outcome
  for(field in c("estimate","hc3_conf_low","hc3_conf_high","cluster_conf_low","cluster_conf_high"))
    effects[[paste0("percent_per100_",field)]]<-100*expm1(100*effects[[field]])
  diagnostics <- dplyr::bind_rows(lapply(names(models)[-1],function(name)
    cbind(data.frame(outcome=outcome,model=name),ex_diagnostic(models[[name]],data,weights))))
  results[[outcome]]<-list(models=models,metrics=metrics,cv=cv,effects=effects,diagnostics=diagnostics,
    outcome_sd=stats::sd(data$log_rent))
}
metrics<-dplyr::bind_rows(lapply(results,`[[`,"metrics"))
effects<-dplyr::bind_rows(lapply(results,`[[`,"effects"))
diagnostics<-dplyr::bind_rows(lapply(results,`[[`,"diagnostics"))
# Exclude open-ended medians from both outcomes together, not separately.
closed <- is.finite(d$median_contract_rent_moe)&is.finite(d$median_gross_rent_moe)
closed_metrics<-list()
for(outcome in names(results)) {
  sub<-droplevels(d[closed,]);sub$log_rent<-log(sub[[paste0("median_",outcome,"_rent_estimate")]])
  fits<-lapply(crime_stage_formulas,stats::lm,data=sub,na.action=stats::na.fail)
  cv<-ex_cv(sub,crime_stage_formulas,base$cv$assignments)
  m<-dplyr::bind_rows(lapply(names(fits),function(name)bg_fit_summary(fits[[name]],name)))
  m<-dplyr::left_join(m,cv$metrics,by="model");m$outcome<-outcome
  closed_metrics[[outcome]]<-m
}
closed_metrics<-dplyr::bind_rows(closed_metrics)
bundle<-list(data=d,results=results,metrics=metrics,effects=effects,diagnostics=diagnostics,
  closed_metrics=closed_metrics,original_n=nrow(original),excluded_missing=sum(!valid),
  excluded_open_ended=sum(!closed),synthetic_data=SYNTHETIC_DATA)
saveRDS(bundle,file.path(analytic_dir,"model_results.rds"))
for(name in c("metrics","effects","diagnostics","closed_metrics"))readr::write_csv(bundle[[name]],file.path(out_dir,paste0(name,".csv")))
readr::write_csv(data.frame(GEOID=d$GEOID),file.path(out_dir,"common_sample.csv"))
jsonlite::write_json(list(input_md5=as.list(tools::md5sum(c(file.path(crime_config$analytic_dir,"model_sample.rds"),
  file.path(bg_model_config$analytic_dir,"model_results.rds")))),
  comparison="Natural-log contract versus gross medians; identical complete cases, controls, equal weights and tract folds",
  formulas=lapply(crime_stage_formulas,function(f)paste(deparse(f),collapse=" "))),
  file.path(out_dir,"provenance.json"),auto_unbox=TRUE,pretty=TRUE)
# Paired scientific checks, including an independent simple-regression identity.
stopifnot(length(unique(metrics$n))==1,length(unique(metrics$test_BGs))==1,
  all(vapply(results,function(z)nrow(z$cv$failures)==0,logical(1))),
  identical(results$contract$cv$predictions$GEOID,results$gross$cv$predictions$GEOID),
  identical(results$contract$cv$predictions$fold,results$gross$cv$predictions$fold))
for(outcome in names(results)) {
  y<-log(d[[paste0("median_",outcome,"_rent_estimate")]])
  m<-results[[outcome]]$metrics
  stopifnot(all(diff(m$r_squared)>=-1e-10),
    abs(unname(stats::coef(results[[outcome]]$models$M1)["violent_crime_count"])-
      stats::cov(y,d$violent_crime_count)/stats::var(d$violent_crime_count))<1e-10,
    abs(stats::cor(y,d$violent_crime_count)^2-m$r_squared[m$model=="M1"])<1e-10)
}
print(metrics[c("outcome","model","n","r_squared","adjusted_r_squared","RMSE_log","predictive_R2")],row.names=FALSE)
message("PASS: identical outcome samples and scoring rows/folds; nested fits and bivariate identities")
