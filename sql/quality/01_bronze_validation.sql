-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 01_bronze_validation.sql
-- Purpose: Validate Bronze layer landing completeness, row counts, and defect profiling.
-- Reference: Unit 2 Lab 3 (Steps 5 & 7: Expected vs Loaded Reconciliation & Profiling)
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Reconciliation: Expected Rows vs Loaded Rows Gate
-- ------------------------------------------------------------------------------
SELECT 'Saudi Weather (Open-Meteo 2019-2024)' AS dataset_source,
       21920 AS expected_rows,
       COUNT_BIG(*) AS loaded_rows,
       CASE WHEN COUNT_BIG(*) = 21920 THEN 'MATCH' ELSE 'MISMATCH' END AS status_flag
FROM bronze.sa_weather
UNION ALL
SELECT 'Saudi Highway Traffic Accidents',
       5066 AS expected_rows,
       COUNT_BIG(*) AS loaded_rows,
       CASE WHEN COUNT_BIG(*) = 5066 THEN 'MATCH' ELSE 'MISMATCH' END
FROM bronze.sa_traffic_accidents
UNION ALL
SELECT 'Autonomous Vehicle Fleet Telemetry & Failures',
       15000 AS expected_rows,
       COUNT_BIG(*) AS loaded_rows,
       CASE WHEN COUNT_BIG(*) = 15000 THEN 'MATCH' ELSE 'MISMATCH' END
FROM bronze.av_telemetry;
GO

-- ------------------------------------------------------------------------------
-- 2. Profiling Saudi Weather Columns for Blanks / Nulls
-- ------------------------------------------------------------------------------
SELECT 
    COUNT(*) AS total_weather_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(city_id)), '') IS NULL THEN 1 ELSE 0 END) AS missing_city_id,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM([date])), '') IS NULL THEN 1 ELSE 0 END) AS missing_date,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(temp_max_c)), '') IS NULL THEN 1 ELSE 0 END) AS missing_temp_max,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(wind_speed_max_kmh)), '') IS NULL THEN 1 ELSE 0 END) AS missing_wind_speed,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(is_dust_storm)), '') IS NULL THEN 1 ELSE 0 END) AS missing_dust_flag
FROM bronze.sa_weather;
GO

-- ------------------------------------------------------------------------------
-- 3. Profiling AV Telemetry Failures Breakdown
-- ------------------------------------------------------------------------------
SELECT 
    ISNULL(NULLIF(LTRIM(RTRIM(failure_type)), ''), 'BLANK_DEFECT') AS failure_type_raw,
    ISNULL(NULLIF(LTRIM(RTRIM(severity)), ''), 'BLANK_DEFECT') AS severity_raw,
    COUNT(*) AS record_count
FROM bronze.av_telemetry
GROUP BY failure_type, severity
ORDER BY record_count DESC;
GO

-- ------------------------------------------------------------------------------
-- 4. Profiling Saudi Traffic Accidents by Cause
-- ------------------------------------------------------------------------------
SELECT 
    ISNULL(NULLIF(LTRIM(RTRIM(primary_cause)), ''), 'BLANK_DEFECT') AS primary_cause_raw,
    COUNT(*) AS accident_count,
    SUM(TRY_CONVERT(INT, vehicles_involved)) AS total_vehicles,
    SUM(TRY_CONVERT(INT, casualties_count)) AS total_casualties
FROM bronze.sa_traffic_accidents
GROUP BY primary_cause
ORDER BY accident_count DESC;
GO

-- ------------------------------------------------------------------------------
-- 5. Audit Log Inspection: Verify Batch Execution Results
-- ------------------------------------------------------------------------------
SELECT TOP 10
    load_id,
    batch_id,
    source_name,
    target_table,
    start_time,
    end_time,
    DATEDIFF(MILLISECOND, start_time, end_time) AS duration_ms,
    rows_loaded,
    status,
    message
FROM audit.load_log
ORDER BY load_id DESC;
GO
