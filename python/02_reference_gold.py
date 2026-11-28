"""
AV-Ready-Saudi - independent reference build of Silver -> prep -> Gold in pandas (condition vocabulary v2).

Purpose: a second implementation of the same rules as sql/02_silver.sql and sql/03_gold.sql, used to
(1) check the SQL results after a run (--compare) and (2) report the data shares. It reads the same
Data/landing/*.tsv files the SQL pipeline loads. The functions are also imported (importlib) by
python/04_av_evidence_models.py and python/05_readiness_model.py, so every rule lives in one place.

Outputs (Data/reference/):
  gold_reference.csv     the expected Gold table (same columns as gold.av_readiness_region_month)
  relative_risk.csv      the expected prep.av_relative_risk (Mantel-Haenszel, with 95 % CI)
  counts.csv             expected row counts per Bronze / Silver / prep / Gold table
  data_shares.csv        how much each data family contributes
  traffic_region_month.csv, population_region_year.csv, region_service_2025.csv   expected Silver tables
  us_hours.csv, ca_days.csv, nhtsa_cells.csv, dmv_days.csv                       inputs of the AV evidence

Usage:
  python3 python/02_reference_gold.py              build the reference
  python3 python/02_reference_gold.py --compare    compare Data/gold_export/*.csv (SQL Gold) with the reference
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
LAND = ROOT / "Data" / "landing"
OUT = ROOT / "Data" / "reference"
EXPORT = ROOT / "Data" / "gold_export" / "gold_av_readiness_region_month.csv"

STATIONS = pd.DataFrame([
    ("40437099999", "SA", "RIY", None, "Asia/Riyadh", 24.958, 46.699),
    ("41024099999", "SA", "MAK", None, "Asia/Riyadh", 21.680, 39.157),
    ("40430099999", "SA", "MED", None, "Asia/Riyadh", 24.553, 39.705),
    ("40415099999", "SA", "EAS", None, "Asia/Riyadh", 26.433, 49.800),
    ("40405099999", "SA", "QAS", None, "Asia/Riyadh", 26.300, 43.767),
    ("40394099999", "SA", "HAI", None, "Asia/Riyadh", 27.438, 41.686),
    ("40375099999", "SA", "TAB", None, "Asia/Riyadh", 28.365, 36.619),
    ("40357099999", "SA", "NBR", None, "Asia/Riyadh", 30.907, 41.138),
    ("40361099999", "SA", "JOF", None, "Asia/Riyadh", 29.785, 40.100),
    ("41112099999", "SA", "ASR", None, "Asia/Riyadh", 18.240, 42.657),
    ("41055099999", "SA", "BAH", None, "Asia/Riyadh", 20.296, 41.634),
    ("41128099999", "SA", "NAJ", None, "Asia/Riyadh", 17.611, 44.419),
    ("41140099999", "SA", "JAZ", None, "Asia/Riyadh", 16.901, 42.586),
    ("72295023174", "US", None, "CA", "America/Los_Angeles", 33.938, -118.387),
    ("72494023234", "US", None, "CA", "America/Los_Angeles", 37.620, -122.365),
    ("72278023183", "US", None, "AZ", "America/Phoenix", 33.428, -112.004),
    ("72254013904", "US", None, "TX", "America/Chicago", 30.183, -97.680),
], columns=["station_id", "country", "region_code", "us_state", "tz", "lat", "lon"])
REGIONS = ["RIY", "MAK", "MED", "EAS", "QAS", "HAI", "TAB", "NBR", "JOF", "ASR", "BAH", "NAJ", "JAZ"]

REGION_ALIAS = {"riyadh": "RIY", "makkah": "MAK", "madinah": "MED", "eastern": "EAS", "qassim": "QAS",
                "hail": "HAI", "tabuk": "TAB", "northernborders": "NBR", "aljouf": "JOF", "aseer": "ASR",
                "albaha": "BAH", "najran": "NAJ", "jazan": "JAZ",
                # Saudi Census 2022 spellings
                "arriyadh": "RIY", "makkahalmukarramah": "MAK", "almadinahalmunawwarah": "MED",
                "alqaseem": "QAS", "aljawf": "JOF", "albahah": "BAH",
                # GASTAT 2022 traffic table header
                "ryiadh": "RIY"}

# ---- every GASTAT sheet the warehouse reads (same rows as silver.gastat_sheet_map) ----------------
# (file key, sheet, metric, year, column, first row, last row)
SHEET_MAP = [
    ("Land_Transport_Statistics_2022", "17", "injuries", 2021, 3, 8, 20),
    ("Land_Transport_Statistics_2022", "17", "injuries", 2022, 4, 8, 20),
    ("Land_Transport_Statistics_2022", "17", "deaths", 2021, 6, 8, 20),
    ("Land_Transport_Statistics_2022", "17", "deaths", 2022, 7, 8, 20),
    ("Land_Transport_Statistics_2022", "20", "serious", 2021, 2, 8, 20),
    ("Land_Transport_Statistics_2022", "20", "serious", 2022, 3, 8, 20),
    ("Land_Transport_Statistics_2023", "34", "injuries", 2023, 2, 7, 19),
    ("Land_Transport_Statistics_2023", "34", "deaths", 2023, 3, 7, 19),
    ("Land_Transport_Statistics_2023", "37", "serious", 2023, 2, 7, 19),
    ("Road_Transport_Statistics_2024", "5-1", "injuries", 2024, 2, 7, 19),
    ("Road_Transport_Statistics_2024", "5-1", "deaths", 2024, 3, 7, 19),
    ("Road_Transport_Statistics_2024", "5-5", "serious_within", 2024, 2, 7, 19),
    ("Road_Transport_Statistics_2024", "5-5", "serious_outside", 2024, 3, 7, 19),
    ("Road_Transport_Statistics_2024", "5-5", "serious", 2024, 4, 7, 19),
    ("Road_Transport_Statistics_2025", "5-1-1", "injuries", 2025, 2, 7, 19),
    ("Road_Transport_Statistics_2025", "5-1-1", "deaths", 2025, 3, 7, 19),
    ("Road_Transport_Statistics_2025", "5-6-1", "serious_within", 2025, 2, 7, 19),
    ("Road_Transport_Statistics_2025", "5-6-1", "serious_outside", 2025, 3, 7, 19),
]
# GASTAT's own rates per 100,000 population: the published denominator of 2023-2025 is recovered from them
RATE_MAP = [
    ("Land_Transport_Statistics_2023", "35", "official_deaths_per_100k", 2023, 2, 7, 19),
    ("Road_Transport_Statistics_2024", "5-4", "official_serious_per_100k", 2024, 2, 7, 19),
    ("Road_Transport_Statistics_2025", "5-7", "official_serious_per_100k", 2025, 2, 7, 19),
    ("Road_Transport_Statistics_2024", "5-2", "official_deaths_per_100k", 2024, 2, 7, 19),   # cross-check only
    ("Road_Transport_Statistics_2025", "5-2", "official_deaths_per_100k", 2025, 4, 8, 20),   # cross-check only
]
# which rate gives the population of each year (the others are a reconciliation)
POP_BASIS = {2023: ("deaths", "official_deaths_per_100k"),
             2024: ("serious", "official_serious_per_100k"),
             2025: ("serious", "official_serious_per_100k")}
SERVICE_MAP = [
    ("Road_Transport_Statistics_2025", "5-11", "response_within_cities", 2025, 3, 7, 19),
    ("Road_Transport_Statistics_2025", "5-11", "response_outside_cities", 2025, 4, 7, 19),
    ("Road_Transport_Statistics_2025", "4-1-2", "registered_vehicles", 2025, 2, 7, 19),
]
# monthly intercity traffic (Average Daily Traffic / Total traffic by month and region)
#  layout car_truck: one region per column pair (Car, Truck), region names on header_row, months on rows
#  layout region_rows: one region per row (label col 1), col 2 = count points, cols 3-14 = Jan-Dec totals
TRAFFIC_MAP = [
    ("Land_Transport_Statistics_2022", "14", 2021, "car_truck", 25, 27, 38),
    ("Land_Transport_Statistics_2022", "14", 2022, "car_truck", 6, 8, 19),
    ("Land_Transport_Statistics_2023", "29", 2023, "region_rows", 7, 8, 20),
    ("Road_Transport_Statistics_2024", "3-5", 2024, "region_rows", 7, 8, 20),
    ("Road_Transport_Statistics_2025", "3-3-1", 2025, "region_rows", 7, 8, 20),
]
# Road network by region (2021 has no road tables: the 2022 publication covers 2022 only)
ROAD_MAP = []
for _y, _key, _dens, _len in [(2022, "Land_Transport_Statistics_2022", "12", "7"),
                              (2023, "Land_Transport_Statistics_2023", "20", "15"),
                              (2024, "Road_Transport_Statistics_2024", "7-5", "7-2"),
                              (2025, "Road_Transport_Statistics_2025", "7-2", "7-1-2")]:
    ROAD_MAP += [(_key, _dens, "density_km_per_person", _y, 2, 7, 19),
                 (_key, _dens, "density_km_per_km2", _y, 3, 7, 19),
                 (_key, _len, "intercity_highway_km", _y, 2, 7, 19),
                 (_key, _len, "intercity_dual_km", _y, 3, 7, 19),
                 (_key, _len, "intercity_exit_km", _y, 4, 7, 19),
                 (_key, _len, "intercity_single_km", _y, 5, 7, 19)]
BAD_Q = set("2367")

# ---- condition vocabulary v2 (same rows as silver.dim_condition) ----------------------------------
WEATHER_CONDITIONS = ["dust", "haze_dry", "fog_moist", "rain", "normal"]   # priority order
FOG_SPREAD_C = 2.5          # temperature - dew point <= 2.5 degC in the hour = moist (fog / mist)
EVIDENCE_MIN_EVENTS = 30    # evidence rule: >= 30 events AND 95 % CI lower bound > 1


def read_tsv(name: str) -> pd.DataFrame:
    return pd.read_csv(LAND / name, sep="\t", dtype=str, keep_default_na=False, quoting=3,
                       na_filter=False, engine="c", encoding="utf-16")


def region_key(label: str) -> str:
    k = str(label).strip().lower().replace("region", "").replace("province", "")
    return k.replace(" ", "").replace("-", "").replace("\xa0", "")


def sql_round(x, nd: int = 0):
    """ROUND() as SQL Server does it for positive numbers (half away from zero)."""
    f = 10.0 ** nd
    return np.floor(np.asarray(x, dtype=float) * f + 0.5) / f


def solar_elevation(lat, lon, utc: pd.Series) -> np.ndarray:
    doy = utc.dt.dayofyear.to_numpy()
    hr = utc.dt.hour.to_numpy()
    mins = hr * 60.0 + utc.dt.minute.to_numpy()
    g = 2 * math.pi / 365.0 * (doy - 1 + (hr - 12) / 24.0)
    decl = (0.006918 - 0.399912 * np.cos(g) + 0.070257 * np.sin(g) - 0.006758 * np.cos(2 * g)
            + 0.000907 * np.sin(2 * g) - 0.002697 * np.cos(3 * g) + 0.00148 * np.sin(3 * g))
    eqt = 229.18 * (0.000075 + 0.001868 * np.cos(g) - 0.032077 * np.sin(g)
                    - 0.014615 * np.cos(2 * g) - 0.040849 * np.sin(2 * g))
    ha = np.radians(((mins + eqt + 4.0 * lon) / 4.0) - 180.0)
    la = np.radians(lat)
    v = np.clip(np.sin(la) * np.sin(decl) + np.cos(la) * np.cos(decl) * np.cos(ha), -1, 1)
    return 90.0 - np.degrees(np.arccos(v))


def to_num(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s, errors="coerce")


# ============================================================================= Silver: weather
def silver_weather(counts: dict) -> pd.DataFrame:
    b = read_tsv("noaa_hourly.tsv")
    counts["bronze.noaa_hourly"] = len(b)
    b["STATION"] = b["STATION"].str.strip()
    b["REPORT_TYPE"] = b["REPORT_TYPE"].str.strip()
    b["obs_utc"] = pd.to_datetime(b["DATE"], format="%Y-%m-%dT%H:%M:%S", errors="coerce")
    b = b[b["obs_utc"].notna() & ~b["REPORT_TYPE"].isin(["SOD", "SOM"])]
    b = b.merge(STATIONS, left_on="STATION", right_on="station_id")
    b["rownum"] = to_num(b["source_row_num"])
    b = b.sort_values("rownum").drop_duplicates(["STATION", "DATE", "REPORT_TYPE"], keep="first")

    def fixed(col, a, n):
        return b[col].str.slice(a, a + n)
    vis = to_num(fixed("VIS", 0, 6)).where(~fixed("VIS", 7, 1).isin(BAD_Q))
    b["vis_m"] = vis.where(vis != 999999)
    t = to_num(fixed("TMP", 0, 5)).where(~fixed("TMP", 6, 1).isin(BAD_Q))
    b["temp_c"] = t.where(t != 9999) / 10.0
    # DEW: +tttt,q exactly like TMP (tenths of degC; +9999 = missing; q 2/3/6/7 = suspect/erroneous)
    dw = to_num(fixed("DEW", 0, 5)).where(~fixed("DEW", 6, 1).isin(BAD_Q))
    b["dew_c"] = dw.where(dw != 9999) / 10.0
    # rounded to 0.1 degC like the SQL DECIMAL(5,1) (25.3 - 22.8 would be 2.5000000000000036 in float)
    b["dew_spread_c"] = (b["temp_c"] - b["dew_c"]).round(1)
    w = to_num(fixed("WND", 8, 4)).where(~fixed("WND", 13, 1).isin(BAD_Q))
    b["wind_ms"] = w.where(w != 9999) / 10.0
    aa = b["AA1"]
    b["precip_1h_mm"] = (to_num(aa.str.slice(3, 7)) / 10.0).where(
        (aa.str.slice(0, 2) == "01") & (aa.str.slice(3, 7) != "9999") & ~aa.str.slice(10, 11).isin(BAD_Q))
    mw = b["MW1"].str.slice(0, 2); aw = b["AW1"].str.slice(0, 2)
    aup = b["AU1"].str.slice(4, 6); auo = b["AU1"].str.slice(7, 8); aut = b["AU1"].str.slice(9, 10)
    b["is_dust"] = mw.isin(["06", "07", "08", "09", "30", "31", "32", "33", "34", "35"]) | auo.isin(["5", "6"]) | aut.isin(["1", "4", "5"])
    b["is_haze"] = mw.isin(["04", "05"]) | aw.isin(["04", "05"]) | auo.isin(["3", "7"])
    b["is_fog"] = mw.between("40", "49") & (mw != "") | aw.between("30", "35") & (aw != "") | (auo == "2")
    b["is_rain"] = ((mw.between("50", "69") | mw.between("80", "99")) & (mw != "")) | \
                   ((aw.between("40", "69") | aw.between("80", "89")) & (aw != "")) | \
                   aup.isin(["01", "02", "09"]) | (b["precip_1h_mm"] > 0)
    b["is_low_vis"] = b["vis_m"] < 5000
    b["is_hot40"] = b["temp_c"] >= 40
    b["is_hot45"] = b["temp_c"] >= 45
    out = []
    for sid, g in b.groupby("station_id"):
        st = STATIONS.set_index("station_id").loc[sid]
        g = g.copy()
        g["sun"] = solar_elevation(st.lat, st.lon, g["obs_utc"])
        g["obs_local"] = g["obs_utc"].dt.tz_localize("UTC").dt.tz_convert(st.tz).dt.tz_localize(None)
        out.append(g)
    b = pd.concat(out)
    b["is_night"] = b["sun"] < -0.833
    b = b[b["obs_local"].dt.year.between(2021, 2025)]
    counts["silver.weather_obs"] = len(b)
    keep = ["station_id", "country", "region_code", "us_state", "obs_utc", "obs_local", "report_type_",
            "vis_m", "temp_c", "dew_c", "dew_spread_c", "wind_ms", "precip_1h_mm", "is_dust", "is_haze",
            "is_fog", "is_rain", "is_low_vis", "is_night", "is_hot40", "is_hot45"]
    b["report_type_"] = b["REPORT_TYPE"]
    return b[keep].reset_index(drop=True)


def day_type(dust, haze_dry, fog_moist, rain):
    """silver.fn_day_type: >= 3 obscured hours (dust + haze_dry + fog_moist) -> the largest of the three
    (ties: dust > haze_dry > fog_moist); else rain if >= 1 rain hour; else normal."""
    dust, haze_dry, fog_moist, rain = (np.asarray(x) for x in (dust, haze_dry, fog_moist, rain))
    top = np.where((dust >= haze_dry) & (dust >= fog_moist), "dust",
                   np.where(haze_dry >= fog_moist, "haze_dry", "fog_moist"))
    return np.where(dust + haze_dry + fog_moist >= 3, top, np.where(rain >= 1, "rain", "normal"))


def prep_hours(wx: pd.DataFrame, fog_spread_c: float = FOG_SPREAD_C) -> tuple[pd.DataFrame, pd.DataFrame]:
    """prep.weather_station_hour and prep.weather_station_day (v2 vocabulary)."""
    wx = wx.copy()
    wx["hour_local"] = wx["obs_local"].dt.floor("h")
    wx["obsc"] = wx["is_dust"] | wx["is_haze"] | wx["is_fog"] | wx["is_low_vis"]
    h = wx.groupby(["station_id", "hour_local"]).agg(
        n_reports=("temp_c", "size"), temp_c=("temp_c", "mean"), temp_max_c=("temp_c", "max"),
        wind_max_ms=("wind_ms", "max"), precip_mm=("precip_1h_mm", "max"),
        dew_spread_c=("dew_spread_c", "mean"), min_dew_spread_c=("dew_spread_c", "min"),
        is_dust=("is_dust", "max"), is_haze=("is_haze", "max"), is_fog=("is_fog", "max"),
        is_low_vis=("is_low_vis", "max"), is_obscured=("obsc", "max"), is_rain=("is_rain", "max"),
        is_hot40=("is_hot40", "max"), is_hot45=("is_hot45", "max"), night=("is_night", "mean")).reset_index()
    for c in ["is_dust", "is_haze", "is_fog", "is_low_vis", "is_obscured", "is_rain", "is_hot40", "is_hot45"]:
        h[c] = h[c].astype(bool)
    h["is_night"] = h["night"] >= 0.5
    moist = h["is_fog"] | (h["min_dew_spread_c"] <= fog_spread_c)
    h["is_fog_moist"] = h["is_obscured"] & ~h["is_dust"] & moist
    h["is_haze_dry"] = h["is_obscured"] & ~h["is_dust"] & ~h["is_fog_moist"]
    h["hour_bucket"] = np.select([h["is_dust"], h["is_haze_dry"], h["is_fog_moist"], h["is_rain"]],
                                 ["dust", "haze_dry", "fog_moist", "rain"], "normal")
    h["local_date"] = h["hour_local"].dt.normalize()
    for c in WEATHER_CONDITIONS:
        h["_" + c] = h["hour_bucket"] == c
    d = h.groupby(["station_id", "local_date"]).agg(
        hours_observed=("hour_bucket", "size"), dust_hours=("_dust", "sum"), haze_dry_hours=("_haze_dry", "sum"),
        fog_moist_hours=("_fog_moist", "sum"), rain_hours=("_rain", "sum"), normal_hours=("_normal", "sum"),
        obscured_hours=("is_obscured", "sum")).reset_index()
    h = h.drop(columns=["_" + c for c in WEATHER_CONDITIONS])
    d["day_type"] = day_type(d["dust_hours"], d["haze_dry_hours"], d["fog_moist_hours"], d["rain_hours"])
    return h, d


# ============================================================================= Silver: GASTAT
_CELLS: pd.DataFrame | None = None


def gastat_cells(counts: dict | None = None) -> pd.DataFrame:
    global _CELLS
    if _CELLS is None:
        c = read_tsv("gastat_cells.tsv")
        c["r"] = to_num(c["row_num"]); c["col"] = to_num(c["col_num"])
        _CELLS = c
    if counts is not None:
        counts["bronze.gastat_cells"] = len(_CELLS)
    return _CELLS


def _sheet(key: str, sheet: str) -> pd.DataFrame:
    c = gastat_cells()
    return c[c["source_file"].str.contains(key, regex=False) & (c["sheet_name"] == sheet)]


def _region_values(spec: list, numeric: bool = True) -> pd.DataFrame:
    """Read (region label in column 1, value in column col) for every row of each map entry."""
    rows = []
    for key, sheet, metric, year, col, r0, r1 in spec:
        s = _sheet(key, sheet)
        v = s[(s["col"] == col) & s["r"].between(r0, r1)]
        lbl = s[s["col"] == 1].set_index("r")["cell_value"]
        for _, x in v.iterrows():
            raw = x["cell_value"]
            val = pd.to_numeric(raw.replace(",", "").replace(" ", ""), errors="coerce") if numeric else raw.strip()
            rows.append((REGION_ALIAS.get(region_key(lbl.get(x["r"], ""))), year, metric, val, x["source_file"]))
    a = pd.DataFrame(rows, columns=["region_code", "year", "metric", "v", "file"])
    bad = a[a["region_code"].isna() | a["v"].isna()]
    assert bad.empty, bad
    return a


def silver_accidents(counts: dict) -> pd.DataFrame:
    gastat_cells(counts)
    a = _region_values(SHEET_MAP)
    a["v"] = a["v"].astype(float).astype(int)
    p = a.pivot_table(index=["region_code", "year"], columns="metric", values="v", aggfunc="max").reset_index()
    p["serious"] = p["serious"].fillna(p["serious_within"] + p["serious_outside"])
    files = a.groupby(["region_code", "year"])["file"].agg(
        lambda s: "; ".join(sorted(set(f.replace("gastat/", "") for f in s))))
    p = p.merge(files.rename("source_files").reset_index(), on=["region_code", "year"])
    counts["silver.accidents_region_year"] = len(p)
    return p


def silver_roads(counts: dict) -> pd.DataFrame:
    a = _region_values(ROAD_MAP)
    p = a.pivot_table(index=["region_code", "year"], columns="metric", values="v", aggfunc="max").reset_index()
    p["intercity_total_km"] = p[["intercity_highway_km", "intercity_dual_km", "intercity_exit_km",
                                 "intercity_single_km"]].sum(axis=1)
    p["road_km_per_1000_people"] = p["density_km_per_person"] * 1000
    p["intercity_divided_share"] = (p["intercity_highway_km"] + p["intercity_dual_km"]) / p["intercity_total_km"]
    counts["silver.roads_region_year"] = len(p)
    return p


def official_rates() -> pd.DataFrame:
    return _region_values(RATE_MAP)


def silver_population(counts: dict, acc: pd.DataFrame) -> pd.DataFrame:
    """Census table rows (2010-2022) + GASTAT's own denominator for 2023-2025, recovered from its
    published rates: population = count x 100,000 / published rate (arithmetic on official numbers)."""
    b = read_tsv("gastat_population.tsv")
    counts["bronze.gastat_population"] = len(b)
    b["region_code"] = b["Region"].map(region_key).map(REGION_ALIAS)
    digits = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
    b["year"] = pd.to_numeric(b["Year"].str.strip().str.translate(digits), errors="coerce")
    b["n"] = pd.to_numeric(b["Population"].str.replace(",", ""), errors="coerce")
    assert b[["region_code", "year", "n"]].notna().all().all()
    p = b.groupby(["region_code", "year"]).agg(population=("n", "sum")).reset_index()
    p["year"] = p["year"].astype(int)
    p["population_basis"] = "census_2022_table"
    p["basis_detail"] = "GASTAT Census 2022 table, all nationalities"
    rates = official_rates()
    imp = []
    for y, (count_col, metric) in POP_BASIS.items():
        r = rates[(rates["year"] == y) & (rates["metric"] == metric)][["region_code", "v", "file"]]
        x = r.merge(acc[acc["year"] == y][["region_code", count_col]], on="region_code")
        x["population"] = sql_round(x[count_col] * 100000.0 / x["v"]).astype(int)
        x["year"] = y
        x["population_basis"] = "gastat_rate_implied"
        sheet = [m for m in RATE_MAP if m[3] == y and m[2] == metric][0][1]
        x["basis_detail"] = f"{count_col} x 100000 / {metric} ({x['file'].iloc[0].replace('gastat/', '')} sheet {sheet})"
        imp.append(x[["region_code", "year", "population", "population_basis", "basis_detail"]])
    p = pd.concat([p] + imp, ignore_index=True).sort_values(["region_code", "year"]).reset_index(drop=True)
    counts["silver.population_region_year"] = len(p)
    return p


def silver_traffic(counts: dict) -> pd.DataFrame:
    """silver.traffic_region_month: 13 regions x 60 months of intercity traffic (GASTAT)."""
    rows = []
    for key, sheet, year, layout, hdr, r0, r1 in TRAFFIC_MAP:
        s = _sheet(key, sheet)
        if layout == "car_truck":
            head = s[(s["r"] == hdr) & (s["col"] >= 2) & (s["cell_value"].str.strip() != "")]
            for _, hc in head.iterrows():
                reg = REGION_ALIAS.get(region_key(hc["cell_value"]))
                for r in range(r0, r1 + 1):
                    car = to_num(s[(s["r"] == r) & (s["col"] == hc["col"])]["cell_value"]).iloc[0]
                    trk = to_num(s[(s["r"] == r) & (s["col"] == hc["col"] + 1)]["cell_value"]).iloc[0]
                    rows.append((reg, year, r - r0 + 1, car + trk, np.nan, np.nan, "avg_daily_per_count_point",
                                 hc["source_file"], sheet))
        else:
            for r in range(r0, r1 + 1):
                rr = s[s["r"] == r].set_index("col")["cell_value"]
                reg = REGION_ALIAS.get(region_key(rr.get(1, "")))
                pts = pd.to_numeric(rr.get(2), errors="coerce")
                for mo in range(1, 13):
                    tot = pd.to_numeric(rr.get(mo + 2), errors="coerce")
                    days = pd.Timestamp(year, mo, 1).days_in_month
                    rows.append((reg, year, mo, tot / pts / days, tot, pts, "total_div_points_days",
                                 s["source_file"].iloc[0], sheet))
    t = pd.DataFrame(rows, columns=["region_code", "year", "month", "adt_per_point", "total_vehicles", "count_points",
                                    "definition", "source_file", "source_sheet"])
    assert t["region_code"].notna().all() and t["adt_per_point"].notna().all(), t[t.isna().any(axis=1)]
    t["month_start"] = pd.to_datetime(dict(year=t["year"], month=t["month"], day=1))
    t["traffic_month_index"] = t["adt_per_point"] / t.groupby(["region_code", "year"])["adt_per_point"].transform("mean")
    counts["silver.traffic_region_month"] = len(t)
    return t


def silver_region_service(counts: dict) -> pd.DataFrame:
    a = _region_values(SERVICE_MAP[:2], numeric=False)
    mmss = a["v"].str.split(":", expand=True).astype(int)
    a["v"] = mmss[0] * 60 + mmss[1]
    v = _region_values(SERVICE_MAP[2:])
    s = pd.concat([a, v]).pivot_table(index="region_code", columns="metric", values="v", aggfunc="max").reset_index()
    s = s.rename(columns={"response_within_cities": "response_within_s", "response_outside_cities": "response_outside_s"})
    counts["silver.region_service_2025"] = len(s)
    return s


# ============================================================================= Silver: DMV / NHTSA
def silver_dmv(counts: dict) -> tuple[pd.DataFrame, pd.DataFrame]:
    d = read_tsv("dmv_disengagements.tsv")
    counts["bronze.dmv_disengagements"] = len(d)
    tok = d["date_raw"].str.strip().str.split(" ").str[0].str.rstrip(".")
    dt = pd.Series(pd.NaT, index=d.index)
    m1 = tok.str.match(r"^\d{4}-"); dt[m1] = pd.to_datetime(tok[m1], format="%Y-%m-%d", errors="coerce")
    m2 = tok.str.match(r"^\d{4}\."); dt[m2] = pd.to_datetime(tok[m2], format="%Y.%m.%d", errors="coerce")
    m3 = tok.str.match(r".*/\d{4}$"); dt[m3] = pd.to_datetime(tok[m3], format="%m/%d/%Y", errors="coerce")
    m4 = tok.str.match(r".*/\d{2}$") & ~m3; dt[m4] = pd.to_datetime(tok[m4], format="%m/%d/%y", errors="coerce")
    # "15/Apr/22": SQL Server's TRY_CONVERT reads an alphabetic month whatever the style
    m5 = tok.str.match(r"^\d{1,2}/[A-Za-z]{3}/\d{2}$"); dt[m5] = pd.to_datetime(tok[m5], format="%d/%b/%y", errors="coerce")
    d["event_date"] = pd.to_datetime(dt)
    ok = (d["manufacturer"].str.strip() != "") & d["event_date"].between("2020-12-01", "2024-11-30")
    d = d[ok].copy()
    d["manufacturer_clean"] = d["manufacturer"].str.replace(",", "", regex=False).str.replace(".", "", regex=False).str.strip().str.upper()
    counts["silver.dmv_disengagement"] = len(d)

    m = read_tsv("dmv_mileage.tsv")
    counts["bronze.dmv_mileage"] = len(m)
    rec = []
    mon = {"JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6, "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12}
    for _, r in m.iterrows():
        for k, v in json.loads(r["months_json"]).items():
            if "TOTAL" in k or k.startswith("col"):
                continue
            mo = mon.get(k.strip().upper()[:3]); yr = k.strip()[-4:]
            miles = pd.to_numeric(v.replace(",", "").replace(" ", ""), errors="coerce")
            if mo is None or not yr.isdigit() or pd.isna(miles) or miles < 0:
                continue
            if r["permit_number"].strip() == "" or r["vin"].strip() == "":
                continue
            manu = r["manufacturer"].replace(",", "").replace(".", "").strip().upper()
            rec.append((r["permit_number"].strip(), r["vin"].strip(), manu, pd.Timestamp(int(yr), mo, 1), float(miles)))
    mm = pd.DataFrame(rec, columns=["permit", "vin", "manufacturer", "month_start", "miles"])
    mm = mm.groupby(["permit", "vin", "month_start"], as_index=False).agg(manufacturer=("manufacturer", "max"),
                                                                         miles=("miles", "max"))
    counts["silver.dmv_mileage_monthly"] = len(mm)
    return d, mm


def silver_nhtsa(counts: dict) -> pd.DataFrame:
    n = read_tsv("nhtsa_sgo_ads.tsv")
    counts["bronze.nhtsa_sgo_ads"] = len(n)
    js = n["row_json"].map(json.loads)
    g = lambda k: js.map(lambda d: d.get(k))
    n["rid"] = n["Report ID"].str.strip(); n["ver"] = to_num(n["Report Version"])
    n["st"] = n["State"].str.strip(); n["city"] = n["City"].str.strip()
    n["inc_month"] = pd.to_datetime("01-" + n["Incident Date"].str.strip(), format="%d-%b-%Y", errors="coerce")
    n["inc_time"] = n["Incident Time (24:00)"].str.strip()
    n["file_rank"] = np.where(n["source_file"].str.contains("archive"), 1, 2)
    n["same"] = g("Same Incident ID").fillna("").str.strip()
    wf = g("Weather - Fog/Smoke/Haze").fillna(g("Weather - Fog/Smoke"))
    flags = {"wc": g("Weather - Clear"), "wcl": g("Weather - Cloudy"), "wpc": g("Weather - Partly Cloudy"),
             "wr": g("Weather - Rain"), "wsn": g("Weather - Snow"), "wf": wf, "wd": g("Weather - Dust Storm"),
             "ww": g("Weather - Severe Wind")}
    for k, v in flags.items():
        n[k] = v.fillna("") == "Y"
    n = n[n["rid"] != ""].sort_values(["ver", "file_rank"], ascending=[False, True])
    n = n.drop_duplicates("rid", keep="first")
    n["sid"] = np.where(n["same"] != "", n["same"], n["rid"])
    n = n.sort_values("rid").drop_duplicates(["file_rank", "sid"], keep="first")
    t = pd.to_datetime(n["inc_time"], format="%H:%M", errors="coerce")
    n["tkey"] = t.dt.strftime("%H:%M:%S").where(t.notna(), n["rid"])
    n = n.sort_values(["file_rank", "rid"]).drop_duplicates(
        ["Reporting Entity", "st", "city", "inc_month", "tkey"], keep="first")
    n = n[n["inc_month"].notna()].copy()
    # v2: NHTSA has a single "Fog/Smoke/Haze" box, so it maps to obscured_unspecified (not fog, not haze)
    n["bucket"] = np.select([n["wd"], n["wf"], n["wr"] | n["wsn"], n["wc"] | n["wcl"] | n["wpc"] | n["ww"]],
                            ["dust", "obscured_unspecified", "rain", "normal"], "unknown")
    light = n["Lighting"].str.strip()
    night = pd.Series(np.nan, index=n.index)
    night[light.str.startswith("Daylight")] = 0
    night[light.str.startswith("Dark") | light.str.startswith("Dawn")] = 1
    ref = STATIONS[STATIONS.country == "US"].sort_values("station_id").drop_duplicates("us_state").set_index("us_state")
    need = night.isna() & n["st"].str[:2].isin(ref.index) & (n["inc_time"] != "")
    for idx in n[need].index:
        st = ref.loc[n.at[idx, "st"][:2]]
        t = pd.to_datetime(n.at[idx, "inc_time"], format="%H:%M", errors="coerce")
        if pd.isna(t):
            continue
        loc = n.at[idx, "inc_month"] + pd.Timedelta(days=14, hours=t.hour, minutes=t.minute)
        utc = pd.Series([loc]).dt.tz_localize(st.tz, ambiguous=True, nonexistent="shift_forward").dt.tz_convert("UTC").dt.tz_localize(None)
        night[idx] = 1 if solar_elevation(st.lat, st.lon, utc)[0] < -0.833 else 0
    n["is_night"] = night
    n["state2"] = n["st"].str[:2]
    n["in_scope"] = n["state2"].isin(["CA", "AZ", "TX"]) & n["inc_month"].dt.year.between(2021, 2025)
    counts["silver.nhtsa_crash"] = len(n)
    return n


# ============================================================================= AV evidence
NHTSA_MAP = {"normal": "normal", "rain": "rain", "fog_moist": "obscured_unspecified",
             "haze_dry": "obscured_unspecified", "dust": "dust"}


def us_hours(h: pd.DataFrame) -> pd.DataFrame:
    """US station-hours per state x local month x NHTSA category (CA = LAX + SFO summed) and light."""
    us = h.merge(STATIONS[STATIONS.country == "US"][["station_id", "us_state"]], on="station_id")
    us["month_start"] = us["hour_local"].dt.to_period("M").dt.to_timestamp()
    us["cond"] = us["hour_bucket"].map(NHTSA_MAP)
    us["light"] = np.where(us["is_night"], "night", "day")
    return us


def ca_days(d: pd.DataFrame) -> pd.DataFrame:
    """California day = max hours of each kind over LAX and SFO, then silver.fn_day_type."""
    ca = d.merge(STATIONS[STATIONS.us_state == "CA"][["station_id"]], on="station_id")
    cad = ca.groupby("local_date").agg(dust=("dust_hours", "max"), haze_dry=("haze_dry_hours", "max"),
                                       fog_moist=("fog_moist_hours", "max"), rain=("rain_hours", "max")).reset_index()
    cad["day_type"] = day_type(cad["dust"], cad["haze_dry"], cad["fog_moist"], cad["rain"])
    return cad


def mantel_haenszel(cells: pd.DataFrame, strata: list, cond_col: str, ref: str) -> pd.DataFrame:
    """Mantel-Haenszel rate ratio (person-time) of every level vs ref, with the Greenland-Robins variance.
    cells: one row per stratum x level with e (events) and t (person-time).
    Returns R = sum e_c T_n / T, S = sum e_n T_c / T, RR = R / S and V (numerator of Var(ln RR) = V / (R S))."""
    n = cells[cells[cond_col] == ref][strata + ["e", "t"]].rename(columns={"e": "e_n", "t": "t_n"})
    out = []
    for lv, c in cells.groupby(cond_col):
        x = c.merge(n, on=strata)
        T = x["t"] + x["t_n"]
        ok = T > 0
        x, T = x[ok], T[ok]
        R = float((x["e"] * x["t_n"] / T).sum())
        S = float((x["e_n"] * x["t"] / T).sum())
        V = float(((x["e"] + x["e_n"]) * x["t"] * x["t_n"] / T ** 2).sum())
        rr = 1.0 if lv == ref else (R / S if S > 0 else np.nan)
        out.append((lv, int(c["e"].sum()), float(c["t"].sum()), R, S, V, rr, int(len(c))))
    return pd.DataFrame(out, columns=[cond_col, "events", "exposure", "R", "S", "V", "rr_adjusted", "n_strata"])


def dispersion(units: pd.DataFrame, strata: list, cond_col: str, ref: str, rr: pd.Series) -> float:
    """Pearson dispersion of the fitted stratified model on the observation units (NHTSA: state x month x
    condition cell; DMV: one California day): E = t x RR(level) x lambda_s with lambda_s = sum e / sum t RR in
    the stratum; phi = sum (e - E)^2 / E / (units - strata - estimated ratios), over units with E > 0."""
    u = units.copy()
    u["rr"] = u[cond_col].map(rr).fillna(0.0)
    u["tr"] = u["t"] * u["rr"]
    s = u.groupby(strata).agg(se=("e", "sum"), st=("tr", "sum")).reset_index()
    s["lam"] = np.where(s["st"] > 0, s["se"] / s["st"].where(s["st"] > 0, 1), np.nan)
    u = u.merge(s[strata + ["lam"]], on=strata)
    u["E"] = u["tr"] * u["lam"]
    v = u[u["E"] > 0]
    p = int(((rr > 0) & (rr.index != ref)).sum())
    df = len(v) - v.groupby(strata).ngroups - p
    return float((((v["e"] - v["E"]) ** 2) / v["E"]).sum() / df) if df > 0 else np.nan


def add_ci(mh: pd.DataFrame, cond_col: str, ref: str, phi: float) -> pd.DataFrame:
    """95 % CI of the MH ratio with the variance inflated by max(1, phi) (quasi-Poisson correction:
    DMV disengagements are heavily overdispersed, so the plain Poisson CI would be far too narrow)."""
    k = max(1.0, phi) if pd.notna(phi) else 1.0
    lo, hi = [], []
    for _, r in mh.iterrows():
        if r[cond_col] == ref or not (r["R"] > 0 and r["S"] > 0):
            lo.append(np.nan); hi.append(np.nan); continue
        se = math.sqrt(r["V"] / (r["R"] * r["S"]) * k)
        lo.append(math.exp(math.log(r["rr_adjusted"]) - 1.96 * se))
        hi.append(math.exp(math.log(r["rr_adjusted"]) + 1.96 * se))
    mh = mh.copy()
    mh["ci_low"], mh["ci_high"], mh["dispersion"] = lo, hi, phi
    return mh


def evidence_note(row) -> tuple[int, str]:
    """Evidence rule (decided with Ali, 27 Nov 2026): a ratio is USED in Gold only if it comes from AV
    crashes (NHTSA: a safety outcome), has >= 30 events and its 95 % CI lower bound > 1. A significant
    disengagement ratio (DMV: a precautionary takeover, 42 % from one company) is reported, not applied."""
    if row["factor"] == "light":
        return 0, ("reference level" if row["condition_code"] == "day"
                   else "exposure is darkness hours, not AV miles - not used")
    if row["condition_code"] == "normal":
        return 0, "reference level"
    if row["events"] == 0:
        return 0, "no events - uncovered"
    if row["events"] >= EVIDENCE_MIN_EVENTS and row["ci_low"] > 1:
        if row["event_source"] == "nhtsa_crash":
            return 1, "significant penalty - used"
        return 0, "takeover signal (CI > 1) - reported, not a crash weight"
    if pd.notna(row["ci_high"]) and row["ci_high"] < 1:
        return 0, "implausible protective - artefact"
    if row["events"] < EVIDENCE_MIN_EVENTS and pd.notna(row["ci_low"]) and row["ci_low"] > 1:
        return 0, "fewer than 30 events - not used"
    return 0, "no detectable penalty (CI includes 1)"


def nhtsa_cells(us: pd.DataFrame, crash: pd.DataFrame, factor: str) -> pd.DataFrame:
    """stratum (state x incident month, strata with >= 1 crash) x level: events and station-hours."""
    c = crash[crash["in_scope"]].copy()
    if factor == "weather":
        c = c[c["bucket"] != "unknown"]; c["lv"] = c["bucket"]
        levels = ["normal", "rain", "obscured_unspecified", "dust"]; ucol = "cond"
    else:
        c = c[c["is_night"].notna()]; c["lv"] = np.where(c["is_night"] == 1, "night", "day")
        levels = ["day", "night"]; ucol = "light"
    ev = c.groupby(["state2", "inc_month", "lv"]).size().rename("e").reset_index()
    ev = ev.rename(columns={"state2": "us_state", "inc_month": "month_start"})
    strata = ev[["us_state", "month_start"]].drop_duplicates()
    grid = strata.merge(pd.DataFrame({"lv": levels}), how="cross")
    tt = us.groupby(["us_state", "month_start", ucol]).size().rename("t").reset_index().rename(columns={ucol: "lv"})
    g = grid.merge(ev, on=["us_state", "month_start", "lv"], how="left").merge(
        tt, on=["us_state", "month_start", "lv"], how="left").fillna({"e": 0, "t": 0})
    return g


def nhtsa_crude(us: pd.DataFrame, crash: pd.DataFrame, factor: str) -> pd.Series:
    """The pooled ratio used before v2: event share / exposure share (state-weighted), normal (day) = 1."""
    c = crash[crash["in_scope"]].copy()
    if factor == "weather":
        c = c[c["bucket"] != "unknown"]; c["lv"] = c["bucket"]; ucol, ref = "cond", "normal"
    else:
        c = c[c["is_night"].notna()]; c["lv"] = np.where(c["is_night"] == 1, "night", "day"); ucol, ref = "light", "day"
    w = c.groupby("state2").size() / len(c)
    es = us.groupby("us_state")[ucol].value_counts(normalize=True).unstack(fill_value=0)
    exp = es.loc[w.index].mul(w, axis=0).sum()
    ev = c["lv"].value_counts(normalize=True)
    ratio = ev.reindex(exp.index).fillna(0) / exp
    return ratio / ratio[ref]


def dmv_days(cad: pd.DataFrame, dis: pd.DataFrame, miles: pd.DataFrame) -> pd.DataFrame:
    """One row per California date in months with fleet miles > 0: miles of that day (= month fleet miles /
    days in month: this is how mileage contributes) and the disengagements of that date."""
    mm = miles.groupby("month_start")["miles"].sum()
    mm = mm[mm > 0]
    x = cad.copy()
    x["month_start"] = x["local_date"].dt.to_period("M").dt.to_timestamp()
    x = x[x["month_start"].isin(mm.index)].copy()
    x["t"] = x["month_start"].map(mm) / x["local_date"].dt.days_in_month
    nd = dis.groupby(dis["event_date"].dt.normalize()).size()
    x["e"] = x["local_date"].map(nd).fillna(0).astype(int)
    x["weekend"] = (x["local_date"].dt.dayofweek >= 5).astype(int)     # Sat-Sun
    x["weekday"] = x["local_date"].dt.dayofweek
    return x


def relative_risks(h: pd.DataFrame, d: pd.DataFrame, crash: pd.DataFrame, dis: pd.DataFrame,
                   miles: pd.DataFrame) -> pd.DataFrame:
    """prep.av_relative_risk v2."""
    us = us_hours(h)
    rows = []
    for factor, ref in [("weather", "normal"), ("light", "day")]:
        cells = nhtsa_cells(us, crash, factor)
        st = ["us_state", "month_start"]
        mh = mantel_haenszel(cells, st, "lv", ref)
        phi = dispersion(cells, st, "lv", ref, mh.set_index("lv")["rr_adjusted"])
        mh = add_ci(mh, "lv", ref, phi)
        crude = nhtsa_crude(us, crash, factor)
        for _, r in mh.iterrows():
            rows.append(("nhtsa_crash", factor, r["lv"], r["events"], r["exposure"], float(crude.get(r["lv"], np.nan)),
                         r["rr_adjusted"], r["ci_low"], r["ci_high"], r["n_strata"], r["dispersion"],
                         "MH: state x incident month"))
    x = dmv_days(ca_days(d), dis, miles)
    st = ["month_start", "weekend"]
    cells = x.groupby(st + ["day_type"]).agg(e=("e", "sum"), t=("t", "sum")).reset_index()
    grid = cells[st].drop_duplicates().merge(pd.DataFrame({"day_type": WEATHER_CONDITIONS}), how="cross")
    cells = grid.merge(cells, on=st + ["day_type"], how="left").fillna({"e": 0, "t": 0})
    mh = mantel_haenszel(cells, st, "day_type", "normal")
    phi = dispersion(x, st, "day_type", "normal", mh.set_index("day_type")["rr_adjusted"])
    mh = add_ci(mh, "day_type", "normal", phi)
    agg = x.groupby("day_type").agg(e=("e", "sum"), t=("t", "sum"))
    base = agg.loc["normal", "e"] / agg.loc["normal", "t"]
    for _, r in mh.iterrows():
        crude = (agg["e"].get(r["day_type"], 0) / agg["t"].get(r["day_type"], np.nan)) / base \
            if r["day_type"] in agg.index else np.nan
        rows.append(("dmv_disengagement", "weather", r["day_type"], r["events"], r["exposure"], crude,
                     r["rr_adjusted"], r["ci_low"], r["ci_high"], r["n_strata"], r["dispersion"],
                     "MH: month x weekday class"))
    rr = pd.DataFrame(rows, columns=["event_source", "factor", "condition_code", "events", "exposure", "rr_crude",
                                     "rr_adjusted", "ci_low", "ci_high", "n_strata", "dispersion", "adjustment"])
    notes = rr.apply(evidence_note, axis=1)
    rr["used_in_index"] = [n[0] for n in notes]
    rr["evidence_note"] = [n[1] for n in notes]
    return rr


def used_rr(rr: pd.DataFrame) -> dict:
    """RR applied per Saudi condition: the largest used (evidence-backed) weather RR of that condition;
    NHTSA's obscured_unspecified would apply to fog_moist and haze_dry; dust is never weighted (uncovered)."""
    u = rr[(rr["used_in_index"] == 1) & (rr["factor"] == "weather")].groupby("condition_code")["rr_adjusted"].max()
    out = {}
    for c in ["rain", "fog_moist", "haze_dry"]:
        v = u.get(c, np.nan)
        if np.isnan(v):
            v = u.get("obscured_unspecified", np.nan)
        if not np.isnan(v):
            out[c] = float(v)
    return out


# ============================================================================= Gold
GOLD_COLUMNS = [
    "region_code", "region_name_en", "region_name_ar", "weather_station_id", "year", "month", "month_start", "season",
    "wx_hours_observed", "wx_hours_in_month", "wx_coverage_pct", "wx_complete",
    "temp_mean_c", "temp_max_c", "wind_max_ms", "mean_dew_spread_c",
    "share_normal_hours", "share_rain_hours", "share_fog_moist_hours", "share_haze_dry_hours", "share_dust_hours",
    "share_haze_hours", "share_fog_hours", "share_low_vis_hours", "share_night_hours",
    "share_hot40_hours", "share_hot45_hours",
    "days_observed", "dust_days", "dust_type_days", "haze_dry_days", "fog_moist_days", "rain_days", "normal_days",
    "traffic_adt_per_point", "traffic_definition", "traffic_month_index",
    "acc_year_serious", "acc_year_deaths", "acc_year_injuries", "acc_year_serious_within_cities",
    "acc_year_serious_outside_cities", "acc_share_outside_cities",
    "population", "population_basis", "acc_serious_per_100k", "acc_deaths_per_100k", "acc_injuries_per_100k",
    "road_km_per_1000_people", "road_km_per_km2", "intercity_road_km", "intercity_divided_share",
    "response_within_s", "response_outside_s", "registered_vehicles_2025",
    "av_uncovered_share", "av_uncovered_share_cons", "av_crash_multiplier", "env_readiness", "env_readiness_cons",
    "src_weather", "src_accidents", "src_traffic", "src_av",
]
REGION_NAMES = {"RIY": ("Riyadh", "الرياض"), "MAK": ("Makkah", "مكة المكرمة"), "MED": ("Madinah", "المدينة المنورة"),
                "EAS": ("Eastern Province", "المنطقة الشرقية"), "QAS": ("Qassim", "القصيم"), "HAI": ("Hail", "حائل"),
                "TAB": ("Tabuk", "تبوك"), "NBR": ("Northern Borders", "الحدود الشمالية"), "JOF": ("Al-Jouf", "الجوف"),
                "ASR": ("Aseer", "عسير"), "BAH": ("Al-Baha", "الباحة"), "NAJ": ("Najran", "نجران"), "JAZ": ("Jazan", "جازان")}
SRC_AV = "prep.av_relative_risk v2: NHTSA state-month MH; DMV month x weekday MH"


def season_of(m):
    return np.select([np.isin(m, [12, 1, 2]), np.isin(m, [3, 4, 5]), np.isin(m, [6, 7, 8])],
                     ["winter", "spring", "summer"], "autumn")


def saudi_region_month(h: pd.DataFrame, d: pd.DataFrame) -> pd.DataFrame:
    """prep.saudi_region_month: hour and day counts per Saudi region x month."""
    sa = h.merge(STATIONS[STATIONS.country == "SA"][["station_id", "region_code"]], on="station_id")
    sa["month_start"] = sa["hour_local"].dt.to_period("M").dt.to_timestamp()
    for c in WEATHER_CONDITIONS:
        sa["b_" + c] = sa["hour_bucket"] == c
    hm = sa.groupby(["region_code", "station_id", "month_start"]).agg(
        hours=("hour_bucket", "size"), temp_mean_c=("temp_c", "mean"), temp_max_c=("temp_max_c", "max"),
        wind_max_ms=("wind_max_ms", "max"), mean_dew_spread_c=("dew_spread_c", "mean"),
        dust_hours=("b_dust", "sum"), haze_dry_hours=("b_haze_dry", "sum"), fog_moist_hours=("b_fog_moist", "sum"),
        rain_hours=("b_rain", "sum"), normal_hours=("b_normal", "sum"),
        haze_hours=("is_haze", "sum"), fog_hours=("is_fog", "sum"), low_vis_hours=("is_low_vis", "sum"),
        night_hours=("is_night", "sum"), hot40_hours=("is_hot40", "sum"), hot45_hours=("is_hot45", "sum")).reset_index()
    dd = d.copy(); dd["month_start"] = dd["local_date"].dt.to_period("M").dt.to_timestamp()
    for c in WEATHER_CONDITIONS:
        dd["t_" + c] = dd["day_type"] == c
    dd["any_dust"] = dd["dust_hours"] > 0
    dm = dd.groupby(["station_id", "month_start"]).agg(
        days=("day_type", "size"), dust_days=("any_dust", "sum"), dust_type_days=("t_dust", "sum"),
        haze_dry_days=("t_haze_dry", "sum"), fog_moist_days=("t_fog_moist", "sum"), rain_days=("t_rain", "sum"),
        normal_days=("t_normal", "sum")).reset_index()
    return hm.merge(dm, on=["station_id", "month_start"])


def build_gold(h, d, acc, roads, pop, traffic, service, rr) -> pd.DataFrame:
    m = saudi_region_month(h, d)
    st = STATIONS[STATIONS.country == "SA"][["region_code", "station_id"]]
    cal = pd.MultiIndex.from_product([REGIONS, pd.date_range("2021-01-01", "2025-12-01", freq="MS")],
                                     names=["region_code", "month_start"]).to_frame(index=False).merge(st, on="region_code")
    g = cal.merge(m.drop(columns=["station_id"]), on=["region_code", "month_start"], how="left")
    g["weather_station_id"] = g["station_id"]
    g["region_name_en"] = g["region_code"].map(lambda r: REGION_NAMES[r][0])
    g["region_name_ar"] = g["region_code"].map(lambda r: REGION_NAMES[r][1])
    g["year"] = g["month_start"].dt.year; g["month"] = g["month_start"].dt.month
    g["season"] = season_of(g["month"])
    g["wx_hours_observed"] = g["hours"]
    g["wx_hours_in_month"] = g["month_start"].dt.days_in_month * 24
    g["wx_coverage_pct"] = sql_round(100.0 * g["hours"] / g["wx_hours_in_month"], 1)
    g["wx_complete"] = (g["hours"].notna() & (g["wx_coverage_pct"] >= 80)).astype(int)
    hrs = g["hours"].replace(0, np.nan)
    for c in ["normal", "rain", "fog_moist", "haze_dry", "dust", "haze", "fog", "low_vis", "night", "hot40", "hot45"]:
        g[f"share_{c}_hours"] = g[f"{c}_hours"] / hrs
    g["days_observed"] = g["days"]
    # traffic, accidents, population, roads, service
    g = g.merge(traffic[["region_code", "month_start", "adt_per_point", "definition", "traffic_month_index"]].rename(
        columns={"adt_per_point": "traffic_adt_per_point", "definition": "traffic_definition"}), on=["region_code", "month_start"], how="left")
    a = acc.rename(columns={"serious": "acc_year_serious", "deaths": "acc_year_deaths", "injuries": "acc_year_injuries",
                            "serious_within": "acc_year_serious_within_cities",
                            "serious_outside": "acc_year_serious_outside_cities", "source_files": "src_accidents"})
    g = g.merge(a[["region_code", "year", "acc_year_serious", "acc_year_deaths", "acc_year_injuries",
                   "acc_year_serious_within_cities", "acc_year_serious_outside_cities", "src_accidents"]],
                on=["region_code", "year"], how="left")
    g["acc_share_outside_cities"] = g["acc_year_serious_outside_cities"] / (
        g["acc_year_serious_within_cities"] + g["acc_year_serious_outside_cities"])
    g = g.merge(pop[["region_code", "year", "population", "population_basis"]], on=["region_code", "year"], how="left")
    for c, src in [("acc_serious_per_100k", "acc_year_serious"), ("acc_deaths_per_100k", "acc_year_deaths"),
                   ("acc_injuries_per_100k", "acc_year_injuries")]:
        g[c] = 100000.0 * g[src] / g["population"]
    r = roads.rename(columns={"density_km_per_km2": "road_km_per_km2", "intercity_total_km": "intercity_road_km"})
    g = g.merge(r[["region_code", "year", "road_km_per_1000_people", "road_km_per_km2", "intercity_road_km",
                   "intercity_divided_share"]], on=["region_code", "year"], how="left")
    g = g.merge(service.rename(columns={"registered_vehicles": "registered_vehicles_2025"})[
        ["region_code", "response_within_s", "response_outside_s", "registered_vehicles_2025"]], on="region_code", how="left")
    # AV-derived measures (vary by row): uncovered share, crash multiplier and environment readiness
    u = used_rr(rr)
    g["av_uncovered_share"] = g["dust_hours"] / hrs
    g["av_uncovered_share_cons"] = (g["dust_hours"] + g["haze_dry_hours"]) / hrs
    # crash multiplier = 1 + sum over used conditions of share x (RR - 1)
    g["av_crash_multiplier"] = 1 + sum((g[f"{c}_hours"] / hrs * (u[c] - 1) for c in u), 0 * hrs)
    # env_readiness = sum of share x weight: dust 0 (uncovered), used conditions 1/RR, other covered conditions 1
    w = {c: (1.0 / u[c] if c in u else 1.0) for c in ["rain", "fog_moist", "haze_dry"]}
    w["normal"] = 1.0
    g["env_readiness"] = sum(g[f"{c}_hours"] * w[c] for c in ["normal", "rain", "fog_moist", "haze_dry"]) / hrs
    # conservative variant: Saudi dry haze is mineral dust, California's is mostly smoke -> haze_dry weight 0
    g["env_readiness_cons"] = sum(g[f"{c}_hours"] * w[c] for c in ["normal", "rain", "fog_moist"]) / hrs
    g["src_weather"] = "NOAA NCEI Global Hourly station " + g["station_id"]
    tsrc = traffic.set_index(["region_code", "month_start"])
    g["src_traffic"] = [f"{tsrc.at[(rc, ms), 'source_file'].replace('gastat/', '')} sheet {tsrc.at[(rc, ms), 'source_sheet']}"
                        if (rc, ms) in tsrc.index else None for rc, ms in zip(g["region_code"], g["month_start"])]
    g["src_av"] = SRC_AV
    return g[GOLD_COLUMNS].sort_values(["region_code", "month_start"]).reset_index(drop=True)


# ============================================================================= whole build
def build_all(fog_spread_c: float = FOG_SPREAD_C, quiet: bool = True) -> dict:
    """Run every step and return the intermediate tables (used by 04 / 05 through importlib)."""
    counts: dict = {}
    wx = silver_weather(counts)
    h, d = prep_hours(wx, fog_spread_c)
    counts["prep.weather_station_hour"] = len(h)
    counts["prep.weather_station_day"] = len(d)
    acc = silver_accidents(counts)
    roads = silver_roads(counts)
    pop = silver_population(counts, acc)
    traffic = silver_traffic(counts)
    service = silver_region_service(counts)
    dis, miles = silver_dmv(counts)
    crash = silver_nhtsa(counts)
    rr = relative_risks(h, d, crash, dis, miles)
    counts["prep.av_relative_risk"] = len(rr)
    gold = build_gold(h, d, acc, roads, pop, traffic, service, rr)
    counts["gold.av_readiness_region_month"] = len(gold)
    return dict(counts=counts, wx=wx, h=h, d=d, acc=acc, roads=roads, pop=pop, traffic=traffic, service=service,
                dis=dis, miles=miles, crash=crash, rr=rr, gold=gold)


def acceptance_report(b: dict) -> pd.DataFrame:
    """The numbers of the execution brief (section 4), computed from this build."""
    h, rr, g, pop = b["h"], b["rr"], b["gold"], b["pop"]
    sa = h.merge(STATIONS[["station_id", "country", "us_state"]], on="station_id")
    rows = []
    for lbl, sub in [("Saudi (13 stations)", sa[sa.country == "SA"]), ("California (LAX+SFO)", sa[sa.us_state == "CA"]),
                     ("Phoenix", sa[sa.us_state == "AZ"])]:
        s = sub["hour_bucket"].value_counts(normalize=True)
        for c in WEATHER_CONDITIONS:
            rows.append((f"{lbl} share {c} hours %", round(100 * s.get(c, 0), 2)))
        rows.append((f"{lbl} share hours >= 40 C %", round(100 * sub["is_hot40"].mean(), 2)))
    for _, r in rr.iterrows():
        rows.append((f"RR {r.event_source} {r.condition_code}: events / crude / adjusted [CI] / used",
                     f"{r.events} / {r.rr_crude:.3f} / {r.rr_adjusted:.3f} [{r.ci_low:.3f}, {r.ci_high:.3f}] / {r.used_in_index}"))
    c = g[g.wx_complete == 1]
    m = c.groupby("region_code")["env_readiness_cons"].mean().sort_values()
    rows.append(("env_readiness_cons region mean (low -> high)", ", ".join(f"{k} {v:.3f}" for k, v in m.items())))
    s = c.groupby(["region_code", "season"])["env_readiness_cons"].mean().sort_values()
    rows.append(("env_readiness_cons worst region-season", f"{s.index[0]} {s.iloc[0]:.3f}"))
    for rc, y in [("RIY", 2023), ("RIY", 2024), ("RIY", 2025), ("MAK", 2023), ("MAK", 2025), ("EAS", 2025), ("BAH", 2025)]:
        v = pop[(pop.region_code == rc) & (pop.year == y)]["population"]
        rows.append((f"implied population {rc} {y}", int(v.iloc[0])))
    return pd.DataFrame(rows, columns=["item", "value"])


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    b = build_all()
    counts = b["counts"]
    b["rr"].to_csv(OUT / "relative_risk.csv", index=False)
    b["gold"].to_csv(OUT / "gold_reference.csv", index=False)
    b["traffic"].to_csv(OUT / "traffic_region_month.csv", index=False)
    b["pop"].to_csv(OUT / "population_region_year.csv", index=False)
    b["service"].to_csv(OUT / "region_service_2025.csv", index=False)
    pd.Series(counts, name="rows").to_csv(OUT / "counts.csv")

    wx, acc, roads, pop, dis, miles, crash, traffic, service = (b[k] for k in
        ["wx", "acc", "roads", "pop", "dis", "miles", "crash", "traffic", "service"])
    fam = {
        "weather - Saudi stations (hourly reports)": int((wx["country"] == "SA").sum()),
        "weather - US analog stations (hourly reports)": int((wx["country"] == "US").sum()),
        "accidents - Saudi GASTAT (region-year values)": int(acc[["serious", "deaths", "injuries"]].notna().sum().sum()
                                                             + acc[["serious_within", "serious_outside"]].notna().sum().sum()),
        "roads - Saudi GASTAT (region-year values)": int(roads[["density_km_per_person", "density_km_per_km2",
                                                                 "intercity_highway_km", "intercity_dual_km",
                                                                 "intercity_exit_km", "intercity_single_km"]].notna().sum().sum()),
        "traffic - Saudi GASTAT (region-month values)": int(len(traffic)),
        "population - Saudi GASTAT (region-year values)": int(len(pop)),
        "region service - Saudi GASTAT 2025 (region values)": int(3 * len(service)),
        "AV - DMV disengagements": int(len(dis)),
        "AV - DMV mileage (vehicle-months)": int(len(miles)),
        "AV - NHTSA crashes (in scope)": int(crash["in_scope"].sum()),
    }
    s = pd.Series(fam, name="records").to_frame()
    s["share_pct"] = (100 * s["records"] / s["records"].sum()).round(2)
    s.to_csv(OUT / "data_shares.csv")
    rep = acceptance_report(b)
    rep.to_csv(OUT / "acceptance.csv", index=False)
    pd.set_option("display.width", 200)
    print(pd.Series(counts).to_string())
    print(b["rr"].to_string())
    print(s.to_string())
    print(rep.to_string())


# ============================================================================= SQL Gold vs reference
def compare() -> int:
    """Row count, keys and every column of the exported SQL Gold against the reference: within one unit of
    the last decimal of the SQL type (the value may be rounded twice: hourly means, then the monthly mean) + 1e-6."""
    if not EXPORT.exists():
        print(f"no export at {EXPORT}"); return 1
    ref = pd.read_csv(OUT / "gold_reference.csv", parse_dates=["month_start"])
    sql = pd.read_csv(EXPORT, dtype=str, keep_default_na=False)
    raw = sql.copy()
    sql = sql.replace({"NULL": np.nan, "": np.nan})
    sql["month_start"] = pd.to_datetime(sql["month_start"])
    fails = []
    if len(sql) != len(ref):
        fails.append(f"row count SQL {len(sql)} vs reference {len(ref)}")
    k = ["region_code", "month_start"]
    m = ref.merge(sql, on=k, how="outer", suffixes=("_ref", "_sql"), indicator=True)
    if (m["_merge"] != "both").any():
        fails.append(f"keys differ: {int((m['_merge'] != 'both').sum())} rows")
    m = m[m["_merge"] == "both"]
    for c in GOLD_COLUMNS:
        if c in k:
            continue
        a, b = m[c + "_ref"], m[c + "_sql"]
        an = pd.to_numeric(a, errors="coerce"); bn = pd.to_numeric(b, errors="coerce")
        if an.notna().any() or bn.notna().any():
            dec = raw[c].str.extract(r"\.(\d+)$")[0].str.len().max()
            tol = 10.0 ** (-(int(dec) if pd.notna(dec) else 0)) + 1e-6
            diff = (an - bn).abs()
            bad = (an.isna() != bn.isna()) | (diff > tol)
            if bad.any():
                i = bad.idxmax()
                fails.append(f"{c}: {int(bad.sum())} rows differ (tol {tol:g}), e.g. {m.at[i, 'region_code']} "
                             f"{m.at[i, 'month_start']:%Y-%m}: ref {a[i]} sql {b[i]}")
        else:
            bad = a.fillna("").astype(str).str.strip() != b.fillna("").astype(str).str.strip()
            if bad.any():
                i = bad.idxmax()
                fails.append(f"{c}: {int(bad.sum())} text rows differ, e.g. ref '{a[i]}' sql '{b[i]}'")
    print(f"SQL Gold vs reference: {len(sql)} rows, {len(GOLD_COLUMNS)} columns compared")
    for f in fails:
        print("  FAIL", f)
    print("RESULT:", "PASS" if not fails else "FAIL")
    return 0 if not fails else 1


if __name__ == "__main__":
    if "--compare" in sys.argv:
        sys.exit(compare())
    main()
