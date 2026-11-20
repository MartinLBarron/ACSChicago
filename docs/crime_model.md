# CPD violent-crime counts and M5

Martin approved an association study using occurrence years 2020–2024. M5 is
the current M3 plus one literal, untransformed five-year `violent_crime_count`.
The input is row-based, not deduplicated by case number; murder victim rows
can contribute more than one row per incident. No rate denominator, logarithm,
annualization, severity weighting, neighboring-area buffer or arrest filter.

## Source and definition

Official CPD dataset: `ijzp-q8t2` on data.cityofchicago.org. Download all offense
rows in the requested occurrence-date window, selecting only the fields needed
for classification, coordinates and quality checks. Yearly keyset-paginated CSVs,
server row counts, metadata before/after, request predicates and MD5 manifests
form a frozen cache. CPD can revise historical records; this extraction is not
an as-of-2024 data vintage. Later runs reuse the snapshot rather than silently
refreshing historical observations.

The official IUCR lookup `c7ck-438e` supplies the frozen code mapping. Include
Index-I murder, criminal sexual assault, robbery and aggravated assault/battery.
Exclude simple/minor-injury non-Index offenses even where a statutory description
uses “aggravated”; exclude reckless homicide and involuntary manslaughter. Keep
qualifying domestic, attempted and inactive-code records. Publish the complete
inclusion map and audit unknown codes; stop if potentially violent codes lack
a lookup entry. Include child sexual-assault codes 1753/1754 and Index ritual
battery codes despite their broader primary headings; cross-check all rows
against recorded FBI violent categories 01A/02/03/04A/04B.

## Geography and coverage

Filter unusable coordinates; never impute or snap missing/unmatched locations.
Assign geocoded rows to whole 2024 block-group polygons. Prefer strict interiors;
boundary ties resolve by smallest GEOID and are counted in the audit. CPD public
locations are privacy-protected approximations, not exact incident addresses.
Count all assigned rows in each whole polygon; retain the baseline majority-city
modeling sample and its community assignments. The >=99%-inside-city sensitivity
refits M3 and M5 on matching stricter cases.

Zero is zero assigned geocoded rows, not proven absence of violence. Missing
coordinates are audited by year/offense and CPD-reported community. CPD community
labels are not used to allocate missing incidents. City-only coverage can miss
suburban events in crossing polygons. Raw counts also reflect population, area,
visitors and reporting; they are not resident risk estimates.

## Run and review

After producing baseline M3 and geography:

```sh
Rscript R/run_crime_analysis.R
Rscript R/check_crime.R
```

The full `R/run_pipeline.R` includes this step. No new R packages are required.
The first extraction requires internet access and may take several minutes.
Raw files: `data/raw_data/cpd_crime_2020_2024_v1`. Local record-assignment audit,
annual/offense/BG counts, M5 data and fitted bundle: `data/analytic/crime_2020_2024`.
Report/Markdown/PNGs/tables/provenance: `output/models/block_group_crime_2024`.
Source report: `R/block_group_crime_report.Rmd`. The website remains unchanged
pending review; no point-level data or M5 exports are written to `html/`.

M3 and M5 use identical cases and baseline tract folds. Report HC3 and community-
clustered slope uncertainty, residual/functional-form/spatial diagnostics, VIFs,
influence, strict-city results and leave-one-community-out crime slopes. A
per-100-row percentage contrast is a presentation calculation only: the fitted
predictor is the unscaled raw count. The sign is unrestricted and tests two-sided.

Checks cover snapshot reconciliation, IDs/dates, code mapping, coordinate and
boundary fixtures, conserved counts, unchanged M3/sample/folds, exact raw-count
design column, nested fit and an independently reconstructed HC3 crime-slope
variance. Repeat the frozen-cache pipeline to confirm numerical reproducibility.
