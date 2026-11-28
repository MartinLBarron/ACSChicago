# Model measures on the map and dashboard

All 28 display measures cover ACS **2010–2014, 2015–2019 and 2020–2024**.
They use tract and block-group boundaries matching each release, retaining whole
areas with positive Chicago overlap and excluding the configured lake-only tract.
The primary model uses 2020–2024, with final-model robustness checks for the two earlier periods.

## Definitions

- Rental stock: studio/one-bedroom, exactly two-bedroom and 3+-bedroom shares; rental shares in one-unit, 2–4,
  5–19 and 20+-unit buildings; pre-1940 and 2000+ construction shares.
- Renter profile: recent move-ins; householders under 35 and age 65+.
- Context: poverty, median household income, bachelor+ and no diploma/GED shares
  among adults 25+, non-Hispanic Black and Hispanic/Latino population shares.
- Crime measures include the recorded five-year count and the five-year rate per 1,000 residents. The model uses the rate.

Recent move-ins mean **2010+, 2015+ and 2020+**, respectively. The first release
uses B25038_010; the others sum _010 and _011. These are stock shares with
period-specific cutoffs, not annual turnover rates. Controls, cards and tooltips
label the applicable cutoff. Construction-era cells in B25036 also differ:
2014's renter total is _012 and its 2000+ numerator is _013 + _014; later totals
are _013 and 2000+ numerators are _014 + _015 + _016. The pipeline verifies these
positions against cached official Census metadata and saves a per-period codebook.

Each geography uses its own source counts and medians. Raw API responses retain
E/M and available EA/MA annotations alongside tidycensus outputs. Derived share
MOEs use the existing subset-proportion and sum formulas. Chicago uses direct
city-place estimates, never averages of tract or block-group estimates. Income
and rent are nominal end-year dollars. Changing geography and dollar values
limit direct comparisons; no cross-period spatial crosswalk is applied.

The one-unit category combines detached and attached homes (B25032_014 + _015)
over renter-occupied units (_013). Exactly two bedrooms uses B25042_012 over
renter-occupied units (_009). Both are display additions; the existing regression
specifications retain these as reference categories.

## Crime coverage

The frozen 2024 IUCR definition applies to all periods: Index murder, criminal
sexual assault, robbery, aggravated assault/battery, including the documented
child-sexual-assault and ritual-battery codes. Each unique CPD row counts once;
separate murder-victim rows remain separate. For the rate, divide the five-year count by the same geography’s ACS total population (B03002_001) and multiply by 1,000. A zero or missing population yields an unavailable rate. Unusable coordinates are excluded from mapped counts, while
city totals retain them. No survey MOE applies; reporting and location errors
remain. Zero assigned rows does not establish absence of violence.

The historical downloader retrieves rows selected by the IUCR definition **or**
the corresponding FBI violent categories, then requires their classifications
to agree. It caches independent all-offense and selected yearly counts, verifies
unique IDs/counts/dates, and records coordinate coverage, query provenance and
checksums. Historical records are revised administrative data, not snapshots as
of each period's end. The original 2020–2024 snapshot is retained unchanged.

## Rebuild and outputs

After the core ACS and original crime preparation:

```sh
Rscript R/run_model_display.R
node tests/check_model_display.cjs
```

The default `R/run_pipeline.R` runs this stage last. For each release, the stage
validates table definitions, downloads ACS sources and historical crime inputs,
derives measures, exports and checks geographic coverage, source ratios, MOEs,
crime conservation and unchanged 2024 model-sample values. Rerun the complete
stage to verify numerical reproducibility; cached inputs avoid new downloads.

- Raw ACS: `data/raw_data/model_display_{year}_v1`; table metadata:
  `data/raw_data/model_display_metadata`.
- Historical raw crime: `data/raw_data/cpd_display_crime_{start}_{end}_v1`;
  analytic local records/audits: `data/analytic/display_crime_{start}_{end}`.
- Analytic supplements and codebooks: `data/analytic/model_display_{year}`.
- Public JSON: `html/data/web/{block_group,tract,chicago_city}_model_measures_{year}.json`.
- Annual city crime: `html/data/web/chicago_annual_violent_crime.json` (2010–2024).

Upload the complete `html/` folder, including all three years' supplements. The
map joins by GEOID and period. All dashboard tabs work in all periods. ACS charts
connect all three estimates; the crime charts show five-year counts and rates using the same data as the cards. All 26 ACS measures have peer-city comparisons; violent
crime remains Chicago-only pending a comparable external crime source. No
point-level crime data is published.
No new R package dependencies are introduced.

## Card distributions

Every citywide card includes View city distribution. Its modal uses the card's
selected period and measure, with an independent tract/block-group selector.
It starts with 30 exact equal-width bins (adjustable from 5 to 100). Each whole
mapped area contributes one observation; unavailable estimates are excluded,
zero estimates retained. These are area distributions, not household-weighted
distributions. No further pipeline download is required.

## Complete ACS peer comparisons

After preparing the core and model-display datasets, run:

```sh
Rscript R/run_comparisons.R
Rscript R/check_model_comparisons.R
node tests/check_comparisons.cjs
```

The full pipeline runs the new `R/download_model_comparisons.R` and checker
after model-display preparation. The comparison runner rebuilds both original
and added measures. Raw API E/M/annotations and tidycensus responses for the
added measures live in `data/raw_data/model_comparisons_{year}_v1`; Chicago
reuses its independent direct-place extraction. Analytic sources, derivations
and measures are saved under `data/analytic/acs_combined/comparison_model_*`.
The unified public asset is `html/data/web/comparison_statistics.json`.

The same ten cities, three periods, year-specific definitions and approximate
ACS share-MOE methods apply to every measure. The US benchmark appears for
percentages and money, and remains excluded from housing-unit count charts.
Every Chicago estimate/MOE must match its independently prepared dashboard card.
Rerun the comparison runner to verify reproducibility from cached responses.

Some racial-composition sources for Philadelphia, New York and the US are
controlled estimates with the Census `*****` MOE annotation. Per the Census
[ACS accuracy guidance](https://www2.census.gov/programs-surveys/acs/tech_docs/accuracy/MultiyearACSAccuracyofData2013.pdf),
calculations use zero sampling error for those inputs. Raw sentinel values and
annotations are preserved; derived records identify controlled-input counts.
Other genuinely unavailable MOEs are never treated as zero.
