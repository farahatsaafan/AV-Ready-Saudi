-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 04_semantic.sql
-- Purpose: Create Semantic Layer metric catalog and business analytical views.
-- Course Standard: DM & DW Project Skeleton (Fall 2026)
--
-- Principles:
--   - metric_catalog mirrors semantic/metrics.yml.
--   - Everyone queries semantic views; nobody rewrites business metric expressions.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Table: semantic.metric_catalog
-- ------------------------------------------------------------------------------
IF OBJECT_ID('semantic.metric_catalog') IS NULL
BEGIN
    CREATE TABLE semantic.metric_catalog (
        metric_name      VARCHAR(100)  NOT NULL PRIMARY KEY,
        label            VARCHAR(200)  NULL,
        definition       VARCHAR(1000) NOT NULL,
        owner            VARCHAR(100)  NULL,
        grain            VARCHAR(200)  NULL,
        sql_expression   VARCHAR(1000) NOT NULL,
        dimensions       VARCHAR(500)  NULL,
        null_policy      VARCHAR(500)  NULL,
        validation_query VARCHAR(2000) NULL,
        updated_at       DATETIME2     NOT NULL DEFAULT SYSDATETIME()
    );
    PRINT 'Table [semantic.metric_catalog] created.';
END
GO

-- Seed / Refresh Metric Catalog from metrics.yml specifications
DELETE FROM semantic.metric_catalog;
INSERT INTO semantic.metric_catalog (metric_name, label, definition, owner, grain, sql_expression, dimensions, null_policy, validation_query)
VALUES 
    ('avg_av_readiness_score', 
     'Average AV Environmental Readiness Index', 
     'Mean synthesized autonomous vehicle operational readiness score (0 to 100) combining weather stability, low visibility, traffic incident density, and sensor attenuation.',
     'Engineering Lead / Farahat Saafan', 
     'one city per day (gold.fact_daily_av_risk)', 
     'ROUND(AVG(f.av_readiness_score), 2)', 
     'city_name_en, climate_zone, year_number, month_number', 
     'Excludes days with null scores; readiness is computed for all 21,920 city-days.', 
     'SELECT ROUND(AVG(av_readiness_score), 2) FROM gold.fact_daily_av_risk'),

    ('total_disengagements', 
     'Total Autonomous Disengagements', 
     'Total cumulative events where an autonomous vehicle required manual human safety takeover.', 
     'Fleet Safety Team', 
     'one city per day (gold.fact_daily_av_risk)', 
     'SUM(f.daily_disengagements_count)', 
     'city_name_en, sensor_hazard_level, year_number, month_number', 
     'Null counts default to 0.', 
     'SELECT SUM(CASE WHEN av_disengagement = 1 THEN 1 ELSE 0 END) FROM silver.av_telemetry'),

    ('dust_storm_days', 
     'Total Sand and Dust Storm Days', 
     'Total days exhibiting active particulate sand/dust storms with high wind gusts (>= 45 km/h).', 
     'Environmental Sensor Analytics', 
     'one city per day (gold.fact_daily_av_risk)', 
     'SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END)', 
     'city_name_en, climate_zone, year_number, month_number', 
     'Non-dust days evaluate to 0.', 
     'SELECT COUNT(*) FROM silver.sa_weather WHERE is_dust_storm = 1'),

    ('extreme_heat_days', 
     'Total Extreme Heat Days (>45C)', 
     'Total days where ambient maximum temperature reaches or exceeds 45 degrees Celsius, triggering GPU compute throttling risk.', 
     'Hardware Reliability Team', 
     'one city per day (gold.fact_daily_av_risk)', 
     'SUM(CASE WHEN f.is_extreme_heat = 1 THEN 1 ELSE 0 END)', 
     'city_name_en, climate_zone, year_number, month_number', 
     'Temperatures under 45C evaluate to 0.', 
     'SELECT COUNT(*) FROM silver.sa_weather WHERE is_extreme_heat = 1'),

    ('total_highway_accidents', 
     'Total Highway Traffic Collisions', 
     'Total count of recorded highway vehicular collisions occurring in the designated corridor.', 
     'Traffic Safety Operations', 
     'one city per day (gold.fact_daily_av_risk)', 
     'SUM(f.daily_accident_count)', 
     'city_name_en, year_number, month_number', 
     'Days without accidents record 0.', 
     'SELECT COUNT(*) FROM silver.sa_traffic_accidents');
GO

-- ------------------------------------------------------------------------------
-- 2. Semantic View: Operational Readiness by City Hub
-- ------------------------------------------------------------------------------
CREATE OR ALTER VIEW semantic.v_readiness_by_city AS
SELECT 
    c.city_id,
    c.city_name_en,
    c.city_name_ar,
    c.climate_zone,
    COUNT(*) AS total_recorded_days,
    ROUND(AVG(f.av_readiness_score), 2) AS avg_readiness_score,
    SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END) AS total_dust_storm_days,
    SUM(CASE WHEN f.is_extreme_heat = 1 THEN 1 ELSE 0 END) AS total_extreme_heat_days,
    SUM(f.daily_accident_count) AS total_accidents,
    SUM(f.daily_disengagements_count) AS total_disengagements,
    ROUND(AVG(f.avg_lidar_attenuation_pct), 2) AS avg_lidar_attenuation_pct
FROM gold.fact_daily_av_risk f
JOIN gold.dim_city c ON f.city_key = c.city_key
GROUP BY c.city_id, c.city_name_en, c.city_name_ar, c.climate_zone;
GO

-- ------------------------------------------------------------------------------
-- 3. Semantic View: Seasonal Readiness by Calendar Month
-- ------------------------------------------------------------------------------
CREATE OR ALTER VIEW semantic.v_readiness_by_month AS
SELECT 
    d.month_number,
    d.month_name,
    COUNT(*) AS total_recorded_days,
    ROUND(AVG(f.avg_temp_c), 2) AS monthly_avg_temp_c,
    ROUND(MAX(f.max_temp_c), 2) AS monthly_peak_temp_c,
    SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END) AS total_dust_storm_days,
    SUM(CASE WHEN f.is_extreme_heat = 1 THEN 1 ELSE 0 END) AS total_extreme_heat_days,
    SUM(f.daily_disengagements_count) AS total_disengagements,
    ROUND(AVG(f.av_readiness_score), 2) AS avg_readiness_score
FROM gold.fact_daily_av_risk f
JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.month_number, d.month_name;
GO

-- ------------------------------------------------------------------------------
-- 4. Semantic View: Sensor Disengagement Breakdown by Hazard Level
-- ------------------------------------------------------------------------------
CREATE OR ALTER VIEW semantic.v_disengagements_by_hazard AS
SELECT 
    h.sensor_hazard_level,
    h.lidar_impact,
    h.camera_impact,
    COUNT(*) AS total_days,
    SUM(f.daily_av_trips_count) AS total_av_trips,
    SUM(f.daily_disengagements_count) AS total_disengagements,
    CASE 
        WHEN SUM(f.daily_av_trips_count) = 0 THEN 0.0
        ELSE ROUND((CAST(SUM(f.daily_disengagements_count) AS DECIMAL(10,2)) / SUM(f.daily_av_trips_count)) * 100.0, 2)
    END AS disengagement_rate_pct,
    ROUND(AVG(f.av_readiness_score), 2) AS avg_readiness_score
FROM gold.fact_daily_av_risk f
JOIN gold.dim_weather_hazard h ON f.hazard_key = h.hazard_key
GROUP BY h.sensor_hazard_level, h.lidar_impact, h.camera_impact;
GO

PRINT 'Semantic layer [metric_catalog and views] created successfully.';
GO
