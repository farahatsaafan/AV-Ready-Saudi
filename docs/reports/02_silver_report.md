# Silver Layer Report — AV-Ready-Saudi

Run: 28 Nov 2026 (design v2) · script `sql/02_silver.sql` · procedure `silver.load_silver`.

## 1. Purpose

Silver makes Bronze trusted: Trim · Standardize · Convert · Deduplicate · Validate · Reject (with a reason, never
silently) — Lab 4. No aggregation to region or month happens here; that is Gold's job.

## 2. Reference tables (the join keys of the model)

| Table | Rows | Content |
|---|---:|---|
| `silver.dim_region` | 13 | region code, English and Arabic name |
| `silver.region_alias` | 20 | normalised GASTAT / census label → region code (13 + 6 census spellings + "Ryiadh" of the 2022 traffic table) |
| `silver.dim_station` | 17 | NOAA station → Saudi region or US state, time zone, coordinates |
| `silver.dim_condition` | 9 | condition vocabulary v2: dust, haze_dry, fog_moist, rain, normal (hour buckets with priority), obscured_unspecified, unknown (NHTSA only), day, night — each with its WMO / METAR / dew-point rule and its US AV coverage |
| `silver.gastat_sheet_map` | 55 | every GASTAT sheet / column / rows the warehouse reads: 18 accident cells, 24 road cells, 5 official rates per 100k (2023 mortality, 2024–2025 serious, 2024–2025 mortality cross-check), 3 region-service cells, 5 monthly traffic blocks |
| `silver.gastat_traffic_map` | 5 | layout of the monthly traffic sheets: car/truck column pairs (2021, 2022) or one region per row (2023–2025) |

Function `silver.fn_day_type(@dust, @haze_dry, @fog_moist, @rain)`: the only day-type rule (Saudi and California days).

## 3. Cleaned tables

| Table | Rows | Grain | Main rules |
|---|---:|---|---|
| `weather_obs` | 920 127 | one weather report | parse fixed-width ISD groups (visibility m, temperature and **dew point** °C, wind m/s, 1-h precipitation); 999999/9999 → NULL; quality 2/3/6/7 → NULL; remove SOD/SOM; dedupe station + time + report type; UTC → local time (`AT TIME ZONE`); flags dust, haze, fog, rain, low visibility (< 5 km), night (sun elevation < −0.833°), heat ≥ 40 / ≥ 45 °C; `dew_spread_c` = temperature − dew point; keep local years 2021–2025; FK → `dim_station` |
| `accidents_region_year` | 65 | region × year | read mapped cells, normalise region label, number check; 2025 total serious = within + outside cities (workbook total is a formula) |
| `roads_region_year` | 52 | region × year (2022–2025) | road km per 1 000 people and per km², intercity road km by type, divided-road share; no 2021 tables in GASTAT, so no 2021 rows (not imputed) |
| `population_region_year` | 208 | region × year (2010–2025) | 169 census rows (2010–2022): census table summed over gender, Saudi / non-Saudi kept, Arabic-Indic year digits converted (`TRANSLATE` with `NCHAR(1632..1641)`); 39 rows 2023–2025 = GASTAT's own denominator, count × 100 000 / published rate (2023 mortality rate; 2024, 2025 serious-accident rate), `population_basis` = `gastat_rate_implied` with `basis_detail` |
| `traffic_region_month` | 780 | region × month (2021–2025) | monthly intercity traffic; 2021–2022 Car + Truck average daily per count point, 2023–2025 month total ÷ count points ÷ days; `traffic_month_index` = month ÷ mean of the region's 12 months |
| `region_service_2025` | 13 | region | ambulance response time within / outside cities ("MM:SS" → seconds), registered vehicles |
| `dmv_disengagement` | 49 066 | one disengagement | date from 4 formats (+ alphabetic month); window 2020-12-01..2024-11-30; manufacturer trimmed/upper; initiator and location standardised; cause category by keyword rules; program (drivered / driverless / first-time) from the file |
| `dmv_mileage_monthly` | 113 900 | vehicle × month | unpivot month JSON (`OPENJSON`), "1,049.54" → 1049.54; same VIN-month in two files → one row |
| `nhtsa_crash` | 3 244 | one crash | latest report version; one report per "Same Incident ID"; same crash in both files → archive copy; `SEP-2026` → date; weather flags → bucket normal / rain / obscured_unspecified / dust / unknown (FK → `dim_condition`); night from the Lighting field, else sun position; `in_scope` = CA/AZ/TX and 2021–2025 (1 893 rows) |

Typed columns (INT, DECIMAL, DATE, DATETIME2, TIME, BIT), primary keys on every table, `dw_create_date` on every row.

## 4. Condition vocabulary v2 (shared by Saudi weather and US AV events)

| Flag | WMO / METAR rule |
|---|---|
| dust | present weather 06–09, 30–35; obscuration DU/SA; dust/sand whirls, sandstorm, duststorm |
| haze / smoke | 04–05 (manual and automated); obscuration FU/HZ |
| fog | manual 40–49, automated 30–35; obscuration FG |
| rain | manual 50–69, 80–99; automated 40–69, 80–89; DZ/RA/UP; measured 1-h precipitation > 0 |
| low visibility | visibility < 5 000 m |
| night | solar elevation < −0.833° (NOAA solar-position equations, `silver.tvf_solar_elevation`) |
| dew point | `DEW` like `TMP`; spread = temperature − dew point |

One hour gets one bucket (in `prep.weather_station_hour`), priority **dust > haze_dry > fog_moist > rain > normal**:
an obscured hour without dust is **fog_moist** if it has a fog code or its smallest temperature–dew-point spread is
≤ 2.5 °C, otherwise **haze_dry**; rain counts only when the hour is not obscured. Dust stays separate because the US AV
data has no dust at all. The dew-point split is needed because Saudi obscured hours without dust are dry haze
(5.7 % fog code, 64.5 % haze code, median spread 5.6 °C) while California's are moist fog (median spread 1.6 °C).
Dew point is valid on 911 590 reports that also have a temperature; 0.000 % have dew point > temperature.

## 5. Rejects (`silver.reject_log`)

| Table | Reason | Rows |
|---|---|---:|
| dmv_disengagement | unparsable or missing date | 56 |
| dmv_disengagement | date outside DMV reporting window | 2 |
| nhtsa_crash | same crash already in the archive file | 19 |
| nhtsa_crash | unparsable incident month | 1 |
| accidents_region_year | — | 0 |
| roads_region_year | — | 0 |
| population_region_year | — | 0 |
| traffic_region_month | — | 0 |
| region_service_2025 | — | 0 |
| weather_obs | unparsable DATE | 0 |

## 6. Reconciliation (`sql/quality/02_silver_reconciliation.sql`) — 35 checks, all PASS

Every Bronze row is accounted for; each part is counted on its own and the check passes only when they add up exactly.

| Check | Result |
|---|---|
| weather | 927 141 Bronze = 920 127 Silver + 0 rejected + 6 975 SOD/SOM summaries + 0 blank report type + 0 unknown station + 0 duplicates + 39 outside 2021–2025 |
| disengagements | 49 124 Bronze = 49 066 Silver + 58 rejected |
| mileage | 0 of 9 483 reports without readable month columns; 114 158 month cells = 113 900 Silver + 0 rejected + 258 same VIN/month in a second file |
| crashes | 4 087 Bronze = 3 244 Silver + 20 rejected + 0 blank Report ID + 443 older versions + 380 same-incident duplicates |
| accidents | 65 rows = 13 regions × 5 years, 0 rejected cells |
| roads | 52 rows = 13 regions × 4 years (2022–2025), 0 rejected cells |
| population | 208 rows = 13 regions × 16 years (169 census + 39 rate-implied), 0 rejected rows; Saudi Arabia 2022 = 32 175 224 (the official census count) |
| population vs GASTAT | the implied 2023–2025 populations give back GASTAT's published rates (0.000 % difference), and the 2024 / 2025 mortality rates, not used to build them, within 0.035 % |
| traffic | 780 rows = 13 regions × 60 months, 0 rejected cells; 2023 sum of the regions = GASTAT's national total row in all 12 months (0.000 %); month index averages 1 in all 65 region-years |
| region service | 13 regions, all response times and vehicle counts read |
| weather v2 | dew point parsed (0.000 % of 911 590 reports with dew > temperature); Saudi hour shares dust 3.49 %, haze_dry 1.16 %, fog_moist 0.51 %, rain 0.51 %, normal 94.34 % (= the independent build) |
| national totals | equal GASTAT's published totals — serious accidents 2023 16 534 · 2024 17 231 · 2025 17 805; deaths 2023 4 423 · 2024 4 282 · 2025 4 448 |

## 7. Error handling

Each step: audit row (RUNNING) → `BEGIN TRAN` → `TRUNCATE` → load → `COMMIT` → audit SUCCESS; `CATCH` → `ROLLBACK`,
audit FAILED with the message, `THROW`. `SET XACT_ABORT ON` also rolls back errors TRY/CATCH cannot catch (found in the
first run: a collation error left a transaction open).
Forced-failure demo: `sql/quality/04_rollback_demo.sql` truncates `accidents_region_year` inside a transaction, divides
by zero, and checks that the 65 rows are still there.

## 8. Assumptions

- One airport station represents each region (the region's main station).
- Cause categories of disengagements are keyword rules on free text (heuristic; used for EDA, not for the indices).
- Missing quality-flagged values are NULL, never imputed.
