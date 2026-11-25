-- ==============================================================================
-- Project : AV-Ready-Saudi
-- Script  : 02_silver.sql
-- Purpose : Silver = clean, type, standardize, deduplicate and enrich.
--           No aggregation to month/region here: that is Gold's job (Lab 3).
--
-- Reference tables (seeded here, they are the join keys of the whole model)
--   silver.dim_region        13 Saudi administrative regions
--   silver.region_alias      GASTAT label spellings -> region_code
--   silver.dim_station       17 weather stations -> Saudi region or US state
--   silver.gastat_sheet_map  which GASTAT sheet/column holds which metric/year
--
-- Cleaned tables
--   silver.weather_obs            one row per weather report (typed + condition flags)
--   silver.accidents_region_year  GASTAT serious accidents / deaths / injuries
--   silver.dmv_disengagement      one row per disengagement (date, location, cause)
--   silver.dmv_mileage_monthly    autonomous miles per vehicle per month
--   silver.nhtsa_crash            one row per ADS crash (latest report version)
--   silver.reject_log             rows that failed a rule, with the reason
-- ==============================================================================

USE av_ready_saudi_dw;
GO

-- ------------------------------------------------------------------------------
-- 0. Reference tables
-- ------------------------------------------------------------------------------
-- drop in dependency order (tables that reference dim_region first) so the script can be re-run
DROP TABLE IF EXISTS silver.reject_log;
DROP TABLE IF EXISTS silver.weather_obs;
DROP TABLE IF EXISTS silver.accidents_region_year;
DROP TABLE IF EXISTS silver.dmv_disengagement;
DROP TABLE IF EXISTS silver.dmv_mileage_monthly;
DROP TABLE IF EXISTS silver.nhtsa_crash;
DROP TABLE IF EXISTS silver.region_alias;
DROP TABLE IF EXISTS silver.dim_station;
DROP TABLE IF EXISTS silver.gastat_sheet_map;
DROP TABLE IF EXISTS silver.dim_region;
GO
CREATE TABLE silver.dim_region (
    region_code     CHAR(3)       NOT NULL PRIMARY KEY,
    region_name_en  NVARCHAR(50)  NOT NULL,
    region_name_ar  NVARCHAR(50)  NOT NULL
);
INSERT INTO silver.dim_region VALUES
 ('RIY', N'Riyadh',           N'الرياض'),
 ('MAK', N'Makkah',           N'مكة المكرمة'),
 ('MED', N'Madinah',          N'المدينة المنورة'),
 ('EAS', N'Eastern Province', N'المنطقة الشرقية'),
 ('QAS', N'Qassim',           N'القصيم'),
 ('HAI', N'Hail',             N'حائل'),
 ('TAB', N'Tabuk',            N'تبوك'),
 ('NBR', N'Northern Borders', N'الحدود الشمالية'),
 ('JOF', N'Al-Jouf',          N'الجوف'),
 ('ASR', N'Aseer',            N'عسير'),
 ('BAH', N'Al-Baha',          N'الباحة'),
 ('NAJ', N'Najran',           N'نجران'),
 ('JAZ', N'Jazan',            N'جازان');

-- GASTAT writes the same region several ways ("Eastern Province", "Eastern Region",
-- " Riyadh", "Al Baha", "Al-Baha "). Labels are normalised by silver.fn_region_key
-- (lower case, no spaces/hyphens, words "region"/"province" removed) then matched here.
CREATE TABLE silver.region_alias (
    alias_key    NVARCHAR(60) NOT NULL PRIMARY KEY,
    region_code  CHAR(3)      NOT NULL REFERENCES silver.dim_region(region_code)
);
INSERT INTO silver.region_alias VALUES
 (N'riyadh','RIY'), (N'makkah','MAK'), (N'madinah','MED'), (N'eastern','EAS'),
 (N'qassim','QAS'), (N'hail','HAI'), (N'tabuk','TAB'), (N'northernborders','NBR'),
 (N'aljouf','JOF'), (N'aseer','ASR'), (N'albaha','BAH'), (N'najran','NAJ'), (N'jazan','JAZ');

-- One station per Saudi region (the region's main airport) + US analog stations
-- where the NHTSA crashes and DMV tests happen (CA, AZ, TX).
CREATE TABLE silver.dim_station (
    station_id    CHAR(11)     NOT NULL PRIMARY KEY,
    station_name  NVARCHAR(80) NOT NULL,
    country       CHAR(2)      NOT NULL,          -- SA / US
    region_code   CHAR(3)      NULL REFERENCES silver.dim_region(region_code),
    us_state      CHAR(2)      NULL,
    tz_name       VARCHAR(60)  NOT NULL,          -- Windows time-zone name for AT TIME ZONE
    latitude      FLOAT        NOT NULL,
    longitude     FLOAT        NOT NULL
);
INSERT INTO silver.dim_station VALUES
 ('40437099999', N'Riyadh - King Khalid Intl',   'SA','RIY',NULL,'Arab Standard Time', 24.958, 46.699),
 ('41024099999', N'Jeddah - King Abdulaziz Intl','SA','MAK',NULL,'Arab Standard Time', 21.680, 39.157),
 ('40430099999', N'Madinah - Prince Mohammad',   'SA','MED',NULL,'Arab Standard Time', 24.553, 39.705),
 ('40415099999', N'Dammam - King Fahd Intl',     'SA','EAS',NULL,'Arab Standard Time', 26.433, 49.800),
 ('40405099999', N'Qassim - Gassim',             'SA','QAS',NULL,'Arab Standard Time', 26.300, 43.767),
 ('40394099999', N'Hail',                        'SA','HAI',NULL,'Arab Standard Time', 27.438, 41.686),
 ('40375099999', N'Tabuk',                       'SA','TAB',NULL,'Arab Standard Time', 28.365, 36.619),
 ('40357099999', N'Arar',                        'SA','NBR',NULL,'Arab Standard Time', 30.907, 41.138),
 ('40361099999', N'Al-Jouf',                     'SA','JOF',NULL,'Arab Standard Time', 29.785, 40.100),
 ('41112099999', N'Abha',                        'SA','ASR',NULL,'Arab Standard Time', 18.240, 42.657),
 ('41055099999', N'Al-Baha',                     'SA','BAH',NULL,'Arab Standard Time', 20.296, 41.634),
 ('41128099999', N'Najran',                      'SA','NAJ',NULL,'Arab Standard Time', 17.611, 44.419),
 ('41140099999', N'Jazan - King Abdullah',       'SA','JAZ',NULL,'Arab Standard Time', 16.901, 42.586),
 ('72295023174', N'Los Angeles Intl (LAX)',      'US',NULL,'CA','Pacific Standard Time',     33.938,-118.387),
 ('72494023234', N'San Francisco Intl (SFO)',    'US',NULL,'CA','Pacific Standard Time',     37.620,-122.365),
 ('72278023183', N'Phoenix Sky Harbor (PHX)',    'US',NULL,'AZ','US Mountain Standard Time', 33.428,-112.004),
 ('72254013904', N'Austin Bergstrom (AUS)',      'US',NULL,'TX','Central Standard Time',     30.183, -97.680);

-- Where each accident metric sits in the GASTAT workbooks (checked cell by cell).
CREATE TABLE silver.gastat_sheet_map (
    file_key    NVARCHAR(80) NOT NULL,   -- matched with LIKE '%' + file_key + '%'
    sheet_name  NVARCHAR(20) NOT NULL,
    metric      VARCHAR(30)  NOT NULL,   -- serious / serious_within / serious_outside / deaths / injuries
    data_year   SMALLINT     NOT NULL,
    col_num     INT          NOT NULL,
    first_row   INT          NOT NULL,
    last_row    INT          NOT NULL,
    PRIMARY KEY (metric, data_year)
);
INSERT INTO silver.gastat_sheet_map VALUES
 (N'Land_Transport_Statistics_2022', N'17',    'injuries',        2021, 3, 8, 20),
 (N'Land_Transport_Statistics_2022', N'17',    'injuries',        2022, 4, 8, 20),
 (N'Land_Transport_Statistics_2022', N'17',    'deaths',          2021, 6, 8, 20),
 (N'Land_Transport_Statistics_2022', N'17',    'deaths',          2022, 7, 8, 20),
 (N'Land_Transport_Statistics_2022', N'20',    'serious',         2021, 2, 8, 20),
 (N'Land_Transport_Statistics_2022', N'20',    'serious',         2022, 3, 8, 20),
 (N'Land_Transport_Statistics_2023', N'34',    'injuries',        2023, 2, 7, 19),
 (N'Land_Transport_Statistics_2023', N'34',    'deaths',          2023, 3, 7, 19),
 (N'Land_Transport_Statistics_2023', N'37',    'serious',         2023, 2, 7, 19),
 (N'Road_Transport_Statistics_2024', N'5-1',   'injuries',        2024, 2, 7, 19),
 (N'Road_Transport_Statistics_2024', N'5-1',   'deaths',          2024, 3, 7, 19),
 (N'Road_Transport_Statistics_2024', N'5-5',   'serious_within',  2024, 2, 7, 19),
 (N'Road_Transport_Statistics_2024', N'5-5',   'serious_outside', 2024, 3, 7, 19),
 (N'Road_Transport_Statistics_2024', N'5-5',   'serious',         2024, 4, 7, 19),
 (N'Road_Transport_Statistics_2025', N'5-1-1', 'injuries',        2025, 2, 7, 19),
 (N'Road_Transport_Statistics_2025', N'5-1-1', 'deaths',          2025, 3, 7, 19),
 (N'Road_Transport_Statistics_2025', N'5-6-1', 'serious_within',  2025, 2, 7, 19),
 (N'Road_Transport_Statistics_2025', N'5-6-1', 'serious_outside', 2025, 3, 7, 19);
-- 2025 total serious = within + outside (the workbook's total column is a formula).
GO

-- ------------------------------------------------------------------------------
-- 0b. Helper functions
-- ------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION silver.fn_region_key (@label NVARCHAR(200))
RETURNS NVARCHAR(200) WITH SCHEMABINDING
AS
BEGIN
    DECLARE @s NVARCHAR(200) = LOWER(LTRIM(RTRIM(ISNULL(@label, N''))));
    SET @s = REPLACE(REPLACE(@s, N'region', N''), N'province', N'');
    SET @s = REPLACE(REPLACE(REPLACE(@s, N' ', N''), N'-', N''), NCHAR(160), N'');
    RETURN @s;
END
GO

-- Solar elevation (degrees) for a place and a UTC time - NOAA general solar
-- position equations. Used to tell day from night (elevation < -0.833 = sun below
-- the horizon). Inline TVF so SQL Server can apply it to ~1M rows efficiently.
CREATE OR ALTER FUNCTION silver.tvf_solar_elevation (@lat FLOAT, @lon FLOAT, @utc DATETIME2)
RETURNS TABLE
AS RETURN
WITH g AS (
    SELECT 2.0 * PI() / 365.0 * (DATEPART(dayofyear, @utc) - 1
           + (DATEPART(hour, @utc) - 12) / 24.0) AS gamma,
           DATEPART(hour, @utc) * 60.0 + DATEPART(minute, @utc) AS utc_min
), d AS (
    SELECT gamma, utc_min,
           0.006918 - 0.399912*COS(gamma) + 0.070257*SIN(gamma) - 0.006758*COS(2*gamma)
         + 0.000907*SIN(2*gamma) - 0.002697*COS(3*gamma) + 0.00148*SIN(3*gamma) AS decl,
           229.18*(0.000075 + 0.001868*COS(gamma) - 0.032077*SIN(gamma)
         - 0.014615*COS(2*gamma) - 0.040849*SIN(2*gamma)) AS eqtime
    FROM g
), h AS (
    SELECT decl, RADIANS(((utc_min + eqtime + 4.0*@lon) / 4.0) - 180.0) AS ha FROM d
)
SELECT 90.0 - DEGREES(ACOS(
         CASE WHEN v > 1 THEN 1 WHEN v < -1 THEN -1 ELSE v END)) AS elevation_deg
FROM (SELECT SIN(RADIANS(@lat))*SIN(decl) + COS(RADIANS(@lat))*COS(decl)*COS(ha) AS v FROM h) x;
GO

-- ------------------------------------------------------------------------------
-- 1. Cleaned tables
-- ------------------------------------------------------------------------------
CREATE TABLE silver.reject_log (
    reject_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_table   VARCHAR(60)    NOT NULL,
    source_file    NVARCHAR(400)  NULL,
    source_row     NVARCHAR(40)   NULL,
    reason         VARCHAR(200)   NOT NULL,
    raw_value      NVARCHAR(400)  NULL,
    dw_create_date DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE silver.weather_obs (
    station_id      CHAR(11)      NOT NULL,
    obs_utc         DATETIME2(0)  NOT NULL,
    obs_local       DATETIME2(0)  NOT NULL,
    report_type     VARCHAR(10)   NOT NULL,
    vis_m           INT           NULL,
    temp_c          DECIMAL(5,1)  NULL,
    wind_ms         DECIMAL(5,1)  NULL,
    precip_1h_mm    DECIMAL(6,1)  NULL,
    mw_code         CHAR(2)       NULL,   -- manual present weather (WMO 4677)
    aw_code         CHAR(2)       NULL,   -- automated present weather (WMO 4680)
    au_precip       CHAR(2)       NULL,   -- METAR-style precipitation code
    au_obscuration  CHAR(1)       NULL,   -- METAR-style obscuration code
    au_other        CHAR(1)       NULL,
    sun_elev_deg    DECIMAL(6,2)  NULL,
    is_dust         BIT NOT NULL,
    is_haze         BIT NOT NULL,
    is_fog          BIT NOT NULL,
    is_rain         BIT NOT NULL,
    is_low_vis      BIT NOT NULL,         -- visibility < 5 km
    is_night        BIT NOT NULL,         -- sun below the horizon
    source_file     NVARCHAR(400) NOT NULL,
    source_row_num  INT           NOT NULL,
    dw_create_date  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT PK_weather_obs PRIMARY KEY (station_id, obs_utc, report_type)
);

CREATE TABLE silver.accidents_region_year (
    region_code             CHAR(3)  NOT NULL REFERENCES silver.dim_region(region_code),
    data_year               SMALLINT NOT NULL,
    serious_accidents       INT      NULL,
    serious_within_cities   INT      NULL,
    serious_outside_cities  INT      NULL,
    deaths                  INT      NULL,
    injuries                INT      NULL,
    source_files            NVARCHAR(400) NULL,
    dw_create_date          DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (region_code, data_year)
);

CREATE TABLE silver.dmv_disengagement (
    disengagement_id  BIGINT IDENTITY(1,1) PRIMARY KEY,
    report_file       NVARCHAR(400) NOT NULL,
    source_row_num    INT           NOT NULL,
    program           VARCHAR(20)   NOT NULL,   -- drivered / driverless / first_time
    manufacturer      NVARCHAR(200) NOT NULL,
    permit_number     NVARCHAR(50)  NULL,
    vin               NVARCHAR(50)  NULL,
    event_date        DATE          NOT NULL,
    initiated_by      VARCHAR(20)   NOT NULL,   -- test_driver / av_system / remote_or_retrieval / other
    location_type     VARCHAR(20)   NOT NULL,   -- street / highway_freeway / parking / other
    cause_category    VARCHAR(30)   NOT NULL,   -- keyword rules, see procedure
    description       NVARCHAR(MAX) NULL,
    dw_create_date    DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE silver.dmv_mileage_monthly (
    permit_number   NVARCHAR(50)  NOT NULL,
    vin             NVARCHAR(50)  NOT NULL,
    manufacturer    NVARCHAR(200) NOT NULL,
    month_start     DATE          NOT NULL,
    miles           DECIMAL(14,2) NOT NULL,
    dw_create_date  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    PRIMARY KEY (permit_number, vin, month_start)
);

CREATE TABLE silver.nhtsa_crash (
    report_id         NVARCHAR(100) NOT NULL PRIMARY KEY,
    report_version    INT           NOT NULL,
    source_file       NVARCHAR(400) NOT NULL,
    reporting_entity  NVARCHAR(200) NULL,
    make              NVARCHAR(200) NULL,
    model             NVARCHAR(200) NULL,
    us_state          CHAR(2)       NULL,
    city              NVARCHAR(200) NULL,
    incident_month    DATE          NULL,
    incident_time     TIME(0)       NULL,
    roadway_type      VARCHAR(20)   NOT NULL,   -- street / intersection / highway_freeway / parking / other
    speed_limit_mph   INT           NULL,
    lighting_raw      NVARCHAR(100) NULL,
    w_clear  BIT NOT NULL, w_cloudy BIT NOT NULL, w_rain BIT NOT NULL, w_snow BIT NOT NULL,
    w_fog_smoke_haze BIT NOT NULL, w_dust BIT NOT NULL, w_wind BIT NOT NULL, w_unknown BIT NOT NULL,
    weather_bucket    VARCHAR(10)   NOT NULL,   -- normal / rain / obscured / unknown
    is_night          BIT           NULL,
    in_scope          BIT           NOT NULL,   -- state CA/AZ/TX and incident year 2021-2025
    dw_create_date    DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
GO

-- ------------------------------------------------------------------------------
-- 2. Load procedure
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- any error (also compile-time ones TRY/CATCH cannot catch) rolls the step back
    -- month names ("SEP-2026", "15/Apr/22") are parsed with CONVERT styles 106 / 1, which follow the
    -- session language: fix it to English so a login with another default language parses the same
    SET LANGUAGE us_english;
    DECLARE @batch UNIQUEIDENTIFIER = NEWID(), @t0 DATETIME2, @rows BIGINT, @log BIGINT;

    ---------------------------------------------------------------- weather_obs
    SET @t0 = SYSDATETIME();
    INSERT audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
    VALUES (@batch, 'silver', 'bronze.noaa_hourly', 'silver.weather_obs', @t0, 'RUNNING');
    SET @log = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE silver.weather_obs;
        DELETE FROM silver.reject_log WHERE source_table = 'weather_obs';

        -- rule: the timestamp must parse; daily/monthly summary records (SOD/SOM) are not observations
        INSERT silver.reject_log (source_table, source_file, source_row, reason, raw_value)
        SELECT 'weather_obs', source_file, source_row_num, 'unparsable DATE', LEFT([DATE], 400)
        FROM bronze.noaa_hourly WHERE TRY_CONVERT(DATETIME2(0), [DATE], 126) IS NULL;

        ;WITH p AS (
            SELECT b.source_file, TRY_CAST(b.source_row_num AS INT) AS source_row_num,
                   s.station_id, s.tz_name, s.latitude, s.longitude,
                   TRY_CONVERT(DATETIME2(0), b.[DATE], 126) AS obs_utc,
                   LTRIM(RTRIM(b.REPORT_TYPE)) AS report_type,
                   -- VIS: dddddd,q,v,q  (metres; 999999 = missing; q 2/3/6/7 = suspect/erroneous)
                   CASE WHEN SUBSTRING(b.VIS,8,1) IN ('2','3','6','7') THEN NULL
                        ELSE NULLIF(TRY_CAST(LEFT(b.VIS,6) AS INT), 999999) END AS vis_m,
                   -- TMP: +tttt,q  (tenths of degC; +9999 = missing)
                   CASE WHEN SUBSTRING(b.TMP,7,1) IN ('2','3','6','7') THEN NULL
                        ELSE NULLIF(TRY_CAST(LEFT(b.TMP,5) AS INT), 9999) / 10.0 END AS temp_c,
                   -- WND: ddd,q,t,ssss,q  (speed tenths of m/s; 9999 = missing)
                   CASE WHEN SUBSTRING(b.WND,14,1) IN ('2','3','6','7') THEN NULL
                        ELSE NULLIF(TRY_CAST(SUBSTRING(b.WND,9,4) AS INT), 9999) / 10.0 END AS wind_ms,
                   -- AA1: pp,dddd,c,q  (period hours, depth tenths of mm) - keep 1-hour totals only;
                   -- q (position 11) 2/3/6/7 = suspect/erroneous, dropped like VIS / TMP / WND
                   CASE WHEN LEFT(b.AA1,2) = '01' AND SUBSTRING(b.AA1,4,4) <> '9999'
                             AND SUBSTRING(b.AA1,11,1) NOT IN ('2','3','6','7')
                        THEN TRY_CAST(SUBSTRING(b.AA1,4,4) AS INT) / 10.0 END AS precip_1h_mm,
                   NULLIF(LEFT(b.MW1,2), '') AS mw_code,
                   NULLIF(LEFT(b.AW1,2), '') AS aw_code,
                   NULLIF(SUBSTRING(b.AU1,5,2), '') AS au_precip,
                   NULLIF(SUBSTRING(b.AU1,8,1), '') AS au_obscuration,
                   NULLIF(SUBSTRING(b.AU1,10,1), '') AS au_other,
                   ROW_NUMBER() OVER (PARTITION BY b.STATION, b.[DATE], LTRIM(RTRIM(b.REPORT_TYPE))
                                      ORDER BY TRY_CAST(b.source_row_num AS INT)) AS rn
            FROM bronze.noaa_hourly b
            JOIN silver.dim_station s ON s.station_id = LTRIM(RTRIM(b.STATION))
            WHERE TRY_CONVERT(DATETIME2(0), b.[DATE], 126) IS NOT NULL
              AND LTRIM(RTRIM(b.REPORT_TYPE)) NOT IN ('SOD', 'SOM')
        )
        INSERT silver.weather_obs (station_id, obs_utc, obs_local, report_type, vis_m, temp_c, wind_ms,
               precip_1h_mm, mw_code, aw_code, au_precip, au_obscuration, au_other, sun_elev_deg,
               is_dust, is_haze, is_fog, is_rain, is_low_vis, is_night, source_file, source_row_num)
        SELECT p.station_id, p.obs_utc,
               CAST(CAST(p.obs_utc AS DATETIMEOFFSET) AT TIME ZONE p.tz_name AS DATETIME2(0)),
               p.report_type, p.vis_m, p.temp_c, p.wind_ms, p.precip_1h_mm,
               p.mw_code, p.aw_code, p.au_precip, p.au_obscuration, p.au_other,
               CAST(se.elevation_deg AS DECIMAL(6,2)),
               -- dust/sand: WMO 4677 06-09, 30-35; METAR obscuration DU/SA; whirls/sand/dust storm
               CASE WHEN p.mw_code IN ('06','07','08','09','30','31','32','33','34','35')
                      OR p.au_obscuration IN ('5','6') OR p.au_other IN ('1','4','5') THEN 1 ELSE 0 END,
               -- haze/smoke: 4677 04-05, 4680 04-05, METAR FU/HZ
               CASE WHEN p.mw_code IN ('04','05') OR p.aw_code IN ('04','05')
                      OR p.au_obscuration IN ('3','7') THEN 1 ELSE 0 END,
               -- fog: 4677 40-49, 4680 30-35, METAR FG
               CASE WHEN p.mw_code BETWEEN '40' AND '49' OR p.aw_code BETWEEN '30' AND '35'
                      OR p.au_obscuration = '2' THEN 1 ELSE 0 END,
               -- rain/precipitation: 4677 50-69, 80-99; 4680 40-69, 80-89; METAR DZ/RA/UP; measured 1-h precip
               CASE WHEN p.mw_code BETWEEN '50' AND '69' OR p.mw_code BETWEEN '80' AND '99'
                      OR p.aw_code BETWEEN '40' AND '69' OR p.aw_code BETWEEN '80' AND '89'
                      OR p.au_precip IN ('01','02','09') OR p.precip_1h_mm > 0 THEN 1 ELSE 0 END,
               CASE WHEN p.vis_m < 5000 THEN 1 ELSE 0 END,
               CASE WHEN se.elevation_deg < -0.833 THEN 1 ELSE 0 END,
               p.source_file, p.source_row_num
        FROM p
        CROSS APPLY silver.tvf_solar_elevation(p.latitude, p.longitude, p.obs_utc) se
        WHERE p.rn = 1
          AND YEAR(CAST(CAST(p.obs_utc AS DATETIMEOFFSET) AT TIME ZONE p.tz_name AS DATETIME2(0)))
              BETWEEN 2021 AND 2025;
        SET @rows = @@ROWCOUNT;
        COMMIT;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS' WHERE load_id = @log;
        PRINT CONCAT('  silver.weather_obs: ', @rows);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED', message = LEFT(ERROR_MESSAGE(),2000) WHERE load_id = @log;
        THROW;
    END CATCH;

    ---------------------------------------------------------------- accidents_region_year
    SET @t0 = SYSDATETIME();
    INSERT audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
    VALUES (@batch, 'silver', 'bronze.gastat_cells', 'silver.accidents_region_year', @t0, 'RUNNING');
    SET @log = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE silver.accidents_region_year;
        DELETE FROM silver.reject_log WHERE source_table = 'accidents_region_year';

        ;WITH cells AS (
            SELECT c.source_file, c.sheet_name, TRY_CAST(c.row_num AS INT) AS r,
                   TRY_CAST(c.col_num AS INT) AS col, c.cell_value
            FROM bronze.gastat_cells c
        ), vals AS (
            SELECT m.metric, m.data_year, v.source_file, v.r, v.cell_value,
                   lbl.cell_value AS region_label,
                   TRY_CAST(TRY_CAST(REPLACE(REPLACE(v.cell_value, ',', ''), ' ', '') AS DECIMAL(18,2)) AS INT) AS n
            FROM silver.gastat_sheet_map m
            JOIN cells v   ON v.source_file LIKE '%' + m.file_key + '%' AND v.sheet_name = m.sheet_name
                          AND v.col = m.col_num AND v.r BETWEEN m.first_row AND m.last_row
            JOIN cells lbl ON lbl.source_file = v.source_file AND lbl.sheet_name = v.sheet_name
                          AND lbl.r = v.r AND lbl.col = 1
        ), mapped AS (
            SELECT vals.*, a.region_code FROM vals
            LEFT JOIN silver.region_alias a ON a.alias_key = silver.fn_region_key(vals.region_label)
        )
        SELECT * INTO #acc FROM mapped;

        INSERT silver.reject_log (source_table, source_file, source_row, reason, raw_value)
        SELECT 'accidents_region_year', source_file, CONCAT(metric, ' ', data_year, ' row ', r),
               CASE WHEN region_code IS NULL THEN 'unknown region label' ELSE 'value is not a whole number' END,
               LEFT(CONCAT(region_label, ' = ', cell_value), 400)
        FROM #acc WHERE region_code IS NULL OR n IS NULL;

        ;WITH ok AS (
            SELECT DISTINCT region_code, data_year, metric, n, source_file FROM #acc
            WHERE region_code IS NOT NULL AND n IS NOT NULL
        ), files AS (
            SELECT region_code, data_year,
                   STRING_AGG(CAST(REPLACE(source_file, 'gastat/', '') AS NVARCHAR(MAX)), '; ')
                       WITHIN GROUP (ORDER BY source_file) AS source_files
            FROM (SELECT DISTINCT region_code, data_year, source_file FROM ok) f
            GROUP BY region_code, data_year
        ), piv AS (
            SELECT region_code, data_year,
                   MAX(CASE WHEN metric = 'serious'         THEN n END) AS serious,
                   MAX(CASE WHEN metric = 'serious_within'  THEN n END) AS s_in,
                   MAX(CASE WHEN metric = 'serious_outside' THEN n END) AS s_out,
                   MAX(CASE WHEN metric = 'deaths'          THEN n END) AS deaths,
                   MAX(CASE WHEN metric = 'injuries'        THEN n END) AS injuries
            FROM ok GROUP BY region_code, data_year
        )
        INSERT silver.accidents_region_year (region_code, data_year, serious_accidents, serious_within_cities,
               serious_outside_cities, deaths, injuries, source_files)
        SELECT p.region_code, p.data_year, COALESCE(p.serious, p.s_in + p.s_out), p.s_in, p.s_out,
               p.deaths, p.injuries, LEFT(f.source_files, 400)
        FROM piv p JOIN files f ON f.region_code = p.region_code AND f.data_year = p.data_year;
        SET @rows = @@ROWCOUNT;
        DROP TABLE #acc;
        COMMIT;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS' WHERE load_id = @log;
        PRINT CONCAT('  silver.accidents_region_year: ', @rows);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED', message = LEFT(ERROR_MESSAGE(),2000) WHERE load_id = @log;
        THROW;
    END CATCH;

    ---------------------------------------------------------------- dmv_disengagement
    SET @t0 = SYSDATETIME();
    INSERT audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
    VALUES (@batch, 'silver', 'bronze.dmv_disengagements', 'silver.dmv_disengagement', @t0, 'RUNNING');
    SET @log = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE silver.dmv_disengagement;
        DELETE FROM silver.reject_log WHERE source_table = 'dmv_disengagement';

        ;WITH b AS (
            SELECT d.*,
                   -- first token of the date text; trailing dot removed ("2022.03.04. 10:11")
                   REPLACE(LEFT(LTRIM(d.date_raw), CHARINDEX(' ', LTRIM(d.date_raw) + ' ') - 1) + '#', '.#', '') AS dtok
            FROM bronze.dmv_disengagements d
        ), t AS (
            SELECT b.*, REPLACE(dtok, '#', '') AS dclean FROM b
        ), p AS (
            SELECT t.*,
                   COALESCE(
                     CASE WHEN dclean LIKE '[0-9][0-9][0-9][0-9]-%' THEN TRY_CONVERT(DATE, dclean, 23) END,
                     CASE WHEN dclean LIKE '[0-9][0-9][0-9][0-9].%' THEN TRY_CONVERT(DATE, dclean, 102) END,
                     CASE WHEN dclean LIKE '%/[0-9][0-9][0-9][0-9]' THEN TRY_CONVERT(DATE, dclean, 101) END,
                     CASE WHEN dclean LIKE '%/[0-9][0-9]' THEN TRY_CONVERT(DATE, dclean, 1) END) AS event_date,
                   LOWER(REPLACE(REPLACE(REPLACE(ISNULL(t.description, N''), N'\n', N' '), N'\r', N' '), N'\t', N' ')) AS dlow
            FROM t
        )
        SELECT p.*,
               CASE
                 WHEN p.source_file LIKE '%driverless%'        THEN 'driverless'
                 WHEN p.source_file LIKE '%first-time-filers%' THEN 'first_time'
                 ELSE 'drivered' END AS program
        INTO #dis FROM p;

        INSERT silver.reject_log (source_table, source_file, source_row, reason, raw_value)
        SELECT 'dmv_disengagement', source_file, source_row_num,
               CASE WHEN LTRIM(RTRIM(ISNULL(manufacturer, ''))) = '' THEN 'missing manufacturer'
                    WHEN event_date IS NULL THEN 'unparsable or missing date'
                    ELSE 'date outside DMV reporting window 2020-12-01..2024-11-30' END,
               LEFT(CONCAT(manufacturer, ' | ', date_raw), 400)
        FROM #dis
        WHERE LTRIM(RTRIM(ISNULL(manufacturer, ''))) = '' OR event_date IS NULL
           OR event_date NOT BETWEEN '2020-12-01' AND '2024-11-30';

        INSERT silver.dmv_disengagement (report_file, source_row_num, program, manufacturer, permit_number, vin,
               event_date, initiated_by, location_type, cause_category, description)
        SELECT source_file, TRY_CAST(source_row_num AS INT), program,
               UPPER(LTRIM(RTRIM(REPLACE(REPLACE(manufacturer, ',', ''), '.', '')))),
               NULLIF(LTRIM(RTRIM(permit_number)), ''), NULLIF(LTRIM(RTRIM(vin)), ''),
               event_date,
               CASE WHEN LOWER(initiated_by) LIKE '%retriev%' OR LOWER(initiated_by) LIKE '%remote%'
                         OR LOWER(initiated_by) LIKE '%operator%' THEN 'remote_or_retrieval'
                    WHEN LOWER(initiated_by) LIKE '%av%' OR LOWER(initiated_by) LIKE '%ads%'
                         OR LOWER(initiated_by) LIKE '%system%' THEN 'av_system'
                    WHEN LOWER(initiated_by) LIKE '%driver%' OR LOWER(initiated_by) LIKE '%drive%' THEN 'test_driver'
                    ELSE 'other' END,
               CASE WHEN LOWER(location) LIKE '%parking%' THEN 'parking'
                    WHEN LOWER(location) LIKE '%freeway%' OR LOWER(location) LIKE '%highway%'
                         OR LOWER(location) LIKE '%interstate%' OR LOWER(location) LIKE '%express%'
                         OR LOWER(location) LIKE '%rural%' THEN 'highway_freeway'
                    WHEN LOWER(location) LIKE '%street%' OR LOWER(location) LIKE '%urban%' THEN 'street'
                    ELSE 'other' END,
               -- cause category: keyword rules, first match wins (documented in docs/05_relations_and_lineage.md)
               CASE WHEN dlow LIKE '%weather%' OR dlow LIKE '%rain%' OR dlow LIKE '% fog%' OR dlow LIKE '%glare%'
                         OR dlow LIKE '%sun %' OR dlow LIKE '%sunlight%' OR dlow LIKE '%dust%' OR dlow LIKE '%smoke%'
                         OR dlow LIKE '%wet road%' THEN 'environment'
                    WHEN dlow LIKE '%perception%' OR dlow LIKE '%detect%' OR dlow LIKE '%sensor%' OR dlow LIKE '%lidar%'
                         OR dlow LIKE '%camera%' OR dlow LIKE '%radar%' OR dlow LIKE '%classif%'
                         OR dlow LIKE '%false positive%' OR dlow LIKE '%occlu%' OR dlow LIKE '%tracking%' THEN 'perception'
                    WHEN dlow LIKE '%locali%' OR dlow LIKE '% map%' OR dlow LIKE '%gps%' THEN 'localization'
                    WHEN dlow LIKE '%software%' OR dlow LIKE '%hardware%' OR dlow LIKE '%health%'
                         OR dlow LIKE '%fault%' OR dlow LIKE '%error%' OR dlow LIKE '%comput%' OR dlow LIKE '%network%'
                         OR dlow LIKE '%connect%' OR dlow LIKE '%latency%' OR dlow LIKE '%sub-system%'
                         OR dlow LIKE '%subsystem%' OR dlow LIKE '%diagnos%' THEN 'system_fault'
                    WHEN dlow LIKE '%steer%' OR dlow LIKE '%brak%' OR dlow LIKE '%throttle%'
                         OR dlow LIKE '%control%' THEN 'control'
                    WHEN dlow LIKE '%predict%' OR dlow LIKE '%impeded%' OR dlow LIKE '%other vehicle%'
                         OR dlow LIKE '%another vehicle%' OR dlow LIKE '%pedestrian%' OR dlow LIKE '%cyclist%'
                         OR dlow LIKE '%road user%' OR dlow LIKE '%cut in%' OR dlow LIKE '%cut-in%' THEN 'prediction'
                    WHEN dlow LIKE '%plan%' OR dlow LIKE '%trajector%' OR dlow LIKE '%maneuver%'
                         OR dlow LIKE '%undesirable%' OR dlow LIKE '%behavior%' OR dlow LIKE '%behaviour%'
                         OR dlow LIKE '%lane%' OR dlow LIKE '%path%' THEN 'planning'
                    WHEN dlow LIKE '%precaution%' OR dlow LIKE '%discretion%' OR dlow LIKE '%safety driver%'
                         OR dlow LIKE '%operator%' OR dlow LIKE '%takeover%' OR dlow LIKE '%manual%' THEN 'precautionary'
                    ELSE 'other' END,
               REPLACE(REPLACE(REPLACE(description, N'\n', NCHAR(10)), N'\r', N''), N'\t', N' ')
        FROM #dis
        WHERE LTRIM(RTRIM(ISNULL(manufacturer, ''))) <> '' AND event_date BETWEEN '2020-12-01' AND '2024-11-30';
        SET @rows = @@ROWCOUNT;
        DROP TABLE #dis;
        COMMIT;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS' WHERE load_id = @log;
        PRINT CONCAT('  silver.dmv_disengagement: ', @rows);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED', message = LEFT(ERROR_MESSAGE(),2000) WHERE load_id = @log;
        THROW;
    END CATCH;

    ---------------------------------------------------------------- dmv_mileage_monthly
    SET @t0 = SYSDATETIME();
    INSERT audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
    VALUES (@batch, 'silver', 'bronze.dmv_mileage', 'silver.dmv_mileage_monthly', @t0, 'RUNNING');
    SET @log = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE silver.dmv_mileage_monthly;
        DELETE FROM silver.reject_log WHERE source_table = 'dmv_mileage_monthly';

        -- unpivot the month columns ("DEC 2020", "JULY 2021", ...) kept in months_json
        SELECT m.source_file, m.source_row_num,
               ISNULL(LTRIM(RTRIM(m.permit_number)), '') AS permit_number, ISNULL(LTRIM(RTRIM(m.vin)), '') AS vin,
               ISNULL(UPPER(LTRIM(RTRIM(REPLACE(REPLACE(m.manufacturer, ',', ''), '.', '')))), '') AS manufacturer,
               j.k AS month_label, j.v AS miles_raw,
               TRY_CAST(CONCAT(RIGHT(LTRIM(RTRIM(j.k)), 4), '-',
                   CASE LEFT(UPPER(LTRIM(j.k)), 3)
                     WHEN 'JAN' THEN '01' WHEN 'FEB' THEN '02' WHEN 'MAR' THEN '03' WHEN 'APR' THEN '04'
                     WHEN 'MAY' THEN '05' WHEN 'JUN' THEN '06' WHEN 'JUL' THEN '07' WHEN 'AUG' THEN '08'
                     WHEN 'SEP' THEN '09' WHEN 'OCT' THEN '10' WHEN 'NOV' THEN '11' WHEN 'DEC' THEN '12' END,
                   '-01') AS DATE) AS month_start,
               TRY_CAST(REPLACE(REPLACE(j.v, ',', ''), ' ', '') AS DECIMAL(14,2)) AS miles
        INTO #mil
        FROM bronze.dmv_mileage m
        -- OPENJSON returns [key] in Latin1_General_BIN2; bring key and value to the database collation
        CROSS APPLY (SELECT oj.[key] COLLATE DATABASE_DEFAULT AS k, oj.[value] COLLATE DATABASE_DEFAULT AS v
                     FROM OPENJSON(m.months_json) oj) j
        WHERE ISJSON(m.months_json) = 1
          AND j.k NOT LIKE '%TOTAL%' AND j.k NOT LIKE 'col%';

        INSERT silver.reject_log (source_table, source_file, source_row, reason, raw_value)
        SELECT 'dmv_mileage_monthly', source_file, source_row_num,
               CASE WHEN month_start IS NULL THEN 'unrecognised month column'
                    WHEN miles IS NULL THEN 'miles not numeric'
                    WHEN miles < 0 THEN 'negative miles'
                    ELSE 'missing permit or VIN' END,
               LEFT(CONCAT(month_label, ' = ', miles_raw), 400)
        FROM #mil
        WHERE month_start IS NULL OR miles IS NULL OR miles < 0 OR permit_number = '' OR vin = '';

        INSERT silver.dmv_mileage_monthly (permit_number, vin, manufacturer, month_start, miles)
        SELECT permit_number, vin, MAX(manufacturer), month_start, MAX(miles)   -- same VIN/month in two files -> keep one
        FROM #mil
        WHERE month_start IS NOT NULL AND miles IS NOT NULL AND miles >= 0 AND permit_number <> '' AND vin <> ''
        GROUP BY permit_number, vin, month_start;
        SET @rows = @@ROWCOUNT;
        DROP TABLE #mil;
        COMMIT;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS' WHERE load_id = @log;
        PRINT CONCAT('  silver.dmv_mileage_monthly: ', @rows);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED', message = LEFT(ERROR_MESSAGE(),2000) WHERE load_id = @log;
        THROW;
    END CATCH;

    ---------------------------------------------------------------- nhtsa_crash
    SET @t0 = SYSDATETIME();
    INSERT audit.load_log (batch_id, layer, source_name, target_table, start_time, status)
    VALUES (@batch, 'silver', 'bronze.nhtsa_sgo_ads', 'silver.nhtsa_crash', @t0, 'RUNNING');
    SET @log = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRAN;
        TRUNCATE TABLE silver.nhtsa_crash;
        DELETE FROM silver.reject_log WHERE source_table = 'nhtsa_crash';

        ;WITH b AS (
            SELECT n.*,
                   LTRIM(RTRIM(n.[Report ID])) AS rid,
                   TRY_CAST(n.[Report Version] AS INT) AS ver,
                   LTRIM(RTRIM(n.[State])) AS st,
                   -- "SEP-2026" -> "01 SEP 2026" (style 106 = dd mon yyyy)
                   TRY_CONVERT(DATE, '01 ' + REPLACE(LTRIM(RTRIM(n.[Incident Date])), '-', ' '), 106) AS inc_month,
                   TRY_CONVERT(TIME(0), LTRIM(RTRIM(n.[Incident Time (24:00)]))) AS inc_time,
                   CASE WHEN n.source_file LIKE '%archive%' THEN 1 ELSE 2 END AS file_rank,
                   JSON_VALUE(n.row_json, '$."Weather - Clear"')            AS wc,
                   JSON_VALUE(n.row_json, '$."Weather - Cloudy"')           AS wcl,
                   JSON_VALUE(n.row_json, '$."Weather - Partly Cloudy"')    AS wpc,
                   JSON_VALUE(n.row_json, '$."Weather - Rain"')             AS wr,
                   JSON_VALUE(n.row_json, '$."Weather - Snow"')             AS wsn,
                   COALESCE(JSON_VALUE(n.row_json, '$."Weather - Fog/Smoke/Haze"'),
                            JSON_VALUE(n.row_json, '$."Weather - Fog/Smoke"')) AS wf,
                   JSON_VALUE(n.row_json, '$."Weather - Dust Storm"')       AS wd,
                   JSON_VALUE(n.row_json, '$."Weather - Severe Wind"')      AS ww,
                   NULLIF(LTRIM(RTRIM(JSON_VALUE(n.row_json, '$."Same Incident ID"'))), '') AS same_incident,
                   COALESCE(JSON_VALUE(n.row_json, '$."Weather - Unknown"'),
                            JSON_VALUE(n.row_json, '$."Weather - Unk - See Narrative"')) AS wu
            FROM bronze.nhtsa_sgo_ads n
        ), v AS (   -- latest version of each report inside its file
            SELECT b.*, ROW_NUMBER() OVER (PARTITION BY rid ORDER BY ver DESC, file_rank) AS rn
            FROM b WHERE rid <> ''
        ), one AS (   -- several entities can report the same crash ("Same Incident ID"): keep one
            SELECT v.*, ROW_NUMBER() OVER (PARTITION BY file_rank, ISNULL(same_incident, rid)
                                           ORDER BY rid) AS rn_s
            FROM v WHERE rn = 1
        ), dedup AS ( -- the same crash in both files (old and new SGO numbering): keep the archive copy
            SELECT one.*, ROW_NUMBER() OVER (
                       PARTITION BY [Reporting Entity], st, LTRIM(RTRIM([City])), inc_month,
                                    ISNULL(CONVERT(VARCHAR(8), inc_time), rid)
                       ORDER BY file_rank, rid) AS rn2
            FROM one WHERE rn_s = 1
        )
        SELECT d.*,
               CASE WHEN d.wf = 'Y' OR d.wd = 'Y' THEN 'obscured'
                    WHEN d.wr = 'Y' OR d.wsn = 'Y' THEN 'rain'
                    WHEN d.wc = 'Y' OR d.wcl = 'Y' OR d.wpc = 'Y' OR d.ww = 'Y' THEN 'normal'
                    ELSE 'unknown' END AS wbucket
        INTO #crash FROM dedup d;

        INSERT silver.reject_log (source_table, source_file, source_row, reason, raw_value)
        SELECT 'nhtsa_crash', source_file, source_row_num,
               CASE WHEN rn2 > 1 THEN 'same crash already in the archive file'
                    ELSE 'unparsable incident month' END,
               LEFT(CONCAT(rid, ' | ', [Incident Date]), 400)
        FROM #crash WHERE rn2 > 1 OR inc_month IS NULL;

        INSERT silver.nhtsa_crash (report_id, report_version, source_file, reporting_entity, make, model,
               us_state, city, incident_month, incident_time, roadway_type, speed_limit_mph, lighting_raw,
               w_clear, w_cloudy, w_rain, w_snow, w_fog_smoke_haze, w_dust, w_wind, w_unknown,
               weather_bucket, is_night, in_scope)
        SELECT c.rid, c.ver, c.source_file, LTRIM(RTRIM(c.[Reporting Entity])), LTRIM(RTRIM(c.[Make])),
               LTRIM(RTRIM(c.[Model])), LEFT(c.st, 2), LTRIM(RTRIM(c.[City])), c.inc_month, c.inc_time,
               CASE WHEN c.[Roadway Type] LIKE '%Highway%' OR c.[Roadway Type] LIKE '%Freeway%' THEN 'highway_freeway'
                    WHEN c.[Roadway Type] LIKE '%Intersection%' THEN 'intersection'
                    WHEN c.[Roadway Type] LIKE '%Parking%' THEN 'parking'
                    WHEN c.[Roadway Type] LIKE '%Street%' THEN 'street'
                    ELSE 'other' END,
               TRY_CAST(LTRIM(RTRIM(c.[Posted Speed Limit (MPH)])) AS INT),
               NULLIF(LTRIM(RTRIM(c.[Lighting])), ''),
               IIF(c.wc='Y',1,0), IIF(c.wcl='Y' OR c.wpc='Y',1,0), IIF(c.wr='Y',1,0), IIF(c.wsn='Y',1,0),
               IIF(c.wf='Y',1,0), IIF(c.wd='Y',1,0), IIF(c.ww='Y',1,0), IIF(c.wu='Y',1,0),
               c.wbucket,
               -- lighting: reported field when present (archive), else sun position at the
               -- state's reference station on the 15th of the incident month (current file)
               CASE WHEN c.[Lighting] LIKE 'Daylight%' THEN 0
                    WHEN c.[Lighting] LIKE 'Dark%' OR c.[Lighting] LIKE 'Dawn%' THEN 1
                    WHEN c.inc_time IS NULL OR c.inc_month IS NULL OR s.station_id IS NULL THEN NULL
                    WHEN se.elevation_deg < -0.833 THEN 1 ELSE 0 END,
               CASE WHEN LEFT(c.st, 2) IN ('CA','AZ','TX') AND YEAR(c.inc_month) BETWEEN 2021 AND 2025 THEN 1 ELSE 0 END
        FROM #crash c
        OUTER APPLY (SELECT TOP 1 ds.station_id, ds.latitude, ds.longitude, ds.tz_name
                     FROM silver.dim_station ds WHERE ds.us_state = LEFT(c.st, 2) ORDER BY ds.station_id) s
        OUTER APPLY silver.tvf_solar_elevation(s.latitude, s.longitude,
                     CAST(DATEADD(second, DATEDIFF(second, CAST('00:00' AS TIME(0)), c.inc_time),
                                  DATEADD(day, 14, CAST(c.inc_month AS DATETIME2(0))))
                          AT TIME ZONE COALESCE(s.tz_name, 'UTC') AT TIME ZONE 'UTC' AS DATETIME2(0))) se
        WHERE c.rn2 = 1 AND c.inc_month IS NOT NULL;
        SET @rows = @@ROWCOUNT;
        DROP TABLE #crash;
        COMMIT;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), rows_loaded = @rows, status = 'SUCCESS' WHERE load_id = @log;
        PRINT CONCAT('  silver.nhtsa_crash: ', @rows);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        UPDATE audit.load_log SET end_time = SYSDATETIME(), status = 'FAILED', message = LEFT(ERROR_MESSAGE(),2000) WHERE load_id = @log;
        THROW;
    END CATCH;
END
GO

PRINT 'Silver objects created.';
GO
