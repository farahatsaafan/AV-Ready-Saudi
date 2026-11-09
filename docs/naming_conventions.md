# Naming Conventions & Architectural Standards

**Project:** AV-Ready-Saudi  
**Course:** Data Mining & Data Warehousing (Fall 2026)  
**Standard Reference:** Department of Computer Science & Engineering - Course Project Skeleton  

---

## 1. General Principles
- **Schemas, Tables, Views, Columns:** All identifiers must be in `lowercase_snake_case`. No spaces, no hyphens, no camelCase.
- **Reserved Keywords:** Never use SQL Server reserved keywords as bare column names (e.g., use `[date]` or preferably `weather_date`, `accident_date`).
- **Language:** English for all database metadata, schemas, table names, and column identifiers. Arabic strings are strictly stored as `NVARCHAR` with explicit `N'...'` literals.

---

## 2. Key Conventions
- **Business Keys (Natural Keys):** Suffix with `_id` (e.g., `city_id`, `accident_id`, `telemetry_id`, `vehicle_id`). Represents the identifier provided by the source system.
- **Surrogate Keys (Warehouse Keys):** Suffix with `_key` in dimensional models (e.g., `city_key`, `date_key`, `hazard_key`, `failure_key`). Typically an `INT IDENTITY(1,1)` or formatted integer (`YYYYMMDD` for dates).
- **Foreign Keys:** Must mirror the referenced surrogate key name exactly in fact tables (e.g., `fact_daily_av_risk.city_key` references `dim_city.city_key`).

---

## 3. Layer-Specific Prefixes & Naming

| Layer / Schema | Object Type | Naming Pattern | Example |
| :--- | :--- | :--- | :--- |
| **`bronze`** | Landing Table | `bronze.<source_name>` | `bronze.sa_weather`, `bronze.sa_traffic_accidents`, `bronze.av_telemetry` |
| **`bronze`** | Ingest View | `bronze.v_<source_name>_load` | `bronze.v_sa_weather_load` (preserves provenance defaults during BULK INSERT) |
| **`silver`** | Trusted Table | `silver.<entity_or_concept>` | `silver.sa_weather`, `silver.sa_traffic_accidents`, `silver.av_telemetry` |
| **`silver`** | Reject Quarantine | `silver.reject_log` | Centralized reject table with `source_table`, `business_key`, `reason` |
| **`gold`** | Dimension | `gold.dim_<entity>` | `gold.dim_city`, `gold.dim_date`, `gold.dim_weather_hazard`, `gold.dim_av_failure_type` |
| **`gold`** | Fact Table / View | `gold.fact_<event_or_grain>` | `gold.fact_daily_av_risk` *(Grain: one row per city per day)* |
| **`gold`** | Feature View | `gold.features_<topic>` | `gold.features_city_monthly`, `gold.features_daily_trip` |
| **`semantic`**| Metric Catalog | `semantic.metric_catalog` | Metadata registry for all enterprise business metrics |
| **`semantic`**| Semantic View | `semantic.v_<metric_or_topic>` | `semantic.v_av_readiness_by_city`, `semantic.v_disengagement_rate_by_weather` |
| **`ml`** | Mining Output | `ml.<topic>_<result>` | `ml.city_risk_clusters`, `ml.trip_risk_predictions` |
| **`audit`** | Audit Table | `audit.load_log` | Tracks batch executions with `batch_id`, timestamps, row counts, and status |

---

## 4. Technical Audit Columns
To ensure end-to-end data lineage and reproducibility:
* **Bronze Provenance:** Every bronze table must include:
  * `source_file VARCHAR(500) NULL` — Name or relative path of the raw file.
  * `ingested_at DATETIME2 NOT NULL DEFAULT SYSDATETIME()` — Precise ingestion timestamp.
* **Silver & Gold Lineage:** Every transformed record must include:
  * `DW_create_date DATETIME2 NOT NULL DEFAULT SYSDATETIME()` — Warehouse loading timestamp.
* **Machine Learning Lineage:** Every ML output written to `ml.*` must include:
  * `model_name VARCHAR(100)` — e.g., `kmeans_city_risk_clustering`
  * `model_version VARCHAR(20)` — e.g., `v1.0`
  * `run_id VARCHAR(50)` — Unique execution GUID
  * `generated_at DATETIME2` — Training and scoring timestamp

---

## 5. SQL Script Numbering
Numbered sequential scripts executed in order:
* `sql/00_init.sql` — Database, 6 schemas, and audit logging table.
* `sql/01_bronze.sql` — Landing tables, provenance columns, and BULK INSERT load views.
* `sql/02_silver.sql` — Strongly-typed silver tables, `reject_log`, and 6-verbs transformation.
* `sql/03_gold.sql` — Dimensional star schema (dimensions & facts with documented grain).
* `sql/04_semantic.sql` — Metric catalog and semantic views.
* `sql/05_feature_views.sql` — Documented feature views feeding Data Mining algorithms.
* `sql/06_analytics.sql` — Business analytical queries answering the core research questions.
