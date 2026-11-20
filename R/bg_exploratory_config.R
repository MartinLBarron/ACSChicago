# Candidate domains are exploratory; M0–M4 and their common sample stay fixed.
source("R/bg_model_config.R")
bg_exploratory_config <- bg_model_config
bg_exploratory_config$raw_dir <- "data/raw_data/bg_exploratory_2024_v1"
bg_exploratory_config$analytic_dir <- "data/analytic/bg_exploratory_2024"
bg_exploratory_config$output_dir <- "output/models/block_group_exploratory_2024"
ex_codes <- function(table, indices) bg_codes(table, indices, paste0(tolower(table), "_", sprintf("%03d", indices)))
bg_exploratory_groups <- list(
  vacancy = ex_codes("B25004", 1:8),
  rooms = ex_codes("B25021", 3),
  household_size = ex_codes("B25009", 10:17),
  crowding = ex_codes("B25014", 8:13),
  plumbing = ex_codes("B25049", 5:7),
  kitchen = ex_codes("B25053", 5:7))
bg_exploratory_config$source_units <- stats::setNames(
  rep("renter-occupied housing units", length(bg_exploratory_groups)), names(bg_exploratory_groups))
bg_exploratory_config$source_units[c("vacancy","rooms")] <- c("vacant housing units", "rooms (median among renter-occupied units)")
ex_share <- function(table, numerator, denominator) list(
  numerator = paste0(tolower(table), "_", sprintf("%03d", numerator)),
  denominator = paste0(tolower(table), "_", sprintf("%03d", denominator)))
bg_exploratory_shares <- list(
  studio = list(numerator="bed_studio",denominator="bed_total"),
  four_plus_bedrooms = list(numerator=c("bed_four","bed_five_plus"),denominator="bed_total"),
  single_person = ex_share("B25009",11,10),
  large_household = ex_share("B25009",14:17,10),
  crowded = ex_share("B25014",11:13,8),
  incomplete_plumbing = ex_share("B25049",7,5),
  incomplete_kitchen = ex_share("B25053",7,5))
# Rental vacancy: available-for-rent / (occupied rentals + available + rented-not-occupied).
bg_exploratory_shares$rental_vacancy <- list(numerator="b25004_002",
  denominator=c("renter_occupied_units","b25004_002","b25004_003"))
bg_exploratory_domains <- list(
  vacancy = "rental_vacancy_10pp",
  finer_bedrooms = c("studio_10pp","four_plus_bedrooms_10pp"),
  rooms = "renter_median_rooms",
  household_size = c("single_person_10pp","large_household_10pp"),
  housing_conditions = c("crowded_10pp","incomplete_plumbing_10pp","incomplete_kitchen_10pp"))
bg_exploratory_labels <- c(
  recent_movers_10pp="Moved into unit in 2020 or later (+10 pp of renters)",
  rental_vacancy_10pp="Rental vacancy rate (+10 pp)",
  studio_10pp="Studio share, holding studio/1-bedroom total fixed (+10 pp)",
  four_plus_bedrooms_10pp="4+ bedrooms, holding 3+ bedroom total fixed (+10 pp)",
  renter_median_rooms="Median rooms among renter-occupied units (+1 room)",
  young_renters_10pp="Renter householder under 35 (+10 pp)",
  older_renters_10pp="Renter householder age 65+ (+10 pp)",
  single_person_10pp="Single-person renter households (+10 pp)",
  large_household_10pp="Renter households with 4+ people (+10 pp)",
  crowded_10pp="Rentals with over 1 person per room (+10 pp)",
  incomplete_plumbing_10pp="Rentals lacking complete plumbing (+10 pp)",
  incomplete_kitchen_10pp="Rentals lacking complete kitchens (+10 pp)")

# Known failed block-group sources remain in the raw cache for audit only.
# Martin requested skipping these rather than seeking substitutes.
bg_exploratory_skipped <- data.frame(
  domain=c("Renter income distribution","Renter family/children composition","Joint construction age and building size"),
  table=c("B25118","B25115","B25127"),
  reason="API returned null estimates for all 2,312 selected block groups; skipped",
  alternative="No tract substitution or imputation")
