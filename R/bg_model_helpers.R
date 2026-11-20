# Statistical helpers for the area-level study. No household survey weights apply.
bg_fit_summary <- function(fit, name) {
  y <- stats::model.response(stats::model.frame(fit))
  w <- stats::weights(fit)
  if (is.null(w)) w <- rep(1, length(y))
  sse <- sum(w * stats::residuals(fit)^2)
  sst <- sum(w * (y - stats::weighted.mean(y, w))^2)
  n <- length(y)
  p <- fit$rank
  data.frame(model = name, n = n, parameters = p, residual_df = stats::df.residual(fit),
    sse = sse, sst = sst, r_squared = 1 - sse / sst,
    adjusted_r_squared = 1 - (sse / (n - p)) / (sst / (n - 1)),
    rmse_log = sqrt(sse / sum(w)), AIC_working = stats::AIC(fit))
}

bg_coefficient_table <- function(fit, name, data, confidence = .95, term_labels = bg_term_labels) {
  beta <- stats::coef(fit)
  stopifnot(all(is.finite(beta)))
  # Saturated singleton indicators have leverage 1. They provide no information
  # on within-community slopes. Refit without them for HC3; slopes are identical.
  singleton <- table(data$community_id)[as.character(data$community_id)] == 1
  has_fe <- "community_id" %in% names(stats::model.frame(fit))
  hc <- matrix(NA_real_, length(beta), length(beta), dimnames = list(names(beta), names(beta)))
  if (has_fe && any(singleton)) {
    reduced <- stats::lm(stats::formula(fit), data = droplevels(data[!singleton, ]), na.action = stats::na.fail)
    cov <- sandwich::vcovHC(reduced, type = "HC3")
    common <- intersect(rownames(cov), names(beta))
    hc[common, common] <- cov[common, common]
    stopifnot(max(abs(stats::coef(reduced)[bg_predictors[bg_predictors %in% names(beta)]] -
      beta[bg_predictors[bg_predictors %in% names(beta)]])) < 1e-8)
  } else hc <- sandwich::vcovHC(fit, type = "HC3")
  cl <- sandwich::vcovCL(fit, cluster = data$community_id, type = "HC1", cadjust = TRUE)
  cluster_df <- nlevels(droplevels(data$community_id)) - 1
  out <- data.frame(model = name, term = names(beta), estimate = unname(beta),
    hc3_se = sqrt(pmax(0, diag(hc))), cluster_se = sqrt(pmax(0, diag(cl))),
    row.names = NULL)
  for (type in c("hc3", "cluster")) {
    df <- if (type == "hc3") stats::df.residual(fit) else cluster_df
    critical <- stats::qt((1 + confidence) / 2, df)
    out[[paste0(type, "_conf_low")]] <- out$estimate - critical * out[[paste0(type, "_se")]]
    out[[paste0(type, "_conf_high")]] <- out$estimate + critical * out[[paste0(type, "_se")]]
    out[[paste0(type, "_p_value")]] <- 2 * stats::pt(-abs(out$estimate / out[[paste0(type, "_se")]]), df)
  }
  # Community coefficients have only one cluster each: do not publish CR1 intervals.
  is_community <- grepl("^community_id", out$term)
  out[is_community, grep("^cluster_", names(out))] <- NA_real_
  multiplier <- ifelse(out$term == "log_income", log(1.1), 1)
  for (field in c("estimate", "hc3_conf_low", "hc3_conf_high", "cluster_conf_low", "cluster_conf_high")) {
    out[[paste0("percent_", field)]] <- 100 * expm1(out[[field]] * multiplier)
  }
  out$label <- unname(term_labels[out$term])
  out$label[is.na(out$label)] <- out$term[is.na(out$label)]
  out
}

bg_vif <- function(fit, model, predictors = bg_predictors) {
  matrix <- stats::model.matrix(fit)
  terms <- intersect(predictors, colnames(matrix))
  dplyr::bind_rows(lapply(terms, function(term) {
    y <- matrix[, term]
    remaining <- matrix[, colnames(matrix) != term, drop = FALSE]
    residual <- stats::lm.fit(remaining, y)$residuals
    r2 <- 1 - sum(residual^2) / sum((y - mean(y))^2)
    data.frame(model = model, term = term, VIF = 1 / (1 - r2))
  }))
}

bg_spatial_diagnostics <- function(data, models, cfg) {
  geometry <- sf::st_read(file.path(cfg$analytic_dir, "geographic_assignment.gpkg"), quiet = TRUE)
  geometry <- geometry[match(data$GEOID, geometry$GEOID), ]
  stopifnot(identical(geometry$GEOID, data$GEOID))
  nb <- suppressWarnings(spdep::poly2nb(geometry, queen = TRUE, snap = .05, row.names = geometry$GEOID))
  weights <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
  knn <- spdep::knn2nb(spdep::knearneigh(sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(geometry))), k = 4), sym = TRUE)
  knn_weights <- spdep::nb2listw(knn, style = "W")
  values <- c(list(observed_log_rent = data$log_rent), lapply(models, stats::residuals))
  rows <- list()
  i <- 0L
  for (kind in c("queen", "knn4")) {
    W <- if (kind == "queen") weights else knn_weights
    for (name in names(values)) {
      i <- i + 1L
      set.seed(cfg$seed + i)
      result <- spdep::moran.mc(values[[name]], W, nsim = cfg$moran_permutations,
                                alternative = "two.sided", zero.policy = TRUE)
      # Add-one tail probabilities avoid a reported zero from the package's
      # two-sided rank interpolation; double the smaller permutation tail.
      simulations <- result$res[seq_len(cfg$moran_permutations)]
      observed <- unname(result$statistic)
      p <- min(1, 2 * min((1 + sum(simulations >= observed)) / (cfg$moran_permutations + 1),
                          (1 + sum(simulations <= observed)) / (cfg$moran_permutations + 1)))
      rows[[i]] <- data.frame(weights = kind, model = name, Moran_I = unname(result$statistic),
        permutation_p = p, permutations = cfg$moran_permutations)
    }
  }
  list(geometry = geometry, queen = weights, knn4 = knn_weights,
    results = dplyr::bind_rows(rows),
    graph = data.frame(neighbor_rule = c("queen", "knn4"),
      islands = c(sum(spdep::card(nb) == 0), sum(spdep::card(knn) == 0)),
      components = c(spdep::n.comp.nb(nb)$nc, spdep::n.comp.nb(knn)$nc),
      mean_neighbors = c(mean(spdep::card(nb)), mean(spdep::card(knn)))))
}

bg_cross_validation <- function(data, cfg) {
  # Whole tracts stay in one fold; balance tract folds within dominant communities.
  tracts <- data |> dplyr::count(tract, community_id, name = "n") |>
    dplyr::group_by(tract) |> dplyr::arrange(dplyr::desc(n), community_id, .by_group = TRUE) |>
    dplyr::slice_head(n = 1) |> dplyr::ungroup() |> dplyr::arrange(community_id, tract)
  set.seed(cfg$seed)
  tracts$fold <- NA_integer_
  for (id in unique(tracts$community_id)) {
    index <- which(tracts$community_id == id)
    pool <- rep(sample.int(cfg$cv_folds), length.out = length(index))
    tracts$fold[index] <- pool[sample.int(length(index))]
  }
  folds <- tracts$fold[match(data$tract, tracts$tract)]
  predictions <- list()
  for (fold in seq_len(cfg$cv_folds)) {
    train <- droplevels(data[folds != fold, ])
    test <- data[folds == fold, ]
    eligible <- as.character(test$community_id) %in% levels(train$community_id)
    # Common eligible test rows for every model: never invent unseen-area effects.
    test_common <- test[eligible, ]
    test_common$community_id <- factor(as.character(test_common$community_id), levels = levels(train$community_id))
    for (name in c("M0", "M1", "M2a", "M2", "M3", "M4")) {
      fit <- stats::lm(bg_formulas[[name]], data = train, na.action = stats::na.fail)
      prediction <- as.numeric(stats::predict(fit, newdata = test_common))
      predictions[[length(predictions) + 1L]] <- data.frame(model = name, fold = fold,
        GEOID = test_common$GEOID, observed = test_common$log_rent, predicted = prediction,
        training_mean = mean(train$log_rent), unseen_community_test_rows = sum(!eligible))
    }
  }
  predictions <- dplyr::bind_rows(predictions)
  metrics <- predictions |> dplyr::group_by(model) |> dplyr::summarise(
    test_BGs = dplyr::n(), RMSE_log = sqrt(mean((observed - predicted)^2)),
    MAE_log = mean(abs(observed - predicted)),
    predictive_R2 = 1 - sum((observed - predicted)^2) / sum((observed - training_mean)^2), .groups = "drop")
  list(metrics = metrics, predictions = predictions,
    assignments = data.frame(GEOID = data$GEOID, tract = data$tract, fold = folds),
    excluded_unseen = nrow(data) - length(unique(predictions$GEOID)))
}

bg_sensitivity_fit <- function(data, name, weights = NULL) {
  data <- droplevels(data)
  if (nrow(data) < 100 || nlevels(data$community_id) < 2) return(NULL)
  if (!is.null(weights)) data$analysis_weight <- weights else data$analysis_weight <- 1
  fits <- lapply(bg_formulas[c("M1", "M2", "M3", "M4")], function(formula) {
    stats::lm(formula, data = data, weights = analysis_weight, na.action = stats::na.fail)
  })
  metrics <- dplyr::bind_rows(lapply(names(fits), function(model) bg_fit_summary(fits[[model]], model)))
  coefficients <- dplyr::bind_rows(lapply(names(fits), function(model) {
    beta <- stats::coef(fits[[model]])
    data.frame(sensitivity = name, model = model, term = names(beta), estimate = unname(beta))
  }))
  metrics$sensitivity <- name
  list(metrics = metrics, coefficients = coefficients)
}
