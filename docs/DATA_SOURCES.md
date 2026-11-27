# Data sources (all real, none generated)

Raw files live in `Data/raw/` (not in Git — `Data/` is ignored). Every file, with its download link, source page,
size and SHA-256, is listed in [`docs/data_files_manifest.csv`](data_files_manifest.csv) and in the tables below.

## Download

**Google Drive — [New Data](https://drive.google.com/drive/folders/1hmh-0XqcQ9MZ5juEkdRgR7CMA9GsERj3):**
`AV-Ready-Saudi_Data_raw.zip` (36 MB, 115 files). Unzip it **in the project folder**; it already contains the
`Data/raw/...` paths below, so nothing has to be moved:

```
AV-Ready-Saudi/Data/raw/noaa_global_hourly/2021 ... 2025/   (17 station CSVs + MANIFEST per year)
AV-Ready-Saudi/Data/raw/gastat/                              (4 xlsx)
AV-Ready-Saudi/Data/raw/gastat_population/                   (1 csv: Saudi Census 2022 population table)
AV-Ready-Saudi/Data/raw/ca_dmv_disengagements/               (8 csv)
AV-Ready-Saudi/Data/raw/ca_dmv_mileage/                      (8 csv)
AV-Ready-Saudi/Data/raw/nhtsa_sgo/                           (2 csv + 2 pdf)
```

The bundle holds exactly the files the pipeline reads, nothing else.

## Sources and links

Each source has two links: the **source page** (the official page the files are published on) and the **download
link** of every file (it downloads the file directly). Every download link was re-checked on 2026-11-25: each file
downloaded from it is byte-identical to the copy in the bundle (same SHA-256; NOAA: same MD5 / S3 ETag).
Full list with sizes and complete SHA-256: [`docs/data_files_manifest.csv`](data_files_manifest.csv).

| Source | Folder in `Data/raw/` | Files | Source page |
|---|---|---|---|
| NOAA NCEI Global Hourly (Integrated Surface Database) — 13 Saudi + 4 US stations, 2021–2025 | `noaa_global_hourly/<year>/` | 85 | [NCEI ISD](https://www.ncei.noaa.gov/products/land-based-station/integrated-surface-database) · [AWS Open Data mirror used for the download](https://registry.opendata.aws/noaa-isd/) |
| GASTAT — Land Transport Statistics 2022, 2023; Road Transport Statistics 2024, 2025 (table workbooks) | `gastat/` | 4 | [GASTAT Road Transport Statistics publications](https://www.stats.gov.sa/en/statistics-tabs?tab=436312&category=124894) |
| GASTAT — Saudi Census 2022: population 2010–2022 by region, nationality and gender | `gastat_population/` | 1 | [GASTAT Census 2022 — Population 2010–2022](https://www.stats.gov.sa/en/w/%D8%A7%D9%84%D8%B3%D9%83%D8%A7%D9%86-2010%D9%85-2022%D9%85-1?tab=436332&category=417653) |
| California DMV — AV Disengagement Reports 2021–2024 (incl. driverless, first-time filers) | `ca_dmv_disengagements/` | 8 | [DMV Disengagement Reports](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/disengagement-reports/) · [archived copy](https://web.archive.org/web/20251030174435/https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/disengagement-reports/) |
| California DMV — AV Mileage Reports 2021–2024 | `ca_dmv_mileage/` | 8 | same page as above |
| NHTSA Standing General Order — ADS incident reports (archive 2021–2025 + current) and data-element definitions | `nhtsa_sgo/` | 2 CSV + 2 PDF | [NHTSA SGO Crash Reporting](https://www.nhtsa.gov/laws-regulations/standing-general-order-crash-reporting) |

Notes on the links
- **GASTAT (stats.gov.sa)** may not open from outside Saudi Arabia; the files were downloaded from a Saudi connection.
  The publications page now shows a newer revision of the 2024 workbook; the file used is the earlier revision,
  still served at the link below.
- **GASTAT census population**: the page shows an interactive table (Tableau); its "Full Data" button downloads the
  CSV served at the direct link below (same file, byte for byte). The older census portal (portal.saudicensus.sa)
  no longer opens, from Egypt or from Saudi Arabia (checked 2026-11-27).
- **California DMV** removed its Disengagement Reports page in 2026 when its AV regulations changed; the file links
  still work, and the page is kept by the Internet Archive (link above, snapshot of 30 Oct 2025).
- **NOAA**: files were downloaded from NOAA's mirror on AWS Open Data (`noaa-global-hourly-pds`), which carries the
  same NCEI Global Hourly files; the mirror's 2025 files end in August 2025. The NCEI copy of the same file is
  listed in the manifest (NCEI may have newer data for 2025).
- **NHTSA** updates the "current" file regularly; the SHA-256 is of the copy used.
- Each `noaa_global_hourly/<year>/MANIFEST.csv` was written by the project at download time (bytes, SHA-256 and
  source of each station file); the other folders are covered by `docs/data_files_manifest.csv`.

## Files

### GASTAT (`gastat/`)

| File | Download | SHA-256 (first 12) |
|---|---|---|
| `GASTAT_Land_Transport_Statistics_2022_tables.xlsx` | [download](https://www.stats.gov.sa/documents/20117/2435259/Land_Transport_Statistics_table_2022-EN.xlsx_fixed_2468493/d721cf5c-4a94-12c6-9996-ac42ba0786c6?t=1734116418300) | `b4819a9c38fe` |
| `GASTAT_Land_Transport_Statistics_2023_tables.xlsx` | [download](https://www.stats.gov.sa/documents/20117/2435259/Land_Transport_Statistics_table_2023-EN.xlsx_fixed_2468469/46152dd1-80d8-25f0-029f-5dac99160917?t=1734115901531) | `bf9a605644bb` |
| `GASTAT_Road_Transport_Statistics_2024_tables.xlsx` | [download](https://www.stats.gov.sa/documents/d/guest/rroad-transport-statistics-2024_en) | `64ce979745d4` |
| `GASTAT_Road_Transport_Statistics_2025_tables.xlsx` | [download](https://www.stats.gov.sa/documents/20117/2435281/%E2%80%8F%E2%80%8F%E2%80%8F%E2%80%8FRoad+Transport+Statistics+2025+-+EN+%281%29.xlsx/ac687a27-82d7-793a-d497-c2fcbb0cbb73?t=1793612751029) | `d8a570f8d9d3` |

#### Which sheets of the GASTAT workbooks are read (all declared in `silver.gastat_sheet_map` / `gastat_traffic_map`)

No new files were added in design v2 (28 Nov 2026): traffic, the rate denominators and the region-service attributes
are further sheets of the same four workbooks that were already in Bronze.

| Content | 2022 workbook | 2023 workbook | 2024 workbook | 2025 workbook | Silver table |
|---|---|---|---|---|---|
| serious accidents, deaths, injuries (2021, 2022 in the 2022 workbook) | 17, 20 | 34, 37 | 5-1, 5-5 | 5-1-1, 5-6-1 | `accidents_region_year` |
| road density, intercity road length by type | 12, 7 | 20, 15 | 7-5, 7-2 | 7-2, 7-1-2 | `roads_region_year` |
| monthly intercity traffic by region (2021 and 2022 blocks in the 2022 workbook) | 14 | 29 | 3-5 | 3-3-1 | `traffic_region_month` |
| GASTAT's rate per 100,000 (gives its population denominator) | — | 35 (mortality) | 5-4 (serious); 5-2 (mortality, check) | 5-7 (serious); 5-2 (mortality, check) | `population_region_year` |
| ambulance response time; registered vehicles | — | — | — | 5-11; 4-1-2 | `region_service_2025` |

### GASTAT Saudi Census 2022 population (`gastat_population/`)

| File | Download | SHA-256 (first 12) |
|---|---|---|
| `GASTAT_Census2022_Population_2010_2022_by_Region_Nationality_Gender.csv` | [download](https://tableau.stats.gov.sa/views/TA9-Population2010-2022byRegionNationalityandGender_17298162510520/Population2010-2022byRegionNationalityandGenderCSV.csv) | `9de90ab01988` |

### California DMV disengagements (`ca_dmv_disengagements/`)

| File | Download | SHA-256 (first 12) |
|---|---|---|
| `CA_DMV_2021-autonomous-vehicle-disengagement-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2021-autonomous-vehicle-disengagement-reports-csv/) | `534d265b80f5` |
| `CA_DMV_2022-23-autonomous-vehicle-disengagement-reports-csvfirst-time-filers.csv` | [download](https://www.dmv.ca.gov/portal/file/2022-23-autonomous-vehicle-disengagement-reports-csvfirst-time-filers/) | `5272ff9f77dc` |
| `CA_DMV_2022-autonomous-vehicle-disengagement-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2022-autonomous-vehicle-disengagement-reports-csv/) | `449a03cbf066` |
| `CA_DMV_2023-24-autonomous-vehicle-disengagement-reports-csvfirst-time-filers.csv` | [download](https://www.dmv.ca.gov/portal/file/2023-24-autonomous-vehicle-disengagement-reports-csvfirst-time-filers/) | `0535052ead0f` |
| `CA_DMV_2023-autonomous-vehicle-disengagement-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2023-autonomous-vehicle-disengagement-reports-csv/) | `13b25ecfb3dd` |
| `CA_DMV_2023-autonomous-vehicle-disengagement-reports-csvdriverless.csv` | [download](https://www.dmv.ca.gov/portal/file/2023-autonomous-vehicle-disengagement-reports-csvdriverless/) | `6b6afdb10593` |
| `CA_DMV_2024-autonomous-vehicle-disengagement-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2024-autonomous-vehicle-disengagement-reports-csv/) | `937fcc119e87` |
| `CA_DMV_2024-autonomous-vehicle-disengagement-reports-csvdriverless.csv` | [download](https://www.dmv.ca.gov/portal/file/2024-autonomous-vehicle-disengagement-reports-csvdriverless/) | `92b76e0761ac` |

### California DMV mileage (`ca_dmv_mileage/`)

| File | Download | SHA-256 (first 12) |
|---|---|---|
| `CA_DMV_2021-autonomous-mileage-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2021-autonomous-mileage-reports-csv/) | `dacfb9dfb8f9` |
| `CA_DMV_2022-23-autonomous-mileage-reports-csvfirst-time-filers.csv` | [download](https://www.dmv.ca.gov/portal/file/2022-23-autonomous-mileage-reports-csvfirst-time-filers/) | `9d2fa2772402` |
| `CA_DMV_2022-autonomous-mileage-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2022-autonomous-mileage-reports-csv/) | `51702c1b98a5` |
| `CA_DMV_2023-24-autonomous-mileage-reports-csvfirst-time-filers.csv` | [download](https://www.dmv.ca.gov/portal/file/2023-24-autonomous-mileage-reports-csvfirst-time-filers/) | `23d532bac969` |
| `CA_DMV_2023-autonomous-mileage-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2023-autonomous-mileage-reports-csv/) | `596b8087641e` |
| `CA_DMV_2023-autonomous-mileage-reports-csvdriverless.csv` | [download](https://www.dmv.ca.gov/portal/file/2023-autonomous-mileage-reports-csvdriverless/) | `0fa710924acb` |
| `CA_DMV_2024-autonomous-mileage-reports-csv.csv` | [download](https://www.dmv.ca.gov/portal/file/2024-autonomous-mileage-reports-csv/) | `862b861a2508` |
| `CA_DMV_2024-autonomous-mileage-reports-csvdriverless.csv` | [download](https://www.dmv.ca.gov/portal/file/2024-autonomous-mileage-reports-csvdriverless/) | `2e6de109800a` |

### NHTSA SGO (`nhtsa_sgo/`)

| File | Download | SHA-256 (first 12) |
|---|---|---|
| `NHTSA_SGO_ADS_archive_2021_2025.csv` | [download](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/Archive-2021-2025/SGO-2021-01_Incident_Reports_ADS.csv) | `cb2b38a21e2c` |
| `NHTSA_SGO_ADS_current.csv` | [download](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/SGO-2021-01_Incident_Reports_ADS.csv) | `326809a7d375` |
| `NHTSA_SGO_Data_Element_Definitions_archive_2021_2025.pdf` | [download](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/Archive-2021-2025/SGO-2021-01_Data_Element_Definitions.pdf) | `df7569df7b72` |
| `NHTSA_SGO_Data_Element_Definitions_current.pdf` | [download](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/SGO-2021-01_Data_Element_Definitions.pdf) | `8c01355d4851` |

### NOAA Global Hourly (`noaa_global_hourly/<year>/<station id>__<name>.csv`)

One file per station per year; each cell downloads that file from the AWS mirror.

| Station file name | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|
| `40357099999__SA_NBR_Arar` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40357099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40357099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40357099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40357099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40357099999.csv) |
| `40361099999__SA_JOF_AlJouf` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40361099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40361099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40361099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40361099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40361099999.csv) |
| `40375099999__SA_TAB_Tabuk` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40375099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40375099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40375099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40375099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40375099999.csv) |
| `40394099999__SA_HAI_Hail` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40394099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40394099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40394099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40394099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40394099999.csv) |
| `40405099999__SA_QAS_Gassim` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40405099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40405099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40405099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40405099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40405099999.csv) |
| `40415099999__SA_EAS_Dammam_KFIA` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40415099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40415099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40415099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40415099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40415099999.csv) |
| `40430099999__SA_MED_Madinah` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40430099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40430099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40430099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40430099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40430099999.csv) |
| `40437099999__SA_RIY_Riyadh_KKIA` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/40437099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/40437099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/40437099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/40437099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/40437099999.csv) |
| `41024099999__SA_MAK_Jeddah_KAIA` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/41024099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/41024099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/41024099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/41024099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/41024099999.csv) |
| `41055099999__SA_BAH_AlBaha` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/41055099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/41055099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/41055099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/41055099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/41055099999.csv) |
| `41112099999__SA_ASR_Abha` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/41112099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/41112099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/41112099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/41112099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/41112099999.csv) |
| `41128099999__SA_NAJ_Najran` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/41128099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/41128099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/41128099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/41128099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/41128099999.csv) |
| `41140099999__SA_JAZ_Jazan` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/41140099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/41140099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/41140099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/41140099999.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/41140099999.csv) |
| `72254013904__US_TX_Austin_AUS` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/72254013904.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/72254013904.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/72254013904.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/72254013904.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/72254013904.csv) |
| `72278023183__US_AZ_Phoenix_PHX` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/72278023183.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/72278023183.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/72278023183.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/72278023183.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/72278023183.csv) |
| `72295023174__US_CA_LosAngeles_LAX` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/72295023174.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/72295023174.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/72295023174.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/72295023174.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/72295023174.csv) |
| `72494023234__US_CA_SanFrancisco_SFO` | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2021/72494023234.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2022/72494023234.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2023/72494023234.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2024/72494023234.csv) | [csv](https://noaa-global-hourly-pds.s3.amazonaws.com/2025/72494023234.csv) |


## All links used in the project

Every web address the project has used, from the first design to now. Each source has its **source page** (where the
data is published) and its **download link** (the file itself).

### A. Sources in use (in the data bundle)

| Source | Source page | Download link(s) |
|---|---|---|
| NOAA NCEI Global Hourly (ISD) | [NCEI ISD](https://www.ncei.noaa.gov/products/land-based-station/integrated-surface-database) · [AWS Open Data registry](https://registry.opendata.aws/noaa-isd/) | `https://noaa-global-hourly-pds.s3.amazonaws.com/<year>/<station id>.csv` (used) · official copy `https://www.ncei.noaa.gov/data/global-hourly/access/<year>/<station id>.csv` — every file is listed above |
| GASTAT Road / Land Transport Statistics 2022–2025 | [GASTAT Road Transport Statistics publications](https://www.stats.gov.sa/en/statistics-tabs?tab=436312&category=124894) | one link per workbook in the GASTAT table above |
| GASTAT Saudi Census 2022 population | [Population 2010–2022](https://www.stats.gov.sa/en/w/%D8%A7%D9%84%D8%B3%D9%83%D8%A7%D9%86-2010%D9%85-2022%D9%85-1?tab=436332&category=417653) | [CSV](https://tableau.stats.gov.sa/views/TA9-Population2010-2022byRegionNationalityandGender_17298162510520/Population2010-2022byRegionNationalityandGenderCSV.csv) |
| California DMV AV disengagement + mileage reports | [DMV Disengagement Reports](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/disengagement-reports/) (removed in 2026) · [archived copy](https://web.archive.org/web/20251030174435/https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/disengagement-reports/) · [DMV Autonomous Vehicles](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/) | `https://www.dmv.ca.gov/portal/file/<report name>/` — every file is listed above |
| NHTSA Standing General Order — ADS incident reports | [NHTSA SGO Crash Reporting](https://www.nhtsa.gov/laws-regulations/standing-general-order-crash-reporting) | [current CSV](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/SGO-2021-01_Incident_Reports_ADS.csv) · [archive 2021–2025 CSV](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/Archive-2021-2025/SGO-2021-01_Incident_Reports_ADS.csv) · [definitions (current)](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/SGO-2021-01_Data_Element_Definitions.pdf) · [definitions (archive)](https://static.nhtsa.gov/odi/ffdd/sgo-2021-01/Archive-2021-2025/SGO-2021-01_Data_Element_Definitions.pdf) |
| Project data bundle | [Google Drive — New Data](https://drive.google.com/drive/folders/1hmh-0XqcQ9MZ5juEkdRgR7CMA9GsERj3) | `AV-Ready-Saudi_Data_raw.zip` |

### B. Sources considered and dropped (not in the bundle, not loaded)

| Source | Source page | Download link | Why it was dropped |
|---|---|---|---|
| KAPSARC — Saudi traffic accidents and casualties by region | [dataset (by region)](https://data.kapsarc.org/explore/dataset/saudi-traffic-accidents-and-casualties-by-region/) · [dataset (injured / dead, since 2008)](https://data.kapsarc.org/explore/dataset/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/) | [CSV export](https://datasource.kapsarc.org/api/explore/v2.1/catalog/datasets/saudi-arabia-traffic-accidents-and-casualties-injured-dead-2008/exports/csv) | 2016–2019 only, outside 2021–2025; counts all accidents, so not comparable with GASTAT's serious accidents |
| UK DfT road safety data (STATS19) | [data.gov.uk dataset](https://www.data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-accidents-safety-data) · [GOV.UK road safety statistics](https://www.gov.uk/government/collections/road-safety-statistics) | e.g. [collisions 2023 CSV](https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-2023.csv) | accidents must be Saudi only; UK is not where the AV data comes from |
| Open-Meteo historical weather (ERA5-based) | [Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api) | `https://archive-api.open-meteo.com/v1/archive?...` | computed by a weather model, not measured by a station |
| Open-Meteo air quality (CAMS dust) | [Air Quality API](https://open-meteo.com/en/docs/air-quality-api) | `https://air-quality-api.open-meteo.com/v1/air-quality?...&hourly=dust` | computed by an atmosphere model (CAMS), not measured; starts August 2022 |
| Copernicus ERA5 reanalysis | [ERA5 single levels](https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels) | (account required) | model output; replaced by NOAA station observations |
| OpenStreetMap GCC extract (Geofabrik) | [Geofabrik — GCC States](https://download.geofabrik.de/asia/gcc-states.html) | [gcc-states-latest.osm.pbf](https://download.geofabrik.de/asia/gcc-states/gcc-states-latest.osm.pbf) | road geometry not needed by the region × month design; GASTAT road tables used instead |
| Saudi Open Data portal (MOI traffic, Red Crescent, MOH, NTSC) | [open.data.gov.sa](https://open.data.gov.sa/) | per dataset on the portal | MOI tables are 1437–1439 H (2016–2018); the rest are national totals or very small; GASTAT already covers 2021–2025 |
| National Center for Meteorology | [ncm.gov.sa](https://ncm.gov.sa/) | — | the portal files are bulletin counts, not weather measurements |
| California DMV AV collision reports | [DMV collision reports](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/autonomous-vehicle-collision-reports/) · [Berkeley TIMS AV safety viewer](https://tims.berkeley.edu/tools/avsafety.php) | — | PDF forms without structured weather; NHTSA SGO used instead |
| Saudi census portal | [portal.saudicensus.sa](https://portal.saudicensus.sa/portal) | — | no longer opens; the same census table is taken from the GASTAT site (section A) |
| Microsoft predictive-maintenance sample (old design) | [microsoft/sqlworkshops](https://github.com/microsoft/sqlworkshops/blob/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv) | [PdM_telemetry.csv](https://raw.githubusercontent.com/microsoft/sqlworkshops/master/SQLServerAndAzureMachineLearning/ML%20Services%20for%20SQL%20Server/data/PdM_telemetry.csv) | not AV data; used only to calibrate the generated telemetry of the old design, which was removed |

### C. Tools and infrastructure

| What | Link |
|---|---|
| Repository | [github.com/farahatsaafan/AV-Ready-Saudi](https://github.com/farahatsaafan/AV-Ready-Saudi) |
| SQL Server 2022 container image (macOS / Linux) | `mcr.microsoft.com/mssql/server:2022-latest` · [Microsoft Learn — run SQL Server Linux containers](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker) |

## Stations

| Region | Station | ID |
|---|---|---|
| Riyadh | King Khalid Intl | 40437099999 |
| Makkah | Jeddah King Abdulaziz Intl | 41024099999 |
| Madinah | Prince Mohammad bin Abdulaziz | 40430099999 |
| Eastern Province | Dammam King Fahd Intl | 40415099999 |
| Qassim | Gassim | 40405099999 |
| Hail | Hail | 40394099999 |
| Tabuk | Tabuk | 40375099999 |
| Northern Borders | Arar | 40357099999 |
| Al-Jouf | Al-Jouf | 40361099999 |
| Aseer | Abha | 41112099999 |
| Al-Baha | Al-Baha | 41055099999 |
| Najran | Najran | 41128099999 |
| Jazan | King Abdullah, Jazan | 41140099999 |
| US — California | Los Angeles (LAX), San Francisco (SFO) | 72295023174, 72494023234 |
| US — Arizona | Phoenix (PHX) | 72278023183 |
| US — Texas | Austin (AUS) | 72254013904 |

Notes
- NOAA data for Saudi stations are the stations' own observations (METAR/SYNOP) archived by NOAA.
- The NOAA mirror used ends in August 2025.
- Considered and dropped (not in the bundle, not loaded): KAPSARC accidents (2016–2019, outside the 2021–2025
  range), UK DfT STATS19 (accidents must be Saudi only), Open-Meteo and CAMS (computed by weather / atmosphere
  models, not measured by a station), OSM road extract (not used by the design).

See `docs/05_relations_and_lineage.md` for how the sources relate and reach the single Gold table.
