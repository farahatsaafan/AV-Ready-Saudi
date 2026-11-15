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
                ROWTERMINATOR = ''0x0a'',
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
                ROWTERMINATOR = ''0x0a'',
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
                ROWTERMINATOR = ''0x0a'',
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
