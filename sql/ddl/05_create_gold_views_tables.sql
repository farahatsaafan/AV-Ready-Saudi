-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 05_create_gold_views_tables.sql
-- Purpose: Create Gold dimensional models, marts and Data Mining feature views.
-- Focus: Autonomous Vehicle (AV) driving safety and sensor readiness in Saudi Arabia.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- 1. Dimension: Weather Conditions & Sensor Hazard Rating
DROP TABLE IF EXISTS gold.dim_weather_hazard;
GO

CREATE TABLE gold.dim_weather_hazard (
    weather_key         INT IDENTITY(1,1) PRIMARY KEY,
    weather_condition   NVARCHAR(100) NOT NULL UNIQUE,
    sensor_hazard_level NVARCHAR(20)  NOT NULL, -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    lidar_impact        NVARCHAR(100) NULL,     -- Impact on LiDAR perception
    camera_impact       NVARCHAR(100) NULL      -- Impact on Optical Camera vision
);
GO

-- 2. Fact / Mart: Daily City Driving Conditions & Sensor Risk
DROP TABLE IF EXISTS gold.fact_city_daily_weather_risk;
GO

CREATE TABLE gold.fact_city_daily_weather_risk (
    fact_id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    city                  NVARCHAR(100) NOT NULL,
    observation_date      DATE          NOT NULL,
    avg_temp_c            DECIMAL(5,2)  NULL,
    max_temp_c            DECIMAL(5,2)  NULL,
    min_temp_c            DECIMAL(5,2)  NULL,
    avg_visibility_km     DECIMAL(5,2)  NULL,
    min_visibility_km     DECIMAL(5,2)  NULL,
    avg_wind_kmh          DECIMAL(5,2)  NULL,
    max_wind_kmh          DECIMAL(5,2)  NULL,
    extreme_heat_hours    INT           DEFAULT 0, -- Hours where temp > 45°C (Sensor thermal throttle risk)
    low_visibility_hours  INT           DEFAULT 0, -- Hours where visibility < 5km (Dust/fog risk)
    dominant_weather      NVARCHAR(100) NULL,
    av_readiness_score    DECIMAL(5,2)  NULL       -- 0 to 100 Safety Score
);
GO

-- 3. Data Mining Feature View: Preparing input for Clustering & Classification algorithms
DROP VIEW IF EXISTS gold.vw_av_mining_features;
GO

CREATE VIEW gold.vw_av_mining_features AS
SELECT 
    city,
    YEAR(observation_date) AS observation_year,
    MONTH(observation_date) AS observation_month,
    COUNT(*) AS total_recorded_days,
    ROUND(AVG(avg_temp_c), 2) AS monthly_avg_temp,
    ROUND(MAX(max_temp_c), 2) AS monthly_peak_temp,
    ROUND(AVG(avg_visibility_km), 2) AS monthly_avg_visibility,
    ROUND(MIN(min_visibility_km), 2) AS monthly_min_visibility,
    SUM(extreme_heat_hours) AS total_extreme_heat_hours,
    SUM(low_visibility_hours) AS total_low_visibility_hours,
    CASE 
        WHEN SUM(low_visibility_hours) > 30 OR MAX(max_temp_c) > 48 THEN 'HIGH_RISK_MONTH'
        WHEN SUM(low_visibility_hours) > 10 OR MAX(max_temp_c) > 42 THEN 'MODERATE_RISK_MONTH'
        ELSE 'OPTIMAL_DRIVING_MONTH'
    END AS av_operating_class
FROM gold.fact_city_daily_weather_risk
GROUP BY city, YEAR(observation_date), MONTH(observation_date);
GO

PRINT 'Gold tables & views [gold.dim_weather_hazard, gold.fact_city_daily_weather_risk, gold.vw_av_mining_features] created successfully.';
GO
