-- ==============================================================================
-- Project: AV-Ready-Saudi
-- Script: 02_silver_reconciliation.sql
-- Purpose: Implement course reconciliation formula: Bronze = Silver + Rejected + Duplicates
-- Reference: Unit 3 Lab 4 (Step 8: Prove - Reconcile the counts)
-- ==============================================================================

USE av_ready_saudi_dw;
GO

SELECT 
    'sa_weather' AS entity_table,
    (SELECT COUNT(*) FROM bronze.sa_weather) AS bronze_raw_rows,
    (SELECT COUNT(*) FROM silver.sa_weather) AS silver_clean_rows,
    (SELECT COUNT(*) FROM silver.reject_log WHERE source_table = 'bronze.sa_weather') AS rejected_rows,
    ((SELECT COUNT(*) FROM bronze.sa_weather) 
     - (SELECT COUNT(DISTINCT city + '|' + weather_date + '|' + weather_time) FROM bronze.sa_weather)) AS duplicates_detected,
    CASE 
        WHEN (SELECT COUNT(*) FROM bronze.sa_weather) = 
             (SELECT COUNT(*) FROM silver.sa_weather) + 
             (SELECT COUNT(*) FROM silver.reject_log WHERE source_table = 'bronze.sa_weather') + 
             ((SELECT COUNT(*) FROM bronze.sa_weather) - (SELECT COUNT(DISTINCT city + '|' + weather_date + '|' + weather_time) FROM bronze.sa_weather))
        THEN 'BALANCED (MATCH)' 
        ELSE 'MISMATCH' 
    END AS reconciliation_status
UNION ALL
SELECT 
    'sa_traffic_accidents',
    (SELECT COUNT(*) FROM bronze.sa_traffic_accidents),
    (SELECT COUNT(*) FROM silver.sa_traffic_accidents),
    (SELECT COUNT(*) FROM silver.reject_log WHERE source_table = 'bronze.sa_traffic_accidents'),
    ((SELECT COUNT(*) FROM bronze.sa_traffic_accidents) 
     - (SELECT COUNT(DISTINCT accident_year + '|' + region + '|' + indicator) FROM bronze.sa_traffic_accidents)),
    CASE 
        WHEN (SELECT COUNT(*) FROM bronze.sa_traffic_accidents) = 
             (SELECT COUNT(*) FROM silver.sa_traffic_accidents) + 
             (SELECT COUNT(*) FROM silver.reject_log WHERE source_table = 'bronze.sa_traffic_accidents') + 
             ((SELECT COUNT(*) FROM bronze.sa_traffic_accidents) - (SELECT COUNT(DISTINCT accident_year + '|' + region + '|' + indicator) FROM bronze.sa_traffic_accidents))
        THEN 'BALANCED (MATCH)' 
        ELSE 'MISMATCH' 
    END
UNION ALL
SELECT 
    'av_telemetry',
    (SELECT COUNT(*) FROM bronze.av_telemetry),
    (SELECT COUNT(*) FROM silver.av_telemetry),
    (SELECT COUNT(*) FROM silver.reject_log WHERE source_table = 'bronze.av_telemetry'),
    ((SELECT COUNT(*) FROM bronze.av_telemetry) 
     - (SELECT COUNT(DISTINCT frame_id) FROM bronze.av_telemetry)),
    CASE 
        WHEN (SELECT COUNT(*) FROM bronze.av_telemetry) = 
             (SELECT COUNT(*) FROM silver.av_telemetry) + 
             (SELECT COUNT(*) FROM silver.reject_log WHERE source_table = 'bronze.av_telemetry') + 
             ((SELECT COUNT(*) FROM bronze.av_telemetry) - (SELECT COUNT(DISTINCT frame_id) FROM bronze.av_telemetry))
        THEN 'BALANCED (MATCH)' 
        ELSE 'MISMATCH' 
    END;
GO
