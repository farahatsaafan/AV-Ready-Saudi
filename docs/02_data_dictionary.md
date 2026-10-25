# AV-Ready-Saudi: Enterprise Data Dictionary

## 1. Overview & Attribute Taxonomy
In compliance with Unit 1 (Lesson 1.2), attributes are classified into their formal statistical types:
* **Nominal**: Categorical identifiers with no intrinsic rank (e.g., `city_id`, `road_name`, `failure_type`).
* **Ordinal**: Categorical values with a meaningful hierarchical ranking (e.g., `severity`, `sensor_hazard_level`, `av_operating_class`).
* **Interval**: Ordered numeric variables with arbitrary zero points (e.g., calendar dates `weather_date`, `accident_date`).
* **Ratio**: Quantitative variables with an absolute zero point where ratios are physically meaningful (e.g., `temp_max_c`, `speed_kmh`, `battery_temp_c`, `tire_pressure_psi`, `lidar_attenuation_pct`).

---

## 2. Table Specifications

### A. Table: `silver.sa_weather`
Consolidated historical daily meteorological observations across 10 major Saudi cities (2019 - 2024).

| Column Name | Business Meaning | Statistical Type | Physical Type | Nullable | Accepted Domain / Rules | Known Caveats |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- |
| `weather_id` | Surrogate Primary Key | Nominal | `INT IDENTITY` | NO | Integer $\ge 1$ | Generated automatically |
| `weather_date` | Date of Observation | Interval | `DATE` | NO | '2019-01-01' to '2024-12-31' | Converted from raw ISO string |
| `weather_year` | Year component | Interval | `INT` | NO | 2019 to 2024 | Extracted for fast indexing |
| `weather_month`| Month component | Interval | `INT` | NO | 1 to 12 | Used in seasonal mining |
| `weather_day`  | Day of month | Interval | `INT` | NO | 1 to 31 | Partitioning attribute |
| `city_id` | 3-Letter City IATA Code | Nominal | `VARCHAR(10)` | NO | 'RUH', 'JED', 'DMM', 'MAK', 'MED', etc. | Composite business key |
| `city_name_en` | English City Name | Nominal | `NVARCHAR(100)` | NO | 'Riyadh', 'Jeddah', 'Dammam', etc. | Trimmed and uppercase |
| `city_name_ar` | Arabic City Name | Nominal | `NVARCHAR(100)` | NO | N'الرياض', N'جدة', N'مكة المكرمة', etc. | UTF-8 UTF-16 supported |
| `latitude` | Geographic Latitude | Ratio | `DECIMAL(10,6)` | NO | Range $16.0$ to $32.5$ | Saudi geographical boundary |
| `longitude`| Geographic Longitude | Ratio | `DECIMAL(10,6)` | NO | Range $34.0$ to $56.0$ | Saudi geographical boundary |
| `temp_max_c` | Peak Daily Temperature (°C) | Ratio | `DECIMAL(5,2)` | NO | $-15.0$ to $65.0$ | Extreme temperatures $>65$ rejected |
| `temp_min_c` | Minimum Daily Temp (°C) | Ratio | `DECIMAL(5,2)` | NO | $-15.0$ to $50.0$ | Minimum diurnal temperature |
| `temp_mean_c`| Mean Daily Temperature (°C)| Ratio | `DECIMAL(5,2)` | NO | $-10.0$ to $55.0$ | 24-hour mean |
| `precipitation_mm`| Daily Total Rainfall (mm) | Ratio | `DECIMAL(6,2)` | NO | $\ge 0.0$ | Flash flood indicator |
| `wind_speed_max_kmh`| Sustained Wind Speed (km/h) | Ratio | `DECIMAL(5,2)` | NO | $\ge 0.0$ | Wind force metric |
| `wind_gusts_max_kmh`| Peak Wind Gusts (km/h) | Ratio | `DECIMAL(5,2)` | NO | $\ge 0.0$ | Severe dust trigger ($>45$) |
| `solar_radiation_mj`| Solar Irradiance ($MJ/m^2$) | Ratio | `DECIMAL(6,2)` | NO | $\ge 0.0$ | Camera glare trigger ($>25$) |
| `weather_code_wmo`| WMO Standard Weather Code | Nominal | `INT` | NO | 0 to 99 | WMO weather classification |
| `is_dust_storm`| Dust Storm Active Flag | Nominal | `BIT` | NO | 0 or 1 | Active particulate hazard |
| `is_extreme_heat`| Extreme Heat Flag ($>45^\circ C$)| Nominal | `BIT` | NO | 0 or 1 | Thermal throttling hazard |
| `DW_create_date`| Ingestion timestamp | Interval | `DATETIME2` | NO | System timestamp | Audit & metadata control |

---

### B. Table: `silver.sa_traffic_accidents`
Highway traffic incident records, casualties, and causes across Saudi transit corridors.

| Column Name | Business Meaning | Statistical Type | Physical Type | Nullable | Accepted Domain / Rules |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `accident_surrogate_id`| Surrogate Primary Key | Nominal | `INT IDENTITY` | NO | Integer $\ge 1$ |
| `accident_id` | Incident Tracking Identifier | Nominal | `VARCHAR(50)` | NO | e.g. 'ACC-SA-100001' |
| `accident_date`| Date of Collision | Interval | `DATE` | NO | '2019-01-01' to '2024-12-31' |
| `accident_year`| Calendar year | Interval | `INT` | NO | 2019 to 2024 |
| `accident_month`| Calendar month | Interval | `INT` | NO | 1 to 12 |
| `city_id` | Nearest City Hub | Nominal | `VARCHAR(10)` | NO | Links to `silver.sa_weather.city_id` |
| `road_name` | Highway / Corridor Name | Nominal | `NVARCHAR(150)` | NO | e.g. 'King Fahd Road', 'Highway 40' |
| `severity` | Impact Severity Tier | Ordinal | `NVARCHAR(50)` | NO | 'FATAL_CHAIN_COLLISION', 'HIGH', 'MEDIUM', 'LOW' |
| `primary_cause` | Root Cause Attribution | Nominal | `NVARCHAR(100)` | NO | 'DUST_STORM_ZERO_VISIBILITY', 'TAILGATING', 'TIRE_BLOWOUT', etc. |
| `vehicles_involved`| Number of Vehicles in Crash| Ratio | `INT` | NO | Integer $\ge 1$ |
| `casualties_count`| Total Injured / Deceased | Ratio | `INT` | NO | Integer $\ge 0$ |
| `weather_condition_code`| Weather code at collision | Nominal | `INT` | YES | Corresponds to WMO code |
| `ambient_temp_c`| Air temperature at collision | Ratio | `DECIMAL(5,2)` | YES | Pavement heating factor |
| `wind_gusts_kmh`| Wind gusts during crash | Ratio | `DECIMAL(5,2)` | YES | Crosswind hazard metric |
| `DW_create_date`| Ingestion timestamp | Interval | `DATETIME2` | NO | Lineage tracking |

---

### C. Table: `silver.av_telemetry`
Autonomous Vehicle operational states, sensor health, and thermal/perception diagnostics.

| Column Name | Business Meaning | Statistical Type | Physical Type | Nullable | Accepted Domain / Rules |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `telemetry_surrogate_id`| Surrogate Primary Key | Nominal | `INT IDENTITY` | NO | Integer $\ge 1$ |
| `telemetry_id` | Telemetry Record Key | Nominal | `VARCHAR(50)` | NO | e.g. 'TEL-TBK-017348' |
| `telemetry_date`| Date of Recording | Interval | `DATE` | NO | '2019-01-01' to '2024-12-31' |
| `city_id` | Operation City Code | Nominal | `VARCHAR(10)` | NO | Links to weather and accidents |
| `vehicle_id` | Autonomous Fleet Unit ID | Nominal | `VARCHAR(50)` | NO | 'AV-SAUDI-001' to 'AV-SAUDI-050' |
| `speed_kmh` | Vehicle Travel Speed | Ratio | `DECIMAL(6,2)` | NO | Range $0.0$ to $250.0$ |
| `battery_temp_c`| Traction Battery Core Temp | Ratio | `DECIMAL(5,2)` | NO | Range $-20.0$ to $100.0$ |
| `gpu_temp_c` | NVIDIA Compute Platform Temp| Ratio | `DECIMAL(5,2)` | NO | Range $20.0$ to $110.0$ |
| `tire_pressure_psi`| Average Tire Pressure | Ratio | `DECIMAL(5,2)` | NO | Range $10.0$ to $80.0$ |
| `lidar_attenuation_pct`| Laser Beam Scattering % | Ratio | `DECIMAL(5,2)` | NO | Range $0.0$ to $100.0$ |
| `camera_glare_index`| Camera Pixel Saturation Index | Ratio | `DECIMAL(4,2)` | NO | Range $0.0$ to $1.0$ |
| `failure_occurred`| Sensor/System Fault Flag | Nominal | `BIT` | NO | 0 (Normal) or 1 (Failure) |
| `failure_type` | Diagnostic Fault Category | Nominal | `NVARCHAR(100)` | NO | 'NONE', 'LIDAR_DUST_OCCLUSION', 'CAMERA_SOLAR_BLINDING', etc. |
| `severity` | Operational Hazard Level | Ordinal | `NVARCHAR(50)` | NO | 'NORMAL', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL' |
| `av_disengagement`| Emergency System Handover | Nominal | `BIT` | NO | 0 (Autonomous) or 1 (Disengaged) |
| `DW_create_date`| Ingestion timestamp | Interval | `DATETIME2` | NO | Lineage tracking |

---

### D. Table: `silver.reject_log`
Quarantine table capturing failed records with technical root causes.

| Column Name | Business Meaning | Physical Type | Nullable | Example Value |
| :--- | :--- | :--- | :---: | :--- |
| `reject_id` | Rejection log identifier | `BIGINT IDENTITY` | NO | 1, 2, ... |
| `source_table` | Originating Bronze source | `VARCHAR(50)` | NO | 'bronze.sa_weather' |
| `business_key` | Identifier of failed record | `VARCHAR(100)` | YES | 'RUH:2023-07-15' |
| `reason` | Explicit business rule broken | `VARCHAR(200)` | NO | 'impossible temperature for Saudi Arabia' |
| `DW_create_date`| Rejection timestamp | `DATETIME2` | NO | `2026-10-25 12:45:00` |
