source("R/bg_exploratory_config.R")
source("R/housing_derivation_helpers.R")
cfg <- bg_exploratory_config
base <- readRDS(file.path(bg_model_config$analytic_dir,"model_sample.rds"))
counts <- readRDS(file.path(cfg$analytic_dir,"source_counts.rds"))
fields <- setdiff(names(counts),c("GEOID",names(base)))
x <- dplyr::left_join(base,counts[c("GEOID",fields)],by="GEOID")
stopifnot(identical(x$GEOID,base$GEOID))
# Table-specific renter totals must agree with the existing tenure denominator.
totals <- c("b25038_009","b25007_012","b25009_010","b25014_008","b25049_005","b25053_005")
for (name in totals) {
  value <- x[[paste0(name,"_estimate")]]
  valid <- is.finite(value)
  stopifnot(all(value[valid] == x$renter_occupied_units_estimate[valid]))
}
partitions <- list(b25038_009=paste0("b25038_",sprintf("%03d",10:15)),
  b25007_012=paste0("b25007_",sprintf("%03d",13:21)),
  b25009_010=paste0("b25009_",sprintf("%03d",11:17)),
  b25014_008=paste0("b25014_",sprintf("%03d",9:13)),
  b25049_005=c("b25049_006","b25049_007"),b25053_005=c("b25053_006","b25053_007"))
for (name in names(partitions)) {
  sum <- rowSums(as.matrix(x[paste0(partitions[[name]],"_estimate")]))
  total <- x[[paste0(name,"_estimate")]]
  valid <- is.finite(sum)&is.finite(total)
  stopifnot(all(sum[valid]==total[valid]))
}
derived <- list()
for (name in names(bg_exploratory_shares)) {
  def <- bg_exploratory_shares[[name]]
  values <- derive_housing_percentage(x,def)
  x[[paste0(name,"_pct")]] <- values$estimate
  x[[paste0(name,"_pct_moe")]] <- values$moe
  x[[paste0(name,"_10pp")]] <- values$estimate/10
  derived[[name]] <- data.frame(GEOID=x$GEOID,variable=name,
    numerator=paste(def$numerator,collapse=" + "),denominator=paste(def$denominator,collapse=" + "),values)
}
x$renter_median_rooms <- x$b25021_003_estimate
x$renter_median_rooms_moe <- x$b25021_003_moe
# Preserve but do not treat open-ended room medians as exact continuous values.
annotated_rooms <- !is.na(x$b25021_003_estimate_annotation) & nzchar(x$b25021_003_estimate_annotation)
x$renter_median_rooms[annotated_rooms] <- NA_real_
variables <- unique(unlist(bg_exploratory_domains))
coverage <- dplyr::bind_rows(lapply(variables,function(term) {
  name <- sub("_10pp$","_pct",term)
  value <- x[[term]]
  moe <- x[[paste0(name,"_moe")]]
  finite <- is.finite(value)
  data.frame(term=term,label=unname(bg_exploratory_labels[term]),eligible=sum(finite),
    missing=sum(!finite),nonzero=sum(finite & value!=0),distinct=length(unique(value[finite])),
    missing_moe=sum(finite & !is.finite(moe)),median=if(any(finite))stats::median(value[finite]) else NA_real_,
    p95=if(any(finite))unname(stats::quantile(value[finite],.95)) else NA_real_)
}))
saveRDS(x,file.path(cfg$analytic_dir,"exploratory_inputs.rds"))
saveRDS(dplyr::bind_rows(derived),file.path(cfg$analytic_dir,"derived_measures_long.rds"))
readr::write_csv(dplyr::bind_rows(derived),file.path(cfg$analytic_dir,"derived_measures_long.csv"))
readr::write_csv(coverage,file.path(cfg$analytic_dir,"variable_coverage.csv"))
readr::write_csv(data.frame(GEOID=x$GEOID,stats::setNames(lapply(variables,function(term)is.finite(x[[term]])),variables)),
  file.path(cfg$analytic_dir,"availability_audit.csv"))
message("Prepared ",length(variables)," exploratory predictors for ",nrow(x)," baseline areas")
print(coverage[c("term","eligible","missing","nonzero")],row.names=FALSE)
