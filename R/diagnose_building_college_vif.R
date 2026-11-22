# Exploratory sensitivity only: retain the agreed sample and all other controls.
source("R/crime_stages_config.R")
source("R/bg_model_helpers.R")
original <- readRDS(file.path(crime_stages_config$analytic_dir,"model_results.rds"))
d <- original$data
out_dir <- "output/models/building_college_vif_2024"
dir.create(out_dir,recursive=TRUE,showWarnings=FALSE)
variants <- c("Original","Omit 20+","Omit 20+ and college")
fits <- vifs <- summaries <- list()
for(model in c("M2","M3","M4")) for(variant in variants) {
  formula <- crime_stage_formulas[[model]]
  if(variant=="Omit 20+") formula <- stats::update(formula,.~.-structure_20_plus_10pp)
  if(variant=="Omit 20+ and college") formula <- stats::update(formula,.~.-structure_20_plus_10pp-college_10pp)
  fit <- stats::lm(formula,data=d,na.action=stats::na.fail)
  stopifnot(nobs(fit)==nrow(d),fit$rank==length(coef(fit)),identical(rownames(model.frame(fit)),rownames(model.frame(original$models[[model]]))))
  omitted <- if(variant=="Original")character() else if(variant=="Omit 20+")"structure_20_plus_10pp" else c("structure_20_plus_10pp","college_10pp")
  stopifnot(setequal(names(coef(fit)),setdiff(names(coef(original$models[[model]])),omitted)))
  key <- paste(model,variant,sep=" / ")
  fits[[key]] <- fit
  vif <- bg_vif(fit,model,predictors=c("violent_crime_count",bg_predictors))
  vif$variant <- variant
  vifs[[key]] <- vif
  metric <- bg_fit_summary(fit,model)
  crime <- bg_coefficient_table(fit,model,d)
  crime <- crime[crime$term=="violent_crime_count",]
  metric$variant <- variant
  metric$max_VIF <- max(vif$VIF)
  metric$max_VIF_term <- vif$term[which.max(vif$VIF)]
  metric$max_housing_VIF <- max(vif$VIF[vif$term %in% c(bg_housing_terms)])
  metric$crime_pct_per100 <- 100*expm1(100*crime$estimate)
  metric$crime_pct_per100_low <- 100*expm1(100*crime$hc3_conf_low)
  metric$crime_pct_per100_high <- 100*expm1(100*crime$hc3_conf_high)
  summaries[[key]] <- metric
  if(variant=="Original") {
    previous <- original$vif[original$vif$model==model,]
    stopifnot(isTRUE(all.equal(vif$VIF[match(previous$term,vif$term)],previous$VIF)),
      abs(metric$r_squared-original$metrics$r_squared[original$metrics$model==model])<1e-10)
  }
}
vif <- dplyr::bind_rows(vifs)
summary <- dplyr::bind_rows(summaries)
# Diagnostic reductions must preserve cases and remove only the intended parameters.
for(model in c("M2","M3","M4")) {
  block <- summary[summary$model==model,]
  stopifnot(block$r_squared[block$variant=="Omit 20+ and college"] <= block$r_squared[block$variant=="Omit 20+"]+1e-10,
    all(block$n==nrow(d)),all(block$r_squared<=block$r_squared[block$variant=="Original"]+1e-10),
    block$parameters[block$variant=="Omit 20+"]==block$parameters[block$variant=="Original"]-1,
    block$parameters[block$variant=="Omit 20+ and college"]==block$parameters[block$variant=="Original"]-
      sum(c("structure_20_plus_10pp","college_10pp") %in% names(coef(original$models[[model]]))))
}
readr::write_csv(vif,file.path(out_dir,"vif.csv"))
readr::write_csv(summary,file.path(out_dir,"fit_and_crime.csv"))
wide <- tidyr::pivot_wider(vif,id_cols=c("model","term"),names_from=variant,values_from=VIF)
readr::write_csv(wide,file.path(out_dir,"vif_comparison.csv"))
analytic_dir <- "data/analytic/building_college_vif_2024"
dir.create(analytic_dir,recursive=TRUE,showWarnings=FALSE)
saveRDS(list(data=d,fits=fits,vif=vif,summary=summary,synthetic_data=SYNTHETIC_DATA),file.path(analytic_dir,"diagnostic_models.rds"))
jsonlite::write_json(list(input_md5=unname(tools::md5sum(file.path(crime_stages_config$analytic_dir,"model_results.rds"))),
  formulas=lapply(fits,function(fit)paste(deparse(formula(fit)),collapse=" ")),sample=nrow(d),
  primary_models_unchanged=TRUE),file.path(out_dir,"provenance.json"),auto_unbox=TRUE,pretty=TRUE)
# A compact reproducible report alongside the complete machine-readable VIF table.
md_table <- function(x) {
  x[] <- lapply(x,function(v)if(is.numeric(v))ifelse(is.na(v),"—",formatC(v,digits=3,format="f")) else as.character(v))
  c(paste0("| ",paste(names(x),collapse=" | ")," |"),paste0("| ",paste(rep("---",ncol(x)),collapse=" | ")," |"),
    apply(x,1,function(row)paste0("| ",paste(row,collapse=" | ")," |")))
}
report <- c("# Building-size and college-share VIF sensitivity: Chicago 2020–2024", "",
  sprintf("Same %s block groups, log median contract rent and equal BG weights. Official public data; not synthetic.",nrow(d)),"",
  "These are exploratory diagnostic refits of M2–M4. M0 and M1 contain neither removed predictor and remain unchanged. College share was never included in M2, so its two omission alternatives are identical. The sample is deliberately unchanged, even though dropping controls might otherwise admit additional cases.","",
  "Omitting 20+ expands the building reference group to include 20+-unit rentals. The additional alternative also removes college share from M3/M4, retaining the no-high-school share and all other controls, including community indicators in M4. This changes the adjustment set; lower VIF alone cannot determine the preferred model.","",
  "## Fit, collinearity and crime association","",
  md_table(summary[c("model","variant","n","r_squared","adjusted_r_squared","max_VIF","max_housing_VIF","crime_pct_per100","crime_pct_per100_low","crime_pct_per100_high")]),"",
  "Crime contrasts are associated percentage differences per 100 additional recorded violent-crime rows, with 95% HC3 intervals. The predictor remains the literal count. Community-indicator singleton safeguards follow the main study.","",
  "## VIFs by predictor","",md_table(wide),"",
  "VIFs apply to continuous predictors; M4 auxiliary regressions include all community indicators. A removed predictor has no VIF, rather than a VIF of zero. Five is a screening convention, not a model-selection rule. Lower VIF does not establish better specification or remove omitted-variable bias.","",
  "## Reproduce","","Run `Rscript R/diagnose_building_college_vif.R` from the project root. Original refits must reproduce the existing VIF/fit results; checks also enforce identical cases, full rank and the intended parameter reductions. Main reports and the website are unchanged.")
writeLines(report,file.path(out_dir,"report.md"))
print(summary[c("model","variant","r_squared","adjusted_r_squared","max_VIF","max_housing_VIF","crime_pct_per100")],row.names=FALSE)
print(summary[c("model","variant","max_VIF_term","crime_pct_per100_low","crime_pct_per100_high")],row.names=FALSE)
message("PASS: original-model reproduction, identical samples and constrained-model checks")
