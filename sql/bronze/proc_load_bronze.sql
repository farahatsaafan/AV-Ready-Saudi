-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: proc_load_bronze.sql
-- Purpose: Automated batch full-load procedure for the Bronze landing layer.
-- Usage:   EXEC bronze.load_bronze;
--          or EXEC bronze.load_bronze @base_path = 'D:\AV-Ready-Saudi\Data';
-- Reference: Unit 2 Lab 3 (Medallion Full-Load Batch Ingestion Algorithm)
-- ==============================================================================

USE av_ready_saudi_dw;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
    @base_path NVARCHAR(1000) = N'D:\AV-Ready-Saudi\Data'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @batch_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @start_time DATETIME2;
    DECLARE @end_time DATETIME2;
    DECLARE @rows_loaded BIGINT;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @file_path NVARCHAR(1000);

    PRINT '==================================================';
    PRINT 'Starting Bronze Batch Ingestion | Batch ID: ' + CAST(@batch_id AS NVARCHAR(50));
    PRINT 'Base Data Directory: ' + @base_path;
    PRINT '==================================================';

    -- --------------------------------------------------------------------------
    -- 1. Source: Saudi Weather (saudi_weather_daily_2019_2024.csv)
    -- --------------------------------------------------------------------------
    BEGIN TRY
        SET @start_time = SYSDATETIME();
        SET @file_path = @base_path + N'\saudi_weather_daily_2019_2024.csv';

        PRINT 'Loading: bronze.sa_weather from ' + @file_path;

        TRUNCATE TABLE bronze.sa_weather;

        SET @sql = N'BULK INSERT bronze.sa_weather
                     FROM ''' + REPLACE(@file_path, '''', '''''') + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = '','',
                         ROWTERMINATOR = ''0x0A'',
                         CODEPAGE = ''65001'',
                         TABLOCK
                     );';
        EXEC sp_executesql @sql;

        SELECT @rows_loaded = COUNT_BIG(*) FROM bronze.sa_weather;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'saudi_weather_daily_2019_2024.csv', 'bronze.sa_weather', @start_time, @end_time, @rows_loaded, 'SUCCESS', 'Full-load Bronze weather landing complete');

        PRINT 'SUCCESS: Loaded ' + CAST(@rows_loaded AS NVARCHAR(20)) + ' rows into bronze.sa_weather';
    END TRY
    BEGIN CATCH
        SET @end_time = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'saudi_weather_daily_2019_2024.csv', 'bronze.sa_weather', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in bronze.sa_weather: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    -- --------------------------------------------------------------------------
    -- 2. Source: Saudi Highway Traffic Accidents (saudi_traffic_accidents_2019_2024.csv)
    -- --------------------------------------------------------------------------
    BEGIN TRY
        SET @start_time = SYSDATETIME();
        SET @file_path = @base_path + N'\saudi_traffic_accidents_2019_2024.csv';

        PRINT 'Loading: bronze.sa_traffic_accidents from ' + @file_path;

        TRUNCATE TABLE bronze.sa_traffic_accidents;

        SET @sql = N'BULK INSERT bronze.sa_traffic_accidents
                     FROM ''' + REPLACE(@file_path, '''', '''''') + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = '','',
                         ROWTERMINATOR = ''0x0A'',
                         CODEPAGE = ''65001'',
                         TABLOCK
                     );';
        EXEC sp_executesql @sql;

        SELECT @rows_loaded = COUNT_BIG(*) FROM bronze.sa_traffic_accidents;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'saudi_traffic_accidents_2019_2024.csv', 'bronze.sa_traffic_accidents', @start_time, @end_time, @rows_loaded, 'SUCCESS', 'Full-load Bronze accidents landing complete');

        PRINT 'SUCCESS: Loaded ' + CAST(@rows_loaded AS NVARCHAR(20)) + ' rows into bronze.sa_traffic_accidents';
    END TRY
    BEGIN CATCH
        SET @end_time = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'saudi_traffic_accidents_2019_2024.csv', 'bronze.sa_traffic_accidents', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in bronze.sa_traffic_accidents: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    -- --------------------------------------------------------------------------
    -- 3. Source: Autonomous Vehicle Fleet Telemetry (av_telemetry_failures_saudi.csv)
    -- --------------------------------------------------------------------------
    BEGIN TRY
        SET @start_time = SYSDATETIME();
        SET @file_path = @base_path + N'\av_telemetry_failures_saudi.csv';

        PRINT 'Loading: bronze.av_telemetry from ' + @file_path;

        TRUNCATE TABLE bronze.av_telemetry;

        SET @sql = N'BULK INSERT bronze.av_telemetry
                     FROM ''' + REPLACE(@file_path, '''', '''''') + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = '','',
                         ROWTERMINATOR = ''0x0A'',
                         CODEPAGE = ''65001'',
                         TABLOCK
                     );';
        EXEC sp_executesql @sql;

        SELECT @rows_loaded = COUNT_BIG(*) FROM bronze.av_telemetry;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'av_telemetry_failures_saudi.csv', 'bronze.av_telemetry', @start_time, @end_time, @rows_loaded, 'SUCCESS', 'Full-load Bronze AV telemetry landing complete');

        PRINT 'SUCCESS: Loaded ' + CAST(@rows_loaded AS NVARCHAR(20)) + ' rows into bronze.av_telemetry';
    END TRY
    BEGIN CATCH
        SET @end_time = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'av_telemetry_failures_saudi.csv', 'bronze.av_telemetry', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in bronze.av_telemetry: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    PRINT '==================================================';
    PRINT 'Bronze Batch Ingestion Finished Successfully!';
    PRINT '==================================================';
END;
GO
