# Decision Log

## 2026-11-17
- User selected the latest available ACS five-year release, 2020–2024 (API year 2024), rather than multiple annual releases or the unreleased 2025 five-year data.
- User selected median monthly contract rent (B25058_001) and gross rent (B25064_001), each retaining its published 90% margin of error.
- User selected ACS-year-matched TIGER boundaries and whole geographies with positive Chicago area overlap. Therefore ACS outputs use 2024 TIGER/Line boundaries; existing 2025 map layers remain separate.
- Original API responses and annotations are cached alongside tidycensus results. Negative special codes become missing analytic dollar values while original codes remain in companion columns. Implementation by Codex.
- The cached official City boundary defines Chicago overlap. Partial suburban areas and O'Hare remain included under the user's previously approved selection rule. Rents describe whole Census areas, not just their Chicago portions.

- User requested rent choropleths and delegated reasonable breaks. Codex selected fixed monthly-dollar thresholds of 750, 1000, 1250, 1500, 2000, and 2500, shared across measures and geography levels for direct comparison. Sequential YlGnBu colors show estimates; missing estimates are gray. Default view is gross rent by tract. MOEs and Census annotations are shown on click; colors do not encode significance. Rent mapping uses matching 2024 analytic geometry, replacing 2025 Census geometry in the displayed map.
- User requested occupied units paying cash rent (B25063_002) and all renter-occupied units (B25003_003). Both are added for 2020–2024 tracts and block groups, retaining estimates, 90% MOEs, raw codes, and annotations. Added counts are cached separately to preserve original rent source files. Count units are explicitly distinguished from monthly dollar values. Map click details include counts without classifying missing-median causes as certain.

- User requested both housing-unit counts as selectable map measures. Count maps use shared classes 0, 1–99, 100–249, 250–499, 500–999, 1,000–1,999, and 2,000+ across both geography levels and count measures. Zero is shown separately from missing data. Counts are labeled as absolute estimated units, not rates or density. Existing dollar breaks remain for rents. Implementation by Codex.
