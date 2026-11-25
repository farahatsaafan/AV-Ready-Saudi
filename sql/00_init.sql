-- ==============================================================================
-- Project : AV-Ready-Saudi
-- Script  : 00_init.sql
-- Purpose : Create the warehouse database, its schemas and the audit log.
-- Server  : Microsoft SQL Server 2022 (Docker on macOS, localhost,1433)
--
-- Schemas
--   bronze : raw landing, one table per source family, every value kept as text
--   silver : cleaned, typed, standardized rows + reference (dimension) tables
--   prep   : intermediate aggregation tables used only to build Gold
--   gold   : exactly ONE analytical table (gold.av_readiness_region_month)
--   audit  : load log and data-quality results
-- ==============================================================================

IF DB_ID('av_ready_saudi_dw') IS NULL
BEGIN
    CREATE DATABASE av_ready_saudi_dw;
    PRINT 'Database [av_ready_saudi_dw] created.';
END
GO

USE av_ready_saudi_dw;
GO

IF SCHEMA_ID('bronze') IS NULL EXEC('CREATE SCHEMA bronze');
IF SCHEMA_ID('silver') IS NULL EXEC('CREATE SCHEMA silver');
IF SCHEMA_ID('prep')   IS NULL EXEC('CREATE SCHEMA prep');
IF SCHEMA_ID('gold')   IS NULL EXEC('CREATE SCHEMA gold');
IF SCHEMA_ID('audit')  IS NULL EXEC('CREATE SCHEMA audit');
GO

-- ------------------------------------------------------------------------------
-- Upgrade from the old design (main before the redesign).
-- A teammate's existing av_ready_saudi_dw still holds the old Star Schema, the
-- semantic / ml layers and an audit.load_log without the "layer" column.
-- Those objects depended on the generated datasets and are not used any more,
-- so they are removed here. On a fresh database this block does nothing.
-- ------------------------------------------------------------------------------
DECLARE @sql NVARCHAR(MAX) = N'';

-- old audit.load_log (no "layer" column, message NVARCHAR(500)): its rows only
-- describe old-design loads, so it is recreated below with the new layout
IF OBJECT_ID('audit.load_log') IS NOT NULL AND COL_LENGTH('audit.load_log', 'layer') IS NULL
BEGIN
    DROP TABLE audit.load_log;
    PRINT 'Old audit.load_log dropped (recreated below with the layer column).';
END;

-- foreign keys that point to or from old tables (must go before the tables)
SELECT @sql += N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.'
             + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys fk
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id)     IN ('gold', 'semantic', 'ml', 'quality')
   OR OBJECT_SCHEMA_NAME(fk.referenced_object_id) IN ('gold', 'semantic', 'ml', 'quality');
EXEC sys.sp_executesql @sql;

-- views and procedures of the old layers
SET @sql = N'';
SELECT @sql += N'DROP ' + CASE o.type WHEN 'V' THEN N'VIEW ' ELSE N'PROCEDURE ' END
             + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N'.' + QUOTENAME(o.name) + N';'
FROM sys.objects o
WHERE o.type IN ('V', 'P')
  AND (SCHEMA_NAME(o.schema_id) IN ('semantic', 'ml', 'quality')
       OR (SCHEMA_NAME(o.schema_id) = 'gold' AND o.type = 'V')
       OR (SCHEMA_NAME(o.schema_id) = 'bronze'
           AND o.name IN ('v_av_telemetry_load', 'v_sa_traffic_accidents_load', 'v_sa_weather_load')));
EXEC sys.sp_executesql @sql;

-- old tables: every gold table except the one Gold table, the semantic / ml layers,
-- and the old Bronze / Silver tables of the generated design
SET @sql = N'';
SELECT @sql += N'DROP TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) + N';'
FROM sys.tables t
WHERE (SCHEMA_NAME(t.schema_id) = 'gold' AND t.name <> 'av_readiness_region_month')
   OR SCHEMA_NAME(t.schema_id) IN ('semantic', 'ml', 'quality')
   OR (SCHEMA_NAME(t.schema_id) IN ('bronze', 'silver')
       AND t.name IN ('av_telemetry', 'sa_traffic_accidents', 'sa_weather'));
IF @sql <> N''
BEGIN
    EXEC sys.sp_executesql @sql;
    PRINT 'Old-design tables removed.';
END;

-- empty old schemas
IF SCHEMA_ID('semantic') IS NOT NULL EXEC('DROP SCHEMA semantic');
IF SCHEMA_ID('ml')       IS NOT NULL EXEC('DROP SCHEMA ml');
IF SCHEMA_ID('quality')  IS NOT NULL EXEC('DROP SCHEMA quality');
GO

-- One row per load step, written by every load procedure.
IF OBJECT_ID('audit.load_log') IS NULL
CREATE TABLE audit.load_log (
    load_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id     UNIQUEIDENTIFIER NOT NULL,
    layer        VARCHAR(10)      NOT NULL,      -- bronze / silver / gold
    source_name  VARCHAR(100)     NOT NULL,
    target_table VARCHAR(100)     NOT NULL,
    start_time   DATETIME2        NOT NULL,
    end_time     DATETIME2        NULL,
    rows_loaded  BIGINT           NULL,
    status       VARCHAR(20)      NOT NULL,      -- RUNNING / SUCCESS / FAILED
    message      NVARCHAR(2000)   NULL
);
GO

-- Results of the data-quality checks in sql/quality/*.sql
IF OBJECT_ID('audit.dq_result') IS NULL
CREATE TABLE audit.dq_result (
    dq_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    run_at       DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    layer        VARCHAR(10)   NOT NULL,
    check_name   VARCHAR(200)  NOT NULL,
    expected     NVARCHAR(200) NULL,
    actual       NVARCHAR(200) NULL,
    passed       BIT           NOT NULL
);
GO

PRINT 'Schemas bronze, silver, prep, gold, audit are ready.';
GO
