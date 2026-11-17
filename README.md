# ACSChicago

Reproducible R pipeline for Chicago geographic boundaries.

## Interactive map

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

## Rent burden, bedrooms, and utilities

The full pipeline now retrieves supplementary source counts from B25070 (rent
burden), B25042 (renter bedrooms), and B25069 (utility payment) for every period,
tract/block group, and Chicago place. To run these stages independently after
core ACS retrieval:

```sh
Rscript R/download_acs_housing.R
Rscript R/derive_acs_housing.R
```

`R/housing_config.R` defines source variables and formulas. Raw counts retain
estimates, MOEs, special codes, and annotations in a separate cache. The derived
stage computes 30%+/50%+ rent-burden shares, renter-bedroom shares, and utility
payment shares, with approximate 90% MOEs in percentage points. It records
numerators, denominators, missingness reasons, and MOE methods. Combined analytic
files are `data/analytic/acs_combined/TAG_housing.*`, with separate source and
derived long files. See [the housing codebook](docs/acs_housing_codebook.md) for
exact definitions and file layout. These datasets are ready for later frontend
additions; existing map and citywide chart measures are unchanged.
