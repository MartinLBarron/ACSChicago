# First contract-rent regression stage

Martin approved the initial specification: log monthly contract rent in 2024
dollars, bedrooms, rooms, building size, construction-year category, and
household size, compared with the same model plus PUMA fixed effects. This is
a descriptive baseline model, not a causal neighborhood-effect estimator.

## Entry points

```sh
Rscript R/model_contract_rent.R
Rscript R/check_rent_model.R
```

`R/run_pipeline.R` runs the model after PUMS preparation. The direct model
step is local and does not redownload Census data. The added direct dependency
is `survey`, listed in `packages.txt`; local installations use `.R-library`.
No random sampling or resampling is performed: the 80 Census replicate weights
are supplied by the survey, so reruns are deterministic.

## Data and sample

Input: `data/analytic/pums_2024/chicago_housing.rds` (43,977 housing records in
the 18 retained PUMAs). Source data and this housing dataset remain unchanged.
The model uses occupied units paying cash rent (`TEN = 3`) with positive,
finite RNTP, valid ADJHSG, valid controls, and a positive full housing weight.
Missing controls are excluded explicitly rather than treated as categories.
No-cash-rent, owner-occupied, and vacant units remain in the parent dataset.
The first fit uses 18,437 units; the two models use exactly the same sample.

The new model sample is `data/analytic/pums_2024/contract_rent_model_sample.rds`.
A separate local `contract_rent_sample_audit.csv` records each original
SERIALNO's inclusion/exclusion reason. Outputs contain a sequential sample
waterfall. No complete-case filtering is left to the regression function.
Allocated/imputed rents are retained, as are top-coded source values; the
allocation count is reported. There is no winsorization, outlier deletion,
category merging, automatic variable selection, or train/test partition.

## Outcome and controls

- `contract_rent_2024 = RNTP * as.numeric(ADJHSG) / 1,000,000`.
- `log_contract_rent = log(contract_rent_2024)` (natural logarithm).
- Bedrooms (BDSP), rooms (RMSP), and household size (NP) are linear terms.
- Building size (BLD) and construction year (YRBLT) use the source categorical
  labels as **unordered** factors. Codes are not numeric building ages.
- The housing-weighted most common category is the reference for each housing
  factor. Treatment contrasts are set explicitly for reproducibility.
- PUMAs use treatment-coded fixed indicators, with the first GEOID as the
  coding reference. Public PUMA differences are subsequently centered so the
  arbitrary coding reference does not drive their interpretation.

The dollar adjustment is applied once in the new model sample from the
unchanged source RNTP. It is not applied back to the housing extract. A
coefficient transformed as `100 * (exp(beta) - 1)` describes a change in fitted
geometric rent holding other regressors fixed. It is not an arithmetic mean
rent estimate or, without additional assumptions, a median-rent effect.

## Survey design and uncertainty

Use `survey::svrepdesign(type = "ACS", combined.weights = TRUE, mse = TRUE)`
with WGTP and the exact ordered WGTP1–WGTP80 columns. The design's variance
scale is checked against 4/80, with replicate scaling factors of one. Fit
Gaussian `survey::svyglm()` models with `return.replicates = TRUE` and
`na.action = na.fail`.

Intervals are **95%**, pointwise, and use model-specific residual degrees of
freedom (54 for housing controls; 37 with PUMA indicators in this fit). These
are regression intervals, not the 90% MOEs used for the aggregate ACS website.
The covariance is independently checked against `4/80 * crossprod(beta_rep -
beta_full)`. The package attaches metadata to its covariance matrices; checks
compare numeric values and dimensions rather than irrelevant attributes.

Replicate weights are never clipped. The current model sample has no negative
replicate weights; the original PUMS extraction continues to preserve valid
negative weights elsewhere. A later sample with signed weights may need a
regression routine that supports them; ordinary GLM routines reject them.

## Quantifying the PUMA association

Both weighted R² values use the same response, full housing weights, and
weighted total sum of squares. We report:

1. Housing-controls R² and housing-plus-PUMA R² (in-sample log-rent fit).
2. Their difference, the incremental explained weighted variation.
3. Partial R²: `(SSE_controls - SSE_controls_puma) / SSE_controls`.
4. A joint design-based Wald F test of the 17 PUMA indicators.
5. Adjusted PUMA differences relative to the housing-weighted PUMA benchmark.

R², its increment, and partial R² are also recomputed for each replicate and
receive SDR standard errors/intervals. These are descriptive fit measures,
not causal shares or a random-intercept variance partition/ICC.

For adjusted PUMA differences, isolate the fitted PUMA component and subtract
its average weighted by the model-sample distribution across the 18 PUMAs.
Repeat both coefficient estimation and centering within each replicate,
including changes in the estimated area shares. Transform log contrasts and
interval endpoints to percentages. The benchmark is geometric and refers to
cash-rent units satisfying the common model-sample definition, not all
Chicago households. PUMA intervals are not multiplicity-adjusted and cannot
be read as tests of all pairwise differences.

## Local outputs

`output/models/contract_rent_2024/` contains:

- `report.md`, `adjusted_puma_effects.png`, and `residual_diagnostics.png`.
- `model_fit.csv`, `coefficients.csv`, and `puma_incremental_fit.csv`.
- `adjusted_puma_effects.csv` and `puma_joint_test.csv`.
- `sample_flow.csv`, `sample_by_puma.csv`, and `category_counts.csv`.
- `residual_diagnostics.csv`, `model_diagnostics.csv`, and `model_metadata.json`.
- `models.rds`, containing model objects, replicate coefficients, and fit statistics.

This generated directory is gitignored because model objects contain microdata
and survey designs. No unit records or model results are exported to the
website in this step. The metadata records input/sample checksums, formulas,
factor references, confidence level, and survey package version.

Diagnostics include weighted binned residual means/spread, design-matrix rank,
condition number, leverage, and small category counts. Bedrooms and rooms are
strongly correlated, so their individual coefficients must be read conditionally.
Some construction-year/building categories have very few observations; these
estimates are unstable even when the matrix is full rank. This first model does
not resolve nonlinearities, rent subsidies, unobserved quality, or omitted
household/neighborhood covariates.

The geography is PUMA, not the 77 community areas. The sample excludes the five
specified suburban PUMAs, omits some Chicago territory, and can include territory
outside Chicago in retained areas. Public PUMS also uses crosswalked 2020–2021
geographies and privacy protections. PUMA indicators describe conditional
associations for this geographic/sample scope, not causal neighborhood premiums.

## Verification

`R/check_rent_model.R` compares survey point estimates with independent
housing-weighted least squares, verifies SDR covariance, checks the common
sample and one-time dollar adjustment, and checks point/replicate PUMA centering.
Run the modeling stage end to end more than once to confirm unchanged tabular
results and input checksums. A synthetic helper fixture additionally checks
sample definitions and dollar adjustment without using actual unit records.

Methods: [Census 2020–2024 PUMS user guide](https://www2.census.gov/programs-surveys/acs/tech_docs/pums/2020_2024ACS_PUMS_User_Guide.pdf),
[survey replicate designs](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/svrepdesign.html),
[survey regression](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/svyglm.html),
and [joint term tests](https://r-survey.r-forge.r-project.org/pkgdown/docs/reference/regTermTest.html).
