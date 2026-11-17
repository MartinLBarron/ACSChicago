# Decision Log

## 2026-11-17
- User selected the latest available ACS five-year release, 2020–2024 (API year 2024), rather than multiple annual releases or the unreleased 2025 five-year data.
- User selected median monthly contract rent (B25058_001) and gross rent (B25064_001), each retaining its published 90% margin of error.
- User selected ACS-year-matched TIGER boundaries and whole geographies with positive Chicago area overlap. Therefore ACS outputs use 2024 TIGER/Line boundaries; existing 2025 map layers remain separate.
- Original API responses and annotations are cached alongside tidycensus results. Negative special codes become missing analytic dollar values while original codes remain in companion columns. Implementation by Codex.
- The cached official City boundary defines Chicago overlap. Partial suburban areas and O'Hare remain included under the user's previously approved selection rule. Rents describe whole Census areas, not just their Chicago portions.
