#!/usr/bin/env python3
"""Render central MODEL_REPORT.md and one checked figure per MODEL_PUBLISH set."""

from __future__ import annotations

import csv
import math
import warnings
from collections import defaultdict
from pathlib import Path
from typing import Iterable

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LogNorm
from PIL import Image, ImageDraw


MODEL_ROOT = Path(__file__).resolve().parents[2]
PUBLISH_ROOT = MODEL_ROOT / "publish"
GOLDEN_DIR = PUBLISH_ROOT / "golden"
VISUAL_DIR = PUBLISH_ROOT / "visual_check"
ANALYTICAL_DIR = MODEL_ROOT / "analytical" / "data"
TLM_DIR = MODEL_ROOT / "tlm" / "data"
RTL_DIR = MODEL_ROOT / "rtl_sim" / "data"

LOSS_CMAP = "YlOrRd"
GAIN_CMAP = "PuBuGn"


SETS = [
    ("set01_loss_surface_delivered", "Loss surface at delivered slice", r"$P_{loss}(B,\rho_{lane})$"),
    ("set02_loss_surface_family", "OPQ loss-surface family", r"$P_{loss}(B,\rho_{lane};N,E)$"),
    ("set03_opq_vs_time_merger_gain", "OPQ vs time-merger gain heatmap", r"$G=P_{loss,TM}/P_{loss,OPQ}$"),
    ("set04_feature_scaling_nlane", "Feature scaling vs N_LANE", r"$P_{loss}(N_{LANE})$"),
    ("set05_feature_scaling_egress", "Feature scaling vs egress width", r"$P_{loss}(E)$"),
    ("set06_loss_vs_ready_duty", "Loss vs ready duty", r"$q=H/(H+L)$"),
    ("set07_loss_vs_burstiness", "Loss vs burstiness", r"$B=(CV-1)/(CV+1)$"),
    ("set08_loss_vs_rate", "Loss vs rho_lane", r"$\rho_{eff}=(N\rho/R)\sqrt{(1+SCV)/2}$"),
    ("set09_feature_scaling_gain", "Feature-scaling gain", r"$G\propto N_{LANE}E$"),
    ("set10_legacy_loss_surface", "Legacy time-merger loss surface", r"$P_{loss,TM}(B,\rho)$"),
    ("set11_opq_vs_legacy_side_by_side", "OPQ vs legacy side by side", r"$G=P_{loss,TM}/P_{loss,OPQ}$"),
    ("set12_latency_cdf", "Latency CDF", r"$F_L(\ell)=P(L\le\ell)$"),
    ("set13_latency_pdf", "Latency PDF", r"$p_L(\ell)=dF_L/d\ell$"),
    ("set14_latency_quantiles", "Latency quantile envelope", r"$Q_p=\inf\{\ell:F_L(\ell)\ge p\}$"),
    ("set15_latency_contour", "Latency response contour", r"$p(L\mid\rho_{lane})$"),
    ("set16_ingress_reorder", "Ingress reordering heatmap", r"$\Delta_{ing}=t_{ing}-t_{frame}$"),
    ("set17_egress_reorder", "Egress reordering heatmap", r"$\Delta_{eg}=t_{eg}-t_{frame}$"),
    ("set18_rbo_distribution", "RBO distribution", r"$RBO=|\Delta-\mathrm{median}(\Delta)|$"),
    ("set19_rto_distribution", "RTO distribution", r"$RTO=\Delta_{eg}$"),
    ("set20_per_lane_fairness", "Per-lane drop fairness", r"$P_{drop,lane}=D_l/O_l$"),
    ("set21_page_residency", "Page residency proxy", r"$K_{proxy}\sim L_{proxy}/16$"),
    ("set22_drop_vs_nshd_rho", "Drop vs N_SHD and rho", r"$P_K=\frac{(1-\rho)\rho^K}{1-\rho^{K+1}}$"),
    ("set23_drop_vs_nshd_burstiness", "Drop vs N_SHD and burstiness", r"$SCV=(1+B)/(1-B)$"),
    ("set24_burstiness_memory", "Burstiness-memory map", r"$M=0$ for periodic finite RTL sweep"),
    ("set25_drr_live", "DRR live-statistics convergence", r"$A_l(t)\rightarrow Q_l$"),
    ("set26_closure_matrix", "A/T/S closure matrix", r"$\Delta_{AT},\Delta_{TS},\Delta_{AS}$"),
    ("set27_promotion_ledger", "Promotion ledger", r"$A\rightarrow T\rightarrow S\rightarrow B$"),
    ("set28_closure_cover", "Chief-architect closure cover", r"$P_{loss},G,\Delta$"),
]


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def f(row: dict[str, str], key: str, default: float = 0.0) -> float:
    value = row.get(key, "")
    if value == "":
        return default
    return float(value)


def i(row: dict[str, str], key: str, default: int = 0) -> int:
    value = row.get(key, "")
    if value == "":
        return default
    return int(float(value))


def close(a: float, b: float, tol: float = 1.0e-9) -> bool:
    return abs(a - b) <= tol


def filter_rows(
    rows: Iterable[dict[str, str]],
    n_lane: int | None = None,
    egress: int | None = None,
    ready: float | None = None,
    burstiness: float | None = None,
    rho: float | None = None,
    impl: str | None = "opq",
) -> list[dict[str, str]]:
    out = []
    for row in rows:
        if impl is not None and row.get("implementation", "opq") != impl:
            continue
        if n_lane is not None and i(row, "n_lane") != n_lane:
            continue
        if egress is not None and i(row, "egress_symbols_per_beat") != egress:
            continue
        if ready is not None and not close(f(row, "ready_duty"), ready, 1.0e-6):
            continue
        if burstiness is not None and not close(f(row, "burstiness"), burstiness, 2.5e-2):
            continue
        if rho is not None and not close(f(row, "rho_lane"), rho, 2.5e-3):
            continue
        out.append(row)
    return out


def pivot(rows: list[dict[str, str]], xkey: str, ykey: str, zkey: str) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    xs = sorted({f(r, xkey) for r in rows})
    ys = sorted({f(r, ykey) for r in rows})
    xi = {v: idx for idx, v in enumerate(xs)}
    yi = {v: idx for idx, v in enumerate(ys)}
    z = np.full((len(ys), len(xs)), np.nan)
    for row in rows:
        z[yi[f(row, ykey)], xi[f(row, xkey)]] = max(f(row, zkey), 1.0e-12)
    return np.array(xs), np.array(ys), z


def line_points(rows: list[dict[str, str]], xkey: str, zkey: str = "loss_probability") -> tuple[np.ndarray, np.ndarray]:
    pts = sorted((f(row, xkey), max(f(row, zkey), 1.0e-12)) for row in rows)
    if not pts:
        return np.array([]), np.array([])
    x, y = zip(*pts)
    return np.array(x), np.array(y)


def finite_queue_loss(rho_eff: np.ndarray, k: np.ndarray | float) -> np.ndarray:
    rho = np.clip(rho_eff, 1.0e-12, 0.999999)
    k_arr = np.asarray(k, dtype=float)
    num = (1.0 - rho) * np.power(rho, k_arr)
    den = 1.0 - np.power(rho, k_arr + 1.0)
    return np.clip(num / den, 1.0e-12, 1.0)


def scv_from_b(b: np.ndarray) -> np.ndarray:
    return np.clip((1.0 + b) / np.maximum(1.0 - b, 1.0e-6), 1.0e-9, 1.0e6)


def model_loss(n_lane: float, egress: float, n_shd: np.ndarray | float, burstiness: np.ndarray, rho_lane: np.ndarray, ready: float = 1.0) -> np.ndarray:
    scv = scv_from_b(burstiness)
    variability = np.sqrt((1.0 + scv) / 2.0)
    service = np.maximum(egress * ready, 1.0e-9)
    rho_eff = np.clip((n_lane * rho_lane / service) * variability, 1.0e-12, 0.999999)
    return finite_queue_loss(rho_eff, n_shd)


def generated_loss_rows(
    n_lane: int,
    egress: int,
    ready: float = 1.0,
    b_values: np.ndarray | None = None,
    rho_values: np.ndarray | None = None,
    n_shd: int = 128,
) -> list[dict[str, float]]:
    b_values = np.linspace(-0.25, 0.95, 61) if b_values is None else b_values
    rho_values = np.linspace(0.005, 0.30, 61) if rho_values is None else rho_values
    rows: list[dict[str, float]] = []
    for b in b_values:
        for rho in rho_values:
            rows.append(
                {
                    "implementation": "opq",
                    "n_lane": float(n_lane),
                    "egress_symbols_per_beat": float(egress),
                    "ready_duty": float(ready),
                    "burstiness": float(b),
                    "rho_lane": float(rho),
                    "loss_probability": float(model_loss(n_lane, egress, n_shd, np.array(b), np.array(rho), ready)),
                }
            )
    return rows


def add_loss_contour(
    ax: plt.Axes,
    rows: list[dict[str, str]],
    title: str,
    show_cbar: bool = True,
    tlm_rows: list[dict[str, str]] | None = None,
    rtl_rows: list[dict[str, str]] | None = None,
    label_contours: bool = True,
) -> None:
    xs, ys, z = pivot(rows, "burstiness", "rho_lane", "loss_probability")
    if len(xs) < 2 or len(ys) < 2:
        ax.text(0.5, 0.5, "insufficient grid", ha="center", va="center", transform=ax.transAxes)
        ax.set_title(title)
        return
    mesh = ax.pcolormesh(xs, ys, z, cmap=LOSS_CMAP, norm=LogNorm(vmin=1.0e-12, vmax=max(float(np.nanmax(z)), 1.0e-4)), shading="auto")
    levels = [1.0e-6, 1.0e-3, 1.0e-2]
    try:
        cs = ax.contour(xs, ys, z, levels=levels, colors=["#222222"], linewidths=0.7)
        if label_contours:
            ax.clabel(cs, inline=True, fontsize=6, fmt=lambda v: f"{v:.0e}")
    except ValueError:
        pass
    if tlm_rows:
        tx, ty, tz = pivot(tlm_rows, "burstiness", "rho_lane", "loss_probability")
        try:
            ax.contour(tx, ty, tz, levels=[1.0e-6, 1.0e-3], colors=["#275dad"], linestyles="--", linewidths=0.8)
        except ValueError:
            pass
    if rtl_rows:
        ax.scatter(
            [f(r, "burstiness") for r in rtl_rows],
            [f(r, "rho_lane") for r in rtl_rows],
            marker="o",
            s=22,
            facecolor="white",
            edgecolor="black",
            linewidth=0.8,
            label="RTL SIM",
            zorder=5,
        )
    ax.set_title(title, fontsize=9)
    ax.set_xlabel("B")
    ax.set_ylabel("rho_lane")
    ax.tick_params(labelsize=7)
    if show_cbar:
        cb = plt.colorbar(mesh, ax=ax, shrink=1.0)
        cb.set_label("loss", fontsize=8)
        cb.ax.tick_params(labelsize=7)


def save_figure(fig: plt.Figure, slug: str, title: str, equation: str) -> Path:
    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    png = GOLDEN_DIR / f"{slug}.png"
    svg = GOLDEN_DIR / f"{slug}.svg"
    fig.savefig(png, dpi=180, bbox_inches="tight")
    fig.savefig(svg, bbox_inches="tight")
    plt.close(fig)
    (GOLDEN_DIR / f"{slug}.rules.md").write_text(
        "\n".join(
            [
                f"# {title}",
                "",
                f"- Equation: {equation}",
                "- Layout: generated with constrained layout and tight export.",
                "- Loss/risk palette: sequential yellow-to-dark-red, darker is worse.",
                "- Visual check: inspect `publish/visual_check/contact_sheet.png`; no intended title, legend, tick, or color-bar overlap.",
                "- Tier labels: analytical/TLM/RTL/board status are shown in legend, panel title, or caption.",
                "",
            ]
        )
    )
    return png


def plot_or_note(ax: plt.Axes, rows: list[dict[str, str]], message: str) -> bool:
    if rows:
        return False
    ax.text(0.5, 0.5, message, ha="center", va="center", transform=ax.transAxes, fontsize=9)
    ax.set_xticks([])
    ax.set_yticks([])
    return True


def load_all() -> dict[str, list[dict[str, str]]]:
    return {
        "a_full": read_csv(ANALYTICAL_DIR / "queueing_model" / "opq_full_feature_loss_surface_grid.csv"),
        "a_ratio": read_csv(ANALYTICAL_DIR / "queueing_model" / "opq_vs_time_merger_ready_burst_ratio_grid.csv"),
        "a_scale": read_csv(ANALYTICAL_DIR / "queueing_model" / "opq_vs_time_merger_feature_scaling_grid.csv"),
        "legacy": read_csv(ANALYTICAL_DIR / "legacy" / "loss_surface_grid.csv"),
        "tlm_full": read_csv(TLM_DIR / "tlm_full_feature_loss_surface_grid.csv"),
        "tlm_ratio": read_csv(TLM_DIR / "tlm_opq_vs_time_merger_ready_burst_ratio_grid.csv"),
        "rtl_ls001": read_csv(RTL_DIR / "RTL-LS-001_loss_vs_ready_duty.csv"),
        "rtl_ls002": read_csv(RTL_DIR / "RTL-LS-002_loss_vs_rho.csv"),
        "rtl_ls005": read_csv(RTL_DIR / "RTL-LS-005_feature_scaling.csv"),
        "rtl_drop_lane": read_csv(RTL_DIR / "RTL-LS-005_per_lane_drops.csv"),
        "rtl_drr": read_csv(RTL_DIR / "RTL-LS-005_drr_live.csv"),
        "rtl_residency": read_csv(RTL_DIR / "RTL-LS-005_page_residency.csv"),
        "rtl_ingress": read_csv(RTL_DIR / "RTL-LS-002_ingress_reorder.csv"),
        "rtl_egress": read_csv(RTL_DIR / "RTL-LS-002_egress_reorder.csv"),
        "bm": read_csv(RTL_DIR / "burstiness_memory_observations.csv"),
        "closure": read_csv(PUBLISH_ROOT / "data" / "closure_matrix.csv"),
    }


def render_figures(data: dict[str, list[dict[str, str]]]) -> list[tuple[int, str, str, str, Path]]:
    outputs: list[tuple[int, str, str, str, Path]] = []

    def record(idx: int, fig: plt.Figure) -> None:
        slug, title, equation = SETS[idx - 1]
        path = save_figure(fig, slug, title, equation)
        outputs.append((idx, slug, title, equation, path))

    a = data["a_full"]
    t = data["tlm_full"]
    r2 = data["rtl_ls002"]
    r1 = data["rtl_ls001"]
    r5 = data["rtl_ls005"]

    # Set 1
    fig, ax = plt.subplots(figsize=(7.2, 4.6), constrained_layout=True)
    add_loss_contour(
        ax,
        filter_rows(a, n_lane=4, egress=1, ready=1.0),
        "A filled, T dashed, S markers: N=4 E=1 ready=1",
        tlm_rows=filter_rows(t, n_lane=4, egress=1, ready=1.0),
        rtl_rows=r2,
    )
    ax.legend(loc="lower right", fontsize=7)
    record(1, fig)

    # Set 2
    fig, axes = plt.subplots(3, 4, figsize=(12.8, 7.6), constrained_layout=True, sharex=True, sharey=True)
    for ridx, n_lane in enumerate([4, 8, 16]):
        for cidx, egress in enumerate([1, 2, 4, 8]):
            ax = axes[ridx, cidx]
            add_loss_contour(ax, generated_loss_rows(n_lane, egress, ready=1.0), f"N={n_lane}, E={egress}", show_cbar=False, label_contours=False)
    fig.colorbar(plt.cm.ScalarMappable(norm=LogNorm(vmin=1e-12, vmax=1e-2), cmap=LOSS_CMAP), ax=axes, shrink=0.95, label="loss")
    record(2, fig)

    # Set 3
    fig, axes = plt.subplots(3, 4, figsize=(12.8, 7.6), constrained_layout=True, sharex=True, sharey=True)
    ratio = data["tlm_ratio"] or data["a_ratio"]
    for ridx, n_lane in enumerate([4, 8, 16]):
        for cidx, egress in enumerate([1, 2, 4, 8]):
            ax = axes[ridx, cidx]
            rows = [row for row in ratio if i(row, "n_lane") == n_lane and i(row, "egress_symbols_per_beat") == egress and close(f(row, "rho_lane"), 0.0075, 1e-6)]
            xs, ys, z = pivot(rows, "burstiness", "ready_duty", "loss_ratio_clipped")
            if len(xs) > 1 and len(ys) > 1:
                ax.pcolormesh(xs, ys, np.maximum(z, 1.0), shading="auto", cmap=GAIN_CMAP, norm=LogNorm(vmin=1, vmax=max(float(np.nanmax(z)), 10.0)))
                try:
                    ax.contour(xs, ys, z, levels=[2, 10, 100], colors="black", linewidths=0.6)
                except ValueError:
                    pass
            ax.set_title(f"N={n_lane}, E={egress}", fontsize=9)
            ax.set_xlabel("B")
            ax.set_ylabel("ready")
            ax.tick_params(labelsize=7)
    fig.colorbar(plt.cm.ScalarMappable(norm=LogNorm(vmin=1, vmax=100), cmap=GAIN_CMAP), ax=axes, shrink=0.95, label="gain")
    record(3, fig)

    # Sets 4-9 line families.
    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    for egress in [1, 2, 4, 8]:
        xs = [4, 8, 16]
        ys = [float(model_loss(n_lane, egress, 128, np.array(0.0), np.array(0.15), 1.0)) for n_lane in xs]
        ax.plot(xs, ys, marker="o", label=f"A E={egress}")
    for row in r5:
        ax.scatter(i(row, "n_lane"), max(f(row, "loss_probability"), 1e-12), marker="x", color="black", zorder=5)
    ax.set_yscale("log")
    ax.set_xlabel("N_LANE")
    ax.set_ylabel("loss")
    ax.set_title("Loss vs lane count, B=0, rho=0.15")
    ax.legend(ncol=2, fontsize=7)
    record(4, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    for n_lane in [4, 8, 16]:
        xs = [1, 2, 4, 8]
        ys = [float(model_loss(n_lane, egress, 128, np.array(0.0), np.array(0.15), 1.0)) for egress in xs]
        ax.plot(xs, ys, marker="o", label=f"A N={n_lane}")
    for row in r5:
        ax.scatter(i(row, "egress_symbols_per_beat"), max(f(row, "loss_probability"), 1e-12), marker="x", color="black", zorder=5)
    ax.set_yscale("log")
    ax.set_xscale("log", base=2)
    ax.set_xlabel("E")
    ax.set_ylabel("loss")
    ax.set_title("Loss vs egress width, B=0, rho=0.15")
    ax.legend(fontsize=7)
    record(5, fig)

    fig, axes = plt.subplots(2, 2, figsize=(10.4, 6.8), constrained_layout=True, sharex=True, sharey=True)
    for ax, egress in zip(axes.flat, [1, 2, 4, 8]):
        for n_lane in [4, 8, 16]:
            x = np.linspace(0.45, 1.0, 80)
            y = model_loss(n_lane, egress, 128, np.zeros_like(x), np.full_like(x, 0.15), x)
            ax.plot(x, y, label=f"N={n_lane}")
        for row in r1:
            ax.scatter(f(row, "ready_duty"), max(f(row, "loss_probability"), 1e-12), marker="x", color="black")
        ax.set_title(f"E={egress}", fontsize=9)
        ax.set_yscale("log")
        ax.grid(True, alpha=0.25)
    axes[0, 0].legend(fontsize=7)
    fig.supxlabel("ready duty")
    fig.supylabel("loss")
    record(6, fig)

    fig, axes = plt.subplots(2, 2, figsize=(10.4, 6.8), constrained_layout=True, sharex=True, sharey=True)
    for ax, egress in zip(axes.flat, [1, 2, 4, 8]):
        for n_lane in [4, 8, 16]:
            x = np.linspace(-0.25, 0.95, 120)
            y = model_loss(n_lane, egress, 128, x, np.full_like(x, 0.15), 1.0)
            ax.plot(x, y, label=f"N={n_lane}")
        ax.set_title(f"E={egress}, rho=0.15", fontsize=9)
        ax.set_yscale("log")
        ax.grid(True, alpha=0.25)
    axes[0, 0].legend(fontsize=7)
    fig.supxlabel("B")
    fig.supylabel("loss")
    record(7, fig)

    fig, axes = plt.subplots(2, 2, figsize=(10.4, 6.8), constrained_layout=True, sharex=True, sharey=True)
    for ax, egress in zip(axes.flat, [1, 2, 4, 8]):
        for n_lane in [4, 8, 16]:
            x = np.linspace(0.005, 0.30, 120)
            y = model_loss(n_lane, egress, 128, np.zeros_like(x), x, 1.0)
            ax.plot(x, y, label=f"N={n_lane}")
        for row in r2:
            ax.scatter(f(row, "rho_lane"), max(f(row, "loss_probability"), 1e-12), marker="x", color="black")
        ax.set_title(f"E={egress}, B=0", fontsize=9)
        ax.set_yscale("log")
        ax.grid(True, alpha=0.25)
    axes[0, 0].legend(fontsize=7)
    fig.supxlabel("rho_lane")
    fig.supylabel("loss")
    record(8, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    scale_rows = data["a_scale"]
    xs = np.arange(len(scale_rows))
    gains = [max(f(row, "loss_ratio_clipped"), 1.0) for row in scale_rows]
    labels = [f"N{i(row,'n_lane')} E{i(row,'egress_symbols_per_beat')}" for row in scale_rows]
    ax.plot(xs, gains, marker="o", label="A gain")
    ax.plot(xs, np.maximum(1.0, (xs + 1) * max(gains) / max(len(xs), 1)), "--", label="linear guide")
    ax.set_yscale("log")
    ax.set_xticks(xs[:: max(1, len(xs) // 8)])
    ax.set_xticklabels(labels[:: max(1, len(xs) // 8)], rotation=25, ha="right")
    ax.set_ylabel("gain")
    ax.set_title("OPQ vs time-merger feature scaling")
    ax.legend(fontsize=8)
    record(9, fig)

    # Sets 10 and 11 legacy.
    fig, ax = plt.subplots(figsize=(7.2, 4.6), constrained_layout=True)
    legacy = data["legacy"]
    if not plot_or_note(ax, legacy, "legacy data missing"):
        xs = sorted({f(r, "burstiness_target") for r in legacy})
        ys = sorted({f(r, "rate_per_lane") for r in legacy})
        xi = {v: idx for idx, v in enumerate(xs)}
        yi = {v: idx for idx, v in enumerate(ys)}
        z = np.full((len(ys), len(xs)), np.nan)
        for row in legacy:
            z[yi[f(row, "rate_per_lane")], xi[f(row, "burstiness_target")]] = max(f(row, "loss_probability"), 1e-12)
        mesh = ax.pcolormesh(xs, ys, z, cmap=LOSS_CMAP, norm=LogNorm(vmin=1e-12, vmax=max(float(np.nanmax(z)), 1e-2)), shading="auto")
        fig.colorbar(mesh, ax=ax, label="legacy loss")
        ax.set_xlabel("B")
        ax.set_ylabel("legacy rate/lane")
        ax.set_title("Legacy time-merger loss surface")
    record(10, fig)

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), constrained_layout=True)
    add_loss_contour(axes[0], filter_rows(a, n_lane=4, egress=1, ready=1.0), "OPQ A, N=4 E=1", show_cbar=False)
    if not plot_or_note(axes[1], legacy, "legacy data missing"):
        xs = sorted({f(r, "burstiness_target") for r in legacy})
        ys = sorted({f(r, "rate_per_lane") for r in legacy})
        xi = {v: idx for idx, v in enumerate(xs)}
        yi = {v: idx for idx, v in enumerate(ys)}
        z = np.full((len(ys), len(xs)), np.nan)
        for row in legacy:
            z[yi[f(row, "rate_per_lane")], xi[f(row, "burstiness_target")]] = max(f(row, "loss_probability"), 1e-12)
        axes[1].pcolormesh(xs, ys, z, cmap=LOSS_CMAP, norm=LogNorm(vmin=1e-12, vmax=max(float(np.nanmax(z)), 1e-2)), shading="auto")
        axes[1].set_title("Legacy baseline")
        axes[1].set_xlabel("B")
        axes[1].set_ylabel("legacy rate/lane")
    record(11, fig)

    # Sets 12-19 from RTL residency/reordering.
    residency = data["rtl_residency"]
    by_rho: dict[float, list[dict[str, str]]] = defaultdict(list)
    for row in residency:
        by_rho[f(row, "rho_ppm") / 1_000_000.0].append(row)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    if not plot_or_note(ax, residency, "RTL residency samples missing"):
        for rho, rows in sorted(by_rho.items()):
            vals = np.sort([f(row, "proxy_cycles") for row in rows])
            cdf = np.arange(1, len(vals) + 1) / len(vals)
            ax.plot(vals, cdf, label=f"rho={rho:.3f}")
        ax.set_xlabel("proxy latency cycles")
        ax.set_ylabel("CDF")
        ax.set_title("RTL residency proxy CDF")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.25)
    record(12, fig)

    fig, axes = plt.subplots(2, 2, figsize=(10.4, 6.8), constrained_layout=True, sharex=True, sharey=True)
    for ax, (rho, rows) in zip(axes.flat, sorted(by_rho.items())):
        vals = [f(row, "proxy_cycles") for row in rows]
        ax.hist(vals, bins=12, density=True, color="#6baed6", edgecolor="white")
        ax.set_title(f"rho={rho:.3f}", fontsize=9)
        ax.grid(True, alpha=0.25)
    for ax in axes.flat[len(by_rho) :]:
        plot_or_note(ax, [], "no sample")
    fig.supxlabel("proxy latency cycles")
    fig.supylabel("PDF")
    record(13, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    if not plot_or_note(ax, residency, "RTL residency samples missing"):
        for q, label in [(0.50, "p50"), (0.90, "p90"), (0.99, "p99"), (1.00, "max")]:
            xs, ys = [], []
            for rho, rows in sorted(by_rho.items()):
                vals = np.array([f(row, "proxy_cycles") for row in rows])
                xs.append(rho)
                ys.append(float(np.quantile(vals, q)))
            ax.plot(xs, ys, marker="o", label=label)
        ax.set_xlabel("rho_lane")
        ax.set_ylabel("cycles")
        ax.set_title("Latency proxy quantiles")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.25)
    record(14, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.6), constrained_layout=True)
    if not plot_or_note(ax, residency, "RTL residency samples missing"):
        xs = np.array([f(row, "rho_ppm") / 1_000_000.0 for row in residency])
        ys = np.array([f(row, "proxy_cycles") for row in residency])
        h = ax.hist2d(xs, ys, bins=[max(3, len(by_rho)), 18], cmap=LOSS_CMAP)
        fig.colorbar(h[3], ax=ax, label="samples")
        ax.set_xlabel("rho_lane")
        ax.set_ylabel("proxy latency cycles")
        ax.set_title("Latency response sample density")
    record(15, fig)

    for set_idx, key, delta_key, title in [
        (16, "rtl_ingress", "delta_arrival_cycles", "Ingress delta samples"),
        (17, "rtl_egress", "delta_egress_cycles", "Egress delta samples"),
    ]:
        rows = data[key]
        fig, ax = plt.subplots(figsize=(7.2, 4.6), constrained_layout=True)
        if not plot_or_note(ax, rows, "RTL reorder samples missing"):
            xs = np.array([f(row, "rho_ppm") / 1_000_000.0 for row in rows])
            ys = np.array([f(row, delta_key) for row in rows])
            h = ax.hist2d(xs, ys, bins=[max(3, len(set(xs))), 18], cmap=LOSS_CMAP)
            fig.colorbar(h[3], ax=ax, label="samples")
            ax.set_xlabel("rho_lane")
            ax.set_ylabel("cycles")
            ax.set_title(title)
        record(set_idx, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    egress_rows = data["rtl_egress"]
    if not plot_or_note(ax, egress_rows, "RTL reorder samples missing"):
        vals = np.array([f(row, "delta_egress_cycles") for row in egress_rows])
        rbo = np.abs(vals - np.median(vals))
        ax.hist(rbo, bins=18, color="#74c476", edgecolor="white")
        ax.axvline(np.max(rbo), color="black", linestyle="--", label="observed max")
        ax.set_xlabel("RBO proxy cycles")
        ax.set_ylabel("count")
        ax.legend(fontsize=8)
        ax.set_title("RBO proxy distribution")
    record(18, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    if not plot_or_note(ax, egress_rows, "RTL reorder samples missing"):
        for rho, rows in sorted(by_rho.items()):
            vals = [f(row, "delta_egress_cycles") for row in rows]
            ax.hist(vals, bins=12, alpha=0.45, label=f"rho={rho:.3f}")
        ax.set_xlabel("RTO proxy cycles")
        ax.set_ylabel("count")
        ax.legend(fontsize=8)
        ax.set_title("RTO proxy distribution")
    record(19, fig)

    # Sets 20-25.
    fig, ax = plt.subplots(figsize=(8.4, 4.6), constrained_layout=True)
    drops = data["rtl_drop_lane"]
    if not plot_or_note(ax, drops, "RTL per-lane drop rows missing"):
        labels = [f"{row['run_tag']}:L{row['lane']}" for row in drops]
        vals = [max(f(row, "loss_probability"), 0.0) for row in drops]
        ax.bar(np.arange(len(vals)), vals, color="#9ecae1", edgecolor="#225ea8")
        ax.set_xticks(np.arange(len(vals)))
        ax.set_xticklabels(labels, rotation=60, ha="right", fontsize=7)
        ax.set_ylabel("drop/offered")
        ax.set_title("Per-lane drop fairness, RTL finite samples")
    record(20, fig)

    fig, axes = plt.subplots(1, 3, figsize=(11.0, 4.2), constrained_layout=True, sharey=True)
    by_n: dict[int, list[dict[str, str]]] = defaultdict(list)
    for row in residency:
        by_n[i(row, "n_lane")].append(row)
    for ax, n_lane in zip(axes, [4, 8, 16]):
        rows = by_n.get(n_lane, [])
        if rows:
            vals = [f(row, "proxy_cycles") / 16.0 for row in rows]
            ax.hist(vals, bins=14, color="#fdae6b", edgecolor="white")
            ax.axvline(128, color="black", linestyle="--", label="K=N_SHD")
        else:
            plot_or_note(ax, [], "pending RTL")
        ax.set_title(f"N={n_lane}", fontsize=9)
        ax.set_xlabel("page residency proxy")
    axes[0].set_ylabel("count")
    record(21, fig)

    n_grid = np.array([32, 64, 128, 256, 512])
    rho_grid = np.linspace(0.005, 0.30, 80)
    RHO, K = np.meshgrid(rho_grid, n_grid)
    Z = model_loss(4, 1, K, np.zeros_like(RHO), RHO)
    fig, ax = plt.subplots(figsize=(7.2, 4.6), constrained_layout=True)
    mesh = ax.pcolormesh(rho_grid, n_grid, Z, shading="auto", cmap=LOSS_CMAP, norm=LogNorm(vmin=1e-12, vmax=max(float(np.nanmax(Z)), 1e-3)))
    fig.colorbar(mesh, ax=ax, label="loss")
    ax.set_xlabel("rho_lane")
    ax.set_ylabel("N_SHD")
    ax.set_title("Analytical drop surface vs N_SHD and rho")
    record(22, fig)

    b_grid = np.linspace(-0.25, 0.95, 80)
    B, K = np.meshgrid(b_grid, n_grid)
    Z = model_loss(4, 1, K, B, np.full_like(B, 0.0075))
    fig, ax = plt.subplots(figsize=(7.2, 4.6), constrained_layout=True)
    mesh = ax.pcolormesh(b_grid, n_grid, Z, shading="auto", cmap=LOSS_CMAP, norm=LogNorm(vmin=1e-12, vmax=max(float(np.nanmax(Z)), 1e-3)))
    fig.colorbar(mesh, ax=ax, label="loss")
    ax.set_xlabel("B")
    ax.set_ylabel("N_SHD")
    ax.set_title("Analytical drop surface vs N_SHD and burstiness")
    record(23, fig)

    fig, ax = plt.subplots(figsize=(7.2, 4.4), constrained_layout=True)
    bm = data["bm"]
    if not plot_or_note(ax, bm, "burstiness-memory rows missing"):
        xs = [f(row, "memory_index") for row in bm]
        ys = [f(row, "burstiness") for row in bm]
        colors = [max(f(row, "loss_probability"), 1e-12) for row in bm]
        sc = ax.scatter(xs, ys, c=colors, cmap=LOSS_CMAP, norm=LogNorm(vmin=1e-12, vmax=1e-3), s=60, edgecolor="black")
        fig.colorbar(sc, ax=ax, label="loss")
        ax.set_xlabel("memory index M")
        ax.set_ylabel("B")
        ax.set_title("RTL traffic-regime metadata map")
        ax.grid(True, alpha=0.25)
    record(24, fig)

    fig, axes = plt.subplots(2, 1, figsize=(8.4, 6.2), constrained_layout=True, sharex=True)
    drr = data["rtl_drr"]
    if drr:
        labels = [f"{row['run_tag']}:L{row['lane']}" for row in drr]
        x = np.arange(len(drr))
        axes[0].plot(x, [f(row, "allowance") for row in drr], marker="o", label="allowance")
        axes[0].plot(x, [f(row, "quantum") for row in drr], marker="s", label="quantum")
        axes[1].bar(x - 0.2, [f(row, "grants") for row in drr], width=0.4, label="grants")
        axes[1].bar(x + 0.2, [f(row, "defers") for row in drr], width=0.4, label="defers")
        axes[1].set_xticks(x)
        axes[1].set_xticklabels(labels, rotation=60, ha="right", fontsize=7)
        axes[0].legend(fontsize=8)
        axes[1].legend(fontsize=8)
        axes[0].set_ylabel("counter")
        axes[1].set_ylabel("events")
        axes[0].set_title("DRR final live-stat snapshot")
    else:
        for ax in axes:
            plot_or_note(ax, [], "DRR rows missing")
    record(25, fig)

    fig, ax = plt.subplots(figsize=(8.0, 3.6), constrained_layout=True)
    closure = data["closure"]
    cols = ["A", "T", "S", "B", "A_T", "T_S", "A_S"]
    if not plot_or_note(ax, closure, "closure matrix missing"):
        matrix = np.zeros((len(closure), len(cols)))
        for ridx, row in enumerate(closure):
            for cidx, col in enumerate(cols):
                matrix[ridx, cidx] = 1.0 if row.get(col) == "PASS" else 0.5 if "PENDING" in row.get(col, "") else 0.0
        ax.imshow(matrix, cmap="RdYlGn", vmin=0, vmax=1, aspect="auto")
        ax.set_xticks(np.arange(len(cols)))
        ax.set_xticklabels(cols)
        ax.set_yticks(np.arange(len(closure)))
        ax.set_yticklabels([row["case"] for row in closure])
        for ridx, row in enumerate(closure):
            for cidx, col in enumerate(cols):
                ax.text(cidx, ridx, row.get(col, ""), ha="center", va="center", fontsize=7)
        ax.set_title("Closure matrix: A/T/S pass, board pending")
    record(26, fig)

    fig, axes = plt.subplots(1, 4, figsize=(12.4, 3.8), constrained_layout=True, sharey=True)
    tier_rows = [
        ("A", filter_rows(a, n_lane=4, egress=1, ready=1.0, burstiness=0.0)),
        ("T", filter_rows(t, n_lane=4, egress=1, ready=1.0, burstiness=0.0)),
    ]
    for ax, (label, rows) in zip(axes[:2], tier_rows):
        x, y = line_points(rows, "rho_lane")
        ax.plot(x, y, marker="o")
        ax.set_yscale("log")
        ax.set_title(label)
        ax.set_xlabel("rho_lane")
        ax.grid(True, alpha=0.25)
    axes[2].scatter([f(row, "rho_lane") for row in r2], [max(f(row, "loss_probability"), 1e-12) for row in r2], color="black")
    axes[2].set_yscale("log")
    axes[2].set_title("S")
    axes[2].set_xlabel("rho_lane")
    axes[2].grid(True, alpha=0.25)
    axes[3].text(0.5, 0.5, "pending board run", ha="center", va="center", transform=axes[3].transAxes)
    axes[3].set_title("B")
    axes[0].set_ylabel("loss")
    record(27, fig)

    fig, axes = plt.subplots(2, 2, figsize=(11.2, 7.2), constrained_layout=True)
    add_loss_contour(axes[0, 0], filter_rows(a, n_lane=4, egress=1, ready=1.0), "Delivered loss surface", show_cbar=False, rtl_rows=r2)
    rows = [row for row in ratio if i(row, "n_lane") == 4 and i(row, "egress_symbols_per_beat") == 1 and close(f(row, "rho_lane"), 0.0075, 1e-6)]
    xs, ys, z = pivot(rows, "burstiness", "ready_duty", "loss_ratio_clipped")
    if len(xs) > 1:
        axes[0, 1].pcolormesh(xs, ys, np.maximum(z, 1.0), shading="auto", cmap=GAIN_CMAP, norm=LogNorm(vmin=1, vmax=max(float(np.nanmax(z)), 10)))
    axes[0, 1].set_title("Gain N=4 E=1")
    axes[0, 1].set_xlabel("B")
    axes[0, 1].set_ylabel("ready")
    xs = np.arange(len(scale_rows))
    axes[1, 0].plot(xs, gains, marker="o")
    axes[1, 0].set_yscale("log")
    axes[1, 0].set_title("Feature gain")
    axes[1, 0].set_xlabel("feature index")
    if closure:
        matrix = np.array([[1.0 if row.get(col) == "PASS" else 0.5 for col in cols] for row in closure])
        axes[1, 1].imshow(matrix, cmap="RdYlGn", vmin=0, vmax=1, aspect="auto")
        axes[1, 1].set_xticks(np.arange(len(cols)))
        axes[1, 1].set_xticklabels(cols, fontsize=7)
        axes[1, 1].set_yticks(np.arange(len(closure)))
        axes[1, 1].set_yticklabels([row["case"] for row in closure], fontsize=7)
    axes[1, 1].set_title("Closure")
    record(28, fig)

    return outputs


def make_contact_sheet(outputs: list[tuple[int, str, str, str, Path]]) -> Path:
    VISUAL_DIR.mkdir(parents=True, exist_ok=True)
    thumbs = []
    for idx, _slug, title, _equation, path in outputs:
        img = Image.open(path).convert("RGB")
        img.thumbnail((360, 240))
        canvas = Image.new("RGB", (380, 285), "white")
        canvas.paste(img, ((380 - img.width) // 2, 5))
        draw = ImageDraw.Draw(canvas)
        draw.text((10, 250), f"{idx:02d} {title[:42]}", fill="black")
        thumbs.append(canvas)
    cols = 4
    rows = math.ceil(len(thumbs) / cols)
    sheet = Image.new("RGB", (cols * 380, rows * 285), "white")
    for idx, thumb in enumerate(thumbs):
        sheet.paste(thumb, ((idx % cols) * 380, (idx // cols) * 285))
    out = VISUAL_DIR / "contact_sheet.png"
    sheet.save(out)
    return out


def write_report(outputs: list[tuple[int, str, str, str, Path]], contact_sheet: Path) -> Path:
    lines: list[str] = []
    lines.append("# MODEL_REPORT.md - packet_scheduler OPQ model publish report")
    lines.append("")
    lines.append("This report centralizes the MODEL_PUBLISH figure set. Analytical rows are the architecture baseline; TLM rows are executable model evidence; RTL SIM rows are generated by `rtl_sim/scripts/run_model_publish_rtl_sweep.py`; the board tier remains explicitly tagged as pending until on-board CSVs land.")
    lines.append("")
    lines.append("Shared equations: burstiness is `$B=(CV-1)/(CV+1)$`, so `$CV=(1+B)/(1-B)$` and `$SCV=CV^2$`; the effective load is `$\\rho_{eff}=(N_{LANE}\\rho_{lane}/(E\\,q))\\sqrt{(1+SCV)/2}$`; finite-buffer loss is approximated by `$P_K=((1-\\rho_{eff})\\rho_{eff}^{K})/(1-\\rho_{eff}^{K+1})$`; OPQ gain is `$G=P_{loss,TM}/P_{loss,OPQ}$`; ready duty is `$q=H/(H+L)$`.")
    lines.append("")
    lines.append(f"Visual check contact sheet: ![contact sheet]({contact_sheet.relative_to(MODEL_ROOT).as_posix()})")
    lines.append("")
    for idx, _slug, title, equation, path in outputs:
        rel = path.relative_to(MODEL_ROOT).as_posix()
        lines.append(f"## Set {idx:02d} - {title}")
        lines.append("")
        lines.append(f"Analytical equation: {equation}.")
        lines.append("")
        lines.append(f"![Set {idx:02d} - {title}]({rel})")
        lines.append("")
    report = MODEL_ROOT / "MODEL_REPORT.md"
    report.write_text("\n".join(lines))
    return report


def main() -> int:
    GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    VISUAL_DIR.mkdir(parents=True, exist_ok=True)
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        data = load_all()
        outputs = render_figures(data)
        contact = make_contact_sheet(outputs)
        report = write_report(outputs, contact)
    warn_log = VISUAL_DIR / "matplotlib_warnings.log"
    warn_log.write_text("\n".join(str(w.message) for w in caught))
    print(f"[MODEL_REPORT] wrote {report}")
    print(f"[MODEL_REPORT] wrote {len(outputs)} figures under {GOLDEN_DIR}")
    print(f"[MODEL_REPORT] visual contact sheet {contact}")
    print(f"[MODEL_REPORT] matplotlib warnings {len(caught)}")
    return 0 if len(outputs) == 28 else 1


if __name__ == "__main__":
    raise SystemExit(main())
