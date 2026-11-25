# Silver Layer Report — AV-Ready-Saudi

Run: 24 Nov 2026 · script `sql/02_silver.sql` · procedure `silver.load_silver`.

## 1. Purpose

Silver makes Bronze trusted: Trim · Standardize · Convert · Deduplicate · Validate · Reject (with a reason, never
silently) — Lab 4. No aggregation to region or month happens here; that is Gold's job.

## 2. Reference tables (the join keys of the model)

| Table | Rows | Content |
|---|---:|---|
| `silver.dim_region` | 13 | region code, English and Arabic name |
| `silver.region_alias` | 13 | normalised GASTAT label → region code |
| `silver.dim_station` | 17 | NOAA station → Saudi region or US state, time zone, coordinates |
| `silver.gastat_sheet_map` | 18 | which sheet / column / rows of which workbook hold which metric and year |

## 3. Cleaned tables

| Table | Rows | Grain | Main rules |
|---|---:|---|---|
| `weather_obs` | 920 127 | one weather report | parse fixed-width ISD groups (visibility m, temperature °C, wind m/s, 1-h precipitation); 999999/9999 → NULL; quality 2/3/6/7 → NULL; remove SOD/SOM; dedupe station + time + report type; UTC → local time (`AT TIME ZONE`); flags dust, haze, fog, rain, low visibility (< 5 km), night (sun elevation < −0.833°); keep local years 2021–2025 |
| `accidents_region_year` | 65 | region × year | read mapped cells, normalise region label, number check; 2025 total serious = within + outside cities (workbook total is a formula) |
| `dmv_disengagement` | 49 066 | one disengagement | date from 4 formats (+ alphabetic month); window 2020-12-01..2024-11-30; manufacturer trimmed/upper; initiator and location standardised; cause category by keyword rules; program (drivered / driverless / first-time) from the file |
| `dmv_mileage_monthly` | 113 900 | vehicle × month | unpivot month JSON (`OPENJSON`), "1,049.54" → 1049.54; same VIN-month in two files → one row |
| `nhtsa_crash` | 3 244 | one crash | latest report version; one report per "Same Incident ID"; same crash in both files → archive copy; `SEP-2026` → date; weather flags → bucket normal / rain / obscured / unknown; night from the Lighting field, else sun position; `in_scope` = CA/AZ/TX and 2021–2025 (1 893 rows) |

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

## 5. Rejects (`silver.reject_log`)

| Table | Reason | Rows |
|---|---|---:|
| dmv_disengagement | unparsable or missing date | 56 |
| dmv_disengagement | date outside DMV reporting window | 2 |
| nhtsa_crash | same crash already in the archive file | 19 |
| nhtsa_crash | unparsable incident month | 1 |
| accidents_region_year | — | 0 |
| weather_obs | unparsable DATE | 0 |

## 6. Reconciliation (`sql/quality/02_silver_reconciliation.sql`) — all PASS

- Weather: 927 141 Bronze = 920 127 Silver + 0 rejected + SOD/SOM summaries + blank report type + unknown station + duplicate reports + reports outside 2021–2025 (each part counted on its own; the check passes only when they add up exactly).
- Mileage: every month cell of every DMV report = a Silver row, a rejected cell, or the same VIN/month in a second file.
- Disengagements: 49 124 Bronze = 49 066 Silver + 58 rejected.
- Crashes: 4 087 Bronze = 3 244 Silver + 20 rejected + blank Report ID + older report versions + same-incident duplicates.
- Accidents: 65 rows = 13 regions × 5 years, 0 rejected cells.
- National totals equal GASTAT's published totals: serious accidents 2023 16 534 · 2024 17 231 · 2025 17 805;
  deaths 2023 4 423 · 2024 4 282 · 2025 4 448.

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
