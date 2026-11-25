# Data sources (all real, none generated)

Raw files live in `Data/raw/` (not in Git — `Data/` is ignored). Each download folder has a `MANIFEST.csv`
with the SHA-256 of every file.

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

| Folder in `Data/raw/` | Source | Files | Link |
|---|---|---|---|
| `noaa_global_hourly/<year>/` | NOAA NCEI Global Hourly (Integrated Surface Database), station CSVs 2021–2025 | 85 (17 stations × 5 years) | https://www.ncei.noaa.gov/data/global-hourly/access/ (mirror: `noaa-global-hourly-pds` on AWS) |
| `gastat/` | GASTAT — Land Transport Statistics 2022, 2023; Road Transport Statistics 2024, 2025 (table workbooks) | 4 | https://www.stats.gov.sa (Transport statistics publications) |
| `ca_dmv_disengagements/` | California DMV — Autonomous Vehicle Disengagement Reports 2021–2024 (incl. driverless and first-time filers) | 8 | https://www.dmv.ca.gov/portal/vehicle-industry-services/autonomous-vehicles/ |
| `ca_dmv_mileage/` | California DMV — Autonomous Mileage Reports 2021–2024 | 8 | same |
| `nhtsa_sgo/` | NHTSA Standing General Order — ADS incident reports (archive 2021–2025 + current) and data-element definitions | 2 CSV + 2 PDF | https://www.nhtsa.gov/laws-regulations/standing-general-order-crash-reporting |

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
