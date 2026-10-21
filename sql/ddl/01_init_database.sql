-- ==============================================================================
-- Project: AV-Ready-Saudi (Autonomous Vehicles Readiness & Safety in Saudi Arabia)
-- Course: Data Mining & Data Warehousing
-- Script: 01_init_database.sql
-- Purpose: Initialize the analytical data warehouse database and schemas
-- ==============================================================================

USE master;
GO

-- 1. Create database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'av_ready_saudi_dw')
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

-- 2. Create Medallion and Governance Schemas
-- Schema: bronze    -> Raw data landing (untyped, preserved as delivered)
-- Schema: silver    -> Cleaned, typed, deduplicated and validated trusted data
-- Schema: gold      -> Business-ready dimensional models, marts and mining features
-- Schema: audit     -> Technical metadata, batch execution logs and load lineage
-- Schema: quality   -> Profiling results, quality rules and reconciliation gates

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'silver')
    EXEC('CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'gold')
    EXEC('CREATE SCHEMA gold');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'audit')
    EXEC('CREATE SCHEMA audit');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'quality')
    EXEC('CREATE SCHEMA quality');
GO

PRINT 'Schemas [bronze, silver, gold, audit, quality] verified successfully.';
GO
