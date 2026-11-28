-- ==============================================================================
-- Project : AV-Ready-Saudi
-- Script  : 04_analysis.sql  -  EDA suite on the ONE Gold table (reads nothing else)
-- Unit 5 OLAP: ROLLUP, CUBE, GROUPING SETS, GROUPING(); window functions RANK / NTILE / LAG.
-- Grain reminder: Gold is region x month. Accident columns are ANNUAL values repeated on the 12 months
-- of a year: they are always reduced to one row per region-year with MAX (never SUM over months).
-- Each query states its business question; the findings of the last run are written under it.
-- ==============================================================================
USE av_ready_saudi_dw;
GO
SET NOCOUNT ON;

-- ------------------------------------------------------------------------------
-- E1. Overview
-- Business question: how much of the Gold table can be analysed (complete weather months per region)?
-- Finding (run of 28 Nov 2026): 780 rows; 715 complete weather months (55 per region, Jan 2021 - Jul 2025, mean coverage 97.6-97.8 %).
--   Every region has the same coverage, so no region is favoured by missing data.
-- ------------------------------------------------------------------------------
SELECT region_code, COUNT(*) AS months, SUM(CAST(wx_complete AS INT)) AS complete_months,
       CAST(AVG(wx_coverage_pct) AS DECIMAL(5,1)) AS mean_coverage_pct,
       MIN(CASE WHEN wx_complete = 1 THEN month_start END) AS first_complete,
       MAX(CASE WHEN wx_complete = 1 THEN month_start END) AS last_complete
FROM gold.av_readiness_region_month
GROUP BY region_code
ORDER BY complete_months, region_code;

-- ------------------------------------------------------------------------------
-- E2. ROLLUP(region, season)
-- Business question: which region-seasons have the lowest environment readiness, and is it dust or dry haze?
-- Finding (run of 28 Nov 2026): across all complete months env_readiness 0.964, conservative 0.952 (dust 3.44 %, dry haze 1.15 % of hours).
--   Lowest region-seasons (conservative): JAZ summer 0.785 (dust 12.1 % + dry haze 9.0 %), NAJ spring 0.857,
--   RIY spring 0.864, QAS spring 0.893, EAS spring 0.894. Spring is the dust season in the centre and east
--   (RIY 12.7 %, NAJ 12.9 %, QAS 10.2 % dust); Jazan's loss is summer dry haze + dust. Highest: HAI autumn 0.997.
-- ------------------------------------------------------------------------------
SELECT CASE WHEN GROUPING(region_code) = 1 THEN 'ALL REGIONS' ELSE region_code END AS region,
       CASE WHEN GROUPING(season) = 1 THEN 'ALL SEASONS' ELSE season END AS season,
       COUNT(*) AS months,
       CAST(AVG(CAST(env_readiness AS FLOAT)) AS DECIMAL(6,4))      AS env_readiness,
       CAST(AVG(CAST(env_readiness_cons AS FLOAT)) AS DECIMAL(6,4)) AS env_readiness_cons,
       CAST(100 * AVG(CAST(share_dust_hours AS FLOAT)) AS DECIMAL(6,2))     AS dust_pct,
       CAST(100 * AVG(CAST(share_haze_dry_hours AS FLOAT)) AS DECIMAL(6,2)) AS haze_dry_pct
FROM gold.av_readiness_region_month
WHERE wx_complete = 1
GROUP BY ROLLUP(region_code, season)
ORDER BY GROUPING(region_code), region_code, GROUPING(season), env_readiness;

-- ------------------------------------------------------------------------------
-- E3. CUBE(region, season, year) of the conservative uncovered share (dust + dry haze)
-- Business question: how much of the time falls outside the US AV evidence, by every combination of
--                    region, season and year?
-- Finding (run of 28 Nov 2026): 4.59 % of complete hours fall outside the US AV evidence (dust + dry haze). By year 2022 is the outlier
--   (7.67 %; spring 2022 14.82 %), 2024 the cleanest (2.59 %). By season spring 7.13 % > summer 5.03 % > winter
--   3.50 % > autumn 2.19 %. By region JAZ 11.18 %, NAJ 8.47 %, EAS 7.88 %, RIY 6.97 % ... HAI and TAB lowest.
-- ------------------------------------------------------------------------------
SELECT CASE WHEN GROUPING(region_code) = 1 THEN 'ALL' ELSE region_code END AS region,
       CASE WHEN GROUPING(season) = 1 THEN 'ALL' ELSE season END AS season,
       CASE WHEN GROUPING([year]) = 1 THEN 'ALL' ELSE CAST([year] AS VARCHAR(4)) END AS [year],
       GROUPING(region_code) * 4 + GROUPING(season) * 2 + GROUPING([year]) AS grouping_level,
       COUNT(*) AS months,
       CAST(100 * AVG(CAST(av_uncovered_share_cons AS FLOAT)) AS DECIMAL(6,2)) AS uncovered_cons_pct
FROM gold.av_readiness_region_month
WHERE wx_complete = 1
GROUP BY CUBE(region_code, season, [year])
ORDER BY grouping_level DESC, uncovered_cons_pct DESC;

-- ------------------------------------------------------------------------------
-- E4. GROUPING SETS((region), (season), ())
-- Business question: is extreme heat or rain the bigger exposure, by region and by season?
-- Finding (run of 28 Nov 2026): hours >= 40 degC: 5.82 % overall (summer 17.87 %), highest in MED 14.01 %, EAS 13.54 %, RIY 12.74 %,
--   QAS 11.56 %; 0 % in ASR and BAH (highlands). Hours >= 45 degC 0.64 % (EAS 3.68 %). Rain is rare everywhere
--   (0.51 % of hours; winter 0.74 %). Heat is a bigger exposure than rain, but it is covered: Phoenix, where AV
--   fleets run commercially, has 7.5 % of hours >= 40 degC.
-- ------------------------------------------------------------------------------
SELECT CASE WHEN GROUPING(region_code) = 0 THEN 'region' WHEN GROUPING(season) = 0 THEN 'season' ELSE 'total' END AS level_,
       COALESCE(region_code, season, 'ALL') AS member,
       CAST(100 * AVG(CAST(share_hot40_hours AS FLOAT)) AS DECIMAL(6,2)) AS hot40_pct,
       CAST(100 * AVG(CAST(share_hot45_hours AS FLOAT)) AS DECIMAL(6,2)) AS hot45_pct,
       CAST(100 * AVG(CAST(share_rain_hours AS FLOAT)) AS DECIMAL(6,2))  AS rain_pct
FROM gold.av_readiness_region_month
WHERE wx_complete = 1
GROUP BY GROUPING SETS ((region_code), (season), ())
ORDER BY level_, hot40_pct DESC;

-- ------------------------------------------------------------------------------
-- E5. Window functions: rank per season, readiness tiers, year-over-year dust change
-- Business question: where does each region rank in each season, which third is it in, and is dust rising?
-- Finding (run of 28 Nov 2026): HAI ranks 1st in summer and autumn, ASR in winter and spring. EAS and RIY are in the lowest third in all
--   four seasons, NAJ in three, JAZ is last in summer and autumn. Dust peaked in 2022 in 9 of 13 regions
--   (RIY 13.19 %, NAJ 13.08 %, QAS 11.23 %, EAS 9.30 %; QAS +7.74 pp vs 2021; JAZ and TAB peaked in 2023, JOF and
--   MAK in 2021) and fell back in every region by 2024 (RIY 2.35 %, QAS 0.85 %).
-- ------------------------------------------------------------------------------
;WITH rs AS (
    SELECT region_code, season, AVG(CAST(env_readiness_cons AS FLOAT)) AS readiness
    FROM gold.av_readiness_region_month WHERE wx_complete = 1 GROUP BY region_code, season
)
SELECT season, region_code, CAST(readiness AS DECIMAL(6,4)) AS env_readiness_cons,
       RANK()   OVER (PARTITION BY season ORDER BY readiness DESC) AS rank_in_season,
       NTILE(3) OVER (PARTITION BY season ORDER BY readiness DESC) AS tier_1_high_3_low
FROM rs ORDER BY season, rank_in_season;

;WITH ry AS (
    SELECT region_code, [year], AVG(CAST(share_dust_hours AS FLOAT)) AS dust
    FROM gold.av_readiness_region_month WHERE wx_complete = 1 AND [year] <= 2024 GROUP BY region_code, [year]
)
SELECT region_code, [year], CAST(100 * dust AS DECIMAL(6,2)) AS dust_pct,
       CAST(100 * (dust - LAG(dust) OVER (PARTITION BY region_code ORDER BY [year])) AS DECIMAL(6,2)) AS change_vs_prev_year_pp
FROM ry ORDER BY region_code, [year];

-- ------------------------------------------------------------------------------
-- E6. Traffic seasonality (traffic_month_index = month / mean of the region's 12 months)
-- Business question: which months carry the most intercity traffic in each region (summer, Hajj, Ramadan)?
-- Finding (run of 28 Nov 2026): traffic peaks in August (summer travel) in 7 regions, in July in BAH and HAI
--   and in November in MAK, NAJ and EAS; it is lowest in December or January in 8 regions.
--   BAH has the strongest seasonality (July index 1.41 vs December 0.81, ratio 1.74);
--   QAS and EAS are the flattest (1.10).
-- ------------------------------------------------------------------------------
;WITH m AS (
    SELECT region_code, [month], AVG(CAST(traffic_month_index AS FLOAT)) AS idx
    FROM gold.av_readiness_region_month GROUP BY region_code, [month]
), r AS (
    SELECT m.*, RANK() OVER (PARTITION BY region_code ORDER BY idx DESC) AS rk_high,
           RANK() OVER (PARTITION BY region_code ORDER BY idx ASC) AS rk_low
    FROM m
)
SELECT region_code,
       MAX(CASE WHEN rk_high = 1 THEN [month] END) AS peak_month,
       CAST(MAX(CASE WHEN rk_high = 1 THEN idx END) AS DECIMAL(5,3)) AS peak_index,
       MAX(CASE WHEN rk_low = 1 THEN [month] END) AS low_month,
       CAST(MAX(CASE WHEN rk_low = 1 THEN idx END) AS DECIMAL(5,3)) AS low_index,
       CAST(MAX(idx) / MIN(idx) AS DECIMAL(5,2)) AS peak_to_low_ratio
FROM r GROUP BY region_code ORDER BY peak_to_low_ratio DESC;

-- ------------------------------------------------------------------------------
-- E7. Accidents at region-year grain (one row per region-year via MAX)
-- Business question: how do serious-accident and death rates per 100,000 differ by region and move over 2021-2025?
-- Finding (run of 28 Nov 2026): serious-accident rates fall almost everywhere between 2021 and 2025 (e.g. JOF 55.8 -> 17.0, NAJ 73.0 ->
--   26.1 per 100k); RIY rises (44.3 -> 56.1). BAH has the highest serious rate in every year except 2023 (MED)
--   (118.4 in 2021, 86.4 in 2025); TAB has the highest death rate in 2025 (19.4 per 100k), EAS the lowest (7.6). The within / outside-city
--   split exists only from 2024 (outside share 2025: ASR 0.86, JAZ 0.73, RIY 0.21).
-- ------------------------------------------------------------------------------
;WITH ry AS (
    SELECT region_code, [year], MAX(acc_serious_per_100k) AS serious_per_100k, MAX(acc_deaths_per_100k) AS deaths_per_100k,
           MAX(acc_share_outside_cities) AS outside_share, MAX(population_basis) AS population_basis
    FROM gold.av_readiness_region_month GROUP BY region_code, [year]
)
SELECT region_code, [year], serious_per_100k, deaths_per_100k, outside_share, population_basis,
       CAST(serious_per_100k - LAG(serious_per_100k) OVER (PARTITION BY region_code ORDER BY [year]) AS DECIMAL(9,2)) AS serious_change,
       RANK() OVER (PARTITION BY [year] ORDER BY deaths_per_100k DESC) AS death_rate_rank
FROM ry ORDER BY region_code, [year];

-- ------------------------------------------------------------------------------
-- E8. Dr. Omar's comparison, done on comparable numbers
-- Business question: do regions have more serious accidents in their most obscured year (dust + dry haze)
--                    than in their least obscured year? Rates are year-adjusted (region rate / national
--                    rate of the same year) so national trends do not masquerade as weather. 2021-2024 only
--                    (2025 weather ends on 25 Aug: NOAA stopped updating ISD).
-- Finding (run of 28 Nov 2026): 10 of 13 regions have a higher year-adjusted rate in their most obscured year, but the most obscured
--   year is 2022 for 12 of 13 regions, so the comparison is mostly 2022 vs 2023/2024. With the year's mean
--   relative rate removed only 9 of 13 are higher (Wilcoxon p 0.27), and the within-region, year-adjusted
--   Spearman correlation of dust with the relative rate is 0.06 (p 0.68): see docs/reports/04_eda_and_models.md.
--   Dust years and accident years coincide at the national level; they do not line up region by region.
-- ------------------------------------------------------------------------------
;WITH ry AS (
    SELECT region_code, [year], MAX(acc_year_serious) AS serious, MAX(population) AS population,
           AVG(CAST(share_dust_hours + share_haze_dry_hours AS FLOAT)) AS obscured
    FROM gold.av_readiness_region_month WHERE [year] BETWEEN 2021 AND 2024 AND wx_complete = 1
    GROUP BY region_code, [year]
), nat AS (
    SELECT [year], 100000.0 * SUM(serious) / SUM(population) AS national_rate FROM ry GROUP BY [year]
), x AS (
    SELECT ry.*, (100000.0 * ry.serious / ry.population) / nat.national_rate AS rel_rate,
           ROW_NUMBER() OVER (PARTITION BY ry.region_code ORDER BY ry.obscured DESC) AS most,
           ROW_NUMBER() OVER (PARTITION BY ry.region_code ORDER BY ry.obscured ASC) AS least
    FROM ry JOIN nat ON nat.[year] = ry.[year]
)
SELECT region_code,
       MAX(CASE WHEN most = 1 THEN [year] END) AS most_obscured_year,
       CAST(100 * MAX(CASE WHEN most = 1 THEN obscured END) AS DECIMAL(5,2)) AS obscured_pct_most,
       CAST(MAX(CASE WHEN most = 1 THEN rel_rate END) AS DECIMAL(5,3)) AS rel_rate_most,
       MAX(CASE WHEN least = 1 THEN [year] END) AS least_obscured_year,
       CAST(100 * MAX(CASE WHEN least = 1 THEN obscured END) AS DECIMAL(5,2)) AS obscured_pct_least,
       CAST(MAX(CASE WHEN least = 1 THEN rel_rate END) AS DECIMAL(5,3)) AS rel_rate_least,
       CASE WHEN MAX(CASE WHEN most = 1 THEN rel_rate END) > MAX(CASE WHEN least = 1 THEN rel_rate END)
            THEN 'higher in most obscured year' ELSE 'not higher' END AS direction
FROM x GROUP BY region_code ORDER BY region_code;

-- ------------------------------------------------------------------------------
-- E9. Data-quality view
-- Business question: which months must be left out of weather analysis, and why?
-- Finding (run of 28 Nov 2026): 65 region-months are excluded: Aug 2025 for all 13 regions (coverage 76.9-77.0 %: NOAA stopped
--   updating ISD after 24 Aug 2025) and Sep-Dec 2025 for all 13 regions (no ISD data). No other month is below 80 %.
-- ------------------------------------------------------------------------------
SELECT region_code, month_start, wx_hours_observed, wx_coverage_pct,
       CASE WHEN wx_hours_observed IS NULL THEN 'no weather data (NOAA ISD ends 24 Aug 2025 / station gap)'
            ELSE 'coverage below 80 %' END AS reason
FROM gold.av_readiness_region_month
WHERE wx_complete = 0
ORDER BY reason, region_code, month_start;
GO
