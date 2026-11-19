# Block-group median contract rent study

This study examines how much between-block-group log median contract rent
variation is associated with rental housing composition, contextual conditions,
and Chicago's 77 community areas. It is ecological and descriptive.

## Agreed design

- ACS 2020–2024; matching 2024 block-group TIGER boundaries.
- Whole areas at least 50% inside the cached City mask by polygon area;
  largest-overlap community assignment. Website selection is unchanged.
- Log median contract rent, equal weight per block group, common complete cases.
- Housing: bedroom composition, building size, construction age among renters.
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
