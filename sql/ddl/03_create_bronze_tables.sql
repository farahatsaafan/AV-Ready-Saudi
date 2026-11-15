-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 03_create_bronze_tables.sql
-- Purpose: Create Bronze landing tables and load views for the 3 core data sources.
-- Principles (from Unit 2 Lab 3 & Lecture 02):
--   1. Preserve received values verbatim (No trimming, no typing, no cleaning).
--   2. Permissive schema: All columns VARCHAR/NVARCHAR NULL to prevent load aborts.
--   3. Provenance: Add source_file and ingested_at metadata tracking.
--   4. Load views allow BULK INSERT while provenance columns keep defaults.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Source: Saudi Weather Landing Table (saudi_weather_daily_2019_2024.csv)
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS bronze.v_sa_weather_load;
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
    is_extreme_heat       VARCHAR(50)   NULL,
    -- Provenance columns
    source_file           VARCHAR(500)  NULL,
    ingested_at           DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE OR ALTER VIEW bronze.v_sa_weather_load AS
SELECT 
    [date], temp_max_c, temp_min_c, temp_mean_c, precipitation_mm,
    wind_speed_max_kmh, wind_gusts_max_kmh, solar_radiation_mj,
    weather_code_wmo, city_id, city_name_en, city_name_ar,
    latitude, longitude, is_dust_storm, is_extreme_heat
FROM bronze.sa_weather;
GO

-- ------------------------------------------------------------------------------
-- 2. Source: Saudi Highway Traffic Accidents (saudi_traffic_accidents_2019_2024.csv)
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS bronze.v_sa_traffic_accidents_load;
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
    wind_gusts_kmh         VARCHAR(50)   NULL,
    -- Provenance columns
    source_file            VARCHAR(500)  NULL,
    ingested_at            DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE OR ALTER VIEW bronze.v_sa_traffic_accidents_load AS
SELECT 
    accident_id, [date], city_id, road_name, severity, primary_cause,
    vehicles_involved, casualties_count, weather_condition_code,
    ambient_temp_c, wind_gusts_kmh
FROM bronze.sa_traffic_accidents;
GO

-- ------------------------------------------------------------------------------
-- 3. Source: AV Fleet Telemetry (av_telemetry_failures_saudi.csv)
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS bronze.v_av_telemetry_load;
DROP TABLE IF EXISTS bronze.av_telemetry;
GO

CREATE TABLE bronze.av_telemetry (
    telemetry_id          VARCHAR(50)   NULL,
    [date]                VARCHAR(50)   NULL,
    city_id               VARCHAR(50)   NULL,
    vehicle_id            VARCHAR(50)   NULL,
    speed_kmh             VARCHAR(50)   NULL,
    battery_temp_c        VARCHAR(50)   NULL,
    gpu_temp_c            VARCHAR(50)   NULL,
    tire_pressure_psi     VARCHAR(50)   NULL,
    lidar_attenuation_pct VARCHAR(50)   NULL,
    camera_glare_index    VARCHAR(50)   NULL,
    failure_occurred      VARCHAR(50)   NULL,
    failure_type          VARCHAR(100)  NULL,
    severity              VARCHAR(50)   NULL,
    av_disengagement      VARCHAR(50)   NULL,
    -- Provenance columns
    source_file           VARCHAR(500)  NULL,
    ingested_at           DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE OR ALTER VIEW bronze.v_av_telemetry_load AS
SELECT 
    telemetry_id, [date], city_id, vehicle_id, speed_kmh,
    battery_temp_c, gpu_temp_c, tire_pressure_psi, lidar_attenuation_pct,
    camera_glare_index, failure_occurred, failure_type, severity,
    av_disengagement
FROM bronze.av_telemetry;
GO

PRINT 'Bronze tables and load views created successfully.';
GO
