# AV-Ready-Saudi: Data Warehouse & Data Mining Project

**New Mansoura University — Faculty of Computer Science and Engineering**
**Course:** Data Mining & Data Warehousing (Fall 2026) — Dr. Omar Elzaki, Eng. Ghada
**Team:** Farahat Saafan, Ali Ezzat, Rokaia, Hajar Radwan, Malak Tamer
**Repository:** [github.com/farahatsaafan/AV-Ready-Saudi](https://github.com/farahatsaafan/AV-Ready-Saudi)

> Design v2 of 28 Nov 2026: real data only (0 % generated), relations declared as foreign keys, condition vocabulary v2
> (dust / dry haze / moist fog / rain / normal, by dew point), stratified AV evidence with confidence intervals, one Gold
> table with no constant column. Full design: **[docs/05_relations_and_lineage.md](docs/05_relations_and_lineage.md)** ·
> [ERD + proposed system](docs/07_erd.md) · layer reports: [Bronze](docs/reports/01_bronze_report.md),
> [Silver](docs/reports/02_silver_report.md), [Gold](docs/reports/03_gold_report.md),
> [EDA, models and evaluation](docs/reports/04_eda_and_models.md) · [data dictionary](docs/02_data_dictionary.md) ·
> [review note for Dr. Omar](docs/06_review_note_dr_omar.md).

## 1. Question

How ready is each Saudi region, by season, for autonomous vehicles (AVs)? The output is a readiness score per region ×
season with its drivers. No AVs operate in Saudi Arabia yet, so AV evidence comes from US records (NHTSA crashes,
California DMV disengagements and mileage) and is transferred through one weather vocabulary measured the same way in
both places. A region-month is as ready as the share of its hours inside the US AV evidence, penalised only by risks
the US crash data shows with confidence (today: rain, RR 1.52 [1.14, 2.00]); dust has no US AV evidence at all and
counts as uncovered. Safety (accident and death rates per 100,000) and infrastructure (divided roads, road density,
ambulance response time) are the other two pillars.

## 2. Data (all real)

| Family | Source | Grain | Origin |
|---|---|---|---|
| Weather | NOAA NCEI Global Hourly — 13 Saudi stations (one per region) + LAX, SFO, PHX, AUS, 2021 – Aug 2025 (incl. dew point) | weather report | Saudi + US |
| Accidents | GASTAT transport statistics 2022–2025 (serious accidents, deaths, injuries by region) | region × year | Saudi |
| Traffic | GASTAT monthly intercity traffic by region, every month 2021–2025 (same workbooks) | region × month | Saudi |
| Population | GASTAT Census 2022 table (2010–2022) + GASTAT's own denominator from its published rates (2023–2025) | region × year | Saudi |
| Roads | GASTAT road network tables 2022–2025 (density, intercity lengths by type) | region × year | Saudi |
| Region service | GASTAT 2025: ambulance response time, registered vehicles | region | Saudi |
| AV failures | California DMV disengagement + mileage reports, Dec 2020 – Nov 2024 | event / vehicle-month | US |
| AV crashes | NHTSA Standing General Order ADS reports 2021–2025 | crash | US |

Details and **every link used in the project** (source page + download link per file, and the sources that were
dropped): [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md) · register: [docs/data_source_register.csv](docs/data_source_register.csv).
Raw files are not in Git (`Data/` is ignored). **Download:** [Google Drive — New Data](https://drive.google.com/drive/folders/1hmh-0XqcQ9MZ5juEkdRgR7CMA9GsERj3)
→ `AV-Ready-Saudi_Data_raw.zip`, unzip it in the project folder (it creates `Data/raw/`).

## 3. Architecture

```
Data/raw ──python/00_land_raw.py──► Data/landing/*.tsv   (format only, values verbatim)
        ──BULK INSERT──► bronze.*   6 raw tables, text + provenance + batch id
        ──silver.load_silver──► silver.*   typed, cleaned, deduplicated, reject_log, reference tables
        ──gold.load_gold──► prep.* (work tables) ──► gold.av_readiness_region_month   (ONE table)
```

| Layer | Objects |
|---|---|
| Bronze | `noaa_hourly`, `gastat_cells`, `dmv_disengagements`, `dmv_mileage`, `nhtsa_sgo_ads`, `gastat_population` |
| Silver | `weather_obs`, `accidents_region_year`, `roads_region_year`, `population_region_year`, `traffic_region_month`, `region_service_2025`, `dmv_disengagement`, `dmv_mileage_monthly`, `nhtsa_crash`, `reject_log`; reference: `dim_region`, `dim_station`, `dim_condition`, `region_alias`, `gastat_sheet_map`, `gastat_traffic_map`; function `fn_day_type` |
| prep | `weather_station_hour`, `weather_station_day`, `saudi_region_month`, `av_relative_risk` |
| Gold | `av_readiness_region_month` — 13 regions × 60 months = 780 rows, the only table in schema `gold` |

Relations (18 foreign keys, diagram in [docs/07_erd.md](docs/07_erd.md)): weather, traffic, roads, population and
service ↔ accidents / Gold on `region_code` (+ `year` or `month_start`); weather ↔ AV events through `silver.dim_condition`
(every hour bucket, day type, NHTSA category and relative-risk row is a FK to it); AV events ↔ US weather on state ×
month (crashes) and date × weekday class (disengagements, weighted by fleet miles). Every source reaches Gold (checked by
`sql/quality/03_gold_checks.sql`).

## 4. Run it (macOS, SQL Server 2022 in Docker)

```bash
cd ~/AV-Ready-Saudi
SA_PASSWORD='your-sa-password' bash run_pipeline_mac.sh   # creates .venv on the first run
```

The script lands the raw files, copies `sql/` and `Data/landing/` into the container `sql2022`, runs
`00_init → 01_bronze → 02_silver → 03_gold` with their load procedures, the four quality scripts and the EDA suite
(`sql/04_analysis.sql`), then: the independent pandas rebuild (`python/02_reference_gold.py`), the GLM cross-check of the
AV evidence (`python/04_av_evidence_models.py`), the export of Gold to `Data/gold_export/` with a column-by-column
comparison against the reference, and the readiness model (`python/05_readiness_model.py`, which writes
`Data/model/`, `docs/figures/` and `docs/reports/04_eda_and_models.md`). Python code runs on Python 3.9+.

Windows (local SQL Server, e.g. SQLEXPRESS): `powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1`
(add `-ServerInstance "localhost"` for a default instance). Step-by-step for the team, in Arabic:
[docs/04_team_collaboration_guide.md](docs/04_team_collaboration_guide.md).

An existing `av_ready_saudi_dw` from the old design is upgraded automatically: `sql/00_init.sql` removes the old
Star Schema, semantic / ml objects and the old `audit.load_log`.

Connect from VS Code (mssql extension): server `localhost,1433`, user `sa`, database `av_ready_saudi_dw`.

## 5. Repository

```
python/00_land_raw.py              raw -> landing TSV (container format only)
python/02_reference_gold.py        independent pandas build of Silver / prep / Gold (+ --compare with the SQL Gold)
python/03_data_dictionary.py       rebuilds the data dictionary from the DDL
python/04_av_evidence_models.py    GLM cross-check of the AV relative risks, robustness, hold-out, forest plot
python/05_readiness_model.py       readiness score, KMeans tiers, weather -> accidents test, sensitivity, report 04
python/01_profile_raw_data.py      profiling helper
sql/00_init.sql                    database, schemas, audit tables
sql/01_bronze.sql                  Bronze tables + bronze.load_bronze
sql/02_silver.sql                  Silver tables, reference data, fn_day_type + silver.load_silver
sql/03_gold.sql                    prep tables, the Gold table + gold.load_gold (AV evidence in SQL)
sql/04_analysis.sql                EDA suite on Gold (ROLLUP, CUBE, GROUPING SETS, window functions) with findings
sql/quality/                       Bronze validation, Silver reconciliation, Gold checks + data shares, rollback demo
docs/05_relations_and_lineage.md   relations, rules, lineage, data shares, limitations
docs/07_erd.md                     ERD (Mermaid) + proposed-system diagram
docs/reports/01-04                 Bronze, Silver, Gold reports; EDA, models and evaluation
docs/figures/                      forest plot, readiness heatmap, pillars, losses, clusters, sensitivity
docs/02_data_dictionary.md         every column of every table (also data_dictionary.csv)
docs/01_architecture_overview.md   layers and run order at a glance
docs/04_team_collaboration_guide.md  setup guide for the team (Arabic)
docs/06_review_note_dr_omar.md     what changed since 24 Nov and why
run_pipeline_mac.sh / run_pipeline.ps1
```

## 6. Results at a glance (run of 28 Nov 2026)

- **Data shares:** 100 % real. By records feeding Gold: weather 84.7 % (Saudi 64.0 %, US 20.7 %), AV 15.2 %, Saudi
  GASTAT tables (accidents, traffic, population, roads, service) 0.15 % — the 247 accident values describe 86 734 serious
  accidents. By Gold columns that vary: weather 25, accidents 9, AV evidence 5, roads 4, region service 3, traffic 2,
  population 1 (49 numeric data columns, none constant).
- **AV evidence:** only NHTSA rain passes the evidence rule (1.52 [1.14, 2.00], 70 crashes). The crude DMV ratios
  (fog/haze 1.35, rain 0.78) disappear once month and weekday are held fixed; weather adds nothing out of time.
- **Readiness score** (0–100, equal weights for environment, safety, infrastructure): Al-Jouf 86.0, Eastern Province 72.0,
  Hail 70.7, Northern Borders 68.8 … Al-Baha 47.4, Madinah 44.9, Jazan 43.6; lowest region-season Jazan in summer (27.2).
  Spring is the weakest season in 10 of 13 regions (dust). Over 66 weight choices the ranking keeps a median Kendall tau
  of 0.68; Al-Jouf, Hail and Jazan keep their tier in ≥ 97 % of them. Details, clusters and figures:
  [report 04](docs/reports/04_eda_and_models.md).
- **Weather → accidents** at region-year level is a null result with this data (year-adjusted rank correlations
  p ≥ 0.42; no model generalises to an unseen region).
