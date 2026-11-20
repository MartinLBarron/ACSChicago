# Block-group median contract rent study

This study examines how much between-block-group log median contract rent
variation is associated with rental housing composition, contextual conditions,
and Chicago's 77 community areas. It is ecological and descriptive.

## Agreed design

- ACS 2020–2024; matching 2024 block-group TIGER boundaries.
- Whole areas at least 50% inside the cached City mask by polygon area;
  largest-overlap community assignment. Website selection is unchanged.
- Log median contract rent, equal weight per block group, common complete cases.
- Housing/renter profile: bedroom composition, building size, construction age,
  recent moves and renter-householder under-35/65+ shares.
- Context: poverty, log median household income, bachelor+ and no diploma/GED
  shares among adults 25+, non-Hispanic Black and Hispanic/Latino shares.
- Stages: housing; + economic/education; + racial/ethnic context; + community
  fixed effects. Alternate order separates shared and unique fitted associations.
- Count/precision weighting, stricter boundaries, reliability, influential-case
  and community-deletion checks are sensitivities.

## Run and outputs

After the existing 2024 aggregate/boundary pipeline, from the project root:

```sh
Rscript R/run_bg_analysis.R
Rscript R/check_bg_models.R
```

Dependencies are listed in `packages.txt`; rendering also requires Pandoc.
The full `R/run_pipeline.R` includes this study. Raw caches/manifests are under
`data/raw_data/bg_model_2024_v1`; analytic counts, codebook, share/MOE derivations,
geographic/sample audits and results are under `data/analytic/bg_model_2024`.
Raw E/M and available annotations are retained. Poverty uses C17002_002 + _003
over _001 because B17001 returned no usable block-group estimates.

Source: `R/block_group_rent_report.Rmd`. Rendered self-contained HTML, Markdown,
PNGs, CSVs and input MD5 provenance: `output/models/block_group_rent_2024`.
`R/render_bg_report.R` renders existing fitted results. Data/output are
gitignored; retain the raw cache/manifest and analytic inputs with the report.

## Inference safeguards

HC3 slope intervals have community-clustered HC1 sensitivity intervals.
Singleton communities remain in the fit but are omitted from HC3 covariance
estimation (slopes unchanged). Their influence statistics and HC3 fixed-effect
intervals are undefined. No community-clustered fixed-effect intervals or joint
test is claimed. Inference conditions on noisy ACS inputs and does not fully
propagate their estimation error.

Diagnostics cover residual form/tails, BP/robust RESET, VIFs, correlations,
partial residuals, leverage/Cook/DFBETA, queen and symmetric 4-NN Moran
permutations, maps, tract-blocked CV and leave-community-out slopes. CV assesses
held-out tracts in communities represented in training, not unseen locations.
Residual permutation tests are exploratory under heteroskedasticity.

Read the report's limitations before interpreting community components. The
previous PUMS study is separate and its R² has a different target. Rerun
end-to-end multiple times to independently confirm numerical reproducibility;
`check_bg_models.R` checks scientific invariants and reconstructs HC3 covariance.

## Website Model page

The analysis entry point also runs `R/export_bg_model_web.R`, exporting aggregate
model summaries, coefficient intervals, public block-group diagnostic points and
the full self-contained research report to `html/data/web`. No PUMS unit records
or fitted R objects are exported. To refresh the page after rendering an existing
fit, run `Rscript R/export_bg_model_web.R`; upload the entire `html/` folder,
including the generated JSON and report, to the website root.

The Model page uses local D3 assets for staged fit, coefficients, a conditional
contrast explorer and diagnostics. Explorer contrasts use M3's raw log coefficient
and HC3 interval; share differences are divided by ten and income uses a log
ratio. Negative differences reverse the confidence-limit ordering. The displayed
range is the common sample's 5th–95th percentiles, with its median as reference.
These are conditional associations, not causal effects or prediction intervals.

`Rscript R/check_bg_web_export.R` compares exports to the R fits and verifies the
actual browser contrast helper against independent R calculations (requires Node).

## M4: housing and community location

M4 contains M1’s housing indicators plus community-area fixed effects, without
socioeconomic or racial/ethnic controls. It replaces the earlier internal H_CA
alternate-order label. It uses the same sample, folds and inference safeguards.
M1 → M4 isolates added location fit after housing; M4 → M3 adds measured context.
M4 appears in report/web comparisons, coefficients, diagnostics and sensitivities.

## Exploratory ACS expansion

`R/run_bg_exploratory.R` downloads/derives additional 2024 ACS measures and tests
five remaining candidate domains separately plus priority/all-available combinations.
It is also called by `R/run_bg_analysis.R` after the baseline report/export.
The nine remaining predictors cover rental vacancy, finer bedrooms, median
rooms, household size, crowding and incomplete facilities; recent moves and
renter householder age now belong to the baseline.
Source E/M, raw sentinels/annotations and approximate share MOEs are preserved.

Martin instructed skipping unavailable variables: B25118 renter income, B25115
renter family/children composition and B25127 joint age/structure all returned
nulls for the selected block groups. Their original responses remain in the raw
audit cache; they are excluded from active downloads, models and combinations.
The aborted search for an alternative renter-income table is not continued.

Raw cache: `data/raw_data/bg_exploratory_2024_v1`; analytic inputs, availability
audit and fitted bundle: `data/analytic/bg_exploratory_2024`; rendered companion
report, PNGs, CSVs, formulas and provenance: `output/models/block_group_exploratory_2024`.
Source: `R/block_group_exploratory_report.Rmd`. `R/check_bg_exploratory.R` checks
ratios/MOEs, matched baselines, exact fold/case matching, nested fit and an
independent reconstruction of HC3 covariance for every new slope.

Each experiment refits M2/M3 on its own complete cases and compares the extension
with/without community indicators. CV retains baseline tract folds and scores
all variants on the same eligible test cases. The four open-ended room medians
are omitted from room-containing experiments. These exploratory point comparisons
do not resolve partition uncertainty, ACS measurement error, endogeneity or the
baseline assumption problems. No candidate is automatically promoted to M3.

## Promotion of recent moves and renter age — 2026-11-19

Martin approved adding recent-mover share (B25038: moved in 2020 or later),
renter-householder under-35 share and age-65+ share (B25007) to the original
models. These are three renter-profile terms in the M1 block and carry through
M2a, M2, M3 and M4; M0 remains intercept-only. Age 35–64 is omitted. Each share
uses all renter-occupied units; values, raw annotations and 90% MOEs are retained.

Prior primary and exploratory fitted bundles/reports are preserved in their
respective history/before_movers_age folders. The original 1,468-area sample and
tract folds are preserved. renter_profile_update.csv records before/after fit.
The remaining exploratory tests now assess nine other predictors against the
updated baseline, without testing the promoted terms again as add-ons.

Selection used the existing exploratory folds, so updated cross-validation scores
are comparative diagnostics, not independent post-selection validation. The report
and website state this explicitly. All updated tables, charts and effect-explorer
inputs are regenerated by R/run_bg_analysis.R.
