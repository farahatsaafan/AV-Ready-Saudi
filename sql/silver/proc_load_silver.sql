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
    DECLARE @rows_rejected BIGINT;

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

        ;WITH raw_weather_deduped AS (
            SELECT 
                NULLIF(LTRIM(RTRIM([date])), '') AS date_clean,
                UPPER(NULLIF(LTRIM(RTRIM(city_id)), '')) AS city_id_clean,
                UPPER(NULLIF(LTRIM(RTRIM(city_name_en)), '')) AS city_name_en_clean,
                NULLIF(LTRIM(RTRIM(city_name_ar)), '') AS city_name_ar_clean,
                NULLIF(LTRIM(RTRIM(latitude)), '') AS lat_clean,
                NULLIF(LTRIM(RTRIM(longitude)), '') AS lon_clean,
                NULLIF(LTRIM(RTRIM(temp_max_c)), '') AS temp_max_clean,
                NULLIF(LTRIM(RTRIM(temp_min_c)), '') AS temp_min_clean,
                NULLIF(LTRIM(RTRIM(temp_mean_c)), '') AS temp_mean_clean,
                NULLIF(LTRIM(RTRIM(precipitation_mm)), '') AS precip_clean,
                NULLIF(LTRIM(RTRIM(wind_speed_max_kmh)), '') AS wind_speed_clean,
                NULLIF(LTRIM(RTRIM(wind_gusts_max_kmh)), '') AS wind_gusts_clean,
                NULLIF(LTRIM(RTRIM(solar_radiation_mj)), '') AS solar_rad_clean,
                NULLIF(LTRIM(RTRIM(weather_code_wmo)), '') AS wmo_code_clean,
                NULLIF(LTRIM(RTRIM(is_dust_storm)), '') AS dust_clean,
                NULLIF(LTRIM(RTRIM(is_extreme_heat)), '') AS heat_clean,
                ROW_NUMBER() OVER (
                    PARTITION BY UPPER(LTRIM(RTRIM(city_id))), LTRIM(RTRIM([date])) 
                    ORDER BY LTRIM(RTRIM([date])) ASC
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
                ISNULL(city_name_en_clean, 'UNKNOWN') AS city_name_en,
                ISNULL(city_name_ar_clean, N'غير محدد') AS city_name_ar,
                TRY_CONVERT(DECIMAL(10,6), lat_clean) AS latitude,
                TRY_CONVERT(DECIMAL(10,6), lon_clean) AS longitude,
                TRY_CONVERT(DECIMAL(5,2), temp_max_clean) AS temp_max_c,
                TRY_CONVERT(DECIMAL(5,2), temp_min_clean) AS temp_min_c,
                TRY_CONVERT(DECIMAL(5,2), temp_mean_clean) AS temp_mean_c,
                TRY_CONVERT(DECIMAL(6,2), precip_clean) AS precipitation_mm,
                TRY_CONVERT(DECIMAL(5,2), wind_speed_clean) AS wind_speed_max_kmh,
                TRY_CONVERT(DECIMAL(5,2), wind_gusts_clean) AS wind_gusts_max_kmh,
                TRY_CONVERT(DECIMAL(6,2), solar_rad_clean) AS solar_radiation_mj,
                TRY_CONVERT(INT, wmo_code_clean) AS weather_code_wmo,
                CASE WHEN UPPER(dust_clean) IN ('TRUE', '1') THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_dust_storm,
                CASE WHEN UPPER(heat_clean) IN ('TRUE', '1') THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS is_extreme_heat,
                -- 6 Verbs: Validate & Reject Reason Mapping
                CASE 
                    WHEN city_id_clean IS NULL THEN 'missing city_id'
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid weather_date'
                    WHEN temp_max_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), temp_max_clean) IS NULL THEN 'invalid temp_max_c'
                    WHEN TRY_CONVERT(DECIMAL(5,2), temp_max_clean) < -15.0 OR TRY_CONVERT(DECIMAL(5,2), temp_max_clean) > 65.0 THEN 'impossible temperature for Saudi Arabia'
                    WHEN TRY_CONVERT(DECIMAL(10,6), lat_clean) NOT BETWEEN 15.0 AND 33.0 THEN 'latitude out of Saudi bounds'
                    WHEN TRY_CONVERT(DECIMAL(10,6), lon_clean) NOT BETWEEN 34.0 AND 56.0 THEN 'longitude out of Saudi bounds'
                    WHEN TRY_CONVERT(DECIMAL(6,2), precip_clean) < 0.0 THEN 'negative precipitation'
                    WHEN TRY_CONVERT(DECIMAL(5,2), wind_speed_clean) < 0.0 THEN 'negative wind speed'
                    ELSE NULL
                END AS reject_reason
            FROM raw_weather_deduped
            WHERE rn = 1
        )
        SELECT * INTO #weather_stage FROM typed_weather;

        -- Quarantine rejected weather records
        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.sa_weather', ISNULL(city_id, 'NULL') + ':' + ISNULL(CONVERT(VARCHAR(20), weather_date), 'NULL'), reject_reason
        FROM #weather_stage
        WHERE reject_reason IS NOT NULL;

        -- Insert clean accepted weather records
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

        -- ----------------------------------------------------------------------
        -- 3. Transform Saudi Highway Traffic Accidents
        -- ----------------------------------------------------------------------
        PRINT 'Transforming: bronze.sa_traffic_accidents -> silver.sa_traffic_accidents & reject_log';

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
                    PARTITION BY UPPER(LTRIM(RTRIM(accident_id))) 
                    ORDER BY LTRIM(RTRIM(accident_id)) ASC
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
                ISNULL(road_name_clean, N'طريق عام') AS road_name,
                ISNULL(severity_clean, 'MEDIUM') AS severity,
                ISNULL(primary_cause_clean, 'UNKNOWN') AS primary_cause,
                TRY_CONVERT(INT, vehicles_clean) AS vehicles_involved,
                TRY_CONVERT(INT, casualties_clean) AS casualties_count,
                TRY_CONVERT(INT, weather_code_clean) AS weather_condition_code,
                TRY_CONVERT(DECIMAL(5,2), temp_clean) AS ambient_temp_c,
                TRY_CONVERT(DECIMAL(5,2), gusts_clean) AS wind_gusts_kmh,
                -- 6 Verbs: Validate & Reject Reason Mapping
                CASE 
                    WHEN accident_id_clean IS NULL THEN 'missing accident_id'
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid accident_date'
                    WHEN city_id_clean IS NULL THEN 'missing city_id'
                    WHEN vehicles_clean IS NULL OR TRY_CONVERT(INT, vehicles_clean) IS NULL OR TRY_CONVERT(INT, vehicles_clean) < 1 THEN 'invalid vehicles_involved (< 1)'
                    WHEN casualties_clean IS NULL OR TRY_CONVERT(INT, casualties_clean) IS NULL OR TRY_CONVERT(INT, casualties_clean) < 0 THEN 'negative casualties_count'
                    ELSE NULL
                END AS reject_reason
            FROM raw_accidents_deduped
            WHERE rn = 1
        )
        SELECT * INTO #accidents_stage FROM typed_accidents;

        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.sa_traffic_accidents', ISNULL(accident_id, 'NULL'), reject_reason
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

        -- ----------------------------------------------------------------------
        -- 4. Transform Autonomous Vehicle Fleet Telemetry
        -- ----------------------------------------------------------------------
        PRINT 'Transforming: bronze.av_telemetry -> silver.av_telemetry & reject_log';

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
                    PARTITION BY UPPER(LTRIM(RTRIM(telemetry_id))) 
                    ORDER BY LTRIM(RTRIM(telemetry_id)) ASC
                ) AS rn
            FROM bronze.av_telemetry
        ),
        typed_telemetry AS (
            SELECT 
                telemetry_id_clean AS telemetry_id,
                TRY_CONVERT(DATE, date_clean) AS telemetry_date,
                city_id_clean AS city_id,
                vehicle_id_clean AS vehicle_id,
                TRY_CONVERT(DECIMAL(6,2), speed_clean) AS speed_kmh,
                TRY_CONVERT(DECIMAL(5,2), bat_temp_clean) AS battery_temp_c,
                TRY_CONVERT(DECIMAL(5,2), gpu_temp_clean) AS gpu_temp_c,
                TRY_CONVERT(DECIMAL(5,2), tire_p_clean) AS tire_pressure_psi,
                TRY_CONVERT(DECIMAL(5,2), lidar_clean) AS lidar_attenuation_pct,
                TRY_CONVERT(DECIMAL(4,2), glare_clean) AS camera_glare_index,
                CASE WHEN UPPER(fail_clean) IN ('TRUE', '1') THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS failure_occurred,
                ISNULL(fail_type_clean, 'NONE') AS failure_type,
                ISNULL(severity_clean, 'NORMAL') AS severity,
                CASE WHEN UPPER(disengage_clean) IN ('TRUE', '1') THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS av_disengagement,
                -- 6 Verbs: Validate & Reject Reason Mapping
                CASE 
                    WHEN telemetry_id_clean IS NULL THEN 'missing telemetry_id'
                    WHEN date_clean IS NULL OR TRY_CONVERT(DATE, date_clean) IS NULL THEN 'invalid telemetry_date'
                    WHEN vehicle_id_clean IS NULL THEN 'missing vehicle_id'
                    WHEN city_id_clean IS NULL THEN 'missing city_id'
                    WHEN speed_clean IS NULL OR TRY_CONVERT(DECIMAL(6,2), speed_clean) IS NULL OR TRY_CONVERT(DECIMAL(6,2), speed_clean) < 0.0 OR TRY_CONVERT(DECIMAL(6,2), speed_clean) > 250.0 THEN 'impossible vehicle speed'
                    WHEN bat_temp_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), bat_temp_clean) < -20.0 OR TRY_CONVERT(DECIMAL(5,2), bat_temp_clean) > 100.0 THEN 'impossible battery temperature'
                    WHEN tire_p_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), tire_p_clean) < 10.0 OR TRY_CONVERT(DECIMAL(5,2), tire_p_clean) > 80.0 THEN 'impossible tire pressure'
                    WHEN lidar_clean IS NULL OR TRY_CONVERT(DECIMAL(5,2), lidar_clean) < 0.0 OR TRY_CONVERT(DECIMAL(5,2), lidar_clean) > 100.0 THEN 'invalid lidar attenuation percentage'
                    ELSE NULL
                END AS reject_reason
            FROM raw_telemetry_deduped
            WHERE rn = 1
        )
        SELECT * INTO #telemetry_stage FROM typed_telemetry;

        INSERT INTO silver.reject_log (source_table, business_key, reason)
        SELECT 'bronze.av_telemetry', ISNULL(telemetry_id, 'NULL'), reject_reason
        FROM #telemetry_stage
        WHERE reject_reason IS NOT NULL;

        INSERT INTO silver.av_telemetry (
            telemetry_id, telemetry_date, city_id, vehicle_id,
            speed_kmh, battery_temp_c, gpu_temp_c, tire_pressure_psi,
            lidar_attenuation_pct, camera_glare_index,
            failure_occurred, failure_type, severity, av_disengagement
        )
        SELECT 
            telemetry_id, telemetry_date, city_id, vehicle_id,
            speed_kmh, battery_temp_c, gpu_temp_c, tire_pressure_psi,
            lidar_attenuation_pct, camera_glare_index,
            failure_occurred, failure_type, severity, av_disengagement
        FROM #telemetry_stage
        WHERE reject_reason IS NULL;

        DROP TABLE #telemetry_stage;

        COMMIT; -- All or nothing: commit transaction when all operations succeed

        -- Count rows loaded into Silver
        SELECT @rows_weather = COUNT_BIG(*) FROM silver.sa_weather;
        SELECT @rows_accidents = COUNT_BIG(*) FROM silver.sa_traffic_accidents;
        SELECT @rows_telemetry = COUNT_BIG(*) FROM silver.av_telemetry;
        SELECT @rows_rejected = COUNT_BIG(*) FROM silver.reject_log;
        SET @end_time = SYSDATETIME();

        -- Log successful Silver load into audit log
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES 
            (@batch_id, 'bronze.sa_weather', 'silver.sa_weather', @start_time, @end_time, @rows_weather, 'SUCCESS', 'Silver weather cleaning, typing, deduplication complete'),
            (@batch_id, 'bronze.sa_traffic_accidents', 'silver.sa_traffic_accidents', @start_time, @end_time, @rows_accidents, 'SUCCESS', 'Silver accidents cleaning and validation complete'),
            (@batch_id, 'bronze.av_telemetry', 'silver.av_telemetry', @start_time, @end_time, @rows_telemetry, 'SUCCESS', 'Silver AV telemetry validation & failure mapping complete');

        PRINT '==================================================';
        PRINT 'Silver Transformation Finished Successfully!';
        PRINT 'Weather Clean Rows Loaded: ' + CAST(@rows_weather AS NVARCHAR(20));
        PRINT 'Accidents Clean Rows Loaded: ' + CAST(@rows_accidents AS NVARCHAR(20));
        PRINT 'Telemetry Clean Rows Loaded: ' + CAST(@rows_telemetry AS NVARCHAR(20));
        PRINT 'Quarantined Rejections Logged: ' + CAST(@rows_rejected AS NVARCHAR(20));
        PRINT '==================================================';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 
            ROLLBACK; -- Undo half-done work on runtime failure

        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'bronze.*', 'silver.*', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in silver.load_silver: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO
