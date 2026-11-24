-- ==============================================================================
-- AV-Ready-Saudi - Silver reconciliation
-- Each Bronze row must be accounted for: kept in Silver, rejected with a reason,
-- or removed by a documented rule (summary record, duplicate, outside 2021-2025).
-- ==============================================================================
USE av_ready_saudi_dw;
GO
DECLARE @r TABLE (check_name VARCHAR(200), expected NVARCHAR(200), actual NVARCHAR(200), passed BIT);

-- weather: bronze = silver + bad date + SOD/SOM summaries + duplicate reports + outside 2021-2025 (local)
DECLARE @wb BIGINT = (SELECT COUNT_BIG(*) FROM bronze.noaa_hourly),
        @ws BIGINT = (SELECT COUNT_BIG(*) FROM silver.weather_obs),
        @wr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'weather_obs'),
        @wsum BIGINT = (SELECT COUNT_BIG(*) FROM bronze.noaa_hourly
                        WHERE TRY_CONVERT(DATETIME2(0), [DATE], 126) IS NOT NULL AND LTRIM(RTRIM(REPORT_TYPE)) IN ('SOD','SOM')),
        @wdup BIGINT, @wout BIGINT;
SELECT @wdup = COUNT_BIG(*) - COUNT_BIG(DISTINCT CONCAT(LTRIM(RTRIM([STATION])), '|', [DATE], '|', LTRIM(RTRIM(REPORT_TYPE))))
FROM bronze.noaa_hourly
WHERE TRY_CONVERT(DATETIME2(0), [DATE], 126) IS NOT NULL AND LTRIM(RTRIM(REPORT_TYPE)) NOT IN ('SOD','SOM');
SET @wout = @wb - @ws - @wr - @wsum - @wdup;
INSERT @r VALUES ('weather: bronze rows accounted for',
                  CONCAT(@wb, ' bronze'),
                  CONCAT(@ws, ' silver + ', @wr, ' rejected + ', @wsum, ' SOD/SOM + ', @wdup, ' duplicates + ', @wout, ' outside 2021-2025'),
                  IIF(@wout >= 0, 1, 0));

-- disengagements: bronze = silver + rejected
DECLARE @db BIGINT = (SELECT COUNT_BIG(*) FROM bronze.dmv_disengagements),
        @ds BIGINT = (SELECT COUNT_BIG(*) FROM silver.dmv_disengagement),
        @dr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'dmv_disengagement');
INSERT @r VALUES ('disengagements: bronze = silver + rejected', CAST(@db AS NVARCHAR), CONCAT(@ds, ' + ', @dr), IIF(@db = @ds + @dr, 1, 0));

-- crashes: bronze = silver + rejected + older report versions
DECLARE @nb BIGINT = (SELECT COUNT_BIG(*) FROM bronze.nhtsa_sgo_ads),
        @ns BIGINT = (SELECT COUNT_BIG(*) FROM silver.nhtsa_crash),
        @nr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'nhtsa_crash'),
        @nv BIGINT;
SELECT @nv = COUNT_BIG(*) - COUNT_BIG(DISTINCT LTRIM(RTRIM([Report ID]))) FROM bronze.nhtsa_sgo_ads;
INSERT @r VALUES ('crashes: bronze rows accounted for', CAST(@nb AS NVARCHAR),
                  CONCAT(@ns, ' silver + ', @nr, ' rejected + ', @nv, ' older versions + ',
                         @nb - @ns - @nr - @nv, ' same-incident duplicates'),
                  IIF(@nb - @ns - @nr - @nv >= 0, 1, 0));

-- accidents: 13 regions x 5 years, no unknown region label
INSERT @r SELECT 'accidents: 13 regions x 5 years', '65', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 65, 1, 0) FROM silver.accidents_region_year;
INSERT @r SELECT 'accidents: rejected GASTAT cells', '0', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 0, 1, 0)
FROM silver.reject_log WHERE source_table = 'accidents_region_year';
-- national totals must equal GASTAT's published totals
INSERT @r SELECT CONCAT('accidents: national serious accidents ', data_year),
       CASE data_year WHEN 2023 THEN '16534' WHEN 2024 THEN '17231' WHEN 2025 THEN '17805' END,
       CAST(SUM(serious_accidents) AS NVARCHAR),
       IIF(SUM(serious_accidents) = CASE data_year WHEN 2023 THEN 16534 WHEN 2024 THEN 17231 WHEN 2025 THEN 17805 END, 1, 0)
FROM silver.accidents_region_year WHERE data_year IN (2023, 2024, 2025) GROUP BY data_year;
INSERT @r SELECT CONCAT('accidents: national deaths ', data_year),
       CASE data_year WHEN 2023 THEN '4423' WHEN 2024 THEN '4282' WHEN 2025 THEN '4448' END,
       CAST(SUM(deaths) AS NVARCHAR),
       IIF(SUM(deaths) = CASE data_year WHEN 2023 THEN 4423 WHEN 2024 THEN 4282 WHEN 2025 THEN 4448 END, 1, 0)
FROM silver.accidents_region_year WHERE data_year IN (2023, 2024, 2025) GROUP BY data_year;

INSERT audit.dq_result (layer, check_name, expected, actual, passed)
SELECT 'silver', check_name, expected, actual, passed FROM @r;
SELECT check_name, expected, actual, IIF(passed = 1, 'PASS', 'FAIL') AS result FROM @r;

SELECT source_table, reason, COUNT(*) AS rows_rejected
FROM silver.reject_log GROUP BY source_table, reason ORDER BY source_table, rows_rejected DESC;
GO
