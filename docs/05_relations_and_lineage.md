# AV-Ready-Saudi — Relations, Lineage and Data Shares

Status: design v2 of 28 Nov 2026 (branch `dev-ali-ezzat`). Replaces the 24 Nov design (fog/haze vocabulary,
pooled AV ratios, constant AV columns in Gold) and the earlier design that used generated telemetry.
All data is **real** (0 % generated, imputed or projected). Entity-relationship diagram: [07_erd.md](07_erd.md).

## 1. Question and output

**Question.** How ready is each Saudi region, by season, for autonomous vehicles (AVs)?

**Output.** One Gold table, `gold.av_readiness_region_month` — one row per Saudi administrative region per calendar
month, 2021–2025 (13 × 60 = 780 rows). Everything else (EDA in `sql/04_analysis.sql`, the readiness score,
clustering and the supervised test in `python/05_readiness_model.py`) is computed from that table only.

The result is an **evidence-based estimate**, not a measurement: no AVs drive in Saudi Arabia yet, so AV behaviour is
taken from US records and transferred through the weather conditions both places share. A Saudi region-month is as
ready as the share of its hours that fall inside the US AV evidence, penalised only by risks that the US crash data
shows with confidence.

## 2. Sources

| # | Family | Source | Period | Grain | Origin | Role |
|---|---|---|---|---|---|---|
| 1 | Weather | NOAA NCEI Global Hourly (ISD) — 13 Saudi airport stations, one per region | Jan 2021 – 25 Aug 2025 | one weather report (≈ hourly) | Saudi (observed in KSA, archived by NOAA) | condition mix of each region-month (incl. dew point and heat) |
| 2 | Weather | NOAA NCEI Global Hourly — LAX, SFO (CA), PHX (AZ), AUS (TX) | same | one weather report | US | exposure: how often each condition occurs where the AV events happen |
| 3 | Accidents | GASTAT Land / Road Transport Statistics workbooks 2022, 2023, 2024, 2025 | 2021–2025 | region × year | Saudi | serious accidents, deaths, injuries, within / outside cities |
| 4 | Traffic | same GASTAT workbooks: monthly intercity traffic by region | 2021–2025, every month | region × month | Saudi | the only Saudi *monthly* road variable (seasonality of travel) |
| 5 | Population | GASTAT Census 2022 table (2010–2022) + GASTAT's own denominator recovered from its published rates (2023–2025) | 2021–2025 used | region × year | Saudi | denominator of rates per 100,000 |
| 6 | Roads | same GASTAT workbooks: density per person / per km², intercity length by road type | 2022–2025 | region × year | Saudi | infrastructure |
| 7 | Region service | GASTAT 2025: ambulance response time within / outside cities, registered vehicles | 2025 | region | Saudi | infrastructure / emergency response |
| 8 | AV failures | California DMV AV disengagement reports (drivered, driverless, first-time filers) | Dec 2020 – Nov 2024 | one disengagement | US | events |
| 9 | AV exposure | California DMV AV mileage reports | Dec 2020 – Nov 2024 | vehicle × month | US | fleet miles |
| 10 | AV crashes | NHTSA Standing General Order — ADS incident reports (archive + current file) | 2021–2025 used | one crash | US | events with structured weather / lighting |

Sources 4, 5 (2023–2025) and 7 are **new sheets of the workbooks already in Bronze** (no new files, no downloads).
Every link: [DATA_SOURCES.md](DATA_SOURCES.md) · register: [data_source_register.csv](data_source_register.csv).

## 3. Relations

All relations are declared as **foreign keys** (18, checked "enabled and trusted" by `sql/quality/03_gold_checks.sql`):
`silver.dim_region` → every regional table and Gold; `silver.dim_station` → `weather_obs`, the prep hour/day/month
tables and Gold; `silver.dim_condition` → `nhtsa_crash.weather_bucket`, `prep.weather_station_hour.hour_bucket`,
`prep.weather_station_day.day_type`, `prep.av_relative_risk.condition_code`. Diagram: [07_erd.md](07_erd.md).

| Relation | Join key | Kind |
|---|---|---|
| Weather ↔ Accidents | `region_code` + `year` | both Saudi and observed; accidents are annual, so the 12 months of a year carry the same values |
| Traffic ↔ Gold | `region_code` + `month_start` | monthly, Saudi |
| Population / Roads ↔ Accidents | `region_code` + `year` | rates per 100,000; road context |
| Region service ↔ Gold | `region_code` | 2025 attributes, same on every row of the region |
| Weather ↔ AV events | **`silver.dim_condition`** (condition vocabulary v2) | Saudi hours, US hours, California days and NHTSA crash categories all carry a `condition_code` FK |
| AV crashes ↔ US weather | `us_state` + incident month (CA → LAX+SFO, AZ → PHX, TX → AUS) | stratum of the Mantel–Haenszel ratio |
| AV disengagements ↔ CA weather ↔ mileage | date (CA day type) + month (fleet miles) and weekday class | stratum of the Mantel–Haenszel ratio |

Accidents and AV events are **not** joined row to row — they are different events in different countries. They meet
in Gold through the condition vocabulary on the same region-month row.

## 4. Rules

### 4.1 Weather report → flags (Silver, `silver.weather_obs`)

WMO present-weather codes from manual (`MW1`, WMO 4677) and automated (`AW1`, WMO 4680) reports and the METAR-style
group `AU1`; the exact rules are stored in `silver.dim_condition.rule_text`.

| Flag | Rule |
|---|---|
| dust | MW 06–09 or 30–35; AU1 obscuration DU / SA; AU1 other dust/sand whirls, sandstorm, duststorm |
| haze / smoke | MW 04–05; AW 04–05; AU1 obscuration FU / HZ |
| fog | MW 40–49; AW 30–35; AU1 obscuration FG |
| rain | MW 50–69 or 80–99; AW 40–69 or 80–89; AU1 precipitation DZ / RA / UP; measured 1-hour precipitation > 0 |
| low visibility | visibility < 5 000 m (quality codes 2/3/6/7 discarded) |
| night | solar elevation < −0.833° (NOAA solar-position equations) |
| dew point | `DEW` parsed exactly like `TMP`; `dew_spread_c = temp_c − dew_c` |
| heat | `is_hot40` temp ≥ 40 °C, `is_hot45` temp ≥ 45 °C |

### 4.2 Condition vocabulary v2 (hour level, identical rules for Saudi and US stations)

Obscured hour = dust OR haze OR fog OR visibility < 5 km. Priority **dust › haze_dry › fog_moist › rain › normal**:

| Condition | Rule | US AV coverage |
|---|---|---|
| `dust` | a dust / sand code in the hour | **uncovered** (no US AV evidence) |
| `haze_dry` | obscured, no dust, not fog_moist (dry air) | covered |
| `fog_moist` | obscured, no dust, and a fog code **or** min(temp − dew point) in the hour ≤ 2.5 °C | covered |
| `rain` | precipitation reported and the hour is not obscured | covered |
| `normal` | none of the above | reference |

**Why split fog/haze by dew point.** Saudi "fog/haze" is not California fog. Of the 8 672 Saudi obscured hours without
dust, only 5.7 % carry a fog code and 64.5 % a haze code; the median temperature–dew-point spread is 5.6 °C (> 5 °C in
50.7 %), i.e. dry air: mineral dust haze. California's (LAX + SFO) are 68.7 % moist (spread ≤ 2.5 °C, median 1.6 °C).
Jazan's are 0 % fog code, 94.8 % haze, 71 % with spread > 5 °C. Applying a California fog ratio to Saudi dust haze is
what put Jazan and the Eastern Province on top of the old risk index.

Result, 2021–2025 station-hours: Saudi (13 stations) dust 3.49 %, haze_dry 1.16 %, fog_moist 0.51 %, rain 0.51 %,
normal 94.34 %; California (LAX + SFO) fog_moist 4.01 %, haze_dry 1.61 %, rain 2.75 %, dust 0.00 %.
Hours ≥ 40 °C: Saudi 6.1 %, Phoenix 7.5 % (where AV fleets run commercially), California 0 %.

**Day type** (`silver.fn_day_type`, the only implementation, used for Saudi days and California days): if
dust + haze_dry + fog_moist hours ≥ 3 → the largest of the three (ties: dust › haze_dry › fog_moist); else `rain` if
≥ 1 rain hour; else `normal`. A California day takes the maximum hours of each kind over LAX and SFO.

**NHTSA categories.** NHTSA has one "Fog/Smoke/Haze" box, so it maps to `obscured_unspecified` (its US exposure is
fog_moist + haze_dry hours); Dust Storm → `dust`; Rain or Snow → `rain`; Clear / Cloudy / Partly Cloudy / Severe Wind →
`normal`; otherwise `unknown` (excluded).

### 4.3 AV evidence (`prep.av_relative_risk`): stratified relative risks

The pooled ratios of the 24 Nov design were confounded: a month's fleet miles were spread evenly over its days, but
98 % of disengagements happen Monday–Friday, and fleets and seasons move together. v2 compares like with like:

```
Mantel-Haenszel rate ratio of condition c vs normal over strata s (T = person-time):
  RR_MH = Σ_s e_c,s · T_n,s / T_s  ÷  Σ_s e_n,s · T_c,s / T_s ,   T_s = T_c,s + T_n,s
  Var(ln RR_MH) = Σ_s (e_c,s + e_n,s) · T_c,s · T_n,s / T_s²  ÷  [ (Σ e_c,s T_n,s / T_s) · (Σ e_n,s T_c,s / T_s) ]
  95 % CI = exp(ln RR ± 1.96 · √(Var · max(1, φ)))     φ = Pearson χ² / df of the fitted stratified model
NHTSA:  in-scope crashes (CA/AZ/TX, 2021-2025, weather known); strata = state × incident month with >= 1 crash;
        T = station-hours of the state (CA = LAX + SFO)
DMV:    one row per California date in months with fleet miles > 0; T of a day = month fleet miles / days in month
        (this is how mileage contributes); events = disengagements that date; strata = month × weekday class
```

φ (overdispersion) is ≈ 0.5 for NHTSA (no correction) and ≈ 8.9 for DMV (one day of one fleet can carry dozens of
disengagements; a plain Poisson CI would be three times too narrow).

**Evidence rule** (agreed with Ali, 27 Nov 2026). A ratio is applied in Gold only if it comes from **AV crashes** (a
safety outcome), has **≥ 30 events** and its **95 % CI lower bound > 1**. A ratio < 1 for an adverse condition is never
used. A significant **disengagement** ratio is reported, not applied: a disengagement is a precautionary take-over,
42 % of them come from one company (MAY MOBILITY) and 81.5 % from three. Conditions with no US events (dust) are
**uncovered**.

The same ratios are re-estimated with GLMs in `python/04_av_evidence_models.py` (statsmodels): Poisson with the same
strata as fixed effects must agree with MH within ±10 % (it does: 0.7–4.9 %); Negative Binomial with month and
day-of-week fixed effects, per manufacturer and with SFO-only / LAX-only day types are robustness checks; a hold-out year
tests whether weather improves the prediction of disengagements (it does not).

### 4.4 Gold measures

```
av_uncovered_share      = share_dust_hours
av_uncovered_share_cons = share_dust_hours + share_haze_dry_hours
av_crash_multiplier     = 1 + Σ_{used c} share_c · (RR_c − 1)                  (today: rain only)
env_readiness           = Σ_c share_c · w_c,  w_dust = 0, w_c = 1/RR_c for used c, w_c = 1 for other covered c
env_readiness_cons      = env_readiness with w_haze_dry = 0   (Saudi dry haze is mineral dust; California's is mostly smoke)
```

Computed from hour counts (exact), not from the rounded shares.

### 4.5 Traffic and population

**Traffic** (`silver.traffic_region_month`, 13 × 60 = 780 rows, 0 rejects). 2021–2022: `Land_Transport_Statistics_2022`
sheet 14, average daily Car + Truck per count point by month (header "Ryiadh" mapped through `region_alias`).
2023–2025: sheets 29 / 3-5 / 3-3-1, month total ÷ count points ÷ days in month. Levels of the two definitions are not
comparable, so `traffic_month_index` = month ÷ mean of the region's 12 months of that year is. 2023 regional totals add
up to GASTAT's national total row (0.000 % difference).

**Population** (`silver.population_region_year`, 208 rows). 2010–2022: census table (`census_2022_table`). 2023–2025:
GASTAT's own denominator recovered from its published rate (`gastat_rate_implied`):
2023 = deaths × 100 000 / mortality rate (2023 sheet 35); 2024 and 2025 = serious accidents × 100 000 / serious-accident
rate (2024 sheet 5-4, 2025 sheet 5-7). Rounded to integers; arithmetic on official numbers, no projection. Check: the
2024 and 2025 mortality rates (not used to build them) are reproduced within 0.035 %. Examples: Riyadh 2023 9 085 342,
2024 9 541 926, 2025 10 090 438; Makkah 2025 9 180 888; Al-Baha 2025 374 010. Caveat: the 2025 workbook revises the 2024
rates (e.g. Riyadh mortality 9.99 → 9.49); each year uses its own publication.

## 5. Lineage (Gold column → Silver / prep → Bronze → raw)

| Gold columns | Silver / prep | Bronze | Raw files |
|---|---|---|---|
| `wx_*`, `temp_*`, `wind_max_ms`, `mean_dew_spread_c`, `share_*_hours`, `*_days` | `weather_obs` → `prep.weather_station_hour` → `_day` (fn_day_type) → `prep.saudi_region_month` | `noaa_hourly` (13 SA stations) | `noaa_global_hourly/<year>/<station>.csv` |
| `traffic_*` | `traffic_region_month` (via `gastat_traffic_map`, `region_alias`) | `gastat_cells` | `gastat/*.xlsx` sheets 14 / 29 / 3-5 / 3-3-1 |
| `acc_year_*`, `acc_share_outside_cities` | `accidents_region_year` (via `gastat_sheet_map`) | `gastat_cells` | sheets 17, 20 / 34, 37 / 5-1, 5-5 / 5-1-1, 5-6-1 |
| `population`, `population_basis`, `acc_*_per_100k` | `population_region_year` + `accidents_region_year` | `gastat_population`, `gastat_cells` | `gastat_population/*.csv`; rate sheets 35 / 5-4 / 5-7 (and 5-2 cross-check) |
| `road_*`, `intercity_*` | `roads_region_year` | `gastat_cells` | sheets 12 / 20 / 7-5 / 7-2 and 7 / 15 / 7-2 / 7-1-2 |
| `response_*`, `registered_vehicles_2025` | `region_service_2025` | `gastat_cells` | 2025 sheets 5-11, 4-1-2 |
| `av_crash_multiplier`, `env_readiness*` | `nhtsa_crash` + US station-hours → `prep.av_relative_risk` (NHTSA rows) | `nhtsa_sgo_ads`, `noaa_hourly` (US) | `nhtsa_sgo/*.csv` |
| evidence behind the weights (DMV rows of `prep.av_relative_risk`) | `dmv_disengagement` + `dmv_mileage_monthly` + CA day types | `dmv_disengagements`, `dmv_mileage`, `noaa_hourly` | `ca_dmv_*/*.csv` |
| `av_uncovered_share*` | `prep.saudi_region_month` + `dim_condition.us_av_coverage` | `noaa_hourly` | — |
| `region_*`, `weather_station_id` | `dim_region`, `dim_station` | — | reference data in `02_silver.sql` |

`sql/quality/03_gold_checks.sql` fails if any source family does not reach Gold.

## 6. Data shares (run of 28 Nov 2026)

**View 1 — real vs generated:** 1 086 572 records, **100 % real, 0 % generated / imputed / projected.**

**View 2 — records per source family (what feeds Gold):**

| Family | Records | Share |
|---|---:|---:|
| Weather – Saudi stations (reports) | 695 617 | 64.02 % |
| Weather – US analog stations (reports) | 224 510 | 20.66 % |
| AV – DMV mileage (vehicle-months) | 113 900 | 10.48 % |
| AV – DMV disengagements | 49 066 | 4.52 % |
| AV – NHTSA crashes (CA/AZ/TX) | 1 893 | 0.17 % |
| Traffic – GASTAT region-month values | 780 | 0.07 % |
| Roads – GASTAT region-year values | 312 | 0.03 % |
| Accidents – GASTAT region-year values | 247 | 0.02 % |
| Population – GASTAT region-year values | 208 | 0.02 % |
| Region service – GASTAT 2025 values | 39 | 0.00 % |

GASTAT publishes totals, so accidents look tiny by records: the 247 values describe **86 734 serious accidents and
22 360 deaths** (2021–2025).

**View 3 — Gold data columns that vary (49 numeric columns, complete months):** weather 25 (51.0 %), accidents 9
(18.4 %), AV evidence 5 (10.2 %), roads 4 (8.2 %), region service 3 (6.1 %), traffic 2 (4.1 %), population 1 (2.0 %).
No Gold column is constant (checked).

## 7. AV evidence found (run of 28 Nov 2026)

| Source | Condition | Events | Crude | Adjusted (MH) | 95 % CI | Used |
|---|---|---:|---:|---:|---|---|
| NHTSA crashes | rain | 70 | 1.40 | **1.52** | [1.14, 2.00] | **yes** |
| NHTSA crashes | obscured_unspecified | 2 | 0.02 | 0.02 | [0.006, 0.10] | no — implausible protective, artefact |
| NHTSA crashes | dust | 0 | — | — | — | no — no events, uncovered |
| NHTSA crashes | night (light) | 741 | 0.64 | 0.64 | [0.57, 0.71] | no — exposure is darkness hours, not AV miles |
| DMV disengagements | rain days | 4 916 | 0.78 | 1.04 | [0.95, 1.15] | no — no detectable penalty |
| DMV disengagements | fog_moist days | 12 093 | 1.21 | 0.97 | [0.91, 1.04] | no — no detectable penalty |
| DMV disengagements | haze_dry days | 5 954 | 1.65 | 1.13 | [1.03, 1.23] | no — take-over signal, reported, not a crash weight |
| DMV disengagements | dust days | 0 | — | — | — | no — no dust days in California |

The crude DMV ratios (fog/haze 1.35 combined, rain 0.78) were confounding: with month and weekday strata they move to
≈ 1. NB GLM with month + day-of-week fixed effects: rain 0.94 [0.82, 1.09], fog_moist 0.87 [0.77, 0.98], haze_dry 1.06
[0.90, 1.23]. Forest plot: `docs/figures/rr_crude_vs_adjusted.png`.

## 8. Limitations (to state in the paper)

1. **Dust is uncovered.** Saudi dust exposure is measured (3.49 % of hours; Najran 7.8 %, Riyadh 6.3 %), but the US AV
   data has no dust events (0 NHTSA crashes, 0 California dust days). It gets weight 0 in `env_readiness`, i.e. it is
   treated as outside the evidence, not as a measured risk.
2. **Saudi dry haze ≠ California smoke.** Both are `haze_dry` by the dew-point rule; the conservative variant
   (`env_readiness_cons`) gives Saudi dry haze weight 0.
3. **DMV has no location**; California weather is taken as the worse of LAX and SFO.
4. **NHTSA has month-level dates**, and its exposure is station-hours of the state, not AV miles. 17 of the 70 rain
   crashes fall in state-months where the reference station logged no rain hour (the station is not the crash place):
   MH keeps them (1.52), a Poisson GLM drops them (1.48).
5. **Accidents are annual.** Monthly rows repeat them: aggregate with MAX / one row per region-year (65 rows).
6. **Heat** is covered by Phoenix operations (7.5 % of hours ≥ 40 °C) but there is no event-level heat evidence.
7. **2024 rate revision** in the 2025 workbook; each year uses its own publication.
8. **Weather 2025** ends on 25 Aug 2025 (Aug 2025 below 80 % coverage; Sep–Dec 2025 without weather: 65 region-months
   excluded by `wx_complete`).
9. **One station per region** (the main airport). **Roads** start in 2022; the within/outside-city split starts in 2024.
   **Traffic** count stations can be added, moved or removed during a year (GASTAT's own note), so traffic levels are
   compared within a region-year through `traffic_month_index`, not across years.
10. **Association, not causation.** Weather → accidents at region-year level is a null result with this data
    (report 04).

## 9. Expected counts after a run (`python/02_reference_gold.py`, equal to the SQL run)

| Table | Rows |
|---|---:|
| bronze.noaa_hourly | 927 141 |
| bronze.gastat_cells | 76 588 |
| bronze.dmv_disengagements | 49 124 |
| bronze.dmv_mileage | 9 483 |
| bronze.nhtsa_sgo_ads | 4 087 |
| bronze.gastat_population | 676 |
| silver.weather_obs | 920 127 |
| silver.accidents_region_year | 65 |
| silver.roads_region_year | 52 |
| silver.population_region_year | 208 |
| silver.traffic_region_month | 780 |
| silver.region_service_2025 | 13 |
| silver.dmv_disengagement | 49 066 |
| silver.dmv_mileage_monthly | 113 900 |
| silver.nhtsa_crash | 3 244 (1 893 in scope) |
| prep.weather_station_hour | 682 398 |
| prep.weather_station_day | 28 744 |
| prep.av_relative_risk | 11 |
| gold.av_readiness_region_month | 780 |

The pipeline exports Gold to `Data/gold_export/` and compares it with the reference column by column
(`python/02_reference_gold.py --compare`): 780 rows, 64 columns, PASS on 28 Nov 2026.
