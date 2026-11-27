-- ==============================================================================
-- Project : AV-Ready-Saudi
-- Script  : 01_bronze.sql
-- Purpose : Bronze = raw landing. One table per source family, every value kept
--           exactly as received (text). Provenance on every row.
--
-- Sources (all real, none generated):
--   1. bronze.noaa_hourly        NOAA NCEI Global Hourly (ISD) - 13 Saudi stations
--                                (one per region) + 4 US analog stations, 2021-2025
--   2. bronze.gastat_cells       GASTAT transport statistics workbooks 2022-2025,
--                                one row per Excel cell (formulas kept as text)
--   3. bronze.dmv_disengagements California DMV AV disengagement reports 2021-2024
--   4. bronze.dmv_mileage        California DMV AV mileage reports 2021-2024
--   5. bronze.nhtsa_sgo_ads      NHTSA Standing General Order ADS crash reports
--   6. bronze.gastat_population  GASTAT Saudi Census 2022 - population 2010-2022 by region,
--                                nationality and gender (one row per CSV row)
--
-- Input: Data/landing/*.tsv (UTF-16LE, tab, CRLF) produced by python/00_land_raw.py. UTF-16 is used
-- because CODEPAGE = '65001' is not supported by SQL Server on Linux. (container format
-- only - see that script). Columns shared by all files of a source are real
-- columns; every other column is kept, with its original header, in a JSON text
-- column so nothing is dropped.
--
-- Rules followed (Lecture 02 / Lab 3):
--   * preserve source values, permissive text schema, no silent corrections
--   * full-load pattern: TRUNCATE then reload the complete extract
--   * batch metadata: load_batch_id, source_file, source_row_num, ingested_at
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. NOAA Global Hourly observations
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS bronze.v_noaa_hourly_load;
DROP TABLE IF EXISTS bronze.noaa_hourly;
GO
CREATE TABLE bronze.noaa_hourly (
    source_file      NVARCHAR(400)  NULL,
    source_row_num   NVARCHAR(20)   NULL,
    [STATION]        NVARCHAR(50)   NULL,
    [DATE]           NVARCHAR(50)   NULL,
    [SOURCE]         NVARCHAR(20)   NULL,
    [LATITUDE]       NVARCHAR(50)   NULL,
    [LONGITUDE]      NVARCHAR(50)   NULL,
    [ELEVATION]      NVARCHAR(50)   NULL,
    [NAME]           NVARCHAR(200)  NULL,
    [REPORT_TYPE]    NVARCHAR(20)   NULL,
    [CALL_SIGN]      NVARCHAR(20)   NULL,
    [QUALITY_CONTROL] NVARCHAR(20)  NULL,
    [WND]            NVARCHAR(50)   NULL,
    [CIG]            NVARCHAR(50)   NULL,
    [VIS]            NVARCHAR(50)   NULL,
    [TMP]            NVARCHAR(50)   NULL,
    [DEW]            NVARCHAR(50)   NULL,
    [SLP]            NVARCHAR(50)   NULL,
    [AA1]            NVARCHAR(50)   NULL,
    [MW1]            NVARCHAR(50)   NULL,
    [AW1]            NVARCHAR(50)   NULL,
    [AU1]            NVARCHAR(50)   NULL,
    extra_json       NVARCHAR(MAX)  NULL,
    row_end          NVARCHAR(10)   NULL,   -- line-end marker from landing (always ".")
    load_batch_id    UNIQUEIDENTIFIER NULL,
    ingested_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW bronze.v_noaa_hourly_load AS
SELECT source_file, source_row_num, [STATION], [DATE], [SOURCE], [LATITUDE], [LONGITUDE],
       [ELEVATION], [NAME], [REPORT_TYPE], [CALL_SIGN], [QUALITY_CONTROL], [WND], [CIG],
       [VIS], [TMP], [DEW], [SLP], [AA1], [MW1], [AW1], [AU1], extra_json, row_end
FROM bronze.noaa_hourly;
GO

-- ------------------------------------------------------------------------------
-- 2. GASTAT workbooks, one row per non-empty cell
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS bronze.v_gastat_cells_load;
DROP TABLE IF EXISTS bronze.gastat_cells;
GO
CREATE TABLE bronze.gastat_cells (
    source_file    NVARCHAR(400)  NULL,
    sheet_name     NVARCHAR(100)  NULL,
    row_num        NVARCHAR(20)   NULL,
    col_num        NVARCHAR(20)   NULL,
    cell_value     NVARCHAR(MAX)  NULL,
    row_end          NVARCHAR(10)   NULL,   -- line-end marker from landing (always ".")
    load_batch_id  UNIQUEIDENTIFIER NULL,
    ingested_at    DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW bronze.v_gastat_cells_load AS
SELECT source_file, sheet_name, row_num, col_num, cell_value, row_end FROM bronze.gastat_cells;
GO

-- ------------------------------------------------------------------------------
-- 3. California DMV disengagement reports
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS bronze.v_dmv_disengagements_load;
DROP TABLE IF EXISTS bronze.dmv_disengagements;
GO
CREATE TABLE bronze.dmv_disengagements (
    source_file            NVARCHAR(400)  NULL,
    source_row_num         NVARCHAR(20)   NULL,
    manufacturer           NVARCHAR(400)  NULL,
    permit_number          NVARCHAR(100)  NULL,
    date_raw               NVARCHAR(100)  NULL,
    vin                    NVARCHAR(100)  NULL,
    capable_without_driver NVARCHAR(100)  NULL,
    driver_present         NVARCHAR(100)  NULL,
    initiated_by           NVARCHAR(200)  NULL,
    location               NVARCHAR(200)  NULL,
    description            NVARCHAR(MAX)  NULL,
    extra_json             NVARCHAR(MAX)  NULL,
    row_end          NVARCHAR(10)   NULL,   -- line-end marker from landing (always ".")
    load_batch_id          UNIQUEIDENTIFIER NULL,
    ingested_at            DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW bronze.v_dmv_disengagements_load AS
SELECT source_file, source_row_num, manufacturer, permit_number, date_raw, vin,
       capable_without_driver, driver_present, initiated_by, location, description, extra_json, row_end
FROM bronze.dmv_disengagements;
GO

-- ------------------------------------------------------------------------------
-- 4. California DMV mileage reports (month columns kept in months_json)
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS bronze.v_dmv_mileage_load;
DROP TABLE IF EXISTS bronze.dmv_mileage;
GO
CREATE TABLE bronze.dmv_mileage (
    source_file            NVARCHAR(400)  NULL,
    source_row_num         NVARCHAR(20)   NULL,
    manufacturer           NVARCHAR(400)  NULL,
    permit_number          NVARCHAR(100)  NULL,
    vin                    NVARCHAR(100)  NULL,
    annual_disengagements  NVARCHAR(100)  NULL,
    months_json            NVARCHAR(MAX)  NULL,
    row_end          NVARCHAR(10)   NULL,   -- line-end marker from landing (always ".")
    load_batch_id          UNIQUEIDENTIFIER NULL,
    ingested_at            DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW bronze.v_dmv_mileage_load AS
SELECT source_file, source_row_num, manufacturer, permit_number, vin,
       annual_disengagements, months_json, row_end
FROM bronze.dmv_mileage;
GO

-- ------------------------------------------------------------------------------
-- 5. NHTSA SGO ADS incident reports (archive 2021-2025 + current file)
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS bronze.v_nhtsa_sgo_ads_load;
DROP TABLE IF EXISTS bronze.nhtsa_sgo_ads;
GO
CREATE TABLE bronze.nhtsa_sgo_ads (
    source_file         NVARCHAR(400) NULL,
    source_row_num      NVARCHAR(20)  NULL,
    [Report ID]         NVARCHAR(100) NULL,
    [Report Version]    NVARCHAR(20)  NULL,
    [Reporting Entity]  NVARCHAR(200) NULL,
    [Make]              NVARCHAR(200) NULL,
    [Model]             NVARCHAR(200) NULL,
    [Model Year]        NVARCHAR(50)  NULL,
    [State]             NVARCHAR(50)  NULL,
    [City]              NVARCHAR(200) NULL,
    [Incident Date]     NVARCHAR(50)  NULL,
    [Incident Time (24:00)] NVARCHAR(50) NULL,
    [Roadway Type]      NVARCHAR(100) NULL,
    [Posted Speed Limit (MPH)] NVARCHAR(50) NULL,
    [Lighting]          NVARCHAR(100) NULL,
    row_json            NVARCHAR(MAX) NULL,
    row_end          NVARCHAR(10)   NULL,   -- line-end marker from landing (always ".")
    load_batch_id       UNIQUEIDENTIFIER NULL,
    ingested_at         DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW bronze.v_nhtsa_sgo_ads_load AS
SELECT source_file, source_row_num, [Report ID], [Report Version], [Reporting Entity], [Make],
       [Model], [Model Year], [State], [City], [Incident Date], [Incident Time (24:00)],
       [Roadway Type], [Posted Speed Limit (MPH)], [Lighting], row_json, row_end
FROM bronze.nhtsa_sgo_ads;
GO

-- ------------------------------------------------------------------------------
-- 6. GASTAT Saudi Census 2022 - population by region, nationality, gender, year
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS bronze.v_gastat_population_load;
DROP TABLE IF EXISTS bronze.gastat_population;
GO
CREATE TABLE bronze.gastat_population (
    source_file     NVARCHAR(400) NULL,
    source_row_num  NVARCHAR(20)  NULL,
    [Gender]        NVARCHAR(50)  NULL,
    [Nationality]   NVARCHAR(50)  NULL,
    [Region]        NVARCHAR(100) NULL,
    [Year]          NVARCHAR(20)  NULL,   -- as published, in Arabic-Indic digits (U+0660..U+0669)
    [Population]    NVARCHAR(50)  NULL,
    row_end         NVARCHAR(10)  NULL,   -- line-end marker from landing (always ".")
    load_batch_id   UNIQUEIDENTIFIER NULL,
    ingested_at     DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO
CREATE VIEW bronze.v_gastat_population_load AS
SELECT source_file, source_row_num, [Gender], [Nationality], [Region], [Year], [Population], row_end
FROM bronze.gastat_population;
GO

-- ------------------------------------------------------------------------------
-- Load procedure
-- Usage: EXEC bronze.load_bronze @landing_path = N'/tmp/av/landing';
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE bronze.load_bronze
    @landing_path NVARCHAR(400) = N'/tmp/av/landing'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @batch UNIQUEIDENTIFIER = NEWID();
    DECLARE @i INT = 1, @n INT, @file NVARCHAR(200), @view NVARCHAR(200), @tbl NVARCHAR(200),
            @src NVARCHAR(100), @sql NVARCHAR(MAX), @t0 DATETIME2, @rows BIGINT, @log BIGINT;

    DECLARE @plan TABLE (id INT IDENTITY(1,1), src NVARCHAR(100), file_name NVARCHAR(200),
                         view_name NVARCHAR(200), table_name NVARCHAR(200));
    INSERT INTO @plan (src, file_name, view_name, table_name) VALUES
      (N'NOAA Global Hourly',     N'noaa_hourly.tsv',        N'bronze.v_noaa_hourly_load',        N'bronze.noaa_hourly'),
      (N'GASTAT workbooks',       N'gastat_cells.tsv',       N'bronze.v_gastat_cells_load',       N'bronze.gastat_cells'),
      (N'CA DMV disengagements',  N'dmv_disengagements.tsv', N'bronze.v_dmv_disengagements_load', N'bronze.dmv_disengagements'),
      (N'CA DMV mileage',         N'dmv_mileage.tsv',        N'bronze.v_dmv_mileage_load',        N'bronze.dmv_mileage'),
      (N'NHTSA SGO ADS',          N'nhtsa_sgo_ads.tsv',      N'bronze.v_nhtsa_sgo_ads_load',      N'bronze.nhtsa_sgo_ads'),
      (N'GASTAT census population', N'gastat_population.tsv', N'bronze.v_gastat_population_load', N'bronze.gastat_population');
    SELECT @n = COUNT(*) FROM @plan;

    PRINT 'Bronze batch ' + CAST(@batch AS NVARCHAR(40));
    WHILE @i <= @n
    BEGIN
        SELECT @src = src, @file = file_name, @view = view_name, @tbl = table_name FROM @plan WHERE id = @i;
        SET @t0 = SYSDATETIME();
        INSERT INTO audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
        VALUES (@batch, 'bronze', @src, @tbl, @t0, 'RUNNING');
        SET @log = SCOPE_IDENTITY();
        BEGIN TRY
            SET @sql = N'TRUNCATE TABLE ' + @tbl + N';
BULK INSERT ' + @view + N' FROM ''' + @landing_path + N'/' + @file + N'''
WITH (FIRSTROW = 2, FIELDTERMINATOR = ''\t'', ROWTERMINATOR = ''\n'',
      DATAFILETYPE = ''widechar'', TABLOCK);
UPDATE ' + @tbl + N' SET load_batch_id = @b WHERE load_batch_id IS NULL;
SELECT @r = COUNT_BIG(*) FROM ' + @tbl + N';';
            EXEC sp_executesql @sql, N'@b UNIQUEIDENTIFIER, @r BIGINT OUTPUT', @b = @batch, @r = @rows OUTPUT;
            UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS'
            WHERE load_id = @log;
            PRINT CONCAT('  ', @tbl, ': ', @rows, ' rows');
        END TRY
        BEGIN CATCH
            UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED',
                   message = LEFT(ERROR_MESSAGE(), 2000)
            WHERE load_id = @log;
            PRINT CONCAT('  FAILED ', @tbl, ': ', ERROR_MESSAGE());
            THROW;
        END CATCH;
        SET @i += 1;
    END
END
GO

PRINT 'Bronze objects created.';
GO
