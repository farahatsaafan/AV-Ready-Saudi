-- ==============================================================================
-- AV-Ready-Saudi - Bronze validation (technical ingestion checks only)
-- Every source file must have landed, and no table may be empty.
-- Results go to audit.dq_result and are printed.
-- ==============================================================================
USE av_ready_saudi_dw;
GO
DECLARE @r TABLE (check_name VARCHAR(200), expected NVARCHAR(200), actual NVARCHAR(200), passed BIT);

INSERT @r SELECT 'bronze.noaa_hourly: station-year files',      '85', CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 85, 1, 0) FROM bronze.noaa_hourly;
INSERT @r SELECT 'bronze.noaa_hourly: stations',                '17', CAST(COUNT(DISTINCT LTRIM(RTRIM([STATION]))) AS NVARCHAR), IIF(COUNT(DISTINCT LTRIM(RTRIM([STATION]))) = 17, 1, 0) FROM bronze.noaa_hourly;
INSERT @r SELECT 'bronze.gastat_cells: workbooks',              '4',  CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 4, 1, 0) FROM bronze.gastat_cells;
INSERT @r SELECT 'bronze.dmv_disengagements: report files',     '8',  CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 8, 1, 0) FROM bronze.dmv_disengagements;
INSERT @r SELECT 'bronze.dmv_mileage: report files',            '8',  CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 8, 1, 0) FROM bronze.dmv_mileage;
INSERT @r SELECT 'bronze.nhtsa_sgo_ads: files',                 '2',  CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 2, 1, 0) FROM bronze.nhtsa_sgo_ads;
INSERT @r SELECT 'bronze.nhtsa_sgo_ads: row_json is valid JSON', '0 bad', CONCAT(SUM(IIF(ISJSON(row_json) = 1, 0, 1)), ' bad'), IIF(SUM(IIF(ISJSON(row_json) = 1, 0, 1)) = 0, 1, 0) FROM bronze.nhtsa_sgo_ads;
INSERT @r SELECT 'bronze.dmv_mileage: months_json is valid JSON', '0 bad', CONCAT(SUM(IIF(ISJSON(months_json) = 1, 0, 1)), ' bad'), IIF(SUM(IIF(ISJSON(months_json) = 1, 0, 1)) = 0, 1, 0) FROM bronze.dmv_mileage;
INSERT @r SELECT 'bronze: every row has a batch id', '0 missing',
       CONCAT((SELECT COUNT(*) FROM bronze.noaa_hourly WHERE load_batch_id IS NULL)
            + (SELECT COUNT(*) FROM bronze.gastat_cells WHERE load_batch_id IS NULL)
            + (SELECT COUNT(*) FROM bronze.dmv_disengagements WHERE load_batch_id IS NULL)
            + (SELECT COUNT(*) FROM bronze.dmv_mileage WHERE load_batch_id IS NULL)
            + (SELECT COUNT(*) FROM bronze.nhtsa_sgo_ads WHERE load_batch_id IS NULL), ' missing'),
       IIF((SELECT COUNT(*) FROM bronze.noaa_hourly WHERE load_batch_id IS NULL)
         + (SELECT COUNT(*) FROM bronze.gastat_cells WHERE load_batch_id IS NULL)
         + (SELECT COUNT(*) FROM bronze.dmv_disengagements WHERE load_batch_id IS NULL)
         + (SELECT COUNT(*) FROM bronze.dmv_mileage WHERE load_batch_id IS NULL)
         + (SELECT COUNT(*) FROM bronze.nhtsa_sgo_ads WHERE load_batch_id IS NULL) = 0, 1, 0);

INSERT audit.dq_result (layer, check_name, expected, actual, passed)
SELECT 'bronze', check_name, expected, actual, passed FROM @r;

SELECT check_name, expected, actual, IIF(passed = 1, 'PASS', 'FAIL') AS result FROM @r;

SELECT 'bronze.noaa_hourly' AS tbl, COUNT_BIG(*) AS rows_loaded FROM bronze.noaa_hourly UNION ALL
SELECT 'bronze.gastat_cells', COUNT_BIG(*) FROM bronze.gastat_cells UNION ALL
SELECT 'bronze.dmv_disengagements', COUNT_BIG(*) FROM bronze.dmv_disengagements UNION ALL
SELECT 'bronze.dmv_mileage', COUNT_BIG(*) FROM bronze.dmv_mileage UNION ALL
SELECT 'bronze.nhtsa_sgo_ads', COUNT_BIG(*) FROM bronze.nhtsa_sgo_ads;
GO
