-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 02_create_audit_tables.sql
-- Purpose: Create audit log table to record every batch load execution
-- Reference: Unit 2 Lab 3 & Lecture 02 (Medallion Technical Metadata)
-- ==============================================================================

USE av_ready_saudi_dw;
GO

DROP TABLE IF EXISTS audit.load_log;
GO

CREATE TABLE audit.load_log (
    load_id      BIGINT IDENTITY(1,1) PRIMARY KEY, -- Automatic incremental row number
    batch_id     UNIQUEIDENTIFIER NOT NULL,        -- Single GUID linking all tasks in one pipeline run
    source_name  VARCHAR(100)     NOT NULL,        -- Name of source file or system
    target_table VARCHAR(128)     NOT NULL,        -- Destination table in bronze/silver/gold
    start_time   DATETIME2        NOT NULL,        -- Batch start timestamp
    end_time     DATETIME2        NULL,            -- Batch completion timestamp
    rows_loaded  BIGINT           NULL,            -- Number of records loaded
    status       VARCHAR(20)      NOT NULL,        -- 'SUCCESS' or 'FAILED'
    message      VARCHAR(2000)    NULL             -- Diagnostic error message or execution summary
);
GO

PRINT 'Table [audit.load_log] created successfully.';
GO
