-- ==============================================================================
-- AV-Ready-Saudi - Silver reconciliation
-- Each Bronze row must be accounted for: kept in Silver, rejected with a reason,
-- or removed by a documented rule (summary record, duplicate, outside 2021-2025).
-- Each rule is counted explicitly; the check passes only when the parts add up exactly.
-- ==============================================================================
USE av_ready_saudi_dw;
GO
DECLARE @r TABLE (check_name VARCHAR(200), expected NVARCHAR(200), actual NVARCHAR(200), passed BIT);

-- Every exclusion is counted on its own (not as "the rest"), so a row that disappears
-- for any other reason makes the check FAIL instead of hiding in a remainder.

-- weather: bronze = silver + bad date + SOD/SOM summaries + blank report type
--          + unknown station + duplicate reports + outside 2021-2025 (local time)
DECLARE @wb BIGINT = (SELECT COUNT_BIG(*) FROM bronze.noaa_hourly),
        @ws BIGINT = (SELECT COUNT_BIG(*) FROM silver.weather_obs),
        @wr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'weather_obs'),
        @wsum BIGINT, @wnrt BIGINT, @wnst BIGINT, @wdup BIGINT, @wout BIGINT;
SELECT @wsum = SUM(IIF(LTRIM(RTRIM(REPORT_TYPE)) IN ('SOD','SOM'), 1, 0)),
       @wnrt = SUM(IIF(REPORT_TYPE IS NULL, 1, 0))
FROM bronze.noaa_hourly
WHERE TRY_CONVERT(DATETIME2(0), [DATE], 126) IS NOT NULL;
SELECT @wnst = COUNT_BIG(*)
FROM bronze.noaa_hourly b
WHERE TRY_CONVERT(DATETIME2(0), b.[DATE], 126) IS NOT NULL
  AND LTRIM(RTRIM(b.REPORT_TYPE)) NOT IN ('SOD','SOM')
  AND NOT EXISTS (SELECT 1 FROM silver.dim_station s WHERE s.station_id = LTRIM(RTRIM(b.STATION)));
;WITH k AS (   -- same candidate rows and the same de-duplication as silver.load_silver
    SELECT TRY_CONVERT(DATETIME2(0), b.[DATE], 126) AS obs_utc, s.tz_name,
           ROW_NUMBER() OVER (PARTITION BY b.STATION, b.[DATE], LTRIM(RTRIM(b.REPORT_TYPE))
                              ORDER BY TRY_CAST(b.source_row_num AS INT)) AS rn
    FROM bronze.noaa_hourly b
    JOIN silver.dim_station s ON s.station_id = LTRIM(RTRIM(b.STATION))
    WHERE TRY_CONVERT(DATETIME2(0), b.[DATE], 126) IS NOT NULL
      AND LTRIM(RTRIM(b.REPORT_TYPE)) NOT IN ('SOD','SOM')
)
SELECT @wdup = SUM(IIF(rn > 1, 1, 0)),
       @wout = SUM(IIF(rn = 1 AND YEAR(CAST(CAST(obs_utc AS DATETIMEOFFSET) AT TIME ZONE tz_name AS DATETIME2(0)))
                               NOT BETWEEN 2021 AND 2025, 1, 0))
FROM k;
INSERT @r VALUES ('weather: bronze rows accounted for',
                  CONCAT(@wb, ' bronze'),
                  CONCAT(@ws, ' silver + ', @wr, ' rejected + ', @wsum, ' SOD/SOM + ', @wnrt, ' blank report type + ',
                         @wnst, ' unknown station + ', @wdup, ' duplicates + ', @wout, ' outside 2021-2025'),
                  IIF(@wb = @ws + @wr + @wsum + @wnrt + @wnst + @wdup + @wout, 1, 0));

-- disengagements: bronze = silver + rejected
DECLARE @db BIGINT = (SELECT COUNT_BIG(*) FROM bronze.dmv_disengagements),
        @ds BIGINT = (SELECT COUNT_BIG(*) FROM silver.dmv_disengagement),
        @dr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'dmv_disengagement');
INSERT @r VALUES ('disengagements: bronze = silver + rejected', CAST(@db AS NVARCHAR), CONCAT(@ds, ' + ', @dr), IIF(@db = @ds + @dr, 1, 0));

-- mileage: every month cell of every report = silver row + rejected cell + same VIN/month in a second file
DECLARE @mb BIGINT = (SELECT COUNT_BIG(*) FROM bronze.dmv_mileage),
        @mnj BIGINT = (SELECT COUNT_BIG(*) FROM bronze.dmv_mileage WHERE ISNULL(ISJSON(months_json), 0) <> 1),
        @ms BIGINT = (SELECT COUNT_BIG(*) FROM silver.dmv_mileage_monthly),
        @mr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'dmv_mileage_monthly'),
        @mc BIGINT, @mkeys BIGINT, @mdup BIGINT;
;WITH cells AS (   -- same unpivot and rules as silver.load_silver
    SELECT ISNULL(LTRIM(RTRIM(m.permit_number)), '') AS permit_number, ISNULL(LTRIM(RTRIM(m.vin)), '') AS vin,
           TRY_CAST(CONCAT(RIGHT(LTRIM(RTRIM(j.k)), 4), '-',
               CASE LEFT(UPPER(LTRIM(j.k)), 3)
                 WHEN 'JAN' THEN '01' WHEN 'FEB' THEN '02' WHEN 'MAR' THEN '03' WHEN 'APR' THEN '04'
                 WHEN 'MAY' THEN '05' WHEN 'JUN' THEN '06' WHEN 'JUL' THEN '07' WHEN 'AUG' THEN '08'
                 WHEN 'SEP' THEN '09' WHEN 'OCT' THEN '10' WHEN 'NOV' THEN '11' WHEN 'DEC' THEN '12' END,
               '-01') AS DATE) AS month_start,
           TRY_CAST(REPLACE(REPLACE(j.v, ',', ''), ' ', '') AS DECIMAL(14,2)) AS miles
    FROM bronze.dmv_mileage m
    CROSS APPLY (SELECT oj.[key] COLLATE DATABASE_DEFAULT AS k, oj.[value] COLLATE DATABASE_DEFAULT AS v
                 FROM OPENJSON(m.months_json) oj) j
    WHERE ISJSON(m.months_json) = 1
      AND j.k NOT LIKE '%TOTAL%' AND j.k NOT LIKE 'col%'
), kept AS (
    SELECT * FROM cells
    WHERE month_start IS NOT NULL AND miles IS NOT NULL AND miles >= 0 AND permit_number <> '' AND vin <> ''
)
SELECT @mc = (SELECT COUNT_BIG(*) FROM cells),
       @mkeys = (SELECT COUNT_BIG(*) FROM (SELECT DISTINCT permit_number, vin, month_start FROM kept) d),
       @mdup = (SELECT COUNT_BIG(*) FROM kept) - (SELECT COUNT_BIG(*) FROM (SELECT DISTINCT permit_number, vin, month_start FROM kept) d);
INSERT @r VALUES ('mileage: bronze reports without readable month columns', '0',
                  CONCAT(@mnj, ' of ', @mb, ' reports'), IIF(@mnj = 0, 1, 0));
INSERT @r VALUES ('mileage: month cells accounted for', CONCAT(@mc, ' cells'),
                  CONCAT(@ms, ' silver + ', @mr, ' rejected + ', @mdup, ' same VIN/month in a second file'),
                  IIF(@mc = @ms + @mr + @mdup AND @ms = @mkeys, 1, 0));

-- crashes: bronze = silver + rejected + blank Report ID + older report versions + same-incident duplicates
DECLARE @nb BIGINT = (SELECT COUNT_BIG(*) FROM bronze.nhtsa_sgo_ads),
        @ns BIGINT = (SELECT COUNT_BIG(*) FROM silver.nhtsa_crash),
        @nr BIGINT = (SELECT COUNT_BIG(*) FROM silver.reject_log WHERE source_table = 'nhtsa_crash'),
        @nblank BIGINT, @nv BIGINT, @nsame BIGINT;
SELECT @nblank = SUM(IIF(ISNULL(LTRIM(RTRIM([Report ID])), '') = '', 1, 0)),
       @nv = SUM(IIF(ISNULL(LTRIM(RTRIM([Report ID])), '') <> '', 1, 0))
             - COUNT(DISTINCT NULLIF(LTRIM(RTRIM([Report ID])), ''))
FROM bronze.nhtsa_sgo_ads;
;WITH b AS (   -- same version and same-incident rules as silver.load_silver
    SELECT LTRIM(RTRIM(n.[Report ID])) AS rid, TRY_CAST(n.[Report Version] AS INT) AS ver,
           CASE WHEN n.source_file LIKE '%archive%' THEN 1 ELSE 2 END AS file_rank,
           NULLIF(LTRIM(RTRIM(JSON_VALUE(n.row_json, '$."Same Incident ID"'))), '') AS same_incident
    FROM bronze.nhtsa_sgo_ads n
), v AS (
    SELECT b.*, ROW_NUMBER() OVER (PARTITION BY rid ORDER BY ver DESC, file_rank) AS rn
    FROM b WHERE rid <> ''
), one AS (
    SELECT v.*, ROW_NUMBER() OVER (PARTITION BY file_rank, ISNULL(same_incident, rid) ORDER BY rid) AS rn_s
    FROM v WHERE rn = 1
)
SELECT @nsame = SUM(IIF(rn_s > 1, 1, 0)) FROM one;
INSERT @r VALUES ('crashes: bronze rows accounted for', CAST(@nb AS NVARCHAR),
                  CONCAT(@ns, ' silver + ', @nr, ' rejected + ', @nblank, ' blank Report ID + ',
                         @nv, ' older versions + ', @nsame, ' same-incident duplicates'),
                  IIF(@nb = @ns + @nr + @nblank + @nv + @nsame, 1, 0));

-- accidents: 13 regions x 5 years, no unknown region label
INSERT @r SELECT 'accidents: 13 regions x 5 years', '65', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 65, 1, 0) FROM silver.accidents_region_year;
INSERT @r SELECT 'accidents: rejected GASTAT cells', '0', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 0, 1, 0)
FROM silver.reject_log WHERE source_table = 'accidents_region_year';
-- roads: 13 regions x 4 years (2022-2025), no unknown region label or non-numeric cell
INSERT @r SELECT 'roads: 13 regions x 4 years (2022-2025)', '52', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 52, 1, 0)
FROM silver.roads_region_year;
INSERT @r SELECT 'roads: rejected GASTAT cells', '0', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 0, 1, 0)
FROM silver.reject_log WHERE source_table = 'roads_region_year';
-- population (GASTAT Census 2022 table): 13 regions x 13 years, national 2022 total = official census count
INSERT @r SELECT 'population: 13 regions x 13 years (2010-2022)', '169', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 169, 1, 0)
FROM silver.population_region_year;
INSERT @r SELECT 'population: rejected census rows', '0', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 0, 1, 0)
FROM silver.reject_log WHERE source_table = 'population_region_year';
INSERT @r SELECT 'population: Saudi Arabia 2022 = census count', '32175224', CAST(SUM(population) AS NVARCHAR),
       IIF(SUM(population) = 32175224, 1, 0)
FROM silver.population_region_year WHERE data_year = 2022;
-- our serious-accident rate per 100,000 (census 2022 population) against GASTAT's own published rate
-- (mid-year population estimates). Ours is higher by roughly the population growth since 2022, so the
-- check passes when every region is within 25 % of the official rate.
;WITH official AS (
    SELECT m.data_year, a.region_code,
           TRY_CAST(REPLACE(v.cell_value, ',', '') AS FLOAT) AS official_rate
    FROM silver.gastat_sheet_map m
    JOIN bronze.gastat_cells v   ON v.source_file LIKE '%' + m.file_key + '%' AND v.sheet_name = m.sheet_name
                                AND TRY_CAST(v.col_num AS INT) = m.col_num
                                AND TRY_CAST(v.row_num AS INT) BETWEEN m.first_row AND m.last_row
    JOIN bronze.gastat_cells lbl ON lbl.source_file = v.source_file AND lbl.sheet_name = v.sheet_name
                                AND lbl.row_num = v.row_num AND TRY_CAST(lbl.col_num AS INT) = 1
    JOIN silver.region_alias a   ON a.alias_key = silver.fn_region_key(lbl.cell_value)
    WHERE m.metric = 'official_serious_per_100k'
), ours AS (
    SELECT a.data_year, a.region_code, 100000.0 * a.serious_accidents / p.population AS our_rate
    FROM silver.accidents_region_year a
    JOIN silver.population_region_year p ON p.region_code = a.region_code AND p.data_year = 2022
)
INSERT @r SELECT CONCAT('population: serious per 100k vs GASTAT official ', o.data_year),
       '13 regions within 25 %',
       CONCAT(SUM(IIF(ABS(u.our_rate / o.official_rate - 1) <= 0.25, 1, 0)), ' regions; max diff ',
              CAST(MAX(ABS(u.our_rate / o.official_rate - 1)) * 100 AS DECIMAL(5,1)), ' %'),
       IIF(SUM(IIF(ABS(u.our_rate / o.official_rate - 1) <= 0.25, 1, 0)) = 13, 1, 0)
FROM official o JOIN ours u ON u.region_code = o.region_code AND u.data_year = o.data_year
GROUP BY o.data_year;
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
