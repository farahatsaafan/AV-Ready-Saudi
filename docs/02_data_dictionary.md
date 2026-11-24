# Data Dictionary — AV-Ready-Saudi

Generated from the DDL in `sql/01_bronze.sql`, `sql/02_silver.sql`, `sql/03_gold.sql` (same content as `docs/data_dictionary.csv`).
Bronze columns are all text by design; Silver/prep/Gold are typed.


## bronze.noaa_hourly (Bronze)

| Column | Type | Null | Description |
|---|---|---|---|
| `source_file` | NVARCHAR(400) | YES | raw file the row came from (path under Data/raw) |
| `source_row_num` | NVARCHAR(20) | YES | line number in the raw file |
| `STATION` | NVARCHAR(50) | YES | NOAA station id (USAF+WBAN) |
| `DATE` | NVARCHAR(50) | YES | observation time, UTC (ISO 8601) |
| `SOURCE` | NVARCHAR(20) | YES | ISD data source flag |
| `LATITUDE` | NVARCHAR(50) | YES | station latitude |
| `LONGITUDE` | NVARCHAR(50) | YES | station longitude |
| `ELEVATION` | NVARCHAR(50) | YES | station elevation (m) |
| `NAME` | NVARCHAR(200) | YES | station name |
| `REPORT_TYPE` | NVARCHAR(20) | YES | report type (FM-15 METAR, FM-12 SYNOP, FM-16 SPECI, SOD/SOM summaries) |
| `CALL_SIGN` | NVARCHAR(20) | YES | call sign |
| `QUALITY_CONTROL` | NVARCHAR(20) | YES | ISD QC process |
| `WND` | NVARCHAR(50) | YES | wind group dir,q,type,speed(0.1 m/s),q |
| `CIG` | NVARCHAR(50) | YES | ceiling group |
| `VIS` | NVARCHAR(50) | YES | visibility group distance(m),q,var,q |
| `TMP` | NVARCHAR(50) | YES | air temperature group (0.1 degC),q |
| `DEW` | NVARCHAR(50) | YES | dew point group |
| `SLP` | NVARCHAR(50) | YES | sea-level pressure group |
| `AA1` | NVARCHAR(50) | YES | liquid precipitation group period(h),depth(0.1 mm),cond,q |
| `MW1` | NVARCHAR(50) | YES | manual present weather (WMO 4677),q |
| `AW1` | NVARCHAR(50) | YES | automated present weather (WMO 4680),q |
| `AU1` | NVARCHAR(50) | YES | METAR-style present weather intensity,descriptor,precip,obscuration,other,combo,q |
| `extra_json` | NVARCHAR(MAX) | YES | all other columns of the raw row as {header: value} |
| `row_end` | NVARCHAR(10) | YES | line-end marker from landing (always ".") |
| `load_batch_id` | UNIQUEIDENTIFIER | YES | Bronze load batch |
| `ingested_at` | DATETIME2 | NO | time the row was loaded |

## bronze.gastat_cells (Bronze)

| Column | Type | Null | Description |
|---|---|---|---|
| `source_file` | NVARCHAR(400) | YES | raw file the row came from (path under Data/raw) |
| `sheet_name` | NVARCHAR(100) | YES | worksheet name |
| `row_num` | NVARCHAR(20) | YES | Excel row number |
| `col_num` | NVARCHAR(20) | YES | Excel column number |
| `cell_value` | NVARCHAR(MAX) | YES | cell text as stored (formulas kept as text) |
| `row_end` | NVARCHAR(10) | YES | line-end marker from landing (always ".") |
| `load_batch_id` | UNIQUEIDENTIFIER | YES | Bronze load batch |
| `ingested_at` | DATETIME2 | NO | time the row was loaded |

## bronze.dmv_disengagements (Bronze)

| Column | Type | Null | Description |
|---|---|---|---|
| `source_file` | NVARCHAR(400) | YES | raw file the row came from (path under Data/raw) |
| `source_row_num` | NVARCHAR(20) | YES | line number in the raw file |
| `manufacturer` | NVARCHAR(400) | YES | AV company |
| `permit_number` | NVARCHAR(100) | YES | DMV permit number |
| `date_raw` | NVARCHAR(100) | YES | date as written in the report |
| `vin` | NVARCHAR(100) | YES | vehicle identification number |
| `capable_without_driver` | NVARCHAR(100) | YES | vehicle capable of driverless operation (Yes/No) |
| `driver_present` | NVARCHAR(100) | YES | driver present (Yes/No) |
| `initiated_by` | NVARCHAR(200) | YES | who initiated the disengagement |
| `location` | NVARCHAR(200) | YES | disengagement location as written |
| `description` | NVARCHAR(MAX) | YES | facts causing the disengagement (free text) |
| `extra_json` | NVARCHAR(MAX) | YES | all other columns of the raw row as {header: value} |
| `row_end` | NVARCHAR(10) | YES | line-end marker from landing (always ".") |
| `load_batch_id` | UNIQUEIDENTIFIER | YES | Bronze load batch |
| `ingested_at` | DATETIME2 | NO | time the row was loaded |

## bronze.dmv_mileage (Bronze)

| Column | Type | Null | Description |
|---|---|---|---|
| `source_file` | NVARCHAR(400) | YES | raw file the row came from (path under Data/raw) |
| `source_row_num` | NVARCHAR(20) | YES | line number in the raw file |
| `manufacturer` | NVARCHAR(400) | YES | AV company |
| `permit_number` | NVARCHAR(100) | YES | DMV permit number |
| `vin` | NVARCHAR(100) | YES | vehicle identification number |
| `annual_disengagements` | NVARCHAR(100) | YES | annual total of disengagements for the vehicle |
| `months_json` | NVARCHAR(MAX) | YES | month columns ("DEC 2020", "JAN 2021"...) and ANNUAL TOTAL as JSON |
| `row_end` | NVARCHAR(10) | YES | line-end marker from landing (always ".") |
| `load_batch_id` | UNIQUEIDENTIFIER | YES | Bronze load batch |
| `ingested_at` | DATETIME2 | NO | time the row was loaded |

## bronze.nhtsa_sgo_ads (Bronze)

| Column | Type | Null | Description |
|---|---|---|---|
| `source_file` | NVARCHAR(400) | YES | raw file the row came from (path under Data/raw) |
| `source_row_num` | NVARCHAR(20) | YES | line number in the raw file |
| `Report ID` | NVARCHAR(100) | YES | NHTSA report id |
| `Report Version` | NVARCHAR(20) | YES | report version (higher = newer) |
| `Reporting Entity` | NVARCHAR(200) | YES | company that filed the report |
| `Make` | NVARCHAR(200) | YES | vehicle make |
| `Model` | NVARCHAR(200) | YES | vehicle model |
| `Model Year` | NVARCHAR(50) | YES | vehicle model year |
| `State` | NVARCHAR(50) | YES | US state |
| `City` | NVARCHAR(200) | YES | city |
| `Incident Date` | NVARCHAR(50) | YES | incident month (MMM-YYYY) |
| `Incident Time (24:00)` | NVARCHAR(50) | YES | incident local time |
| `Roadway Type` | NVARCHAR(100) | YES | roadway type |
| `Posted Speed Limit (MPH)` | NVARCHAR(50) | YES | posted speed limit |
| `Lighting` | NVARCHAR(100) | YES | lighting condition (archive file only) |
| `row_json` | NVARCHAR(MAX) | YES | the complete raw row as {header: value} |
| `row_end` | NVARCHAR(10) | YES | line-end marker from landing (always ".") |
| `load_batch_id` | UNIQUEIDENTIFIER | YES | Bronze load batch |
| `ingested_at` | DATETIME2 | NO | time the row was loaded |

## silver.dim_region (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `region_code` | CHAR(3) | NO | Saudi administrative region code (3 letters) |
| `region_name_en` | NVARCHAR(50) | NO | region name, English |
| `region_name_ar` | NVARCHAR(50) | NO | region name, Arabic |

## silver.region_alias (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `alias_key` | NVARCHAR(60) | NO | normalised region label (lower case, no spaces/hyphens/"region"/"province") |
| `region_code` | CHAR(3) | NO | Saudi administrative region code (3 letters) |

## silver.dim_station (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `station_id` | CHAR(11) | NO | NOAA station id |
| `station_name` | NVARCHAR(80) | NO | station name |
| `country` | CHAR(2) | NO | SA or US |
| `region_code` | CHAR(3) | YES | Saudi administrative region code (3 letters) |
| `us_state` | CHAR(2) | YES | US state code (US stations) |
| `tz_name` | VARCHAR(60) | NO | Windows time-zone name used with AT TIME ZONE |
| `latitude` | FLOAT | NO | latitude |
| `longitude` | FLOAT | NO | longitude |

## silver.gastat_sheet_map (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `file_key` | NVARCHAR(80) | NO | part of the workbook file name |
| `sheet_name` | NVARCHAR(20) | NO | worksheet name |
| `metric` | VARCHAR(30) | NO | serious / serious_within / serious_outside / deaths / injuries |
| `data_year` | SMALLINT | NO | year the value refers to |
| `col_num` | INT | NO | Excel column that holds the value |
| `first_row` | INT | NO | first data row |
| `last_row` | INT | NO | last data row |

## silver.reject_log (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `reject_id` | BIGINT | NO | surrogate key |
| `source_table` | VARCHAR(60) | NO | Silver table the row was meant for |
| `source_file` | NVARCHAR(400) | YES | raw file the row came from (path under Data/raw) |
| `source_row` | NVARCHAR(40) | YES | row reference in the source |
| `reason` | VARCHAR(200) | NO | rule that rejected the row |
| `raw_value` | NVARCHAR(400) | YES | offending value |
| `dw_create_date` | DATETIME2 | NO | time the Silver row was written |

## silver.weather_obs (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `station_id` | CHAR(11) | NO | NOAA station id |
| `obs_utc` | DATETIME2(0) | NO | observation time UTC |
| `obs_local` | DATETIME2(0) | NO | observation time, station local time |
| `report_type` | VARCHAR(10) | NO | report type (trimmed) |
| `vis_m` | INT | YES | visibility in metres (NULL if missing or suspect) |
| `temp_c` | DECIMAL(5,1) | YES | air temperature degC |
| `wind_ms` | DECIMAL(5,1) | YES | wind speed m/s |
| `precip_1h_mm` | DECIMAL(6,1) | YES | 1-hour precipitation mm |
| `mw_code` | CHAR(2) | YES | manual present-weather code (WMO 4677) |
| `aw_code` | CHAR(2) | YES | automated present-weather code (WMO 4680) |
| `au_precip` | CHAR(2) | YES | METAR precipitation code |
| `au_obscuration` | CHAR(1) | YES | METAR obscuration code |
| `au_other` | CHAR(1) | YES | METAR other-phenomena code |
| `sun_elev_deg` | DECIMAL(6,2) | YES | solar elevation (degrees) |
| `is_dust` | BIT | NO | dust or sand reported |
| `is_haze` | BIT | NO | haze or smoke reported |
| `is_fog` | BIT | NO | fog reported |
| `is_rain` | BIT | NO | rain/precipitation reported or measured |
| `is_low_vis` | BIT | NO | visibility < 5 km |
| `is_night` | BIT | NO | sun below the horizon (elevation < -0.833 deg) |
| `source_file` | NVARCHAR(400) | NO | raw file the row came from (path under Data/raw) |
| `source_row_num` | INT | NO | line number in the raw file |
| `dw_create_date` | DATETIME2 | NO | time the Silver row was written |

## silver.accidents_region_year (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `region_code` | CHAR(3) | NO | Saudi administrative region code (3 letters) |
| `data_year` | SMALLINT | NO | year the value refers to |
| `serious_accidents` | INT | YES | serious traffic accidents in the year |
| `serious_within_cities` | INT | YES | serious accidents within cities (2024-2025) |
| `serious_outside_cities` | INT | YES | serious accidents outside cities (2024-2025) |
| `deaths` | INT | YES | road traffic deaths |
| `injuries` | INT | YES | road traffic injuries |
| `source_files` | NVARCHAR(400) | YES | GASTAT workbooks the values came from |
| `dw_create_date` | DATETIME2 | NO | time the Silver row was written |

## silver.dmv_disengagement (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `disengagement_id` | BIGINT | NO | surrogate key |
| `report_file` | NVARCHAR(400) | NO | DMV report file |
| `source_row_num` | INT | NO | line number in the raw file |
| `program` | VARCHAR(20) | NO | drivered / driverless / first_time |
| `manufacturer` | NVARCHAR(200) | NO | AV company |
| `permit_number` | NVARCHAR(50) | YES | DMV permit number |
| `vin` | NVARCHAR(50) | YES | vehicle identification number |
| `event_date` | DATE | NO | disengagement date |
| `initiated_by` | VARCHAR(20) | NO | who initiated the disengagement |
| `location_type` | VARCHAR(20) | NO | street / highway_freeway / parking / other |
| `cause_category` | VARCHAR(30) | NO | environment / perception / localization / system_fault / control / prediction / planning / precautionary / other (keyword rules) |
| `description` | NVARCHAR(MAX) | YES | facts causing the disengagement (free text) |
| `dw_create_date` | DATETIME2 | NO | time the Silver row was written |

## silver.dmv_mileage_monthly (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `permit_number` | NVARCHAR(50) | NO | DMV permit number |
| `vin` | NVARCHAR(50) | NO | vehicle identification number |
| `manufacturer` | NVARCHAR(200) | NO | AV company |
| `month_start` | DATE | NO | first day of the month |
| `miles` | DECIMAL(14,2) | NO | autonomous miles driven in the month |
| `dw_create_date` | DATETIME2 | NO | time the Silver row was written |

## silver.nhtsa_crash (Silver)

| Column | Type | Null | Description |
|---|---|---|---|
| `report_id` | NVARCHAR(100) | NO | NHTSA report id |
| `report_version` | INT | NO | latest version kept |
| `source_file` | NVARCHAR(400) | NO | raw file the row came from (path under Data/raw) |
| `reporting_entity` | NVARCHAR(200) | YES | company that filed the report |
| `make` | NVARCHAR(200) | YES | vehicle make |
| `model` | NVARCHAR(200) | YES | vehicle model |
| `us_state` | CHAR(2) | YES | US state code (US stations) |
| `city` | NVARCHAR(200) | YES | city |
| `incident_month` | DATE | YES | incident month |
| `incident_time` | TIME(0) | YES | incident local time |
| `roadway_type` | VARCHAR(20) | NO | street / intersection / highway_freeway / parking / other |
| `speed_limit_mph` | INT | YES | posted speed limit |
| `lighting_raw` | NVARCHAR(100) | YES | reported lighting |
| `w_clear` | BIT | NO | weather flag clear |
| `w_cloudy` | BIT | NO | weather flag cloudy / partly cloudy |
| `w_rain` | BIT | NO | weather flag rain |
| `w_snow` | BIT | NO | weather flag snow |
| `w_fog_smoke_haze` | BIT | NO | weather flag fog/smoke/haze |
| `w_dust` | BIT | NO | weather flag dust storm |
| `w_wind` | BIT | NO | weather flag severe wind |
| `w_unknown` | BIT | NO | weather unknown |
| `weather_bucket` | VARCHAR(10) | NO | normal / rain / obscured / unknown |
| `is_night` | BIT | YES | sun below the horizon (elevation < -0.833 deg) |
| `in_scope` | BIT | NO | CA/AZ/TX and incident year 2021-2025 |
| `dw_create_date` | DATETIME2 | NO | time the Silver row was written |

## prep.weather_station_hour (prep (Gold work))

| Column | Type | Null | Description |
|---|---|---|---|
| `station_id` | CHAR(11) | NO | NOAA station id |
| `hour_local` | DATETIME2(0) | NO | local clock hour |
| `local_date` | DATE | NO | local date |
| `n_reports` | INT | NO | reports in the hour |
| `temp_c` | DECIMAL(5,1) | YES | air temperature degC |
| `temp_max_c` | DECIMAL(5,1) | YES | max temperature degC |
| `wind_max_ms` | DECIMAL(5,1) | YES | max wind m/s |
| `precip_mm` | DECIMAL(6,1) | YES | precipitation mm |
| `is_dust` | BIT | NO | dust or sand reported |
| `is_haze` | BIT | NO | haze or smoke reported |
| `is_fog` | BIT | NO | fog reported |
| `is_low_vis` | BIT | NO | visibility < 5 km |
| `is_obscured` | BIT | NO | dust OR haze OR fog OR visibility < 5 km |
| `is_rain` | BIT | NO | rain/precipitation reported or measured |
| `is_night` | BIT | NO | sun below the horizon (elevation < -0.833 deg) |
| `hour_bucket` | VARCHAR(10) | NO | obscured > rain > normal |

## prep.weather_station_day (prep (Gold work))

| Column | Type | Null | Description |
|---|---|---|---|
| `station_id` | CHAR(11) | NO | NOAA station id |
| `local_date` | DATE | NO | local date |
| `hours_observed` | INT | NO | hours with at least one report |
| `dust_hours` | INT | NO | hours with dust |
| `obscured_hours` | INT | NO | obscured hours |
| `rain_hours` | INT | NO | rain hours |
| `day_type` | VARCHAR(10) | NO | obscured (>=3 obscured h) > rain (>=1 rain h) > normal |

## prep.saudi_region_month (prep (Gold work))

| Column | Type | Null | Description |
|---|---|---|---|
| `region_code` | CHAR(3) | NO | Saudi administrative region code (3 letters) |
| `station_id` | CHAR(11) | NO | NOAA station id |
| `month_start` | DATE | NO | first day of the month |
| `hours_observed` | INT | YES | hours with at least one report |
| `temp_mean_c` | DECIMAL(5,1) | YES | mean of hourly temperatures degC |
| `temp_max_c` | DECIMAL(5,1) | YES | max temperature degC |
| `wind_max_ms` | DECIMAL(5,1) | YES | max wind m/s |
| `rain_mm` | DECIMAL(8,1) | YES | sum of 1-hour precipitation mm |
| `dust_hours` | INT | YES | hours with dust |
| `haze_hours` | INT | YES | hours with haze |
| `fog_hours` | INT | YES | hours with fog |
| `low_vis_hours` | INT | YES | hours with visibility < 5 km |
| `obscured_hours` | INT | YES | obscured hours |
| `rain_hours` | INT | YES | rain hours |
| `normal_hours` | INT | YES | normal hours |
| `night_hours` | INT | YES | night hours |
| `days_observed` | INT | YES | days with data |
| `dust_days` | INT | YES | days with any dust hour |
| `obscured_days` | INT | YES | obscured days |
| `rain_days` | INT | YES | rain days |
| `normal_days` | INT | YES | normal days |

## prep.av_relative_risk (prep (Gold work))

| Column | Type | Null | Description |
|---|---|---|---|
| `event_source` | VARCHAR(20) | NO | nhtsa_crash / dmv_disengagement |
| `factor` | VARCHAR(10) | NO | weather / light |
| `level` | VARCHAR(10) | NO | normal, rain, obscured / day, night |
| `events` | INT | NO | events in the level |
| `event_share` | FLOAT | YES | share of events |
| `exposure` | FLOAT | YES | fleet miles on those days (disengagements) |
| `exposure_share` | FLOAT | YES | share of exposure |
| `relative_risk` | FLOAT | YES | (event share / exposure share) / same for reference level |
| `used_in_index` | BIT | YES | 1 if events >= 30 |

## gold.av_readiness_region_month (Gold)

| Column | Type | Null | Description |
|---|---|---|---|
| `region_code` | CHAR(3) | NO | Saudi administrative region code (3 letters) |
| `region_name_en` | NVARCHAR(50) | NO | region name, English |
| `region_name_ar` | NVARCHAR(50) | NO | region name, Arabic |
| `weather_station_id` | CHAR(11) | NO | NOAA station that represents the region |
| `year` | SMALLINT | NO | calendar year |
| `month` | TINYINT | NO | calendar month |
| `month_start` | DATE | NO | first day of the month |
| `season` | VARCHAR(6) | NO | winter (DJF) / spring / summer / autumn |
| `wx_hours_observed` | INT | YES | hours of the month with weather data |
| `wx_hours_in_month` | INT | NO | hours in the month |
| `wx_coverage_pct` | DECIMAL(5,1) | YES | observed / total hours % |
| `temp_mean_c` | DECIMAL(5,1) | YES | mean of hourly temperatures degC |
| `temp_max_c` | DECIMAL(5,1) | YES | max temperature degC |
| `wind_max_ms` | DECIMAL(5,1) | YES | max wind m/s |
| `rain_mm` | DECIMAL(8,1) | YES | sum of 1-hour precipitation mm |
| `share_dust_hours` | DECIMAL(6,4) | YES | share of hours with dust |
| `share_haze_hours` | DECIMAL(6,4) | YES | share of hours with haze/smoke |
| `share_fog_hours` | DECIMAL(6,4) | YES | share of hours with fog |
| `share_low_vis_hours` | DECIMAL(6,4) | YES | share of hours with visibility < 5 km |
| `share_obscured_hours` | DECIMAL(6,4) | YES | share of obscured hours |
| `share_rain_hours` | DECIMAL(6,4) | YES | share of rain hours (not obscured) |
| `share_normal_hours` | DECIMAL(6,4) | YES | share of normal hours |
| `share_night_hours` | DECIMAL(6,4) | YES | share of night hours |
| `days_observed` | INT | YES | days with data |
| `dust_days` | INT | YES | days with any dust hour |
| `obscured_days` | INT | YES | obscured days |
| `rain_days` | INT | YES | rain days |
| `normal_days` | INT | YES | normal days |
| `acc_year_serious` | INT | YES | serious accidents in the region in that year (GASTAT) |
| `acc_year_deaths` | INT | YES | deaths in the region in that year |
| `acc_year_injuries` | INT | YES | injuries in the region in that year |
| `acc_year_serious_within_cities` | INT | YES | serious accidents within cities (2024-2025) |
| `acc_year_serious_outside_cities` | INT | YES | serious accidents outside cities (2024-2025) |
| `acc_share_outside_cities` | DECIMAL(6,4) | YES | outside / (within + outside) |
| `acc_serious_month_avg` | DECIMAL(9,2) | YES | annual serious accidents / 12 (even split, not observed) |
| `av_rr_crash_rain` | DECIMAL(9,4) | YES | relative risk of an AV crash in rain (NHTSA) |
| `av_rr_crash_obscured` | DECIMAL(9,4) | YES | relative risk of an AV crash in obscured conditions (NULL: < 30 events) |
| `av_rr_crash_night` | DECIMAL(9,4) | YES | relative risk of an AV crash at night (stored, not in index) |
| `av_rr_diseng_rain_day` | DECIMAL(9,4) | YES | relative risk of a disengagement on a rain day (CA DMV) |
| `av_rr_diseng_obscured_day` | DECIMAL(9,4) | YES | relative risk of a disengagement on an obscured day (CA DMV) |
| `av_crash_risk_index` | DECIMAL(9,4) | YES | condition mix x crash relative risks (1 = normal only) |
| `av_diseng_risk_index` | DECIMAL(9,4) | YES | day-type mix x disengagement relative risks (1 = normal only) |
| `src_weather` | NVARCHAR(200) | NO | weather lineage |
| `src_accidents` | NVARCHAR(400) | YES | accident lineage (workbooks) |
| `src_av` | NVARCHAR(200) | NO | AV lineage |
| `gold_batch_id` | UNIQUEIDENTIFIER | NO | Gold load batch |
| `gold_loaded_at` | DATETIME2 | NO | time Gold was loaded |
