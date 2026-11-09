-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 01_bronze.sql
-- Purpose: Create Bronze landing tables, provenance columns, load views, and
--          the automated batch ingestion stored procedure bronze.load_bronze.
-- Principles (Course Skeleton Fall 2026):
--   1. Preserve source data exactly as received (all raw columns are text).
--   2. No silent cleaning in Bronze; keep defects for traceable Silver quarantine.
--   3. Provenance: track source_file and ingested_at timestamp for every row.
--   4. Load views allow BULK INSERT while provenance columns keep defaults.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Source: Saudi Daily Meteorological Observations (saudi_weather_daily_2019_2024.csv)
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
    -- Provenance columns (Course Standard)
    source_file           VARCHAR(500)  NULL,
    ingested_at           DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- BULK INSERT loads into this view so provenance columns keep their defaults
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
    -- Provenance columns (Course Standard)
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
-- 3. Source: Autonomous Vehicle Fleet Telemetry (av_telemetry_failures_saudi.csv)
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
    -- Provenance columns (Course Standard)
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

-- ------------------------------------------------------------------------------
-- 4. Stored Procedure: bronze.load_bronze
-- Usage: EXEC bronze.load_bronze @base_path = 'D:\AV-Ready-Saudi\Data';
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE bronze.load_bronze
    @base_path NVARCHAR(500) = N'D:\AV-Ready-Saudi\Data'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @step_start DATETIME2;
    DECLARE @step_end DATETIME2;
    DECLARE @rows BIGINT;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @file_path NVARCHAR(600);
    DECLARE @file_name VARCHAR(100);

    PRINT '====================================================================';
    PRINT 'Starting Bronze Ingestion Batch: ' + CAST(@batch_id AS NVARCHAR(50));
    PRINT 'Base Path: ' + @base_path;
    PRINT '====================================================================';

    BEGIN TRY
        -- ----------------------------------------------------------------------
        -- Step 1: Ingest saudi_weather_daily_2019_2024.csv
        -- ----------------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        SET @file_name = 'saudi_weather_daily_2019_2024.csv';
        SET @file_path = @base_path + '\' + @file_name;

        TRUNCATE TABLE bronze.sa_weather;

        SET @sql = N'
            BULK INSERT bronze.v_sa_weather_load
            FROM ''' + @file_path + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        UPDATE bronze.sa_weather 
        SET source_file = @file_name 
        WHERE source_file IS NULL;

        SELECT @rows = COUNT_BIG(*) FROM bronze.sa_weather;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, @file_name, 'bronze.sa_weather', @step_start, @step_end, @rows, 'SUCCESS', 'Ingested successfully via view');
        PRINT '  [SUCCESS] bronze.sa_weather loaded: ' + CAST(@rows AS NVARCHAR(20)) + ' rows.';

        -- ----------------------------------------------------------------------
        -- Step 2: Ingest saudi_traffic_accidents_2019_2024.csv
        -- ----------------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        SET @file_name = 'saudi_traffic_accidents_2019_2024.csv';
        SET @file_path = @base_path + '\' + @file_name;

        TRUNCATE TABLE bronze.sa_traffic_accidents;

        SET @sql = N'
            BULK INSERT bronze.v_sa_traffic_accidents_load
            FROM ''' + @file_path + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        UPDATE bronze.sa_traffic_accidents 
        SET source_file = @file_name 
        WHERE source_file IS NULL;

        SELECT @rows = COUNT_BIG(*) FROM bronze.sa_traffic_accidents;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, @file_name, 'bronze.sa_traffic_accidents', @step_start, @step_end, @rows, 'SUCCESS', 'Ingested successfully via view');
        PRINT '  [SUCCESS] bronze.sa_traffic_accidents loaded: ' + CAST(@rows AS NVARCHAR(20)) + ' rows.';

        -- ----------------------------------------------------------------------
        -- Step 3: Ingest av_telemetry_failures_saudi.csv
        -- ----------------------------------------------------------------------
        SET @step_start = SYSDATETIME();
        SET @file_name = 'av_telemetry_failures_saudi.csv';
        SET @file_path = @base_path + '\' + @file_name;

        TRUNCATE TABLE bronze.av_telemetry;

        SET @sql = N'
            BULK INSERT bronze.v_av_telemetry_load
            FROM ''' + @file_path + '''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        UPDATE bronze.av_telemetry 
        SET source_file = @file_name 
        WHERE source_file IS NULL;

        SELECT @rows = COUNT_BIG(*) FROM bronze.av_telemetry;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, @file_name, 'bronze.av_telemetry', @step_start, @step_end, @rows, 'SUCCESS', 'Ingested successfully via view');
        PRINT '  [SUCCESS] bronze.av_telemetry loaded: ' + CAST(@rows AS NVARCHAR(20)) + ' rows.';

        PRINT '====================================================================';
        PRINT 'Bronze Ingestion Finished Successfully. Total Batch Time: ' + 
              CAST(DATEDIFF(SECOND, @start_time, SYSDATETIME()) AS NVARCHAR(10)) + 's';
        PRINT '====================================================================';
    END TRY
    BEGIN CATCH
        SET @step_end = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, ISNULL(@file_name, 'UNKNOWN'), 'bronze.*', @start_time, @step_end, 0, 'FAILED', ERROR_MESSAGE());

        PRINT '====================================================================';
        PRINT 'ERROR in bronze.load_bronze: ' + ERROR_MESSAGE();
        PRINT '====================================================================';
        THROW;
    END CATCH;
END;
GO
