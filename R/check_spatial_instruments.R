# Audit the SAR GMM spatial-instrument construction and first-stage relevance.
source("R/acs_config.R")
suppressPackageStartupMessages(library(spatialreg))
r<-readRDS("data/analytic/spatial_sensitivity_2024/model_results.rds")
out<-list()
for(spec in c("Original","Drop both"))for(stage in c("M3","M4"))for(rule in c("queen","knn4")) {
  key<-paste(spec,stage,rule,"SAR",sep=" / ")
  ols<-r$fits[[paste(spec,stage,rule,"OLS",sep=" / ")]]
  X<-model.matrix(ols);y<-r$data$log_rent;W<-r$graphs[[rule]]$W
  WX<-as.matrix(W%*%X[,-1,drop=FALSE]);W2X<-as.matrix(W%*%WX)
  H<-cbind(X,WX,W2X);qh<-qr(H);H<-H[,qh$pivot[seq_len(qh$rank)],drop=FALSE]
  qh<-qr(H);Z<-cbind(X,as.vector(W%*%y));projected<-qr.fitted(qh,Z)
  independent_beta<-qr.coef(qr(projected),y)
  gmm_beta<-as.numeric(r$gmm_fits[[key]]$coefficients)
  stopifnot(length(independent_beta)==length(gmm_beta),max(abs(independent_beta-gmm_beta))<1e-6)
  wy<-as.vector(W%*%y);sse_restricted<-sum(qr.resid(qr(X),wy)^2);sse_full<-sum(qr.resid(qh,wy)^2)
  extra<-qh$rank-ncol(X);df<-length(y)-qh$rank
  out[[length(out)+1L]]<-data.frame(spec=spec,stage=stage,weights=rule,
    instrument_rank=qh$rank,excluded_instruments=extra,first_stage_partial_R2=1-sse_full/sse_restricted,
    first_stage_classical_F=((sse_restricted-sse_full)/extra)/(sse_full/df),
    first_stage_residual_df=df,coefficient_reconstruction_error=max(abs(independent_beta-gmm_beta)))
}
out<-dplyr::bind_rows(out)
readr::write_csv(out,"output/models/spatial_sensitivity_2024/instrument_audit.csv")
print(out,row.names=FALSE)
message("PASS: all SAR GMM point estimates independently reconstructed from X, WX and W2X instruments. Relevance does not establish instrument exogeneity.")
