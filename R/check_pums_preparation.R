# Synthetic fixtures only: check vacancy retention, exclusions, and source preservation.
source("R/pums_config.R")
source("R/pums_helpers.R")
SYNTHETIC_DATA <- TRUE
lookup <- pums_puma_lookup(pums_config)
codes <- c(lookup$puma_code, substr(unname(acs_config$excluded_puma_geoids[["2020"]])[1:2], 3, 7))
n <- length(codes)
raw <- as.data.frame(stats::setNames(rep(list(rep(NA_real_, n)), length(pums_config$variables)),
                                    pums_config$variables))
raw$SERIALNO <- sprintf("fixture%03d", seq_len(n))
raw$STATE <- rep("17", n)
raw$PUMA <- codes
raw$TYPEHUGQ <- rep("1", n)
raw$SPORDER <- rep("01", n)
raw$TEN <- rep("3", n)
raw$VACS <- rep("b", n)
raw$NP <- rep(2, n)
raw$RNTP <- rep(1000, n)
raw$GRNTP <- rep(1100, n)
raw$WGTP <- rep(50, n)
for (i in 1:80) raw[[paste0("WGTP", i)]] <- rep(50, n)
raw$WGTP1[1] <- -2 # Legitimate negative replicate weight must survive unchanged.
raw$VACS[2] <- "1"
raw$TEN[2] <- "b"
raw$NP[2] <- 0
raw$SPORDER[2] <- NA_character_
raw$RNTP[2] <- raw$GRNTP[2] <- NA_real_
raw$TEN[3] <- "2" # Owner occupied; do not silently create a renter-only sample.
raw$TEN[4] <- "4" # Occupied without cash rent; retain unavailable rent values.
raw$RNTP[3:4] <- raw$GRNTP[3:4] <- NA_real_
for (name in c("TEN", "VACS", "BLD", "YRBLT")) raw[[paste0(name, "_label")]] <- factor(rep("fixture", n))
x <- prepare_chicago_pums(raw, lookup, pums_config)
stopifnot(nrow(x) == 18, sum(x$is_vacant) == 1,
  x$WGTP1[match(raw$SERIALNO[1], x$SERIALNO)] == -2,
  all(raw$SERIALNO[3:4] %in% x$SERIALNO),
  !any(tail(raw$SERIALNO, 2) %in% x$SERIALNO),
  all(x$synthetic_data))
bad <- raw
bad$SERIALNO[2] <- bad$SERIALNO[1]
stopifnot(inherits(tryCatch(validate_pums_housing(bad, pums_config), error = identity), "error"))
message("Synthetic PUMS preparation checks passed: vacant/owner/no-cash-rent units, ",
        "negative replicate weights, exclusions, factor labels, and duplicate-ID rejection.")
