# Current primary OLS specification: omit 20+-unit and college-educated shares.
# Preserve the original models and the same complete-case sample for comparison.
source("R/crime_stages_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")
cfg<-crime_stages_config
cfg$analytic_dir<-"data/analytic/crime_stages_reduced_2024"
cfg$output_dir<-"output/models/block_group_crime_stages_reduced_2024"
dir.create(cfg$analytic_dir,recursive=TRUE,showWarnings=FALSE)
dir.create(cfg$output_dir,recursive=TRUE,showWarnings=FALSE)
original<-readRDS(file.path(crime_stages_config$analytic_dir,"model_results.rds"))
baseline<-readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
d<-original$data
stopifnot(identical(d$GEOID,baseline$data$GEOID))
removed_terms<-c("structure_20_plus_10pp","college_10pp")
formulas<-lapply(crime_stage_formulas,function(f)stats::update(f,.~.-structure_20_plus_10pp-college_10pp))
models<-lapply(formulas,stats::lm,data=d,na.action=stats::na.fail)
for(name in names(models)) {
 stopifnot(nobs(models[[name]])==nrow(d),models[[name]]$rank==length(coef(models[[name]])),
   setequal(names(coef(models[[name]])),setdiff(names(coef(original$models[[name]])),removed_terms)))
}
metrics<-dplyr::bind_rows(lapply(names(models),function(name)bg_fit_summary(models[[name]],name)))
metrics$r_squared[abs(metrics$r_squared)<1e-12]<-0
metrics$adjusted_r_squared[abs(metrics$adjusted_r_squared)<1e-12]<-0
cv<-ex_cv(d,formulas,baseline$cv$assignments)
metrics<-dplyr::left_join(metrics,cv$metrics,by="model")
metrics$predictive_R2[abs(metrics$predictive_R2)<1e-12]<-0
coefficients<-dplyr::bind_rows(lapply(names(models),function(name)bg_coefficient_table(models[[name]],name,d,
 term_labels=c(bg_term_labels,violent_crime_count="Recorded violent rows (+1 row over 2020–2024)"))))
effects<-coefficients[coefficients$term=="violent_crime_count",]
for(field in c("estimate","hc3_conf_low","hc3_conf_high","cluster_conf_low","cluster_conf_high"))
 effects[[paste0("percent_per100_",field)]]<-100*expm1(100*effects[[field]])
diagnostics<-dplyr::bind_rows(lapply(names(models)[-1],function(name)
 cbind(data.frame(model=name),ex_diagnostic(models[[name]],d,baseline$spatial$queen))))
vif<-dplyr::bind_rows(lapply(names(models)[-1],function(name)bg_vif(models[[name]],name,
 predictors=setdiff(c("violent_crime_count",bg_predictors),removed_terms))))
spatial<-list()
for(rule in c("queen","knn4"))for(name in names(models)) {
 test<-spdep::lm.morantest(models[[name]],baseline$spatial[[rule]],alternative="two.sided",zero.policy=TRUE)
 spatial[[length(spatial)+1L]]<-data.frame(weights=rule,model=name,Moran_I=unname(test$estimate[1]),
   expected_I=unname(test$estimate[2]),p_value=test$p.value,method="Regression-adjusted Moran test")
}
strict<-droplevels(d[d$city_fraction>=bg_model_config$strict_city_share,])
strict_models<-lapply(formulas,stats::lm,data=strict,na.action=stats::na.fail)
strict_metrics<-dplyr::bind_rows(lapply(names(strict_models),function(name)bg_fit_summary(strict_models[[name]],name)))
closed<-droplevels(d[is.finite(d$rent_moe),])
closed_models<-lapply(formulas,stats::lm,data=closed,na.action=stats::na.fail)
closed_metrics<-dplyr::bind_rows(lapply(names(closed_models),function(name)bg_fit_summary(closed_models[[name]],name)))
comparison<-dplyr::left_join(original$metrics[c("model","r_squared","adjusted_r_squared")],
 metrics[c("model","r_squared","adjusted_r_squared")],by="model",suffix=c("_before","_after"))
results<-list(config=cfg,data=d,models=models,metrics=metrics,coefficients=coefficients,effects=effects,
 diagnostics=diagnostics,vif=vif,spatial=dplyr::bind_rows(spatial),cv=cv,
 strict_metrics=strict_metrics,closed_metrics=closed_metrics,sample_flow=original$sample_flow,
 comparison=comparison,removed_terms=removed_terms,formulas=formulas,synthetic_data=SYNTHETIC_DATA)
saveRDS(results,file.path(cfg$analytic_dir,"model_results.rds"))
for(name in c("metrics","coefficients","effects","diagnostics","vif","spatial","strict_metrics","closed_metrics","comparison"))
 readr::write_csv(results[[name]],file.path(cfg$output_dir,paste0(name,".csv")))
stopifnot(!any(coefficients$term %in% removed_terms),nrow(cv$failures)==0,
 identical(coef(models$M1),coef(original$models$M1)))
print(metrics[c("model","n","parameters","r_squared","adjusted_r_squared")],row.names=FALSE)
message("PASS: current reduced M0–M4, identical cases, intended parameter sets and diagnostics")
