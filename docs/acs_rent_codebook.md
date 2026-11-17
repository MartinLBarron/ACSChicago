# ACS 2020–2024 rent datasets

Official public ACS data, not synthetic. Universe for both measures:
renter-occupied housing units paying cash rent. Dollar values are monthly amounts
in 2024 inflation-adjusted dollars. Contract rent is the agreed monthly rent;
gross rent adds estimated renter-paid utilities and fuels. These are separate
medians; subtracting them does not estimate median utility expenditure.

Source: Census ACS five-year Detailed Tables, API year 2024, variables
`B25058_001` (median contract rent) and `B25064_001` (median gross rent).
API variable suffixes: E = estimate, M = published 90% margin of error,
EA/MA = associated annotations. Medians and MOEs are not summed or averaged.

## Files

Under `data/analytic/acs_2024/`, `tract_rent` and `block_group_rent` each have:

- `.csv`: one row per selected whole Census area, with both measures side by side.
- `.rds`: the same table with R types preserved.
- `.gpkg`: the table joined to full 2024 geometry (EPSG:26916).
- `_long.csv`: four rows per area, one per measure, including variable code and unit.

`validation_summary.csv` records row counts and missing E/M values;
`package_versions.csv` records direct dependency versions. Raw JSON responses,
tidycensus RDS responses, TIGER ZIPs, and a checksum manifest live under
`data/raw_data/acs_2024/`. Extracted original shapefiles and selected 2024 geometry
are under `data/shape/acs_2024/`.

## Columns

| Column | Meaning |
| --- | --- |
| GEOID | Character identifier: 11 digits for tracts, 12 for block groups; preserve leading zeros when importing CSV |
| NAME | Census API area description |
| geography | tract or block group |
| acs_start_year / acs_end_year | 2020 / 2024 |
| boundary_year | 2024 |
| moe_confidence | 90 (percent) |
| synthetic_data | FALSE |
| median_contract_rent_estimate / median_gross_rent_estimate | Valid monthly dollar estimate; missing where Census provides a special code or no value |
| median_contract_rent_moe / median_gross_rent_moe | Published 90% dollar MOE; missing where Census provides a special code or no value |
| *_estimate_raw / *_moe_raw | Original API E/M values as text, including special negative codes |
| *_estimate_annotation / *_moe_annotation | Census API EA/MA annotations, including top/bottom coding indicators where supplied |

Long files instead use `variable`, `variable_code`, `estimate`, `moe`,
`estimate_raw`, `moe_raw`, `estimate_annotation`, and `moe_annotation`.
Raw companion values and annotations must be considered when interpreting
suppressed, unavailable, or top/bottom-coded medians. Missing MOEs remain missing,
never zero; a valid estimate can have an unavailable MOE. See the
[Census ACS special-value documentation](https://www.census.gov/programs-surveys/acs/technical-documentation/summary-file-documentation.html).

Whole areas are selected by positive area overlap in EPSG:26916, using full 2024
TIGER geometry and the project's cached City boundary. Touching an edge alone is
insufficient. Small boundary mismatches and suburban portions remain included.
The City snapshot is not a historical 2024 city-limit reconstruction. No areal
allocation of rent values is performed. Use these matching 2024 geometries for
mapping the rent estimates, rather than assuming the existing 2025 map has
identical GEOIDs or geometry.

## Housing-unit counts

Both tract and block-group datasets also include:

| Prefix | ACS variable | Definition |
| --- | --- | --- |
| cash_rent_units | B25063_002 | Estimated renter-occupied housing units paying cash rent |
| renter_occupied_units | B25003_003 | Estimated renter-occupied housing units, including those occupied without payment of cash rent |

Each prefix has `_estimate`, `_moe` (published 90%), `_estimate_raw`, `_moe_raw`,
`_estimate_annotation`, and `_moe_annotation` columns, as with the rent measures.
Count estimates and their MOEs are in **housing units**, not dollars. Long files
have four rows per area and a `unit` column distinguishing housing units from
monthly 2024 dollars. Wide files retain one row per area.
Counts use the same ACS period, selected GEOIDs, and boundaries as the rents.

Original rent downloads are retained unchanged. Additional API JSON and
tidycensus RDS files use the `_housing_counts` suffix. All inputs are covered by
the existing checksum manifest. The map's click details include both counts and
MOEs; the color scale remains monthly rent. Counts can help interpret missing
medians, but an ACS estimated zero is not proof of no actual cash-rent units.
A positive count with a missing median does not identify whether insufficient
sample observations or the median precision suppression rule caused the gap.

## Lake Michigan exclusion

Tract `17031990000` and its block group `170319900000` are excluded from analytic
outputs, selected 2024 GeoPackages, and the rent-map GeoJSON. TIGER reports zero
land area and 1,717,072,182 square meters of water for each. This targeted exclusion
is configured by parent tract GEOID in `R/acs_config.R`. Original Census responses
and Illinois shapefiles remain unchanged. The remaining analytic coverage is
868 tracts and 2,312 block groups. Positive city overlap remains the selection rule
for other areas; the separate original 2025 boundary exports are not filtered.

## Three non-overlapping periods

The pipeline now runs the same four measures for 2010–2014, 2015–2019, and
2020–2024 (end years 2014, 2019, 2024). The 2005–2009 period is intentionally
excluded because the current tidycensus implementation cannot retrieve its
block groups. The earlier sections describe the latest-release files; the same
file schema and validation apply to each earlier period.

Each release has its own `data/raw_data/acs_YEAR/`, `data/shape/acs_YEAR/`, and
`data/analytic/acs_YEAR/` directories. `R/acs_config.R` lists the periods and
constructs their paths; `R/download_acs_rent.R` runs the per-period stages;
`R/combine_acs_periods.R` stacks the results into `data/analytic/acs_combined/`.

Combined tract and block-group outputs include CSV/RDS wide and long tables.
Each wide-table row is a **geographic area within a period**, uniquely identified
by (`acs_end_year`, `GEOID`). Long tables add `variable` to that key. Combined
GeoPackages have one native-geography layer per end year: `acs_2014`, `acs_2019`,
and `acs_2024`. These are repeated cross-sections, not a boundary-harmonized panel.
GEOIDs and geometry can change; identical GEOIDs do not guarantee stable boundaries.

Additional metadata columns are `period` (e.g. 2010–2014) and `dollar_year`.
Rent estimates and their MOEs remain in each release's **end-year dollars**:
2014, 2019, or 2024 dollars. They have not been converted to a common purchasing
power. The long-table `unit` column records the applicable year. Housing-unit
counts remain counts. Inflation adjustment and geographic harmonization are
separate analytical steps required before interpreting area-level rent changes.
All releases use the same cached contemporary City boundary as an overlap mask,
not reconstructed historical city limits. The Lake Michigan parent-tract exclusion
applies in all periods. Original responses and geometry archives remain unchanged.

The website offers all three periods through a period selector, defaulting to
2020–2024. Each selection loads matching native geometry and labels its end-year
dollar units. It does not harmonize boundaries or adjust dollar amounts for inflation.

Availability also changes with methodology: Census introduced the five-year
dollar-median suppression rule (MOE greater than estimate) beginning with the
2015 release. Thus missing-median patterns in the 2014 release are not directly
comparable to those in 2019/2024. See the [Census methodological note](https://www.census.gov/programs-surveys/acs/technical-documentation/user-notes/2016-01.html).

## Chicago citywide published estimates

The same four measures are retrieved for the **Chicago city, Illinois place**
(state FIPS `17`, place FIPS `14000`, GEOID `1714000`) for all three periods.
These are directly published ACS estimates and 90% MOEs, not sums or averages of
tract/block-group statistics. No county restriction is used; the place covers
Chicago across county boundaries. This Census place differs from the set of
whole areas selected by positive City overlap, which can include suburban parts.

Each `data/analytic/acs_YEAR/` directory contains `chicago_city_rent.csv` and
`.rds` (one row), plus `chicago_city_rent_long.csv` and `.rds` (four rows).
`data/analytic/acs_combined/` contains the same filenames with three wide rows
and twelve long rows. All use the existing variable, period, dollar-year,
estimate, MOE, raw-code, and annotation definitions. `geography` is `place`;
GEOID is the seven-character `1714000`. `boundary_year` records the Census
geographic vintage, not a downloaded city geometry. City outputs are tabular;
no city GeoPackage is created for these statistics.

Raw responses are cached as `chicago_place_api.json` and
`chicago_place_tidycensus.rds` in each period's raw directory and included in its
checksum manifest. tidycensus requests Illinois places, then retains Chicago;
the companion raw API request selects Chicago directly. All four estimates and
MOEs are checked against that raw response. Source identifiers:
[B25058](https://api.census.gov/data/2024/acs/acs5/groups/B25058.html),
[B25064](https://api.census.gov/data/2024/acs/acs5/groups/B25064.html),
[B25063](https://api.census.gov/data/2024/acs/acs5/groups/B25063.html), and
[B25003](https://api.census.gov/data/2024/acs/acs5/groups/B25003.html).


The dashboard now presents these published citywide estimates in four cards and
four D3 trend charts. Cards follow the selected period; charts show all periods.
The self-contained website JSON is `html/data/web/chicago_city_statistics.json`,
exported by `R/export_city_web_data.R`. Published 90% MOEs appear as chart error
bars and card text; a full HTML table includes values and annotations. Rent charts
show nominal end-year dollars and do not assert real growth or statistical
significance. Lines connect the three period estimates, not annual observations.
