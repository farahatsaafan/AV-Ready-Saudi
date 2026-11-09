# Project Specification: AV-Ready-Saudi

**Course:** Data Mining & Data Warehousing (Fall 2026)  
**Institution:** New Mansoura University — Faculty of Computer Science & Engineering  
**Project Lead & Author:** Farahat Saafan & Project Team  
**Repository:** [github.com/farahatsaafan/AV-Ready-Saudi](https://github.com/farahatsaafan/AV-Ready-Saudi)  
**Data Repository:** [Google Drive AV-Ready-Saudi Datasets](https://drive.google.com/drive/u/0/folders/1ehqYZj7pMf8gUf-10DxyHAhyGpUt86tH)  

---

## 1. Problem Statement
The Kingdom of Saudi Arabia is investing heavily in futuristic, smart-mobility ecosystems (e.g., NEOM, Ceer Motors, Lucid EV assembly, and Vision 2030 smart transit). However, the Arabian Peninsula presents some of the world's harshest operational design domains (ODD) for Autonomous Vehicles (SAE Level 3 to Level 5):
* Frequent convective sandstorms and airborne $PM_{10}$ dust causing optical occlusion and severe LiDAR pulse absorption.
* Summer surface temperatures exceeding $48^\circ\text{C}$ and highway asphalt reaching $70^\circ\text{C}$, triggering on-board compute GPU thermal throttling and explosive tire delamination.
* Intense direct solar irradiance ($>25\,\text{MJ/m}^2$) blinding front-facing automotive cameras during midday transit.

This project delivers an end-to-end Enterprise Data Warehouse and Machine Learning Feature Store (**AV-Ready-Saudi**) to determine:
1. **When and where** autonomous vehicles can safely operate across Saudi urban and highway corridors.
2. **How severe** climate extremes degrade multi-sensor perception stacks (LiDAR and Cameras).
3. **What operational safety policies** municipal authorities and fleet operators must enforce to avert autonomous disengagements and fatal traffic accidents.

---

## 2. Business Questions
1. **Sensor & Environmental Hazard Rating:** How do dust storms, ambient heat peaks ($>45^\circ\text{C}$), and high solar glare degrade LiDAR attenuation ($>60\%$) and camera contrast across 10 major Saudi cities?
2. **Corridor Accident Hotspot Correlation:** How do historical highway traffic accidents correlate with localized climate hazards (e.g., dust-induced zero visibility vs. wet road skidding) on national transit corridors (Highways 40, 65, 15)?
3. **Autonomous Operational Readiness Index:** What is the daily and monthly synthesized AV Readiness Index (`av_readiness_score` 0 to 100) across Saudi urban hubs?
4. **Machine Learning Regime Segmentation:** Which Saudi cities and months group into *Optimal Autonomous Capable*, *Moderate Risk (Advisory Required)*, and *High Hazard (Autonomous Operations Restricted)* regimes?
5. **Disengagement Root-Cause Attribution:** What is the empirical probability that an AV will require manual human takeover (`av_disengagement = True`) under specific wind gust, dust, and temperature thresholds?

---

## 3. Source Contract
All 3 primary data sources are registered in `docs/data_source_register.csv`:

| Source ID | Name | Modality | Native Grain | Expected Volume | Key Attributes | Provenance & Access |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`SRC-WEA-01`** | `saudi_weather_daily_2019_2024.csv` | Tabular CSV | One row per city per day | 21,920 rows (10 cities $\times$ 6 years) | `date, city_id, temp_max_c, wind_gusts_max_kmh, solar_radiation_mj, weather_code_wmo, is_dust_storm, is_extreme_heat` | Open-Meteo Historical Archive API (ECMWF ERA5 / Saudi NCM stations) |
| **`SRC-ACC-02`** | `saudi_traffic_accidents_2019_2024.csv` | Tabular CSV | One row per collision event | 5,066 rows | `accident_id, date, city_id, road_name, severity, primary_cause, vehicles_involved, casualties_count` | GASTAT Road Safety Bulletins & Ministry of Transport Open Data Portal |
| **`SRC-TEL-03`** | `av_telemetry_failures_saudi.csv` | Tabular CSV | One row per vehicle trip | 15,000 rows (50 AV units) | `telemetry_id, date, city_id, vehicle_id, speed_kmh, battery_temp_c, gpu_temp_c, lidar_attenuation_pct, camera_glare_index, failure_type, av_disengagement` | California DMV Disengagement Reports & Fraunhofer Sensor Degradation Physics |

---

## 4. Target Entities
1. **City Hub:** Natural key `city_id` (e.g., `RUH`, `JED`, `DMM`, `ABH`, `ULA`), coordinates, and climate classifications.
2. **Observation Date:** Time dimension linking daily synoptic weather, traffic collisions, and fleet telemetry.
3. **Weather Hazard Profile:** Mapping WMO meteorological codes to quantitative sensor risk levels (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`).
4. **AV Failure Mode:** Formal automotive component failure classifications (LiDAR occlusion, camera solar glare, battery throttling, tire delamination).
5. **Daily Operational Risk:** Consolidated fact entity scoring daily safety and sensor viability.

---

## 5. Architectural Layers (SQL Server Schemas)
All layers coexist inside a single SQL Server database (`av_ready_saudi_dw`):

* **`bronze`:** Landing tables storing incoming data verbatim as `VARCHAR NULL` to prevent ingestion aborts. Adds provenance columns `source_file` and `ingested_at`.
* **`silver`:** Cleaned, strongly-typed, and deduplicated tables (`DATE`, `DECIMAL`, `INT`, `BIT`). Defective or unparseable records are quarantined in `silver.reject_log` with actionable diagnostic reasons. Adds technical audit column `DW_create_date`.
* **`gold`:** Dimensional Star Schema optimized for OLAP cubes and analytical queries. Contains dimensions (`dim_*`), fact tables (`fact_*` with explicitly declared grain), and model-ready feature views (`features_*`).
* **`semantic`:** Enterprise metric catalog (`semantic.metric_catalog`) populated from `semantic/metrics.yml`, accompanied by canonical metric views (`semantic.v_*`).
* **`ml`:** Dedicated schema storing machine learning model predictions, cluster assignments, and evaluation scores written back to SQL via the strict **(SQL $\rightarrow$ Python $\rightarrow$ SQL)** contract.
* **`audit`:** Automated pipeline audit logging (`audit.load_log`) recording execution batch GUIDs, start/end timestamps, rows loaded, and success/failure statuses.

---

## 6. Integration Challenges & Solutions
1. **Spatio-Temporal Mismatch Across Autonomous Sources:**
   * *Challenge:* AV disengagement records from California DMV occur in US geographic coordinates, incompatible with Saudi meteorological stations.
   * *Solution:* Multi-sensor physical calibration and digital twin environmental modeling. Disengagement frequencies and sensor failure functions (Beer-Lambert optical extinction and thermal limits) are dynamically calibrated to daily synoptic weather observations across 10 Saudi cities.
2. **Format and Typing Standardization:**
   * *Challenge:* Dates arrive in varying text strings; numbers contain potential whitespace or null blanks.
   * *Solution:* 6-Verbs transformation pipeline (Trim, Standardize, Convert via `TRY_CONVERT`, Deduplicate via `ROW_NUMBER()`, Validate, and Quarantine to `reject_log`).
3. **Mathematical Pipeline Balance Gate:**
   * *Rule:* Total Bronze rows must equal Silver rows plus quarantined rejects plus duplicates:
     $$\text{Bronze Rows} = \text{Silver Rows} + \text{Reject Log Rows} + \text{Duplicates}$$

---

## 7. SQL Checklist
- [x] Multi-source `JOIN` operations across weather, traffic accidents, and telemetry tables.
- [x] Common Table Expressions (CTEs) for staged data profiling and transformation.
- [x] Window functions (`ROW_NUMBER() OVER (...)`) for deterministic deduplication (`rn = 1`).
- [x] Conditional aggregation (`SUM(CASE WHEN ... THEN 1 ELSE 0 END)`) for climatic event frequency.
- [x] Automated data-quality reconciliation gates.
- [x] Temporal analysis across 6 calendar years (2019–2024).
- [x] Dimensional star schema loading with surrogate key generation.
- [x] Feature engineering views (`gold.features_*`) for data mining algorithms.
- [x] Semantic metric views answering executive business queries.

---

## 8. Mining Checklist
- **Feature Views:** `gold.features_city_monthly` and `gold.features_daily_trip`.
- **Baseline Method:** K-Means Clustering ($K=3$) segmenting Saudi operational design domains into *Optimal*, *Moderate Risk*, and *High Hazard*.
- **Predictive Method:** Decision Tree Classifier / Random Forest predicting autonomous disengagements (`av_disengagement = True`) based on environmental sensor stress.
- **Contract:** SQL $\rightarrow$ Python $\rightarrow$ SQL. All model artifacts write results to `ml.city_risk_clusters` and `ml.trip_risk_predictions` with `model_name`, `model_version`, `run_id`, and `generated_at`.

---

## 9. Milestones & Delivery Schedule
* **M1 (Completed):** Problem Statement, Source Contract, Data Register, Data Dictionary, Naming Conventions.
* **M2:** Database Initialization, Audit Table, Bronze Landing Tables, Automated Batch Loader with Provenance.
* **M3:** Silver Layer Ingestion, 6-Verbs Cleansing, Reject Quarantine, Reconciliation Proof.
* **M4:** Gold Dimensional Star Schema, Documented Grain Fact Tables, Semantic Layer (`metrics.yml`), Feature Views.
* **M5:** Data Mining Pipeline (Clustering & Classification) writing back to `ml.*`.
* **M6:** Business Analytics SQL Scripts & Reporting Dashboards.
* **M7:** Executive Presentation, Final Report, and Repository Defense.
