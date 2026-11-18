# PUMS preparation and validation. Microdata remain local; logs contain counts only.
pums_code <- function(x, width) {
  number <- suppressWarnings(as.integer(as.character(x)))
  if (anyNA(number)) stop("Missing or invalid PUMS geography code.")
  sprintf(paste0("%0", width, "d"), number)
}

validate_pums_housing <- function(x, config) {
  required <- c(config$variables, "SERIALNO", "SPORDER", "STATE", "WGTP",
                paste0("WGTP", 1:80))
  stopifnot(nrow(x) > 0L, all(required %in% names(x)),
    !anyNA(x$SERIALNO), !anyDuplicated(x$SERIALNO),
    all(pums_code(x$STATE, 2) == config$state_fips),
    all(as.character(x$TYPEHUGQ) == "1"))
  vacant <- as.character(x$VACS) %in% as.character(1:7)
  stopifnot(any(vacant), any(!vacant),
    all(is.na(x$SPORDER[vacant])),
    all(as.integer(as.character(x$SPORDER[!vacant])) == 1L),
    all(x$NP[vacant] == 0), all(x$NP[!vacant] > 0))
  # Replicate weights may legitimately be negative; never truncate them.
  weights <- as.matrix(x[c("WGTP", paste0("WGTP", 1:80))])
  stopifnot(is.numeric(weights), all(is.finite(weights)), all(x$WGTP >= 0),
    sum(x$WGTP) > 0,
    all(c("TEN_label", "VACS_label", "BLD_label", "YRBLT_label") %in% names(x)))
  invisible(TRUE)
}

pums_puma_lookup <- function(config) {
  if (!file.exists(config$boundary_path)) stop("Run R/download_puma_boundaries.R first.")
  x <- sf::st_read(config$boundary_path, quiet = TRUE) |> sf::st_drop_geometry()
  excluded <- acs_config$excluded_puma_geoids[[as.character(config$puma_definition_year)]]
  stopifnot(nrow(x) == 18L, !anyDuplicated(x$GEOID),
    all(x$puma_definition_year == config$puma_definition_year),
    !any(x$GEOID %in% excluded))
  x[c("GEOID", "NAME", "puma_code", "puma_definition_year")]
}

prepare_chicago_pums <- function(raw, lookup, config) {
  validate_pums_housing(raw, config)
  geoid <- paste0(pums_code(raw$STATE, 2), pums_code(raw$PUMA, 5))
  retained <- geoid %in% lookup$GEOID
  x <- raw[retained, ]
  # Preserve every returned data/label column; add geography and provenance only.
  x$puma_geoid <- geoid[retained]
  x$puma_name <- lookup$NAME[match(x$puma_geoid, lookup$GEOID)]
  x$puma_definition_year <- config$puma_definition_year
  x$acs_start_year <- config$year - 4L
  x$acs_end_year <- config$year
  x$is_vacant <- as.character(x$VACS) %in% as.character(1:7)
  x$synthetic_data <- SYNTHETIC_DATA
  x <- x[order(x$puma_geoid, x$SERIALNO), ]
  # SERIALNO is the key; discard inherited row positions for stable RDS reruns.
  rownames(x) <- NULL
  validate_pums_housing(x, config)
  stopifnot(setequal(x$puma_geoid, lookup$GEOID))
  # No rent, tenure, positive-weight, or complete-case model filters are applied.
  matched <- match(x$SERIALNO, raw$SERIALNO)
  for (field in names(raw)) stopifnot(identical(x[[field]], raw[[field]][matched]))
  x
}
