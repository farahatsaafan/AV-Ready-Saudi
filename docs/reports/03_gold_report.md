# Gold Layer Report — AV-Ready-Saudi

Run: 27 Nov 2026 · script `sql/03_gold.sql` · procedure `gold.load_gold`.

## 1. The single Gold table

`gold.av_readiness_region_month` — **grain: one Saudi administrative region × one calendar month, 2021–2025**
(13 × 60 = **780 rows**, key `region_code + month_start`). Schema `gold` holds only this table (checked).
Work tables used to build it live in schema `prep`.

| Column group | Columns | From |
|---|---:|---|
| keys and labels | 8 | `dim_region`, `dim_station`, calendar |
| Saudi weather | 23 | NOAA hourly → station-hour → region-month |
| Saudi accidents | 9 | GASTAT region-year (counts + rates per 100,000) |
| Saudi population | 2 | GASTAT Census 2022 table (`population`, `population_basis`) |
| Saudi road network | 4 | GASTAT road tables, region-year (2022–2025) |
| AV evidence | 9 | NHTSA crashes, DMV disengagements + mileage, US analog weather |
| lineage | 5 | source text, batch id, load time |

Column definitions: `docs/02_data_dictionary.md`.

## 2. How the sources meet (relations)

| Relation | Key |
|---|---|
| weather ↔ accidents | `region_code` + `year` |
| weather ↔ AV events | condition vocabulary: normal / rain / fog_haze (fog, haze, mist, < 5 km without dust) / dust, day / night |
| roads ↔ accidents | `region_code` + `year` |
| population ↔ accidents | `region_code` + `year` (2023–2025: 2022 census count) |
| AV crashes ↔ US weather | `us_state` (CA → LAX + SFO, AZ → PHX, TX → AUS) |
| AV disengagements ↔ CA weather ↔ mileage | event date ↔ California day type; month ↔ fleet miles |

Diagram, rules and full lineage: `docs/05_relations_and_lineage.md`.

## 3. Build steps

1. `prep.weather_station_hour` — several reports per hour → one hour; hour bucket dust › fog_haze › rain › normal.
2. `prep.weather_station_day` — day type: ≥ 3 obscured hours → dust or fog_haze (whichever has more hours)
   › rain (≥ 1 rain hour) › normal.
3. `prep.saudi_region_month` — hours and days per condition for each Saudi station-month.
4. `prep.av_relative_risk` — relative risk of an AV event in each condition vs the normal condition
   (exposure = US station-hours weighted by crash state for crashes; fleet miles on CA days for disengagements);
   evidence rule: used only if ≥ 30 events.
5. Gold — calendar of 780 region-months, joined to (3), to accidents, roads and population by region + year
   (population: same year, else the 2022 census count), and to the risks.

## 4. Relative risks (prep.av_relative_risk)

| Source | Level | Events | Event share | Exposure share | Relative risk | Used |
|---|---|---:|---:|---:|---:|---|
| NHTSA crash | rain | 70 | 3.73 % | 2.58 % | 1.40 | yes |
| NHTSA crash | fog / haze | 2 | 0.11 % | 4.47 % | 0.02 | no (< 30) |
| NHTSA crash | dust | 0 | 0 % | 0.02 % | — | no (< 30) |
| NHTSA crash | night | 741 | 39.1 % | 49.9 % | 0.64 | stored, not in index |
| DMV disengagement | rain days | 5 096 | 10.4 % | 14.0 % | 0.79 | yes |
| DMV disengagement | fog / haze days | 17 968 | 36.7 % | 29.2 % | 1.34 | yes |
| DMV disengagement | dust days | 0 | 0 % | — | — | no (no dust days in California) |

## 5. Indices

```
av_crash_risk_index  = share_normal + share_rain · RR_crash(rain) + share_fog_haze · RR_crash(fog_haze)
                     + share_dust · RR_crash(dust)
av_diseng_risk_index = normal_days/days + rain_days/days · RR_diseng(rain) + fog_haze_days/days · RR_diseng(fog_haze)
                     + dust_type_days/days · RR_diseng(dust)
```
1 = a month of normal conditions only; a NULL risk counts as 1.

## 6. First results

| Measure (728 region-months with weather) | Mean | Min | Max |
|---|---:|---:|---:|
| share of dust hours | 3.5 % | 0 % | 39.9 % |
| share of fog / haze hours (no dust) | 1.7 % | 0 % | 21.0 % |
| share of obscured hours (dust + fog / haze) | 5.1 % | 0 % | 39.9 % |
| share of rain hours | 0.5 % | 0 % | 6.6 % |
| monthly max temperature | 36.7 °C | 20.0 °C | 50.0 °C |
| `av_diseng_risk_index` | 1.007 | 0.927 | 1.276 |
| `av_crash_risk_index` | 1.002 | 1.000 | 1.026 |

Highest disengagement risk (region × season, mean index): Eastern winter 1.06 · Eastern autumn 1.06 · Jazan autumn
1.05 · Jazan summer 1.05 · Jazan spring 1.05 — the regions with the most fog / haze. Lowest: Riyadh, Qassim and Hail
in spring (≈ 0.99). Dust no longer raises the index (no AV evidence for dust), so dusty regions such as Najran are not
scored as risky on borrowed fog evidence; their dust exposure stays visible in `share_dust_hours`.
The crash index barely moves because its only usable condition (rain) is rare in Saudi Arabia, and the fog / haze
crash ratio fails the evidence rule.

Serious accidents per 100,000 people (region mean 2021–2025): Al-Baha 101.2 · Madinah 84.5 · Makkah 73.4 ·
Jazan 58.5 · … · Najran 37.0 · Eastern 33.2 · Al-Jouf 29.5. In absolute counts Makkah and Riyadh lead; per person,
Al-Baha is highest — the reason the rates are in Gold.

## 7. Checks (`sql/quality/03_gold_checks.sql`) — 11 checks, all PASS

One table in `gold` · 780 rows · unique key · Saudi weather in all 13 regions · US weather used as exposure ·
GASTAT values in all 780 rows · census population and rates in all 780 rows · road columns in the 624 rows of
2022–2025 · all 4 GASTAT workbooks used · NHTSA risk set · DMV risk set.

## 8. Data shares

100 % real. By records feeding Gold: weather 84.8 % (Saudi 64.1 %, US 20.7 %), AV 15.2 %, Saudi accidents + roads +
population 0.07 % (728 region-year values; the 247 accident values describe 86 734 serious accidents and 22 360
deaths). By Gold data columns (46): weather 23 (50.0 %), accidents 9, population 1, roads 4 (together 30.4 %),
AV 9 (19.6 %).

## 9. Known gaps

52 region-months (Sep–Dec 2025) have no weather (NOAA mirror ends Aug 2025); 13 region-months have < 80 % hourly
coverage (`wx_coverage_pct`); accidents, roads and population are annual (same value on the 12 months of a year, not
additive over months); road tables start in 2022; population for 2023–2025 is the 2022 census count
(`population_basis`); within/outside-cities split only for 2024–2025.
