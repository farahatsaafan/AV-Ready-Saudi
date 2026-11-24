"""
AV-Ready-Saudi - independent reference build of Silver -> Gold in pandas.

Purpose: a second implementation of the same rules as sql/02_silver.sql and
sql/03_gold.sql, used to (1) check the SQL results after a run and (2) report the
data shares. It reads the same Data/landing/*.tsv files the SQL pipeline loads.

Outputs (Data/reference/):
  gold_reference.csv     the expected Gold table (same columns as gold.av_readiness_region_month)
  relative_risk.csv      the expected prep.av_relative_risk
  counts.csv             expected row counts per Bronze / Silver table
  data_shares.csv        how much each data family contributes

Usage: python3 python/02_reference_gold.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
LAND = ROOT / "Data" / "landing"
OUT = ROOT / "Data" / "reference"

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

REGION_ALIAS = {"riyadh": "RIY", "makkah": "MAK", "madinah": "MED", "eastern": "EAS", "qassim": "QAS",
                "hail": "HAI", "tabuk": "TAB", "northernborders": "NBR", "aljouf": "JOF", "aseer": "ASR",
                "albaha": "BAH", "najran": "NAJ", "jazan": "JAZ"}
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
BAD_Q = set("2367")


def read_tsv(name: str) -> pd.DataFrame:
    return pd.read_csv(LAND / name, sep="\t", dtype=str, keep_default_na=False, quoting=3,
                       na_filter=False, engine="c", encoding="utf-16-le")


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


def to_int(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s, errors="coerce")


# ----------------------------------------------------------------------------- weather
def silver_weather(counts: dict) -> pd.DataFrame:
    b = read_tsv("noaa_hourly.tsv")
    counts["bronze.noaa_hourly"] = len(b)
    b["STATION"] = b["STATION"].str.strip()
    b["REPORT_TYPE"] = b["REPORT_TYPE"].str.strip()
    b["obs_utc"] = pd.to_datetime(b["DATE"], format="%Y-%m-%dT%H:%M:%S", errors="coerce")
    b = b[b["obs_utc"].notna() & ~b["REPORT_TYPE"].isin(["SOD", "SOM"])]
    b = b.merge(STATIONS, left_on="STATION", right_on="station_id")
    b["rownum"] = to_int(b["source_row_num"])
    b = b.sort_values("rownum").drop_duplicates(["STATION", "DATE", "REPORT_TYPE"], keep="first")

    def fixed(col, a, n):
        return b[col].str.slice(a, a + n)
    vis = to_int(fixed("VIS", 0, 6)).where(~fixed("VIS", 7, 1).isin(BAD_Q))
    b["vis_m"] = vis.where(vis != 999999)
    t = to_int(fixed("TMP", 0, 5)).where(~fixed("TMP", 6, 1).isin(BAD_Q))
    b["temp_c"] = (t.where(t != 9999) / 10.0)
    w = to_int(fixed("WND", 8, 4)).where(~fixed("WND", 13, 1).isin(BAD_Q))
    b["wind_ms"] = w.where(w != 9999) / 10.0
    aa = b["AA1"]
    b["precip_1h_mm"] = (to_int(aa.str.slice(3, 7)) / 10.0).where((aa.str.slice(0, 2) == "01") & (aa.str.slice(3, 7) != "9999"))
    mw = b["MW1"].str.slice(0, 2); aw = b["AW1"].str.slice(0, 2)
    aup = b["AU1"].str.slice(4, 6); auo = b["AU1"].str.slice(7, 8); aut = b["AU1"].str.slice(9, 10)
    b["is_dust"] = mw.isin(["06", "07", "08", "09", "30", "31", "32", "33", "34", "35"]) | auo.isin(["5", "6"]) | aut.isin(["1", "4", "5"])
    b["is_haze"] = mw.isin(["04", "05"]) | aw.isin(["04", "05"]) | auo.isin(["3", "7"])
    b["is_fog"] = mw.between("40", "49") & (mw != "") | aw.between("30", "35") & (aw != "") | (auo == "2")
    b["is_rain"] = ((mw.between("50", "69") | mw.between("80", "99")) & (mw != "")) | \
                   ((aw.between("40", "69") | aw.between("80", "89")) & (aw != "")) | \
                   aup.isin(["01", "02", "09"]) | (b["precip_1h_mm"] > 0)
    b["is_low_vis"] = b["vis_m"] < 5000
    b["sun"] = 0.0
    b["obs_local"] = pd.NaT
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
    return b


def prep_hours(wx: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    wx = wx.copy()
    wx["hour_local"] = wx["obs_local"].dt.floor("h")
    wx["obsc"] = wx["is_dust"] | wx["is_haze"] | wx["is_fog"] | wx["is_low_vis"]
    h = wx.groupby(["station_id", "hour_local"]).agg(
        temp_c=("temp_c", "mean"), temp_max_c=("temp_c", "max"), wind_max_ms=("wind_ms", "max"),
        precip_mm=("precip_1h_mm", "max"), is_dust=("is_dust", "max"), is_haze=("is_haze", "max"),
        is_fog=("is_fog", "max"), is_low_vis=("is_low_vis", "max"), is_obscured=("obsc", "max"),
        is_rain=("is_rain", "max"), night=("is_night", "mean")).reset_index()
    h["is_night"] = h["night"] >= 0.5
    h["bucket"] = np.where(h["is_obscured"], "obscured", np.where(h["is_rain"], "rain", "normal"))
    h["local_date"] = h["hour_local"].dt.normalize()
    d = h.groupby(["station_id", "local_date"]).agg(
        hours=("bucket", "size"), dust_hours=("is_dust", "sum"), obscured_hours=("is_obscured", "sum"),
        rain_hours=("is_rain", "sum")).reset_index()
    d["day_type"] = np.where(d["obscured_hours"] >= 3, "obscured", np.where(d["rain_hours"] >= 1, "rain", "normal"))
    return h, d


# ----------------------------------------------------------------------------- accidents
def silver_accidents(counts: dict) -> pd.DataFrame:
    c = read_tsv("gastat_cells.tsv")
    counts["bronze.gastat_cells"] = len(c)
    c["r"] = to_int(c["row_num"]); c["col"] = to_int(c["col_num"])
    rows = []
    for key, sheet, metric, year, col, r0, r1 in SHEET_MAP:
        s = c[c["source_file"].str.contains(key, regex=False) & (c["sheet_name"] == sheet)]
        v = s[(s["col"] == col) & s["r"].between(r0, r1)]
        lbl = s[s["col"] == 1].set_index("r")["cell_value"]
        for _, x in v.iterrows():
            label = lbl.get(x["r"], "")
            k = label.strip().lower().replace("region", "").replace("province", "")
            k = k.replace(" ", "").replace("-", "").replace("\xa0", "")
            n = pd.to_numeric(x["cell_value"].replace(",", "").replace(" ", ""), errors="coerce")
            rows.append((REGION_ALIAS.get(k), year, metric, None if pd.isna(n) else int(n), x["source_file"]))
    a = pd.DataFrame(rows, columns=["region_code", "year", "metric", "n", "file"])
    bad = a[a["region_code"].isna() | a["n"].isna()]
    assert bad.empty, bad
    p = a.pivot_table(index=["region_code", "year"], columns="metric", values="n", aggfunc="max").reset_index()
    p["serious"] = p["serious"].fillna(p["serious_within"] + p["serious_outside"])
    counts["silver.accidents_region_year"] = len(p)
    return p


# ----------------------------------------------------------------------------- DMV
def silver_dmv(counts: dict) -> tuple[pd.DataFrame, pd.DataFrame]:
    d = read_tsv("dmv_disengagements.tsv")
    counts["bronze.dmv_disengagements"] = len(d)
    tok = d["date_raw"].str.strip().str.split(" ").str[0].str.rstrip(".")
    dt = pd.Series(pd.NaT, index=d.index)
    m1 = tok.str.match(r"^\d{4}-"); dt[m1] = pd.to_datetime(tok[m1], format="%Y-%m-%d", errors="coerce")
    m2 = tok.str.match(r"^\d{4}\."); dt[m2] = pd.to_datetime(tok[m2], format="%Y.%m.%d", errors="coerce")
    m3 = tok.str.match(r".*/\d{4}$"); dt[m3] = pd.to_datetime(tok[m3], format="%m/%d/%Y", errors="coerce")
    m4 = tok.str.match(r".*/\d{2}$") & ~m3; dt[m4] = pd.to_datetime(tok[m4], format="%m/%d/%y", errors="coerce")
    d["event_date"] = pd.to_datetime(dt)
    ok = (d["manufacturer"].str.strip() != "") & d["event_date"].between("2020-12-01", "2024-11-30")
    d = d[ok]
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
            rec.append((r["permit_number"].strip(), r["vin"].strip(), pd.Timestamp(int(yr), mo, 1), float(miles)))
    mm = pd.DataFrame(rec, columns=["permit", "vin", "month_start", "miles"])
    mm = mm.groupby(["permit", "vin", "month_start"], as_index=False)["miles"].max()
    counts["silver.dmv_mileage_monthly"] = len(mm)
    return d, mm


# ----------------------------------------------------------------------------- NHTSA
def silver_nhtsa(counts: dict) -> pd.DataFrame:
    n = read_tsv("nhtsa_sgo_ads.tsv")
    counts["bronze.nhtsa_sgo_ads"] = len(n)
    js = n["row_json"].map(json.loads)
    g = lambda k: js.map(lambda d: d.get(k))
    n["rid"] = n["Report ID"].str.strip(); n["ver"] = to_int(n["Report Version"])
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
    n = n[n["inc_month"].notna()]
    n["bucket"] = np.where(n["wf"] | n["wd"], "obscured", np.where(n["wr"] | n["wsn"], "rain",
                  np.where(n["wc"] | n["wcl"] | n["wpc"] | n["ww"], "normal", "unknown")))
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
    n["in_scope"] = n["st"].str[:2].isin(["CA", "AZ", "TX"]) & n["inc_month"].dt.year.between(2021, 2025)
    counts["silver.nhtsa_crash"] = len(n)
    return n


# ----------------------------------------------------------------------------- relative risks
def relative_risks(h: pd.DataFrame, d: pd.DataFrame, crash: pd.DataFrame,
                   dis: pd.DataFrame, miles: pd.DataFrame) -> pd.DataFrame:
    us = h.merge(STATIONS[STATIONS.country == "US"], on="station_id")
    rows = []
    c = crash[crash["in_scope"]]
    # weather
    ck = c[c["bucket"] != "unknown"]
    w = ck.groupby(ck["st"].str[:2]).size() / len(ck)
    es = us.groupby("us_state")["bucket"].value_counts(normalize=True).unstack(fill_value=0)
    exp = (es.loc[w.index].mul(w, axis=0)).sum()
    ev = ck["bucket"].value_counts(normalize=True); evn = ck["bucket"].value_counts()
    base = ev.get("normal", 0) / exp.get("normal", np.nan)
    for lv in ["normal", "rain", "obscured"]:
        rows.append(("nhtsa_crash", "weather", lv, int(evn.get(lv, 0)), ev.get(lv, 0), np.nan, exp.get(lv, np.nan),
                     (ev.get(lv, 0) / exp.get(lv, np.nan)) / base))
    # light
    cl = c[c["is_night"].notna()].copy(); cl["lv"] = np.where(cl["is_night"] == 1, "night", "day")
    w = cl.groupby(cl["st"].str[:2]).size() / len(cl)
    us["lv"] = np.where(us["is_night"], "night", "day")
    es = us.groupby("us_state")["lv"].value_counts(normalize=True).unstack(fill_value=0)
    exp = (es.loc[w.index].mul(w, axis=0)).sum()
    ev = cl["lv"].value_counts(normalize=True); evn = cl["lv"].value_counts()
    base = ev["day"] / exp["day"]
    for lv in ["day", "night"]:
        rows.append(("nhtsa_crash", "light", lv, int(evn.get(lv, 0)), ev.get(lv, 0), np.nan, exp.get(lv), (ev.get(lv, 0) / exp.get(lv)) / base))
    # disengagements
    ca = d.merge(STATIONS[STATIONS.us_state == "CA"][["station_id"]], on="station_id")
    cad = ca.groupby("local_date").agg(o=("obscured_hours", "max"), r=("rain_hours", "max")).reset_index()
    cad["day_type"] = np.where(cad["o"] >= 3, "obscured", np.where(cad["r"] >= 1, "rain", "normal"))
    mm = miles.groupby("month_start")["miles"].sum()
    cad["ms"] = cad["local_date"].dt.to_period("M").dt.to_timestamp()
    cad = cad[cad["ms"].isin(mm.index)]
    cad["miles_day"] = cad["ms"].map(mm) / cad["local_date"].dt.days_in_month
    nd = dis.groupby(dis["event_date"].dt.normalize()).size()
    cad["n"] = cad["local_date"].map(nd).fillna(0)
    agg = cad.groupby("day_type").agg(events=("n", "sum"), exposure=("miles_day", "sum"))
    base = agg.loc["normal", "events"] / agg.loc["normal", "exposure"]
    for lv in ["normal", "rain", "obscured"]:
        e = agg["events"].get(lv, 0); x = agg["exposure"].get(lv, np.nan)
        rows.append(("dmv_disengagement", "weather", lv, int(e), e / agg["events"].sum(), x, x / agg["exposure"].sum(), (e / x) / base))
    return pd.DataFrame(rows, columns=["event_source", "factor", "level", "events", "event_share", "exposure",
                                       "exposure_share", "relative_risk"])


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    counts: dict = {}
    wx = silver_weather(counts)
    h, d = prep_hours(wx)
    acc = silver_accidents(counts)
    dis, miles = silver_dmv(counts)
    crash = silver_nhtsa(counts)
    rr = relative_risks(h, d, crash, dis, miles)
    rr.to_csv(OUT / "relative_risk.csv", index=False)
    rr["used_in_index"] = (rr["events"] >= 30) & rr["relative_risk"].notna()
    rr.to_csv(OUT / "relative_risk.csv", index=False)

    def R(src, f, lv):
        x = rr[(rr.event_source == src) & (rr.factor == f) & (rr.level == lv)].iloc[0]
        return float(x.relative_risk) if x.used_in_index else 1.0

    sa = h.merge(STATIONS[STATIONS.country == "SA"], on="station_id")
    sa["month_start"] = sa["hour_local"].dt.to_period("M").dt.to_timestamp()
    hm = sa.groupby(["region_code", "station_id", "month_start"]).agg(
        hours=("bucket", "size"), temp_mean_c=("temp_c", "mean"), temp_max_c=("temp_max_c", "max"),
        wind_max_ms=("wind_max_ms", "max"), rain_mm=("precip_mm", "sum"), dust=("is_dust", "sum"),
        haze=("is_haze", "sum"), fog=("is_fog", "sum"), lowvis=("is_low_vis", "sum"), obsc=("is_obscured", "sum"),
        rain=("bucket", lambda s: (s == "rain").sum()), normal=("bucket", lambda s: (s == "normal").sum()),
        night=("is_night", "sum")).reset_index()
    dd = d.copy(); dd["month_start"] = dd["local_date"].dt.to_period("M").dt.to_timestamp()
    dm = dd.groupby(["station_id", "month_start"]).agg(
        days=("day_type", "size"), dust_days=("dust_hours", lambda s: (s > 0).sum()),
        obscured_days=("day_type", lambda s: (s == "obscured").sum()), rain_days=("day_type", lambda s: (s == "rain").sum()),
        normal_days=("day_type", lambda s: (s == "normal").sum())).reset_index()
    m = hm.merge(dm, on=["station_id", "month_start"])
    cal = pd.MultiIndex.from_product([STATIONS[STATIONS.country == "SA"]["region_code"],
                                      pd.date_range("2021-01-01", "2025-12-01", freq="MS")],
                                     names=["region_code", "month_start"]).to_frame(index=False)
    g = cal.merge(m, on=["region_code", "month_start"], how="left")
    g["year"] = g["month_start"].dt.year
    g = g.merge(acc.rename(columns={"year": "year"}), on=["region_code", "year"], how="left")
    hrs = g["hours"].replace(0, np.nan); dys = g["days"].replace(0, np.nan)
    for c in ["dust", "haze", "fog", "lowvis", "obsc", "rain", "normal", "night"]:
        g["share_" + c] = g[c] / hrs
    g["av_crash_risk_index"] = (g["share_normal"] + g["share_rain"] * R("nhtsa_crash", "weather", "rain")
                                + g["share_obsc"] * R("nhtsa_crash", "weather", "obscured"))
    g["av_diseng_risk_index"] = (g["normal_days"] / dys + g["rain_days"] / dys * R("dmv_disengagement", "weather", "rain")
                                 + g["obscured_days"] / dys * R("dmv_disengagement", "weather", "obscured"))
    g.to_csv(OUT / "gold_reference.csv", index=False)
    counts["gold.av_readiness_region_month"] = len(g)
    pd.Series(counts, name="rows").to_csv(OUT / "counts.csv")

    # data shares: records that feed Gold, by family
    fam = {
        "weather - Saudi stations (hourly reports)": int((wx["country"] == "SA").sum()),
        "weather - US analog stations (hourly reports)": int((wx["country"] == "US").sum()),
        "accidents - Saudi GASTAT (region-year values)": int(acc[["serious", "deaths", "injuries"]].notna().sum().sum()
                                                             + acc[["serious_within", "serious_outside"]].notna().sum().sum()),
        "AV - DMV disengagements": int(len(dis)),
        "AV - DMV mileage (vehicle-months)": int(len(miles)),
        "AV - NHTSA crashes (in scope)": int(crash["in_scope"].sum()),
    }
    s = pd.Series(fam, name="records").to_frame()
    s["share_pct"] = (100 * s["records"] / s["records"].sum()).round(2)
    s.to_csv(OUT / "data_shares.csv")
    print(pd.Series(counts).to_string())
    print(rr.to_string())
    print(s.to_string())
    print(g[["region_code", "month_start", "hours", "share_dust", "share_obsc", "share_rain", "share_night",
             "serious", "av_crash_risk_index", "av_diseng_risk_index"]].describe().to_string())


if __name__ == "__main__":
    main()
