# Scientific checks against independently reconstructed likelihoods and effects.
source("R/crime_stages_config.R")
source("R/spatial_model_helpers.R")
suppressPackageStartupMessages(library(spatialreg))
r<-readRDS("data/analytic/spatial_sensitivity_2024/model_results.rds")
original<-readRDS(file.path(crime_stages_config$analytic_dir,"model_results.rds"))
reduced<-readRDS("data/analytic/building_college_vif_2024/diagnostic_models.rds")
m<-r$metrics;n<-nrow(r$data)
stopifnot(nrow(m)==24L,nrow(r$effects)==40L,nrow(r$gmm)==32L,length(r$gmm_fits)==16L,
  all(m$n==n),!r$synthetic_data,identical(r$data$GEOID,original$data$GEOID))
for(spec in c("Original","Drop both"))for(stage in c("M3","M4"))for(rule in c("queen","knn4")) {
  old<-if(spec=="Original")original$models[[stage]] else reduced$fits[[paste(stage,"Omit 20+ and college",sep=" / ")]]
  block<-m[m$spec==spec&m$stage==stage&m$weights==rule,]
  stopifnot(nrow(block)==3,all(block$parameters[block$family!="OLS"]==block$parameters[block$family=="OLS"]+1))
  for(family in c("OLS","SEM","SAR")) {
    key<-paste(spec,stage,rule,family,sep=" / ");fit<-r$fits[[key]];row<-block[block$family==family,]
    if(family=="OLS")stopifnot(isTRUE(all.equal(coef(fit),coef(old))))
    beta<-if(family=="OLS")coef(fit) else fit$coefficients
    stopifnot(setequal(names(beta),names(coef(old))))
    W<-r$graphs[[rule]]$W;theta<-row$theta;A<-Matrix::Diagonal(n)-theta*W
    X<-model.matrix(old);y<-r$data$log_rent
    innovation<-if(family=="SEM")as.vector(A%*%(y-X%*%beta)) else if(family=="SAR")as.vector(A%*%y-X%*%beta) else as.vector(y-X%*%beta)
    # A separate sparse determinant checks the eigenvalue determinant calculation.
    determinant<-Matrix::determinant(A,logarithm=TRUE)
    ll<-as.numeric(determinant$modulus)-n/2*(log(2*pi)+1+log(sum(innovation^2)/n))
    stopifnot(determinant$sign==1,abs(ll-row$logLik)<1e-5,
      abs((-2*ll+2*row$parameters)-row$AIC)<1e-5,
      abs((-2*ll+log(n)*row$parameters)-row$BIC)<1e-5)
    saved<-r$residuals[r$residuals$spec==spec&r$residuals$stage==stage&r$residuals$weights==rule&r$residuals$family==family,]
    stopifnot(identical(saved$GEOID,r$data$GEOID),max(abs(saved$innovation-innovation))<1e-10)
    effect<-r$effects[r$effects$spec==spec&r$effects$stage==stage&r$effects$weights==rule&r$effects$family==family,]
    if(family=="SAR") {
      stopifnot(abs(effect$log_effect[effect$effect=="Direct"]+effect$log_effect[effect$effect=="Indirect"]-effect$log_effect[effect$effect=="Total"])<1e-10)
      # KNN is connected; queen has 15 explicit zero-lag islands.
      S<-as.matrix(Matrix::solve(A));b<-beta["violent_crime_count"]
      stopifnot(abs(mean(diag(S))*b-effect$log_effect[effect$effect=="Direct"])<1e-8,
        abs(mean(rowSums(S))*b-effect$log_effect[effect$effect=="Total"])<1e-8)
    } else stopifnot(abs(beta["violent_crime_count"]-effect$log_effect)<1e-10)
  }
}
stopifnot(all(r$effects$log_low<=r$effects$log_high),all(r$gmm$log_low<=r$gmm$log_high),
  all(is.finite(r$gmm$theta)),all(r$effects$accepted_draws[!is.na(r$effects$accepted_draws)]>3800L))
message("PASS: all 24 fits/16 robust sensitivities, sample and parameter identity, independent sparse likelihoods, AIC/BIC, innovations, and exact island-aware SAR impacts")
