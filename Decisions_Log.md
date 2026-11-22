# Model measures on map/dashboard; retire PUMAs — 2026-11-20

- Martin requested adding the complete model's source measures to the map and
  dashboard, then specified that only tracts and block groups are needed.
  Remove PUMA geography/overlay controls and default PUMA/PUMS downloads/model
  steps; retain historical scripts and data without deletion.
- Display latest-model measures for 2020–2024, using readable percentages and
  annual income dollars. Earlier periods retain existing measures. Preserve
  ACS E/M and raw/annotation caches. Use whole mapped areas, not the fit sample.
- City ACS measures are direct Chicago-place estimates. New cards are Chicago-only;
  original measures retain peer comparisons. Single-period ACS values are cards,
  not manufactured trends; crime receives an annual 2020–2024 recorded-count chart.
- Map crime counts exclude unusable locations; the citywide recorded total includes
  them. No sampling MOE is assigned to administrative counts. Community names are
  displayed through outlines/popups, including BG model assignment where available.

# Crime-first staged report — 2026-11-20

- Martin reframed the question as the association between median rent and violent
  crime and requested a separate crime-first sequence: M0 intercept; M1 raw crime;
  M2 housing/renter-profile controls; M3 socioeconomic/demographic context; M4
  community-area indicators. Preserve recent moves and renter age in the
  established housing/renter-profile block. No new transformation or data source.
- Keep the identical 1,468 cases and tract folds. New M4 must reproduce previous
  crime M5. Produce a new R Markdown report with crime-effect trajectories,
  confidence/contrast charts, full diagnostics and strict-city sensitivity.
- New numbering is confined to data/analytic/crime_stages_2024 and its report;
  retain prior reports and website numbering. Explain the small positive M3
  point estimate after socioeconomic adjustment and its shift back negative
  after community indicators, without a causal mediation interpretation.

# CPD crime study — 2026-11-20

- Martin approved a descriptive association study, not causal rent suppression.
  Use occurrence years 2020–2024, raw untransformed violent row counts inside
  block groups, and M5 = current M3 + violent_crime_count. No denominator,
  annualization, logarithm or neighboring-area exposure in this first model.
- Count each CPD ID once, without case-number deduplication, including multiple
  murder victim rows. Include qualifying domestic rows regardless of arrest.
  Freeze an explicit official IUCR Index-I violent-offense mapping; exclude
  simple/minor-injury offenses, reckless homicide and involuntary manslaughter.
- Exclude unusable coordinates from spatial counts but retain a coverage audit.
  Use whole 2024 polygons and the existing majority-city sample; refit M3/M5 on
  >=99%-inside-city areas as a boundary sensitivity. Preserve zero assigned
  counts while explaining missing-coordinate and city-only coverage limitations.
- Final mapping includes Index child sexual assault (1753/1754) and ritual
  battery codes outside the main primary-type headings, and reconciles exactly
  with recorded FBI violent categories 01A/02/03/04A/04B.
- Snapshot: 1,187,239 total rows; 134,913 selected violent rows; 1,797 lack usable
  coordinates; 94,321 rows assigned to 1,468 modeling BGs. M5 R² is 0.73010
  versus M3 0.72937, held-out R² 0.67470 versus 0.67425. The per-100-row
  contrast is -2.12%, HC3 interval -4.36% to +0.16%; clustered sensitivity
  interval -3.67% to -0.55%. The negative estimate adds very little fit and
  interval conclusions depend on covariance choice.
- Martin approved preparing the audit and M5 report together, with the website
  kept on its current models until the new result is reviewed. Crime inputs,
  fitted objects and point audits stay outside html/. Record the frozen current
  extraction as revised historical data, not an as-of-2024 snapshot.

# Promote renter-profile variables — 2026-11-19

- Martin requested adding recent moves and renter-householder age to the original
  models and rerunning them. Add the moved-in-2020+ share, under-35 share and
  age-65+ share to the M1 housing/renter-profile block and carry through M2a,
  M2, M3 and M4. Preserve the intercept-only M0 and the same 1,468 areas/folds.
- Retain source estimates, MOEs and annotations. Recent moves are a pooled stock
  characteristic, not annual turnover; the renter-age reference is 35–64.
- Archive prior primary/exploratory fits and reports under history/before_movers_age.
  Refresh primary reports and website exports. Rerun remaining exploratory domains
  against the promoted baseline; do not retest promoted terms as new additions.
- Updated M3 R² is 0.7294 (previously 0.7132), with held-out R² 0.6742
  (previously 0.6551); all 1,468 areas and fold assignments are identical.
- Because promotion followed exploratory use of the same folds, label the updated
  CV results as comparative rather than independent post-selection validation.

# Exploratory ACS expansion — 2026-11-19

- Martin authorized testing additional ACS rent-model predictors in an exploratory
  extension, then explicitly instructed skipping unavailable variables. Preserve
  M0–M4. Test available domains separately and in transparent combinations.
- B25118 renter income, B25115 renter family/children composition and B25127 joint
  construction-age/building-size returned null estimates for every mapped BG.
  Retain raw responses for audit, remove them from active downloads/derivations,
  and do not continue the alternative renter-income search or substitute tracts.
- Twelve feasible predictors cover recent moves, vacancy, finer bedrooms, rooms,
  renter age, household size, crowding, plumbing and kitchen facilities. Preserve
  source estimates/MOEs/annotations and derived share uncertainty/status fields.
- For every comparison, refit baseline models on exactly the extension’s cases;
  use existing tract folds with identical eligible test rows across variants.
  Four open-ended room medians are excluded from room-containing comparisons.
- Exploratory results: recent moves improve held-out R² from 0.6551 to 0.6695;
  renter age to 0.6660. All available candidates give 0.6705 versus matched-case
  baseline 0.6565 (1,464 areas). Heteroskedasticity and RESET flags remain.
  No exploratory candidate is automatically selected as a replacement model.

# M4 addition — 2026-11-19

- Martin requested M4: rental-housing composition plus community-area indicators,
  without socioeconomic context. Promote the existing H_CA comparison to M4;
  retain the identical common sample and cross-validation folds. Include it in
  report and website fit comparisons, coefficients, diagnostics and sensitivities.

# Block-group rent study — 2026-11-18

- Martin approved using the current model on the website pending refinement.
  The Model page presents staged fits, HC3 and clustered coefficient intervals,
  M3 observed-range contrasts, diagnostic plots, spatial/specification tests and
  sensitivities. Explicitly label associations and initial-model limitations.
  Generated public aggregate exports and the full report live under html/data/web;
  no PUMS unit records are exported. Decision by Martin; presentation by Codex.

- Martin approved 2020–2024 log median contract rent, equal block-group weights,
  rental-count and precision sensitivities, and staged housing/context/community
  models. Both college and no diploma/GED shares are included as requested.
- Martin approved whole block groups >=50% inside the City by polygon area,
  dominant-community assignment and stricter boundary sensitivities. Map
  coverage is unchanged; the earlier PUMS model is retained independently.
- Poverty uses C17002's two below-one ratio cells; B17001 returned no usable BG
  estimates. All raw inputs, MOEs and annotations remain available for audit.
- Codex retained singleton communities and flagged exact fitting. HC3 slopes
  use nonsingleton communities (same slopes); singleton influence and HC3
  effect intervals are unavailable. No community-clustered effect intervals
  or joint effect test are claimed. This safeguards inference without changing
  the agreed sample. R Markdown report includes diagnostics and limitations.
- Final common sample: 1,468 areas across all 77 communities; Oakland is a
  singleton. The majority-city set has 2,137 areas: 449 lack a usable rent
  estimate and another 220 lack median household income. Seven retained rent
  medians are open-ended $3,500+ categories (numeric endpoint 3,501); flag these
  and include an exclusion sensitivity rather than silently treating them as exact.
- Initial log-rent R²: housing 0.1266, housing/context 0.6368, adding community
  location 0.7132. The community increment is 0.0764 (partial R² 0.2105).
  Tract-blocked CV R² for the full model is 0.6551. Heteroskedasticity, tails,
  RESET and residual spatial checks warrant further refinement, not causal claims.

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
- `TAG_housing_source.csv` / `.rds`: 21 source counts plus six bedroom-specific rent medians per area in wide form.
- `TAG_housing_source_long.csv` / `.rds`: one row per area/source variable.
- `TAG_housing_derived_long.csv` / `.rds`: one row per area/derived percentage.
- `TAG_housing.csv` / `.rds`: original four rent/count measures, 21 supplementary source counts and six published
  bedroom-specific medians, and derived percentages joined in one wide analytic dataset.
- `TAG_housing.gpkg`: matching geometry and the extended analytic data for tracts
  and block groups only. Citywide data are tabular.

TAG is `tract`, `block_group`, or `chicago_city`. Combined extended, source-long,
and derived-long CSV/RDS files are in `data/analytic/acs_combined/`. Combined
GeoPackages have separate native-geography layers `acs_2014`, `acs_2019`, and
`acs_2024`. The unique wide key is (`acs_end_year`, `GEOID`); long files also use
`variable`. `housing_validation_summary.csv` reports definition/MOE statuses.
The existing core `_rent` files and website measures are preserved. The map and citywide dashboard expose the derived percentages through grouped
measure/topic pickers. Source counts remain available in the analytical files.

## Source counts and universes

All counts and their MOEs have units of **housing units**. B25031 medians and
their MOEs have units of monthly end-year dollars.

| Source | Fields | Population described |
| --- | --- | --- |
| B25070 | 001 total; 002–010 rent/income bands; 011 not computed | Renter-occupied housing units |
| B25042 | 009 renter total; 010–015 studio, 1, 2, 3, 4, 5+ bedrooms | Renter-occupied housing units, including no-cash-rent units |
| B25069 | 001 total; 002 extra utility payment; 003 no extra payment for any utilities | Renter-occupied housing units |
| B25031 | 002–007 studio/no bedroom, 1, 2, 3, 4, 5+ bedrooms | Renter-occupied housing units paying cash rent; only available from the 2015 release |

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


## Published rent medians by bedrooms (B25031)

`median_gross_rent_bedrooms_0`, `_1`, `_2`, `_3`, `_4`, and `_5plus` correspond to
B25031_002 through B25031_007. Each retains estimate, MOE, raw E/M values,
annotations, and `source_status`. Medians are retrieved directly, not derived
from the bedroom-composition table or averaged across areas. Source metadata and
API responses for this group have separate cached filenames containing
`bedroom_rent`, preserving prior source files.

The table was introduced in the 2015 release, so 2010–2014 has explicit structural
gaps with `source_status = table_not_published`, missing numeric/raw values, and
no fabricated Census annotations. No API request for B25031 is made in 2014.
That year's source codebook lists only actually published source fields.
2019/2024 table entries have `source_status = published`, even where an individual
median is unavailable or bounded. The original API annotations remain essential
for interpreting top/bottom-coded medians. See the [Census introduction note](https://www.census.gov/programs-surveys/acs/technical-documentation/table-and-geography-changes/2015/5-year.html).

The public Bedrooms view now displays these six medians instead of composition
shares. The latter remain in analytic files. Web exports contain 15 displayed
measures (four core measures, six bedroom rent medians, and five burden/utility
percentages). Both geographic levels and the citywide dashboard retain the same
period pickers. There is no corresponding published ACS detailed table for
median contract rent by bedrooms, and aggregate medians do not supply the missing
joint distribution needed to calculate it.
- **Supersedes the prior expansion of displayed and collected housing measures:** User requested removal of 30%+ rent burden, all rent-by-bedroom measures, and all utility measures from the website and data collection pipeline. Retain the original four core measures, 50%+ burden, and not-computed coverage share. Drop bedroom composition sources as unused. Keep B25070 category counts needed for the remaining burden denominator/MOE; do not calculate the retired 30%+ summary. Regenerate active analytic and web exports. Historical raw downloads remain unchanged but are excluded from active source manifests and inputs.

- User also removed the not-computed share from the website and derived outputs. The only derived public measure is now 50%+ rent burden. Keep the underlying not-computed count for source-table validation and exclusion from the burden denominator.

### 2026-11-17 — City and national ACS rent benchmarks

Added direct ACS place estimates for Philadelphia, Milwaukee, Detroit,
Minneapolis, Boston, Houston, New York, Los Angeles, and Miami, alongside
Chicago and the United States benchmark. Use all three existing ACS5 periods
and the five active measures, preserving source E/M codes, annotations, and
90% MOEs. Severe burden follows the existing derived-variable method. This
is an editorial peer set, without geographic or housing-composition matching.
The collection stage exports comparison data but does not change the interface.

### 2026-11-18 — Renter share of occupied homes

Add `renter_occupied_pct`, 100 × B25003_003 / B25003_001, to the collection
and calculation pipeline for all active geographies and periods. Exclude
vacant homes. Preserve source estimates/MOEs and raw annotations, derive a
90% percentage-point MOE using the existing percentage helper, and retain
undefined-denominator and missing-data statuses. Cache tenure separately and
validate owner plus renter counts against total occupied units.

### 2026-11-18 — Period-matched PUMA outlines

Add an optional, initially hidden TIGER/Line PUMA boundary overlay. Use
2010-defined PUMAs for ACS 2014 and 2019 and 2020-defined PUMAs for ACS 2024.
Retain whole areas with positive Chicago overlap, matching the existing
geographic selection policy. Preserve raw ZIPs with checksum manifests and
export selected geometry to the self-contained website root. Names, codes,
and definition vintages appear in click popups when enabled. No PUMA rent
estimates or microdata are added by this change.

### 2026-11-18 — Select PUMAs using matching TIGER city limits

The initial filter used City portal Chicago limits directly (not the union
of selected tracts or block groups), but differences in City/TIGER linework
admitted neighboring PUMAs through sliver intersections. Select against
Chicago place GEOID 1714000 from each matching-year TIGER PLACE archive,
cache that archive with the PUMA source manifest, and use a native-coordinate
GEOS polygon-interior test. Exclude point/edge contact without arbitrary
area thresholds. Keep entire qualifying PUMAs, including real cross-city
areas. Regenerated outputs retain 23 PUMAs in each of 2014, 2019, and 2024
(previously 28, 28, and 29).

### 2026-11-18 — Exclude five specified suburban PUMAs

Explicitly exclude the PUMAs covering Oak Lawn, Addison, Northlake, Elk Grove
Village, and Des Plaines, as requested. Identified each by the largest
municipal-boundary overlap in the matching TIGER release. Configure exclusions
by decennial definition in `R/acs_config.R`:

| Place | 2010-definition GEOID | 2020-definition GEOID |
|---|---|---|
| Oak Lawn | 1703411 | 1703114 |
| Addison | 1703207 | 1704302 |
| Northlake | 1703422 | 1703109 |
| Elk Grove Village | 1703419 | 1703104 |
| Des Plaines | 1703420 | 1703108 |

Apply after city-limit overlap selection; retain all other qualifying PUMAs.
Regenerated map layers contain 18 PUMAs per period. Record selection/exclusion
in `data/shape/puma_YEAR/puma_selection.csv`. These explicit whole-PUMA
exclusions override the prior include-all-city-overlaps rule and remove some
Chicago territory contained within mixed city/suburban PUMAs; notably the
older Northlake/Des Plaines PUMAs include O'Hare/Edison Park. No tract or
block-group records are excluded by this change.

### 2026-11-18 — Published PUMA rent aggregates

Extend the shared ACS core, supplementary, derived, combined, and web-export
stages to PUMAs. Fetch Illinois-level PUMA requests, retaining only each
period's 18 selected GEOIDs and preserving estimates, MOEs, raw codes, and
annotations. Use published PUMA medians/counts and the existing two derived
percentage definitions and uncertainty methods. Add PUMA areas to the map
geography selector, retaining independent PUMA outline control and the five
requested exclusions. Keep all outlines above choropleth fills.

### 2026-11-18 — First housing PUMS stage for future modeling

At Martin's request, collect only the latest requested ACS five-year PUMS
release (2020–2024), with `get_pums(recode = TRUE, return_vacant = TRUE)`.
Download an Illinois housing-unit extract, using SPORDER = 1 and TYPEHUGQ = 1
for occupied housing, plus the package's separate vacant-unit requests.
Retain housing weights and all 80 housing replicate weights. Start with rent,
tenure/vacancy, bedrooms, rooms, building size, construction year, household
size, housing-dollar adjustment factor, and rent allocation flags. Preserve
source values and labels; no dollar adjustment or model sample is created yet.

Filter locally to the 18 retained 2024-map PUMAs, including all five prior
explicit exclusions. Keep vacant, owner-occupied, and no-cash-rent units.
Use the release's unified 2020 PUMA codes; Census already crosswalked 2020/2021
records. PUMS identifies PUMAs, not Chicago's 77 community areas, so it cannot
support assigning these observations directly to community-area neighborhoods.
Store all microdata locally outside the website and log aggregate QA counts
only. No regression is fitted in this step.

Validation completed: the Illinois cache contains 267,378 housing records
(252,463 occupied and 14,915 vacant). The retained-PUMA dataset contains
43,977 records (40,217 occupied and 3,760 vacant) across all 18 PUMAs. Source
column identity and unique housing IDs passed. Negative replicate weights
are permitted by Census and preserved; validation treats full and replicate
weights separately. Cached end-to-end reruns produced identical checksums for
the Illinois RDS and both Chicago dataset formats.

### 2026-11-18 — First descriptive contract-rent models

Martin approved modeling positive cash-rent units' log monthly contract rent
adjusted to 2024 dollars, with bedrooms, rooms, building size, construction-year
category, and household size, compared with the same specification plus PUMA
fixed effects. Use one common sample, housing weights, and all 80 housing
replicate weights. No random-effects or causal neighborhood model is added.

Apply RNTP × ADJHSG / 1,000,000 exactly once in a separate model sample. Keep
imputed/top-coded observations; report exclusions, allocation counts, and sparse
categories. Set categorical treatment coding explicitly. Use the survey package
ACS SDR design with MSE centering, 4/80 scaling, and 95% pointwise intervals.
Report weighted in-sample R², incremental/partial R², their replicate-weight
uncertainty, a joint PUMA test, and area contrasts centered on the weighted
PUMA distribution (recentered in every replicate). Outcomes are individual
unit log rents; transformed coefficients describe geometric-rent ratios.

Store the sample/audit under data/analytic/pums_2024 and model results under
the gitignored output/models/contract_rent_2024. No website changes or exports.
PUMA associations do not identify community-area or causal neighborhood effects.

The first fitted models use 18,437 cash-rent units (609,338 housing-weighted
units). Weighted log-rent R² is 0.0951 for housing controls and 0.2798 after
adding PUMA indicators: increment 0.1847 (95% interval 0.1702–0.1991), partial
R² 0.2041. The joint design-based PUMA F test is F(17,37) = 214.58.
These describe in-sample conditional area associations. Diagnostics flag five
categories with fewer than 30 observations and maximum weighted leverage
0.731, so sparse-category sensitivity and additional model checks remain
appropriate before treating this as a finished research result.

## 2026-11-20 — Compare contract and gross rent

Fit both natural-log outcomes using the current crime-first M0–M4 models,
equal BG weights, identical controls and existing tract folds. Use the shared
1,451-BG sample (17 original contract-model cases lack usable gross rent)
to avoid confounding outcome differences with sample selection. Compare
in-sample/held-out R² as relative fit and report log RMSE separately; avoid
cross-outcome AIC ranking. Contract has higher relative fit at every stage;
M4 R² is 0.7338 versus 0.7099, and held-out R² is 0.6768 versus 0.6545.
Gross has lower absolute log error and lower outcome dispersion. Preserve
original reports and add a separate paired report with diagnostics, crime
coefficient charts and a shared non-open-ended-median sensitivity.

## 2026-11-20 — Publish crime-first contract-rent models

The Model page now uses crime-first M0–M4, retaining contract rent and its
full 1,468-BG sample (the paired gross comparison used 1,451). Export from
crime_stages_2024 through R/export_crime_stages_web.R; the crime-stages runner
refreshes the public JSON and linked research report. M4 drives residuals
and the variable explorer. Crime coefficient displays use +100 rows, while
explorer contrasts use the actual count difference with unscaled coefficients.
Replace the superseded partition/before-after displays with a crime-association
chart across adjustments; show current spatial tests and strict-boundary
sensitivity. Verify R metrics/residuals and 51 JS contrasts against R fixtures.

## 2026-11-21 — Extend all display measures to every period

At Martin's request, extend the 17 model/crime measures to 2010–2014 and
2015–2019, retaining all 23 measures across three waves. Each geographic
selection and crime point assignment uses the corresponding ACS-year geometry.
Martin approved available recent-move categories with explicit cutoff labels:
2010+, 2015+, 2020+. B25036 construction cells require year-specific mappings;
verify these and renter universes against cached official Census labels. Preserve
raw ACS E/M/annotations and derive shares with existing MOE methods.

Reuse the frozen 2024 crime definition and snapshot. Download historical
IUCR-or-FBI selected violent rows, crosscheck classification equality, cache
all-offense/violent yearly source totals, retain unique-ID rows and audit missing
coordinates. City counts include missing coordinates; polygon counts exclude
them. Historical extracts are revised records, not end-of-period snapshots.

All map and dashboard periods now load their own supplements. Show ACS trends
for the added measures and annual crime within each selected five-year period.
Keep original six peer comparisons; added measures remain Chicago-only.
The regression models remain the separately specified 2020–2024 study.

Verification: all three period checks and browser-calculation tests pass. A full
cached rerun reproduced all ten public supplement/annual JSON outputs byte for
byte (SHA-256). Historical coverage is 2,330 block groups and 872 tracts per
release; 2024 coverage remains 2,312 and 868. All eight dashboard tabs and
23 cards were exercised for every period, including keyboard navigation.

## 2026-11-21 — Restore 30%+ rent burden

At Martin's request, restore rent_burden_30plus_pct alongside 50%+ burden for
all three periods and mapped geographies, direct Chicago-place statistics and
peer-city/US comparisons. Numerator: B25070_007 through _010 (30%+); denominator:
B25070_002 through _010, excluding not-computed ratios. Retain source estimates
and MOEs and use the existing subset-proportion MOE derivation. Existing cached
source cells suffice; no additional download or model changes are required.
Place the new measure in Rent and affordability with its card and trend plot.

## 2026-11-21 — Complete displayed bedroom and one-unit-building shares

Add exactly-two-bedroom rentals (B25042_012 / _009) and rentals in one-unit
buildings (B25032_014 + _015 over _013, detached plus attached) for all three
periods, all mapped areas and direct Chicago-city statistics. Existing raw
caches contain all necessary counts and MOEs. Use the established derived-share
MOE method and Housing characteristics group. These are display additions;
leave regression reference categories and fitted models unchanged.

## 2026-11-21 — Guard against outdated map supplements

A reported 2024-only all-unavailable display exposed a loader validation gap:
GEOIDs/years were checked but absent new measure columns were silently accepted.
Revalidate map and city supplement HTTP caches; require every supplemental
estimate/MOE column before joining, distinguishing absent fields from valid null
estimates. Refresh page script versions and regenerate 2024 exports. Exercise
the production loader on initial 2024 load, both historical periods, return to
2024 and a simulated old 2024 payload lacking the new columns. Local data and
localhost responses contained values in 865 tracts and 2,235 block groups; no
remote URL was provided, so the specific hosted response remains unverified.

## 2026-11-21 — City distribution histograms

Add a View city distribution action to every citywide card, beside Compare
cities where available. Use the selected card's measure and period with all
whole mapped tracts/block groups, not the model complete-case sample. Each
area has equal weight; exclude unavailable, nonfinite and negative estimates
but retain zeros. Use 30 exact equal-width bins by default, with geography and
5–100 bin controls in an independent native modal. Counts are area frequencies,
not numbers of homes or residents. Keep point-estimate distributions separate
from ACS MOE interpretation. Use existing exports, with no new download.
Verification covered all 156 measure/period/geography combinations, exact bin
counts, observation conservation and constant/zero-valued data.

## 2026-11-21 — Extend comparisons to all ACS measures

At Martin's request, collect the remaining 18 ACS measures for all existing
peer cities and the United States in 2014, 2019 and 2024. Preserve the original
seven comparison measures unchanged, and use year-specific model-display source
codes and derivations for the extension. Source direct place estimates, retain
raw E/M/EA/MA responses and tidycensus objects, and preserve derived share MOEs.
Chicago reuses the independently prepared direct-city sources; require every
comparison estimate/MOE to reproduce the dashboard cards.

Separate supplemental-data membership from comparison availability in the shared
frontend definitions, so enabling comparisons cannot bypass map schema checks.
Retain US benchmark rules and label household income in annual dollars.
CPD contains Chicago crimes only; peer crime needs a separately agreed source,
so leave that comparison pending rather than inventing values.

Martin confirmed: add every ACS comparison now and handle peer-city crime
separately. Crime remains the only card without Compare cities.

Controlled-estimate handling: Philadelphia, NYC and national B03002 totals
include raw MOE -555555555 with ***** annotations; some Hispanic numerators
are also controlled. Census multiyear accuracy guidance specifies zero sampling
error for controlled inputs when calculating derived statistics. Update the
shared component-sum helper to apply that rule only to explicitly controlled
annotations, without mutating source MOEs/raw fields. Preserve a controlled-input
count on derived records; ordinary missing MOEs remain missing. Synthetic checks
verify positive, zero and genuinely missing uncertainty cases separately.

Verification: comparison checks pass for 25 ACS measures × 3 periods, all
ten cities and the US, including all MOEs and Chicago source equivalence.
Card actions, map supplemental-schema checks, distributions and controlled-MOE
fixtures pass. A complete cached comparison rerun reproduced both public JSON
copies byte for byte (SHA-256).

## 2026-11-21 — Five-year violent-crime trend

At Martin's request, show the citywide violent-crime chart over the three
aggregate periods, using the already-derived city totals for 2010–2014,
2015–2019 and 2020–2024. Remove the annual-data request from the page and label
the chart's axes, title, tooltip and units as five-year CPD totals. Counts retain
rows without usable coordinates, as on the city cards. The local annual source
asset remains available for auditing period sums.

## 2026-11-21 — Formal model specification matrix

Replace the crime-adjustment chart disclosure with Formal model specification.
Export all 127 stored M0–M4 coefficients, including intercepts and community
indicators, into a 94-parameter-row matrix. Show raw log-rent coefficients,
95% HC3 intervals and two-sided HC3 significance stars (* .05, ** .01, *** .001).
Retain missing intervals as NE for Oakland's saturated singleton, and excluded
parameters as dashes. Label parameter units and Rogers Park community reference.
Existing coefficient-association charts retain percent transformations.
Verified exported values/CIs/p-values against the fitted R bundle and tested
matrix rendering, significance, omitted parameters and singleton handling.

## 2026-11-22 — Building-size VIF diagnostics

At Martin's request, refit crime-first M2–M4 on the same 1,468 cases with
structure_20_plus_10pp omitted or summed with structure_5_19_10pp as a 5+ share.
Keep all other controls and community effects. These are diagnostic alternatives;
main models, reports and website remain unchanged. Omission changes the housing
reference group; pooling imposes equal slopes on the original two shares.

Largest housing VIFs, original/omitted/pooled: M2 6.067/2.161/5.267;
M3 6.553/2.346/5.534; M4 9.695/2.718/8.086. Contextual collinearity persists.
M4 R² is 0.730103/0.730033/0.729822, and crime percent contrasts per100 rows
are -2.121/-2.091/-2.145. Do not select controls by VIF alone. Code:
R/diagnose_building_size_vif.R; separate report/output under
output/models/building_size_vif_2024. Original fits/VIFs reproduce existing
results, identical-sample/rank/constraint checks pass, and the second execution
reproduces all CSVs and report bytes exactly.

## 2026-11-22 — Joint building-size/college-share diagnostic

At Martin's request, compare original M2–M4, omission of 20+ units only, and
omission of both 20+ units and college share on the unchanged 1,468 BG sample.
College share was absent from M2; both omission variants therefore match there.
Retain the no-high-school measure and all other controls, including community
indicators in M4. Main models and the website remain unchanged.

Maximum overall VIF original/joint omission: M2 6.067/2.161, M3 6.609/3.760,
M4 13.713/11.444. Non-Hispanic Black share is the maximum in the new M3/M4.
R² original/new: M2 .466675/.460605, M3 .670662/.659534, M4 .730103/.728476.
M4 crime contrast shifts from -2.121% to -2.318% per100 rows; its 95% HC3
interval is [-4.567%, -.015%], narrowly excluding zero in this exploratory
specification. This is specification sensitivity, not independent validation.
Code: R/diagnose_building_college_vif.R; separate tables/report/model bundle
under building_college_vif_2024. Retained-parameter, identical-case, rank and
nested-fit checks pass; rerunning reproduces all CSVs and report exactly.

## 2026-11-22 — Regression-aware spatial diagnostics

For Martin's question about spatial lag/error models, repeat ordinary residual
permutations on the joint-omission models and add regression-aware Moran tests
and adjusted Rao score tests for original/reduced M3/M4 under queen and KNN4.
Same 1,468 IDs and cached graphs. Earlier permutation p-values treated fitted
residuals as exchangeable and do not account for the model-dependent null,
especially with community fixed effects. They should not be the main evidence
for residual independence. Regression-aware original M4 queen I=.027815 has
expected I=-.041613 and p=.0000373; reduced M4 I=.028292, p=.0000346.

Queen M3 adjusted scores favor error dependence, KNN4 favors lag dependence.
M4 score evidence is weaker and weights-sensitive. These conventional tests
remain limited by known heteroskedasticity; adjusted score tests are adjusted
for the competing spatial alternative, not arbitrary heteroskedasticity.
Moran I does not select lag versus error or imply a causal spillover. Consider
spatial models as sensitivity analyses; do not automatically replace OLS.

Scripts: R/check_reduced_model_spatial.R and R/diagnose_regression_spatial.R.
Results and explanatory note under output/models/building_college_vif_2024.
Regression-aware diagnostics reproduced the initial calculation. Existing main
model reports and website were not changed in this diagnostic discussion.

## 2026-11-22 — Spatial SEM/SAR comparison report

At Martin's request, fit original and joint-omission M3/M4 as OLS, SEM and
SAR on the same 1,468 BGs under cached queen and symmetric KNN4 graphs. Use
Gaussian ML with exact eigenvalue log determinants, same covariates/sample,
AIC/BIC/LR comparisons, innovation diagnostics, marginal/reduced-form means,
and heteroskedasticity-robust sphet GMM sensitivity. Preserve queen's 15 islands
with zero spatial lag; sparse W input avoids the package's default listw
island-conversion failure. Keep the main models/site separate.

Report SAR direct/indirect/total crime responses rather than treating beta as
a total impact. Exact inverse-matrix checks account for islands; 4,000 seeded
joint crime/rho normal draws generate intervals. Percentage-equivalent
transformations are of average log responses, not arithmetic mean BG changes.

M3 ML favors SEM under queen (AIC gains 65.25 original / 75.80 reduced) and
SAR under KNN4 (86.25 / 109.39). M4 gains at most 1.01 AIC points and BIC
prefers OLS in every fixed-specification/W comparison. Robust M4 KNN4 SAR
rho estimates (.265/.279) substantially exceed ML (.051/.058), so no universal
spatial replacement is established. Crime magnitudes remain modest and
interval inclusion of zero is specification/uncertainty sensitive.

Do not interpret near-zero spatial-model innovation Moran I as a formal
independence test: fitting changes its null distribution. Report regression-aware
Moran p-values only for OLS; explain the earlier unrestricted-permutation
limitation. Heteroskedasticity/functional-form and tail issues persist.

Independent checks reconstruct all likelihoods using sparse determinants and
innovations, validate sample/parameter identity, and verify SAR impacts with
full inverse matrices. Reconstruct robust SAR GMM point estimates from X/WX/W2X
instruments; first stages show relevance but have many excluded instruments
and do not establish exogeneity. Six scientific plots reviewed visually.

Runner: R/run_spatial_sensitivity.R; report source R/spatial_sensitivity_report.Rmd;
output output/models/spatial_sensitivity_2024/report.html; model caches and
bundle data/analytic/spatial_sensitivity_2024. Added spatialreg, sphet, Matrix
and MASS to packages.txt; required packages installed locally.

Cached end-to-end reproducibility verified: all 13 CSV, self-contained HTML
and PNG artifacts reproduced byte for byte (SHA-256).

## 2026-11-22 — Promote reduced crime-first models to the website

Omit college-educated share and 20+-unit-building share throughout M0–M4 where
previously present, retaining the original 1,468-case sample and staged order.
Original model bundles and reports remain archived. The current branch is
R/run_current_model_web.R, with estimates, HC3 intervals, F tests, VIFs, plots,
same-fold cross-validation and boundary/open-ended-median sensitivities rebuilt.

Reduced M4 R² is 0.72847582 and adjusted R² is 0.71051891. Its crime association
is −2.31797% per 100 records (95% HC3 interval −4.56750% to −0.01542%); the page
therefore no longer describes that interval as statistically insignificant.
Moran tests now use regression-adjusted lm.morantest inference. The diagnostic
section includes matching reduced SEM/SAR models, queen/KNN4 sensitivity and
heteroskedastic GMM checks. M4 spatial AIC gains are small and BIC favors OLS;
these checks do not establish spatial independence. Assertions verify sample,
coefficient and fit identity between website and spatial bundles.
