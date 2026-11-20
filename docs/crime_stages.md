# Crime-first staged association study

Question: “What is the association between median rent and violent crime?”
The dependent variable remains log ACS 2020–2024 median contract rent; the
exposure remains the untransformed five-year CPD violent row count.

## New numbering, separate results

- M0: intercept only.
- M1: violent crime only.
- M2: M1 + housing composition and renter profile (recent moves and age).
- M3: M2 + socioeconomic/demographic context (poverty, income, both education
  measures, non-Hispanic Black and Hispanic/Latino shares).
- M4: M3 + community-area categorical indicators.

These labels belong to this report only. New M4 is the same specification as
the previous crime report's M5; previous reports and website models are retained.
All five stages use identical complete cases, equal BG weights, raw crime counts
and original tract folds. CV scores every stage on the same eligible test rows.

## Run

After the CPD preparation/baseline study, no new download is required:

```sh
Rscript R/run_crime_stages.R
Rscript R/check_crime_stages.R
```

The full `R/run_crime_analysis.R` also runs these stages after the prior M5 report.
Source formulas: `R/crime_stages_config.R`. R Markdown source:
`R/crime_stages_report.Rmd`. Fitted objects: `data/analytic/crime_stages_2024`.
Rendered report/Markdown/PNGs/tables/provenance:
`output/models/block_group_crime_stages_2024`. Dependencies are already listed
in `packages.txt`; rendering requires Pandoc.

Report summaries include staged R²/adjusted R² and held-out metrics, crime's
unique/partial R² at each control level, HC3 and community-clustered intervals,
per-100-row forest and contrast charts, residual/QQ/partial-residual plots,
BP/RESET, VIFs, influence, residual Moran permutations and strict-city sensitivity.
The per-100-row percentage is an interpretation calculation only, not a predictor
transformation. M0's BP/RESET are undefined and not claimed. Saturated singleton
handling is restricted to models containing community indicators.

Checks verify formulas, same sample/folds, literal raw-count design, nested fit,
bivariate correlation/slope identities, final-model equivalence with old M5 and
independent HC3 reconstruction at each stage. Repeat the runner to independently
confirm numerical reproducibility. These estimates remain associations with
measurement, selection, spatial and functional-form limitations; stage-to-stage
coefficient changes are not a causal mediation analysis.
