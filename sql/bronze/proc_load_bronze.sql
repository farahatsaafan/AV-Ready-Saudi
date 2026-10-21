-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: proc_load_bronze.sql
-- Purpose: Automated batch full-load procedure for the Bronze layer.
-- Usage:   EXEC bronze.load_bronze;
--          or EXEC bronze.load_bronze @base_path = 'C:\path\to\Data';
-- Reference: Unit 2 Lab 3 (Medallion Full-Load Batch Algorithm)
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
    -- 1. Source: Saudi Weather (weather-sa-2017-2019-clean.csv)
    -- --------------------------------------------------------------------------
    BEGIN TRY
        SET @start_time = SYSDATETIME();
        SET @file_path = @base_path + N'\weather-sa-2017-2019-clean.csv';

        PRINT 'Loading: bronze.sa_weather from ' + @file_path;

        TRUNCATE TABLE bronze.sa_weather;

        SET @sql = N'BULK INSERT bronze.sa_weather
                     FROM ''' + REPLACE(@file_path, '''', '''''') + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = '','',
                         ROWTERMINATOR = ''0x0A'',
                         TABLOCK
                     );';
        EXEC sp_executesql @sql;

        SELECT @rows_loaded = COUNT_BIG(*) FROM bronze.sa_weather;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'weather-sa-2017-2019-clean.csv', 'bronze.sa_weather', @start_time, @end_time, @rows_loaded, 'SUCCESS', 'Full-load Bronze landing complete');

        PRINT 'SUCCESS: Loaded ' + CAST(@rows_loaded AS NVARCHAR(20)) + ' rows into bronze.sa_weather';
    END TRY
    BEGIN CATCH
        SET @end_time = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'weather-sa-2017-2019-clean.csv', 'bronze.sa_weather', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in bronze.sa_weather: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    -- --------------------------------------------------------------------------
    -- 2. Source: Saudi Traffic Accidents (saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008.csv)
    -- --------------------------------------------------------------------------
    BEGIN TRY
        SET @start_time = SYSDATETIME();
        SET @file_path = @base_path + N'\saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008.csv';

        PRINT 'Loading: bronze.sa_traffic_accidents from ' + @file_path;

        TRUNCATE TABLE bronze.sa_traffic_accidents;

        SET @sql = N'BULK INSERT bronze.sa_traffic_accidents
                     FROM ''' + REPLACE(@file_path, '''', '''''') + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = '';'',
                         ROWTERMINATOR = ''0x0A'',
                         TABLOCK
                     );';
        EXEC sp_executesql @sql;

        SELECT @rows_loaded = COUNT_BIG(*) FROM bronze.sa_traffic_accidents;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'saudi-arabia-traffic-accidents-2008.csv', 'bronze.sa_traffic_accidents', @start_time, @end_time, @rows_loaded, 'SUCCESS', 'Full-load Bronze landing complete');

        PRINT 'SUCCESS: Loaded ' + CAST(@rows_loaded AS NVARCHAR(20)) + ' rows into bronze.sa_traffic_accidents';
    END TRY
    BEGIN CATCH
        SET @end_time = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'saudi-arabia-traffic-accidents-2008.csv', 'bronze.sa_traffic_accidents', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in bronze.sa_traffic_accidents: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    -- --------------------------------------------------------------------------
    -- 3. Source: AV Racing Telemetry (A2RL_IAC_prediction_annotations\a2rl_raw.csv)
    -- --------------------------------------------------------------------------
    BEGIN TRY
        SET @start_time = SYSDATETIME();
        SET @file_path = @base_path + N'\A2RL_IAC_prediction_annotations\a2rl_raw.csv';

        PRINT 'Loading: bronze.av_telemetry from ' + @file_path;

        TRUNCATE TABLE bronze.av_telemetry;

        SET @sql = N'BULK INSERT bronze.av_telemetry
                     FROM ''' + REPLACE(@file_path, '''', '''''') + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = '','',
                         ROWTERMINATOR = ''0x0A'',
                         TABLOCK
                     );';
        EXEC sp_executesql @sql;

        SELECT @rows_loaded = COUNT_BIG(*) FROM bronze.av_telemetry;
        SET @end_time = SYSDATETIME();

        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'a2rl_raw.csv', 'bronze.av_telemetry', @start_time, @end_time, @rows_loaded, 'SUCCESS', 'Full-load Bronze landing complete');

        PRINT 'SUCCESS: Loaded ' + CAST(@rows_loaded AS NVARCHAR(20)) + ' rows into bronze.av_telemetry';
    END TRY
    BEGIN CATCH
        SET @end_time = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, source_name, target_table, start_time, end_time, rows_loaded, status, message)
        VALUES (@batch_id, 'a2rl_raw.csv', 'bronze.av_telemetry', @start_time, @end_time, NULL, 'FAILED', ERROR_MESSAGE());

        PRINT 'ERROR in bronze.av_telemetry: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    PRINT '==================================================';
    PRINT 'Bronze Ingestion Finished Successfully!';
    PRINT '==================================================';
END;
GO
