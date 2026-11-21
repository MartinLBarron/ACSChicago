# Model measures on the map and dashboard

The 2020–2024 model source measures are added alongside the six existing dashboard
measures. The display uses percentages and annual household-income dollars,
rather than regression coding in 10-percentage-point units or logged income.
The new fields are available for 2020–2024 only. Older-period selections retain
their original measures; the controls mark new measures as unavailable there.

The active map geographies and default aggregate pipeline are now **tracts and
block groups only**. PUMA/PUMS source scripts and existing caches are retained
as historical workflows, but they are not requested or displayed by default.

## Definitions and coverage

- Rental stock: studio/one-bedroom and 3+-bedroom shares; shares in 2–4, 5–19 and
  20+-unit structures; pre-1940 and 2000+ construction shares.
- Renter profile: moved in 2020+; householder under 35 and age 65+ shares.
- Context: poverty rate; median household income; bachelor+ and no diploma/GED
  shares among adults 25+; non-Hispanic Black and Hispanic/Latino population shares.
- Crime: raw 2020–2024 violent recorded rows, with the frozen IUCR definition.
- Community names remain location labels in popups and outline layers. Block-group
  popups also show the model's largest-overlap community assignment.

All mapped areas are retained (2,312 BGs; 868 tracts), not just the model's
complete-case sample. ACS measures use each geography's own source counts,
preserving raw responses, estimates, 90% MOEs and available annotations. Derived
share MOEs follow the same subset-proportion/sum formulas as the modeling data.
Chicago cards use direct **Chicago city place** source counts and medians; no
average of block-group or tract medians is used. City-comparison popups continue
for the original six measures; new cards are Chicago-only.

Mapped crime counts exclude unusable coordinates and count within whole polygons.
The citywide CPD total includes selected records lacking coordinates. Neither
has an ACS sampling MOE; zero assigned rows is not verified absence of violence.
The annual crime chart uses five single-year CPD totals for 2020–2024, not five
ACS waves. New single-period ACS values appear as cards, not invented trend lines.

## Rebuild

After the baseline ACS and crime pipelines:

```sh
Rscript R/run_model_display.R
```

The default `R/run_pipeline.R` runs this stage last. The downloader obtains direct
2024 tract and Chicago-place estimates through tidycensus plus raw API responses;
BG values reuse the existing full modeling input extraction. Raw caches live at
`data/raw_data/model_display_2024_v1`, analytic supplements under
`data/analytic/model_display_2024`. No new dependencies are introduced.

Public supplements in `html/data/web` are:

- `block_group_model_measures_2024.json`
- `tract_model_measures_2024.json`
- `chicago_city_model_measures_2024.json`
- `chicago_annual_violent_crime.json`

Upload the entire `html/` folder including the new files. The map joins supplements
by GEOID to the matching 2024 geometry. The dashboard merges the city supplement
only into its 2024 row. Existing period and original city-comparison data are kept.

`R/check_model_display.R` verifies full geographic coverage, source/model value
agreement, direct city ratios, E/M round trips, crime count conservation and annual
totals. Rerun the stage to confirm numerical reproducibility.
