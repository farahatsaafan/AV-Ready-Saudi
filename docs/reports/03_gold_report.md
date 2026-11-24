# Gold Layer Report — AV-Ready-Saudi

Run: 24 Nov 2026 · script `sql/03_gold.sql` · procedure `gold.load_gold`.

## 1. The single Gold table

`gold.av_readiness_region_month` — **grain: one Saudi administrative region × one calendar month, 2021–2025**
(13 × 60 = **780 rows**, key `region_code + month_start`). Schema `gold` holds only this table (checked).
Work tables used to build it live in schema `prep`.

| Column group | Columns | From |
|---|---:|---|
| keys and labels | 8 | `dim_region`, `dim_station`, calendar |
| Saudi weather | 20 | NOAA hourly → station-hour → region-month |
| Saudi accidents | 7 | GASTAT region-year |
| AV evidence | 7 | NHTSA crashes, DMV disengagements + mileage, US analog weather |
| lineage | 5 | source text, batch id, load time |

Column definitions: `docs/02_data_dictionary.md`.

## 2. How the sources meet (relations)

| Relation | Key |
|---|---|
| weather ↔ accidents | `region_code` + `year` |
| weather ↔ AV events | condition vocabulary: normal / rain / obscured (dust, haze, fog, < 5 km), day / night |
| AV crashes ↔ US weather | `us_state` (CA → LAX + SFO, AZ → PHX, TX → AUS) |
| AV disengagements ↔ CA weather ↔ mileage | event date ↔ California day type; month ↔ fleet miles |

Diagram, rules and full lineage: `docs/05_relations_and_lineage.md`.

## 3. Build steps

1. `prep.weather_station_hour` — several reports per hour → one hour; hour bucket obscured › rain › normal.
2. `prep.weather_station_day` — day type: obscured (≥ 3 obscured hours) › rain (≥ 1 rain hour) › normal.
3. `prep.saudi_region_month` — hours and days per condition for each Saudi station-month.
4. `prep.av_relative_risk` — relative risk of an AV event in each condition vs the normal condition
   (exposure = US station-hours weighted by crash state for crashes; fleet miles on CA days for disengagements);
   evidence rule: used only if ≥ 30 events.
5. Gold — calendar of 780 region-months, joined to (3), to accidents by region + year, and to the risks.

## 4. Relative risks (prep.av_relative_risk)

| Source | Level | Events | Event share | Exposure share | Relative risk | Used |
|---|---|---:|---:|---:|---:|---|
| NHTSA crash | rain | 70 | 3.73 % | 2.58 % | 1.40 | yes |
| NHTSA crash | obscured | 2 | 0.11 % | 4.49 % | 0.02 | no (< 30) |
| NHTSA crash | night | 741 | 39.1 % | 49.9 % | 0.64 | stored, not in index |
| DMV disengagement | rain days | 5 216 | 10.6 % | 14.1 % | 0.81 | yes |
| DMV disengagement | obscured days | 17 848 | 36.4 % | 29.2 % | 1.34 | yes |

## 5. Indices

```
av_crash_risk_index  = share_normal + share_rain · RR_crash(rain) + share_obscured · RR_crash(obscured)
av_diseng_risk_index = normal_days/days + rain_days/days · RR_diseng(rain) + obscured_days/days · RR_diseng(obscured)
```
1 = a month of normal conditions only; a NULL risk counts as 1.

## 6. First results

| Measure (728 region-months with weather) | Mean | Min | Max |
|---|---:|---:|---:|
| share of dust hours | 3.5 % | 0 % | 39.9 % |
| share of obscured hours | 5.1 % | 0 % | 39.9 % |
| share of rain hours | 0.5 % | 0 % | 6.6 % |
| monthly max temperature | 36.7 °C | 20.0 °C | 50.0 °C |
| `av_diseng_risk_index` | 1.043 | 0.955 | 1.327 |
| `av_crash_risk_index` | 1.002 | 1.000 | 1.026 |

Highest disengagement risk (region × season, mean index): Jazan summer 1.21 · Jazan spring 1.14 · Jazan autumn 1.12 ·
Eastern summer 1.11 · Najran spring 1.10 · Riyadh spring 1.10. Lowest: Hail, Al-Baha, Madinah, Tabuk in autumn (≈ 1.00).
The crash index barely moves because its only usable condition (rain) is rare in Saudi Arabia, and the obscured
crash ratio fails the evidence rule.

## 7. Checks (`sql/quality/03_gold_checks.sql`) — all PASS

One table in `gold` · 780 rows · unique key · Saudi weather in all 13 regions · US weather used as exposure ·
GASTAT values in all 780 rows · all 4 GASTAT workbooks used · NHTSA risk set · DMV risk set.

## 8. Data shares

100 % real. By records feeding Gold: weather 84.8 % (Saudi 64.1 %, US 20.7 %), AV 15.2 %, accidents 0.02 %
(247 values describing 86 734 serious accidents and 22 360 deaths). By Gold data columns: weather 58.8 %,
accidents 20.6 %, AV 20.6 %.

## 9. Known gaps

52 region-months (Sep–Dec 2025) have no weather (NOAA mirror ends Aug 2025); 13 region-months have < 80 % hourly
coverage (`wx_coverage_pct`); accidents are annual (same value on the 12 months of a year); within/outside-cities
split only for 2024–2025.
