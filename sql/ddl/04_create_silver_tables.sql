-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 04_create_silver_tables.sql
-- Purpose: Create trusted Silver tables and reject quarantine log.
-- Principles (from Unit 3 Lab 4):
--   1. Strong typing (DATE, DECIMAL, INT, BIT) instead of text strings.
--   2. Primary keys for entity identification and lineage.
--   3. Quarantine bad mandatory records into silver.reject_log with explicit reasons.
--   4. Standardize text cases, trim whitespace, and clean defects.
--   5. Add DW_create_date timestamp for lineage tracking.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Quarantine / Reject Log Table
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.reject_log;
GO

CREATE TABLE silver.reject_log (
    reject_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_table   VARCHAR(50)          NOT NULL,
    business_key   VARCHAR(100)         NULL,
    reason         VARCHAR(200)         NOT NULL,
    DW_create_date DATETIME2            NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 2. Silver Saudi Weather Table
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.sa_weather;
GO

CREATE TABLE silver.sa_weather (
    weather_id            INT IDENTITY(1,1) PRIMARY KEY,
    weather_date          DATE          NOT NULL,
    weather_year          INT           NOT NULL,
    weather_month         INT           NOT NULL,
    weather_day           INT           NOT NULL,
    city_id               VARCHAR(10)   NOT NULL,
    city_name_en          NVARCHAR(100) NOT NULL,
    city_name_ar          NVARCHAR(100) NOT NULL,
    latitude              DECIMAL(10,6) NOT NULL,
    longitude             DECIMAL(10,6) NOT NULL,
    temp_max_c            DECIMAL(5,2)  NOT NULL,
    temp_min_c            DECIMAL(5,2)  NOT NULL,
    temp_mean_c           DECIMAL(5,2)  NOT NULL,
    precipitation_mm      DECIMAL(6,2)  NOT NULL,
    wind_speed_max_kmh    DECIMAL(5,2)  NOT NULL,
    wind_gusts_max_kmh    DECIMAL(5,2)  NOT NULL,
    solar_radiation_mj    DECIMAL(6,2)  NOT NULL,
    weather_code_wmo      INT           NOT NULL,
    is_dust_storm         BIT           NOT NULL,
    is_extreme_heat       BIT           NOT NULL,
    DW_create_date        DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 3. Silver Saudi Traffic Accidents Table
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.sa_traffic_accidents;
GO

CREATE TABLE silver.sa_traffic_accidents (
    accident_surrogate_id  INT IDENTITY(1,1) PRIMARY KEY,
    accident_id            VARCHAR(50)   NOT NULL,
    accident_date          DATE          NOT NULL,
    accident_year          INT           NOT NULL,
    accident_month         INT           NOT NULL,
    city_id                VARCHAR(10)   NOT NULL,
    road_name              NVARCHAR(150) NOT NULL,
    severity               NVARCHAR(50)  NOT NULL,
    primary_cause          NVARCHAR(100) NOT NULL,
    vehicles_involved      INT           NOT NULL,
    casualties_count       INT           NOT NULL,
    weather_condition_code INT           NULL,
    ambient_temp_c         DECIMAL(5,2)  NULL,
    wind_gusts_kmh         DECIMAL(5,2)  NULL,
    DW_create_date         DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 4. Silver Autonomous Vehicle Fleet Telemetry Table
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.av_telemetry;
GO

CREATE TABLE silver.av_telemetry (
    telemetry_surrogate_id INT IDENTITY(1,1) PRIMARY KEY,
    telemetry_id           VARCHAR(50)   NOT NULL,
    telemetry_date         DATE          NOT NULL,
    city_id                VARCHAR(10)   NOT NULL,
    vehicle_id             VARCHAR(50)   NOT NULL,
    speed_kmh              DECIMAL(6,2)  NOT NULL,
    battery_temp_c         DECIMAL(5,2)  NOT NULL,
    gpu_temp_c             DECIMAL(5,2)  NOT NULL,
    tire_pressure_psi      DECIMAL(5,2)  NOT NULL,
    lidar_attenuation_pct  DECIMAL(5,2)  NOT NULL,
    camera_glare_index     DECIMAL(4,2)  NOT NULL,
    failure_occurred       BIT           NOT NULL,
    failure_type           NVARCHAR(100) NOT NULL,
    severity               NVARCHAR(50)  NOT NULL,
    av_disengagement       BIT           NOT NULL,
    DW_create_date         DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

PRINT 'Silver tables [silver.reject_log, silver.sa_weather, silver.sa_traffic_accidents, silver.av_telemetry] created successfully.';
GO
