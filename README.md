# AV-Ready-Saudi: Data Warehouse & Data Mining Project

**New Mansoura University — Faculty of Computer Science and Engineering**
**Course:** Data Mining & Data Warehousing (Fall 2026) — Dr. Omar Elzaki, Eng. Ghada
**Team:** Farahat Saafan, Ali Ezzat, Rokaia, Hajar Radwan, Malak Tamer
**Repository:** [github.com/farahatsaafan/AV-Ready-Saudi](https://github.com/farahatsaafan/AV-Ready-Saudi)

> Redesign of 24 Nov 2026: real data only (0 % generated), relations defined first, one Gold table.
> Full design: **[docs/05_relations_and_lineage.md](docs/05_relations_and_lineage.md)** ·
> layer reports: [Bronze](docs/reports/01_bronze_report.md), [Silver](docs/reports/02_silver_report.md),
> [Gold](docs/reports/03_gold_report.md) · [data dictionary](docs/02_data_dictionary.md) ·
> [review note for Dr. Omar](docs/06_review_note_dr_omar.md).

## 1. Question

How ready is each Saudi region, month by month, for autonomous vehicles, judged by the environmental conditions
AVs would meet there? No AVs operate in Saudi Arabia yet, so AV behaviour is learned from US records and transferred
through the conditions both places share (rain, fog/haze/low visibility, day/night; dust is measured in Saudi Arabia
but has no AV evidence, so it stays neutral). Accidents are compared as rates per 100,000 people next to each region's
road network.

## 2. Data (all real)

| Family | Source | Grain | Origin |
|---|---|---|---|
| Weather | NOAA NCEI Global Hourly — 13 Saudi stations (one per region) + LAX, SFO, PHX, AUS, 2021–2025 | weather report | Saudi + US |
| Accidents | GASTAT transport statistics 2022–2025 (serious accidents, deaths, injuries by region) | region × year | Saudi |
| AV failures | California DMV disengagement + mileage reports 2021–2024 | event / vehicle-month | US |
| AV crashes | NHTSA Standing General Order ADS reports 2021–2025 | crash | US |
| Roads | GASTAT road network tables 2022–2025 (density, intercity lengths by type) | region × year | Saudi |
| Population | GASTAT Saudi Census 2022 — population 2010–2022 by region | region × year | Saudi |

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
| Silver | `weather_obs`, `accidents_region_year`, `roads_region_year`, `population_region_year`, `dmv_disengagement`, `dmv_mileage_monthly`, `nhtsa_crash`, `reject_log`; reference: `dim_region`, `dim_station`, `region_alias`, `gastat_sheet_map` |
| prep | `weather_station_hour`, `weather_station_day`, `saudi_region_month`, `av_relative_risk` |
| Gold | `av_readiness_region_month` — 13 regions × 60 months = 780 rows |

Relations: weather, roads and population ↔ accidents on `region_code + year`; weather ↔ AV events through one
condition vocabulary (normal / rain / fog_haze / dust, day / night);
AV events ↔ US weather on state / date. Every source reaches Gold (checked by `sql/quality/03_gold_checks.sql`).

## 4. Run it (macOS, SQL Server 2022 in Docker)

```bash
cd ~/AV-Ready-Saudi
SA_PASSWORD='your-sa-password' bash run_pipeline_mac.sh   # creates .venv on the first run
```

The script lands the raw files, copies `sql/` and `Data/landing/` into the container `sql2022`, runs
`00_init → 01_bronze → 02_silver → 03_gold` with their load procedures, then the four quality scripts, then the
independent pandas rebuild (`python/02_reference_gold.py`) whose expected counts are listed in
[docs/05_relations_and_lineage.md §9](docs/05_relations_and_lineage.md).

Windows (local SQL Server, e.g. SQLEXPRESS): `powershell -ExecutionPolicy Bypass -File .\run_pipeline.ps1`
(add `-ServerInstance "localhost"` for a default instance). Step-by-step for the team, in Arabic:
[docs/04_team_collaboration_guide.md](docs/04_team_collaboration_guide.md).

An existing `av_ready_saudi_dw` from the old design is upgraded automatically: `sql/00_init.sql` removes the old
Star Schema, semantic / ml objects and the old `audit.load_log`.

Connect from VS Code (mssql extension): server `localhost,1433`, user `sa`, database `av_ready_saudi_dw`.

## 5. Repository

```
python/00_land_raw.py           raw -> landing TSV (container format only)
python/02_reference_gold.py     independent pandas build of Silver/Gold + data shares
python/01_profile_raw_data.py   profiling helper
sql/00_init.sql                 database, schemas, audit tables
sql/01_bronze.sql               Bronze tables + bronze.load_bronze
sql/02_silver.sql               Silver tables, reference data + silver.load_silver
sql/03_gold.sql                 prep tables, the Gold table + gold.load_gold
sql/04_analysis.sql             first EDA queries on Gold (bad vs good weather years, region profiles)
sql/quality/                    Bronze validation, Silver reconciliation, Gold checks + data shares, rollback demo
docs/05_relations_and_lineage.md  relations, rules, lineage, data shares, limitations
docs/reports/01-03               Bronze, Silver, Gold reports (run of 24 Nov 2026)
docs/02_data_dictionary.md       every column of every table (also data_dictionary.csv)
docs/01_architecture_overview.md layers and run order at a glance
docs/04_team_collaboration_guide.md  setup guide for the team (Arabic)
docs/06_review_note_dr_omar.md   open question for Dr. Omar (data shares)
run_pipeline_mac.sh / run_pipeline.ps1
```

## 6. Data shares (reference build)

100 % real. By records feeding Gold: weather 84.8 % (Saudi 64.1 %, US 20.7 %), AV 15.2 %, accidents 0.02 %
(247 GASTAT values that describe 86 734 serious accidents). By Gold data columns: weather 58.8 %, accidents 20.6 %,
AV 20.6 %. See the design document for the discussion.
