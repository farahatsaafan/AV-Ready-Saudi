# Review note for Dr. Omar Elzaki — AV-Ready-Saudi (Ali Ezzat, 29 Nov 2026)

Purpose: show what changed since the review of 24 Nov, why, and what the Gold table and the models now say.
Everything is still **100 % real data** (0 % generated, imputed or projected), and there is still **exactly one Gold
table** that all analysis and models are built on. Full design: [05_relations_and_lineage.md](05_relations_and_lineage.md);
diagrams: [07_erd.md](07_erd.md); results: [reports/04_eda_and_models.md](reports/04_eda_and_models.md).

## 1. What changed since 24 Nov, and why

| # | Problem found in the 24 Nov version | What we did |
|---|---|---|
| 1 | The AV weather risks came from pooled ratios that were **confounded**: a month's fleet miles were spread evenly over its days, but 98 % of disengagements happen Monday–Friday, and fleets and seasons move together. The "fog/haze 1.35, rain 0.79" ratios vanish when like is compared with like. | AV evidence is now a **stratified relative risk with a 95 % confidence interval** (Mantel–Haenszel): crashes compared within the same state and month, disengagements within the same month and weekday class. Cross-checked with regression models (statsmodels); both agree within 5 %. |
| 2 | Saudi "fog/haze" is not California fog: only 5.7 % of Saudi fog/haze hours carry a fog code, 64.5 % are haze codes, and the air is dry (median temperature–dew-point gap 5.6 °C). California's is moist fog (median gap 1.6 °C). A California fog ratio was being applied to Saudi dust haze. | The dew point (already in Bronze, never parsed) is now used: **dry haze** and **moist fog** are separate conditions, with the same rules for Saudi and US stations. |
| 3 | Gold had 7 AV columns with no variation (4 constants, 3 empty), and the two AV indices were exact linear functions of the weather shares, so any model on them would be circular. | Removed. Gold now carries AV measures that vary by row (share of hours outside the AV evidence, environment readiness, crash multiplier). A check fails if any Gold column is constant. |
| 4 | Accidents are annual, but GASTAT also publishes **monthly intercity traffic by region**, which we were not using. | Added: 13 regions × 60 months of real Saudi traffic in Gold (seasonality index). |
| 5 | 2023–2025 rates used the 2022 census, so populations were 7–17 % too low. | 2023–2025 now use **GASTAT's own denominator**, recovered from its published rates (count × 100 000 / rate). It reproduces GASTAT's other published rates within 0.035 %. |
| 6 | The hypothesis "weather causes more accidents" was not tested properly. | Tested at region-year level with group cross-validation and year-adjusted rank tests: **null result** (see §4). |
| 7 | Heat was listed as a gap. | Measured: 6.1 % of Saudi hours are ≥ 40 °C; Phoenix, where AV fleets run commercially, has 7.5 %. |
| 8 | The weather ↔ AV relation existed only as text inside SQL CASE statements, and some foreign keys were missing. | One vocabulary table, `silver.dim_condition`, one day-type function `silver.fn_day_type`, and **18 declared foreign keys** (all checked as trusted). ERD in `docs/07_erd.md`. |
| 9 | EDA had 3 queries without the Unit 5 OLAP operators; no ML code existed. | `sql/04_analysis.sql`: 9 queries with ROLLUP, CUBE, GROUPING SETS, GROUPING(), RANK, NTILE, LAG and written findings. `python/05_readiness_model.py`: readiness score, clustering, supervised test, sensitivity. |

## 2. Data (all real)

| Family | Source | Period | Grain | Origin |
|---|---|---|---|---|
| Weather | NOAA Global Hourly — 13 Saudi airport stations + LAX, SFO, PHX, AUS | 2021 – Aug 2025 | weather report | Saudi + US |
| Accidents | GASTAT transport statistics | 2021–2025 | region × year | Saudi |
| Traffic | GASTAT monthly intercity traffic | 2021–2025 | region × month | Saudi |
| Population | GASTAT Census 2022 table + GASTAT rate denominators | 2021–2025 | region × year | Saudi |
| Roads, region service | GASTAT road network; ambulance response time and registered vehicles | 2022–2025; 2025 | region × year; region | Saudi |
| AV failures and exposure | California DMV disengagements + fleet mileage | Dec 2020 – Nov 2024 | event; vehicle-month | US |
| AV crashes | NHTSA Standing General Order ADS reports (CA, AZ, TX) | 2021–2025 | crash | US |

The new Saudi variables (traffic, rate denominators, region service) are new sheets of workbooks that were already in
Bronze: no new files were added.

## 3. Gold: `gold.av_readiness_region_month` (13 regions × 60 months = 780 rows)

Saudi weather mix (normal / rain / moist fog / dry haze / dust shares, heat, dew point, day types), monthly traffic,
accidents and rates per 100,000 (same-year population), roads, region service, and the AV-derived measures:

```
env_readiness      = share of hours inside the US AV evidence: dust weight 0 (no US AV data), rain weight 1/1.52, others 1
env_readiness_cons = the same, with Saudi dry haze also weight 0
```

**AV evidence behind it** (stratified, 95 % CI; used only if it comes from crashes, has ≥ 30 events and CI > 1):

| Source | Condition | Events | Crude ratio | Adjusted ratio [95 % CI] | Used |
|---|---|---:|---:|---|---|
| NHTSA crashes | rain | 70 | 1.40 | 1.52 [1.14, 2.00] | yes |
| NHTSA crashes | fog / smoke / haze | 2 | 0.02 | 0.02 [0.006, 0.10] | no — implausible, artefact |
| NHTSA crashes | dust | 0 | — | — | no — uncovered |
| DMV disengagements | rain days | 4 916 | 0.78 | 1.04 [0.95, 1.15] | no |
| DMV disengagements | moist fog days | 12 093 | 1.21 | 0.97 [0.91, 1.04] | no |
| DMV disengagements | dry haze days | 5 954 | 1.65 | 1.13 [1.03, 1.23] | no — take-over signal, reported only |

## 4. What the data says

- **Environment.** Over complete months, environment readiness averages 0.964 (0.952 conservatively): dust is 3.4 % of
  hours and dry haze 1.2 %. The weakest region-seasons are Jazan in summer (dust + dry haze), and Najran, Riyadh, Qassim
  and the Eastern Province in spring (dust). Hail ranks first in summer and autumn, Aseer in winter and spring.
- **Your comparison of good vs bad weather years** (query E8, rates adjusted for the national rate of each year):
  10 of 13 regions look worse in their most obscured year, but that year is 2022 for 12 of the 13 regions. Once the year
  itself is taken out, the association disappears (rank correlation 0.06, p 0.68). Weather → accidents is a **null result**
  with this data, and no model predicts a region it has not seen better than the average. This is why the readiness score
  uses the AV evidence, the region's safety record and its infrastructure, and not a weather → accident model.
- **Readiness score, clusters and sensitivity:** [reports/04_eda_and_models.md](reports/04_eda_and_models.md).

## 5. Checks (run of 28 Nov 2026)

67 quality checks, all PASS (Bronze 11 · Silver 35 · Gold 20 · rollback 1). The SQL Gold equals the independent pandas
rebuild on all 780 rows and 64 columns; the regression cross-check agrees with the SQL relative risks; national accident
totals equal GASTAT's published totals; traffic totals equal GASTAT's national row.

## 6. Limitations we will state in the paper

Dust has no US AV evidence (treated as uncovered, not as measured risk); Saudi dry haze is mineral dust, California's is
mostly smoke (hence the conservative variant); DMV reports have no location and NHTSA has month-level dates; crash
exposure is weather time, not AV miles; accidents are annual; GASTAT revised its 2024 rates in the 2025 workbook; Saudi
weather ends in August 2025; one station per region; association is not causation.
