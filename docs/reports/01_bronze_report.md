# Bronze Layer Report — AV-Ready-Saudi

Run: 27 Nov 2026, SQL Server 2022 (Docker, macOS), database `av_ready_saudi_dw`, script `sql/01_bronze.sql`,
procedure `bronze.load_bronze`. All numbers below are from that run (`Data/pipeline_run.log`).

Bronze is unchanged in design v2 (28 Nov 2026): the new Silver inputs (dew point `DEW`, monthly traffic, GASTAT rate
sheets, region service) were already in `bronze.noaa_hourly` and `bronze.gastat_cells`; no file or column was added.

## 1. Purpose

Bronze is the raw landing zone (Lecture 02 §2.2): every value is stored exactly as the source published it, as text,
with provenance, so Silver always has a stable, inspectable input. No cleaning, typing or dropping happens here.

## 2. Sources and tables

| Bronze table | Source | Raw files | Rows loaded | Columns (data + JSON) |
|---|---|---:|---:|---|
| `bronze.noaa_hourly` | NOAA NCEI Global Hourly — 13 Saudi + 4 US stations, 2021–2025 | 85 | 927 141 | 22 named + `extra_json` (all optional ISD groups) |
| `bronze.gastat_cells` | GASTAT transport statistics workbooks 2022–2025 | 4 | 76 588 | one row per non-empty cell: file, sheet, row, column, value |
| `bronze.dmv_disengagements` | California DMV disengagement reports 2021–2024 | 8 | 49 124 | 9 named + `extra_json` |
| `bronze.dmv_mileage` | California DMV mileage reports 2021–2024 | 8 | 9 483 | 4 named + `months_json` (month columns differ per year) |
| `bronze.nhtsa_sgo_ads` | NHTSA SGO ADS incident reports (archive + current) | 2 | 4 087 | 13 named + `row_json` (complete row) |
| `bronze.gastat_population` | GASTAT Census 2022 population table (region × nationality × gender × year, 2010–2022) | 1 | 676 | 5 named (`Gender`, `Nationality`, `Region`, `Year`, `Population`) |
| **Total** | | **108** | **1 067 099** | |

Every table also has `load_batch_id`, `ingested_at`, `source_file`, `source_row_num` and `row_end`.

## 3. Landing step (format only)

`python/00_land_raw.py` turns the raw files into one TSV per Bronze table (`Data/landing/`). It changes the
container format only:

| Problem in the raw files | What landing does | What stays verbatim |
|---|---|---|
| NOAA files carry different optional columns per station (111 distinct) | fixed columns + the rest as `{header: value}` JSON | every value, with its original header |
| GASTAT tables are `.xlsx` (BULK INSERT cannot read Excel) | one row per cell | cell text, formulas kept as text (`=SUM(B8:B20)`) |
| DMV mileage month headers change every year (`DEC 2020`, `JAN 2022`…) | months kept in JSON | every month value |
| NHTSA archive (137 columns) and current (116) differ | key columns + full row JSON | every value |
| census table is a UTF-8 CSV exported from GASTAT's Tableau server | same 5 columns, re-encoded | every value, including Arabic-Indic digits in `Year` |

Encoding: UTF-16 with byte-order mark, tab-separated, CRLF, plus a constant last column `row_end = "."`. Reasons found
while running on Linux: `CODEPAGE = '65001'` is not supported by SQL Server on Linux, `widechar` needs the BOM, and
Linux BULK INSERT ends rows at LF — the marker column absorbs the CR so no data column is altered.

## 4. Load procedure

`bronze.load_bronze @landing_path` loops over a 6-row load plan. For each table:
`TRUNCATE` → `BULK INSERT` into a load view (so provenance defaults still apply) → stamp `load_batch_id` →
count → write `audit.load_log` (RUNNING → SUCCESS / FAILED with the error text). Full-load pattern as in the course.

## 5. Validation (`sql/quality/01_bronze_validation.sql`) — 11 checks, all PASS

| Check | Expected | Actual |
|---|---|---|
| NOAA station-year files | 85 | 85 |
| NOAA stations | 17 | 17 |
| GASTAT workbooks | 4 | 4 |
| DMV disengagement files | 8 | 8 |
| DMV mileage files | 8 | 8 |
| NHTSA files | 2 | 2 |
| census population file | 1 | 1 |
| census population rows (2 genders × 2 nationality groups × 13 regions × 13 years) | 676 | 676 |
| NHTSA `row_json` valid JSON | 0 bad | 0 bad |
| DMV `months_json` valid JSON | 0 bad | 0 bad |
| every row has a batch id | 0 missing | 0 missing |

Row counts equal the landing manifest (`Data/landing/LANDING_MANIFEST.csv`) and the independent pandas build.

## 6. Defects kept on purpose (handled in Silver)

- NOAA: daily/monthly summary records (`SOD`, `SOM`) mixed with observations; duplicate reports; `999999` / `+9999`
  missing markers; quality flags 2/3/6/7.
- GASTAT: region names written several ways (`Eastern Province` / `Eastern Region`, leading spaces); total rows as formulas.
- DMV: 10+ date formats (`1/5/2021`, `2022.03.04.`, `15/Apr/22`, blank), location and initiator spelled freely.
- Census: some `Year` values written in Arabic-Indic digits (٢٠٢٢); region names in a third spelling (`Ar Riyadh`, `Al Qaseem`…).
- NHTSA: several versions of the same report; the same crash reported by two entities; state codes with trailing spaces.
