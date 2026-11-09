-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 06_analytics.sql
-- Purpose: Business analytical queries answering the core research questions.
-- Course Standard: DM & DW Project Skeleton (Fall 2026)
--
-- Rule:
--   Start every analytical query with the question and the GRAIN of the result.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- Q1: What is the overall environmental readiness score for each Saudi city,
--     and how do they rank from safest to most hazardous for autonomous vehicles?
-- GRAIN: One row per city.
-- ------------------------------------------------------------------------------
SELECT 
    c.city_name_en,
    c.city_name_ar,
    c.climate_zone,
    COUNT(*) AS total_monitored_days,
    ROUND(AVG(f.av_readiness_score), 2) AS avg_readiness_score,
    SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END) AS total_dust_days,
    SUM(CASE WHEN f.is_extreme_heat = 1 THEN 1 ELSE 0 END) AS total_heat_days,
    SUM(f.daily_disengagements_count) AS total_disengagements,
    DENSE_RANK() OVER (ORDER BY AVG(f.av_readiness_score) DESC) AS readiness_rank
FROM gold.fact_daily_av_risk f
JOIN gold.dim_city c ON f.city_key = c.city_key
GROUP BY c.city_name_en, c.city_name_ar, c.climate_zone
ORDER BY avg_readiness_score DESC;

-- ------------------------------------------------------------------------------
-- Q2: How does seasonal variation across the 12 calendar months impact
--     autonomous driving safety, extreme heat, and disengagement rates?
-- GRAIN: One row per calendar month.
-- ------------------------------------------------------------------------------
SELECT 
    d.month_number,
    d.month_name,
    COUNT(*) AS total_days,
    ROUND(AVG(f.avg_temp_c), 2) AS avg_monthly_temp,
    ROUND(MAX(f.max_temp_c), 2) AS peak_temp,
    SUM(CASE WHEN f.is_dust_storm = 1 THEN 1 ELSE 0 END) AS dust_days,
    SUM(CASE WHEN f.is_extreme_heat = 1 THEN 1 ELSE 0 END) AS heat_days,
    SUM(f.daily_disengagements_count) AS disengagements,
    ROUND(AVG(f.av_readiness_score), 2) AS avg_readiness_score
FROM gold.fact_daily_av_risk f
JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.month_number, d.month_name
ORDER BY d.month_number ASC;

-- ------------------------------------------------------------------------------
-- Q3: Which national highway corridors exhibit the highest traffic collisions
--     specifically caused by sandstorm zero-visibility events?
-- GRAIN: One row per highway corridor.
-- ------------------------------------------------------------------------------
SELECT TOP 10
    road_name,
    city_id,
    COUNT(*) AS dust_collision_count,
    SUM(casualties_count) AS total_casualties,
    SUM(vehicles_involved) AS total_vehicles_damaged
FROM silver.sa_traffic_accidents
WHERE primary_cause LIKE '%DUST%' OR primary_cause LIKE '%VISIBILITY%'
GROUP BY road_name, city_id
ORDER BY dust_collision_count DESC;

-- ------------------------------------------------------------------------------
-- Q4: What is the empirical breakdown of AV sensor disengagements
--     across standardized meteorological hazard levels?
-- GRAIN: One row per sensor hazard level.
-- ------------------------------------------------------------------------------
SELECT 
    h.sensor_hazard_level,
    COUNT(*) AS total_days_recorded,
    SUM(f.daily_av_trips_count) AS total_av_trips,
    SUM(f.daily_disengagements_count) AS total_disengagements,
    CASE 
        WHEN SUM(f.daily_av_trips_count) = 0 THEN 0.0
        ELSE ROUND((CAST(SUM(f.daily_disengagements_count) AS DECIMAL(10,2)) / SUM(f.daily_av_trips_count)) * 100.0, 2)
    END AS disengagement_percentage,
    ROUND(AVG(f.av_readiness_score), 2) AS avg_readiness_score
FROM gold.fact_daily_av_risk f
JOIN gold.dim_weather_hazard h ON f.hazard_key = h.hazard_key
GROUP BY h.sensor_hazard_level
ORDER BY disengagement_percentage DESC;

-- ------------------------------------------------------------------------------
-- Q5: What is the correlation between ambient temperature peaks (>45C)
--     and on-board compute GPU thermal stress across operating fleets?
-- GRAIN: One row per thermal operating category.
-- ------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN t.ambient_temp_c >= 45.0 THEN 'EXTREME_HEAT (>= 45C)'
        WHEN t.ambient_temp_c >= 35.0 THEN 'MODERATE_SUMMER (35 - 45C)'
        ELSE 'TEMPERATE_MILD (< 35C)'
    END AS thermal_environment,
    COUNT(*) AS trip_observations,
    ROUND(AVG(t.gpu_temp_c), 2) AS avg_gpu_temp,
    ROUND(MAX(t.gpu_temp_c), 2) AS peak_gpu_temp,
    ROUND(AVG(t.battery_temp_c), 2) AS avg_battery_temp,
    SUM(CASE WHEN t.target_disengagement = 1 THEN 1 ELSE 0 END) AS disengagements
FROM gold.features_trip_telemetry t
GROUP BY 
    CASE 
        WHEN t.ambient_temp_c >= 45.0 THEN 'EXTREME_HEAT (>= 45C)'
        WHEN t.ambient_temp_c >= 35.0 THEN 'MODERATE_SUMMER (35 - 45C)'
        ELSE 'TEMPERATE_MILD (< 35C)'
    END
ORDER BY avg_gpu_temp DESC;
