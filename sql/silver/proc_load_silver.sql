-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: proc_load_silver.sql
-- Purpose: Automated transformation procedure to load trusted Silver tables.
-- Reference: Unit 3 Lab 4 (6 Verbs: Trim, Convert, Map, Dedupe, Validate, Reject)
-- Usage:   EXEC silver.load_silver;
-- ==============================================================================

USE av_ready_saudi_dw;
GO

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Any run-time error triggers automatic rollback

    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_weather BIGINT;
    DECLARE @rows_accidents BIGINT;
    DECLARE @rows_telemetry BIGINT;

    PRINT '==================================================';
    PRINT 'Starting Silver Transformation | Batch ID: ' + CAST(@batch_id AS NVARCHAR(50));
    PRINT '==================================================';

    BEGIN TRY
        BEGIN TRAN;

        -- 1. Truncate Silver targets and quarantine reject log
        TRUNCATE TABLE silver.sa_weather;
        TRUNCATE TABLE silver.sa_traffic_accidents;
        TRUNCATE TABLE silver.av_telemetry;
        TRUNCATE TABLE silver.reject_log;

        -- ----------------------------------------------------------------------
        -- 2. Transform Saudi Weather: Deduplicate, Type, Validate, Standardize
        -- ----------------------------------------------------------------------
        PRINT 'Transforming: bronze.sa_weather -> silver.sa_weather & reject_log';

        ;WITH raw_deduped AS (
            SELECT 
                row_id,
                NULLIF(LTRIM(RTRIM(city)), '') AS city_clean,
                NULLIF(LTRIM(RTRIM(weather_date)), '') AS date_clean,
                NULLIF(LTRIM(RTRIM(weather_time)), '') AS time_clean,
                NULLIF(LTRIM(RTRIM(weather_year)), '') AS year_clean,
                NULLIF(LTRIM(RTRIM(weather_month)), '') AS month_clean,
                NULLIF(LTRIM(RTRIM(weather_day)), '') AS day_clean,
                NULLIF(LTRIM(RTRIM(weather_hour)), '') AS hour_clean,
                UPPER(NULLIF(LTRIM(RTRIM(weather_condition)), '')) AS condition_clean,
                NULLIF(LTRIM(RTRIM(temp)), '') AS temp_clean,
                NULLIF(LTRIM(RTRIM(wind)), '') AS wind_clean,
                REPLACE(NULLIF(LTRIM(RTRIM(humidity)), ''), '%', '') AS humidity_clean,
                NULLIF(LTRIM(RTRIM(barometer)), '') AS barometer_clean,
                NULLIF(LTRIM(RTRIM(visibility)), '') AS visibility_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY city, weather_date, weather_time 
                    ORDER BY TRY_CONVERT(BIGINT, row_id) ASC
                ) AS rn
            FROM bronze.sa_weather
        ),
        typed_weather AS (
            SELECT 
                row_id,
                city_clean AS city,
                TRY_CONVERT(DATE, date_clean) AS weather_date,
                TRY_CONVERT(TIME(0), time_clean) AS weather_time,
                TRY_CONVERT(INT, year_clean) AS weather_year,
                TRY_CONVERT(INT, month_clean) AS weather_month,
                TRY_CONVERT(INT, day_clean) AS weather_day,
                TRY_CONVERT(INT, hour_clean) AS weather_hour,
                ISNULL(condition_clean, 'UNKNOWN') AS weather_condition,
                TRY_CONVERT(DECIMAL(6,2), temp_clean) AS temp_c,
                TRY_CONVERT(DECIMAL(6,2), wind_clean) AS wind_kmh,
                TRY_CONVERT(DECIMAL(5,2), humidity_clean) AS humidity_pct,
                TRY_CONVERT(DECIMAL(8,2), barometer_clean) AS barometer_mbar,
                TRY_CONVERT(DECIMAL(6,2), visibility_clean) AS visibility_km,
                CASE 
                    WHEN city_clean IS NULL THEN 'missing city'
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid weather_date'
                    WHEN temp_clean IS NULL OR TRY_CONVERT(DECIMAL(6,2), temp_clean) IS NULL THEN 'invalid temperature'
                    WHEN TRY_CONVERT(DECIMAL(6,2), temp_clean) < -20 OR TRY_CONVERT(DECIMAL(6,2), temp_clean) > 65 THEN 'extreme impossible temp'
                    ELSE NULL
                END AS reject_reason
            FROM raw_deduped
            WHERE rn = 1
        )
        SELECT * INTO #weather_stage FROM typed_weather;

        -- Quarantine rejected weather records
        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.sa_weather', 'RowID:' + ISNULL(row_id, 'NULL'), reject_reason
        FROM #weather_stage
        WHERE reject_reason IS NOT NULL;

        -- Insert clean accepted weather records
        INSERT INTO silver.sa_weather (
            city, weather_date, weather_time, weather_year, weather_month, weather_day, weather_hour,
            weather_condition, temp_c, wind_kmh, humidity_pct, barometer_mbar, visibility_km
        )
        SELECT 
            city, weather_date, weather_time, weather_year, weather_month, weather_day, weather_hour,
            weather_condition, temp_c, wind_kmh, humidity_pct, barometer_mbar, visibility_km
        FROM #weather_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #weather_stage;

        -- ----------------------------------------------------------------------
        -- 3. Transform Saudi Traffic Accidents
        -- ----------------------------------------------------------------------
        PRINT 'Transforming: bronze.sa_traffic_accidents -> silver.sa_traffic_accidents & reject_log';

        ;WITH raw_accidents AS (
            SELECT 
                NULLIF(LTRIM(RTRIM(accident_year)), '') AS year_clean,
                UPPER(NULLIF(LTRIM(RTRIM(region)), '')) AS region_clean,
                UPPER(NULLIF(LTRIM(RTRIM(indicator)), '')) AS indicator_clean,
                NULLIF(LTRIM(RTRIM(indicator_value)), '') AS value_clean,
                REPLACE(REPLACE(geo_point_2d, CHAR(13), ''), CHAR(10), '') AS geo_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY accident_year, region, indicator 
                    ORDER BY accident_year DESC
                ) AS rn
            FROM bronze.sa_traffic_accidents
        ),
        typed_accidents AS (
            SELECT 
                region_clean AS region,
                TRY_CONVERT(INT, year_clean) AS accident_year,
                indicator_clean AS indicator,
                TRY_CONVERT(INT, value_clean) AS indicator_value,
                CASE 
                    WHEN CHARINDEX(',', geo_clean) > 0 
                    THEN TRY_CONVERT(DECIMAL(10,6), LTRIM(RTRIM(SUBSTRING(geo_clean, 1, CHARINDEX(',', geo_clean) - 1))))
                    ELSE NULL 
                END AS latitude,
                CASE 
                    WHEN CHARINDEX(',', geo_clean) > 0 
                    THEN TRY_CONVERT(DECIMAL(10,6), LTRIM(RTRIM(SUBSTRING(geo_clean, CHARINDEX(',', geo_clean) + 1, LEN(geo_clean)))))
                    ELSE NULL 
                END AS longitude,
                CASE 
                    WHEN year_clean IS NULL OR TRY_CONVERT(INT, year_clean) IS NULL THEN 'invalid accident_year'
                    WHEN region_clean IS NULL THEN 'missing region'
                    WHEN value_clean IS NULL OR TRY_CONVERT(INT, value_clean) IS NULL THEN 'invalid indicator_value'
                    WHEN TRY_CONVERT(INT, value_clean) < 0 THEN 'negative indicator_value'
                    ELSE NULL
                END AS reject_reason
            FROM raw_accidents
            WHERE rn = 1
        )
        SELECT * INTO #accidents_stage FROM typed_accidents;

        -- Quarantine rejected accident records
        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.sa_traffic_accidents', ISNULL(region, 'UNKNOWN') + ':' + ISNULL(indicator, 'UNKNOWN'), reject_reason
        FROM #accidents_stage
        WHERE reject_reason IS NOT NULL;

        -- Insert clean accepted accident records
        INSERT INTO silver.sa_traffic_accidents (
            accident_year, region, indicator, indicator_value, latitude, longitude
        )
        SELECT 
            accident_year, region, indicator, indicator_value, latitude, longitude
        FROM #accidents_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #accidents_stage;

        -- ----------------------------------------------------------------------
        -- 4. Transform Autonomous Racing Telemetry
        -- ----------------------------------------------------------------------
        PRINT 'Transforming: bronze.av_telemetry -> silver.av_telemetry & reject_log';

        ;WITH raw_telemetry AS (
            SELECT 
                NULLIF(LTRIM(RTRIM(frame_id)), '') AS frame_clean,
                NULLIF(LTRIM(RTRIM(timestamp_val)), '') AS ts_clean,
                NULLIF(LTRIM(RTRIM(pos_x)), '') AS x_clean,
                NULLIF(LTRIM(RTRIM(pos_y)), '') AS y_clean,
                NULLIF(LTRIM(RTRIM(pos_z)), '') AS z_clean,
                NULLIF(LTRIM(RTRIM(q_x)), '') AS qx_clean,
                NULLIF(LTRIM(RTRIM(q_y)), '') AS qy_clean,
                NULLIF(LTRIM(RTRIM(q_z)), '') AS qz_clean,
                NULLIF(LTRIM(RTRIM(q_w)), '') AS qw_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY frame_id 
                    ORDER BY TRY_CONVERT(DECIMAL(20,6), timestamp_val) DESC
                ) AS rn
            FROM bronze.av_telemetry
        ),
        typed_telemetry AS (
            SELECT 
                TRY_CONVERT(BIGINT, frame_clean) AS frame_id,
                TRY_CONVERT(DECIMAL(20,6), ts_clean) AS timestamp_val,
                TRY_CONVERT(DECIMAL(12,4), x_clean) AS pos_x,
                TRY_CONVERT(DECIMAL(12,4), y_clean) AS pos_y,
                TRY_CONVERT(DECIMAL(12,4), z_clean) AS pos_z,
                TRY_CONVERT(DECIMAL(10,6), qx_clean) AS q_x,
                TRY_CONVERT(DECIMAL(10,6), qy_clean) AS q_y,
                TRY_CONVERT(DECIMAL(10,6), qz_clean) AS q_z,
                TRY_CONVERT(DECIMAL(10,6), qw_clean) AS q_w,
                CASE 
                    WHEN frame_clean IS NULL OR TRY_CONVERT(BIGINT, frame_clean) IS NULL THEN 'invalid frame_id'
                    WHEN ts_clean IS NULL OR TRY_CONVERT(DECIMAL(20,6), ts_clean) IS NULL THEN 'invalid timestamp'
                    WHEN x_clean IS NULL OR TRY_CONVERT(DECIMAL(12,4), x_clean) IS NULL THEN 'invalid pos_x'
                    ELSE NULL
                END AS reject_reason
            FROM raw_telemetry
            WHERE rn = 1
        )
        SELECT * INTO #telemetry_stage FROM typed_telemetry;

        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.av_telemetry', 'Frame:' + ISNULL(CAST(frame_id AS VARCHAR(30)), 'NULL'), reject_reason
        FROM #telemetry_stage
        WHERE reject_reason IS NOT NULL;

        INSERT INTO silver.av_telemetry (
            frame_id, timestamp_val, pos_x, pos_y, pos_z, q_x, q_y, q_z, q_w
        )
        SELECT 
            frame_id, timestamp_val, pos_x, pos_y, pos_z, q_x, q_y, q_z, q_w
        FROM #telemetry_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #telemetry_stage;

        COMMIT; -- All or nothing: commit when all operations succeed

        -- Count rows loaded into Silver
        SELECT @rows_weather = COUNT_BIG(*) FROM silver.sa_weather;
        SELECT @rows_accidents = COUNT_BIG(*) FROM silver.sa_traffic_accidents;
        SELECT @rows_telemetry = COUNT_BIG(*) FROM silver.av_telemetry;
        SET @end_time = SYSDATETIME();

        -- Log successful Silver load into audit log
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES 
            (@batch_id, 'bronze.sa_weather', 'silver.sa_weather', @start_time, @end_time, @rows_weather, 'SUCCESS', 'Silver cleaning, typing, deduplication complete'),
            (@batch_id, 'bronze.sa_traffic_accidents', 'silver.sa_traffic_accidents', @start_time, @end_time, @rows_accidents, 'SUCCESS', 'Silver cleaning & coordinate parsing complete'),
            (@batch_id, 'bronze.av_telemetry', 'silver.av_telemetry', @start_time, @end_time, @rows_telemetry, 'SUCCESS', 'Silver telemetry validation complete');

        PRINT '==================================================';
        PRINT 'Silver Transformation Finished Successfully!';
        PRINT 'Weather Loaded: ' + CAST(@rows_weather AS NVARCHAR(20));
        PRINT 'Accidents Loaded: ' + CAST(@rows_accidents AS NVARCHAR(20));
        PRINT 'Telemetry Loaded: ' + CAST(@rows_telemetry AS NVARCHAR(20));
        PRINT '==================================================';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK; -- Undo half-done work

        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'bronze.*', 'silver.*', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in silver.load_silver: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO
