-- ==============================================================================
-- Project : AV-Ready-Saudi
-- Script  : 03_gold.sql
-- Purpose : Gold = ONE analytical table, gold.av_readiness_region_month
--           (grain: one Saudi administrative region x one calendar month, 2021-2025).
--           All aggregation happens here (Lab 3: "total by month and region" is Gold).
--
-- How the three data families meet (relations, see docs/05_relations_and_lineage.md):
--   Weather  -> Accidents : same region_code + same year      (both Saudi, observed)
--   Roads    -> Accidents : same region_code + same year      (both GASTAT; road network context)
--   Census   -> Accidents : same region_code + same year      (population -> rates per 100,000)
--   Weather  -> AV events : same condition vocabulary
--                           (normal / rain / fog_haze = fog, haze, mist, visibility < 5 km without
--                            dust / dust = dust or sand reported; day / night by sun position).
--                           Dust and fog/haze are kept apart: Saudi obscured hours are mostly dust,
--                           California's are fog and mist, so a fog risk must not be applied to dust.
--   AV crashes (NHTSA) and disengagements (DMV) are turned into relative risks per
--   condition using US weather from the same places/dates as the exposure; the risks
--   are then applied to each Saudi region-month's own mix of conditions.
--
-- Intermediate tables live in schema prep (allowed on the server); the schema gold
-- holds exactly one table.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

DROP TABLE IF EXISTS prep.weather_station_hour;
DROP TABLE IF EXISTS prep.weather_station_day;
DROP TABLE IF EXISTS prep.saudi_region_month;
DROP TABLE IF EXISTS prep.av_relative_risk;
DROP TABLE IF EXISTS gold.av_readiness_region_month;
GO

-- one row per station per local clock hour (several reports per hour -> one hour)
CREATE TABLE prep.weather_station_hour (
    station_id   CHAR(11)     NOT NULL,
    hour_local   DATETIME2(0) NOT NULL,
    local_date   DATE         NOT NULL,
    n_reports    INT          NOT NULL,
    temp_c       DECIMAL(5,1) NULL,
    temp_max_c   DECIMAL(5,1) NULL,
    wind_max_ms  DECIMAL(5,1) NULL,
    precip_mm    DECIMAL(6,1) NULL,
    is_dust      BIT NOT NULL,
    is_haze      BIT NOT NULL,
    is_fog       BIT NOT NULL,
    is_low_vis   BIT NOT NULL,
    is_obscured  BIT NOT NULL,   -- dust OR haze OR fog OR visibility < 5 km
    is_fog_haze  BIT NOT NULL,   -- obscured hour WITHOUT any dust report (fog, haze/smoke, mist, low visibility)
    is_rain      BIT NOT NULL,
    is_night     BIT NOT NULL,
    hour_bucket  VARCHAR(10) NOT NULL,   -- dust > fog_haze > rain > normal
    PRIMARY KEY (station_id, hour_local)
);

-- one row per station per local day; day_type uses the same vocabulary
CREATE TABLE prep.weather_station_day (
    station_id      CHAR(11) NOT NULL,
    local_date      DATE     NOT NULL,
    hours_observed  INT      NOT NULL,
    dust_hours      INT      NOT NULL,
    fog_haze_hours  INT      NOT NULL,
    obscured_hours  INT      NOT NULL,
    rain_hours      INT      NOT NULL,
    day_type        VARCHAR(10) NOT NULL, -- >=3 obscured hours: dust or fog_haze (whichever has more hours,
                                          -- ties -> dust); else rain (>=1 rain hour); else normal
    PRIMARY KEY (station_id, local_date)
);

CREATE TABLE prep.saudi_region_month (
    region_code     CHAR(3)  NOT NULL,
    station_id      CHAR(11) NOT NULL,
    month_start     DATE     NOT NULL,
    hours_observed  INT, temp_mean_c DECIMAL(5,1), temp_max_c DECIMAL(5,1), wind_max_ms DECIMAL(5,1),
    rain_mm DECIMAL(8,1),
    dust_hours INT, haze_hours INT, fog_hours INT, low_vis_hours INT, obscured_hours INT, fog_haze_hours INT,
    rain_hours INT, normal_hours INT, night_hours INT,
    days_observed INT, dust_days INT, dust_type_days INT, fog_haze_days INT, obscured_days INT,
    rain_days INT, normal_days INT,
    PRIMARY KEY (region_code, month_start)
);

-- relative risk of an AV event under each condition, compared with the reference level
CREATE TABLE prep.av_relative_risk (
    event_source    VARCHAR(20) NOT NULL,   -- nhtsa_crash / dmv_disengagement
    factor          VARCHAR(10) NOT NULL,   -- weather / light
    level           VARCHAR(10) NOT NULL,   -- normal, rain, fog_haze, dust / day, night
    events          INT         NOT NULL,
    event_share     FLOAT       NULL,
    exposure        FLOAT       NULL,       -- weighted hours (crash) or fleet miles (disengagement)
    exposure_share  FLOAT       NULL,
    relative_risk   FLOAT       NULL,       -- reference level (normal / day) = 1
    used_in_index   BIT         NULL,       -- 1 only if the level has >= 30 events (evidence rule)
    PRIMARY KEY (event_source, factor, level)
);

-- THE Gold table
CREATE TABLE gold.av_readiness_region_month (
    region_code                    CHAR(3)       NOT NULL,
    region_name_en                 NVARCHAR(50)  NOT NULL,
    region_name_ar                 NVARCHAR(50)  NOT NULL,
    weather_station_id             CHAR(11)      NOT NULL,
    [year]                         SMALLINT      NOT NULL,
    [month]                        TINYINT       NOT NULL,
    month_start                    DATE          NOT NULL,
    season                         VARCHAR(6)    NOT NULL,
    -- Saudi weather (NOAA hourly, observed)
    wx_hours_observed              INT           NULL,
    wx_hours_in_month              INT           NOT NULL,
    wx_coverage_pct                DECIMAL(5,1)  NULL,
    temp_mean_c                    DECIMAL(5,1)  NULL,
    temp_max_c                     DECIMAL(5,1)  NULL,
    wind_max_ms                    DECIMAL(5,1)  NULL,
    rain_mm                        DECIMAL(8,1)  NULL,
    share_dust_hours               DECIMAL(6,4)  NULL,
    share_haze_hours               DECIMAL(6,4)  NULL,
    share_fog_hours                DECIMAL(6,4)  NULL,
    share_low_vis_hours            DECIMAL(6,4)  NULL,
    share_obscured_hours           DECIMAL(6,4)  NULL,   -- dust + fog/haze
    share_fog_haze_hours           DECIMAL(6,4)  NULL,   -- obscured hours without dust
    share_rain_hours               DECIMAL(6,4)  NULL,
    share_normal_hours             DECIMAL(6,4)  NULL,
    share_night_hours              DECIMAL(6,4)  NULL,
    days_observed                  INT           NULL,
    dust_days                      INT           NULL,   -- days with at least one dust hour
    dust_type_days                 INT           NULL,   -- day type = dust
    fog_haze_days                  INT           NULL,   -- day type = fog_haze
    obscured_days                  INT           NULL,   -- dust_type_days + fog_haze_days
    rain_days                      INT           NULL,
    normal_days                    INT           NULL,
    -- Saudi accidents (GASTAT, annual per region; same value on the 12 months of a year)
    acc_year_serious               INT           NULL,
    acc_year_deaths                INT           NULL,
    acc_year_injuries              INT           NULL,
    acc_year_serious_within_cities INT           NULL,
    acc_year_serious_outside_cities INT          NULL,
    acc_share_outside_cities       DECIMAL(6,4)  NULL,
    -- annual counts are NOT additive over the 12 months of a year: aggregate them with MAX / one row per year
    population                     INT           NULL,   -- GASTAT Census 2022 table (2021, 2022 observed)
    population_basis               VARCHAR(20)   NULL,   -- 'census_year' (2021-2022) / 'census_2022' (2023-2025)
    acc_serious_per_100k           DECIMAL(9,2)  NULL,   -- acc_year_serious / population * 100,000
    acc_deaths_per_100k            DECIMAL(9,2)  NULL,
    acc_injuries_per_100k          DECIMAL(9,2)  NULL,
    -- Saudi road network (GASTAT, per region and year; NULL for 2021: no road tables published for it)
    road_km_per_1000_people        DECIMAL(9,3)  NULL,   -- whole network / population
    road_km_per_km2                DECIMAL(9,4)  NULL,   -- whole network / area
    intercity_road_km              DECIMAL(10,1) NULL,
    intercity_divided_share        DECIMAL(6,4)  NULL,   -- (highway + dual carriageway) / intercity total
    -- AV side (NHTSA crashes + CA DMV disengagements & mileage + US analog weather)
    av_rr_crash_rain               DECIMAL(9,4)  NULL,
    av_rr_crash_fog_haze           DECIMAL(9,4)  NULL,
    av_rr_crash_dust               DECIMAL(9,4)  NULL,   -- NULL: too few AV crashes in dust (evidence rule)
    av_rr_crash_night              DECIMAL(9,4)  NULL,
    av_rr_diseng_rain_day          DECIMAL(9,4)  NULL,
    av_rr_diseng_fog_haze_day      DECIMAL(9,4)  NULL,
    av_rr_diseng_dust_day          DECIMAL(9,4)  NULL,   -- NULL: no dust days in the California AV data
    av_crash_risk_index            DECIMAL(9,4)  NULL,   -- 1 = month with only normal-weather hours
    av_diseng_risk_index           DECIMAL(9,4)  NULL,   -- 1 = all-normal-days month
    -- lineage
    src_weather                    NVARCHAR(200) NOT NULL,
    src_accidents                  NVARCHAR(400) NULL,
    src_av                         NVARCHAR(200) NOT NULL,
    gold_batch_id                  UNIQUEIDENTIFIER NOT NULL,
    gold_loaded_at                 DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_gold_region_month PRIMARY KEY (region_code, month_start)
);
GO

CREATE OR ALTER PROCEDURE gold.load_gold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @batch UNIQUEIDENTIFIER = NEWID(), @t0 DATETIME2 = SYSDATETIME(), @rows BIGINT, @log BIGINT;
    INSERT audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
    VALUES (@batch, 'gold', 'silver.*', 'gold.av_readiness_region_month', @t0, 'RUNNING');
    SET @log = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE prep.weather_station_hour;
        TRUNCATE TABLE prep.weather_station_day;
        TRUNCATE TABLE prep.saudi_region_month;
        TRUNCATE TABLE prep.av_relative_risk;
        TRUNCATE TABLE gold.av_readiness_region_month;

        -------------------------------------------------- 1. station-hour
        INSERT prep.weather_station_hour
        SELECT station_id, h.hour_local, CAST(h.hour_local AS DATE), COUNT(*),
               CAST(AVG(temp_c) AS DECIMAL(5,1)), MAX(temp_c), MAX(wind_ms), MAX(precip_1h_mm),
               MAX(CAST(is_dust AS INT)), MAX(CAST(is_haze AS INT)), MAX(CAST(is_fog AS INT)),
               MAX(CAST(is_low_vis AS INT)),
               MAX(CASE WHEN is_dust = 1 OR is_haze = 1 OR is_fog = 1 OR is_low_vis = 1 THEN 1 ELSE 0 END),
               CASE WHEN MAX(CAST(is_dust AS INT)) = 0
                         AND MAX(CASE WHEN is_haze = 1 OR is_fog = 1 OR is_low_vis = 1 THEN 1 ELSE 0 END) = 1 THEN 1 ELSE 0 END,
               MAX(CAST(is_rain AS INT)),
               CASE WHEN AVG(CAST(is_night AS FLOAT)) >= 0.5 THEN 1 ELSE 0 END,
               CASE WHEN MAX(CAST(is_dust AS INT)) = 1 THEN 'dust'
                    WHEN MAX(CASE WHEN is_haze = 1 OR is_fog = 1 OR is_low_vis = 1 THEN 1 ELSE 0 END) = 1 THEN 'fog_haze'
                    WHEN MAX(CAST(is_rain AS INT)) = 1 THEN 'rain' ELSE 'normal' END
        FROM silver.weather_obs
        CROSS APPLY (SELECT DATEADD(hour, DATEDIFF(hour, CAST('2000-01-01' AS DATETIME2(0)), obs_local),
                                    CAST('2000-01-01' AS DATETIME2(0))) AS hour_local) h
        GROUP BY station_id, h.hour_local;

        -------------------------------------------------- 2. station-day
        INSERT prep.weather_station_day
        SELECT station_id, local_date, COUNT(*), SUM(CAST(is_dust AS INT)), SUM(CAST(is_fog_haze AS INT)),
               SUM(CAST(is_obscured AS INT)), SUM(CAST(is_rain AS INT)),
               CASE WHEN SUM(CAST(is_obscured AS INT)) >= 3
                    THEN CASE WHEN SUM(CAST(is_dust AS INT)) >= SUM(CAST(is_fog_haze AS INT)) THEN 'dust' ELSE 'fog_haze' END
                    WHEN SUM(CAST(is_rain AS INT)) >= 1 THEN 'rain' ELSE 'normal' END
        FROM prep.weather_station_hour
        GROUP BY station_id, local_date;

        -------------------------------------------------- 3. Saudi region-month
        ;WITH hm AS (
            SELECT s.region_code, s.station_id, DATEFROMPARTS(YEAR(h.local_date), MONTH(h.local_date), 1) AS month_start,
                   COUNT(*) AS hours_observed, CAST(AVG(h.temp_c) AS DECIMAL(5,1)) AS temp_mean_c,
                   MAX(h.temp_max_c) AS temp_max_c, MAX(h.wind_max_ms) AS wind_max_ms, SUM(h.precip_mm) AS rain_mm,
                   SUM(CAST(h.is_dust AS INT)) AS dust_hours, SUM(CAST(h.is_haze AS INT)) AS haze_hours,
                   SUM(CAST(h.is_fog AS INT)) AS fog_hours, SUM(CAST(h.is_low_vis AS INT)) AS low_vis_hours,
                   SUM(CAST(h.is_obscured AS INT)) AS obscured_hours,
                   SUM(CAST(h.is_fog_haze AS INT)) AS fog_haze_hours,
                   SUM(CASE WHEN h.hour_bucket = 'rain' THEN 1 ELSE 0 END) AS rain_hours,
                   SUM(CASE WHEN h.hour_bucket = 'normal' THEN 1 ELSE 0 END) AS normal_hours,
                   SUM(CAST(h.is_night AS INT)) AS night_hours
            FROM prep.weather_station_hour h
            JOIN silver.dim_station s ON s.station_id = h.station_id AND s.country = 'SA'
            GROUP BY s.region_code, s.station_id, DATEFROMPARTS(YEAR(h.local_date), MONTH(h.local_date), 1)
        ), dm AS (
            SELECT d.station_id, DATEFROMPARTS(YEAR(d.local_date), MONTH(d.local_date), 1) AS month_start,
                   COUNT(*) AS days_observed,
                   SUM(CASE WHEN d.dust_hours > 0 THEN 1 ELSE 0 END) AS dust_days,
                   SUM(CASE WHEN d.day_type = 'dust' THEN 1 ELSE 0 END) AS dust_type_days,
                   SUM(CASE WHEN d.day_type = 'fog_haze' THEN 1 ELSE 0 END) AS fog_haze_days,
                   SUM(CASE WHEN d.day_type IN ('dust', 'fog_haze') THEN 1 ELSE 0 END) AS obscured_days,
                   SUM(CASE WHEN d.day_type = 'rain' THEN 1 ELSE 0 END) AS rain_days,
                   SUM(CASE WHEN d.day_type = 'normal' THEN 1 ELSE 0 END) AS normal_days
            FROM prep.weather_station_day d
            GROUP BY d.station_id, DATEFROMPARTS(YEAR(d.local_date), MONTH(d.local_date), 1)
        )
        INSERT prep.saudi_region_month
        SELECT hm.region_code, hm.station_id, hm.month_start, hm.hours_observed, hm.temp_mean_c, hm.temp_max_c,
               hm.wind_max_ms, hm.rain_mm, hm.dust_hours, hm.haze_hours, hm.fog_hours, hm.low_vis_hours,
               hm.obscured_hours, hm.fog_haze_hours, hm.rain_hours, hm.normal_hours, hm.night_hours,
               dm.days_observed, dm.dust_days, dm.dust_type_days, dm.fog_haze_days, dm.obscured_days,
               dm.rain_days, dm.normal_days
        FROM hm JOIN dm ON dm.station_id = hm.station_id AND dm.month_start = hm.month_start;

        -------------------------------------------------- 4a. AV crash relative risk (NHTSA x US weather)
        -- exposure = share of hours in each condition at the state's analog station(s),
        -- weighted by where the crashes happened (CA: LAX+SFO, AZ: PHX, TX: AUS)
        ;WITH crash AS (
            SELECT us_state, weather_bucket, is_night FROM silver.nhtsa_crash WHERE in_scope = 1
        ), w_state AS (
            SELECT us_state, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS w
            FROM crash WHERE weather_bucket <> 'unknown' GROUP BY us_state
        ), exp_state AS (
            SELECT s.us_state, h.hour_bucket AS level, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY s.us_state) AS share
            FROM prep.weather_station_hour h JOIN silver.dim_station s ON s.station_id = h.station_id AND s.country = 'US'
            GROUP BY s.us_state, h.hour_bucket
        ), exp_w AS (
            SELECT e.level, SUM(e.share * w.w) AS exposure_share
            FROM exp_state e JOIN w_state w ON w.us_state = e.us_state GROUP BY e.level
        ), ev AS (
            SELECT weather_bucket AS level, COUNT(*) AS events, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS event_share
            FROM crash WHERE weather_bucket <> 'unknown' GROUP BY weather_bucket
        ), lv AS (SELECT level FROM (VALUES ('normal'), ('rain'), ('fog_haze'), ('dust')) v(level))
        INSERT prep.av_relative_risk (event_source, factor, level, events, event_share, exposure, exposure_share, relative_risk)
        SELECT 'nhtsa_crash', 'weather', lv.level, ISNULL(ev.events, 0), ISNULL(ev.event_share, 0), NULL, x.exposure_share,
               (ISNULL(ev.event_share, 0) / NULLIF(x.exposure_share, 0))
             / NULLIF((SELECT e2.event_share / NULLIF(x2.exposure_share, 0)
                       FROM ev e2 JOIN exp_w x2 ON x2.level = e2.level WHERE e2.level = 'normal'), 0)
        FROM lv LEFT JOIN ev ON ev.level = lv.level LEFT JOIN exp_w x ON x.level = lv.level;

        ;WITH crash AS (
            SELECT us_state, CASE WHEN is_night = 1 THEN 'night' ELSE 'day' END AS level
            FROM silver.nhtsa_crash WHERE in_scope = 1 AND is_night IS NOT NULL
        ), w_state AS (
            SELECT us_state, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS w FROM crash GROUP BY us_state
        ), exp_state AS (
            SELECT s.us_state, CASE WHEN h.is_night = 1 THEN 'night' ELSE 'day' END AS level,
                   COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY s.us_state) AS share
            FROM prep.weather_station_hour h JOIN silver.dim_station s ON s.station_id = h.station_id AND s.country = 'US'
            GROUP BY s.us_state, CASE WHEN h.is_night = 1 THEN 'night' ELSE 'day' END
        ), exp_w AS (
            SELECT e.level, SUM(e.share * w.w) AS exposure_share
            FROM exp_state e JOIN w_state w ON w.us_state = e.us_state GROUP BY e.level
        ), ev AS (
            SELECT level, COUNT(*) AS events, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS event_share
            FROM crash GROUP BY level
        )
        INSERT prep.av_relative_risk (event_source, factor, level, events, event_share, exposure, exposure_share, relative_risk)
        SELECT 'nhtsa_crash', 'light', ev.level, ev.events, ev.event_share, NULL, x.exposure_share,
               (ev.event_share / NULLIF(x.exposure_share, 0))
             / NULLIF((SELECT e2.event_share / NULLIF(x2.exposure_share, 0)
                       FROM ev e2 JOIN exp_w x2 ON x2.level = e2.level WHERE e2.level = 'day'), 0)
        FROM ev JOIN exp_w x ON x.level = ev.level;

        -------------------------------------------------- 4b. AV disengagement relative risk (DMV x CA weather)
        -- California day = the worse of LAX and SFO (max hours of each kind over the two stations),
        -- then the same day-type rule as Saudi days; exposure = fleet miles of the month spread evenly over its days
        ;WITH ca_max AS (
            SELECT d.local_date, MAX(d.dust_hours) AS du, MAX(d.fog_haze_hours) AS fh, MAX(d.rain_hours) AS rn
            FROM prep.weather_station_day d
            JOIN silver.dim_station s ON s.station_id = d.station_id AND s.us_state = 'CA'
            GROUP BY d.local_date
        ), ca_day AS (
            SELECT local_date,
                   CASE WHEN du + fh >= 3 THEN CASE WHEN du >= fh THEN 'dust' ELSE 'fog_haze' END
                        WHEN rn >= 1 THEN 'rain' ELSE 'normal' END AS day_type
            FROM ca_max
        ), miles_month AS (
            SELECT month_start, SUM(miles) AS miles FROM silver.dmv_mileage_monthly GROUP BY month_start
        ), day_exp AS (
            SELECT c.local_date, c.day_type,
                   m.miles / DAY(EOMONTH(c.local_date)) AS miles_day
            FROM ca_day c
            JOIN miles_month m ON m.month_start = DATEFROMPARTS(YEAR(c.local_date), MONTH(c.local_date), 1)
        ), dis AS (
            SELECT event_date, COUNT(*) AS n FROM silver.dmv_disengagement GROUP BY event_date
        ), agg AS (
            SELECT e.day_type AS level, SUM(ISNULL(d.n, 0)) AS events, SUM(CAST(e.miles_day AS FLOAT)) AS exposure
            FROM day_exp e LEFT JOIN dis d ON d.event_date = e.local_date
            GROUP BY e.day_type
        ), lv AS (SELECT level FROM (VALUES ('normal'), ('rain'), ('fog_haze'), ('dust')) v(level))
        INSERT prep.av_relative_risk (event_source, factor, level, events, event_share, exposure, exposure_share, relative_risk)
        SELECT 'dmv_disengagement', 'weather', lv.level, ISNULL(a.events, 0),
               ISNULL(a.events, 0) * 1.0 / NULLIF((SELECT SUM(events) FROM agg), 0),
               a.exposure, a.exposure / NULLIF((SELECT SUM(exposure) FROM agg), 0),
               (ISNULL(a.events, 0) / NULLIF(a.exposure, 0))
             / NULLIF((SELECT a2.events / NULLIF(a2.exposure, 0) FROM agg a2 WHERE a2.level = 'normal'), 0)
        FROM lv LEFT JOIN agg a ON a.level = lv.level;

        -- evidence rule: a relative risk is used only when its level has at least 30 events;
        -- otherwise it stays NULL in Gold and the index treats that condition as neutral (1).
        UPDATE prep.av_relative_risk
        SET used_in_index = CASE WHEN events >= 30 AND relative_risk IS NOT NULL THEN 1 ELSE 0 END;

        -------------------------------------------------- 5. Gold: region x month
        DECLARE @rr_c_rain FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='nhtsa_crash' AND factor='weather' AND level='rain' AND used_in_index = 1),
                @rr_c_fh   FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='nhtsa_crash' AND factor='weather' AND level='fog_haze' AND used_in_index = 1),
                @rr_c_dust FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='nhtsa_crash' AND factor='weather' AND level='dust' AND used_in_index = 1),
                @rr_c_ngt  FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='nhtsa_crash' AND factor='light'   AND level='night' AND used_in_index = 1),
                @rr_d_rain FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='dmv_disengagement' AND level='rain' AND used_in_index = 1),
                @rr_d_fh   FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='dmv_disengagement' AND level='fog_haze' AND used_in_index = 1),
                @rr_d_dust FLOAT = (SELECT relative_risk FROM prep.av_relative_risk WHERE event_source='dmv_disengagement' AND level='dust' AND used_in_index = 1);

        ;WITH cal AS (
            SELECT r.region_code, r.region_name_en, r.region_name_ar, s.station_id,
                   DATEFROMPARTS(y.y, m.m, 1) AS month_start, y.y, m.m
            FROM silver.dim_region r
            JOIN silver.dim_station s ON s.region_code = r.region_code
            CROSS JOIN (VALUES (2021),(2022),(2023),(2024),(2025)) y(y)
            CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) m(m)
        ), w AS (
            SELECT p.*, NULLIF(p.hours_observed, 0) * 1.0 AS hrs, NULLIF(p.days_observed, 0) * 1.0 AS dys
            FROM prep.saudi_region_month p
        )
        INSERT gold.av_readiness_region_month (
            region_code, region_name_en, region_name_ar, weather_station_id, [year], [month], month_start, season,
            wx_hours_observed, wx_hours_in_month, wx_coverage_pct, temp_mean_c, temp_max_c, wind_max_ms, rain_mm,
            share_dust_hours, share_haze_hours, share_fog_hours, share_low_vis_hours, share_obscured_hours,
            share_fog_haze_hours, share_rain_hours, share_normal_hours, share_night_hours,
            days_observed, dust_days, dust_type_days, fog_haze_days, obscured_days, rain_days, normal_days,
            acc_year_serious, acc_year_deaths, acc_year_injuries, acc_year_serious_within_cities,
            acc_year_serious_outside_cities, acc_share_outside_cities,
            population, population_basis, acc_serious_per_100k, acc_deaths_per_100k, acc_injuries_per_100k,
            road_km_per_1000_people, road_km_per_km2, intercity_road_km, intercity_divided_share,
            av_rr_crash_rain, av_rr_crash_fog_haze, av_rr_crash_dust, av_rr_crash_night,
            av_rr_diseng_rain_day, av_rr_diseng_fog_haze_day, av_rr_diseng_dust_day,
            av_crash_risk_index, av_diseng_risk_index,
            src_weather, src_accidents, src_av, gold_batch_id)
        SELECT c.region_code, c.region_name_en, c.region_name_ar, c.station_id, c.y, c.m, c.month_start,
               CASE WHEN c.m IN (12,1,2) THEN 'winter' WHEN c.m IN (3,4,5) THEN 'spring'
                    WHEN c.m IN (6,7,8) THEN 'summer' ELSE 'autumn' END,
               w.hours_observed, DAY(EOMONTH(c.month_start)) * 24,
               CAST(100.0 * w.hours_observed / (DAY(EOMONTH(c.month_start)) * 24) AS DECIMAL(5,1)),
               w.temp_mean_c, w.temp_max_c, w.wind_max_ms, w.rain_mm,
               CAST(w.dust_hours / w.hrs AS DECIMAL(6,4)), CAST(w.haze_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.fog_hours / w.hrs AS DECIMAL(6,4)), CAST(w.low_vis_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.obscured_hours / w.hrs AS DECIMAL(6,4)), CAST(w.fog_haze_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.rain_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.normal_hours / w.hrs AS DECIMAL(6,4)), CAST(w.night_hours / w.hrs AS DECIMAL(6,4)),
               w.days_observed, w.dust_days, w.dust_type_days, w.fog_haze_days, w.obscured_days,
               w.rain_days, w.normal_days,
               a.serious_accidents, a.deaths, a.injuries, a.serious_within_cities, a.serious_outside_cities,
               CAST(a.serious_outside_cities * 1.0 / NULLIF(a.serious_within_cities + a.serious_outside_cities, 0) AS DECIMAL(6,4)),
               pop.population, pop.basis,
               CAST(100000.0 * a.serious_accidents / NULLIF(pop.population, 0) AS DECIMAL(9,2)),
               CAST(100000.0 * a.deaths            / NULLIF(pop.population, 0) AS DECIMAL(9,2)),
               CAST(100000.0 * a.injuries          / NULLIF(pop.population, 0) AS DECIMAL(9,2)),
               rd.road_km_per_1000_people, rd.road_km_per_km2, rd.intercity_total_km, rd.intercity_divided_share,
               @rr_c_rain, @rr_c_fh, @rr_c_dust, @rr_c_ngt, @rr_d_rain, @rr_d_fh, @rr_d_dust,
               -- weather part only: the night ratio is kept as a column but not multiplied in,
               -- because its exposure (hours of darkness) is not AV miles driven at night
               -- dust gets its own relative risk only when the AV data has >= 30 dust events;
               -- otherwise it is neutral (1) and its exposure stays visible in share_dust_hours
               CAST( w.normal_hours / w.hrs + w.rain_hours / w.hrs * ISNULL(@rr_c_rain, 1)
                   + w.fog_haze_hours / w.hrs * ISNULL(@rr_c_fh, 1)
                   + (w.obscured_hours - w.fog_haze_hours) / w.hrs * ISNULL(@rr_c_dust, 1) AS DECIMAL(9,4)),
               CAST( w.normal_days / w.dys + w.rain_days / w.dys * ISNULL(@rr_d_rain, 1)
                   + w.fog_haze_days / w.dys * ISNULL(@rr_d_fh, 1)
                   + w.dust_type_days / w.dys * ISNULL(@rr_d_dust, 1) AS DECIMAL(9,4)),
               N'NOAA NCEI Global Hourly station ' + c.station_id,
               a.source_files,
               N'NHTSA SGO ADS crashes; CA DMV disengagements + mileage; NOAA LAX/SFO/PHX/AUS',
               @batch
        FROM cal c
        LEFT JOIN w ON w.region_code = c.region_code AND w.month_start = c.month_start
        LEFT JOIN silver.accidents_region_year a ON a.region_code = c.region_code AND a.data_year = c.y
        LEFT JOIN silver.roads_region_year rd   ON rd.region_code = c.region_code AND rd.data_year = c.y
        -- population of the same year when the census table has it (2021, 2022); otherwise the latest
        -- census count (2022), flagged in population_basis - no projection or interpolation
        OUTER APPLY (SELECT TOP (1) pr.population,
                            CASE WHEN pr.data_year = c.y THEN 'census_year' ELSE 'census_2022' END AS basis
                     FROM silver.population_region_year pr
                     WHERE pr.region_code = c.region_code AND pr.data_year <= c.y
                     ORDER BY pr.data_year DESC) pop;
        SET @rows = @@ROWCOUNT;

        COMMIT;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS' WHERE load_id = @log;
        PRINT CONCAT('  gold.av_readiness_region_month: ', @rows, ' rows');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED', message = LEFT(ERROR_MESSAGE(), 2000) WHERE load_id = @log;
        THROW;
    END CATCH;
END
GO

PRINT 'Gold objects created.';
GO
