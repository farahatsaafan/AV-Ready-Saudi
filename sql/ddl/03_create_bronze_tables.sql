-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 03_create_bronze_tables.sql
-- Purpose: Create Bronze landing tables for the 3 core data sources.
-- Principles (from Unit 2 Lab 3 & Lecture 02):
--   1. Preserve received values verbatim (No trimming, no typing, no cleaning).
--   2. Permissive schema: All columns VARCHAR/NVARCHAR NULL to prevent load aborts.
--   3. Keep defects (spaces, blanks, malformed formats) for traceable Silver cleansing.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Source: Saudi Weather Landing Table (saudi_weather_daily_2019_2024.csv)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.sa_weather;
GO

CREATE TABLE bronze.sa_weather (
    [date]                VARCHAR(50)   NULL,
    temp_max_c            VARCHAR(50)   NULL,
    temp_min_c            VARCHAR(50)   NULL,
    temp_mean_c           VARCHAR(50)   NULL,
    precipitation_mm      VARCHAR(50)   NULL,
    wind_speed_max_kmh    VARCHAR(50)   NULL,
    wind_gusts_max_kmh    VARCHAR(50)   NULL,
    solar_radiation_mj    VARCHAR(50)   NULL,
    weather_code_wmo      VARCHAR(50)   NULL,
    city_id               VARCHAR(50)   NULL,
    city_name_en          VARCHAR(100)  NULL,
    city_name_ar          NVARCHAR(100) NULL,
    latitude              VARCHAR(50)   NULL,
    longitude             VARCHAR(50)   NULL,
    is_dust_storm         VARCHAR(50)   NULL,
    is_extreme_heat       VARCHAR(50)   NULL
);
GO

-- ------------------------------------------------------------------------------
-- 2. Source: Saudi Highway Traffic Accidents (saudi_traffic_accidents_2019_2024.csv)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.sa_traffic_accidents;
GO

CREATE TABLE bronze.sa_traffic_accidents (
    accident_id            VARCHAR(50)   NULL,
    [date]                 VARCHAR(50)   NULL,
    city_id                VARCHAR(50)   NULL,
    road_name              NVARCHAR(150) NULL,
    severity               VARCHAR(50)   NULL,
    primary_cause          VARCHAR(100)  NULL,
    vehicles_involved      VARCHAR(50)   NULL,
    casualties_count       VARCHAR(50)   NULL,
    weather_condition_code VARCHAR(50)   NULL,
    ambient_temp_c         VARCHAR(50)   NULL,
    wind_gusts_kmh         VARCHAR(50)   NULL
);
GO

-- ------------------------------------------------------------------------------
-- 3. Source: Autonomous Vehicle Fleet Telemetry & Failures (av_telemetry_failures_saudi.csv)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.av_telemetry;
GO

CREATE TABLE bronze.av_telemetry (
    telemetry_id          VARCHAR(50)  NULL,
    [date]                VARCHAR(50)  NULL,
    city_id               VARCHAR(50)  NULL,
    vehicle_id            VARCHAR(50)  NULL,
    speed_kmh             VARCHAR(50)  NULL,
    battery_temp_c        VARCHAR(50)  NULL,
    gpu_temp_c            VARCHAR(50)  NULL,
    tire_pressure_psi     VARCHAR(50)  NULL,
    lidar_attenuation_pct VARCHAR(50)  NULL,
    camera_glare_index    VARCHAR(50)  NULL,
    failure_occurred      VARCHAR(50)  NULL,
    failure_type          VARCHAR(100) NULL,
    severity              VARCHAR(50)  NULL,
    av_disengagement      VARCHAR(50)  NULL
);
GO

PRINT 'Bronze tables [bronze.sa_weather, bronze.sa_traffic_accidents, bronze.av_telemetry] created successfully.';
GO
