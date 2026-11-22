source("R/crime_stages_config.R")
r<-readRDS("data/analytic/crime_stages_reduced_2024/model_results.rds")
w<-jsonlite::read_json("html/data/web/block_group_model_2024.json",simplifyVector=TRUE)
old<-readRDS(file.path(crime_stages_config$analytic_dir,"model_results.rds"))
baseline<-readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
stopifnot(w$version==3L,w$sample_n==1468L,identical(r$data$GEOID,old$data$GEOID),
 setequal(w$removed_terms,c("structure_20_plus_10pp","college_10pp")),
 !any(w$formal_coefficients$term %in% w$removed_terms),!any(w$coefficients$term %in% w$removed_terms),
 !any(w$variables$term %in% w$removed_terms),nrow(w$formal_coefficients)==122L)
for(name in names(r$models)) {
 fit<-r$models[[name]];row<-w$models[w$models$model==name,]
 stopifnot(row$n==nobs(fit),row$parameters==length(coef(fit)),
 abs(row$r_squared-summary(fit)$r.squared)<1e-10,
 abs(row$adjusted_r_squared-summary(fit)$adj.r.squared)<1e-10)
 f<-summary(fit)$fstatistic
 if(!is.null(f))stopifnot(abs(row$f_statistic-f[1])<1e-10,row$f_df2==f[3])
 c<-w$formal_coefficients[w$formal_coefficients$model==name,]
 stopifnot(isTRUE(all.equal(c$estimate,unname(coef(fit)),check.attributes=FALSE)))
 for(rule in c("queen","knn4")) {
  test<-spdep::lm.morantest(fit,baseline$spatial[[rule]],alternative="two.sided",zero.policy=TRUE)
  spatial<-w$spatial[w$spatial$model==name&w$spatial$weights==rule,]
  stopifnot(abs(test$p.value-spatial$p_value)<1e-12,abs(unname(test$estimate[1])-spatial$Moran_I)<1e-12)
 }
}
for(field in c("estimate","hc3_conf_low","hc3_conf_high","hc3_p_value"))
 stopifnot(isTRUE(all.equal(w$formal_coefficients[[field]],r$coefficients[[field]],check.attributes=FALSE)))
stopifnot(isTRUE(all.equal(w$points$residual,unname(residuals(r$models$M4)),check.attributes=FALSE)),
 isTRUE(all.equal(w$points$fitted,unname(exp(fitted(r$models$M4))),check.attributes=FALSE)),
 isTRUE(all.equal(w$vif$VIF,r$vif$VIF)),nrow(w$sensitivity)==2L,
 nrow(w$spatial_robustness$metrics)==12L,nrow(w$spatial_robustness$effects)==20L,
 nrow(w$spatial_robustness$gmm)==16L,
 all(w$spatial_robustness$metrics$spec=="Drop both"))
for(stage in c("M3","M4"))for(rule in c("queen","knn4")) {
 row<-w$spatial_robustness$metrics[w$spatial_robustness$metrics$stage==stage&w$spatial_robustness$metrics$weights==rule&w$spatial_robustness$metrics$family=="OLS",]
 stopifnot(abs(row$mean_R2-w$models$r_squared[w$models$model==stage])<1e-10)
}
message("PASS: reduced-model web values, full coefficients/CIs/F tests, diagnostic points/VIFs, regression-aware spatial tests and matching robustness fits")
