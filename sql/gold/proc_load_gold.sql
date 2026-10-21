-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: proc_load_gold.sql
-- Purpose: Populate Gold dimensional models and aggregated fact tables for Data Mining.
-- Usage:   EXEC gold.load_gold;
-- ==============================================================================

USE av_ready_saudi_dw;
GO

CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time DATETIME2 = SYSDATETIME();
    DECLARE @end_time DATETIME2;
    DECLARE @rows_hazard BIGINT;
    DECLARE @rows_facts BIGINT;

    PRINT '==================================================';
    PRINT 'Starting Gold Layer Ingestion | Batch ID: ' + CAST(@batch_id AS NVARCHAR(50));
    PRINT '==================================================';

    BEGIN TRY
        BEGIN TRAN;

        -- 1. Populate/Refresh Dimension: Weather Hazards for Autonomous Vehicles
        TRUNCATE TABLE gold.dim_weather_hazard;

        INSERT INTO gold.dim_weather_hazard (weather_condition, sensor_hazard_level, lidar_impact, camera_impact)
        SELECT DISTINCT
            weather_condition,
            CASE 
                WHEN weather_condition LIKE '%DUST%' OR weather_condition LIKE '%SAND%' THEN 'CRITICAL'
                WHEN weather_condition LIKE '%FOG%' OR weather_condition LIKE '%HAZE%' THEN 'CRITICAL'
                WHEN weather_condition LIKE '%THUNDER%' OR weather_condition LIKE '%RAIN%' THEN 'HIGH'
                WHEN weather_condition LIKE '%CLOUD%' THEN 'MEDIUM'
                WHEN weather_condition IN ('CLEAR', 'SUNNY') THEN 'LOW'
                ELSE 'MEDIUM'
            END AS sensor_hazard_level,
            CASE 
                WHEN weather_condition LIKE '%DUST%' THEN 'Severe beam absorption and false obstacle returns'
                WHEN weather_condition LIKE '%FOG%' THEN 'High scattering and range attenuation under 50m'
                WHEN weather_condition LIKE '%RAIN%' THEN 'Water droplets cause noise and ground reflection'
                ELSE 'Nominal operational range (>200m)'
            END AS lidar_impact,
            CASE 
                WHEN weather_condition LIKE '%DUST%' OR weather_condition LIKE '%FOG%' THEN 'Severe optical occlusion and lost lane perception'
                WHEN weather_condition LIKE '%THUNDER%' THEN 'Low light and windshield water distortion'
                WHEN weather_condition = 'SUNNY' THEN 'High direct glare on front-facing HDR cameras'
                ELSE 'Clear optical visibility'
            END AS camera_impact
        FROM silver.sa_weather;

        -- 2. Populate Fact Table: Daily City Driving Conditions & Safety Risk
        TRUNCATE TABLE gold.fact_city_daily_weather_risk;

        INSERT INTO gold.fact_city_daily_weather_risk (
            city, observation_date, avg_temp_c, max_temp_c, min_temp_c,
            avg_visibility_km, min_visibility_km, avg_wind_kmh, max_wind_kmh,
            extreme_heat_hours, low_visibility_hours, dominant_weather, av_readiness_score
        )
        SELECT 
            w.city,
            w.weather_date,
            ROUND(AVG(w.temp_c), 2) AS avg_temp_c,
            MAX(w.temp_c) AS max_temp_c,
            MIN(w.temp_c) AS min_temp_c,
            ROUND(AVG(w.visibility_km), 2) AS avg_visibility_km,
            MIN(w.visibility_km) AS min_visibility_km,
            ROUND(AVG(w.wind_kmh), 2) AS avg_wind_kmh,
            MAX(w.wind_kmh) AS max_wind_kmh,
            SUM(CASE WHEN w.temp_c >= 45.0 THEN 1 ELSE 0 END) AS extreme_heat_hours,
            SUM(CASE WHEN w.visibility_km <= 5.0 THEN 1 ELSE 0 END) AS low_visibility_hours,
            MAX(w.weather_condition) AS dominant_weather,
            -- Calculated Safety & AV Readiness Index (0 to 100)
            ROUND(
                100.0 
                - (SUM(CASE WHEN w.visibility_km <= 3.0 THEN 1 ELSE 0 END) * 4.0)
                - (SUM(CASE WHEN w.temp_c >= 45.0 THEN 1 ELSE 0 END) * 2.0)
                - (CASE WHEN MAX(w.wind_kmh) > 50 THEN 15.0 ELSE 0.0 END), 
                2
            ) AS av_readiness_score
        FROM silver.sa_weather w
        GROUP BY w.city, w.weather_date;

        COMMIT;

        SELECT @rows_hazard = COUNT_BIG(*) FROM gold.dim_weather_hazard;
        SELECT @rows_facts = COUNT_BIG(*) FROM gold.fact_city_daily_weather_risk;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES 
            (@batch_id, 'silver.sa_weather', 'gold.dim_weather_hazard', @start_time, @end_time, @rows_hazard, 'SUCCESS', 'Gold hazard dimension refreshed'),
            (@batch_id, 'silver.sa_weather', 'gold.fact_city_daily_weather_risk', @start_time, @end_time, @rows_facts, 'SUCCESS', 'Gold daily city safety facts aggregated');

        PRINT '==================================================';
        PRINT 'Gold Layer Load Finished Successfully!';
        PRINT 'Hazard Dimension Rows: ' + CAST(@rows_hazard AS NVARCHAR(20));
        PRINT 'City Daily Risk Facts: ' + CAST(@rows_facts AS NVARCHAR(20));
        PRINT '==================================================';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'silver.*', 'gold.*', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in gold.load_gold: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;
END;
GO
