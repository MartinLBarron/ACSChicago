# Shared calculations for equal-sample OLS, spatial error (SEM) and lag (SAR).
sp_moran <- function(x,W) {
  z <- x-mean(x)
  effective_n <- sum(Matrix::rowSums(W)!=0) # Match spdep adjust.n=TRUE for islands.
  as.numeric(effective_n/sum(W)*crossprod(z,W%*%z)/crossprod(z))
}
sp_impact <- function(beta,theta,eigenvalues,island_fraction) {
  direct_factor <- mean(1/(1-theta*eigenvalues))
  total_factor <- island_fraction+(1-island_fraction)/(1-theta)
  c(direct=beta*direct_factor,indirect=beta*(total_factor-direct_factor),total=beta*total_factor)
}
sp_effects <- function(beta,V,theta,theta_name,family,eigenvalues,island_fraction,interval,seed,draws=4000L) {
  crime <- "violent_crime_count"
  if(family!="SAR") {
    se <- sqrt(V[crime,crime])
    return(data.frame(effect="Conditional association",log_effect=beta[crime],
      log_low=beta[crime]-qnorm(.975)*se,log_high=beta[crime]+qnorm(.975)*se,accepted_draws=NA_integer_))
  }
  point <- sp_impact(beta[crime],theta,eigenvalues,island_fraction)
  set.seed(seed)
  covariance <- V[c(crime,theta_name),c(crime,theta_name)]
  stopifnot(all(is.finite(covariance)),min(eigen(covariance,symmetric=TRUE,only.values=TRUE)$values)>-1e-10)
  sims <- MASS::mvrnorm(draws,mu=c(beta[crime],theta),Sigma=covariance)
  keep <- sims[,2]>interval[1]&sims[,2]<interval[2]&abs(1-sims[,2])>1e-8
  sims <- sims[keep,,drop=FALSE]
  stopifnot(nrow(sims)>.95*draws)
  effects <- t(vapply(seq_len(nrow(sims)),function(i)sp_impact(sims[i,1],sims[i,2],eigenvalues,island_fraction),numeric(3)))
  stopifnot(max(abs(rowSums(effects[,1:2])-effects[,3]))<1e-8)
  data.frame(effect=c("Direct","Indirect","Total"),log_effect=unname(point),
    log_low=apply(effects,2,quantile,.025),log_high=apply(effects,2,quantile,.975),accepted_draws=nrow(sims))
}
sp_cache_fit <- function(path,signature,fit) {
  if(file.exists(path)) {
    cached <- readRDS(path)
    if(identical(cached$signature,signature)) {
      for(message in cached$warnings)warning(message,call.=FALSE)
      return(cached$fit)
    }
  }
  messages <- character()
  value <- withCallingHandlers(fit(),warning=function(w){messages<<-c(messages,conditionMessage(w));invokeRestart("muffleWarning")})
  saveRDS(list(signature=signature,fit=value,warnings=messages),path)
  for(message in messages)warning(message,call.=FALSE)
  value
}
