# Spatial alternatives to the current descriptive M3/M4 associations; no site edits.
source("R/crime_stages_config.R")
source("R/bg_model_helpers.R")
source("R/spatial_model_helpers.R")
suppressPackageStartupMessages(library(spatialreg))
paths <- c(original=file.path(crime_stages_config$analytic_dir,"model_results.rds"),
  reduced="data/analytic/building_college_vif_2024/diagnostic_models.rds",
  geography=file.path(bg_model_config$analytic_dir,"model_results.rds"))
original <- readRDS(paths["original"]); reduced <- readRDS(paths["reduced"]); baseline <- readRDS(paths["geography"])
d <- original$data; y <- d$log_rent; n <- nrow(d)
stopifnot(identical(d$GEOID,baseline$spatial$geometry$GEOID),identical(d$GEOID,reduced$data$GEOID),identical(d$GEOID,baseline$data$GEOID),!SYNTHETIC_DATA)
out <- "output/models/spatial_sensitivity_2024"; analytic <- "data/analytic/spatial_sensitivity_2024"
dir.create(out,recursive=TRUE,showWarnings=FALSE);dir.create(analytic,recursive=TRUE,showWarnings=FALSE)
base_signature <- list(cache_version=2L,input_md5=tools::md5sum(paths),spatialreg=as.character(packageVersion("spatialreg")),sphet=as.character(packageVersion("sphet")))
fits <- diagnostics <- coefficients <- effects <- residual_data <- warnings <- gmm_summary <- list()
graphs <- list(); index <- 0L
for(rule in c("queen","knn4")) {
  lw <- baseline$spatial[[rule]];W <- as(lw,"CsparseMatrix")
  stopifnot(max(abs(Matrix::rowSums(W)-ifelse(spdep::card(lw$neighbours)==0,0,1)))<1e-10)
  ev <- spatialreg::eigenw(lw,quiet=TRUE)
  stopifnot(max(abs(Im(ev)))<1e-8);ev<-Re(ev)
  island_fraction <- mean(spdep::card(lw$neighbours)==0)
  graphs[[rule]] <- list(listw=lw,W=W,eigenvalues=ev,island_fraction=island_fraction)
  for(spec in c("Original","Drop both")) for(stage in c("M3","M4")) {
    ols <- if(spec=="Original")original$models[[stage]] else reduced$fits[[paste(stage,"Omit 20+ and college",sep=" / ")]]
    X <- model.matrix(ols)
    stopifnot(identical(rownames(model.frame(ols)),rownames(d)),nobs(ols)==n)
    for(family in c("OLS","SEM","SAR")) {
      index <- index+1L;key <- paste(spec,stage,rule,family,sep=" / ")
      message("Spatial analysis: ",key)
      captured <- character()
      if(family=="OLS")fit<-ols else {
        signature<-c(base_signature,list(formula=deparse(formula(ols)),rule=rule,family=family))
        fit <- withCallingHandlers(sp_cache_fit(file.path(analytic,paste0(gsub(" / | ","_",key),".rds")),signature,function() {
          fun<-if(family=="SEM")spatialreg::errorsarlm else spatialreg::lagsarlm
          fun(formula(ols),data=d,listw=lw,method="eigen",zero.policy=TRUE,quiet=TRUE,control=list(pre_eig=ev))
        }),warning=function(w){captured<<-c(captured,conditionMessage(w));invokeRestart("muffleWarning")})
      }
      fits[[key]]<-fit
      if(length(captured))warnings[[key]]<-data.frame(key=key,message=captured)
      beta<-if(family=="OLS")coef(fit) else fit$coefficients
      theta<-if(family=="OLS")0 else if(family=="SEM")fit$lambda else fit$rho
      theta_name<-if(family=="SEM")"lambda" else "rho"
      A<-Matrix::Diagonal(n)-theta*W
      xb<-as.vector(X%*%beta)
      mean_fit<-if(family=="SAR")as.vector(Matrix::solve(A,xb)) else xb
      innovations<-if(family=="SEM")as.vector(A%*%(y-xb)) else if(family=="SAR")as.vector(A%*%y-xb) else y-xb
      ll<-as.numeric(logLik(fit));k<-attr(logLik(fit),"df")
      sigma2<-sum(innovations^2)/n
      # Independent likelihood reconstruction catches residual/parameter misinterpretations.
      manual_ll<-sum(log(1-theta*ev))-n/2*(log(2*pi)+1+log(sigma2))
      stopifnot(abs(ll-manual_ll)<1e-5,setequal(names(beta),colnames(X)),all(is.finite(innovations)))
      lr<-if(family=="OLS")NA_real_ else 2*(ll-as.numeric(logLik(ols)))
      if(family!="OLS")stopifnot(lr > -1e-5)
      if(family=="OLS") {
        ctab<-bg_coefficient_table(ols,stage,d)
        crime<-ctab[ctab$term=="violent_crime_count",]
        eff<-data.frame(effect="Conditional association",log_effect=crime$estimate,
          log_low=crime$hc3_conf_low,log_high=crime$hc3_conf_high,accepted_draws=NA_integer_)
        ctab<-ctab[c("term","estimate","hc3_conf_low","hc3_conf_high","hc3_p_value")]
        names(ctab)<-c("term","estimate","low","high","p_value")
        theta_se<-NA_real_;theta_p<-NA_real_
        moran_test<-spdep::lm.morantest(ols,lw,alternative="two.sided",zero.policy=TRUE)
        moran_p<-moran_test$p.value
        stopifnot(abs(sp_moran(innovations,W)-unname(moran_test$estimate[1]))<1e-10)
      } else {
        V<-vcov(fit);se<-sqrt(diag(V)[names(beta)])
        stopifnot(all(is.finite(V)),all(se>=0))
        ctab<-data.frame(term=names(beta),estimate=unname(beta),low=unname(beta-qnorm(.975)*se),high=unname(beta+qnorm(.975)*se),p_value=2*pnorm(-abs(beta/se)))
        theta_se<-sqrt(V[theta_name,theta_name]);theta_p<-2*pnorm(-abs(theta/theta_se));moran_p<-NA_real_
        eff<-sp_effects(beta,V,theta,theta_name,family,ev,island_fraction,fit$interval,crime_stages_config$seed+index)
        if(family=="SAR") {
          S<-as.matrix(Matrix::solve(A))
          check<-sp_impact(beta["violent_crime_count"],theta,ev,island_fraction)
          stopifnot(abs(check[1]-mean(diag(S))*beta["violent_crime_count"])<1e-8,
            abs(check[3]-mean(rowSums(S))*beta["violent_crime_count"])<1e-8)
        }
      }
      meta<-data.frame(spec=spec,stage=stage,weights=rule,family=family)
      coefficients[[key]]<-cbind(meta,ctab)
      eff$percent_equiv_per100<-100*expm1(100*eff$log_effect)
      eff$percent_equiv_low<-100*expm1(100*eff$log_low);eff$percent_equiv_high<-100*expm1(100*eff$log_high)
      effects[[key]]<-cbind(meta,eff)
      bp<-lmtest::bptest(innovations~mean_fit)$p.value
      diagnostics[[key]]<-cbind(meta,data.frame(n=n,parameters=k,logLik=ll,AIC=AIC(fit),BIC=BIC(fit),
        theta=theta,theta_se=theta_se,theta_p=theta_p,LR_vs_OLS=lr,LR_p=if(is.na(lr))NA_real_ else pchisq(max(0,lr),1,lower.tail=FALSE),
        mean_R2=1-sum((y-mean_fit)^2)/sum((y-mean(y))^2),mean_RMSE=sqrt(mean((y-mean_fit)^2)),
        innovation_RMSE=sqrt(sigma2),innovation_Moran=sp_moran(innovations,W),OLS_regression_Moran_p=moran_p,
        variance_mean_p=unname(bp),max_abs_standard_innovation=max(abs(innovations/sqrt(sigma2)))))
      residual_data[[key]]<-cbind(meta,data.frame(GEOID=d$GEOID,observed=y,mean_fit=mean_fit,innovation=innovations,standard_innovation=innovations/sqrt(sigma2)))
    }
  }
}
# Heteroskedasticity-robust GMM sensitivity. Sparse W preserves queen islands.
gmm_fits<-list()
for(rule in names(graphs))for(spec in c("Original","Drop both"))for(stage in c("M3","M4"))for(family in c("SEM","SAR")) {
  index<-index+1L;key<-paste(spec,stage,rule,family,sep=" / ");message("Robust GMM: ",key)
  ols<-if(spec=="Original")original$models[[stage]] else reduced$fits[[paste(stage,"Omit 20+ and college",sep=" / ")]]
  graph<-graphs[[rule]];captured<-character()
  value<-tryCatch(withCallingHandlers(sp_cache_fit(file.path(analytic,paste0("GMM_",gsub(" / | ","_",key),".rds")),
    c(base_signature,list(formula=deparse(formula(ols)),rule=rule,family=family,het=TRUE)),function()
      sphet::spreg(formula(ols),data=d,listw=graph$W,model=if(family=="SEM")"error" else "lag",het=TRUE,verbose=FALSE)),
    warning=function(w){captured<<-c(captured,conditionMessage(w));invokeRestart("muffleWarning")}),error=function(e)e)
  if(inherits(value,"error")) {
    warnings[[paste0("GMM ",key)]]<-data.frame(key=paste0("GMM ",key),message=conditionMessage(value));next
  }
  stopifnot(length(value$residuals)==n)
  gmm_fits[[key]]<-value
  if(length(captured))warnings[[paste0("GMM ",key)]]<-data.frame(key=paste0("GMM ",key),message=captured)
  beta<-setNames(as.numeric(value$coefficients),rownames(value$coefficients));V<-as.matrix(value$var)
  stopifnot(nrow(V)==length(beta),all(rownames(V)==""|rownames(V)==names(beta)))
  dimnames(V)<-list(names(beta),names(beta))
  spatial_name<-setdiff(names(beta),names(coef(ols)));stopifnot(length(spatial_name)==1L)
  theta<-beta[spatial_name];se<-sqrt(V[spatial_name,spatial_name])
  interval<-range(1/range(graph$eigenvalues));interval<-sort(interval)
  eff<-sp_effects(beta,V,theta,spatial_name,family,graph$eigenvalues,graph$island_fraction,interval,crime_stages_config$seed+index)
  eff$percent_equiv_per100<-100*expm1(100*eff$log_effect);eff$percent_equiv_low<-100*expm1(100*eff$log_low);eff$percent_equiv_high<-100*expm1(100*eff$log_high)
  gmm_summary[[key]]<-cbind(data.frame(spec=spec,stage=stage,weights=rule,family=family,theta=unname(theta),theta_se=unname(se),theta_p=unname(2*pnorm(-abs(theta/se)))),eff)
}
metrics<-dplyr::bind_rows(diagnostics) |> dplyr::group_by(spec,stage,weights) |>
  dplyr::mutate(delta_AIC=AIC-min(AIC),delta_BIC=BIC-min(BIC),AIC_gain_over_OLS=AIC[family=="OLS"]-AIC) |> dplyr::ungroup()
coefs<-dplyr::bind_rows(coefficients);effects<-dplyr::bind_rows(effects);residuals<-dplyr::bind_rows(residual_data)
gmm<-dplyr::bind_rows(gmm_summary);warning_table<-if(length(warnings))dplyr::bind_rows(warnings) else data.frame(key=character(),message=character())
stopifnot(nrow(metrics)==24L,all(metrics$n==n),all(is.finite(metrics$AIC)),all(is.finite(effects$log_effect)))
for(name in c("metrics","coefs","effects","gmm","warning_table"))readr::write_csv(get(name),file.path(out,paste0(name,".csv")))
saveRDS(list(data=d,fits=fits,gmm_fits=gmm_fits,metrics=metrics,coefficients=coefs,effects=effects,gmm=gmm,
  residuals=residuals,warnings=warning_table,graphs=graphs,geometry=baseline$spatial$geometry,
  seed=crime_stages_config$seed,synthetic_data=SYNTHETIC_DATA),file.path(analytic,"model_results.rds"))
jsonlite::write_json(c(base_signature,list(seed=crime_stages_config$seed,impact_draws=4000L,
  scope="Same-sample original and joint-omission M3/M4, queen primary and symmetric KNN4 sensitivity; website unchanged")),
  file.path(out,"provenance.json"),pretty=TRUE,auto_unbox=TRUE)
print(metrics[c("spec","stage","weights","family","AIC","BIC","theta","innovation_Moran")],n=24)
message("PASS: equal samples, full covariate sets, exact likelihood reconstruction and island-aware SAR impacts")
