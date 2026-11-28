-- ==============================================================================
-- Project : AV-Ready-Saudi
-- Script  : 03_gold.sql
-- Purpose : Gold = ONE analytical table, gold.av_readiness_region_month
--           (grain: one Saudi administrative region x one calendar month, 2021-2025 = 780 rows).
--           All aggregation happens here (Lab 3: "total by month and region" is Gold).
--
-- How the data families meet (relations, see docs/05_relations_and_lineage.md and docs/07_erd.md):
--   Weather    -> Accidents : same region_code + same year      (both Saudi, observed)
--   Traffic    -> Gold      : same region_code + same month     (GASTAT monthly intercity traffic)
--   Roads      -> Accidents : same region_code + same year      (GASTAT road network)
--   Population -> Accidents : same region_code + same year      (rates per 100,000)
--   Service    -> Gold      : same region_code                  (GASTAT 2025 response time, vehicles)
--   Weather    -> AV events : silver.dim_condition (condition vocabulary v2, FK everywhere):
--       dust > haze_dry > fog_moist > rain > normal, identical rules for Saudi and US station-hours.
--       NHTSA crashes are compared with US station-hours of the same state and month, DMV disengagements
--       with California day types (silver.fn_day_type) weighted by DMV fleet miles of the month, both as
--       Mantel-Haenszel relative risks with 95 % CI (prep.av_relative_risk).
--   Evidence rule: a ratio is applied to Saudi months only if it comes from AV crashes, has >= 30 events and
--   its CI lower bound is > 1 (today: NHTSA rain). Dust has no US AV evidence: it is "uncovered".
--
-- Intermediate tables live in schema prep (allowed on the server); the schema gold holds exactly one table.
-- ==============================================================================

USE av_ready_saudi_dw;
GO

DROP TABLE IF EXISTS gold.av_readiness_region_month;
DROP TABLE IF EXISTS prep.av_relative_risk;
DROP TABLE IF EXISTS prep.saudi_region_month;
DROP TABLE IF EXISTS prep.weather_station_day;
DROP TABLE IF EXISTS prep.weather_station_hour;
GO

-- one row per station per local clock hour (several reports per hour -> one hour), v2 condition of the hour
CREATE TABLE prep.weather_station_hour (
    station_id        CHAR(11)     NOT NULL REFERENCES silver.dim_station(station_id),
    hour_local        DATETIME2(0) NOT NULL,
    local_date        DATE         NOT NULL,
    n_reports         INT          NOT NULL,
    temp_c            DECIMAL(5,1) NULL,
    temp_max_c        DECIMAL(5,1) NULL,
    wind_max_ms       DECIMAL(5,1) NULL,
    precip_mm         DECIMAL(6,1) NULL,
    dew_spread_c      FLOAT        NULL,   -- mean temperature - dew point of the hour's reports
    min_dew_spread_c  DECIMAL(5,1) NULL,   -- smallest spread in the hour (fog_moist rule)
    is_dust           BIT NOT NULL,
    is_haze           BIT NOT NULL,
    is_fog            BIT NOT NULL,
    is_low_vis        BIT NOT NULL,
    is_obscured       BIT NOT NULL,        -- dust OR haze OR fog OR visibility < 5 km
    is_fog_moist      BIT NOT NULL,        -- obscured, no dust, (fog code OR min spread <= 2.5 degC)
    is_haze_dry       BIT NOT NULL,        -- obscured, no dust, not fog_moist
    is_rain           BIT NOT NULL,        -- precipitation reported (raw flag; bucket rain only if not obscured)
    is_night          BIT NOT NULL,
    is_hot40          BIT NOT NULL,        -- a report >= 40 degC in the hour
    is_hot45          BIT NOT NULL,
    hour_bucket       VARCHAR(25)  NOT NULL REFERENCES silver.dim_condition(condition_code),
    PRIMARY KEY (station_id, hour_local)
);

-- one row per station per local day; day_type from silver.fn_day_type (the single day rule)
CREATE TABLE prep.weather_station_day (
    station_id       CHAR(11) NOT NULL REFERENCES silver.dim_station(station_id),
    local_date       DATE     NOT NULL,
    hours_observed   INT      NOT NULL,
    dust_hours       INT      NOT NULL,
    haze_dry_hours   INT      NOT NULL,
    fog_moist_hours  INT      NOT NULL,
    rain_hours       INT      NOT NULL,
    normal_hours     INT      NOT NULL,
    obscured_hours   INT      NOT NULL,
    day_type         VARCHAR(25) NOT NULL REFERENCES silver.dim_condition(condition_code),
    PRIMARY KEY (station_id, local_date)
);

CREATE TABLE prep.saudi_region_month (
    region_code       CHAR(3)  NOT NULL REFERENCES silver.dim_region(region_code),
    station_id        CHAR(11) NOT NULL REFERENCES silver.dim_station(station_id),
    month_start       DATE     NOT NULL,
    hours_observed    INT, temp_mean_c DECIMAL(5,1), temp_max_c DECIMAL(5,1), wind_max_ms DECIMAL(5,1),
    mean_dew_spread_c FLOAT,
    dust_hours INT, haze_dry_hours INT, fog_moist_hours INT, rain_hours INT, normal_hours INT,
    haze_hours INT, fog_hours INT, low_vis_hours INT, night_hours INT, hot40_hours INT, hot45_hours INT,
    days_observed INT, dust_days INT, dust_type_days INT, haze_dry_days INT, fog_moist_days INT,
    rain_days INT, normal_days INT,
    PRIMARY KEY (region_code, month_start)
);

-- relative risk of an AV event under each condition vs the reference level, stratified (Mantel-Haenszel)
CREATE TABLE prep.av_relative_risk (
    event_source    VARCHAR(20)  NOT NULL,   -- nhtsa_crash / dmv_disengagement
    factor          VARCHAR(10)  NOT NULL,   -- weather / light
    condition_code  VARCHAR(25)  NOT NULL REFERENCES silver.dim_condition(condition_code),
    events          INT          NOT NULL,
    exposure        FLOAT        NULL,       -- station-hours (crashes) or DMV fleet miles (disengagements)
    rr_crude        FLOAT        NULL,       -- pooled ratio, no stratification (the pre-v2 number)
    rr_adjusted     FLOAT        NULL,       -- Mantel-Haenszel rate ratio over the strata
    ci_low          FLOAT        NULL,       -- 95 % CI, Greenland-Robins variance x max(1, dispersion)
    ci_high         FLOAT        NULL,
    n_strata        INT          NOT NULL,
    dispersion      FLOAT        NULL,       -- Pearson chi2 / df of the fitted stratified model (overdispersion)
    adjustment      VARCHAR(40)  NOT NULL,
    used_in_index   BIT          NOT NULL,
    evidence_note   VARCHAR(120) NOT NULL,
    PRIMARY KEY (event_source, factor, condition_code)
);

-- THE Gold table
CREATE TABLE gold.av_readiness_region_month (
    region_code                     CHAR(3)       NOT NULL REFERENCES silver.dim_region(region_code),
    region_name_en                  NVARCHAR(50)  NOT NULL,
    region_name_ar                  NVARCHAR(50)  NOT NULL,
    weather_station_id              CHAR(11)      NOT NULL REFERENCES silver.dim_station(station_id),
    [year]                          SMALLINT      NOT NULL,
    [month]                         TINYINT       NOT NULL,
    month_start                     DATE          NOT NULL,
    season                          VARCHAR(6)    NOT NULL,
    -- Saudi weather (NOAA hourly, observed)
    wx_hours_observed               INT           NULL,
    wx_hours_in_month               INT           NOT NULL,
    wx_coverage_pct                 DECIMAL(5,1)  NULL,
    wx_complete                     BIT           NOT NULL,   -- weather present and coverage >= 80 %
    temp_mean_c                     DECIMAL(5,1)  NULL,
    temp_max_c                      DECIMAL(5,1)  NULL,
    wind_max_ms                     DECIMAL(5,1)  NULL,
    mean_dew_spread_c               DECIMAL(5,1)  NULL,   -- temperature - dew point (small = moist)
    -- (no rain_mm: the Saudi stations publish no 1-hour precipitation totals, only 12-hour ones -> it was 0 on every row)
    -- v2 hour shares (the five sum to 1)
    share_normal_hours              DECIMAL(6,4)  NULL,
    share_rain_hours                DECIMAL(6,4)  NULL,
    share_fog_moist_hours           DECIMAL(6,4)  NULL,
    share_haze_dry_hours            DECIMAL(6,4)  NULL,
    share_dust_hours                DECIMAL(6,4)  NULL,
    -- raw flags (not exclusive)
    share_haze_hours                DECIMAL(6,4)  NULL,
    share_fog_hours                 DECIMAL(6,4)  NULL,
    share_low_vis_hours             DECIMAL(6,4)  NULL,
    share_night_hours               DECIMAL(6,4)  NULL,
    share_hot40_hours               DECIMAL(6,4)  NULL,
    share_hot45_hours               DECIMAL(6,4)  NULL,
    -- v2 day types (silver.fn_day_type)
    days_observed                   INT           NULL,
    dust_days                       INT           NULL,   -- days with at least one dust hour
    dust_type_days                  INT           NULL,
    haze_dry_days                   INT           NULL,
    fog_moist_days                  INT           NULL,
    rain_days                       INT           NULL,
    normal_days                     INT           NULL,
    -- Saudi monthly intercity traffic (GASTAT)
    traffic_adt_per_point           DECIMAL(12,1) NULL,
    traffic_definition              VARCHAR(40)   NULL,
    traffic_month_index             DECIMAL(6,3)  NULL,   -- month / mean of the region's 12 months (comparable)
    -- Saudi accidents (GASTAT, annual per region; same value on the 12 months of a year)
    acc_year_serious                INT           NULL,
    acc_year_deaths                 INT           NULL,
    acc_year_injuries               INT           NULL,
    acc_year_serious_within_cities  INT           NULL,
    acc_year_serious_outside_cities INT           NULL,
    acc_share_outside_cities        DECIMAL(6,4)  NULL,
    -- annual counts are NOT additive over the 12 months of a year: aggregate them with MAX / one row per year
    population                      INT           NULL,   -- same year: census table (2021-2022) / GASTAT rate-implied (2023-2025)
    population_basis                VARCHAR(30)   NULL,
    acc_serious_per_100k            DECIMAL(9,2)  NULL,
    acc_deaths_per_100k             DECIMAL(9,2)  NULL,
    acc_injuries_per_100k           DECIMAL(9,2)  NULL,
    -- Saudi road network (GASTAT, per region and year; NULL for 2021: no road tables published for it)
    road_km_per_1000_people         DECIMAL(9,3)  NULL,
    road_km_per_km2                 DECIMAL(9,4)  NULL,
    intercity_road_km               DECIMAL(10,1) NULL,
    intercity_divided_share         DECIMAL(6,4)  NULL,
    -- region service (GASTAT 2025, same value on every row of a region)
    response_within_s               INT           NULL,
    response_outside_s              INT           NULL,
    registered_vehicles_2025        BIGINT        NULL,
    -- AV-derived measures (NHTSA crashes + CA DMV disengagements & mileage + US analog weather; vary by row)
    av_uncovered_share              DECIMAL(9,6)  NULL,   -- share of hours without US AV evidence (dust)
    av_uncovered_share_cons         DECIMAL(9,6)  NULL,   -- conservative: dust + dry haze
    av_crash_multiplier             DECIMAL(9,6)  NULL,   -- 1 + sum over used conditions of share x (RR - 1)
    env_readiness                   DECIMAL(9,6)  NULL,   -- sum share x weight (dust 0, used 1/RR, covered 1)
    env_readiness_cons              DECIMAL(9,6)  NULL,   -- same with dry haze weight 0
    -- lineage
    src_weather                     NVARCHAR(200) NOT NULL,
    src_accidents                   NVARCHAR(400) NULL,
    src_traffic                     NVARCHAR(200) NULL,
    src_av                          NVARCHAR(200) NOT NULL,
    gold_batch_id                   UNIQUEIDENTIFIER NOT NULL,
    gold_loaded_at                  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
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
        -- children before parents (FK order inside prep / gold)
        DELETE FROM gold.av_readiness_region_month;
        DELETE FROM prep.av_relative_risk;
        DELETE FROM prep.saudi_region_month;
        DELETE FROM prep.weather_station_day;
        DELETE FROM prep.weather_station_hour;

        -------------------------------------------------- 1. station-hour (v2 vocabulary)
        ;WITH h AS (
            SELECT station_id, hl.hour_local, COUNT(*) AS n_reports,
                   CAST(AVG(temp_c) AS DECIMAL(5,1)) AS temp_c, MAX(temp_c) AS temp_max_c, MAX(wind_ms) AS wind_max_ms,
                   MAX(precip_1h_mm) AS precip_mm,
                   AVG(CAST(dew_spread_c AS FLOAT)) AS dew_spread_c, MIN(dew_spread_c) AS min_dew_spread_c,
                   MAX(CAST(is_dust AS INT)) AS dust, MAX(CAST(is_haze AS INT)) AS haze, MAX(CAST(is_fog AS INT)) AS fog,
                   MAX(CAST(is_low_vis AS INT)) AS low_vis,
                   MAX(CASE WHEN is_dust = 1 OR is_haze = 1 OR is_fog = 1 OR is_low_vis = 1 THEN 1 ELSE 0 END) AS obscured,
                   MAX(CAST(is_rain AS INT)) AS rain,
                   CASE WHEN AVG(CAST(is_night AS FLOAT)) >= 0.5 THEN 1 ELSE 0 END AS night,
                   MAX(CAST(is_hot40 AS INT)) AS hot40, MAX(CAST(is_hot45 AS INT)) AS hot45
            FROM silver.weather_obs
            CROSS APPLY (SELECT DATEADD(hour, DATEDIFF(hour, CAST('2000-01-01' AS DATETIME2(0)), obs_local),
                                        CAST('2000-01-01' AS DATETIME2(0))) AS hour_local) hl
            GROUP BY station_id, hl.hour_local
        ), v AS (
            -- fog_moist: obscured, no dust, and a fog code or a near-saturated hour (spread <= 2.5 degC)
            SELECT h.*,
                   CASE WHEN obscured = 1 AND dust = 0 AND (fog = 1 OR min_dew_spread_c <= 2.5) THEN 1 ELSE 0 END AS fog_moist
            FROM h
        )
        INSERT prep.weather_station_hour (station_id, hour_local, local_date, n_reports, temp_c, temp_max_c,
               wind_max_ms, precip_mm, dew_spread_c, min_dew_spread_c, is_dust, is_haze, is_fog, is_low_vis,
               is_obscured, is_fog_moist, is_haze_dry, is_rain, is_night, is_hot40, is_hot45, hour_bucket)
        SELECT station_id, hour_local, CAST(hour_local AS DATE), n_reports, temp_c, temp_max_c, wind_max_ms, precip_mm,
               dew_spread_c, min_dew_spread_c, dust, haze, fog, low_vis, obscured, fog_moist,
               CASE WHEN obscured = 1 AND dust = 0 AND fog_moist = 0 THEN 1 ELSE 0 END,
               rain, night, hot40, hot45,
               -- priority dust > haze_dry > fog_moist > rain > normal (silver.dim_condition.priority)
               CASE WHEN dust = 1 THEN 'dust'
                    WHEN obscured = 1 AND fog_moist = 0 THEN 'haze_dry'
                    WHEN fog_moist = 1 THEN 'fog_moist'
                    WHEN rain = 1 THEN 'rain' ELSE 'normal' END
        FROM v;

        -------------------------------------------------- 2. station-day (hours per v2 bucket, then silver.fn_day_type)
        ;WITH d AS (
            SELECT station_id, local_date, COUNT(*) AS hours_observed,
                   SUM(CASE WHEN hour_bucket = 'dust'      THEN 1 ELSE 0 END) AS dust,
                   SUM(CASE WHEN hour_bucket = 'haze_dry'  THEN 1 ELSE 0 END) AS haze_dry,
                   SUM(CASE WHEN hour_bucket = 'fog_moist' THEN 1 ELSE 0 END) AS fog_moist,
                   SUM(CASE WHEN hour_bucket = 'rain'      THEN 1 ELSE 0 END) AS rain,
                   SUM(CASE WHEN hour_bucket = 'normal'    THEN 1 ELSE 0 END) AS normal,
                   SUM(CAST(is_obscured AS INT)) AS obscured
            FROM prep.weather_station_hour
            GROUP BY station_id, local_date
        )
        INSERT prep.weather_station_day (station_id, local_date, hours_observed, dust_hours, haze_dry_hours,
               fog_moist_hours, rain_hours, normal_hours, obscured_hours, day_type)
        SELECT station_id, local_date, hours_observed, dust, haze_dry, fog_moist, rain, normal, obscured,
               silver.fn_day_type(dust, haze_dry, fog_moist, rain)
        FROM d;

        -------------------------------------------------- 3. Saudi region-month
        ;WITH hm AS (
            SELECT s.region_code, s.station_id, DATEFROMPARTS(YEAR(h.local_date), MONTH(h.local_date), 1) AS month_start,
                   COUNT(*) AS hours_observed, CAST(AVG(h.temp_c) AS DECIMAL(5,1)) AS temp_mean_c,
                   MAX(h.temp_max_c) AS temp_max_c, MAX(h.wind_max_ms) AS wind_max_ms,
                   AVG(h.dew_spread_c) AS mean_dew_spread_c,
                   SUM(CASE WHEN h.hour_bucket = 'dust'      THEN 1 ELSE 0 END) AS dust_hours,
                   SUM(CASE WHEN h.hour_bucket = 'haze_dry'  THEN 1 ELSE 0 END) AS haze_dry_hours,
                   SUM(CASE WHEN h.hour_bucket = 'fog_moist' THEN 1 ELSE 0 END) AS fog_moist_hours,
                   SUM(CASE WHEN h.hour_bucket = 'rain'      THEN 1 ELSE 0 END) AS rain_hours,
                   SUM(CASE WHEN h.hour_bucket = 'normal'    THEN 1 ELSE 0 END) AS normal_hours,
                   SUM(CAST(h.is_haze AS INT)) AS haze_hours, SUM(CAST(h.is_fog AS INT)) AS fog_hours,
                   SUM(CAST(h.is_low_vis AS INT)) AS low_vis_hours, SUM(CAST(h.is_night AS INT)) AS night_hours,
                   SUM(CAST(h.is_hot40 AS INT)) AS hot40_hours, SUM(CAST(h.is_hot45 AS INT)) AS hot45_hours
            FROM prep.weather_station_hour h
            JOIN silver.dim_station s ON s.station_id = h.station_id AND s.country = 'SA'
            GROUP BY s.region_code, s.station_id, DATEFROMPARTS(YEAR(h.local_date), MONTH(h.local_date), 1)
        ), dm AS (
            SELECT d.station_id, DATEFROMPARTS(YEAR(d.local_date), MONTH(d.local_date), 1) AS month_start,
                   COUNT(*) AS days_observed,
                   SUM(CASE WHEN d.dust_hours > 0 THEN 1 ELSE 0 END) AS dust_days,
                   SUM(CASE WHEN d.day_type = 'dust'      THEN 1 ELSE 0 END) AS dust_type_days,
                   SUM(CASE WHEN d.day_type = 'haze_dry'  THEN 1 ELSE 0 END) AS haze_dry_days,
                   SUM(CASE WHEN d.day_type = 'fog_moist' THEN 1 ELSE 0 END) AS fog_moist_days,
                   SUM(CASE WHEN d.day_type = 'rain'      THEN 1 ELSE 0 END) AS rain_days,
                   SUM(CASE WHEN d.day_type = 'normal'    THEN 1 ELSE 0 END) AS normal_days
            FROM prep.weather_station_day d
            GROUP BY d.station_id, DATEFROMPARTS(YEAR(d.local_date), MONTH(d.local_date), 1)
        )
        INSERT prep.saudi_region_month
        SELECT hm.region_code, hm.station_id, hm.month_start, hm.hours_observed, hm.temp_mean_c, hm.temp_max_c,
               hm.wind_max_ms, hm.mean_dew_spread_c,
               hm.dust_hours, hm.haze_dry_hours, hm.fog_moist_hours, hm.rain_hours, hm.normal_hours,
               hm.haze_hours, hm.fog_hours, hm.low_vis_hours, hm.night_hours, hm.hot40_hours, hm.hot45_hours,
               dm.days_observed, dm.dust_days, dm.dust_type_days, dm.haze_dry_days, dm.fog_moist_days,
               dm.rain_days, dm.normal_days
        FROM hm JOIN dm ON dm.station_id = hm.station_id AND dm.month_start = hm.month_start;

        -------------------------------------------------- 4. AV evidence: stratified relative risks
        -- Observation units (#u): NHTSA = stratum (state x incident month, strata with >= 1 crash) x level,
        -- with station-hours of that state and month (CA = LAX + SFO); DMV = one California day, with
        -- person-time = that month's DMV fleet miles / days in month (this is how mileage contributes).
        CREATE TABLE #lv (event_source VARCHAR(20), factor VARCHAR(10), lvl VARCHAR(25), is_ref BIT, adjustment VARCHAR(40));
        INSERT #lv VALUES
         ('nhtsa_crash', 'weather', 'normal', 1, 'MH: state x incident month'),
         ('nhtsa_crash', 'weather', 'rain', 0, 'MH: state x incident month'),
         ('nhtsa_crash', 'weather', 'obscured_unspecified', 0, 'MH: state x incident month'),
         ('nhtsa_crash', 'weather', 'dust', 0, 'MH: state x incident month'),
         ('nhtsa_crash', 'light', 'day', 1, 'MH: state x incident month'),
         ('nhtsa_crash', 'light', 'night', 0, 'MH: state x incident month'),
         ('dmv_disengagement', 'weather', 'normal', 1, 'MH: month x weekday class'),
         ('dmv_disengagement', 'weather', 'rain', 0, 'MH: month x weekday class'),
         ('dmv_disengagement', 'weather', 'fog_moist', 0, 'MH: month x weekday class'),
         ('dmv_disengagement', 'weather', 'haze_dry', 0, 'MH: month x weekday class'),
         ('dmv_disengagement', 'weather', 'dust', 0, 'MH: month x weekday class');
        CREATE TABLE #u (event_source VARCHAR(20), factor VARCHAR(10), stratum VARCHAR(40), lvl VARCHAR(25),
                         e FLOAT, t FLOAT);

        -- US station-hours per state x local month x NHTSA category / light
        SELECT s.us_state, DATEFROMPARTS(YEAR(h.local_date), MONTH(h.local_date), 1) AS month_start,
               CASE WHEN h.hour_bucket IN ('fog_moist', 'haze_dry') THEN 'obscured_unspecified' ELSE h.hour_bucket END AS cond,
               CASE WHEN h.is_night = 1 THEN 'night' ELSE 'day' END AS light
        INTO #ush
        FROM prep.weather_station_hour h
        JOIN silver.dim_station s ON s.station_id = h.station_id AND s.country = 'US';

        -- NHTSA, weather
        ;WITH ev AS (
            SELECT us_state, incident_month AS month_start, weather_bucket AS lvl, COUNT(*) AS e
            FROM silver.nhtsa_crash WHERE in_scope = 1 AND weather_bucket <> 'unknown'
            GROUP BY us_state, incident_month, weather_bucket
        ), st AS (SELECT DISTINCT us_state, month_start FROM ev),
        hr AS (SELECT us_state, month_start, cond AS lvl, COUNT(*) AS t FROM #ush GROUP BY us_state, month_start, cond)
        INSERT #u
        SELECT 'nhtsa_crash', 'weather', CONCAT(st.us_state, ' ', CONVERT(CHAR(7), st.month_start, 120)), l.lvl,
               ISNULL(ev.e, 0), ISNULL(hr.t, 0)
        FROM st CROSS JOIN #lv l
        LEFT JOIN ev ON ev.us_state = st.us_state AND ev.month_start = st.month_start AND ev.lvl = l.lvl
        LEFT JOIN hr ON hr.us_state = st.us_state AND hr.month_start = st.month_start AND hr.lvl = l.lvl
        WHERE l.event_source = 'nhtsa_crash' AND l.factor = 'weather';

        -- NHTSA, light (exposure = darkness hours, not AV miles at night: kept for the table, never used)
        ;WITH ev AS (
            SELECT us_state, incident_month AS month_start, CASE WHEN is_night = 1 THEN 'night' ELSE 'day' END AS lvl,
                   COUNT(*) AS e
            FROM silver.nhtsa_crash WHERE in_scope = 1 AND is_night IS NOT NULL
            GROUP BY us_state, incident_month, CASE WHEN is_night = 1 THEN 'night' ELSE 'day' END
        ), st AS (SELECT DISTINCT us_state, month_start FROM ev),
        hr AS (SELECT us_state, month_start, light AS lvl, COUNT(*) AS t FROM #ush GROUP BY us_state, month_start, light)
        INSERT #u
        SELECT 'nhtsa_crash', 'light', CONCAT(st.us_state, ' ', CONVERT(CHAR(7), st.month_start, 120)), l.lvl,
               ISNULL(ev.e, 0), ISNULL(hr.t, 0)
        FROM st CROSS JOIN #lv l
        LEFT JOIN ev ON ev.us_state = st.us_state AND ev.month_start = st.month_start AND ev.lvl = l.lvl
        LEFT JOIN hr ON hr.us_state = st.us_state AND hr.month_start = st.month_start AND hr.lvl = l.lvl
        WHERE l.event_source = 'nhtsa_crash' AND l.factor = 'light';

        -- DMV: California day = max hours of each kind over LAX and SFO, then the same day rule as Saudi days
        ;WITH ca_day AS (
            SELECT d.local_date,
                   silver.fn_day_type(MAX(d.dust_hours), MAX(d.haze_dry_hours), MAX(d.fog_moist_hours), MAX(d.rain_hours)) AS day_type
            FROM prep.weather_station_day d
            JOIN silver.dim_station s ON s.station_id = d.station_id AND s.us_state = 'CA'
            GROUP BY d.local_date
        ), mm AS (
            SELECT month_start, SUM(miles) AS miles FROM silver.dmv_mileage_monthly
            GROUP BY month_start HAVING SUM(miles) > 0
        ), dis AS (
            SELECT event_date, COUNT(*) AS n FROM silver.dmv_disengagement GROUP BY event_date
        )
        INSERT #u
        SELECT 'dmv_disengagement', 'weather',
               -- weekday class without DATEFIRST: day 0 = 1900-01-01 = Monday, so 5 and 6 are Sat and Sun
               CONCAT(CONVERT(CHAR(7), m.month_start, 120), IIF(DATEDIFF(day, '19000101', c.local_date) % 7 >= 5, ' Sat-Sun', ' Mon-Fri')),
               c.day_type, ISNULL(d.n, 0), CAST(m.miles AS FLOAT) / DAY(EOMONTH(c.local_date))
        FROM ca_day c
        JOIN mm m ON m.month_start = DATEFROMPARTS(YEAR(c.local_date), MONTH(c.local_date), 1)
        LEFT JOIN dis d ON d.event_date = c.local_date;

        -- Mantel-Haenszel per level vs the reference level of its source/factor:
        --   RR = sum(e_c T_n / T) / sum(e_n T_c / T),  Var(ln RR) = sum((e_c + e_n) T_c T_n / T^2) / (R S)
        SELECT event_source, factor, stratum, lvl, SUM(e) AS e, SUM(t) AS t
        INTO #cell FROM #u GROUP BY event_source, factor, stratum, lvl;

        ;WITH n AS (
            SELECT c.* FROM #cell c
            JOIN #lv l ON l.event_source = c.event_source AND l.factor = c.factor AND l.lvl = c.lvl AND l.is_ref = 1
        ), pr AS (
            SELECT c.event_source, c.factor, c.lvl, c.e, c.t, n.e AS e_n, n.t AS t_n, c.t + n.t AS tt
            FROM #cell c JOIN n ON n.event_source = c.event_source AND n.factor = c.factor AND n.stratum = c.stratum
        )
        SELECT event_source, factor, lvl,
               SUM(CASE WHEN tt > 0 THEN e * t_n / tt END)               AS R,
               SUM(CASE WHEN tt > 0 THEN e_n * t / tt END)               AS S,
               SUM(CASE WHEN tt > 0 THEN (e + e_n) * t * t_n / (tt * tt) END) AS V
        INTO #mh FROM pr GROUP BY event_source, factor, lvl;

        SELECT l.event_source, l.factor, l.lvl, l.is_ref, l.adjustment,
               ISNULL(tot.e, 0) AS events, ISNULL(tot.t, 0) AS exposure, k.n_strata, m.R, m.S, m.V,
               CASE WHEN l.is_ref = 1 THEN 1.0 ELSE m.R / NULLIF(m.S, 0) END AS rr
        INTO #rr
        FROM #lv l
        LEFT JOIN (SELECT event_source, factor, lvl, SUM(e) AS e, SUM(t) AS t FROM #cell GROUP BY event_source, factor, lvl) tot
               ON tot.event_source = l.event_source AND tot.factor = l.factor AND tot.lvl = l.lvl
        LEFT JOIN (SELECT event_source, factor, COUNT(DISTINCT stratum) AS n_strata FROM #cell GROUP BY event_source, factor) k
               ON k.event_source = l.event_source AND k.factor = l.factor
        LEFT JOIN #mh m ON m.event_source = l.event_source AND m.factor = l.factor AND m.lvl = l.lvl;

        -- Overdispersion: Pearson chi2 / df of the fitted stratified model on the observation units,
        -- fitted = t x RR(level) x lambda(stratum), lambda = sum e / sum t RR in the stratum (units with fitted > 0).
        -- The CI variance is multiplied by max(1, dispersion) (quasi-Poisson correction).
        ;WITH uu AS (
            SELECT u.event_source, u.factor, u.stratum, u.e, u.t * ISNULL(r.rr, 0) AS tr
            FROM #u u LEFT JOIN #rr r ON r.event_source = u.event_source AND r.factor = u.factor AND r.lvl = u.lvl
        ), lam AS (
            SELECT event_source, factor, stratum, SUM(e) / NULLIF(SUM(tr), 0) AS lam
            FROM uu GROUP BY event_source, factor, stratum
        ), fit AS (
            SELECT uu.event_source, uu.factor, uu.stratum, uu.e, uu.tr * lam.lam AS fitted
            FROM uu JOIN lam ON lam.event_source = uu.event_source AND lam.factor = uu.factor AND lam.stratum = uu.stratum
        ), p AS (
            SELECT event_source, factor, COUNT(*) AS p FROM #rr WHERE is_ref = 0 AND rr > 0 GROUP BY event_source, factor
        )
        SELECT f.event_source, f.factor,
               SUM(SQUARE(f.e - f.fitted) / f.fitted) / NULLIF(COUNT(*) - COUNT(DISTINCT f.stratum) - MAX(ISNULL(p.p, 0)), 0) AS phi
        INTO #phi
        FROM fit f LEFT JOIN p ON p.event_source = f.event_source AND p.factor = f.factor
        WHERE f.fitted > 0
        GROUP BY f.event_source, f.factor;

        -- crude NHTSA ratio (the pre-v2 pooled number): event share / exposure share, the exposure share of each
        -- state weighted by that state's share of the crashes; reference level = 1
        ;WITH c AS (
            SELECT 'weather' AS factor, us_state, weather_bucket AS lvl FROM silver.nhtsa_crash
            WHERE in_scope = 1 AND weather_bucket <> 'unknown'
            UNION ALL
            SELECT 'light', us_state, CASE WHEN is_night = 1 THEN 'night' ELSE 'day' END FROM silver.nhtsa_crash
            WHERE in_scope = 1 AND is_night IS NOT NULL
        ), w AS (
            SELECT factor, us_state, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY factor) AS w FROM c GROUP BY factor, us_state
        ), es AS (
            SELECT 'weather' AS factor, us_state, cond AS lvl, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY us_state) AS share
            FROM #ush GROUP BY us_state, cond
            UNION ALL
            SELECT 'light', us_state, light, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY us_state)
            FROM #ush GROUP BY us_state, light
        ), ex AS (
            SELECT es.factor, es.lvl, SUM(es.share * w.w) AS exposure_share
            FROM es JOIN w ON w.factor = es.factor AND w.us_state = es.us_state GROUP BY es.factor, es.lvl
        ), ev AS (
            SELECT factor, lvl, COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (PARTITION BY factor) AS event_share
            FROM c GROUP BY factor, lvl
        ), ratio AS (
            SELECT ex.factor, ex.lvl, ISNULL(ev.event_share, 0) / NULLIF(ex.exposure_share, 0) AS r
            FROM ex LEFT JOIN ev ON ev.factor = ex.factor AND ev.lvl = ex.lvl
        )
        SELECT r.factor, r.lvl, r.r / NULLIF(b.r, 0) AS rr_crude
        INTO #crude_n
        FROM ratio r JOIN ratio b ON b.factor = r.factor AND b.lvl = CASE r.factor WHEN 'weather' THEN 'normal' ELSE 'day' END;

        INSERT prep.av_relative_risk (event_source, factor, condition_code, events, exposure, rr_crude, rr_adjusted,
               ci_low, ci_high, n_strata, dispersion, adjustment, used_in_index, evidence_note)
        SELECT r.event_source, r.factor, r.lvl, CAST(r.events AS INT), r.exposure,
               CASE WHEN r.event_source = 'nhtsa_crash' THEN cn.rr_crude
                    ELSE (r.events / NULLIF(r.exposure, 0)) / NULLIF(dref.events / NULLIF(dref.exposure, 0), 0) END,
               r.rr, ci.lo, ci.hi, ISNULL(r.n_strata, 0), ph.phi, r.adjustment, 0, ''
        FROM #rr r
        LEFT JOIN #phi ph ON ph.event_source = r.event_source AND ph.factor = r.factor
        LEFT JOIN #crude_n cn ON r.event_source = 'nhtsa_crash' AND cn.factor = r.factor AND cn.lvl = r.lvl
        LEFT JOIN #rr dref ON r.event_source = 'dmv_disengagement' AND dref.event_source = r.event_source
                          AND dref.factor = r.factor AND dref.is_ref = 1
        OUTER APPLY (SELECT CASE WHEN r.is_ref = 0 AND r.R > 0 AND r.S > 0
                                 THEN SQRT(r.V / (r.R * r.S) * IIF(ISNULL(ph.phi, 1) > 1, ph.phi, 1)) END AS se) s
        OUTER APPLY (SELECT EXP(LOG(NULLIF(r.rr, 0)) - 1.96 * s.se) AS lo, EXP(LOG(NULLIF(r.rr, 0)) + 1.96 * s.se) AS hi) ci;

        -- Evidence rule (agreed with Ali, 27 Nov 2026): a ratio is applied in Gold only if it comes from AV
        -- crashes (a safety outcome), has >= 30 events and its 95 % CI lower bound is > 1. A significant
        -- disengagement ratio (precautionary takeover; 42 % of them from one company) is reported, not applied.
        UPDATE prep.av_relative_risk
        SET used_in_index = CASE WHEN factor = 'weather' AND condition_code <> 'normal' AND events >= 30
                                      AND ci_low > 1 AND event_source = 'nhtsa_crash' THEN 1 ELSE 0 END,
            evidence_note = CASE
                WHEN factor = 'light' AND condition_code = 'day' THEN 'reference level'
                WHEN factor = 'light' THEN 'exposure is darkness hours, not AV miles - not used'
                WHEN condition_code = 'normal' THEN 'reference level'
                WHEN events = 0 THEN 'no events - uncovered'
                WHEN events >= 30 AND ci_low > 1 AND event_source = 'nhtsa_crash' THEN 'significant penalty - used'
                WHEN events >= 30 AND ci_low > 1 THEN 'takeover signal (CI > 1) - reported, not a crash weight'
                WHEN ci_high < 1 THEN 'implausible protective - artefact'
                WHEN events < 30 AND ci_low > 1 THEN 'fewer than 30 events - not used'
                ELSE 'no detectable penalty (CI includes 1)' END;

        DROP TABLE #lv; DROP TABLE #u; DROP TABLE #ush; DROP TABLE #cell; DROP TABLE #mh; DROP TABLE #rr;
        DROP TABLE #phi; DROP TABLE #crude_n;

        -------------------------------------------------- 5. Gold: region x month
        -- RR applied per Saudi condition = the used (evidence-backed) weather ratio of that condition;
        -- NHTSA's obscured_unspecified would apply to fog_moist and haze_dry; dust is never weighted (uncovered).
        DECLARE @rr_rain FLOAT = (SELECT MAX(rr_adjusted) FROM prep.av_relative_risk
                                  WHERE used_in_index = 1 AND factor = 'weather' AND condition_code = 'rain'),
                @rr_obsc FLOAT = (SELECT MAX(rr_adjusted) FROM prep.av_relative_risk
                                  WHERE used_in_index = 1 AND factor = 'weather' AND condition_code = 'obscured_unspecified');
        DECLARE @rr_fog  FLOAT = COALESCE((SELECT MAX(rr_adjusted) FROM prep.av_relative_risk
                                           WHERE used_in_index = 1 AND factor = 'weather' AND condition_code = 'fog_moist'), @rr_obsc),
                @rr_haze FLOAT = COALESCE((SELECT MAX(rr_adjusted) FROM prep.av_relative_risk
                                           WHERE used_in_index = 1 AND factor = 'weather' AND condition_code = 'haze_dry'), @rr_obsc);

        ;WITH cal AS (
            SELECT r.region_code, r.region_name_en, r.region_name_ar, s.station_id,
                   DATEFROMPARTS(y.y, m.m, 1) AS month_start, y.y, m.m
            FROM silver.dim_region r
            JOIN silver.dim_station s ON s.region_code = r.region_code
            CROSS JOIN (VALUES (2021),(2022),(2023),(2024),(2025)) y(y)
            CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) m(m)
        ), w AS (
            SELECT p.*, NULLIF(p.hours_observed, 0) * 1.0 AS hrs FROM prep.saudi_region_month p
        )
        INSERT gold.av_readiness_region_month (
            region_code, region_name_en, region_name_ar, weather_station_id, [year], [month], month_start, season,
            wx_hours_observed, wx_hours_in_month, wx_coverage_pct, wx_complete,
            temp_mean_c, temp_max_c, wind_max_ms, mean_dew_spread_c,
            share_normal_hours, share_rain_hours, share_fog_moist_hours, share_haze_dry_hours, share_dust_hours,
            share_haze_hours, share_fog_hours, share_low_vis_hours, share_night_hours, share_hot40_hours, share_hot45_hours,
            days_observed, dust_days, dust_type_days, haze_dry_days, fog_moist_days, rain_days, normal_days,
            traffic_adt_per_point, traffic_definition, traffic_month_index,
            acc_year_serious, acc_year_deaths, acc_year_injuries, acc_year_serious_within_cities,
            acc_year_serious_outside_cities, acc_share_outside_cities,
            population, population_basis, acc_serious_per_100k, acc_deaths_per_100k, acc_injuries_per_100k,
            road_km_per_1000_people, road_km_per_km2, intercity_road_km, intercity_divided_share,
            response_within_s, response_outside_s, registered_vehicles_2025,
            av_uncovered_share, av_uncovered_share_cons, av_crash_multiplier, env_readiness, env_readiness_cons,
            src_weather, src_accidents, src_traffic, src_av, gold_batch_id)
        SELECT c.region_code, c.region_name_en, c.region_name_ar, c.station_id, c.y, c.m, c.month_start,
               CASE WHEN c.m IN (12,1,2) THEN 'winter' WHEN c.m IN (3,4,5) THEN 'spring'
                    WHEN c.m IN (6,7,8) THEN 'summer' ELSE 'autumn' END,
               w.hours_observed, DAY(EOMONTH(c.month_start)) * 24, cov.pct,
               CASE WHEN w.hours_observed IS NOT NULL AND cov.pct >= 80 THEN 1 ELSE 0 END,
               w.temp_mean_c, w.temp_max_c, w.wind_max_ms, CAST(w.mean_dew_spread_c AS DECIMAL(5,1)),
               CAST(w.normal_hours / w.hrs AS DECIMAL(6,4)), CAST(w.rain_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.fog_moist_hours / w.hrs AS DECIMAL(6,4)), CAST(w.haze_dry_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.dust_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.haze_hours / w.hrs AS DECIMAL(6,4)), CAST(w.fog_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.low_vis_hours / w.hrs AS DECIMAL(6,4)), CAST(w.night_hours / w.hrs AS DECIMAL(6,4)),
               CAST(w.hot40_hours / w.hrs AS DECIMAL(6,4)), CAST(w.hot45_hours / w.hrs AS DECIMAL(6,4)),
               w.days_observed, w.dust_days, w.dust_type_days, w.haze_dry_days, w.fog_moist_days, w.rain_days, w.normal_days,
               t.adt_per_point, t.definition, t.traffic_month_index,
               a.serious_accidents, a.deaths, a.injuries, a.serious_within_cities, a.serious_outside_cities,
               CAST(a.serious_outside_cities * 1.0 / NULLIF(a.serious_within_cities + a.serious_outside_cities, 0) AS DECIMAL(6,4)),
               pop.population, pop.population_basis,
               CAST(100000.0 * a.serious_accidents / NULLIF(pop.population, 0) AS DECIMAL(9,2)),
               CAST(100000.0 * a.deaths            / NULLIF(pop.population, 0) AS DECIMAL(9,2)),
               CAST(100000.0 * a.injuries          / NULLIF(pop.population, 0) AS DECIMAL(9,2)),
               rd.road_km_per_1000_people, rd.road_km_per_km2, rd.intercity_total_km, rd.intercity_divided_share,
               sv.response_within_s, sv.response_outside_s, sv.registered_vehicles,
               -- AV-derived measures from hour counts (exact, not from the rounded shares)
               CAST(w.dust_hours / w.hrs AS DECIMAL(9,6)),
               CAST((w.dust_hours + w.haze_dry_hours) / w.hrs AS DECIMAL(9,6)),
               CAST(1 + w.rain_hours / w.hrs * (ISNULL(@rr_rain, 1) - 1)
                      + w.fog_moist_hours / w.hrs * (ISNULL(@rr_fog, 1) - 1)
                      + w.haze_dry_hours / w.hrs * (ISNULL(@rr_haze, 1) - 1) AS DECIMAL(9,6)),
               -- env_readiness: dust weight 0 (no US AV evidence), used conditions 1/RR, other covered conditions 1
               CAST((w.normal_hours + w.rain_hours / ISNULL(@rr_rain, 1) + w.fog_moist_hours / ISNULL(@rr_fog, 1)
                     + w.haze_dry_hours / ISNULL(@rr_haze, 1)) / w.hrs AS DECIMAL(9,6)),
               -- conservative: Saudi dry haze is mineral dust, California's is mostly smoke -> haze_dry weight 0
               CAST((w.normal_hours + w.rain_hours / ISNULL(@rr_rain, 1) + w.fog_moist_hours / ISNULL(@rr_fog, 1))
                     / w.hrs AS DECIMAL(9,6)),
               N'NOAA NCEI Global Hourly station ' + c.station_id,
               a.source_files,
               CASE WHEN t.source_file IS NOT NULL THEN CONCAT(REPLACE(t.source_file, N'gastat/', N''), N' sheet ', t.source_sheet) END,
               N'prep.av_relative_risk v2: NHTSA state-month MH; DMV month x weekday MH',
               @batch
        FROM cal c
        LEFT JOIN w ON w.region_code = c.region_code AND w.month_start = c.month_start
        OUTER APPLY (SELECT CAST(100.0 * w.hours_observed / (DAY(EOMONTH(c.month_start)) * 24) AS DECIMAL(5,1)) AS pct) cov
        LEFT JOIN silver.traffic_region_month t   ON t.region_code = c.region_code AND t.month_start = c.month_start
        LEFT JOIN silver.accidents_region_year a  ON a.region_code = c.region_code AND a.data_year = c.y
        LEFT JOIN silver.roads_region_year rd     ON rd.region_code = c.region_code AND rd.data_year = c.y
        LEFT JOIN silver.population_region_year pop ON pop.region_code = c.region_code AND pop.data_year = c.y
        LEFT JOIN silver.region_service_2025 sv   ON sv.region_code = c.region_code;
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
