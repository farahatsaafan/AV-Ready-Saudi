# Data sources (all real, none generated)

Raw files live in `Data/raw/` (not in Git — `Data/` is ignored). Every file, with its download link, source page,
size and SHA-256, is listed in [`docs/data_files_manifest.csv`](data_files_manifest.csv) and in the tables below.

## Download

**Google Drive — [New Data](https://drive.google.com/drive/folders/1hmh-0XqcQ9MZ5juEkdRgR7CMA9GsERj3):**
`AV-Ready-Saudi_Data_raw.zip` (36 MB, 114 files). Unzip it **in the project folder**; it already contains the
`Data/raw/...` paths below, so nothing has to be moved:

```
AV-Ready-Saudi/Data/raw/noaa_global_hourly/2021 ... 2025/   (17 station CSVs + MANIFEST per year)
AV-Ready-Saudi/Data/raw/gastat/                              (4 xlsx)
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
| California DMV — AV Disengagement Reports 2021–2024 (incl. driverless, first-time filers) | `ca_dmv_disengagements/` | 8 | [DMV Disengagement Reports](https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/disengagement-reports/) · [archived copy](https://web.archive.org/web/20251030174435/https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/disengagement-reports/) |
| California DMV — AV Mileage Reports 2021–2024 | `ca_dmv_mileage/` | 8 | same page as above |
| NHTSA Standing General Order — ADS incident reports (archive 2021–2025 + current) and data-element definitions | `nhtsa_sgo/` | 2 CSV + 2 PDF | [NHTSA SGO Crash Reporting](https://www.nhtsa.gov/laws-regulations/standing-general-order-crash-reporting) |

Notes on the links
- **GASTAT (stats.gov.sa)** may not open from outside Saudi Arabia; the files were downloaded from a Saudi connection.
  The publications page now shows a newer revision of the 2024 workbook; the file used is the earlier revision,
  still served at the link below.
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
