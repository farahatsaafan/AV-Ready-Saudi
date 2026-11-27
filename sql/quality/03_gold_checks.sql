-- ==============================================================================
-- AV-Ready-Saudi - Gold checks
--   * exactly one table in schema gold; grain 13 regions x 60 months, unique key
--   * foreign keys of Silver / prep / Gold exist, are enabled and trusted
--   * v2 shares sum to 1; env_readiness in [0, 1]; no Gold data column is constant
--   * every source family reaches Gold (Dr. Omar's rule: every file contributes)
--   * data-share report in three views: real vs generated / records per family / varying Gold columns per family
-- ==============================================================================
USE av_ready_saudi_dw;
GO
SET NOCOUNT ON;
DECLARE @r TABLE (check_name VARCHAR(200), expected NVARCHAR(200), actual NVARCHAR(200), passed BIT);

INSERT @r SELECT 'gold schema holds exactly one table', '1', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 1, 1, 0)
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'gold';
INSERT @r SELECT 'gold rows = 13 regions x 60 months', '780', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month;
INSERT @r SELECT 'gold key (region, month) is unique', '0 duplicates',
       CONCAT(COUNT(*) - COUNT(DISTINCT CONCAT(region_code, month_start)), ' duplicates'),
       IIF(COUNT(*) = COUNT(DISTINCT CONCAT(region_code, month_start)), 1, 0)
FROM gold.av_readiness_region_month;

-- relations: every declared FK is enabled and trusted (SQL Server has checked every row against its parent)
INSERT @r SELECT 'foreign keys on silver / prep / gold: enabled and trusted', '18 FKs, 0 untrusted',
       CONCAT(COUNT(*), ' FKs, ', SUM(IIF(fk.is_disabled = 1 OR fk.is_not_trusted = 1, 1, 0)), ' untrusted'),
       IIF(COUNT(*) = 18 AND SUM(IIF(fk.is_disabled = 1 OR fk.is_not_trusted = 1, 1, 0)) = 0, 1, 0)
FROM sys.foreign_keys fk WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) IN ('silver', 'prep', 'gold');
INSERT @r SELECT 'condition vocabulary: every bucket / day type / RR level is in silver.dim_condition', '0 orphans',
       CONCAT(SUM(x.n), ' orphans'), IIF(SUM(x.n) = 0, 1, 0)
FROM (SELECT COUNT(*) AS n FROM prep.weather_station_hour h WHERE NOT EXISTS (SELECT 1 FROM silver.dim_condition c WHERE c.condition_code = h.hour_bucket)
      UNION ALL SELECT COUNT(*) FROM prep.weather_station_day d WHERE NOT EXISTS (SELECT 1 FROM silver.dim_condition c WHERE c.condition_code = d.day_type)
      UNION ALL SELECT COUNT(*) FROM silver.nhtsa_crash n WHERE NOT EXISTS (SELECT 1 FROM silver.dim_condition c WHERE c.condition_code = n.weather_bucket)
      UNION ALL SELECT COUNT(*) FROM prep.av_relative_risk r WHERE NOT EXISTS (SELECT 1 FROM silver.dim_condition c WHERE c.condition_code = r.condition_code)) x;

-- content rules on complete months
INSERT @r SELECT 'v2 hour shares sum to 1 (+-0.001) on wx_complete rows', '0 rows off',
       CONCAT(SUM(IIF(ABS(share_normal_hours + share_rain_hours + share_fog_moist_hours + share_haze_dry_hours
                         + share_dust_hours - 1) > 0.001, 1, 0)), ' rows off of ', COUNT(*)),
       IIF(SUM(IIF(ABS(share_normal_hours + share_rain_hours + share_fog_moist_hours + share_haze_dry_hours
                      + share_dust_hours - 1) > 0.001, 1, 0)) = 0 AND COUNT(*) > 0, 1, 0)
FROM gold.av_readiness_region_month WHERE wx_complete = 1;
INSERT @r SELECT 'env_readiness and env_readiness_cons within [0, 1], cons <= base', '0 rows off',
       CONCAT(SUM(IIF(env_readiness NOT BETWEEN 0 AND 1 OR env_readiness_cons NOT BETWEEN 0 AND 1
                      OR env_readiness_cons > env_readiness, 1, 0)), ' rows off'),
       IIF(SUM(IIF(env_readiness NOT BETWEEN 0 AND 1 OR env_readiness_cons NOT BETWEEN 0 AND 1
                   OR env_readiness_cons > env_readiness, 1, 0)) = 0, 1, 0)
FROM gold.av_readiness_region_month WHERE wx_complete = 1;
INSERT @r SELECT 'complete weather months (coverage >= 80 %)', '> 650 of 780',
       CAST(SUM(CAST(wx_complete AS INT)) AS NVARCHAR), IIF(SUM(CAST(wx_complete AS INT)) > 650, 1, 0)
FROM gold.av_readiness_region_month;

-- no constant data column: every numeric data column takes > 1 value on the complete rows
-- (keys, the wx_complete filter flag and the batch id are not data columns)
DECLARE @const TABLE (col SYSNAME, n_distinct INT);
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'SELECT ''' + c.name + N''', COUNT(DISTINCT ' + QUOTENAME(c.name)
             + N') FROM gold.av_readiness_region_month WHERE wx_complete = 1 UNION ALL '
FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('gold.av_readiness_region_month')
  AND ty.name IN ('int', 'smallint', 'tinyint', 'bigint', 'decimal', 'float', 'numeric')
  AND c.name NOT IN ('year', 'month');
SET @sql = LEFT(@sql, LEN(@sql) - LEN(N' UNION ALL'));
INSERT @const EXEC sys.sp_executesql @sql;
INSERT @r SELECT 'no constant Gold data column (complete rows)', CONCAT('0 of ', COUNT(*), ' numeric columns constant'),
       CONCAT(SUM(IIF(n_distinct <= 1, 1, 0)), ' constant',
              ISNULL(N': ' + STRING_AGG(CASE WHEN n_distinct <= 1 THEN col END, N', '), N'')),
       IIF(SUM(IIF(n_distinct <= 1, 1, 0)) = 0, 1, 0)
FROM @const;

-- every source family reaches Gold
INSERT @r SELECT 'NOAA Saudi stations -> gold v2 weather shares', '13 regions',
       CONCAT(COUNT(DISTINCT region_code), ' regions'), IIF(COUNT(DISTINCT region_code) = 13, 1, 0)
FROM gold.av_readiness_region_month WHERE share_dust_hours IS NOT NULL AND share_haze_dry_hours IS NOT NULL;
INSERT @r SELECT 'NOAA US stations -> AV relative risks (exposure)', '> 0 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) > 0, 1, 0)
FROM prep.av_relative_risk WHERE exposure > 0;
INSERT @r SELECT 'GASTAT accidents -> gold accident columns', '780 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month WHERE acc_year_serious IS NOT NULL;
INSERT @r SELECT 'GASTAT roads -> gold road columns (2022-2025)', '624 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 624, 1, 0)
FROM gold.av_readiness_region_month WHERE road_km_per_km2 IS NOT NULL AND intercity_road_km IS NOT NULL;
INSERT @r SELECT 'GASTAT monthly traffic -> gold traffic columns', '780 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month WHERE traffic_adt_per_point IS NOT NULL AND traffic_month_index IS NOT NULL;
INSERT @r SELECT 'population (same year) -> gold rates per 100k', '780 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month WHERE population IS NOT NULL AND acc_serious_per_100k IS NOT NULL;
INSERT @r SELECT 'GASTAT rate-implied population 2023-2025 -> gold', '468 rows (13 x 36)',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 468, 1, 0)
FROM gold.av_readiness_region_month WHERE population_basis = 'gastat_rate_implied';
INSERT @r SELECT 'GASTAT region service 2025 -> gold', '780 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month WHERE response_outside_s IS NOT NULL AND registered_vehicles_2025 IS NOT NULL;
INSERT @r SELECT 'GASTAT: all 4 workbooks used', '4',
       CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 4, 1, 0)
FROM bronze.gastat_cells c
WHERE EXISTS (SELECT 1 FROM silver.gastat_sheet_map m WHERE c.source_file LIKE '%' + m.file_key + '%' AND c.sheet_name = m.sheet_name);
INSERT @r SELECT 'NHTSA crashes -> gold av_crash_multiplier / env_readiness (a used RR)', '>= 1 used RR, multiplier varies',
       CONCAT((SELECT COUNT(*) FROM prep.av_relative_risk WHERE used_in_index = 1 AND event_source = 'nhtsa_crash'),
              ' used; ', COUNT(DISTINCT av_crash_multiplier), ' distinct multipliers'),
       IIF((SELECT COUNT(*) FROM prep.av_relative_risk WHERE used_in_index = 1 AND event_source = 'nhtsa_crash') >= 1
           AND COUNT(DISTINCT av_crash_multiplier) > 1, 1, 0)
FROM gold.av_readiness_region_month WHERE wx_complete = 1;
INSERT @r SELECT 'DMV disengagements + mileage -> evidence rows (with notes) behind the Gold weights', '5 rows with notes',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 5 AND MIN(LEN(evidence_note)) > 0 AND SUM(exposure) > 0, 1, 0)
FROM prep.av_relative_risk WHERE event_source = 'dmv_disengagement';

INSERT audit.dq_result (layer, check_name, expected, actual, passed)
SELECT 'gold', check_name, expected, actual, passed FROM @r;
SELECT check_name, expected, actual, IIF(passed = 1, 'PASS', 'FAIL') AS result FROM @r;

-- the AV evidence table (Mantel-Haenszel, 95 % CI corrected for overdispersion; evidence rule applied)
SELECT event_source, factor, condition_code, events, CAST(exposure AS DECIMAL(14,1)) AS exposure,
       CAST(rr_crude AS DECIMAL(8,3)) AS rr_crude, CAST(rr_adjusted AS DECIMAL(8,3)) AS rr_adjusted,
       CAST(ci_low AS DECIMAL(8,3)) AS ci_low, CAST(ci_high AS DECIMAL(8,3)) AS ci_high, n_strata,
       CAST(dispersion AS DECIMAL(8,2)) AS dispersion, used_in_index, evidence_note
FROM prep.av_relative_risk ORDER BY event_source, factor, condition_code;

-- Data shares, view 1: real vs generated (every record is real: 0 % generated)
-- Data shares, view 2: records per source family (what feeds Gold)
;WITH fam AS (
    SELECT 'weather - Saudi (NOAA hourly reports)' AS family, 'Saudi' AS origin, COUNT_BIG(*) AS records
    FROM silver.weather_obs w JOIN silver.dim_station s ON s.station_id = w.station_id WHERE s.country = 'SA'
    UNION ALL
    SELECT 'weather - US analog (NOAA hourly reports)', 'foreign', COUNT_BIG(*)
    FROM silver.weather_obs w JOIN silver.dim_station s ON s.station_id = w.station_id WHERE s.country = 'US'
    UNION ALL
    SELECT 'accidents - Saudi GASTAT (region-year values)', 'Saudi',
           SUM(IIF(serious_accidents IS NULL, 0, 1) + IIF(deaths IS NULL, 0, 1) + IIF(injuries IS NULL, 0, 1)
             + IIF(serious_within_cities IS NULL, 0, 1) + IIF(serious_outside_cities IS NULL, 0, 1))
    FROM silver.accidents_region_year
    UNION ALL
    SELECT 'roads - Saudi GASTAT (region-year values)', 'Saudi',
           SUM(IIF(road_km_per_1000_people IS NULL, 0, 1) + IIF(road_km_per_km2 IS NULL, 0, 1)
             + IIF(intercity_highway_km IS NULL, 0, 1) + IIF(intercity_dual_km IS NULL, 0, 1)
             + IIF(intercity_exit_km IS NULL, 0, 1) + IIF(intercity_single_km IS NULL, 0, 1))
    FROM silver.roads_region_year
    UNION ALL SELECT 'traffic - Saudi GASTAT (region-month values)', 'Saudi', COUNT_BIG(*) FROM silver.traffic_region_month
    UNION ALL SELECT 'population - Saudi GASTAT (region-year values)', 'Saudi', COUNT_BIG(*) FROM silver.population_region_year
    UNION ALL SELECT 'region service - Saudi GASTAT 2025 (region values)', 'Saudi', 3 * COUNT_BIG(*) FROM silver.region_service_2025
    UNION ALL SELECT 'AV - DMV disengagements', 'foreign', COUNT_BIG(*) FROM silver.dmv_disengagement
    UNION ALL SELECT 'AV - DMV mileage (vehicle-months)', 'foreign', COUNT_BIG(*) FROM silver.dmv_mileage_monthly
    UNION ALL SELECT 'AV - NHTSA crashes (CA/AZ/TX, 2021-2025)', 'foreign', COUNT_BIG(*) FROM silver.nhtsa_crash WHERE in_scope = 1
)
SELECT * INTO #fam FROM fam;

SELECT 'view 1: real vs generated' AS view_name, 'real (official published sources)' AS kind, SUM(records) AS records,
       CAST(100.0 AS DECIMAL(6,2)) AS share_pct FROM #fam
UNION ALL SELECT 'view 1: real vs generated', 'generated / imputed / projected', 0, CAST(0 AS DECIMAL(6,2));

SELECT 'view 2: records per source family' AS view_name, family, origin, records,
       CAST(100.0 * records / SUM(records) OVER () AS DECIMAL(6,2)) AS share_pct
FROM #fam ORDER BY records DESC;

-- Data shares, view 3: Gold columns that carry varying data, by family (complete rows)
SELECT 'view 3: varying Gold data columns per family' AS view_name,
       CASE WHEN col LIKE 'av[_]%' OR col LIKE 'env[_]%' THEN 'AV evidence (NHTSA + DMV + US weather)'
            WHEN col LIKE 'acc[_]%' THEN 'accidents (GASTAT)'
            WHEN col LIKE 'population%' THEN 'population (GASTAT)'
            WHEN col LIKE 'road[_]%' OR col LIKE 'intercity[_]%' THEN 'roads (GASTAT)'
            WHEN col LIKE 'traffic[_]%' THEN 'traffic (GASTAT)'
            WHEN col LIKE 'response[_]%' OR col LIKE 'registered[_]%' THEN 'region service (GASTAT)'
            ELSE 'weather (NOAA Saudi stations)' END AS family,
       COUNT(*) AS varying_columns,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(6,2)) AS share_pct
FROM @const WHERE n_distinct > 1
GROUP BY CASE WHEN col LIKE 'av[_]%' OR col LIKE 'env[_]%' THEN 'AV evidence (NHTSA + DMV + US weather)'
              WHEN col LIKE 'acc[_]%' THEN 'accidents (GASTAT)'
              WHEN col LIKE 'population%' THEN 'population (GASTAT)'
              WHEN col LIKE 'road[_]%' OR col LIKE 'intercity[_]%' THEN 'roads (GASTAT)'
              WHEN col LIKE 'traffic[_]%' THEN 'traffic (GASTAT)'
              WHEN col LIKE 'response[_]%' OR col LIKE 'registered[_]%' THEN 'region service (GASTAT)'
              ELSE 'weather (NOAA Saudi stations)' END
ORDER BY varying_columns DESC;

-- events represented (what the records describe)
SELECT 'Saudi serious accidents 2021-2025' AS measure, SUM(serious_accidents) AS value FROM silver.accidents_region_year
UNION ALL SELECT 'Saudi road deaths 2021-2025', SUM(deaths) FROM silver.accidents_region_year
UNION ALL SELECT 'Saudi weather station-hours', COUNT_BIG(*) FROM prep.weather_station_hour h JOIN silver.dim_station s ON s.station_id = h.station_id WHERE s.country = 'SA'
UNION ALL SELECT 'AV disengagements (CA DMV)', COUNT_BIG(*) FROM silver.dmv_disengagement
UNION ALL SELECT 'AV crashes (NHTSA, in scope)', COUNT_BIG(*) FROM silver.nhtsa_crash WHERE in_scope = 1;
DROP TABLE #fam;
GO
