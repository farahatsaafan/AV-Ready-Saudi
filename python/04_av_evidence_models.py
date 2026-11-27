"""
AV-Ready-Saudi - AV evidence cross-check with regression models (statsmodels).

The source of truth for Gold is the Mantel-Haenszel table built in SQL (prep.av_relative_risk). This script
re-estimates the same relative risks with GLMs on the same units, shows how much of the crude ratio is
confounding, and tests whether weather adds anything out of time. Every rule (condition vocabulary, day
type, strata) comes from python/02_reference_gold.py through importlib, so nothing is re-implemented.

  1. NHTSA crashes: Poisson GLM on state x month x category cells, offset log(station-hours),
     state-month fixed effects (= the MH strata).
  2. DMV disengagements on California days, offset log(fleet miles of the day):
       Poisson GLM with month + weekday-class fixed effects (= the MH strata: the +-10 % agreement check),
       Negative Binomial crude (n ~ day_type) and adjusted (n ~ day_type + C(month) + C(weekday)),
       robustness per manufacturer (MAY MOBILITY, APPLE INC, BEEP INC) and with SFO-only / LAX-only day types,
       hold-out: train Dec 2020 - Nov 2023, test Dec 2023 - Nov 2024, month-of-year + weekday model with vs
       without day_type (test deviance and MAE).
Outputs: Data/model/av_evidence_glm.csv, Data/model/av_evidence_holdout.csv,
         docs/figures/rr_crude_vs_adjusted.png (forest plot)
Usage: python3 python/04_av_evidence_models.py
"""
from __future__ import annotations

import importlib.util
import math
import sys
import warnings
from pathlib import Path

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")
import statsmodels.api as sm                      # noqa: E402
import statsmodels.formula.api as smf             # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location("ref", ROOT / "python" / "02_reference_gold.py")
ref = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ref)

MODEL = ROOT / "Data" / "model"
FIG = ROOT / "docs" / "figures"
LEVELS_DMV = ["rain", "fog_moist", "haze_dry"]


def _rr(fit, term: str):
    b = fit.params.get(term, np.nan)
    ci = fit.conf_int().loc[term] if term in fit.params.index else [np.nan, np.nan]
    return float(np.exp(b)), float(np.exp(ci[0])), float(np.exp(ci[1]))


def nhtsa_glm(cells: pd.DataFrame) -> list:
    """Poisson GLM with stratum (state x month) fixed effects; levels with no events are not estimable."""
    c = cells[(cells["t"] > 0)].copy()
    c["stratum"] = c["us_state"] + " " + c["month_start"].dt.strftime("%Y-%m")
    est = [lv for lv in ["rain", "obscured_unspecified"] if c.loc[c["lv"] == lv, "e"].sum() > 0]
    c = c[c["lv"].isin(["normal"] + est)]
    c["lv"] = pd.Categorical(c["lv"], categories=["normal"] + est)
    fit = smf.glm("e ~ C(lv) + C(stratum)", data=c, offset=np.log(c["t"]),
                  family=sm.families.Poisson()).fit()
    disp = fit.pearson_chi2 / fit.df_resid
    out = []
    for lv in est:
        r = _rr(fit, f"C(lv)[T.{lv}]")
        out.append(("nhtsa_crash", "Poisson GLM, state x month FE", lv, *r, int(c.loc[c["lv"] == lv, "e"].sum()), disp))
    return out


def nb_fit(formula: str, x: pd.DataFrame):
    return smf.negativebinomial(formula, data=x, offset=np.log(x["t"])).fit(disp=0, maxiter=300)


def dmv_models(x: pd.DataFrame, label: str, full: bool = True) -> list:
    x = x[x["day_type"].isin(["normal"] + LEVELS_DMV)].copy()
    x["dt"] = pd.Categorical(x["day_type"], categories=["normal"] + LEVELS_DMV)
    x["mo"] = x["month_start"].dt.strftime("%Y-%m")
    out = []
    specs = [("NB GLM adjusted: month + weekday FE", "e ~ dt + C(mo) + C(weekday)", "nb")]
    if full:
        specs = [("Poisson GLM, month x weekday-class FE (= MH strata)", "e ~ dt + C(mo):C(weekend)", "poisson"),
                 ("NB GLM crude", "e ~ dt", "nb")] + specs
    for name, f, fam in specs:
        if fam == "poisson":
            fit = smf.glm(f, data=x, offset=np.log(x["t"]), family=sm.families.Poisson()).fit()
            disp = fit.pearson_chi2 / fit.df_resid
        else:
            fit = nb_fit(f, x)
            disp = float(fit.params["alpha"])
        for lv in LEVELS_DMV:
            r = _rr(fit, f"dt[T.{lv}]")
            out.append((label, name, lv, *r, int(x.loc[x["day_type"] == lv, "e"].sum()), disp))
    return out


def station_day_types(d: pd.DataFrame, station_id: str) -> pd.DataFrame:
    s = d[d["station_id"] == station_id][["local_date", "dust_hours", "haze_dry_hours", "fog_moist_hours", "rain_hours"]]
    s = s.rename(columns={"dust_hours": "dust", "haze_dry_hours": "haze_dry", "fog_moist_hours": "fog_moist",
                          "rain_hours": "rain"})
    s["day_type"] = ref.day_type(s["dust"], s["haze_dry"], s["fog_moist"], s["rain"])
    return s


def holdout(x: pd.DataFrame) -> pd.DataFrame:
    """Out-of-time test: does knowing the day's weather improve the prediction of disengagements?"""
    x = x[x["day_type"].isin(["normal"] + LEVELS_DMV)].copy()
    x["dt"] = pd.Categorical(x["day_type"], categories=["normal"] + LEVELS_DMV)
    x["moy"] = x["month_start"].dt.month
    tr = x[x["month_start"] <= "2023-11-01"]
    te = x[(x["month_start"] >= "2023-12-01") & (x["month_start"] <= "2024-11-01")]
    rows = []
    for name, f in [("month-of-year + weekday", "e ~ C(moy) + C(weekday)"),
                    ("month-of-year + weekday + day_type", "e ~ C(moy) + C(weekday) + dt")]:
        alpha = float(nb_fit(f, tr).params["alpha"])
        fit = smf.glm(f, data=tr, offset=np.log(tr["t"]), family=sm.families.NegativeBinomial(alpha=alpha)).fit()
        mu = fit.predict(te, offset=np.log(te["t"]))
        dev = float(sm.families.NegativeBinomial(alpha=alpha).deviance(te["e"].to_numpy(), mu.to_numpy()))
        rows.append((name, len(tr), len(te), round(alpha, 4), dev, float(np.mean(np.abs(te["e"] - mu)))))
    return pd.DataFrame(rows, columns=["model", "train_days", "test_days", "nb_alpha", "test_deviance", "test_mae"])


def forest_plot(rr: pd.DataFrame, path: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    rows = rr[(rr["factor"] == "weather") & (rr["condition_code"] != "normal") & (rr["events"] > 0)].copy()
    rows["label"] = rows["event_source"].map({"nhtsa_crash": "NHTSA crashes", "dmv_disengagement": "DMV disengagements"}) \
        + " - " + rows["condition_code"] + " (" + rows["events"].map("{:,}".format) + " events)"
    rows = rows.sort_values(["event_source", "condition_code"], ascending=[False, True]).reset_index(drop=True)
    blue, orange, ink, ink2, grid = "#257de0", "#f47230", "#191919", "#666666", "#e5e5e5"
    lo_x, hi_x = 0.6, 2.4
    fig = plt.figure(figsize=(11, 0.75 * len(rows) + 2.0), dpi=150)
    ax = fig.add_axes([0.29, 0.16, 0.45, 0.70])
    y = np.arange(len(rows))[::-1].astype(float)
    for i, r in rows.iterrows():
        yy = y[i]
        if r["rr_adjusted"] < lo_x:      # off scale: say it in words instead of squeezing the axis
            ax.text(lo_x * 1.03, yy, f"RR {r['rr_adjusted']:.2f} [{r['ci_low']:.3f}, {r['ci_high']:.2f}], crude "
                    f"{r['rr_crude']:.2f}: off scale, only {r['events']} events - implausible (artefact), not used",
                    va="center", fontsize=8, color=ink2)
            continue
        if pd.notna(r["ci_low"]):
            ax.plot([max(r["ci_low"], lo_x), min(r["ci_high"], hi_x)], [yy, yy], color=blue, lw=2,
                    solid_capstyle="round", zorder=2)
        ax.scatter([r["rr_adjusted"]], [yy], s=70, color=blue, edgecolor="white", linewidth=2, zorder=3)
        ax.scatter([r["rr_crude"]], [yy + 0.25], s=50, marker="D", color=orange, edgecolor="white", linewidth=1.5, zorder=3)
        note = {1: "used in Gold"}.get(int(r["used_in_index"]), "reported, not used" if r["ci_low"] > 1 else "not used")
        ax.text(1.01, yy, f"{r['rr_adjusted']:.2f} [{r['ci_low']:.2f}, {r['ci_high']:.2f}]  {note}",
                transform=ax.get_yaxis_transform(), va="center", fontsize=8, color=ink)
    ax.scatter([], [], s=70, color=blue, label="adjusted: Mantel-Haenszel, 95 % CI")
    ax.scatter([], [], s=50, marker="D", color=orange, label="crude: pooled ratio, no strata")
    ax.axvline(1, color=ink2, lw=1, ls="--", zorder=1)
    ax.set_xscale("log")
    ax.set_xlim(lo_x, hi_x)
    ax.set_ylim(-0.6, len(rows) - 0.2)
    ticks = [0.6, 0.8, 1, 1.5, 2]
    ax.set_xticks(ticks); ax.set_xticklabels([f"{t:g}" for t in ticks]); ax.minorticks_off()
    ax.set_yticks(y)
    ax.set_yticklabels(rows["label"], fontsize=8.5, color=ink)
    ax.grid(axis="x", color=grid, lw=0.8)
    for s_ in ["top", "right", "left"]:
        ax.spines[s_].set_visible(False)
    ax.spines["bottom"].set_color(ink2)
    ax.tick_params(colors=ink2, labelsize=8)
    ax.set_xlabel("relative risk vs normal weather (log scale; 1 = no effect)", color=ink2, fontsize=8.5)
    ax.set_title("AV events by weather: crude ratio vs stratified ratio", loc="left", fontsize=11, color=ink, pad=22)
    ax.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=2, fontsize=8, frameon=False, borderaxespad=0.2)
    fig.text(0.01, 0.01, "NHTSA strata: state x incident month, exposure = station-hours. DMV strata: month x weekday "
             "class, exposure = fleet miles; CI widened by the overdispersion factor.", fontsize=6.8, color=ink2)
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path)
    plt.close(fig)


def main() -> int:
    MODEL.mkdir(parents=True, exist_ok=True)
    counts: dict = {}
    wx = ref.silver_weather(counts)
    h, d = ref.prep_hours(wx)
    dis, miles = ref.silver_dmv(counts)
    crash = ref.silver_nhtsa(counts)
    rr = ref.relative_risks(h, d, crash, dis, miles)
    us = ref.us_hours(h)

    rows = nhtsa_glm(ref.nhtsa_cells(us, crash, "weather"))
    cad = ref.ca_days(d)
    x_all = ref.dmv_days(cad, dis, miles)
    rows += dmv_models(x_all, "dmv_disengagement")
    for m in ["MAY MOBILITY", "APPLE INC", "BEEP INC"]:
        x = ref.dmv_days(cad, dis[dis["manufacturer_clean"].str.contains(m)], miles[miles["manufacturer"].str.contains(m)])
        rows += dmv_models(x, f"dmv {m}", full=False)
    for sid, nm in [("72494023234", "SFO only"), ("72295023174", "LAX only")]:
        rows += dmv_models(ref.dmv_days(station_day_types(d, sid), dis, miles), f"dmv day types {nm}", full=False)
    glm = pd.DataFrame(rows, columns=["data", "model", "condition_code", "rr", "ci_low", "ci_high", "events",
                                      "dispersion_or_alpha"])
    glm.to_csv(MODEL / "av_evidence_glm.csv", index=False)
    ho = holdout(x_all)
    ho.to_csv(MODEL / "av_evidence_holdout.csv", index=False)
    forest_plot(rr, FIG / "rr_crude_vs_adjusted.png")

    pd.set_option("display.width", 220)
    print("Mantel-Haenszel (source of truth, same as prep.av_relative_risk):")
    print(rr[["event_source", "factor", "condition_code", "events", "rr_crude", "rr_adjusted", "ci_low", "ci_high",
              "dispersion", "used_in_index", "evidence_note"]].to_string(index=False))
    print("\nGLM estimates:")
    print(glm.to_string(index=False))
    # agreement check: GLM on the same strata as MH must agree within +-10 %
    print("\nMH vs GLM on the same strata (must agree within 10 %):")
    ok = True
    pairs = [("nhtsa_crash", "Poisson GLM, state x month FE", "nhtsa_crash"),
             ("dmv_disengagement", "Poisson GLM, month x weekday-class FE (= MH strata)", "dmv_disengagement")]
    for data, model, src in pairs:
        g = glm[(glm["data"] == data) & (glm["model"] == model)]
        for _, r in g.iterrows():
            mh = rr[(rr["event_source"] == src) & (rr["condition_code"] == r["condition_code"])]["rr_adjusted"].iloc[0]
            diff = abs(r["rr"] / mh - 1)
            flag = "PASS" if diff <= 0.10 else "FAIL"
            ok &= diff <= 0.10
            print(f"  {src:18s} {r['condition_code']:22s} MH {mh:7.3f}  GLM {r['rr']:7.3f}  diff {100 * diff:5.1f} %  {flag}")
    print("\nHold-out (train Dec 2020 - Nov 2023, test Dec 2023 - Nov 2024):")
    print(ho.to_string(index=False))
    better = ho.iloc[1]["test_deviance"] < ho.iloc[0]["test_deviance"]
    print("  weather day type " + ("improves" if better else "does NOT improve") + " the out-of-time prediction "
          f"(deviance {ho.iloc[0]['test_deviance']:.1f} -> {ho.iloc[1]['test_deviance']:.1f})")
    print("\nRESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
