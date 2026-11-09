-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 05_feature_views.sql
-- Purpose: Create documented Feature Views for Data Mining and Machine Learning.
-- Course Standard: DM & DW Project Skeleton (Fall 2026)
--
-- Rule:
--   Every ML model reads ONLY from a documented feature view in the gold schema.
--   Outputs are written back to the ml schema (SQL -> Python -> SQL).
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Feature View: City Monthly Operational Profile (For Clustering)
-- GRAIN: Exactly ONE row per city per year-month.
-- Used by: K-Means Clustering to group Saudi operational regimes.
-- ------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.features_city_monthly AS
SELECT 
    c.city_key,
    c.city_id,
    c.city_name_en,
    c.climate_zone,
    d.year_number,
    d.month_number,
    -- Environmental Aggregations
    ROUND(AVG(f.avg_temp_c), 2) AS monthly_avg_temp_c,
    ROUND(MAX(f.max_temp_c), 2) AS monthly_peak_temp_c,
    ROUND(AVG(f.max_wind_gusts_kmh), 2) AS monthly_avg_wind_gusts_kmh,
    SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END) AS monthly_dust_days,
    ROUND(CAST(SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END) AS DECIMAL(6,2)) / COUNT(*), 4) AS dust_day_ratio,
    SUM(CASE WHEN f.is_extreme_heat = 1 THEN 1 ELSE 0 END) AS monthly_extreme_heat_days,
    -- Traffic & Fleet Safety Aggregations
    SUM(f.daily_accident_count) AS monthly_accident_count,
    SUM(f.daily_casualties_count) AS monthly_casualties_count,
    SUM(f.daily_av_trips_count) AS monthly_av_trips_count,
    SUM(f.daily_disengagements_count) AS monthly_disengagements_count,
    -- Target Metric for Evaluation
    ROUND(AVG(f.av_readiness_score), 2) AS monthly_avg_readiness_score
FROM gold.fact_daily_av_risk f
JOIN gold.dim_city c ON f.city_key = c.city_key
JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY c.city_key, c.city_id, c.city_name_en, c.climate_zone, d.year_number, d.month_number;
GO

-- ------------------------------------------------------------------------------
-- 2. Feature View: AV Fleet Trip Telemetry (For Classification)
-- GRAIN: Exactly ONE row per vehicle trip.
-- Used by: Decision Tree / Random Forest to predict av_disengagement.
-- ------------------------------------------------------------------------------
CREATE OR ALTER VIEW gold.features_trip_telemetry AS
SELECT 
    t.telemetry_key,
    t.telemetry_id,
    t.telemetry_date,
    t.city_id,
    t.vehicle_id,
    -- Quantitative Predictor Features
    t.speed_kmh,
    t.battery_temp_c,
    t.gpu_temp_c,
    t.tire_pressure_psi,
    t.lidar_attenuation_pct,
    t.camera_glare_index,
    -- Ambient Weather Context via join
    w.temp_max_c AS ambient_temp_c,
    w.wind_gusts_max_kmh,
    w.is_dust_storm,
    w.is_extreme_heat,
    -- Ground Truth Target Variable for Classification
    t.av_disengagement AS target_disengagement
FROM silver.av_telemetry t
JOIN silver.sa_weather w 
    ON t.telemetry_date = w.weather_date 
   AND t.city_id = w.city_id;
GO

PRINT 'Feature views [gold.features_city_monthly, gold.features_trip_telemetry] created.';
GO
