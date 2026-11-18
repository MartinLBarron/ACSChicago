# PUMS housing extract: ACS 2020–2024

This is the first microdata stage for future rent modeling. It creates a
housing-unit dataset, not a fitted model or a renter-only estimation sample.
The observations are official public ACS PUMS records (`SYNTHETIC_DATA = FALSE`).
Data stay on this computer and are not exported to the website.

## Download and unit of observation

`R/download_pums.R` calls `tidycensus::get_pums()` for Illinois, `year = 2024`,
`survey = "acs5"`, `recode = TRUE`, `return_vacant = TRUE`, and
`rep_weights = "housing"`. No PUMA filter is applied at the API stage.
`variables_filter = list(SPORDER = 1, TYPEHUGQ = 1)` requests one householder
record per occupied housing unit and excludes group quarters. The package
makes separate requests for vacant units, which have no person records.
Vacant units have missing SPORDER, and are retained in the returned extract.
SERIALNO must uniquely identify a housing unit in the five-year extract.

The complete, unaltered **returned tidycensus object** is cached as
`data/raw_data/pums_2024/housing_basic_v1/illinois_housing.rds`. This is a parsed,
recoded extract, not the original HTTP response bytes. It retains source
codes, numeric values, and the additional `*_label` columns created by recoding.
The original function return is cached before QA, so any validation failure
can be investigated locally without downloading again. The directory also stores official API variable metadata, the request settings
(without the API key), value-label metadata, and an MD5 manifest. Successful
reruns reuse and verify this cache. A changed request needs a new cache version;
do not overwrite the original extract.

## Starting variables

| Code | Content | Notes |
|---|---|---|
| RNTP | Monthly contract rent | Preserve Census value; not adjusted in this stage |
| GRNTP | Monthly gross rent | Includes utility components as defined by Census |
| TEN | Tenure | Owner, rented, and no-cash-rent categories retained |
| VACS | Vacancy status | All seven vacancy categories retained |
| TYPEHUGQ | Housing unit / group quarters type | Housing units only |
| BDSP | Bedrooms | Count |
| RMSP | Rooms | Count |
| BLD | Units in structure | Categorical; retain codes and labels |
| YRBLT | When the structure was first built | Categorical; do not treat codes as exact years |
| NP | Persons associated with housing record | Zero for vacant units |
| ADJHSG | Housing-dollar adjustment factor | Six implied decimal places |
| FRNTP, FGRNTP | Rent allocation flags | Preserve indicators of allocation/imputation |
| PUMA, STATE | Geographic codes | Retain leading zeros; state + PUMA identifies the area |
| SERIALNO | Housing-record identifier | Not a street address or location coordinate |
| WGTP | Housing-unit sample weight | Use for housing analysis, not the automatic PWGTP column |
| WGTP1–WGTP80 | Housing replicate weights | Retained for future design-based uncertainty calculations |
| SPORDER, PWGTP | Automatically returned person fields | Not the housing weights; vacant records lack person fields |

This stage preserves original dollar amounts and ADJHSG. Before combining
interview years in a rent model, apply the documented housing-dollar adjustment
(`amount * ADJHSG / 1,000,000`) in a separate, agreed analysis step. Do not apply
it twice. Blank/not-applicable values are not zero rent. Categorical missing
codes and labels remain as supplied by tidycensus. Top coding and allocation
in PUMS must be considered in subsequent analysis; this extraction does not
attempt to undo them.

## Chicago selection

`R/prepare_pums.R` reads the retained PUMA lookup from
`data/shape/puma_2024/chicago_pumas.gpkg`. It filters the Illinois extract to
exactly those 18 GEOIDs, including the previously requested Oak Lawn, Addison,
Northlake, Elk Grove Village, and Des Plaines exclusions. State and PUMA codes
are normalized only for constructing the added `puma_geoid` field; the original
columns are unchanged. No rent, tenure, positive-weight, or complete-case filters
are applied to the retained housing records. Owner-occupied, no-cash-rent, and
vacant units remain available for later sample definitions.

The official 2020–2024 PUMS release has a unified **2020-based PUMA** variable.
Census crosswalked the 2020 and 2021 records from their original PUMA definitions;
2022–2024 records already use 2020 definitions. Do not apply another geographic
crosswalk based on interview year.

PUMAs are the most detailed identifiable residential geography in PUMS. These
records cannot be assigned to Chicago tracts, block groups, or the 77 community
areas. The selected PUMAs are whole areas, may contain territory outside Chicago,
and exclude some Chicago territory under our explicit exclusions. This dataset
therefore represents housing in the retained PUMAs, not an exact Chicago-city
microdata extract. A future PUMA effect must not be described as a community-area
effect. No population weighting or regression specification is chosen here.

## Outputs and validation

In `data/analytic/pums_2024/`:

- `chicago_housing.rds`: canonical local dataset, including factor labels and weights.
- `chicago_housing.csv`: convenient flat-file copy; RDS preserves types and labels.
- `retained_pumas.csv`: the exact geography lookup used for filtering.
- `source_codebook.csv`: source variable descriptions and types.
- `sample_counts.csv`: unweighted occupied/vacant sample counts by PUMA.
- `validation_summary.csv`: unweighted Illinois/subset counts and coverage checks.

Added columns are `puma_geoid`, `puma_name`, `puma_definition_year`,
`acs_start_year`, `acs_end_year`, `is_vacant`, and `synthetic_data`.
Replicate weights can be negative under the Census weighting method. They
are preserved as supplied and must not be clipped to zero. Full housing
weights are checked separately from replicate weights.

There are no per-record ACS margins of error; uncertainty for microdata
statistics must be computed with the sample design and weights in a later step.

```sh
Rscript R/download_pums.R
Rscript R/prepare_pums.R
Rscript R/check_pums.R
```

The download and preparation stages are included in `R/run_pipeline.R` after
the existing aggregate stages. Checks require unique SERIALNO values, one record
per housing unit, vacant and occupied records, all 80 nonmissing replicate
weights, correct geography membership, and unchanged source values. Confirm
reproducibility by rerunning the stages end to end; cached reruns should leave
the source checksum and prepared records unchanged.

Sources: [tidycensus get_pums documentation](https://walker-data.com/tidycensus/reference/get_pums.html),
[Census PUMS variable metadata](https://api.census.gov/data/2024/acs/acs5/pums/variables.html),
and [2020–2024 PUMS user guide](https://www2.census.gov/programs-surveys/acs/tech_docs/pums/2020_2024ACS_PUMS_User_Guide.pdf).

Weight reference: [2020–2024 PUMS Accuracy of the Data](https://www2.census.gov/programs-surveys/acs/tech_docs/pums/accuracy/2020_2024AccuracyPUMS.pdf).
