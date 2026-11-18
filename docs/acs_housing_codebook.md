# Rent-burden supplement

The current supplement uses B25070 for 2010–2014, 2015–2019, and 2020–2024,
covering the project's selected tracts/block groups and published Chicago city
place (1714000). Geographic selection and the Lake Michigan exclusion are unchanged.

## Active measures

| Variable | Numerator | Denominator |
| --- | --- | --- |
| rent_burden_50plus_pct | B25070_010: gross rent is 50%+ of income | Sum of B25070_002–010: computed rent/income categories |

Source estimates and MOEs are housing-unit counts. Derived estimates are percent
(0–100); their approximate 90% MOEs are **percentage points**. The component
counts B25070_001–011 remain necessary for the denominator, uncertainty calculation,
and partition checks. The retired 30%+ summary is not calculated.

## Pipeline and files

- `R/download_acs_housing.R`: caches original API JSON, tidycensus responses, and
  release-specific metadata under `data/raw_data/acs_YEAR/housing/`. Only active
  burden files are read or tracked in the current manifest. Historical bedroom
  and utility cache files remain on disk but are no longer pipeline inputs.
- `R/derive_acs_housing.R`: computes the 50%+ percentage offline and joins them
  and their source counts to the original four rent/count measures.
- `R/housing_config.R`: defines sources, formulas, and public measures.

In each `data/analytic/acs_YEAR/` directory, TAG is `tract`, `block_group`, or
`chicago_city`:

- `TAG_housing_source.csv` / `.rds`: 11 source counts with E/M, original raw codes,
  Census annotations, and source-status fields.
- `TAG_housing_source_long.csv` / `.rds`: one row per area/source variable.
- `TAG_housing.csv` / `.rds`: extended wide table with core measures, source
  counts, and the derived percentage.
- `TAG_housing_derived_long.csv` / `.rds`: one row per area with estimates, MOEs,
  numerator/denominator counts and MOEs, formula components, and validity flags.
- `TAG_housing.gpkg`: matching full geometry for tracts and block groups only.
- `housing_source_codebook.csv`: actual source codes and labels for that release.

Combined extended, source-long, and derived-long CSV/RDS files live in
`data/analytic/acs_combined/`, alongside `housing_validation_summary.csv`.
Combined GeoPackages have separate `acs_2014`, `acs_2019`, and `acs_2024` layers.
Wide tables are keyed by (`acs_end_year`, `GEOID`); long tables also use `variable`.
Native boundaries are not harmonized, and rents remain in end-year dollars.

## Missingness and uncertainty

Source special codes become missing usable values while raw codes and annotations
are preserved. Count sums use `tidycensus::moe_sum()` with estimates supplied so
multiple zero-estimate components contribute only their largest MOE. Missing
components propagate. Derived percentages use `100 * tidycensus::moe_prop()`;
the package uses its ratio fallback if the subset-variance expression is
nonpositive. Record `moe_method` rather than concealing this approximation.

A percentage is undefined if required estimates are missing, its denominator is
zero, or its numerator exceeds its denominator. A valid estimate may have a
missing MOE. Status fields explain these cases. No missing values are replaced
by zero and no MOEs are capped. Source partition totals and unchanged core columns
are validated. `R/check_housing_derivations.R` checks formulas and edge cases.

## Website and retired measures

The public map and citywide dashboard expose five measures: four original rent/count
measures and the 50%+ percentage above. Cards, tooltips, and graphs retain MOEs;
percentage MOEs are labeled in pp. The citywide selector remains independent of
the map. Web exports exclude retired variables.

The 30%+ summary, bedroom composition/rent measures, and utility-payment measures
were retired at the user's request. They are absent from current collection
configuration, formulas, analytic outputs, website exports, and controls. Older
immutable source downloads remain unused locally for provenance.

Source: [Census B25070](https://api.census.gov/data/2024/acs/acs5/groups/B25070.html).

The not-computed share is also retired. Its underlying count remains a source
component used for table partition checks, not a displayed or derived percentage.

## City and national comparisons

`R/download_acs_comparisons.R` retrieves Chicago, Philadelphia, Milwaukee,
Detroit, Minneapolis, Boston, Houston, New York city (all five boroughs),
Los Angeles, Miami city (not Miami-Dade County), and the United States for
2010–2014, 2015–2019, and 2020–2024. Each city is a whole Census place,
without county restrictions, using that release's geography. The national
benchmark uses ACS `us` geography. This is an editorial comparison set,
not a statistically matched sample of cities.

The four core rent/count measures and all eleven B25070 source cells are
collected via tidycensus. Original API E/M codes and EA/MA annotations are
cached alongside tidycensus RDS responses under
`data/raw_data/acs_YEAR/comparisons/`, with checksum manifests. Severe rent
burden uses the existing computed-ratio denominator and approximate 90% MOE
method, including zero-denominator and missing-source handling. Retired
bedroom, utility, and other derived measures are not collected.

Annual `comparison_housing.csv/.rds` files are in each ACS analytic folder.
Combined wide, source-long, and derived files are in
`data/analytic/acs_combined/` with the `comparison_housing` prefix. The combined
wide dataset has 33 observations (11 geographies × 3 releases). Its key is
`GEOID` plus `acs_end_year`; `comparison_id` provides stable readable IDs.
`comparison_statistics.json` is exported to `data/web/` and `html/data/web/`
for future frontend use. The current interface is unchanged. Chicago's five
estimates and MOEs are checked against the existing dashboard dataset.

Run after the Chicago housing derivation stage:

```sh
Rscript R/download_acs_comparisons.R
```

The full `R/run_pipeline.R` includes this stage. Reruns reuse cached responses
and verify prior manifest checksums. Dollar amounts remain nominal end-year
dollars; city boundaries and housing composition can differ across periods.

## Renter-occupied share

`renter_occupied_pct` is **100 × B25003_003 / B25003_001**: the percentage
of occupied homes that are renter occupied. Vacant homes, including vacant
rentals, are excluded from the denominator. Renter-occupied units include
homes occupied without payment of cash rent.

The `tenure` source group collects B25003_001 (`occupied_units`), B25003_002
(`owner_occupied_units`), and B25003_003 (`tenure_renter_units`), with both
estimates and 90% MOEs and the original E/M/EA/MA API fields. The separate
source name for renters lets us check agreement with the existing core
`renter_occupied_units` measure. Tenure totals must equal owner plus renter
counts. Source caches use a `_tenure` suffix, preserving earlier caches.

The percentage uses the same `derive_housing_percentage()` subset-proportion
MOE method as rent burden, with the ratio fallback when needed. Its MOE is
in percentage points. Zero occupied units produce an unavailable percentage,
not zero; missing source estimates and MOEs retain explicit status fields.
Derived-long outputs retain numerator and denominator estimates and MOEs.

The measure is calculated for all three periods, for Chicago-overlapping
tracts and block groups, Chicago city, all nine comparison cities, and the
United States. Standard analytic and web exports include it. Frontend
measure controls are maintained separately.
