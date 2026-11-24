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
