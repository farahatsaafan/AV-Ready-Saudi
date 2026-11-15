-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 05_create_gold_views_tables.sql
-- Purpose: Create Gold dimensional Star Schema (dim_* and fact_daily_av_risk).
-- Focus: Autonomous Vehicle (AV) driving safety and sensor readiness in Saudi Arabia.
-- Course Standard: DM & DW Project Skeleton (Fall 2026)
--
-- Dimensional Model Structure:
--   - Dimensions: dim_city, dim_date, dim_weather_hazard, dim_av_failure_type
--   - Fact: fact_daily_av_risk
--   - MANDATORY RULE: State the GRAIN of every fact table first.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Dimension: City Hubs (gold.dim_city)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS gold.dim_city;
GO

CREATE TABLE gold.dim_city (
    city_key       INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate key
    city_id        VARCHAR(10)       NOT NULL UNIQUE, -- Natural key
    city_name_en   NVARCHAR(100)     NOT NULL,
    city_name_ar   NVARCHAR(100)     NOT NULL,
    latitude       DECIMAL(10,6)     NOT NULL,
    longitude      DECIMAL(10,6)     NOT NULL,
    climate_zone   VARCHAR(50)       NOT NULL
);
GO

-- ------------------------------------------------------------------------------
-- 2. Dimension: Calendar Date (gold.dim_date)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS gold.dim_date;
GO

CREATE TABLE gold.dim_date (
    date_key       INT          PRIMARY KEY, -- Formatted YYYYMMDD
    calendar_date  DATE         NOT NULL UNIQUE,
    year_number    INT          NOT NULL,
    month_number   INT          NOT NULL,
    month_name     VARCHAR(20)  NOT NULL,
    quarter_number INT          NOT NULL
);
GO

-- ------------------------------------------------------------------------------
-- 3. Dimension: Weather Sensor Hazard Taxonomy (gold.dim_weather_hazard)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS gold.dim_weather_hazard;
GO

CREATE TABLE gold.dim_weather_hazard (
    hazard_key          INT IDENTITY(1,1) PRIMARY KEY,
    weather_code_wmo    INT               NOT NULL UNIQUE,
    sensor_hazard_level NVARCHAR(20)      NOT NULL, -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    lidar_impact        NVARCHAR(150)     NOT NULL,
    camera_impact       NVARCHAR(150)     NOT NULL
);
GO

-- ------------------------------------------------------------------------------
-- 4. Dimension: AV Component Failure Catalog (gold.dim_av_failure_type)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS gold.dim_av_failure_type;
GO

CREATE TABLE gold.dim_av_failure_type (
    failure_type_key INT IDENTITY(1,1) PRIMARY KEY,
    failure_type     NVARCHAR(100)     NOT NULL UNIQUE,
    subsystem        NVARCHAR(50)      NOT NULL, -- 'PERCEPTION_LIDAR', 'PERCEPTION_CAMERA', etc.
    risk_level       NVARCHAR(20)      NOT NULL  -- 'NORMAL', 'MEDIUM', 'HIGH', 'CRITICAL'
);
GO

-- ------------------------------------------------------------------------------
-- 5. Fact Table: Daily City Driving Conditions & Sensor Risk
-- GRAIN: Exactly ONE row per city per observation date (date_key + city_key).
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS gold.fact_daily_av_risk;
GO

CREATE TABLE gold.fact_daily_av_risk (
    fact_id                     BIGINT IDENTITY(1,1) PRIMARY KEY,
    city_key                    INT            NOT NULL REFERENCES gold.dim_city(city_key),
    date_key                    INT            NOT NULL REFERENCES gold.dim_date(date_key),
    hazard_key                  INT            NOT NULL REFERENCES gold.dim_weather_hazard(hazard_key),
    -- Observed Weather Measures
    avg_temp_c                  DECIMAL(5,2)   NOT NULL,
    max_temp_c                  DECIMAL(5,2)   NOT NULL,
    max_wind_gusts_kmh          DECIMAL(5,2)   NOT NULL,
    is_dust_storm               BIT            NOT NULL,
    is_extreme_heat             BIT            NOT NULL,
    -- Aggregated Traffic Incident Measures
    daily_accident_count        INT            NOT NULL DEFAULT 0,
    daily_casualties_count      INT            NOT NULL DEFAULT 0,
    -- Aggregated AV Fleet Telemetry & Disengagement Measures
    daily_av_trips_count        INT            NOT NULL DEFAULT 0,
    daily_disengagements_count  INT            NOT NULL DEFAULT 0,
    avg_lidar_attenuation_pct   DECIMAL(5,2)   NULL,
    avg_camera_glare_index      DECIMAL(4,2)   NULL,
    -- Synthesized Operational Readiness Score (0 to 100)
    av_readiness_score          DECIMAL(5,2)   NOT NULL,
    DW_create_date              DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
GO

PRINT 'Gold tables [dim_city, dim_date, dim_weather_hazard, dim_av_failure_type, fact_daily_av_risk] created successfully.';
GO
