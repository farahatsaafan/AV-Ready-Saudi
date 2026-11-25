# Review note for Dr. Omar Elzaki — AV-Ready-Saudi (Ali Ezzat, 24 Nov 2026)

Purpose: confirm the relations and the Gold design before the Gold re-review, and settle one question about data shares.

## 1. What changed since the last review

| Last review | Now |
|---|---|
| relations between datasets not defined → Gold 0 | relations defined first, documented, and checked by SQL (`docs/05_relations_and_lineage.md`) |
| part of the data generated | **100 % real, 0 % generated** |
| several Gold tables | **exactly one Gold table**, every server file contributes to it (checked automatically) |

## 2. Data

| Family | Source | Period | Grain |
|---|---|---|---|
| Weather (Saudi) | NOAA Global Hourly — 13 airport stations, one per region | 2021 – Aug 2025 | weather report (≈ hourly) |
| Weather (US analog) | NOAA Global Hourly — LAX, SFO, PHX, AUS | 2021 – Aug 2025 | weather report |
| Accidents (Saudi only) | GASTAT transport statistics (Ministerial Committee for Traffic Safety) | 2021–2025 | region × year |
| AV failures | California DMV disengagement + mileage reports | 2021–2024 | event / vehicle-month |
| AV crashes | NHTSA Standing General Order ADS reports (CA, AZ, TX) | 2021–2025 | crash |

## 3. Relations

```
Weather (SA) ──region_code + year──► Accidents (SA)              direct, both Saudi
Weather (SA) ──condition──► AV evidence (US)                       normal / rain / obscured (dust, haze, fog, <5 km), day / night
AV crashes   ──us_state──► US weather    (exposure)
AV disengagements ──date──► California weather, ──month──► fleet miles   (exposure)
```

Accidents and AV events are never joined row-to-row (different countries, different events): they meet in the Gold
row through the region's weather. Accident data stays Saudi-only; foreign data is used only for AV behaviour.

## 4. Gold

`gold.av_readiness_region_month` — one row per region per month (13 × 60 = 780). Columns: Saudi weather mix (20),
Saudi accidents (7), AV relative risks and two risk indices (7), keys and lineage. The ML step will produce the
readiness score per region and season from this table.

Your suggested comparison (accidents under bad vs good weather) is in `sql/04_analysis.sql` at region × year.

## 5. Result of the run

Bronze 1 066 423 rows from 107 files → Silver (with reject log and reconciliation) → Gold 780 rows.
32 quality checks, all PASS; the national accident totals equal GASTAT's published totals.

## 6. Question for you

The data-share rule (weather at most about half). Shares depend on how they are counted:

| Count by | Weather | Accidents | AV |
|---|---:|---:|---:|
| records feeding Gold | 84.8 % | 0.02 % | 15.2 % |
| Gold data columns | 58.8 % | 20.6 % | 20.6 % |

Accidents are small by records because GASTAT publishes totals (247 values that describe 86 734 serious accidents).
Which count should we use for the rule? If it must be met by records, we can aggregate weather to station-day before
Silver (≈ 28 700 rows) — at the cost of losing hour-level dust detail.

## 7. Limitations we will state in the paper

US AV data contains almost no dust (one crash), so dust enters only through the "obscured" group; exposure is weather
time, not AV miles; accidents are annual; Saudi weather ends Aug 2025; the result is an evidence-based estimate, not a
measurement.
