-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 04_create_silver_tables.sql
-- Purpose: Create Silver tables and reject log.
-- Principles (from Unit 3 Lab 4):
--   1. Strong typing (DATE, DECIMAL, INT) instead of text.
--   2. Primary keys for entity identification.
--   3. Quarantine bad mandatory records into silver.reject_log with reasons.
--   4. Standardize text cases and trim whitespace.
--   5. Add DW_create_date timestamp for lineage tracking.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- 1. Quarantine / Reject Log
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

-- 2. Silver Saudi Weather Table
DROP TABLE IF EXISTS silver.sa_weather;
GO

CREATE TABLE silver.sa_weather (
    weather_id        INT IDENTITY(1,1) PRIMARY KEY,
    city              NVARCHAR(100) NOT NULL,
    weather_date      DATE          NOT NULL,
    weather_time      TIME(0)       NULL,
    weather_year      INT           NOT NULL,
    weather_month     INT           NOT NULL,
    weather_day       INT           NOT NULL,
    weather_hour      INT           NOT NULL,
    weather_condition NVARCHAR(100) NOT NULL,
    temp_c            DECIMAL(6,2)  NULL,
    wind_kmh          DECIMAL(6,2)  NULL,
    humidity_pct      DECIMAL(5,2)  NULL,
    barometer_mbar    DECIMAL(8,2)  NULL,
    visibility_km     DECIMAL(6,2)  NULL,
    DW_create_date    DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- 3. Silver Saudi Traffic Accidents & Casualties
DROP TABLE IF EXISTS silver.sa_traffic_accidents;
GO

CREATE TABLE silver.sa_traffic_accidents (
    accident_id     INT IDENTITY(1,1) PRIMARY KEY,
    accident_year   INT           NOT NULL,
    region          NVARCHAR(100) NOT NULL,
    indicator       NVARCHAR(100) NOT NULL,
    indicator_value INT           NOT NULL,
    latitude        DECIMAL(10,6) NULL,
    longitude       DECIMAL(10,6) NULL,
    DW_create_date  DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- 4. Silver Autonomous Racing Telemetry
DROP TABLE IF EXISTS silver.av_telemetry;
GO

CREATE TABLE silver.av_telemetry (
    telemetry_id   INT IDENTITY(1,1) PRIMARY KEY,
    frame_id       BIGINT        NOT NULL,
    timestamp_val  DECIMAL(20,6) NOT NULL,
    pos_x          DECIMAL(12,4) NOT NULL,
    pos_y          DECIMAL(12,4) NOT NULL,
    pos_z          DECIMAL(12,4) NOT NULL,
    q_x            DECIMAL(10,6) NULL,
    q_y            DECIMAL(10,6) NULL,
    q_z            DECIMAL(10,6) NULL,
    q_w            DECIMAL(10,6) NULL,
    DW_create_date DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

PRINT 'Silver tables [silver.reject_log, silver.sa_weather, silver.sa_traffic_accidents, silver.av_telemetry] created successfully.';
GO
