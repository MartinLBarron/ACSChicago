source("R/bg_exploratory_config.R")
source("R/bg_model_helpers.R")
source("R/bg_exploratory_helpers.R")
cfg <- bg_exploratory_config
base <- readRDS(file.path(bg_model_config$analytic_dir,"model_results.rds"))
x <- readRDS(file.path(cfg$analytic_dir,"exploratory_inputs.rds"))
coverage <- readr::read_csv(file.path(cfg$analytic_dir,"variable_coverage.csv"),show_col_types=FALSE)
dir.create(cfg$output_dir,recursive=TRUE,showWarnings=FALSE)
groups <- bg_exploratory_domains
available <- coverage$term[coverage$eligible>=100 & coverage$distinct>=2]
# Explicitly record exclusions from combinations; never let an unavailable domain
# erase all cases for otherwise feasible candidates.
priority_requested <- unique(unlist(groups[c("vacancy","finer_bedrooms")]))
groups$priority_available <- intersect(priority_requested,available)
groups$all_available <- intersect(unique(unlist(bg_exploratory_domains)),available)
ids <- stats::setNames(paste0("E",seq_along(groups)),names(groups))
results <- list(); audit <- list(); formulas_audit <- list()
for (domain in names(groups)) {
  terms <- groups[[domain]]
  valid <- stats::complete.cases(x[terms]) & apply(as.matrix(x[terms]),1,function(row)all(is.finite(row)))
  data <- droplevels(x[valid,])
  status <- if(nrow(data)<100)"Too few complete areas" else if(any(vapply(data[terms],function(v)length(unique(v))<2,logical(1))))"Constant candidate predictor" else "fit"
  audit[[domain]] <- data.frame(model=ids[[domain]],domain=domain,baseline_n=nrow(x),paired_n=nrow(data),
    excluded=nrow(x)-nrow(data),status=status,
    terms=paste(terms,collapse=" + "))
  if(status!="fit") next
  extended <- unique(c(bg_predictors,terms))
  formulas <- list(baseline_no_location=bg_formulas$M2,baseline_location=bg_formulas$M3,
    expanded_no_location=stats::reformulate(extended,"log_rent"),
    expanded_location=stats::reformulate(c(extended,"community_id"),"log_rent"))
  fits <- lapply(formulas,stats::lm,data=data,na.action=stats::na.fail)
  if(any(vapply(fits,function(m)m$rank<length(stats::coef(m)),logical(1)))) {
    audit[[domain]]$status <- "Rank-deficient full-sample design"; next
  }
  metrics <- dplyr::bind_rows(lapply(names(fits),function(name)bg_fit_summary(fits[[name]],name)))
  cv <- ex_cv(data,formulas,base$cv$assignments)
  metrics <- dplyr::left_join(metrics,cv$metrics,by="model")
  coefficients <- bg_coefficient_table(fits$expanded_location,ids[[domain]],data,
    term_labels=c(bg_term_labels,bg_exploratory_labels))
  vif <- bg_vif(fits$expanded_location,ids[[domain]],predictors=extended)
  weights <- suppressWarnings(spdep::subset.listw(base$spatial$queen,subset=valid,zero.policy=TRUE))
  diagnostics <- dplyr::bind_rows(lapply(c("baseline_location","expanded_location"),function(name) {
    cbind(data.frame(model=name),ex_diagnostic(fits[[name]],data,weights))
  }))
  formulas_audit[[domain]] <- data.frame(experiment=ids[[domain]],domain=domain,model=names(formulas),
    formula=vapply(formulas,function(f)paste(deparse(f),collapse=" "),character(1)))
  results[[domain]] <- list(id=ids[[domain]],terms=terms,data=data[c("GEOID","community_id","tract")],
    models=fits,metrics=metrics,cv=cv,coefficients=coefficients,vif=vif,diagnostics=diagnostics)
  message(ids[[domain]]," ",domain,": ",nrow(data)," paired areas")
}
audit <- dplyr::bind_rows(audit)
summary <- dplyr::bind_rows(lapply(names(results),function(domain) {
  result <- results[[domain]]; m <- result$metrics
  get <- function(name,field) m[[field]][match(name,m$model)]
  data.frame(experiment=result$id,domain=domain,n=nrow(result$data),
    baseline_R2=get("baseline_location","r_squared"),expanded_R2=get("expanded_location","r_squared"),
    added_R2=get("expanded_location","r_squared")-get("baseline_location","r_squared"),
    baseline_CV_R2=get("baseline_location","predictive_R2"),expanded_CV_R2=get("expanded_location","predictive_R2"),
    baseline_CV_RMSE=get("baseline_location","RMSE_log"),expanded_CV_RMSE=get("expanded_location","RMSE_log"),
    baseline_community_increment=get("baseline_location","r_squared")-get("baseline_no_location","r_squared"),
    expanded_community_increment=get("expanded_location","r_squared")-get("expanded_no_location","r_squared"),
    cv_excluded_unseen=result$cv$excluded_unseen,max_VIF=max(result$vif$VIF))
}))
bundle <- list(skipped=bg_exploratory_skipped,config=cfg,synthetic_data=SYNTHETIC_DATA,baseline_sample_n=nrow(x),coverage=coverage,
  unavailable_combination_terms=setdiff(unique(unlist(bg_exploratory_domains)),available),
  audit=audit,summary=summary,results=results,formulas=dplyr::bind_rows(formulas_audit),
  source_codebook=readr::read_csv(file.path(cfg$analytic_dir,"source_codebook.csv"),show_col_types=FALSE))
saveRDS(bundle,file.path(cfg$analytic_dir,"model_results.rds"))
readr::write_csv(summary,file.path(cfg$output_dir,"model_comparison.csv"))
readr::write_csv(audit,file.path(cfg$output_dir,"sample_audit.csv"))
readr::write_csv(bundle$formulas,file.path(cfg$output_dir,"formulas.csv"))
for (field in c("metrics","coefficients","vif","diagnostics")) {
  rows <- dplyr::bind_rows(lapply(names(results),function(domain) {
    cbind(data.frame(experiment=results[[domain]]$id,domain=domain),results[[domain]][[field]])
  }))
  readr::write_csv(rows,file.path(cfg$output_dir,paste0(field,".csv")))
}
inputs <- c(file.path(bg_model_config$analytic_dir,"model_results.rds"),
            file.path(cfg$analytic_dir,c("source_counts.rds","exploratory_inputs.rds")))
jsonlite::write_json(list(seed=cfg$seed,year=cfg$year,synthetic_data=SYNTHETIC_DATA,
  input_md5=as.list(tools::md5sum(inputs)),folds="Original baseline tract folds; identical eligible test rows per comparison"),
  file.path(cfg$output_dir,"provenance.json"),auto_unbox=TRUE,pretty=TRUE)
print(summary[c("experiment","domain","n","expanded_R2","expanded_CV_R2")],row.names=FALSE)
