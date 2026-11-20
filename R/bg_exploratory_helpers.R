# Compare all specifications on identical held-out cases and fixed tract folds.
ex_cv <- function(data, formulas, assignments) {
  folds <- assignments$fold[match(data$GEOID,assignments$GEOID)]
  stopifnot(!anyNA(folds))
  rows <- list()
  failures <- list()
  for (fold in sort(unique(folds))) {
    train <- droplevels(data[folds!=fold,])
    test <- data[folds==fold,]
    keep <- as.character(test$community_id) %in% levels(train$community_id)
    test <- test[keep,]
    test$community_id <- factor(as.character(test$community_id),levels=levels(train$community_id))
    for (name in names(formulas)) {
      fit <- stats::lm(formulas[[name]],data=train,na.action=stats::na.fail)
      if (fit$rank < length(stats::coef(fit))) {
        failures[[length(failures)+1L]] <- data.frame(fold=fold,model=name,reason="Rank-deficient training design")
        next
      }
      rows[[length(rows)+1L]] <- data.frame(model=name,fold=fold,GEOID=test$GEOID,
        observed=test$log_rent,predicted=as.numeric(stats::predict(fit,newdata=test)),
        training_mean=mean(train$log_rent))
    }
  }
  predictions <- dplyr::bind_rows(rows)
  # Never compare a model scored on fewer folds with one scored on all folds.
  valid_models <- names(formulas)[vapply(names(formulas),function(name) {
    setequal(unique(predictions$fold[predictions$model==name]),unique(folds))
  },logical(1))]
  metrics <- predictions[predictions$model %in% valid_models,] |>
    dplyr::group_by(model) |> dplyr::summarise(test_BGs=dplyr::n(),
      RMSE_log=sqrt(mean((observed-predicted)^2)),MAE_log=mean(abs(observed-predicted)),
      predictive_R2=1-sum((observed-predicted)^2)/sum((observed-training_mean)^2),.groups="drop")
  list(metrics=metrics,predictions=predictions,failures=dplyr::bind_rows(failures),
       excluded_unseen=nrow(data)-length(unique(predictions$GEOID)))
}

ex_diagnostic <- function(fit, data, weights) {
  singleton <- table(data$community_id)[as.character(data$community_id)]==1
  reduced <- if(any(singleton)) stats::lm(stats::formula(fit),data=droplevels(data[!singleton,])) else fit
  bp <- lmtest::bptest(fit)
  reset <- tryCatch(lmtest::resettest(reduced,power=2:3,type="fitted",
    vcov=function(m)sandwich::vcovHC(m,type="HC3")),error=function(e)NULL)
  moran <- spdep::moran(stats::residuals(fit),weights,
    n=nrow(data)-sum(spdep::card(weights$neighbours)==0),S0=spdep::Szero(weights),zero.policy=TRUE)$I
  data.frame(BP_statistic=unname(bp$statistic),BP_p=bp$p.value,
    RESET_p=if(is.null(reset))NA_real_ else reset$p.value,
    residual_Moran_I=moran,max_leverage=max(stats::hatvalues(fit)),singleton_communities=sum(table(data$community_id)==1))
}
