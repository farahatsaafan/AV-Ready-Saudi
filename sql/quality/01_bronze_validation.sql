-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 01_bronze_validation.sql
-- Purpose: Validate Bronze layer completeness, counts and identify defects.
-- Reference: Unit 2 Lab 3 (Steps 5 & 7: Expected vs Loaded & Profiling)
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- 1. Reconciliation: Expected Rows vs Loaded Rows
SELECT 'Saudi Weather' AS dataset_source,
       249023 AS expected_rows,
       COUNT_BIG(*) AS loaded_rows,
       CASE WHEN COUNT_BIG(*) = 249023 THEN 'MATCH' ELSE 'MISMATCH' END AS status_flag
FROM bronze.sa_weather
UNION ALL
SELECT 'Saudi Traffic Accidents',
       168,
       COUNT_BIG(*),
       CASE WHEN COUNT_BIG(*) = 168 THEN 'MATCH' ELSE 'MISMATCH' END
FROM bronze.sa_traffic_accidents
UNION ALL
SELECT 'AV Telemetry',
       389,
       COUNT_BIG(*),
       CASE WHEN COUNT_BIG(*) = 389 THEN 'MATCH' ELSE 'MISMATCH' END
FROM bronze.av_telemetry;
GO

-- 2. Profiling Weather Columns for Blanks / Nulls
SELECT 
    COUNT(*) AS total_weather_rows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(city)), '') IS NULL THEN 1 ELSE 0 END) AS missing_city,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(temp)), '') IS NULL THEN 1 ELSE 0 END) AS missing_temp,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(visibility)), '') IS NULL THEN 1 ELSE 0 END) AS missing_visibility,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(humidity)), '') IS NULL THEN 1 ELSE 0 END) AS missing_humidity,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(weather_condition)), '') IS NULL THEN 1 ELSE 0 END) AS missing_condition
FROM bronze.sa_weather;
GO

-- 3. Profiling Distinct Weather Conditions (Notice trailing spaces or case differences)
SELECT TOP 10 
    weather_condition, 
    COUNT(*) AS frequency
FROM bronze.sa_weather
GROUP BY weather_condition
ORDER BY frequency DESC;
GO

-- 4. Traffic Accidents Indicator Breakdown
SELECT 
    indicator,
    COUNT(*) AS row_count,
    SUM(TRY_CONVERT(INT, indicator_value)) AS total_reported
FROM bronze.sa_traffic_accidents
GROUP BY indicator;
GO
