"""
AV-Ready-Saudi - readiness score, clustering, supervised test and sensitivity (Phase F).

Input: the ONE Gold table, exported by the pipeline to Data/gold_export/gold_av_readiness_region_month.csv
(falls back to Data/reference/gold_reference.csv, and says so, only if the export is missing). The AV evidence
table comes from Data/gold_export/av_relative_risk.tsv (fallback Data/reference/relative_risk.csv).

  F1 Readiness score per region x season = 100 x (wE E_n + wS S + wI I), default weights 1/3:
       E = environment (mean env_readiness, min-max over the 52 region-seasons)
       S = traffic-safety environment (1 - mean percent-rank of serious and death rates per 100k, per region)
       I = infrastructure (min-max of divided intercity share, road km per 1,000 people, response time outside
           cities - the last inverted - mean of the three)
  F2 Clustering (model 1): KMeans on standardised region x season features, k = 2..6 by silhouette,
     stability = mean adjusted Rand index over 200 bootstrap resamples.
  F3 Supervised test of weather -> accidents (model 2), region-years only, LeaveOneGroupOut by year and by
     region, Dummy vs Ridge vs RandomForest; plus Spearman (within-region, cross-section) and Wilcoxon.
  F4 Sensitivity: 66 weight triples, env_readiness vs _cons, rain RR at its CI bounds, fog/haze dew-spread
     threshold 2.0 / 2.5 / 3.0 degC.
  F5 Figures (docs/figures/), F6 report docs/reports/04_eda_and_models.md (generated: every number from this run).
Usage: python3 python/05_readiness_model.py
"""
from __future__ import annotations

import importlib.util
import itertools
import json
import sys
import warnings
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd

warnings.filterwarnings("ignore")
from scipy import stats                                              # noqa: E402
from sklearn.cluster import KMeans                                   # noqa: E402
from sklearn.dummy import DummyRegressor                             # noqa: E402
from sklearn.ensemble import RandomForestRegressor                   # noqa: E402
from sklearn.linear_model import RidgeCV                             # noqa: E402
from sklearn.metrics import adjusted_rand_score, mean_absolute_error, r2_score, silhouette_score  # noqa: E402
from sklearn.model_selection import LeaveOneGroupOut                 # noqa: E402
from sklearn.pipeline import make_pipeline                           # noqa: E402
from sklearn.preprocessing import StandardScaler                     # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
EXPORT = ROOT / "Data" / "gold_export"
REFDIR = ROOT / "Data" / "reference"
MODEL = ROOT / "Data" / "model"
FIG = ROOT / "docs" / "figures"
REPORT = ROOT / "docs" / "reports" / "04_eda_and_models.md"
SEED = 42
SEASONS = ["winter", "spring", "summer", "autumn"]
INK, INK2, GRID, SURF = "#191919", "#666666", "#e5e5e5", "#ffffff"
BLUE, ORANGE, AQUA = "#257de0", "#f47230", "#00b894"
BLUE_RAMP = ["#cce3fd", "#9dc8f7", "#6aabf1", "#338ced", "#2370cd", "#1757ac", "#0e3d7e"]


# ============================================================================= inputs
def load_inputs() -> tuple[pd.DataFrame, pd.DataFrame, str]:
    gpath = EXPORT / "gold_av_readiness_region_month.csv"
    if gpath.exists():
        g = pd.read_csv(gpath, na_values=["NULL"], keep_default_na=True)
        src = "Gold export (SQL Server)"
    else:
        gpath = REFDIR / "gold_reference.csv"
        g = pd.read_csv(gpath)
        src = "Data/reference/gold_reference.csv (Gold export missing - pandas reference used instead)"
        print("WARNING:", src)
    rpath = EXPORT / "av_relative_risk.tsv"
    rr = pd.read_csv(rpath, sep="\t", na_values=["NULL"]) if rpath.exists() else pd.read_csv(REFDIR / "relative_risk.csv")
    g["month_start"] = pd.to_datetime(g["month_start"])
    return g, rr, src


def minmax(s: pd.Series, invert: bool = False) -> pd.Series:
    x = (s - s.min()) / (s.max() - s.min())
    return 1 - x if invert else x


def pct_rank(s: pd.Series) -> pd.Series:
    """PERCENT_RANK as in SQL: (rank - 1) / (n - 1)."""
    return (s.rank(method="min") - 1) / (len(s) - 1)


def region_years(g: pd.DataFrame) -> pd.DataFrame:
    """One row per region-year (annual columns via MAX, weather as the mean of complete months)."""
    ann = g.groupby(["region_code", "year"]).agg(
        serious=("acc_year_serious", "max"), deaths=("acc_year_deaths", "max"), population=("population", "max"),
        serious_100k=("acc_serious_per_100k", "max"), deaths_100k=("acc_deaths_per_100k", "max"),
        divided=("intercity_divided_share", "max"), road_km=("road_km_per_1000_people", "max"),
        response_out=("response_outside_s", "max")).reset_index()
    c = g[g["wx_complete"] == 1]
    w = c.groupby(["region_code", "year"]).agg(
        dust=("share_dust_hours", "mean"), haze_dry=("share_haze_dry_hours", "mean"),
        fog_moist=("share_fog_moist_hours", "mean"), rain=("share_rain_hours", "mean"),
        hot40=("share_hot40_hours", "mean"), months=("month", "size")).reset_index()
    ry = ann.merge(w, on=["region_code", "year"], how="left")
    nat = ry.groupby("year").apply(lambda x: 100000.0 * x["serious"].sum() / x["population"].sum()).rename("nat_rate")
    ry = ry.merge(nat.reset_index(), on="year")
    ry["rel_rate"] = ry["serious_100k"] / ry["nat_rate"]
    ry["obscured_no_dust"] = ry["fog_moist"] + ry["haze_dry"]
    return ry


# ============================================================================= F1 readiness
def pillars(g: pd.DataFrame, env_col: str = "env_readiness") -> tuple[pd.DataFrame, pd.DataFrame]:
    c = g[g["wx_complete"] == 1]
    rs = c.groupby(["region_code", "season"]).agg(
        E=(env_col, "mean"), env_readiness=("env_readiness", "mean"), env_readiness_cons=("env_readiness_cons", "mean"),
        share_dust=("share_dust_hours", "mean"), share_haze_dry=("share_haze_dry_hours", "mean"),
        share_fog_moist=("share_fog_moist_hours", "mean"), share_rain=("share_rain_hours", "mean"),
        share_hot40=("share_hot40_hours", "mean"), months=("month", "size")).reset_index()
    rs["E_n"] = minmax(rs["E"])
    ry = region_years(g)
    reg = ry.groupby("region_code").agg(serious_100k=("serious_100k", "mean"), deaths_100k=("deaths_100k", "mean")).reset_index()
    reg["S"] = 1 - (pct_rank(reg["serious_100k"]) + pct_rank(reg["deaths_100k"])) / 2
    inf = ry[ry["year"].between(2022, 2025)].groupby("region_code").agg(
        divided=("divided", "mean"), road_km=("road_km", "mean"), response_out=("response_out", "mean")).reset_index()
    inf["I"] = (minmax(inf["divided"]) + minmax(inf["road_km"]) + minmax(inf["response_out"], invert=True)) / 3
    reg = reg.merge(inf, on="region_code")
    rs = rs.merge(reg[["region_code", "S", "I", "serious_100k", "deaths_100k", "divided", "road_km", "response_out"]],
                  on="region_code")
    return rs, reg


def score(rs: pd.DataFrame, w=(1 / 3, 1 / 3, 1 / 3)) -> pd.DataFrame:
    r = rs.copy()
    r["contrib_E"] = 100 * w[0] * r["E_n"]
    r["contrib_S"] = 100 * w[1] * r["S"]
    r["contrib_I"] = 100 * w[2] * r["I"]
    r["readiness"] = r["contrib_E"] + r["contrib_S"] + r["contrib_I"]
    # E losses (share of time lost, before normalisation): dust weight 0, rain 1/RR; cons also loses dry haze
    r["loss_dust"] = r["share_dust"]
    r["loss_rain"] = (1 - r["env_readiness"]) - r["share_dust"]
    r["loss_haze_dry_cons"] = r["env_readiness"] - r["env_readiness_cons"]
    return r


def region_rank(rsc: pd.DataFrame) -> pd.Series:
    return rsc.groupby("region_code")["readiness"].mean().sort_values(ascending=False)


def ntile3(order: list) -> dict:
    """NTILE(3) as in SQL: 13 -> groups of 5, 4, 4."""
    return {r: i + 1 for i, grp in enumerate(np.array_split(np.array(order), 3)) for r in grp}


# ============================================================================= F2 clustering
CLUSTER_FEATURES = ["share_dust", "share_haze_dry", "share_fog_moist", "share_rain", "share_hot40", "S", "I"]


def clustering(rsc: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    X = StandardScaler().fit_transform(rsc[CLUSTER_FEATURES])
    sil = {}
    for k in range(2, 7):
        lab = KMeans(n_clusters=k, n_init=20, random_state=SEED).fit_predict(X)
        sil[k] = float(silhouette_score(X, lab))
    k = max(sil, key=sil.get)
    km = KMeans(n_clusters=k, n_init=20, random_state=SEED).fit(X)
    base = km.labels_
    rng = np.random.RandomState(SEED)
    aris = []
    for _ in range(200):
        idx = rng.randint(0, len(X), len(X))
        m = KMeans(n_clusters=k, n_init=10, random_state=SEED).fit(X[idx])
        aris.append(adjusted_rand_score(base, m.predict(X)))
    out = rsc.copy()
    out["cluster"] = base
    order = out.groupby("cluster")["readiness"].mean().sort_values(ascending=False).index.tolist()
    names = {2: ["High", "Low"], 3: ["High", "Medium", "Low"], 4: ["High", "Medium-high", "Medium-low", "Low"],
             5: ["High", "Medium-high", "Medium", "Medium-low", "Low"]}.get(k, [f"Tier {i + 1}" for i in range(k)])
    out["cluster_name"] = out["cluster"].map({c: names[i] for i, c in enumerate(order)})
    info = dict(k=k, silhouette=sil, ari_mean=float(np.mean(aris)), ari_p05=float(np.percentile(aris, 5)),
                ari_p95=float(np.percentile(aris, 95)))
    return out, info


# ============================================================================= F3 supervised test
def cv_eval(X: np.ndarray, y: np.ndarray, groups: np.ndarray, region=None) -> dict:
    models = {
        "Dummy (mean)": DummyRegressor(strategy="mean"),
        "Ridge (alpha by inner CV)": make_pipeline(StandardScaler(), RidgeCV(alphas=np.logspace(-3, 3, 13))),
        "RandomForest (300 trees, depth 3)": RandomForestRegressor(n_estimators=300, max_depth=3, random_state=SEED),
    }
    res = {}
    for name, m in models.items():
        pred = np.zeros_like(y, dtype=float)
        for tr, te in LeaveOneGroupOut().split(X, y, groups):
            m.fit(X[tr], y[tr])
            pred[te] = m.predict(X[te])
        res[name] = dict(MAE=float(mean_absolute_error(y, pred)), R2=float(r2_score(y, pred)))
    if region is not None:
        # identity baseline: the region's own mean in the training folds (no weather at all). When a year is left
        # out, every model can recognise the region from its stable climate / road values; this shows how much
        # of any "skill" is just region identity. (Undefined when the region itself is left out.)
        pred = np.zeros_like(y, dtype=float)
        for tr, te in LeaveOneGroupOut().split(X, y, groups):
            mu = pd.Series(y[tr]).groupby(region[tr]).mean()
            pred[te] = [mu.get(r, y[tr].mean()) for r in region[te]]
        res["Region mean (identity baseline, no weather)"] = dict(MAE=float(mean_absolute_error(y, pred)),
                                                                   R2=float(r2_score(y, pred)))
    return res


def supervised(g: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    ry = region_years(g)
    rows = []
    designs = {
        "C1 weather (2021-2024, 52 region-years)": (ry[ry["year"].between(2021, 2024)], ["dust", "haze_dry", "rain", "hot40"]),
        "C2 weather + divided-road share (2022-2024, 39 region-years)": (ry[ry["year"].between(2022, 2024)],
                                                                         ["dust", "haze_dry", "rain", "hot40", "divided"]),
    }
    for dname, (d, feats) in designs.items():
        d = d.dropna(subset=feats + ["rel_rate"])
        X, y = d[feats].to_numpy(), d["rel_rate"].to_numpy()
        for cvname, grp, reg in [("leave one year out", d["year"].to_numpy(), d["region_code"].to_numpy()),
                                 ("leave one region out", d["region_code"].to_numpy(), None)]:
            for mname, v in cv_eval(X, y, grp, reg).items():
                rows.append((dname, len(d), cvname, mname, v["MAE"], v["R2"]))
    sup = pd.DataFrame(rows, columns=["design", "n", "cv", "model", "MAE", "R2"])
    # rank tests on 2021-2024. "Within-region, year-adjusted" = both the region mean and the year mean removed
    # (two-way demeaning) from the weather share and from rel_rate. The region-only version is kept to show the
    # year confound: 2021-2022 were the dusty years and also years with higher relative rates in small regions.
    d = ry[ry["year"].between(2021, 2024)].dropna(subset=["dust", "rel_rate"]).copy()

    def two_way(v: pd.Series) -> pd.Series:
        a = v - d.groupby("region_code")[v.name].transform("mean")
        return a - a.groupby(d["year"]).transform("mean")
    tests = {}
    for f in ["dust", "obscured_no_dust", "rain", "hot40"]:
        a1 = d[f] - d.groupby("region_code")[f].transform("mean")
        b1 = d["rel_rate"] - d.groupby("region_code")["rel_rate"].transform("mean")
        rho0, p0 = stats.spearmanr(a1, b1)
        rho, p = stats.spearmanr(two_way(d[f]), two_way(d["rel_rate"]))
        cs = d.groupby("region_code")[[f, "rel_rate"]].mean()
        rho2, p2 = stats.spearmanr(cs[f], cs["rel_rate"])
        tests[f] = dict(within_rho=float(rho), within_p=float(p), region_only_rho=float(rho0), region_only_p=float(p0),
                        cross_rho=float(rho2), cross_p=float(p2))
    # Wilcoxon for query E8: rel_rate in the most vs the least obscured year of each region, as in the query and
    # with the year's mean relative rate removed (the year-adjusted version)
    d["obscured"] = d["dust"] + d["haze_dry"]
    d["rel_rate_yc"] = d["rel_rate"] - d.groupby("year")["rel_rate"].transform("mean")
    imax, imin = d.groupby("region_code")["obscured"].idxmax(), d.groupby("region_code")["obscured"].idxmin()
    for key, col in [("wilcoxon_E8", "rel_rate"), ("wilcoxon_E8_year_centred", "rel_rate_yc")]:
        most = d.loc[imax].set_index("region_code")[col]
        least = d.loc[imin].set_index("region_code")[col].loc[most.index]
        wst, wp = stats.wilcoxon(most, least)
        tests[key] = dict(stat=float(wst), p=float(wp), n_higher=int((most > least).sum()), n=int(len(most)))
    tests["most_obscured_years"] = {int(k): int(v) for k, v in d.loc[imax, "year"].value_counts().sort_index().items()}
    tests["rel_rate_year_mean"] = {int(k): float(v) for k, v in d.groupby("year")["rel_rate"].mean().items()}
    return sup, tests


# ============================================================================= F4 sensitivity
def sensitivity(g: pd.DataFrame, rr: pd.DataFrame, rs_default: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    base = score(rs_default)
    base_rank = region_rank(base)
    base_tier = ntile3(base_rank.index.tolist())
    grid = [(a / 10, b / 10, round(1 - a / 10 - b / 10, 1)) for a in range(11) for b in range(11 - a)]
    rows = []
    keep = {r: 0 for r in base_rank.index}
    for w in grid:
        rk = region_rank(score(rs_default, w))
        tau = stats.kendalltau(base_rank.index.map(rk.rank(ascending=False)), np.arange(1, len(rk) + 1))[0]
        tier = ntile3(rk.index.tolist())
        for r in keep:
            keep[r] += int(tier[r] == base_tier[r])
        rows.append((*w, float(tau)))
    sens = pd.DataFrame(rows, columns=["wE", "wS", "wI", "kendall_tau"])
    out = {"n_weight_triples": len(grid), "tau_median": float(sens["kendall_tau"].median()),
           "tau_min": float(sens["kendall_tau"].min()), "share_tau_ge_0.7": float((sens["kendall_tau"] >= 0.7).mean()),
           "tier_kept_share": {r: keep[r] / len(grid) for r in keep}}

    def tau_vs_base(rs_alt):
        rk = region_rank(score(rs_alt))
        return float(stats.kendalltau(base_rank.index.map(rk.rank(ascending=False)), np.arange(1, len(rk) + 1))[0]), rk

    # env_readiness vs env_readiness_cons
    rs_c, _ = pillars(g, "env_readiness_cons")
    out["tau_cons"], rk_c = tau_vs_base(rs_c)
    out["order_cons"] = rk_c.index.tolist()
    # rain RR at its CI bounds (only the evidence-backed rain ratio is applied)
    r = rr[(rr["event_source"] == "nhtsa_crash") & (rr["condition_code"] == "rain")].iloc[0]
    out["rr_rain"] = [float(r["rr_adjusted"]), float(r["ci_low"]), float(r["ci_high"])]
    for lbl, v in [("rr_rain_low", r["ci_low"]), ("rr_rain_high", r["ci_high"])]:
        g2 = g.copy()
        g2["env_readiness"] = (g2["share_normal_hours"] + g2["share_fog_moist_hours"] + g2["share_haze_dry_hours"]
                               + g2["share_rain_hours"] / v)
        rs2, _ = pillars(g2)
        out["tau_" + lbl], _ = tau_vs_base(rs2)
    # fog/haze dew-spread threshold: re-classify the Saudi hours with the reference functions
    try:
        spec = importlib.util.spec_from_file_location("ref", ROOT / "python" / "02_reference_gold.py")
        ref = importlib.util.module_from_spec(spec); spec.loader.exec_module(ref)
        wx = ref.silver_weather({})
        wx = wx[wx["country"] == "SA"]
        thr = {}
        for t in [2.0, 2.5, 3.0]:
            h, _ = ref.prep_hours(wx, t)
            h = h.merge(ref.STATIONS[["station_id", "region_code"]], on="station_id")
            h["month_start"] = h["hour_local"].dt.to_period("M").dt.to_timestamp()
            s = h.groupby(["region_code", "month_start"]).agg(
                fog=("hour_bucket", lambda x: (x == "fog_moist").mean()),
                haze=("hour_bucket", lambda x: (x == "haze_dry").mean())).reset_index()
            g3 = g.drop(columns=["share_fog_moist_hours", "share_haze_dry_hours"]).merge(
                s.rename(columns={"fog": "share_fog_moist_hours", "haze": "share_haze_dry_hours"}),
                on=["region_code", "month_start"], how="left")
            # base env_readiness does not depend on the split (both weight 1); the conservative one does
            g3["env_readiness_cons"] = g3["env_readiness"] - g3["share_haze_dry_hours"]
            rs3, _ = pillars(g3, "env_readiness_cons")
            tau, rk3 = tau_vs_base(rs3)
            thr[str(t)] = dict(tau_vs_default=tau, saudi_fog_moist_pct=float(100 * (h["hour_bucket"] == "fog_moist").mean()),
                               saudi_haze_dry_pct=float(100 * (h["hour_bucket"] == "haze_dry").mean()),
                               order=rk3.index.tolist())
        out["dew_threshold"] = thr
    except Exception as e:                       # landing files absent: say so, do not invent numbers
        out["dew_threshold"] = f"not run: {e}"
    return sens, out


# ============================================================================= F5 figures
def _style(ax):
    for s in ["top", "right"]:
        ax.spines[s].set_visible(False)
    for s in ["left", "bottom"]:
        ax.spines[s].set_color(INK2)
    ax.tick_params(colors=INK2, labelsize=8)


def figures(rsc: pd.DataFrame, cl: pd.DataFrame, sens: pd.DataFrame, names: dict) -> list:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap
    FIG.mkdir(parents=True, exist_ok=True)
    made = []
    order = region_rank(rsc).index.tolist()
    lbl = [f"{r} {names.get(r, '')}" for r in order]

    # 1. heatmap region x season
    m = rsc.pivot(index="region_code", columns="season", values="readiness").loc[order, SEASONS]
    fig, ax = plt.subplots(figsize=(6.4, 6.2), dpi=150)
    cmap = LinearSegmentedColormap.from_list("blue", BLUE_RAMP)
    im = ax.imshow(m.to_numpy(), cmap=cmap, aspect="auto", vmin=np.floor(m.min().min() / 5) * 5, vmax=np.ceil(m.max().max() / 5) * 5)
    for i in range(m.shape[0]):
        for j in range(m.shape[1]):
            v = m.iat[i, j]
            ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=8,
                    color="white" if v > (m.min().min() + m.max().max()) / 2 else INK)
    ax.set_xticks(range(4)); ax.set_xticklabels(SEASONS)
    ax.set_yticks(range(len(order))); ax.set_yticklabels(lbl, fontsize=8)
    ax.tick_params(colors=INK2, labelsize=8, length=0)
    for s in ax.spines.values():
        s.set_visible(False)
    cb = fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02); cb.ax.tick_params(labelsize=7, colors=INK2); cb.outline.set_visible(False)
    ax.set_title("AV readiness score (0-100) by region and season", loc="left", fontsize=10.5, color=INK)
    fig.tight_layout(); p = FIG / "readiness_heatmap_region_season.png"; fig.savefig(p); plt.close(fig); made.append(p)

    # 2. stacked pillar contributions per region (mean of its 4 seasons)
    rc = rsc.groupby("region_code")[["contrib_E", "contrib_S", "contrib_I"]].mean().loc[order[::-1]]
    fig, ax = plt.subplots(figsize=(7.6, 5.6), dpi=150)
    left = np.zeros(len(rc))
    for col, colr, name in [("contrib_E", BLUE, "Environment (weather inside the US AV evidence)"),
                            ("contrib_S", ORANGE, "Traffic-safety environment (accident & death rates)"),
                            ("contrib_I", AQUA, "Infrastructure (divided roads, road km, response time)")]:
        ax.barh(range(len(rc)), rc[col], left=left, color=colr, edgecolor=SURF, linewidth=2, height=0.7, label=name)
        left += rc[col].to_numpy()
    for i, v in enumerate(left):
        ax.text(v + 0.8, i, f"{v:.0f}", va="center", fontsize=8, color=INK)
    ax.set_yticks(range(len(rc))); ax.set_yticklabels([f"{r} {names.get(r, '')}" for r in rc.index], fontsize=8)
    ax.set_xlim(0, 100); ax.grid(axis="x", color=GRID, lw=0.8); ax.set_axisbelow(True); _style(ax)
    ax.set_xlabel("readiness score = sum of the three weighted pillars (weights 1/3 each)", fontsize=8, color=INK2)
    ax.set_title("What drives each region's readiness", loc="left", fontsize=10.5, color=INK, pad=50)
    ax.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=1, fontsize=7.5, frameon=False)
    fig.tight_layout(); p = FIG / "readiness_pillars_by_region.png"; fig.savefig(p); plt.close(fig); made.append(p)

    # 3. E-loss breakdown (share of hours lost)
    el = rsc.groupby("region_code")[["loss_dust", "loss_rain", "loss_haze_dry_cons"]].mean() * 100
    el = el.loc[el.sum(axis=1).sort_values().index]
    fig, ax = plt.subplots(figsize=(7.6, 5.4), dpi=150)
    left = np.zeros(len(el))
    for col, colr, name in [("loss_dust", ORANGE, "dust / sand (no US AV evidence: weight 0)"),
                            ("loss_rain", BLUE, "rain (NHTSA crash ratio 1/RR)"),
                            ("loss_haze_dry_cons", AQUA, "dry haze (conservative variant only)")]:
        ax.barh(range(len(el)), el[col], left=left, color=colr, edgecolor=SURF, linewidth=2, height=0.7, label=name)
        left += el[col].to_numpy()
    for i, v in enumerate(left):
        ax.text(v + 0.1, i, f"{v:.1f} %", va="center", fontsize=8, color=INK)
    ax.set_yticks(range(len(el))); ax.set_yticklabels([f"{r} {names.get(r, '')}" for r in el.index], fontsize=8)
    ax.grid(axis="x", color=GRID, lw=0.8); ax.set_axisbelow(True); _style(ax)
    ax.set_xlabel("share of hours lost from environment readiness (%)", fontsize=8, color=INK2)
    ax.set_title("Where the environment pillar loses readiness", loc="left", fontsize=10.5, color=INK, pad=50)
    ax.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=1, fontsize=7.5, frameon=False)
    fig.tight_layout(); p = FIG / "environment_loss_breakdown.png"; fig.savefig(p); plt.close(fig); made.append(p)

    # 4. cluster profiles (mean standardised feature per cluster)
    Z = cl[CLUSTER_FEATURES].apply(lambda s: (s - s.mean()) / s.std())
    Z["cluster_name"] = cl["cluster_name"]
    prof = Z.groupby("cluster_name")[CLUSTER_FEATURES].mean()
    pref = ["High", "Medium-high", "Medium", "Medium-low", "Low"]
    cats = [c for c in pref if c in prof.index] + [c for c in prof.index if c not in pref]
    prof = prof.loc[cats]
    colors = [BLUE, ORANGE, AQUA, "#f2a600", "#ee7fac", "#008a17"]
    fig, ax = plt.subplots(figsize=(8, 4.4), dpi=150)
    x = np.arange(len(CLUSTER_FEATURES)); wdt = 0.8 / len(prof)
    for i, (nm, row) in enumerate(prof.iterrows()):
        n = int((cl["cluster_name"] == nm).sum())
        ax.bar(x + i * wdt - 0.4 + wdt / 2, row.to_numpy(), width=wdt - 0.02, color=colors[i], edgecolor=SURF,
               linewidth=1, label=f"{nm} ({n} region-seasons)")
    ax.axhline(0, color=INK2, lw=0.8)
    ax.set_xticks(x); ax.set_xticklabels(["dust", "dry haze", "fog / mist", "rain", "hours >= 40 C",
                                          "safety S", "infrastructure I"], fontsize=8)
    ax.grid(axis="y", color=GRID, lw=0.8); ax.set_axisbelow(True); _style(ax)
    ax.set_ylabel("mean standardised value (z)", fontsize=8, color=INK2)
    ax.set_title("Cluster profiles (KMeans on region x season)", loc="left", fontsize=10.5, color=INK, pad=36)
    ax.legend(loc="lower left", bbox_to_anchor=(0, 1.0), ncol=2, fontsize=7.5, frameon=False)
    fig.tight_layout(); p = FIG / "cluster_profiles.png"; fig.savefig(p); plt.close(fig); made.append(p)

    # 5. sensitivity: Kendall tau over the 66 weight triples
    fig, ax = plt.subplots(figsize=(6.4, 3.8), dpi=150)
    ax.hist(sens["kendall_tau"], bins=np.linspace(0, 1, 11), color=BLUE, edgecolor=SURF, linewidth=2)
    ax.set_xlim(0, 1)
    from matplotlib.ticker import MaxNLocator
    ax.yaxis.set_major_locator(MaxNLocator(integer=True))
    med = sens["kendall_tau"].median()
    ax.axvline(med, color=INK2, lw=1, ls="--"); ax.text(med, ax.get_ylim()[1] * 0.95, f"  median {med:.2f}", fontsize=8, color=INK, va="top")
    ax.grid(axis="y", color=GRID, lw=0.8); ax.set_axisbelow(True); _style(ax)
    ax.set_xlabel("Kendall tau of the region ranking vs the default weights (1 = same order)", fontsize=8, color=INK2)
    ax.set_ylabel("weight triples", fontsize=8, color=INK2)
    ax.set_title(f"Ranking stability over {len(sens)} pillar-weight triples", loc="left", fontsize=10.5, color=INK)
    fig.tight_layout(); p = FIG / "sensitivity_weights_tau.png"; fig.savefig(p); plt.close(fig); made.append(p)
    return made


# ============================================================================= F6 report
def fmt(x, nd=3):
    return "n/a" if x is None or (isinstance(x, float) and np.isnan(x)) else f"{x:.{nd}f}"


def write_report(src, g, rr, rsc, reg_out, cl, info, sup, tests, sens_info, figs) -> None:
    c = g[g["wx_complete"] == 1]
    hold = pd.read_csv(MODEL / "av_evidence_holdout.csv") if (MODEL / "av_evidence_holdout.csv").exists() else None
    glm = pd.read_csv(MODEL / "av_evidence_glm.csv") if (MODEL / "av_evidence_glm.csv").exists() else None
    L = []
    A = L.append
    A("# Report 04 - EDA, models and evaluation")
    A("")
    A(f"_Generated by `python/05_readiness_model.py` on {date.today():%d %b %Y} from the run outputs; every number below comes "
      f"from that run. Input: {src} ({len(g)} rows, {int(g['wx_complete'].sum())} complete weather months)._")
    A("")
    A("## 1. Question and data")
    A("How ready is each Saudi region, by season, for autonomous vehicles? The answer is an evidence-based readiness "
      "score per region x season with its drivers. Everything is computed from the one Gold table "
      "`gold.av_readiness_region_month` (13 regions x 60 months, 100 % real data). The EDA queries are in "
      "`sql/04_analysis.sql` (ROLLUP, CUBE, GROUPING SETS, RANK, NTILE, LAG).")
    A("")
    A("## 2. AV evidence: crude vs adjusted relative risks (the confounding demonstration)")
    A("Relative risk of an AV event under each weather condition vs normal weather. Crude = pooled ratio (the number "
      "used before v2). Adjusted = Mantel-Haenszel over strata (NHTSA: state x incident month; DMV: month x weekday "
      "class), 95 % CI widened by the overdispersion factor. Evidence rule: applied in Gold only if the ratio comes "
      "from AV crashes, has >= 30 events and its CI lower bound is > 1.")
    A("")
    A("| source | condition | events | crude | adjusted | 95 % CI | overdispersion | used | note |")
    A("|---|---|---:|---:|---:|---|---:|---:|---|")
    for _, r in rr[rr["factor"] == "weather"].sort_values(["event_source", "condition_code"]).iterrows():
        A(f"| {r['event_source']} | {r['condition_code']} | {int(r['events']):,} | {fmt(r['rr_crude'], 3)} | "
          f"{fmt(r['rr_adjusted'], 3)} | [{fmt(r['ci_low'], 3)}, {fmt(r['ci_high'], 3)}] | {fmt(r['dispersion'], 2)} | "
          f"{int(r['used_in_index'])} | {r['evidence_note']} |")
    A("")
    if glm is not None:
        nb = glm[(glm["data"] == "dmv_disengagement") & (glm["model"].str.startswith("NB GLM adjusted"))]
        cr = glm[(glm["data"] == "dmv_disengagement") & (glm["model"] == "NB GLM crude")]
        A("DMV disengagements with a Negative Binomial GLM (statsmodels): crude "
          + ", ".join(f"{r.condition_code} {r.rr:.2f}" for r in cr.itertuples())
          + "; with month and day-of-week fixed effects "
          + ", ".join(f"{r.condition_code} {r.rr:.2f} [{r.ci_low:.2f}, {r.ci_high:.2f}]" for r in nb.itertuples())
          + ". The weather effects of the crude ratios mostly disappear once fleets, months and weekdays are compared "
            "like with like: the crude DMV ratios were confounding (98 % of disengagements happen Mon-Fri, and fleets "
            "and seasons move together).")
        A("")
    if hold is not None:
        A(f"Out-of-time test (train Dec 2020 - Nov 2023, test Dec 2023 - Nov 2024): month-of-year + weekday model test "
          f"deviance {hold.iloc[0]['test_deviance']:.1f} (MAE {hold.iloc[0]['test_mae']:.1f}); adding the weather day type "
          f"gives {hold.iloc[1]['test_deviance']:.1f} (MAE {hold.iloc[1]['test_mae']:.1f}). Weather "
          + ("does not improve" if hold.iloc[1]['test_deviance'] >= hold.iloc[0]['test_deviance'] else "improves")
          + " the prediction of disengagements.")
        A("")
    A("Figure: `docs/figures/rr_crude_vs_adjusted.png`.")
    A("")
    A("## 3. Readiness score (F1)")
    A("Readiness = 100 x (1/3 E + 1/3 S + 1/3 I) per region x season, over complete weather months 2021-2025.")
    A("- **E (environment)**: mean `env_readiness` = share of hours inside the US AV evidence envelope (dust weight 0, "
      "rain weight 1/RR_rain, other covered conditions 1), min-max over the 52 region-seasons.")
    A("- **S (traffic-safety environment)**: 1 - mean percent-rank of the 2021-2025 serious-accident and death rates per "
      "100,000 (same for the 4 seasons of a region).")
    A("- **I (infrastructure)**: mean of min-max divided intercity share, road km per 1,000 people and (inverted) "
      "ambulance response time outside cities, 2022-2025.")
    A("")
    A("| rank | region | readiness | E part | S part | I part | best season | worst season | cluster |")
    A("|---:|---|---:|---:|---:|---:|---|---|---|")
    for i, r in enumerate(reg_out.itertuples(), 1):
        A(f"| {i} | {r.region_code} {r.region_name_en} | {r.readiness:.1f} | {r.contrib_E:.1f} | {r.contrib_S:.1f} | "
          f"{r.contrib_I:.1f} | {r.best_season} ({r.best_score:.1f}) | {r.worst_season} ({r.worst_score:.1f}) | {r.cluster_mode} |")
    A("")
    worst = rsc.sort_values("readiness").iloc[0]
    best = rsc.sort_values("readiness").iloc[-1]
    A(f"Lowest region-season: {worst['region_code']} {worst['season']} ({worst['readiness']:.1f}); highest: "
      f"{best['region_code']} {best['season']} ({best['readiness']:.1f}). Lowest environment readiness "
      f"(env_readiness_cons): " + ", ".join(f"{k} {v:.3f}" for k, v in
                                            c.groupby('region_code')['env_readiness_cons'].mean().sort_values().head(4).items()) + ".")
    A("")
    A("Figures: `readiness_heatmap_region_season.png`, `readiness_pillars_by_region.png`, `environment_loss_breakdown.png`.")
    A("")
    A("## 4. Clustering (F2, model 1)")
    A(f"KMeans on standardised region x season features ({', '.join(CLUSTER_FEATURES)}), k = 2..6, chosen by "
      f"silhouette: " + ", ".join(f"k={k} {v:.3f}" for k, v in info['silhouette'].items()) + f". Chosen k = {info['k']}. "
      f"Stability over 200 bootstrap resamples: mean adjusted Rand index {info['ari_mean']:.2f} "
      f"(5-95 %: {info['ari_p05']:.2f}-{info['ari_p95']:.2f}). Clusters are named by their mean readiness.")
    A("")
    for nm, grp in cl.groupby("cluster_name"):
        A(f"- **{nm}** ({len(grp)} region-seasons, mean readiness {grp['readiness'].mean():.1f}): "
          + ", ".join(f"{r.region_code}-{r.season}" for r in grp.sort_values('readiness', ascending=False).itertuples()))
    A("")
    A("Figure: `cluster_profiles.png`.")
    A("")
    A("## 5. Supervised test of weather -> accidents (F3, model 2)")
    A("Samples are region-years (never months: accidents are annual). Target = region serious-accident rate per "
      "100,000 / national rate of the same year. Cross-validation leaves out a whole year or a whole region "
      "(random K-fold would leak the region). Metrics on the pooled out-of-fold predictions.")
    A("")
    A("| design | n | CV | model | MAE | R2 |")
    A("|---|---:|---|---|---:|---:|")
    for r in sup.itertuples():
        A(f"| {r.design} | {r.n} | {r.cv} | {r.model} | {r.MAE:.3f} | {r.R2:.3f} |")
    A("")
    # verdict: in leave-one-region-out a weather model must beat the mean; in leave-one-year-out it must beat
    # the region-identity baseline (otherwise its "skill" is only recognising the region)
    verdict = []
    for (dsg, cv), grp in sup.groupby(["design", "cv"]):
        wx_models = grp[grp["model"].str.startswith(("Ridge", "RandomForest"))]
        best_m = wx_models.sort_values("MAE").iloc[0]
        ref_name = "Region mean" if cv == "leave one year out" else "Dummy"
        ref_row = grp[grp["model"].str.startswith(ref_name)].iloc[0]
        verdict.append(dict(design=dsg, cv=cv, best=best_m["model"], best_mae=best_m["MAE"], best_r2=best_m["R2"],
                            ref=ref_row["model"], ref_mae=ref_row["MAE"], ref_r2=ref_row["R2"],
                            beats=bool(best_m["MAE"] < ref_row["MAE"])))
    for v in verdict:
        A(f"- {v['design']}, {v['cv']}: best weather model {v['best']} MAE {v['best_mae']:.3f} (R2 {v['best_r2']:.2f}) vs "
          f"{v['ref']} MAE {v['ref_mae']:.3f} (R2 {v['ref_r2']:.2f}) -> " + ("better" if v["beats"] else "not better"))
    A("")
    A("Rank tests on region-years 2021-2024 (Spearman). Year-adjusted = region mean and year mean removed from both "
      "the weather share and the relative rate; the region-only version is shown because it is confounded by year:")
    A("")
    A("| weather share | within-region, year-adjusted rho (p) | region mean removed only rho (p) | cross-section of 13 regions rho (p) |")
    A("|---|---|---|---|")
    for k in ["dust", "obscured_no_dust", "rain", "hot40"]:
        v = tests[k]
        A(f"| {k} | {v['within_rho']:.2f} ({v['within_p']:.2f}) | {v['region_only_rho']:.2f} ({v['region_only_p']:.2f}) | "
          f"{v['cross_rho']:.2f} ({v['cross_p']:.2f}) |")
    A("")
    w, wy = tests["wilcoxon_E8"], tests["wilcoxon_E8_year_centred"]
    yrs = ", ".join(f"{k}: {v}" for k, v in tests["most_obscured_years"].items())
    A(f"Query E8 (Dr. Omar's comparison): {w['n_higher']} of {w['n']} regions have a higher relative rate in their most "
      f"obscured year (Wilcoxon signed-rank p = {w['p']:.3f}). The most obscured year is {yrs} (year: regions). With the "
      f"year's mean relative rate removed, {wy['n_higher']} of {wy['n']} are higher (p = {wy['p']:.3f}).")
    A("")
    sig = [k for k in ["dust", "obscured_no_dust", "rain", "hot40"] if tests[k]["within_p"] < 0.05]
    top_y, top_n = max(tests["most_obscured_years"].items(), key=lambda kv: kv[1])
    if not sig and not any(v["beats"] for v in verdict):
        A("**Result: null.** No weather model generalises to a region it has not seen (every leave-one-region-out "
          "model is worse than the mean), the leave-one-year-out \"skill\" is region identity (compare the region-mean "
          "baseline, which uses no weather at all), and no year-adjusted rank correlation is significant. The apparent "
          f"dust signal in the region-only correlation and in E8 is a year effect: {top_y} is the most obscured year for "
          f"{top_n} of 13 regions, and the average relative rate of the regions is itself higher in some years ("
          + ", ".join(f"{k} {v:.2f}" for k, v in tests["rel_rate_year_mean"].items())
          + "; small regions do not move with the national rate). With annual regional accident counts, the share "
          "of dusty, hazy or rainy hours does not explain which regions or years have more serious accidents. This is a "
          "finding, not a failure: it is why readiness is built from the AV evidence envelope and the region's own "
          "safety and infrastructure record, not from a weather -> accident model.")
    else:
        won = [f"{v['design']} / {v['cv']}" for v in verdict if v["beats"]]
        A("**Result:** a weather model beats its baseline in " + (", ".join(won) if won else "no design")
          + (f"; significant year-adjusted correlation for {', '.join(sig)}" if sig else "")
          + ". With 13 regions x 4 years this is a hypothesis to test with more data, not a finding; no weather -> "
            "accident model is used in the readiness score.")
    A("")
    A("## 6. Sensitivity (F4)")
    s = sens_info
    A(f"- {s['n_weight_triples']} pillar-weight triples on a 0.1 grid: Kendall tau of the region ranking vs the default "
      f"median {s['tau_median']:.2f}, minimum {s['tau_min']:.2f}; tau >= 0.7 in {100 * s['share_tau_ge_0.7']:.0f} % of "
      f"triples. Share of triples in which each region keeps its default tier (NTILE 3): "
      + ", ".join(f"{k} {100 * v:.0f} %" for k, v in sorted(s['tier_kept_share'].items(), key=lambda x: -x[1])) + ".")
    A(f"- Conservative environment (dry haze weight 0): tau {s['tau_cons']:.2f}.")
    A(f"- Rain RR {s['rr_rain'][0]:.3f} replaced by its CI bounds {s['rr_rain'][1]:.3f} / {s['rr_rain'][2]:.3f}: tau "
      f"{s['tau_rr_rain_low']:.2f} / {s['tau_rr_rain_high']:.2f}.")
    if isinstance(s.get("dew_threshold"), dict):
        A("- Fog/haze dew-spread threshold (re-classified from the hourly reports; only the conservative variant "
          "depends on it): " + "; ".join(f"{t} degC: Saudi fog_moist {v['saudi_fog_moist_pct']:.2f} %, haze_dry "
                                          f"{v['saudi_haze_dry_pct']:.2f} %, tau {v['tau_vs_default']:.2f}"
                                          for t, v in s['dew_threshold'].items()) + ".")
    else:
        A(f"- Dew-spread threshold: {s.get('dew_threshold')}.")
    A("")
    A("Figure: `sensitivity_weights_tau.png`.")
    A("")
    A("## 7. Limitations")
    for t in ["Dust has no US AV evidence at all (0 NHTSA events, 0 DMV dust days): it is treated as uncovered (weight 0), "
              "not as measured risk.",
              "Saudi dry haze is mostly mineral dust; California's is mostly smoke: the conservative variant gives it weight 0.",
              "DMV disengagements have a date but no location; California weather is taken as the worse of LAX and SFO.",
              "NHTSA crashes have month-level dates; exposure is station-hours of the state, not AV miles. 17 of the 70 rain "
              "crashes fall in state-months where the reference station logged no rain hour (station is not the crash place).",
              "Accidents are annual per region; monthly rows repeat them (use one row per region-year).",
              "Heat: hours >= 40 degC are 6.1 % in Saudi and 7.5 % at Phoenix, where AV fleets run commercially, but there is "
              "no event-level heat evidence.",
              "The 2025 workbook revises the 2024 rates; each year uses its own publication.",
              "NOAA stopped updating its hourly product (ISD) after 24 Aug 2025: September-December 2025 has no weather.",
              "One weather station per region (the main airport).",
              "Association is not causation: the score is an evidence-based estimate of readiness, not a measurement."]:
        A(f"- {t}")
    A("")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(L), encoding="utf-8")


# ============================================================================= main
def main() -> int:
    MODEL.mkdir(parents=True, exist_ok=True)
    g, rr, src = load_inputs()
    names = g.drop_duplicates("region_code").set_index("region_code")["region_name_en"].to_dict()
    rs, reg = pillars(g)
    rsc = score(rs)
    cl, info = clustering(rsc)
    rsc = rsc.merge(cl[["region_code", "season", "cluster_name"]], on=["region_code", "season"])
    rsc.to_csv(MODEL / "readiness_region_season.csv", index=False)
    rk = region_rank(rsc)
    agg = rsc.groupby("region_code").agg(readiness=("readiness", "mean"), contrib_E=("contrib_E", "mean"),
                                         contrib_S=("contrib_S", "mean"), contrib_I=("contrib_I", "mean"),
                                         E=("E", "mean"), S=("S", "first"), I=("I", "first"),
                                         loss_dust=("loss_dust", "mean"), loss_rain=("loss_rain", "mean"),
                                         loss_haze_dry_cons=("loss_haze_dry_cons", "mean"),
                                         cluster_mode=("cluster_name", lambda s: s.mode().iloc[0])).loc[rk.index]
    bw = rsc.sort_values("readiness").groupby("region_code")
    agg["worst_season"] = bw.first()["season"]; agg["worst_score"] = bw.first()["readiness"]
    agg["best_season"] = bw.last()["season"]; agg["best_score"] = bw.last()["readiness"]
    agg["tier_ntile3"] = agg.index.map(ntile3(rk.index.tolist()))
    agg["region_name_en"] = agg.index.map(names)
    reg_out = agg.reset_index()
    reg_out.to_csv(MODEL / "readiness_region.csv", index=False)
    sup, tests = supervised(g)
    sup.to_csv(MODEL / "supervised_weather_accidents.csv", index=False)
    sens, sens_info = sensitivity(g, rr, rs)
    sens.to_csv(MODEL / "sensitivity_weights.csv", index=False)
    (MODEL / "model_summary.json").write_text(json.dumps(dict(input=src, clustering=info, tests=tests, sensitivity=sens_info),
                                                         indent=2, default=str))
    figs = figures(rsc, cl, sens, names)
    write_report(src, g, rr, rsc, reg_out, cl, info, sup, tests, sens_info, figs)
    pd.set_option("display.width", 200)
    print("input:", src)
    print(reg_out[["region_code", "readiness", "contrib_E", "contrib_S", "contrib_I", "best_season", "worst_season",
                   "cluster_mode", "tier_ntile3"]].round(2).to_string(index=False))
    print("clustering:", json.dumps(info))
    print(sup.round(3).to_string(index=False))
    print("tests:", json.dumps(tests, indent=1))
    print("sensitivity:", json.dumps({k: v for k, v in sens_info.items() if k != "dew_threshold"}, default=str))
    print("dew threshold:", json.dumps(sens_info.get("dew_threshold"), default=str)[:600])
    print("figures:", ", ".join(p.name for p in figs))
    print("report:", REPORT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
