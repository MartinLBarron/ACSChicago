# ACSChicago

Reproducible R pipeline for Chicago geographic boundaries.

## Interactive map

The local MapLibre GL JS webpage in `html/` displays city limits, community areas,
and whole 2025 block groups and tracts, with layer toggles and click-to-inspect details.
After downloading the shapefiles, generate browser-ready WGS84 GeoJSON and serve
the project root:

```sh
Rscript R/export_web_data.R
python3 -m http.server 8000
```

Open <http://localhost:8000/html/>. Serve the project root so the page can access
`data/web/`; opening the HTML directly as a file will not work. MapLibre's pinned
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
