-- ==============================================================================
-- AV-Ready-Saudi - first analysis queries on the single Gold table (EDA support)
-- Nothing here creates tables: every query reads gold.av_readiness_region_month.
-- ==============================================================================
USE av_ready_saudi_dw;
GO

-- 1. Dr. Omar's comparison: years with more bad-weather hours vs serious accidents.
--    Accidents are annual per region, so compare at region x year grain.
;WITH ry AS (
    SELECT region_code, [year],
           AVG(share_obscured_hours) AS obscured_share,
           AVG(share_dust_hours)     AS dust_share,
           AVG(share_rain_hours)     AS rain_share,
           MAX(acc_year_serious)     AS serious,
           MAX(acc_year_deaths)      AS deaths
    FROM gold.av_readiness_region_month
    WHERE share_obscured_hours IS NOT NULL
    GROUP BY region_code, [year]
), split AS (
    SELECT ry.*, NTILE(2) OVER (PARTITION BY region_code ORDER BY obscured_share) AS half
    FROM ry
)
SELECT region_code,
       AVG(CASE WHEN half = 2 THEN serious END) AS serious_in_worse_weather_years,
       AVG(CASE WHEN half = 1 THEN serious END) AS serious_in_better_weather_years
FROM split GROUP BY region_code ORDER BY region_code;
-- Association only: years also differ in traffic volume, enforcement and population.

-- 2. Environmental profile and AV risk index by region and season
SELECT region_name_en, season,
       CAST(AVG(share_dust_hours)     * 100 AS DECIMAL(5,2)) AS dust_hours_pct,
       CAST(AVG(share_obscured_hours) * 100 AS DECIMAL(5,2)) AS obscured_hours_pct,
       CAST(AVG(share_rain_hours)     * 100 AS DECIMAL(5,2)) AS rain_hours_pct,
       CAST(AVG(temp_max_c) AS DECIMAL(5,1))                 AS avg_monthly_max_temp_c,
       CAST(AVG(av_crash_risk_index)  AS DECIMAL(6,3))       AS av_crash_risk_index,
       CAST(AVG(av_diseng_risk_index) AS DECIMAL(6,3))       AS av_diseng_risk_index
FROM gold.av_readiness_region_month
WHERE share_obscured_hours IS NOT NULL
GROUP BY region_name_en, season
ORDER BY av_diseng_risk_index DESC;

-- 3. Weather coverage per region (months with fewer than 80% of hours observed)
SELECT region_code, COUNT(*) AS months, SUM(IIF(wx_coverage_pct < 80, 1, 0)) AS months_below_80pct,
       SUM(IIF(wx_hours_observed IS NULL, 1, 0)) AS months_without_weather
FROM gold.av_readiness_region_month GROUP BY region_code ORDER BY region_code;
GO
