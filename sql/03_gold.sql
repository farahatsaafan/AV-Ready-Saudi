-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 03_gold.sql
-- Purpose: Create Gold dimensional Star Schema and materialization load procedure.
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

PRINT 'Gold tables [dim_city, dim_date, dim_weather_hazard, dim_av_failure_type, fact_daily_av_risk] created.';
GO

-- ------------------------------------------------------------------------------
-- 6. Stored Procedure: gold.load_gold
-- Usage: EXEC gold.load_gold;
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_facts BIGINT;

    PRINT '====================================================================';
    PRINT 'Starting Gold Dimensional Loading Batch: ' + CAST(@batch_id AS NVARCHAR(50));
    PRINT '====================================================================';

    BEGIN TRY
        BEGIN TRAN;

        -- ----------------------------------------------------------------------
        -- Step 1: Refresh Dimensions
        -- ----------------------------------------------------------------------
        -- A) dim_city
        TRUNCATE TABLE gold.dim_city;
        INSERT INTO gold.dim_city (city_id, city_name_en, city_name_ar, latitude, longitude, climate_zone)
        SELECT 
            city_id,
            MAX(city_name_en),
            MAX(city_name_ar),
            MAX(latitude),
            MAX(longitude),
            CASE 
                WHEN city_id IN ('RUH', 'HAS', 'ULA') THEN 'DESERT_CONTINENTAL'
                WHEN city_id IN ('JED', 'DMM')        THEN 'COASTAL_HUMID_DUST'
                WHEN city_id IN ('MAK', 'MED')        THEN 'ARID_VALLEY_HEAT'
                WHEN city_id IN ('ABH', 'TIF')        THEN 'HIGHLAND_TEMPERATE'
                WHEN city_id = 'TBK'                  THEN 'NORTHERN_DESERT_PLATEAU'
                ELSE 'DESERT_ARID'
            END AS climate_zone
        FROM silver.sa_weather
        GROUP BY city_id;

        -- B) dim_date
        DELETE FROM gold.dim_date;
        INSERT INTO gold.dim_date (date_key, calendar_date, year_number, month_number, month_name, quarter_number)
        SELECT DISTINCT
            CONVERT(INT, CONVERT(CHAR(8), weather_date, 112)) AS date_key,
            weather_date AS calendar_date,
            weather_year AS year_number,
            weather_month AS month_number,
            DATENAME(MONTH, weather_date) AS month_name,
            DATEPART(QUARTER, weather_date) AS quarter_number
        FROM silver.sa_weather;

        -- C) dim_weather_hazard
        TRUNCATE TABLE gold.dim_weather_hazard;
        INSERT INTO gold.dim_weather_hazard (weather_code_wmo, sensor_hazard_level, lidar_impact, camera_impact)
        SELECT DISTINCT
            weather_code_wmo,
            CASE 
                WHEN weather_code_wmo IN (6, 7, 8, 9, 30, 31, 32, 33, 34, 35) THEN 'CRITICAL' -- Dust / Sandstorm
                WHEN weather_code_wmo IN (40, 41, 42, 43, 44, 45, 46, 47, 48, 49) THEN 'CRITICAL' -- Fog
                WHEN weather_code_wmo IN (95, 96, 97, 98, 99) THEN 'HIGH'                       -- Thunderstorm
                WHEN weather_code_wmo IN (50, 51, 52, 53, 54, 55, 60, 61, 62, 63, 64, 65) THEN 'MEDIUM' -- Rain
                WHEN weather_code_wmo IN (0, 1) THEN 'LOW'                                       -- Clear
                ELSE 'LOW'
            END AS sensor_hazard_level,
            CASE 
                WHEN weather_code_wmo IN (6, 7, 8, 9, 30, 31, 32, 33, 34, 35) THEN 'Severe particulate absorption (>70% attenuation)'
                WHEN weather_code_wmo IN (45, 48) THEN 'Severe optical scattering under 50m'
                WHEN weather_code_wmo >= 60 AND weather_code_wmo <= 65 THEN 'Ground droplet reflection and noise returns'
                ELSE 'Nominal operational pulse range (>200m)'
            END AS lidar_impact,
            CASE 
                WHEN weather_code_wmo IN (6, 7, 8, 9, 30, 31, 32, 33, 34, 35) THEN 'Total loss of lane contrast and optical occlusion'
                WHEN weather_code_wmo = 0 THEN 'Potential solar glare blinding during midday low-angle sun'
                WHEN weather_code_wmo IN (45, 48) THEN 'Severe contrast loss under dense atmospheric fog'
                ELSE 'Nominal optical exposure'
            END AS camera_impact
        FROM silver.sa_weather;

        -- D) dim_av_failure_type
        TRUNCATE TABLE gold.dim_av_failure_type;
        INSERT INTO gold.dim_av_failure_type (failure_type, subsystem, risk_level)
        SELECT DISTINCT
            failure_type,
            CASE 
                WHEN failure_type LIKE '%LIDAR%' THEN 'PERCEPTION_LIDAR'
                WHEN failure_type LIKE '%CAMERA%' OR failure_type LIKE '%LANE%' THEN 'PERCEPTION_CAMERA'
                WHEN failure_type LIKE '%BATTERY%' OR failure_type LIKE '%GPU%' THEN 'COMPUTE_HARDWARE'
                WHEN failure_type LIKE '%TIRE%' THEN 'CHASSIS_TIRE'
                ELSE 'GENERAL_SYSTEM'
            END AS subsystem,
            CASE 
                WHEN failure_type = 'NONE' THEN 'NORMAL'
                WHEN failure_type IN ('BATTERY_THERMAL_THROTTLING', 'LIDAR_DUST_OCCLUSION') THEN 'CRITICAL'
                WHEN failure_type = 'CAMERA_SOLAR_BLINDING' THEN 'HIGH'
                ELSE 'MEDIUM'
            END AS risk_level
        FROM silver.av_telemetry;

        -- ----------------------------------------------------------------------
        -- Step 2: Populate Fact Table (gold.fact_daily_av_risk)
        -- GRAIN: One row per city per observation date
        -- ----------------------------------------------------------------------
        TRUNCATE TABLE gold.fact_daily_av_risk;

        -- Pre-aggregate Accidents by city and date
        ;WITH acc_agg AS (
            SELECT 
                city_id,
                accident_date,
                COUNT(*) AS accident_count,
                SUM(casualties_count) AS casualties_count
            FROM silver.sa_traffic_accidents
            GROUP BY city_id, accident_date
        ),
        -- Pre-aggregate Telemetry by city and date
        tel_agg AS (
            SELECT 
                city_id,
                telemetry_date,
                COUNT(*) AS trips_count,
                SUM(CASE WHEN av_disengagement = 1 THEN 1 ELSE 0 END) AS disengagements_count,
                ROUND(AVG(lidar_attenuation_pct), 2) AS avg_lidar_attenuation,
                ROUND(AVG(camera_glare_index), 2) AS avg_camera_glare
            FROM silver.av_telemetry
            GROUP BY city_id, telemetry_date
        )
        INSERT INTO gold.fact_daily_av_risk (
            city_key, date_key, hazard_key,
            avg_temp_c, max_temp_c, max_wind_gusts_kmh,
            is_dust_storm, is_extreme_heat,
            daily_accident_count, daily_casualties_count,
            daily_av_trips_count, daily_disengagements_count,
            avg_lidar_attenuation_pct, avg_camera_glare_index,
            av_readiness_score
        )
        SELECT 
            c.city_key,
            d.date_key,
            h.hazard_key,
            w.temp_mean_c,
            w.temp_max_c,
            w.wind_gusts_max_kmh,
            w.is_dust_storm,
            w.is_extreme_heat,
            ISNULL(a.accident_count, 0) AS daily_accident_count,
            ISNULL(a.casualties_count, 0) AS daily_casualties_count,
            ISNULL(t.trips_count, 0) AS daily_av_trips_count,
            ISNULL(t.disengagements_count, 0) AS daily_disengagements_count,
            t.avg_lidar_attenuation,
            t.avg_camera_glare,
            -- Synthesized Composite Readiness Score (0 to 100)
            -- 70% Real Environmental/Traffic reality, 30% AV Sensor response
            ROUND(
                100.0
                - (CASE WHEN w.is_dust_storm = 1 THEN 35.0 ELSE 0.0 END)
                - (CASE WHEN w.is_extreme_heat = 1 THEN 20.0 ELSE 0.0 END)
                - (CASE WHEN w.wind_gusts_max_kmh > 50.0 THEN 15.0 ELSE 0.0 END)
                - (ISNULL(a.accident_count, 0) * 5.0)
                - (ISNULL(t.disengagements_count, 0) * 8.0),
                2
            ) AS av_readiness_score
        FROM silver.sa_weather w
        JOIN gold.dim_city c ON w.city_id = c.city_id
        JOIN gold.dim_date d ON w.weather_date = d.calendar_date
        JOIN gold.dim_weather_hazard h ON w.weather_code_wmo = h.weather_code_wmo
        LEFT JOIN acc_agg a ON w.city_id = a.city_id AND w.weather_date = a.accident_date
        LEFT JOIN tel_agg t ON w.city_id = t.city_id AND w.weather_date = t.telemetry_date;

        SELECT @rows_facts = COUNT_BIG(*) FROM gold.fact_daily_av_risk;
        SET @end_time = SYSDATETIME();

        COMMIT;

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'silver.*', 'gold.fact_daily_av_risk', @start_time, @end_time, @rows_facts, 'SUCCESS', 'Gold dimensions and daily fact loaded');

        PRINT '====================================================================';
        PRINT 'Gold Layer Load Finished Successfully!';
        PRINT 'Daily AV Risk Fact Rows: ' + CAST(@rows_facts AS NVARCHAR(20));
        PRINT 'Total Batch Time:        ' + CAST(DATEDIFF(SECOND, @start_time, SYSDATETIME()) AS NVARCHAR(10)) + 's';
        PRINT '====================================================================';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'silver.*', 'gold.*', @start_time, @end_time, 0, 'FAILED', ERROR_MESSAGE());

        PRINT '====================================================================';
        PRINT 'ERROR in gold.load_gold: ' + ERROR_MESSAGE();
        PRINT '====================================================================';
        THROW;
    END CATCH;
END;
GO
