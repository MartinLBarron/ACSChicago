# Synthetic fixtures verify sample rules and adjustment without actual unit records.
source("R/rent_model_config.R")
source("R/rent_model_helpers.R")
SYNTHETIC_DATA <- TRUE
n <- 36L
fixture <- data.frame(SERIALNO = sprintf("fixture%03d", 1:n),
  puma_geoid = rep(paste0("17", sprintf("%05d", 3151:3168)), 2),
  puma_name = "Synthetic PUMA", is_vacant = FALSE, TYPEHUGQ = "1", TEN = "3",
  RNTP = 1000, ADJHSG = "1000000", BDSP = 2, RMSP = 4, NP = 2, WGTP = 10,
  BLD = rep(c("03", "09"), 18), YRBLT = rep(c("01", "08"), 18),
  BLD_label = factor(rep(c("2 Apartments", "50 or more apartments"), 18), ordered = TRUE),
  YRBLT_label = factor(rep(c("1939 or earlier", "2000 to 2009"), 18), ordered = TRUE),
  synthetic_data = TRUE)
fixture$is_vacant[1] <- TRUE
fixture$TEN[2] <- "2"
fixture$TEN[3] <- "4"
fixture$RNTP[4] <- 0
fixture$ADJHSG[5] <- NA_character_
fixture$BDSP[6] <- NA_real_
fixture$WGTP[7] <- 0
fixture$ADJHSG[8] <- "1214548"
original <- fixture
result <- prepare_rent_model_sample(fixture)
sample <- result$sample
adjusted <- sample$contract_rent_2024[match(fixture$SERIALNO[8], sample$SERIALNO)]
stopifnot(identical(fixture, original), nrow(sample) == 29,
  !any(fixture$SERIALNO[1:7] %in% sample$SERIALNO), nlevels(sample$puma) == 18,
  !is.ordered(sample$building_size), !is.ordered(sample$year_built),
  isTRUE(all.equal(adjusted, 1214.548)),
  isTRUE(all.equal(sample$log_contract_rent, log(sample$contract_rent_2024))),
  all(result$waterfall$remaining == c(36, 35, 33, 32, 31, 30, 29)))
interval <- replicate_interval(10, rep(c(9, 11), 40), 4/80, 30, .95)
named_interval <- replicate_interval(c(named = 10), rep(c(9, 11), 40), 4/80, 30, .95)
stopifnot(interval[["std_error"]] == 2,
  identical(names(named_interval), c("estimate", "std_error", "conf_low", "conf_high")),
  weighted_fit(c(0, 2), c(1, 1), c(1, 1))[["r_squared"]] == 0)
message("Synthetic model-helper checks passed: exclusions, one dollar adjustment, ",
        "unordered factors, source preservation, and SDR variance scaling.")
