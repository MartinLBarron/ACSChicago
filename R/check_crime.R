source("R/crime_config.R")
source("R/crime_helpers.R")
cfg <- crime_config
crime_validate_manifest(cfg$raw_dir)
r <- readRDS(file.path(cfg$analytic_dir, "model_results.rds"))
base <- readRDS(file.path(bg_model_config$analytic_dir, "model_results.rds"))
assigned <- readRDS(file.path(cfg$analytic_dir, "violent_record_assignment.rds"))
grid <- readr::read_csv(file.path(cfg$analytic_dir, "counts_by_year_offense.csv"),
  col_types = readr::cols(GEOID = readr::col_character()))
stopifnot(!r$synthetic_data, identical(r$data$GEOID, base$data$GEOID), !anyDuplicated(assigned$id),
  all(assigned$occurrence_year %in% cfg$years),
  all(assigned$included), all(assigned$violent_group %in% c("homicide", "sexual_assault", "robbery", "aggravated_assault", "aggravated_battery")),
  sum(grid$recorded_rows) == sum(!is.na(assigned$GEOID)),
  sum(r$data$violent_crime_count) == sum(assigned$in_model_sample),
  all(is.na(assigned$GEOID[assigned$coordinate_status != "usable"])),
  all(r$data$violent_crime_count >= 0), all(r$data$violent_crime_count %% 1 == 0))
direct <- table(factor(assigned$GEOID, levels = r$data$GEOID))
stopifnot(identical(as.integer(direct), as.integer(r$data$violent_crime_count)))
expected <- c(attr(stats::terms(r$models$M3), "term.labels"), "violent_crime_count")
stopifnot(setequal(attr(stats::terms(r$models$M5), "term.labels"), expected),
  max(abs(stats::model.matrix(r$models$M5)[, "violent_crime_count"] - r$data$violent_crime_count)) == 0,
  max(abs(stats::fitted(r$models$M3) - stats::fitted(base$models$M3))) < 1e-8,
  stats::nobs(r$models$M3) == stats::nobs(r$models$M5),
  r$metrics$r_squared[r$metrics$model == "M5"] >= r$metrics$r_squared[r$metrics$model == "M3"] - 1e-10,
  nrow(r$cv$failures) == 0)
predictions <- r$cv$predictions
sets <- split(predictions$GEOID, predictions$model)
stopifnot(setequal(sets$M3, sets$M5), all(is.finite(predictions$predicted)),
  all(predictions$fold == base$cv$assignments$fold[match(predictions$GEOID, base$cv$assignments$GEOID)]))
keep <- table(r$data$community_id)[as.character(r$data$community_id)] > 1
fit <- stats::lm(crime_formula, data = droplevels(r$data[keep, ]))
X <- stats::model.matrix(fit); bread <- solve(crossprod(X))
adjusted <- stats::residuals(fit)/(1 - stats::hatvalues(fit))
covariance <- bread %*% crossprod(X * adjusted) %*% bread
stopifnot(abs(sqrt(covariance["violent_crime_count", "violent_crime_count"]) - r$crime_effect$hc3_se) < 1e-9,
  abs(stats::coef(fit)["violent_crime_count"] - r$crime_effect$estimate) < 1e-9,
  abs(100 * expm1(100 * r$crime_effect$estimate) - r$crime_effect$percent_per100_estimate) < 1e-10,
  all(stats::model.frame(r$strict_models$M5)$violent_crime_count == r$data$violent_crime_count[r$data$city_fraction >= bg_model_config$strict_city_share]),
  all(is.finite(r$loco$crime_coefficient)))
# Independent behavioral fixtures for classification and spatial edge cases.
lookup <- r$iucr
included <- lookup$iucr[lookup$included]
stopifnot(all(c("0110", "0130", "0261", "0281", "031A", "041A", "051A") %in% included),
  all(c("1753", "1754", "0490", "0491", "0492", "0493", "0510") %in% included),
  !any(c("0141", "0142", "0440", "0460", "0486", "0560") %in% included),
  "0499" %in% included) # Inactive aggravated domestic-battery code must remain eligible.
crosscheck <- readr::read_csv(file.path(cfg$analytic_dir, "fbi_definition_crosscheck.csv"), show_col_types = FALSE)
stopifnot(nrow(crosscheck) == 0)
fixture <- crime_coordinates(c("41.88", NA, "0", "bad"), c("-87.65", "-87.6", "0", "-87.6"), cfg$coordinate_bounds)
stopifnot(identical(fixture$coordinate_status, c("usable", "missing_coordinates", "outside_regional_bounds", "invalid_coordinates")))
square <- function(x) sf::st_polygon(list(matrix(c(x,0,x+1,0,x+1,1,x,1,x,0), ncol = 2, byrow = TRUE)))
polygons <- sf::st_sf(GEOID = c("02", "01"), geometry = sf::st_sfc(square(0), square(1), crs = cfg$crs))
points <- sf::st_as_sf(data.frame(x = c(.5,1,3), y = c(.5,.5,.5)), coords = c("x", "y"), crs = cfg$crs)
matched <- crime_assign_points(points, polygons)
stopifnot(identical(matched$GEOID, c("02", "01", NA_character_)), matched$spatial_matches[2] == 2,
  matched$assignment_rule[2] == "boundary_GEOID_tiebreak")
p <- jsonlite::read_json(file.path(cfg$output_dir, "provenance.json"), simplifyVector = TRUE)
hashes <- unlist(p$input_md5)
stopifnot(identical(unname(tools::md5sum(names(hashes))), unname(hashes)))
message("PASS: crime dates/IDs/definition, coordinate and boundary fixtures, conserved row counts, unchanged sample/folds, literal raw-count M5, strict-city fit, independent HC3 and source hashes")
