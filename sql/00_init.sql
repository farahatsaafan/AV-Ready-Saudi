-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 00_init.sql
-- Purpose: Initialize Data Warehouse database, 6 standard schemas, and audit log.
-- Course Standard: DM & DW Project Skeleton (Fall 2026)
-- Target Server: Microsoft SQL Server 2017 or later
-- ==============================================================================

IF DB_ID('av_ready_saudi_dw') IS NULL 
BEGIN
    CREATE DATABASE av_ready_saudi_dw;
    PRINT 'Database [av_ready_saudi_dw] created successfully.';
END
ELSE
BEGIN
    PRINT 'Database [av_ready_saudi_dw] already exists.';
END
GO

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 1. Create the 6 Standard Schemas
-- ------------------------------------------------------------------------------
IF SCHEMA_ID('bronze')   IS NULL EXEC('CREATE SCHEMA bronze');
IF SCHEMA_ID('silver')   IS NULL EXEC('CREATE SCHEMA silver');
IF SCHEMA_ID('gold')     IS NULL EXEC('CREATE SCHEMA gold');
IF SCHEMA_ID('semantic') IS NULL EXEC('CREATE SCHEMA semantic');
IF SCHEMA_ID('ml')       IS NULL EXEC('CREATE SCHEMA ml');
IF SCHEMA_ID('audit')    IS NULL EXEC('CREATE SCHEMA audit');
GO

PRINT 'All 6 schemas [bronze, silver, gold, semantic, ml, audit] verified successfully.';
GO

-- ------------------------------------------------------------------------------
-- 2. Audit Table: audit.load_log
-- Purpose: Records one row per pipeline run, written by every load procedure.
-- ------------------------------------------------------------------------------
IF OBJECT_ID('audit.load_log') IS NULL
BEGIN
    CREATE TABLE audit.load_log (
        load_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
        batch_id     UNIQUEIDENTIFIER     NOT NULL,
        source_name  VARCHAR(100)         NOT NULL,
        target_table VARCHAR(100)         NOT NULL,
        start_time   DATETIME2            NOT NULL,
        end_time     DATETIME2            NULL,
        rows_loaded  BIGINT               NULL,
        status       VARCHAR(20)          NOT NULL, -- 'RUNNING', 'SUCCESS', 'FAILED'
        message      NVARCHAR(500)        NULL
    );
    PRINT 'Table [audit.load_log] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [audit.load_log] already exists.';
END
GO
