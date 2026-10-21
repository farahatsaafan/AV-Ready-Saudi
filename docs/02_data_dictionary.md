# AV-Ready-Saudi: Enterprise Data Dictionary

## 1. Overview & Attribute Taxonomy
In compliance with Unit 1 (Lesson 1.2), attributes are classified into their formal statistical types:
* **Nominal**: Categorical identifiers with no intrinsic rank (e.g., `city`, `region`, `weather_condition`).
* **Ordinal**: Categorical values with a meaningful hierarchical ranking (e.g., `sensor_hazard_level`, `av_operating_class`).
* **Interval**: Ordered numeric variables with arbitrary zero points (e.g., calendar dates `weather_date`, timestamps).
* **Ratio**: Quantitative variables with an absolute zero point where ratios are physically meaningful (e.g., `temp_c`, `visibility_km`, `wind_kmh`, `indicator_value`).

---

## 2. Table Specifications

### A. Table: `silver.sa_weather`
Consolidated historical hourly meteorological observations across major Saudi cities.

| Column Name | Business Meaning | Statistical Type | Physical Type | Nullable | Accepted Domain / Rules | Known Caveats |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- |
| `weather_id` | Surrogate Primary Key | Nominal | `INT IDENTITY` | NO | Integer $\ge 1$ | Generated automatically |
| `city` | Saudi Observation City | Nominal | `NVARCHAR(100)` | NO | 'Riyadh', 'Jeddah', 'Hail', 'Qassim', etc. | Trimmed and title-cased |
| `weather_date` | Date of Observation | Interval | `DATE` | NO | '2017-01-01' to '2019-12-31' | Converted from raw string |
| `weather_time` | Time of Observation | Interval | `TIME(0)` | YES | '00:00:00' to '23:59:59' | Hourly intervals |
| `weather_year` | Year component | Interval | `INT` | NO | 2017, 2018, 2019 | Extracted for fast indexing |
| `weather_month`| Month component | Interval | `INT` | NO | 1 to 12 | Used in seasonal mining |
| `weather_day`  | Day of month | Interval | `INT` | NO | 1 to 31 | Partitioning attribute |
| `weather_hour` | Hour of day (24-hour) | Interval | `INT` | NO | 0 to 23 | Diurnal analysis |
| `weather_condition` | Weather description | Nominal | `NVARCHAR(100)` | NO | 'CLEAR', 'DUSTSTORM', 'FOG', etc. | Standardized uppercase |
| `temp_c` | Ambient Temperature in °C | Ratio | `DECIMAL(6,2)` | YES | $-10.0$ to $60.0$ | Mandatory threshold rule: extreme temperatures $>65$ rejected |
| `wind_kmh` | Wind speed in km/h | Ratio | `DECIMAL(6,2)` | YES | $\ge 0.0$ | Optional attribute |
| `humidity_pct`| Relative humidity percentage | Ratio | `DECIMAL(5,2)` | YES | $0.0$ to $100.0$ | '%' character stripped in Silver |
| `barometer_mbar`| Atmospheric pressure (mbar) | Ratio | `DECIMAL(8,2)` | YES | $900.0$ to $1100.0$ | Barometric pressure |
| `visibility_km`| Horizontal visibility (km) | Ratio | `DECIMAL(6,2)` | YES | $0.0$ to $50.0$ | Critical for LiDAR range checks |
| `DW_create_date`| Ingestion timestamp | Interval | `DATETIME2` | NO | System timestamp | Audit & metadata control |

---

### B. Table: `silver.sa_traffic_accidents`
Official statistical records of road traffic incidents, casualties, and injuries by Saudi administrative regions.

| Column Name | Business Meaning | Statistical Type | Physical Type | Nullable | Accepted Domain / Rules |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `accident_id` | Surrogate Primary Key | Nominal | `INT IDENTITY` | NO | Integer $\ge 1$ |
| `accident_year`| Reporting calendar year | Interval | `INT` | NO | 2008 to 2019 |
| `region` | Administrative Region | Nominal | `NVARCHAR(100)` | NO | 'RIYADH', 'MAKKAH', 'EASTERN PROVINCE', etc. |
| `indicator` | Metric Type | Nominal | `NVARCHAR(100)` | NO | 'NO. OF ACCIDENTS', 'NO. OF CASUALTIES - DEAD', 'NO. OF CASUALTIES - INJURED' |
| `indicator_value`| Total Count | Ratio | `INT` | NO | Value $\ge 0$ |
| `latitude` | Geographic centroid lat | Ratio | `DECIMAL(10,6)` | YES | Range $16.0$ to $32.5$ |
| `longitude`| Geographic centroid lon | Ratio | `DECIMAL(10,6)` | YES | Range $36.0$ to $55.0$ |

---

### C. Table: `silver.av_telemetry`
High-frequency vehicle state telemetry from autonomous test runs.

| Column Name | Business Meaning | Statistical Type | Physical Type | Nullable | Accepted Domain / Rules |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `telemetry_id` | Surrogate Primary Key | Nominal | `INT IDENTITY` | NO | Integer $\ge 1$ |
| `frame_id` | Sensor recording frame | Nominal | `BIGINT` | NO | Unique sequence integer |
| `timestamp_val` | POSIX Epoch Timestamp | Ratio | `DECIMAL(20,6)` | NO | High precision microsecond epoch |
| `pos_x` | Local X Coordinate (meters)| Ratio | `DECIMAL(12,4)` | NO | Cartesian coordinate |
| `pos_y` | Local Y Coordinate (meters)| Ratio | `DECIMAL(12,4)` | NO | Cartesian coordinate |
| `pos_z` | Local Z Coordinate (meters)| Ratio | `DECIMAL(12,4)` | NO | Altitude / vertical displacement |
| `q_x`, `q_y`, `q_z`, `q_w` | Unit Quaternion components | Ratio | `DECIMAL(10,6)` | YES | Vehicle 3D orientation |

---

### D. Table: `silver.reject_log`
Quarantine table capturing failed records with technical root causes.

| Column Name | Business Meaning | Physical Type | Nullable | Example Value |
| :--- | :--- | :--- | :---: | :--- |
| `reject_id` | Rejection log identifier | `BIGINT IDENTITY` | NO | 1, 2, ... |
| `source_table` | Originating Bronze source | `VARCHAR(50)` | NO | 'bronze.sa_weather' |
| `business_key` | Identifier of failed record | `VARCHAR(100)` | YES | 'RowID:23091' |
| `reason` | Explicit business rule broken | `VARCHAR(200)` | NO | 'out-of-range temperature' |
| `DW_create_date`| Rejection timestamp | `DATETIME2` | NO | `2026-10-21 22:25:08` |
