# Gold Layer Report — AV-Ready-Saudi

Run: 28 Nov 2026 (design v2) · script `sql/03_gold.sql` · procedure `gold.load_gold`.

## 1. The single Gold table

`gold.av_readiness_region_month` — **grain: one Saudi administrative region × one calendar month, 2021–2025**
(13 × 60 = **780 rows**, key `region_code + month_start`, FKs to `dim_region` and `dim_station`). Schema `gold` holds only
this table (checked). Work tables used to build it live in schema `prep`.

| Column group | Columns | From |
|---|---:|---|
| keys and labels | 8 | `dim_region`, `dim_station`, calendar |
| Saudi weather | 26 | NOAA hourly → station-hour (v2 vocabulary) → region-month: coverage, `wx_complete`, temperature, wind, dew-point spread, 5 v2 shares (sum 1), 6 raw-flag shares (haze, fog, low visibility, night, ≥ 40 °C, ≥ 45 °C), 7 day counts |
| Saudi traffic | 3 | GASTAT monthly intercity traffic (`traffic_adt_per_point`, `traffic_definition`, `traffic_month_index`) |
| Saudi accidents | 9 | GASTAT region-year (counts, outside-city share, rates per 100,000) |
| Saudi population | 2 | same-year population and its basis (census table / GASTAT rate-implied) |
| Saudi road network | 4 | GASTAT road tables, region-year (2022–2025) |
| region service | 3 | GASTAT 2025 response times and registered vehicles |
| AV-derived | 5 | `av_uncovered_share`, `av_uncovered_share_cons`, `av_crash_multiplier`, `env_readiness`, `env_readiness_cons` |
| lineage | 6 | source text (weather, accidents, traffic, AV), batch id, load time |

Removed in v2 (no variance or circular): the 7 `av_rr_*` columns, `av_crash_risk_index`, `av_diseng_risk_index`,
`share_fog_haze_hours`, `share_obscured_hours`, `fog_haze_days`, `obscured_days`, and `rain_mm` (the Saudi stations
publish no 1-hour precipitation totals, so it was 0 on every row). Column definitions: `docs/02_data_dictionary.md`.

## 2. How the sources meet (relations)

| Relation | Key |
|---|---|
| weather ↔ accidents | `region_code` + `year` |
| traffic ↔ Gold | `region_code` + `month_start` |
| roads, population ↔ accidents | `region_code` + `year` (population: same year for every year) |
| region service ↔ Gold | `region_code` |
| weather ↔ AV events | `silver.dim_condition` (FK on hour buckets, day types, NHTSA categories, relative-risk rows) |
| AV crashes ↔ US weather | state × incident month (CA → LAX + SFO, AZ → PHX, TX → AUS) |
| AV disengagements ↔ CA weather ↔ mileage | date ↔ California day type, month × weekday class, month ↔ fleet miles |

Diagram: `docs/07_erd.md`; rules and full lineage: `docs/05_relations_and_lineage.md`.

## 3. Build steps

1. `prep.weather_station_hour` (682 398 rows) — several reports per hour → one hour; v2 bucket
   dust › haze_dry › fog_moist › rain › normal, using the smallest temperature–dew-point spread of the hour.
2. `prep.weather_station_day` (28 744) — hours per bucket, day type from `silver.fn_day_type`.
3. `prep.saudi_region_month` (728) — hours and days per condition, heat hours, dew spread, per Saudi station-month.
4. `prep.av_relative_risk` (11) — Mantel–Haenszel relative risk of each condition vs normal (NHTSA: strata state ×
   incident month, exposure station-hours; DMV: strata month × weekday class, exposure fleet miles), 95 % CI widened by
   the overdispersion factor, evidence rule (crash ratio, ≥ 30 events, CI lower bound > 1).
5. Gold — calendar of 780 region-months joined to (3), traffic (region + month), accidents, roads and population
   (region + year), region service (region) and the used ratios.

## 4. AV evidence (prep.av_relative_risk)

| Source | Condition | Events | Crude | Adjusted [95 % CI] | Dispersion | Used | Note |
|---|---|---:|---:|---|---:|---|---|
| NHTSA crash | rain | 70 | 1.400 | 1.515 [1.145, 2.005] | 0.48 | **yes** | significant penalty - used |
| NHTSA crash | obscured_unspecified | 2 | 0.023 | 0.024 [0.006, 0.098] | 0.48 | no | implausible protective - artefact |
| NHTSA crash | dust | 0 | 0.000 | — | 0.48 | no | no events - uncovered |
| NHTSA crash | night (light) | 741 | 0.645 | 0.638 [0.571, 0.712] | 1.17 | no | exposure is darkness hours, not AV miles |
| DMV disengagement | rain days | 4 916 | 0.777 | 1.044 [0.945, 1.153] | 8.87 | no | no detectable penalty |
| DMV disengagement | fog_moist days | 12 093 | 1.210 | 0.973 [0.907, 1.044] | 8.87 | no | no detectable penalty |
| DMV disengagement | haze_dry days | 5 954 | 1.651 | 1.126 [1.030, 1.230] | 8.87 | no | take-over signal, reported, not a crash weight |
| DMV disengagement | dust days | 0 | — | — | 8.87 | no | no events - uncovered |

The crude DMV ratios move to ≈ 1 once month and weekday are held fixed: they were confounding (forest plot
`docs/figures/rr_crude_vs_adjusted.png`; GLM cross-check in `python/04_av_evidence_models.py`).

## 5. Gold measures

```
av_uncovered_share      = share_dust_hours                         (no US AV evidence)
av_uncovered_share_cons = share_dust_hours + share_haze_dry_hours
av_crash_multiplier     = 1 + share_rain · (1.515 − 1)              (only the used ratio)
env_readiness           = share_normal + share_fog_moist + share_haze_dry + share_rain / 1.515     (dust weight 0)
env_readiness_cons      = share_normal + share_fog_moist + share_rain / 1.515                      (dry haze weight 0 too)
```

## 6. First results (715 complete region-months)

| Measure | Mean | Min | Max |
|---|---:|---:|---:|
| share of dust hours | 3.44 % | 0 % | 39.9 % |
| share of dry-haze hours | 1.15 % | 0 % | 20.7 % |
| share of moist-fog hours | 0.51 % | 0 % | 16.4 % |
| share of rain hours | 0.51 % | 0 % | 6.6 % |
| share of hours ≥ 40 °C | 5.8 % | 0 % | 56.3 % |
| monthly max temperature | 36.6 °C | 20.0 °C | 50.0 °C |
| `env_readiness` | 0.964 | 0.601 | 1.000 |
| `env_readiness_cons` | 0.952 | 0.601 | 1.000 |
| `av_crash_multiplier` | 1.003 | 1.000 | 1.034 |
| `traffic_month_index` | 0.99 | 0.38 | 2.21 |

Environment readiness (conservative, region mean): Jazan 0.886 · Najran 0.914 · Eastern 0.919 · Riyadh 0.928 ·
Qassim 0.955 · … · Tabuk 0.979 · Hail 0.983. Jazan loses mostly to summer dust and dry haze; Najran, Riyadh, Qassim and
the Eastern Province to spring dust. The crash multiplier barely moves because rain, the only evidence-backed penalty,
is rare in Saudi Arabia.

Serious accidents per 100,000 people (region mean 2021–2025, same-year population): Al-Baha 97.4 · Madinah 80.3 ·
Makkah 69.6 · Jazan 56.2 · … · Najran 35.5 · Eastern 31.4 · Al-Jouf 28.6. In absolute counts Makkah and Riyadh lead; per
person, Al-Baha is highest — the reason the rates are in Gold.

EDA on this table: `sql/04_analysis.sql`; models and evaluation: `docs/reports/04_eda_and_models.md`.

## 7. Checks (`sql/quality/03_gold_checks.sql`) — 20 checks, all PASS

One table in `gold` · 780 rows · unique key · 18 foreign keys enabled and trusted · every condition in `dim_condition` ·
v2 shares sum to 1 on all 715 complete rows · `env_readiness` and `_cons` in [0, 1] · 715 complete months · **no
constant numeric column (0 of 49)** · Saudi weather in all 13 regions · US weather used as exposure · accidents,
traffic, population, region service in all 780 rows · roads in the 624 rows of 2022–2025 · 468 rate-implied
population rows · all 4 GASTAT workbooks used · NHTSA reaches Gold through a used ratio (267 distinct multipliers) ·
DMV evidence rows with notes. The exported SQL Gold equals the pandas reference on all 780 rows × 64 columns.

## 8. Data shares (three views)

1. **Real vs generated:** 100 % real (1 086 572 records), 0 % generated / imputed / projected.
2. **Records per source family:** weather 84.7 % (Saudi 64.0 %, US 20.7 %), AV 15.2 % (DMV mileage 10.5 %,
   disengagements 4.5 %, NHTSA 0.2 %), Saudi GASTAT tables 0.15 % (traffic 780, roads 312, accidents 247, population 208,
   service 39 values; the 247 accident values describe 86 734 serious accidents and 22 360 deaths).
3. **Gold data columns that vary, per family (49):** weather 25 (51.0 %), accidents 9 (18.4 %), AV evidence 5 (10.2 %),
   roads 4 (8.2 %), region service 3 (6.1 %), traffic 2 (4.1 %), population 1 (2.0 %).

## 9. Known gaps

65 region-months have no usable weather (`wx_complete` = 0): Aug 2025 for all 13 regions (77 % coverage, the NOAA files
end on 25 Aug 2025) and Sep–Dec 2025 (no files). Accidents, roads and population are annual (same value on the 12 months
of a year, not additive over months); road tables start in 2022; the within/outside-cities split starts in 2024; region
service is 2025 only.
