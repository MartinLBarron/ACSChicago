# Rent burden, renter bedrooms, and utility payment

Official ACS five-year estimates for 2010–2014, 2015–2019, and 2020–2024,
retrieved for the same selected tracts/block groups and Chicago city place as the
core rent pipeline. Whole areas with positive Chicago overlap are retained,
excluding Lake Michigan tract 17031990000 and its block group. Chicago place
statistics are retrieved directly, not aggregated from smaller geographies.

## Stages and outputs

1. `R/download_acs_housing.R` retrieves and caches source data using tidycensus
   plus companion original API JSON, and verifies E/M values against the API.
2. `R/derive_acs_housing.R` computes derived percentages and MOEs offline.
   The full `R/run_pipeline.R` runs both stages after the core ACS downloads.

Source metadata, original API JSON, tidycensus RDS results, and checksum manifests
are stored in `data/raw_data/acs_YEAR/housing/`. Existing rent caches are preserved.
Each period's `data/analytic/acs_YEAR/` directory contains:

- `housing_source_codebook.csv`: actual release-specific labels and variable codes.
- `TAG_housing_source.csv` / `.rds`: 21 source counts per area in wide form.
- `TAG_housing_source_long.csv` / `.rds`: one row per area/source variable.
- `TAG_housing_derived_long.csv` / `.rds`: one row per area/derived percentage.
- `TAG_housing.csv` / `.rds`: original four rent/count measures, 21 supplementary
  source counts, and derived percentages joined in one wide analytic dataset.
- `TAG_housing.gpkg`: matching geometry and the extended analytic data for tracts
  and block groups only. Citywide data are tabular.

TAG is `tract`, `block_group`, or `chicago_city`. Combined extended, source-long,
and derived-long CSV/RDS files are in `data/analytic/acs_combined/`. Combined
GeoPackages have separate native-geography layers `acs_2014`, `acs_2019`, and
`acs_2024`. The unique wide key is (`acs_end_year`, `GEOID`); long files also use
`variable`. `housing_validation_summary.csv` reports definition/MOE statuses.
The existing core `_rent` files and website measures are preserved. This change
adds pipeline datasets; it does not yet add new frontend selectors or charts.

## Source counts and universes

All counts and their MOEs have units of **housing units**.

| Source | Fields | Population described |
| --- | --- | --- |
| B25070 | 001 total; 002–010 rent/income bands; 011 not computed | Renter-occupied housing units |
| B25042 | 009 renter total; 010–015 studio, 1, 2, 3, 4, 5+ bedrooms | Renter-occupied housing units, including no-cash-rent units |
| B25069 | 001 total; 002 extra utility payment; 003 no extra payment for any utilities | Renter-occupied housing units |

Source fields preserve `_estimate`, `_moe`, `_estimate_raw`, `_moe_raw`,
`_estimate_annotation`, and `_moe_annotation`. Negative API special codes become
missing usable values, while raw codes and annotations are retained. Missing
MOEs are not replaced by zero. Source metadata are checked separately for each
release; no estimate is inferred from a missing code.

## Derived percentages

| Variable | Numerator | Denominator |
| --- | --- | --- |
| rent_burden_30plus_pct | B25070 007–010: 30% or more of income | Sum of B25070 002–010: computed rent/income categories |
| rent_burden_50plus_pct | B25070 010: 50% or more | Same computed-category denominator |
| rent_burden_not_computed_pct | B25070 011 | B25070 001 total |
| renter_bedrooms_0_pct through renter_bedrooms_5plus_pct | Individual B25042 010–015 categories | B25042 009 renter total |
| renter_bedrooms_3plus_pct | B25042 013–015 | B25042 009 renter total |
| utilities_included_pct | B25069 003: no extra payment for any utilities | B25069 001 total |
| utilities_extra_pct | B25069 002: extra for one or more utilities | B25069 001 total |

All percentages are 0–100; MOEs are **percentage points**, not relative percent.
The burden denominator excludes the not-computed category. The separate
not-computed share exposes that coverage limitation. Utilities-included means
**no additional utility payment**, not a measured utility expenditure or an
inference from subtracting median gross and contract rent. Bedroom percentages
measure housing composition, not median rents by bedroom size. No average bedroom
count is computed because the top category is open-ended (5+).

## Uncertainty and undefined values

Count sums use `tidycensus::moe_sum(moe, estimate = estimates)` with missing values
propagated. For multiple components with zero estimates, only the largest of their
MOEs contributes, following the implemented Census guidance. A single published
count retains its original MOE.

Percentages use `100 * tidycensus::moe_prop(n, d, moe_n, moe_d)`. This uses the
subset-proportion approximation, with the package's ratio fallback when the
subset variance expression is nonpositive. These are approximate 90% MOEs;
component covariances are not available. All burden denominator MOEs are computed
by summing the disjoint computed categories, rather than treating total minus
not-computed as independent quantities. Calculated MOEs are not capped at 100.

Derived long outputs retain numerator/denominator estimates and MOEs, formula
component names, `estimate_status`, `moe_status`, and `moe_method`. The wide files
retain each derived percentage's estimate, MOE, statuses, and method. Estimates
are missing if any required source count is missing, the denominator is zero, or
the numerator exceeds its denominator. An otherwise valid percentage can retain
its estimate while its MOE is missing. Missing counts are not summed with `na.rm`.
A zero estimate is not proof that the true population count is zero.

Source partition totals are checked within each table. Core rent columns and
selected GEOIDs are checked unchanged by the final joins. Small synthetic fixtures
in `R/check_housing_derivations.R` verify sum MOEs, subset/fallback formulas,
missing inputs, and zero denominators. Re-run the full pipeline end-to-end to
confirm reproducibility; cached sources and checksums make repeat runs comparable.

## Documentation

- [B25070: rent as a percentage of income](https://api.census.gov/data/2024/acs/acs5/groups/B25070.html)
- [B25042: tenure by bedrooms](https://api.census.gov/data/2024/acs/acs5/groups/B25042.html)
- [B25069: utilities included in rent](https://api.census.gov/data/2024/acs/acs5/groups/B25069.html)
- [tidycensus proportion MOEs](https://walker-data.com/tidycensus/reference/moe_prop.html)
- [tidycensus sum MOEs](https://walker-data.com/tidycensus/reference/moe_sum.html)
