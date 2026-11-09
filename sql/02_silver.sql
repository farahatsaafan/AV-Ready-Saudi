-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 02_silver.sql
-- Purpose: Create Silver trusted tables, reject quarantine log, and the
--          automated 6-verbs transformation stored procedure silver.load_silver.
-- Course Standard: DM & DW Project Skeleton (Fall 2026)
--
-- The 6 Core Verbs Applied:
--   1. Trim: Remove leading/trailing whitespaces (NULLIF(TRIM(x), '')).
--   2. Standardize: Canonical uppercase and uniform categorical values.
--   3. Convert: Strongly typed concrete types (DATE, INT, DECIMAL, BIT).
--   4. Deduplicate: Window function ROW_NUMBER() OVER (...) retaining rn = 1.
--   5. Validate & Quarantine: Reject rule violations into silver.reject_log.
--   6. Transaction Safety: Encapsulated inside ACID transactions (BEGIN TRAN/COMMIT).
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Silver Centralized Reject Log (Quarantine)
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.reject_log;
GO

CREATE TABLE silver.reject_log (
    reject_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_table   VARCHAR(50)          NOT NULL,
    business_key   VARCHAR(50)          NULL,
    reason         VARCHAR(100)         NOT NULL,
    DW_create_date DATETIME2            NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 2. Silver Table: Meteorological Observations
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.sa_weather;
GO

CREATE TABLE silver.sa_weather (
    weather_key        INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate key
    weather_date       DATE              NOT NULL,
    weather_year       INT               NOT NULL,
    weather_month      INT               NOT NULL,
    weather_day        INT               NOT NULL,
    city_id            VARCHAR(10)       NOT NULL,    -- Natural key component
    city_name_en       NVARCHAR(100)     NOT NULL,
    city_name_ar       NVARCHAR(100)     NOT NULL,
    latitude           DECIMAL(10,6)     NOT NULL,
    longitude          DECIMAL(10,6)     NOT NULL,
    temp_max_c         DECIMAL(5,2)      NOT NULL,
    temp_min_c         DECIMAL(5,2)      NOT NULL,
    temp_mean_c        DECIMAL(5,2)      NOT NULL,
    precipitation_mm   DECIMAL(6,2)      NOT NULL,
    wind_speed_max_kmh DECIMAL(5,2)      NOT NULL,
    wind_gusts_max_kmh DECIMAL(5,2)      NOT NULL,
    solar_radiation_mj DECIMAL(6,2)      NOT NULL,
    weather_code_wmo   INT               NOT NULL,
    is_dust_storm      BIT               NOT NULL,
    is_extreme_heat    BIT               NOT NULL,
    DW_create_date     DATETIME2         NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 3. Silver Table: Highway Traffic Accidents
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.sa_traffic_accidents;
GO

CREATE TABLE silver.sa_traffic_accidents (
    accident_key           INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate key
    accident_id            VARCHAR(50)       NOT NULL,    -- Natural key
    accident_date          DATE              NOT NULL,
    accident_year          INT               NOT NULL,
    accident_month         INT               NOT NULL,
    city_id                VARCHAR(10)       NOT NULL,
    road_name              NVARCHAR(150)     NOT NULL,
    severity               NVARCHAR(50)      NOT NULL,
    primary_cause          NVARCHAR(100)     NOT NULL,
    vehicles_involved      INT               NOT NULL,
    casualties_count       INT               NOT NULL,
    weather_condition_code INT               NULL,
    ambient_temp_c         DECIMAL(5,2)      NULL,
    wind_gusts_kmh         DECIMAL(5,2)      NULL,
    DW_create_date         DATETIME2         NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 4. Silver Table: Autonomous Vehicle Fleet Telemetry & Sensor Degradation
-- ------------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.av_telemetry;
GO

CREATE TABLE silver.av_telemetry (
    telemetry_key         INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate key
    telemetry_id          VARCHAR(50)       NOT NULL,    -- Natural key
    telemetry_date        DATE              NOT NULL,
    city_id               VARCHAR(10)       NOT NULL,
    vehicle_id            VARCHAR(50)       NOT NULL,
    speed_kmh             DECIMAL(6,2)      NOT NULL,
    battery_temp_c        DECIMAL(5,2)      NOT NULL,
    gpu_temp_c            DECIMAL(5,2)      NOT NULL,
    tire_pressure_psi     DECIMAL(5,2)      NOT NULL,
    lidar_attenuation_pct DECIMAL(5,2)      NOT NULL,
    camera_glare_index    DECIMAL(4,2)      NOT NULL,
    failure_occurred      BIT               NOT NULL,
    failure_type          NVARCHAR(100)     NOT NULL,
    severity              NVARCHAR(50)      NOT NULL,
    av_disengagement      BIT               NOT NULL,
    DW_create_date        DATETIME2         NOT NULL DEFAULT SYSDATETIME()
);
GO

PRINT 'Silver tables and reject log created successfully.';
GO

-- ------------------------------------------------------------------------------
-- 5. Stored Procedure: silver.load_silver
-- Usage: EXEC silver.load_silver;
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @step_start DATETIME2;
    DECLARE @step_end DATETIME2;
    DECLARE @rows_weather BIGINT;
    DECLARE @rows_accidents BIGINT;
    DECLARE @rows_telemetry BIGINT;
    DECLARE @rows_rejected BIGINT;

    PRINT '====================================================================';
    PRINT 'Starting Silver Cleansing & Transformation Batch: ' + CAST(@batch_id AS NVARCHAR(50));
    PRINT '====================================================================';

    BEGIN TRY
        BEGIN TRAN;

        -- ----------------------------------------------------------------------
        -- Step 1: Truncate destination Silver tables and reject log
        -- ----------------------------------------------------------------------
        TRUNCATE TABLE silver.reject_log;
        TRUNCATE TABLE silver.sa_weather;
        TRUNCATE TABLE silver.sa_traffic_accidents;
        TRUNCATE TABLE silver.av_telemetry;

        -- ----------------------------------------------------------------------
        -- Step 2: Transform bronze.sa_weather -> silver.sa_weather & reject_log
        -- ----------------------------------------------------------------------
        SET @step_start = SYSDATETIME();

        ;WITH raw_weather_deduped AS (
            SELECT 
                NULLIF(LTRIM(RTRIM([date])), '') AS date_clean,
                UPPER(NULLIF(LTRIM(RTRIM(city_id)), '')) AS city_id_clean,
                NULLIF(LTRIM(RTRIM(city_name_en)), '') AS city_name_en_clean,
                NULLIF(LTRIM(RTRIM(city_name_ar)), '') AS city_name_ar_clean,
                NULLIF(LTRIM(RTRIM(latitude)), '') AS lat_clean,
                NULLIF(LTRIM(RTRIM(longitude)), '') AS lon_clean,
                NULLIF(LTRIM(RTRIM(temp_max_c)), '') AS temp_max_clean,
                NULLIF(LTRIM(RTRIM(temp_min_c)), '') AS temp_min_clean,
                NULLIF(LTRIM(RTRIM(temp_mean_c)), '') AS temp_mean_clean,
                NULLIF(LTRIM(RTRIM(precipitation_mm)), '') AS precip_clean,
                NULLIF(LTRIM(RTRIM(wind_speed_max_kmh)), '') AS wind_speed_clean,
                NULLIF(LTRIM(RTRIM(wind_gusts_max_kmh)), '') AS wind_gusts_clean,
                NULLIF(LTRIM(RTRIM(solar_radiation_mj)), '') AS solar_clean,
                NULLIF(LTRIM(RTRIM(weather_code_wmo)), '') AS weather_code_clean,
                NULLIF(LTRIM(RTRIM(is_dust_storm)), '') AS dust_clean,
                NULLIF(LTRIM(RTRIM(is_extreme_heat)), '') AS heat_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY NULLIF(LTRIM(RTRIM([date])), ''), UPPER(NULLIF(LTRIM(RTRIM(city_id)), '')) 
                    ORDER BY NULLIF(LTRIM(RTRIM([date])), '') ASC
                ) AS rn
            FROM bronze.sa_weather
        ),
        typed_weather AS (
            SELECT 
                TRY_CONVERT(DATE, date_clean) AS weather_date,
                YEAR(TRY_CONVERT(DATE, date_clean)) AS weather_year,
                MONTH(TRY_CONVERT(DATE, date_clean)) AS weather_month,
                DAY(TRY_CONVERT(DATE, date_clean)) AS weather_day,
                city_id_clean AS city_id,
                city_name_en_clean AS city_name_en,
                city_name_ar_clean AS city_name_ar,
                TRY_CONVERT(DECIMAL(10,6), lat_clean) AS latitude,
                TRY_CONVERT(DECIMAL(10,6), lon_clean) AS longitude,
                TRY_CONVERT(DECIMAL(5,2), temp_max_clean) AS temp_max_c,
                TRY_CONVERT(DECIMAL(5,2), temp_min_clean) AS temp_min_c,
                TRY_CONVERT(DECIMAL(5,2), temp_mean_clean) AS temp_mean_c,
                TRY_CONVERT(DECIMAL(6,2), precip_clean) AS precipitation_mm,
                TRY_CONVERT(DECIMAL(5,2), wind_speed_clean) AS wind_speed_max_kmh,
                TRY_CONVERT(DECIMAL(5,2), wind_gusts_clean) AS wind_gusts_max_kmh,
                TRY_CONVERT(DECIMAL(6,2), solar_clean) AS solar_radiation_mj,
                TRY_CONVERT(INT, weather_code_clean) AS weather_code_wmo,
                CASE 
                    WHEN LOWER(dust_clean) IN ('true', '1') THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS is_dust_storm,
                CASE 
                    WHEN LOWER(heat_clean) IN ('true', '1') THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS is_extreme_heat,
                -- 6-Verbs Validation Gate
                CASE 
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid or missing date'
                    WHEN city_id_clean IS NULL THEN 'missing city_id'
                    WHEN temp_max_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), temp_max_clean) IS NULL THEN 'invalid temp_max_c'
                    WHEN TRY_CONVERT(DECIMAL(5,2), temp_max_clean) < -15.0 OR TRY_CONVERT(DECIMAL(5,2), temp_max_clean) > 65.0 THEN 'temp_max_c out of physical range (-15 to 65C)'
                    ELSE NULL
                END AS reject_reason
            FROM raw_weather_deduped
            WHERE rn = 1
        )
        SELECT * INTO #weather_stage FROM typed_weather;

        -- Quarantine Rejects
        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.sa_weather', ISNULL(city_id, 'UNKNOWN') + '_' + CONVERT(VARCHAR(20), ISNULL(weather_date, '1900-01-01')), reject_reason
        FROM #weather_stage
        WHERE reject_reason IS NOT NULL;

        -- Load Clean Valid Rows
        INSERT INTO silver.sa_weather (
            weather_date, weather_year, weather_month, weather_day,
            city_id, city_name_en, city_name_ar, latitude, longitude,
            temp_max_c, temp_min_c, temp_mean_c, precipitation_mm,
            wind_speed_max_kmh, wind_gusts_max_kmh, solar_radiation_mj,
            weather_code_wmo, is_dust_storm, is_extreme_heat
        )
        SELECT 
            weather_date, weather_year, weather_month, weather_day,
            city_id, city_name_en, city_name_ar, latitude, longitude,
            temp_max_c, temp_min_c, temp_mean_c, precipitation_mm,
            wind_speed_max_kmh, wind_gusts_max_kmh, solar_radiation_mj,
            weather_code_wmo, is_dust_storm, is_extreme_heat
        FROM #weather_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #weather_stage;
        SELECT @rows_weather = COUNT_BIG(*) FROM silver.sa_weather;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'bronze.sa_weather', 'silver.sa_weather', @step_start, @step_end, @rows_weather, 'SUCCESS', 'Cleaned & loaded');
        PRINT '  [SUCCESS] silver.sa_weather: ' + CAST(@rows_weather AS NVARCHAR(20)) + ' rows loaded.';

        -- ----------------------------------------------------------------------
        -- Step 3: Transform bronze.sa_traffic_accidents -> silver.sa_traffic_accidents
        -- ----------------------------------------------------------------------
        SET @step_start = SYSDATETIME();

        ;WITH raw_accidents_deduped AS (
            SELECT 
                UPPER(NULLIF(LTRIM(RTRIM(accident_id)), '')) AS accident_id_clean,
                NULLIF(LTRIM(RTRIM([date])), '') AS date_clean,
                UPPER(NULLIF(LTRIM(RTRIM(city_id)), '')) AS city_id_clean,
                NULLIF(LTRIM(RTRIM(road_name)), '') AS road_name_clean,
                UPPER(NULLIF(LTRIM(RTRIM(severity)), '')) AS severity_clean,
                UPPER(NULLIF(LTRIM(RTRIM(primary_cause)), '')) AS primary_cause_clean,
                NULLIF(LTRIM(RTRIM(vehicles_involved)), '') AS vehicles_clean,
                NULLIF(LTRIM(RTRIM(casualties_count)), '') AS casualties_clean,
                NULLIF(LTRIM(RTRIM(weather_condition_code)), '') AS weather_code_clean,
                NULLIF(LTRIM(RTRIM(ambient_temp_c)), '') AS temp_clean,
                NULLIF(LTRIM(RTRIM(wind_gusts_kmh)), '') AS gusts_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY UPPER(NULLIF(LTRIM(RTRIM(accident_id)), '')) 
                    ORDER BY NULLIF(LTRIM(RTRIM(accident_id)), '') ASC
                ) AS rn
            FROM bronze.sa_traffic_accidents
        ),
        typed_accidents AS (
            SELECT 
                accident_id_clean AS accident_id,
                TRY_CONVERT(DATE, date_clean) AS accident_date,
                YEAR(TRY_CONVERT(DATE, date_clean)) AS accident_year,
                MONTH(TRY_CONVERT(DATE, date_clean)) AS accident_month,
                city_id_clean AS city_id,
                ISNULL(road_name_clean, N'National Highway') AS road_name,
                ISNULL(severity_clean, 'MODERATE') AS severity,
                ISNULL(primary_cause_clean, 'UNKNOWN') AS primary_cause,
                TRY_CONVERT(INT, vehicles_clean) AS vehicles_involved,
                TRY_CONVERT(INT, casualties_clean) AS casualties_count,
                TRY_CONVERT(INT, weather_code_clean) AS weather_condition_code,
                TRY_CONVERT(DECIMAL(5,2), temp_clean) AS ambient_temp_c,
                TRY_CONVERT(DECIMAL(5,2), gusts_clean) AS wind_gusts_kmh,
                -- 6-Verbs Validation Gate
                CASE 
                    WHEN accident_id_clean IS NULL THEN 'missing accident_id'
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid accident_date'
                    WHEN city_id_clean IS NULL THEN 'missing city_id'
                    WHEN vehicles_clean IS NULL OR TRY_CONVERT(INT, vehicles_clean) < 1 THEN 'invalid vehicles_involved (< 1)'
                    WHEN casualties_clean IS NULL OR TRY_CONVERT(INT, casualties_clean) < 0 THEN 'negative casualties_count'
                    ELSE NULL
                END AS reject_reason
            FROM raw_accidents_deduped
            WHERE rn = 1
        )
        SELECT * INTO #accidents_stage FROM typed_accidents;

        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.sa_traffic_accidents', ISNULL(accident_id, 'UNKNOWN'), reject_reason
        FROM #accidents_stage
        WHERE reject_reason IS NOT NULL;

        INSERT INTO silver.sa_traffic_accidents (
            accident_id, accident_date, accident_year, accident_month,
            city_id, road_name, severity, primary_cause,
            vehicles_involved, casualties_count, weather_condition_code,
            ambient_temp_c, wind_gusts_kmh
        )
        SELECT 
            accident_id, accident_date, accident_year, accident_month,
            city_id, road_name, severity, primary_cause,
            vehicles_involved, casualties_count, weather_condition_code,
            ambient_temp_c, wind_gusts_kmh
        FROM #accidents_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #accidents_stage;
        SELECT @rows_accidents = COUNT_BIG(*) FROM silver.sa_traffic_accidents;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'bronze.sa_traffic_accidents', 'silver.sa_traffic_accidents', @step_start, @step_end, @rows_accidents, 'SUCCESS', 'Cleaned & loaded');
        PRINT '  [SUCCESS] silver.sa_traffic_accidents: ' + CAST(@rows_accidents AS NVARCHAR(20)) + ' rows loaded.';

        -- ----------------------------------------------------------------------
        -- Step 4: Transform bronze.av_telemetry -> silver.av_telemetry
        -- ----------------------------------------------------------------------
        SET @step_start = SYSDATETIME();

        ;WITH raw_telemetry_deduped AS (
            SELECT 
                UPPER(NULLIF(LTRIM(RTRIM(telemetry_id)), '')) AS telemetry_id_clean,
                NULLIF(LTRIM(RTRIM([date])), '') AS date_clean,
                UPPER(NULLIF(LTRIM(RTRIM(city_id)), '')) AS city_id_clean,
                UPPER(NULLIF(LTRIM(RTRIM(vehicle_id)), '')) AS vehicle_id_clean,
                NULLIF(LTRIM(RTRIM(speed_kmh)), '') AS speed_clean,
                NULLIF(LTRIM(RTRIM(battery_temp_c)), '') AS bat_temp_clean,
                NULLIF(LTRIM(RTRIM(gpu_temp_c)), '') AS gpu_temp_clean,
                NULLIF(LTRIM(RTRIM(tire_pressure_psi)), '') AS tire_p_clean,
                NULLIF(LTRIM(RTRIM(lidar_attenuation_pct)), '') AS lidar_clean,
                NULLIF(LTRIM(RTRIM(camera_glare_index)), '') AS glare_clean,
                NULLIF(LTRIM(RTRIM(failure_occurred)), '') AS fail_clean,
                UPPER(NULLIF(LTRIM(RTRIM(failure_type)), '')) AS fail_type_clean,
                UPPER(NULLIF(LTRIM(RTRIM(severity)), '')) AS severity_clean,
                NULLIF(LTRIM(RTRIM(av_disengagement)), '') AS disengage_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY UPPER(NULLIF(LTRIM(RTRIM(telemetry_id)), '')) 
                    ORDER BY NULLIF(LTRIM(RTRIM(telemetry_id)), '') ASC
                ) AS rn
            FROM bronze.av_telemetry
        ),
        typed_telemetry AS (
            SELECT 
                telemetry_id_clean AS telemetry_id,
                TRY_CONVERT(DATE, date_clean) AS telemetry_date,
                city_id_clean AS city_id,
                ISNULL(vehicle_id_clean, 'AV-SAUDI-001') AS vehicle_id,
                TRY_CONVERT(DECIMAL(6,2), speed_clean) AS speed_kmh,
                TRY_CONVERT(DECIMAL(5,2), bat_temp_clean) AS battery_temp_c,
                TRY_CONVERT(DECIMAL(5,2), gpu_temp_clean) AS gpu_temp_c,
                TRY_CONVERT(DECIMAL(5,2), tire_p_clean) AS tire_pressure_psi,
                TRY_CONVERT(DECIMAL(5,2), lidar_clean) AS lidar_attenuation_pct,
                TRY_CONVERT(DECIMAL(4,2), glare_clean) AS camera_glare_index,
                CASE 
                    WHEN LOWER(fail_clean) IN ('true', '1') THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS failure_occurred,
                ISNULL(fail_type_clean, 'NONE') AS failure_type,
                ISNULL(severity_clean, 'NORMAL') AS severity,
                CASE 
                    WHEN LOWER(disengage_clean) IN ('true', '1') THEN CAST(1 AS BIT)
                    ELSE CAST(0 AS BIT)
                END AS av_disengagement,
                -- 6-Verbs Validation Gate
                CASE 
                    WHEN telemetry_id_clean IS NULL THEN 'missing telemetry_id'
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid telemetry_date'
                    WHEN city_id_clean IS NULL THEN 'missing city_id'
                    WHEN speed_clean IS NULL OR TRY_CONVERT(DECIMAL(6,2), speed_clean) < 0.0 OR TRY_CONVERT(DECIMAL(6,2), speed_clean) > 250.0 THEN 'speed_kmh out of physical range (0 to 250)'
                    WHEN bat_temp_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), bat_temp_clean) < -10.0 OR TRY_CONVERT(DECIMAL(5,2), bat_temp_clean) > 90.0 THEN 'battery_temp_c out of range (-10 to 90C)'
                    WHEN gpu_temp_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), gpu_temp_clean) < 10.0 OR TRY_CONVERT(DECIMAL(5,2), gpu_temp_clean) > 115.0 THEN 'gpu_temp_c out of range (10 to 115C)'
                    ELSE NULL
                END AS reject_reason
            FROM raw_telemetry_deduped
            WHERE rn = 1
        )
        SELECT * INTO #telemetry_stage FROM typed_telemetry;

        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.av_telemetry', ISNULL(telemetry_id, 'UNKNOWN'), reject_reason
        FROM #telemetry_stage
        WHERE reject_reason IS NOT NULL;

        INSERT INTO silver.av_telemetry (
            telemetry_id, telemetry_date, city_id, vehicle_id,
            speed_kmh, battery_temp_c, gpu_temp_c, tire_pressure_psi,
            lidar_attenuation_pct, camera_glare_index, failure_occurred,
            failure_type, severity, av_disengagement
        )
        SELECT 
            telemetry_id, telemetry_date, city_id, vehicle_id,
            speed_kmh, battery_temp_c, gpu_temp_c, tire_pressure_psi,
            lidar_attenuation_pct, camera_glare_index, failure_occurred,
            failure_type, severity, av_disengagement
        FROM #telemetry_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #telemetry_stage;
        SELECT @rows_telemetry = COUNT_BIG(*) FROM silver.av_telemetry;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'bronze.av_telemetry', 'silver.av_telemetry', @step_start, @step_end, @rows_telemetry, 'SUCCESS', 'Cleaned & loaded');
        PRINT '  [SUCCESS] silver.av_telemetry: ' + CAST(@rows_telemetry AS NVARCHAR(20)) + ' rows loaded.';

        -- Commit transaction
        COMMIT;

        SELECT @rows_rejected = COUNT_BIG(*) FROM silver.reject_log;
        PRINT '====================================================================';
        PRINT 'Silver Transformation Finished Successfully!';
        PRINT 'Weather Rows:    ' + CAST(@rows_weather AS NVARCHAR(20));
        PRINT 'Accident Rows:   ' + CAST(@rows_accidents AS NVARCHAR(20));
        PRINT 'Telemetry Rows:  ' + CAST(@rows_telemetry AS NVARCHAR(20));
        PRINT 'Rejected Rows:   ' + CAST(@rows_rejected AS NVARCHAR(20));
        PRINT 'Total Batch Time: ' + CAST(DATEDIFF(SECOND, @start_time, SYSDATETIME()) AS NVARCHAR(10)) + 's';
        PRINT '====================================================================';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @step_end = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'bronze.*', 'silver.*', @start_time, @step_end, 0, 'FAILED', ERROR_MESSAGE());

        PRINT '====================================================================';
        PRINT 'ERROR in silver.load_silver: ' + ERROR_MESSAGE();
        PRINT '====================================================================';
        THROW;
    END CATCH;
END;
GO
