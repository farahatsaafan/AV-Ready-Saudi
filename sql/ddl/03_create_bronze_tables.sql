-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 03_create_bronze_tables.sql
-- Purpose: Create Bronze landing tables.
-- Principles (from Unit 2 Lab 3):
--   1. Preserve received values verbatim (No trimming, no typing, no cleaning).
--   2. Permissive schema: All columns VARCHAR NULL to prevent any load aborts.
--   3. Keep defects (spaces, blanks, malformed formats) for traceable Silver cleansing.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- 1. Saudi Weather Landing Table
DROP TABLE IF EXISTS bronze.sa_weather;
GO

CREATE TABLE bronze.sa_weather (
    row_id            VARCHAR(50)   NULL,
    city              VARCHAR(100)  NULL,
    weather_date      VARCHAR(100)  NULL,
    weather_time      VARCHAR(50)   NULL,
    weather_year      VARCHAR(20)   NULL,
    weather_month     VARCHAR(20)   NULL,
    weather_day       VARCHAR(20)   NULL,
    weather_hour      VARCHAR(20)   NULL,
    weather_minute    VARCHAR(20)   NULL,
    weather_condition VARCHAR(150)  NULL,
    temp              VARCHAR(50)   NULL,
    wind              VARCHAR(50)   NULL,
    humidity          VARCHAR(50)   NULL,
    barometer         VARCHAR(50)   NULL,
    visibility        VARCHAR(50)   NULL
);
GO

-- 2. Saudi Traffic Accidents & Casualties Landing Table
DROP TABLE IF EXISTS bronze.sa_traffic_accidents;
GO

CREATE TABLE bronze.sa_traffic_accidents (
    accident_year   VARCHAR(20)    NULL,
    region          VARCHAR(150)   NULL,
    indicator       VARCHAR(150)   NULL,
    indicator_value VARCHAR(50)    NULL,
    geo_shape       NVARCHAR(MAX)  NULL, -- Contains GeoJSON polygon boundary
    geo_point_2d    VARCHAR(150)   NULL  -- "lat, long" coordinates
);
GO

-- 3. Autonomous Racing / AV Telemetry Landing Table
DROP TABLE IF EXISTS bronze.av_telemetry;
GO

CREATE TABLE bronze.av_telemetry (
    frame_id      VARCHAR(50)  NULL,
    timestamp_val VARCHAR(100) NULL,
    pos_x         VARCHAR(50)  NULL,
    pos_y         VARCHAR(50)  NULL,
    pos_z         VARCHAR(50)  NULL,
    q_x           VARCHAR(50)  NULL,
    q_y           VARCHAR(50)  NULL,
    q_z           VARCHAR(50)  NULL,
    q_w           VARCHAR(50)  NULL
);
GO

PRINT 'Bronze tables [bronze.sa_weather, bronze.sa_traffic_accidents, bronze.av_telemetry] created successfully.';
GO
