# ACSChicago

Reproducible R pipeline for Chicago geographic boundaries.

## Block-group rent research report

The staged 2020–2024 median contract rent study is documented in
[docs/block_group_rent_model.md](docs/block_group_rent_model.md). Run
`Rscript R/run_bg_analysis.R` after preparing the existing 2024 aggregate data.
It produces `output/models/block_group_rent_2024/report.html`, with diagnostics,
sensitivity analyses, and source/sample audits. The source is
[R/block_group_rent_report.Rmd](R/block_group_rent_report.Rmd).

Additional ACS candidates are tested separately with
`Rscript R/run_bg_exploratory.R`. The companion report is
`output/models/block_group_exploratory_2024/report.html`, with source
[R/block_group_exploratory_report.Rmd](R/block_group_exploratory_report.Rmd).
It preserves M0–M4 and uses matched-case baselines and the original tract folds.

The CPD crime extension is documented in [docs/crime_model.md](docs/crime_model.md).
Run `Rscript R/run_crime_analysis.R` to download the 2020–2024 records, audit
violent-offense/geographic coverage and fit M5 (M3 plus the raw violent row count).
The review report is `output/models/block_group_crime_2024/report.html`; M5 is
kept separate from the website pending review.

For the crime-first sequence (M0 intercept; M1 crime; M2 housing/renter profile;
M3 socioeconomic context; M4 community areas), run `Rscript R/run_crime_stages.R`.
Its new report is `output/models/block_group_crime_stages_2024/report.html`.
See [docs/crime_stages.md](docs/crime_stages.md) for the specification and checks.

## Interactive map

The map now uses tracts and block groups only. Latest-period model measures,
including recorded violent crime, are documented in
[docs/model_display_measures.md](docs/model_display_measures.md). Rebuild their
map/dashboard supplements with `Rscript R/run_model_display.R` after the ACS and
crime stages. Include the complete `html/data/web/` folder when uploading.

The local MapLibre GL JS webpage in `html/` displays city limits, community areas,
and ACS rent choropleths for three periods, for whole block groups and tracts, with measure and
geography selectors, boundary toggles, and click-to-inspect estimates and MOEs.
After downloading the shapefiles, generate browser-ready WGS84 GeoJSON and serve
the project root:

```sh
Rscript R/export_web_data.R
Rscript R/export_rent_web_data.R
python3 -m http.server 8000 --directory html
```

Open <http://localhost:8000/>. The `html/` directory is a self-contained website;
its map loads `html/data/web/` through relative `data/web/` paths. Opening the HTML
directly as a file will not work. MapLibre's pinned
CDN assets and OpenStreetMap basemap require internet access. Regenerate GeoJSON
after refreshing shapefiles. All R source remains in `R/` and data in `data/`.

## Run

From the project root, install `sf` once, then run the pipeline:

```sh
Rscript -e 'install.packages("sf", repos = "https://cloud.r-project.org")'
Rscript R/download_boundaries.R
```

`sf` requires GDAL, GEOS, and PROJ; CRAN provides binaries for supported macOS
and Windows versions. Internet access is required on the first run.

## Layout

- `R/`: all R source files.
- `data/raw_data/`: original City GeoJSON exports, original Census ZIP, and a
  source manifest containing URLs, cache timestamps, and MD5 checksums.
- `data/shape/`: shapefiles (including sidecar files), extracted Illinois TIGER
  data, and R/spatial-library session information.

Generated data are ignored by Git. Keep the raw cache and manifest together to
reproduce a particular run; City sources are live exports, not versioned snapshots.
Reruns reuse cached downloads and check their hashes. To intentionally refresh a
source, archive its cached file and the manifest first. The script overwrites its
derived shapefile layers on each successful run.

## Sources and geographic definitions

The official City of Chicago Data Portal supplies
[city limits](https://data.cityofchicago.org/d/qqq8-j68g) and
[77 community areas](https://data.cityofchicago.org/d/igwz-8jzy).
Original exports are retained as GeoJSON and converted to shapefiles.
Block groups use the full-resolution **2025 TIGER/Line** Illinois state file from
the [U.S. Census Bureau](https://www.census.gov/geographies/mapping-files/2025/geo/tiger-line-file.html),
rather than generalized cartographic boundaries. Change `tiger_year` in the R
script only when intentionally adopting a different geographic vintage.

The pipeline selects block groups from all of Illinois using positive area overlap
with city limits, preserving their complete geometry and 12-character `GEOID`.
This includes partially overlapping suburban block groups and small overlaps caused
by differences between City and Census boundary vintages. A separate `_clipped`
shapefile contains only the portions inside Chicago for mapping. Neither selection
nor clipping allocates population or ACS estimates to Chicago; that needs a separate
method. Match future ACS data to the appropriate geographic vintage.

Derived shapefiles use NAD83 / UTM zone 16N (EPSG:26916), in meters. The extracted
Illinois source retains its original CRS. Shapefile field names may be shortened to
10 characters; use the original cached exports when full source field names matter.
Census `ALAND` and `AWATER` are written as text to preserve integer values beyond
the shapefile numeric field width; convert them to numeric in R for calculations.
The pipeline checks geometry validity, community-area count, unique Census GEOIDs,
and successful shapefile round trips. Dependency versions are recorded in
`data/shape/session_info.txt`; package installation itself is not version-locked.

## Census tracts

The pipeline also downloads the official 2025 Illinois TIGER/Line tract archive
(`tl_2025_17_tract.zip`) into `data/raw_data/`, recording its checksum in the same
manifest. Original Illinois tract shapefiles are extracted into
`data/shape/tiger_2025_illinois/`. Whole Chicago tracts and a clipped mapping layer
are saved under `data/shape/chicago_tracts_2025/` and
`data/shape/chicago_tracts_2025_clipped/`. Tracts use the same positive-area city
overlap rule as block groups, with no O'Hare exclusion. Tract GEOIDs retain all
11 characters. The web export writes `data/web/chicago_tracts_2025.geojson`.
The map has independent tract and block-group toggles, and identifies both GEOIDs
on click. Rerun both R scripts to refresh the map data.

## ACS rent analysis (2020–2024)

Settings are in `R/acs_config.R`; reusable download, selection, and validation
functions are in `R/acs_helpers.R`. Dependencies are listed in `packages.txt`.
The scripts also look for dependencies in the project-local `.R-library/`.
Set `CENSUS_API_KEY` in your ignored `.Renviron` (never commit the key).

```sh
Rscript -e 'install.packages(readLines("packages.txt"), repos = "https://cloud.r-project.org")'
Rscript R/download_acs_rent.R
```

This runs the ACS stages independently. To run the entire project pipeline:

```sh
Rscript R/run_pipeline.R
```

The ACS pipeline downloads 2024 TIGER/Line tract and block-group boundaries and
uses `tidycensus::get_acs(year = 2024, survey = "acs5", moe_level = 90)` to retrieve
median contract and gross monthly rent. Entire areas with positive City overlap
are retained. Both estimates and MOEs are preserved, along with original API
codes and annotations. See [the codebook](docs/acs_rent_codebook.md) for output
files, column definitions, and interpretation, and [the decision log](Decisions_Log.md)
for the agreed choices. Raw data are cached; reruns reuse them and check recorded
hashes. Archive the cache and manifest together before intentionally refreshing.
Check reproducibility by running the pipeline end-to-end multiple times.
The rent map uses the matching 2024 analytic GeoPackages. Rebuild its GeoJSON
with `Rscript R/export_rent_web_data.R` after refreshing the analytic data.
Shared fixed monthly-dollar breaks are $750, $1,000, $1,250, $1,500, $2,000, and
$2,500. Gray means no estimate; click an area for both measures, their published
90% MOEs, and Census annotations. Repeated pipeline runs should reproduce the
same exports. The original 2025 boundary downloads remain available separately.

The analytic datasets also contain `cash_rent_units` (B25063_002) and
`renter_occupied_units` (B25003_003), each with its estimate, 90% MOE, raw codes,
and annotations. These are housing-unit counts. The map displays them on click
to support interpretation of missing rent estimates; a zero is an ACS estimate,
not a verified absence of rental housing.

Both housing-unit counts are selectable choropleth measures. Count legends use
0, 1–99, 100–249, 250–499, 500–999, 1,000–1,999, and 2,000+ units, shared across
tracts and block groups. These show absolute estimated counts, not percentages
or density. Estimated zero has its own color class; missing estimates stay gray.

The water-only Lake Michigan tract `17031990000` and its block group
`170319900000` are excluded from the 2024 analytic datasets and rent map.
The reproducible exclusion is in `R/acs_config.R`; raw sources are retained.

## Shared hosting

Run both export scripts (or `Rscript R/run_pipeline.R`) before uploading.
The exporters keep research exports in `data/web/` and copy the eight map assets
into `html/data/web/`, verifying matching checksums. Upload **all contents of
`html/`** to the hosting document root, preserving its subdirectories:

```text
index.html
map.js
style.css
data/web/chicago_city.geojson
data/web/chicago_community_areas.geojson
data/web/tract_rent_2014.geojson
data/web/block_group_rent_2014.geojson
data/web/tract_rent_2019.geojson
data/web/block_group_rent_2019.geojson
data/web/tract_rent_2024.geojson
data/web/block_group_rent_2024.geojson
```

The server needs no R installation, packages, raw inputs, or shapefiles. Generated
GeoJSON copies are ignored by Git; include them explicitly in manual uploads.

## Non-overlapping ACS periods

`Rscript R/download_acs_rent.R` now gathers **2010–2014, 2015–2019, and
2020–2024**, with the same four variables and their 90% MOEs, raw codes, and
annotations. Periods are configured in `R/acs_config.R`. Each period has its own
cached sources, matching TIGER boundaries, and analytic files under directories
ending in `acs_2014`, `acs_2019`, or `acs_2024`.

The script also runs `R/combine_acs_periods.R`, producing combined tract and
block-group CSV/RDS datasets and GeoPackages under `data/analytic/acs_combined/`.
GeoPackages have separate layers for each year. The table key is
`acs_end_year` plus `GEOID`; long tables also include `variable`.

These datasets retain native boundaries and end-year dollar units. They are
repeated cross-sections, not a harmonized panel. Inflation and boundary changes
must be addressed before interpreting historical rent differences. The web exports include all three releases, selected with the map period picker. The [codebook](docs/acs_rent_codebook.md)
details these conventions. The 2005–2009 release is excluded by user decision.

The dashboard period picker defaults to 2020–2024 and also offers 2015–2019 and
2010–2014. Historical layers load on demand and are cached in browser memory.
Period changes update both tract and block-group sources and preserve the selected
measure, geography, and map position. Upload all eight files from `html/data/web/`
when updating shared hosting. Dollar breaks stay fixed, but dollar units reflect
the selected period's end year; the map explicitly labels the lack of inflation
adjustment and the use of changing native boundaries.

## Published Chicago citywide statistics

The ACS pipeline also retrieves the four measures directly for Census place
**Chicago city, Illinois (`1714000`)**, for every period, with published 90% MOEs,
raw codes, and annotations. It does not aggregate block-group or tract medians.
Find `chicago_city_rent.csv` / `.rds` and `chicago_city_rent_long.csv` / `.rds`
in each `data/analytic/acs_YEAR/` directory and the combined directory. Combined
outputs contain three city-period rows or twelve city-period-measure rows.
These published place estimates feed the citywide dashboard cards and charts.

## Chicago citywide cards and D3 trends

Below the map, four citywide cards follow their own statistics-period selector,
independent of the map. Four D3 line
charts show each measure across all three periods, with published 90% MOE bars,
statistics-period outlines, keyboard-focusable point details, and an accessible
HTML data table. The graphs use independent unit scales starting at zero. They
show period estimates, not annual measurements; rents remain in end-year dollars
without inflation adjustment.

`R/export_city_web_data.R` exports the validated published place estimates to
`data/web/chicago_city_statistics.json` and copies them into `html/data/web/`.
It runs at the end of `R/run_pipeline.R` and can also be run independently after
ACS retrieval. Include this JSON, `city-stats.js`, and the pinned D3 library in
`html/vendor/` in uploads, along with the existing HTML/CSS/map assets and GeoJSON.
The four cards and HTML table remain available if the chart library fails to load.

## Rent burden

The supplementary pipeline retrieves B25070 source counts for every period,
tract/block group, and Chicago place. To run these stages after core ACS retrieval:

```sh
Rscript R/download_acs_housing.R
Rscript R/derive_acs_housing.R
Rscript R/export_rent_web_data.R
Rscript R/export_city_web_data.R
```

`R/housing_config.R` defines the active source variables and formulas. The active
supplement now contains only the **50%+ rent-burden share** only. All B25070 categories remain necessary
for the computed-ratio denominator and its MOE; the 30%+ summary is no longer
calculated. Bedrooms and utility-payment tables are no longer requested, used,
or included in active source manifests. Earlier raw cache files are retained
locally as unused historical downloads, rather than modified or deleted.

The website offers five measures: the original four rent/count measures plus the
50%+ burden share. The citywide section shows all five cards and charts together, with its period
selector independent of the map. Percentage breaks
remain 10/20/30/40/50/75; percentages have approximate MOEs in percentage points.
Web exports contain only active measures. Re-upload the full `html/` folder after
regeneration to remove retired fields and controls from hosting.

Combined analytic outputs remain `data/analytic/acs_combined/TAG_housing.*`,
with separate source and derived long files. See the
[housing codebook](docs/acs_housing_codebook.md) for definitions and uncertainty
handling. The full `R/run_pipeline.R` executes all stages. Re-run end-to-end to
check reproducibility; original raw inputs are cached and checksummed.

The map measure selector is a flat list of all five measures. The citywide
section has no topic filter: every measure has its own card and trend chart.

City/national comparison data are also collected by
`R/download_acs_comparisons.R` (included in the full pipeline): Chicago and
nine comparison cities, plus the United States, for all three ACS periods.
See [the housing codebook](docs/acs_housing_codebook.md#city-and-national-comparisons)
for geography definitions, outputs, and validation.

### Archived PUMA boundary overlay

**Retired from the website and default pipeline on 2026-11-20.** The following
describes the earlier workflow; source scripts and cached outputs are retained
for historical reproducibility only. Active maps now use tracts and block groups.

The map's optional **PUMAs** checkbox displays whole Public Use Microdata
Areas with positive Chicago overlap, selected directly against matching-year
TIGER Chicago city limits (place GEOID `1714000`). Edge/point contact is
excluded using native-coordinate polygon-interior tests, avoiding slivers
from mixing City portal and TIGER linework. `R/download_puma_boundaries.R`, included
in the full pipeline, downloads Illinois TIGER/Line PUMAs for 2014, 2019,
and 2024. The first two use 2010-defined PUMAs; 2024 uses 2020-defined PUMAs.
PUMA and Illinois place archives and checksum manifests are in `data/raw_data/puma_YEAR/`; extracted
shapefiles and selected Chicago-overlap GeoPackages are in
`data/shape/puma_YEAR/`. GeoJSON exports named `chicago_pumas_YEAR.geojson`
are written to both `data/web/` and `html/data/web/`.

The five PUMAs covering Oak Lawn, Addison, Northlake, Elk Grove Village,
and Des Plaines are explicitly excluded using vintage-specific GEOIDs in
`R/acs_config.R`. This leaves 18 map PUMAs per period. The per-year
`puma_selection.csv` records city overlap, requested exclusion, and retention.
The exclusions apply to whole PUMAs, so some Chicago territory within these
mixed city/suburban PUMAs is omitted from this optional overlay, including
O'Hare/Edison Park coverage in the older definition.

PUMAs are available both as an optional outline overlay and as a rent-map
geography. The geography picker shades PUMA areas using published PUMA
estimates and our derived shares; it does not average tract or block-group
values.
Clicking with the overlay enabled shows the PUMA name, code, and definition
vintage. Period switching updates tracts, block groups, and PUMAs together.
PUMAs are designed to contain at least 100,000 people and may extend beyond
city limits; they are not the 77 community areas. Their definitions changed
between the two decennial vintages, so codes alone are not stable longitudinal
identifiers. Sources: [Census PUMA guidance](https://www.census.gov/programs-surveys/geography/guidance/geo-areas/pumas.html)
and [ACS geography vintages](https://www.census.gov/programs-surveys/acs/geography-acs/geography-boundaries-by-year.html).

PUMA aggregates follow the same core → supplementary → derived → web-export
stages as tracts and block groups. Validate the finished PUMA data with
`Rscript R/check_puma_data.R`. See the housing codebook for table-level
caching and the documented recovery from Census server timeouts.

### Archived PUMS housing microdata (2020–2024)

The modeling pipeline starts with a separate local housing-unit extract:

```sh
Rscript R/download_pums.R
Rscript R/prepare_pums.R
Rscript R/check_pums.R
```

The download uses `tidycensus::get_pums(recode = TRUE, return_vacant = TRUE)`
for Illinois, with housing and replicate weights. Preparation retains the
same 18 PUMAs selected for the 2024 map. See the
[PUMS housing codebook](docs/pums_housing_codebook.md) for variables, output
paths, sampling-unit safeguards, and geographic limitations. The default pipeline no longer includes these legacy steps. Microdata are not published to the website.

### First contract-rent models

After PUMS preparation, run `Rscript R/model_contract_rent.R` and
`Rscript R/check_rent_model.R`. This legacy model is no longer run by the default pipeline.
It compares housing-weighted log contract rent models with and without PUMA
fixed effects, using ACS replicate weights for uncertainty. The local report
is `output/models/contract_rent_2024/report.md`. See
[the model documentation](docs/contract_rent_model.md) for sample rules,
inflation adjustment, interpretation, diagnostics, and reproducibility checks.

### Paired contract- and gross-rent models

Run `Rscript R/run_rent_outcome_comparison.R` after preparing the crime/model
sample. It fits the crime-first M0–M4 specifications to both log rent outcomes
on identical complete cases and tract folds, with diagnostics and a joint
open-ended-median sensitivity. The report is
`output/models/rent_outcome_comparison_2024/report.html`; its source is
`R/rent_outcome_comparison.Rmd`. The crime-stages runner includes this comparison.

### All-period map and citywide measures

`Rscript R/run_model_display.R` now builds every display measure for 2010–2014,
2015–2019 and 2020–2024, including historical violent-crime counts. It preserves
ACS estimates/MOEs, validates changing table definitions and assigns crime points
to each period's geometry. See [measure definitions and rebuild instructions](docs/model_display_measures.md).
Upload the complete `html/data/web` directory with the updated HTML/JS.
The Model page continues to describe the 2020–2024 regressions.

### ACS comparisons for every card

After core and model-display preparation, `Rscript R/run_comparisons.R` builds
all 25 ACS comparison measures for the ten cities and US across all three
periods, preserving estimates, MOEs, raw source responses and annotations.
The default pipeline includes this extension. See
[the peer comparison notes](docs/model_display_measures.md#complete-acs-peer-comparisons).
Violent crime requires a separate peer-city source and is currently Chicago-only.

### Spatial error and lag sensitivity report

After the original crime-first and joint-omission diagnostic fits, run
`Rscript R/run_spatial_sensitivity.R`. It compares OLS, SEM and SAR versions of
original/reduced M3/M4 on identical cases under queen and symmetric KNN4 weights,
with heteroskedasticity-robust GMM sensitivity, exact SAR impacts, instrument
audits, numerical checks and a self-contained R Markdown HTML report.

Report: `output/models/spatial_sensitivity_2024/report.html`; source:
`R/spatial_sensitivity_report.Rmd`. Models/cache: `data/analytic/spatial_sensitivity_2024`.
This is a separate diagnostic branch and does not replace the website models.
Install the listed packages before running; rerun the runner to verify cached
reproducibility.
