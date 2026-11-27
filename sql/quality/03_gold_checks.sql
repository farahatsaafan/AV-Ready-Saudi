-- ==============================================================================
-- AV-Ready-Saudi - Gold checks
--   * exactly one table in schema gold
--   * grain: 13 regions x 60 months, unique key
--   * every source family reaches Gold (Dr. Omar's rule: every file contributes)
--   * data-share report (real vs generated, Saudi vs foreign, by family)
-- ==============================================================================
USE av_ready_saudi_dw;
GO
DECLARE @r TABLE (check_name VARCHAR(200), expected NVARCHAR(200), actual NVARCHAR(200), passed BIT);

INSERT @r SELECT 'gold schema holds exactly one table', '1', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 1, 1, 0)
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'gold';
INSERT @r SELECT 'gold rows = 13 regions x 60 months', '780', CAST(COUNT(*) AS NVARCHAR), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month;
INSERT @r SELECT 'gold key (region, month) is unique', '0 duplicates',
       CONCAT(COUNT(*) - COUNT(DISTINCT CONCAT(region_code, month_start)), ' duplicates'),
       IIF(COUNT(*) = COUNT(DISTINCT CONCAT(region_code, month_start)), 1, 0)
FROM gold.av_readiness_region_month;

-- every Bronze source reaches Gold
INSERT @r SELECT 'NOAA Saudi stations -> gold weather columns', '13 regions',
       CONCAT(COUNT(DISTINCT region_code), ' regions'), IIF(COUNT(DISTINCT region_code) = 13, 1, 0)
FROM gold.av_readiness_region_month WHERE share_obscured_hours IS NOT NULL;
INSERT @r SELECT 'NOAA US stations -> relative risks (exposure)', '> 0 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) > 0, 1, 0)
FROM prep.av_relative_risk WHERE exposure_share IS NOT NULL;
INSERT @r SELECT 'GASTAT -> gold accident columns', '780 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 780, 1, 0)
FROM gold.av_readiness_region_month WHERE acc_year_serious IS NOT NULL;
INSERT @r SELECT 'GASTAT roads -> gold road columns (2022-2025)', '624 rows',
       CONCAT(COUNT(*), ' rows'), IIF(COUNT(*) = 624, 1, 0)
FROM gold.av_readiness_region_month WHERE road_km_per_km2 IS NOT NULL AND intercity_road_km IS NOT NULL;
INSERT @r SELECT 'GASTAT: all 4 workbooks used', '4',
       CAST(COUNT(DISTINCT source_file) AS NVARCHAR), IIF(COUNT(DISTINCT source_file) = 4, 1, 0)
FROM bronze.gastat_cells c
WHERE EXISTS (SELECT 1 FROM silver.gastat_sheet_map m WHERE c.source_file LIKE '%' + m.file_key + '%' AND c.sheet_name = m.sheet_name);
INSERT @r SELECT 'NHTSA crashes -> gold av_rr_crash_*', 'not null',
       IIF(MAX(av_rr_crash_rain) IS NULL, 'null', 'set'), IIF(MAX(av_rr_crash_rain) IS NULL, 0, 1)
FROM gold.av_readiness_region_month;
INSERT @r SELECT 'DMV disengagements + mileage -> gold av_rr_diseng_*', 'not null',
       IIF(MAX(av_rr_diseng_fog_haze_day) IS NULL, 'null', 'set'), IIF(MAX(av_rr_diseng_fog_haze_day) IS NULL, 0, 1)
FROM gold.av_readiness_region_month;

INSERT audit.dq_result (layer, check_name, expected, actual, passed)
SELECT 'gold', check_name, expected, actual, passed FROM @r;
SELECT check_name, expected, actual, IIF(passed = 1, 'PASS', 'FAIL') AS result FROM @r;

-- relative risks used by Gold (with the evidence rule)
SELECT event_source, factor, level, events, ROUND(event_share, 4) AS event_share,
       ROUND(exposure_share, 4) AS exposure_share, ROUND(relative_risk, 3) AS relative_risk, used_in_index
FROM prep.av_relative_risk ORDER BY event_source, factor, level;

-- data shares: real records that feed Gold, by family (everything is real: 0% generated)
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
    UNION ALL SELECT 'AV - DMV disengagements', 'foreign', COUNT_BIG(*) FROM silver.dmv_disengagement
    UNION ALL SELECT 'AV - DMV mileage (vehicle-months)', 'foreign', COUNT_BIG(*) FROM silver.dmv_mileage_monthly
    UNION ALL SELECT 'AV - NHTSA crashes (CA/AZ/TX, 2021-2025)', 'foreign', COUNT_BIG(*) FROM silver.nhtsa_crash WHERE in_scope = 1
)
SELECT family, origin, records, CAST(100.0 * records / SUM(records) OVER () AS DECIMAL(6,2)) AS share_pct
FROM fam ORDER BY records DESC;

-- events represented (what the records describe)
SELECT 'Saudi serious accidents 2021-2025' AS measure, SUM(serious_accidents) AS value FROM silver.accidents_region_year
UNION ALL SELECT 'Saudi road deaths 2021-2025', SUM(deaths) FROM silver.accidents_region_year
UNION ALL SELECT 'Saudi weather station-hours', COUNT_BIG(*) FROM prep.weather_station_hour h JOIN silver.dim_station s ON s.station_id = h.station_id WHERE s.country = 'SA'
UNION ALL SELECT 'AV disengagements (CA DMV)', COUNT_BIG(*) FROM silver.dmv_disengagement
UNION ALL SELECT 'AV crashes (NHTSA, in scope)', COUNT_BIG(*) FROM silver.nhtsa_crash WHERE in_scope = 1;
GO
