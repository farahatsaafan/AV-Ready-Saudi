# Silver Layer Report — AV-Ready-Saudi

Run: 27 Nov 2026 · script `sql/02_silver.sql` · procedure `silver.load_silver`.

## 1. Purpose

Silver makes Bronze trusted: Trim · Standardize · Convert · Deduplicate · Validate · Reject (with a reason, never
silently) — Lab 4. No aggregation to region or month happens here; that is Gold's job.

## 2. Reference tables (the join keys of the model)

| Table | Rows | Content |
|---|---:|---|
| `silver.dim_region` | 13 | region code, English and Arabic name |
| `silver.region_alias` | 19 | normalised GASTAT / census label → region code (13 + 6 census spellings) |
| `silver.dim_station` | 17 | NOAA station → Saudi region or US state, time zone, coordinates |
| `silver.gastat_sheet_map` | 44 | which sheet / column / rows of which workbook hold which metric and year: 18 accident cells, 24 road cells, 2 official rate-per-100k cells (2024, 2025 — used only as a check) |

## 3. Cleaned tables

| Table | Rows | Grain | Main rules |
|---|---:|---|---|
| `weather_obs` | 920 127 | one weather report | parse fixed-width ISD groups (visibility m, temperature °C, wind m/s, 1-h precipitation); 999999/9999 → NULL; quality 2/3/6/7 → NULL; remove SOD/SOM; dedupe station + time + report type; UTC → local time (`AT TIME ZONE`); flags dust, haze, fog, rain, low visibility (< 5 km), night (sun elevation < −0.833°); keep local years 2021–2025 |
| `accidents_region_year` | 65 | region × year | read mapped cells, normalise region label, number check; 2025 total serious = within + outside cities (workbook total is a formula) |
| `roads_region_year` | 52 | region × year (2022–2025) | road km per 1 000 people and per km², intercity road km by type, divided-road share; no 2021 tables in GASTAT, so no 2021 rows (not imputed) |
| `population_region_year` | 169 | region × year (2010–2022) | census table summed over gender; Saudi / non-Saudi kept; Arabic-Indic year digits converted (`TRANSLATE` with `NCHAR(1632..1641)`); census region spellings via `region_alias` |
| `dmv_disengagement` | 49 066 | one disengagement | date from 4 formats (+ alphabetic month); window 2020-12-01..2024-11-30; manufacturer trimmed/upper; initiator and location standardised; cause category by keyword rules; program (drivered / driverless / first-time) from the file |
| `dmv_mileage_monthly` | 113 900 | vehicle × month | unpivot month JSON (`OPENJSON`), "1,049.54" → 1049.54; same VIN-month in two files → one row |
| `nhtsa_crash` | 3 244 | one crash | latest report version; one report per "Same Incident ID"; same crash in both files → archive copy; `SEP-2026` → date; weather flags → bucket normal / rain / fog_haze / dust / unknown; night from the Lighting field, else sun position; `in_scope` = CA/AZ/TX and 2021–2025 (1 893 rows) |

Typed columns (INT, DECIMAL, DATE, DATETIME2, TIME, BIT), primary keys on every table, `dw_create_date` on every row.

## 4. Condition vocabulary (shared by Saudi weather and US AV events)

| Flag | WMO / METAR rule |
|---|---|
| dust | present weather 06–09, 30–35; obscuration DU/SA; dust/sand whirls, sandstorm, duststorm |
| haze / smoke | 04–05 (manual and automated); obscuration FU/HZ |
| fog | manual 40–49, automated 30–35; obscuration FG |
| rain | manual 50–69, 80–99; automated 40–69, 80–89; DZ/RA/UP; measured 1-h precipitation > 0 |
| low visibility | visibility < 5 000 m |
| night | solar elevation < −0.833° (NOAA solar-position equations, `silver.tvf_solar_elevation`) |

Fog and haze/smoke are reported together as **fog_haze**; **dust** is kept separate, because Saudi obscured hours are
68 % dust while the California stations have 0 % dust — the US data cannot tell us how AVs behave in dust, and the
model must not pretend it can. One hour gets one bucket, in this order: dust > fog_haze > rain > normal.

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
| weather_obs | unparsable DATE | 0 |

## 6. Reconciliation (`sql/quality/02_silver_reconciliation.sql`) — 20 checks, all PASS

Every Bronze row is accounted for; each part is counted on its own and the check passes only when they add up exactly.

| Check | Result |
|---|---|
| weather | 927 141 Bronze = 920 127 Silver + 0 rejected + 6 975 SOD/SOM summaries + 0 blank report type + 0 unknown station + 0 duplicates + 39 outside 2021–2025 |
| disengagements | 49 124 Bronze = 49 066 Silver + 58 rejected |
| mileage | 0 of 9 483 reports without readable month columns; 114 158 month cells = 113 900 Silver + 0 rejected + 258 same VIN/month in a second file |
| crashes | 4 087 Bronze = 3 244 Silver + 20 rejected + 0 blank Report ID + 443 older versions + 380 same-incident duplicates |
| accidents | 65 rows = 13 regions × 5 years, 0 rejected cells |
| roads | 52 rows = 13 regions × 4 years (2022–2025), 0 rejected cells |
| population | 169 rows = 13 regions × 13 years, 0 rejected rows; Saudi Arabia 2022 = 32 175 224 (the official census count) |
| population vs GASTAT | our serious accidents per 100 000 (census 2022 population) against GASTAT's published rate: all 13 regions within 25 %, max difference 11.1 % (2024) and 17.4 % (2025) — ours is higher because GASTAT divides by the later, larger mid-year population |
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
