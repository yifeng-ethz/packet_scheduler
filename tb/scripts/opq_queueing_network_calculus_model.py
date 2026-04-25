#!/usr/bin/env python3
"""Generate OPQ queueing/network-calculus model plots.

The generated figures are analytical design-space artifacts.  They are not RTL
drop-probability evidence; MATH_REPORT.md keeps that distinction explicit.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import Normalize


DEFAULT_OUTPUT_DIR = (
    Path(__file__).resolve().parents[1] / "REPORT" / "math" / "queueing_model"
)
DEFAULT_BURSTINESS_COUNT = 121
DEFAULT_RATE_COUNT = 121
DEFAULT_READY_COUNT = 101
LOSS_FLOOR = 1.0e-12
RATIO_CLIP = 1.0e6
MAX_ENDPOINT_SCV = 1_000.0


@dataclass(frozen=True)
class FeaturePoint:
    implementation: str
    n_lane: int
    egress_symbols_per_beat: int
    ready_duty: float
    burstiness: float
    scv: float
    rho_lane: float
    service_symbols_per_cycle: float
    effective_load: float
    effective_capacity: int
    loss_probability: float


def linspace(start: float, stop: float, count: int) -> np.ndarray:
    return np.linspace(float(start), float(stop), int(count))


def burstiness_to_scv(burstiness: np.ndarray | float) -> np.ndarray | float:
    if isinstance(burstiness, np.ndarray):
        clipped = np.clip(burstiness, -0.999999, 0.999999)
        return (1.0 + clipped) / (1.0 - clipped)
    if burstiness <= -0.999999:
        return 0.0
    if burstiness >= 0.999999:
        return MAX_ENDPOINT_SCV
    return (1.0 + burstiness) / (1.0 - burstiness)


def variability_factor(scv: np.ndarray | float) -> np.ndarray | float:
    return np.clip(np.sqrt((1.0 + scv) / 2.0), 0.10, 12.0)


def finite_queue_loss(load: np.ndarray | float, capacity: int) -> np.ndarray | float:
    load_arr = np.asarray(load, dtype=float)
    load_safe = np.maximum(load_arr, 0.0)
    result = np.zeros_like(load_safe)

    if capacity <= 0:
        result[...] = 1.0
        return result if isinstance(load, np.ndarray) else float(result)

    near_one = np.isclose(load_safe, 1.0, rtol=0.0, atol=1.0e-9)
    result[near_one] = 1.0 / float(capacity + 1)

    low = (load_safe > 0.0) & (load_safe < 1.0) & ~near_one
    if np.any(low):
        rho = load_safe[low]
        log_rho = np.log(rho)
        numerator = (1.0 - rho) * np.exp(float(capacity) * log_rho)
        denominator = 1.0 - np.exp(float(capacity + 1) * log_rho)
        result[low] = numerator / denominator

    high = (load_safe > 1.0) & ~near_one
    if np.any(high):
        rho = load_safe[high]
        log_rho = np.log(rho)
        exponent = float(capacity + 1) * log_rho
        high_result = np.empty_like(rho)
        saturated = exponent > 700.0
        high_result[saturated] = (rho[saturated] - 1.0) / rho[saturated]
        if np.any(~saturated):
            rho_u = rho[~saturated]
            log_u = log_rho[~saturated]
            numerator = (rho_u - 1.0) * np.exp(float(capacity) * log_u)
            denominator = np.exp(float(capacity + 1) * log_u) - 1.0
            high_result[~saturated] = numerator / denominator
        result[high] = high_result

    result = np.clip(result, 0.0, 1.0)
    return result if isinstance(load, np.ndarray) else float(result)


def time_merger_penalty(n_lane: int) -> float:
    # Historical tree-merger comparison model: the supported lane count rises by
    # adding tree arbitration stages, while service and local credit lose a
    # quadratic-in-depth factor.
    depth = max(1, math.ceil(math.log2(max(1, n_lane))))
    return float(1 + (depth * depth))


def service_and_capacity(
    implementation: str,
    n_lane: int,
    egress_symbols_per_beat: int,
    ready_duty: float,
    opq_capacity: int,
    time_merger_credit: float,
) -> tuple[float, int]:
    ready = np.asarray(ready_duty, dtype=float)
    if implementation == "opq":
        service = np.maximum(1.0e-9, ready * float(egress_symbols_per_beat))
        if service.shape == ():
            return float(service), opq_capacity
        return service, opq_capacity
    penalty = time_merger_penalty(n_lane)
    service = np.maximum(1.0e-9, ready / penalty)
    capacity = max(1, int(round(time_merger_credit / penalty)))
    if service.shape == ():
        return float(service), capacity
    return service, capacity


def loss_surface(
    implementation: str,
    n_lane: int,
    egress_symbols_per_beat: int,
    ready_duty: float,
    burstiness_grid: np.ndarray,
    rho_grid: np.ndarray,
    opq_capacity: int,
    time_merger_credit: float,
) -> tuple[np.ndarray, np.ndarray]:
    scv = burstiness_to_scv(burstiness_grid)
    variability = variability_factor(scv)
    service, capacity = service_and_capacity(
        implementation,
        n_lane,
        egress_symbols_per_beat,
        ready_duty,
        opq_capacity,
        time_merger_credit,
    )
    effective_load = (rho_grid * float(n_lane) / service) * variability
    loss = finite_queue_loss(effective_load, capacity)
    return effective_load, np.maximum(loss, LOSS_FLOOR)


def write_feature_csv(
    output_path: Path,
    rows: list[FeaturePoint],
) -> None:
    with output_path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(asdict(rows[0]).keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def build_feature_rows(args: argparse.Namespace) -> list[FeaturePoint]:
    rows: list[FeaturePoint] = []
    b_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    rho_values = linspace(args.rho_min, args.rho_max, args.rate_count)
    ready_values = linspace(args.ready_min, args.ready_max, args.ready_count)

    for n_lane, egress_symbols in args.feature:
        for implementation in ("opq", "time_merger"):
            for ready_duty in ready_values:
                for burstiness in b_values:
                    scv = float(burstiness_to_scv(float(burstiness)))
                    variability = float(variability_factor(scv))
                    service, capacity = service_and_capacity(
                        implementation,
                        n_lane,
                        egress_symbols,
                        float(ready_duty),
                        args.opq_capacity,
                        args.time_merger_credit,
                    )
                    for rho_lane in rho_values:
                        effective_load = (
                            float(rho_lane) * float(n_lane) / service * variability
                        )
                        loss = finite_queue_loss(effective_load, capacity)
                        rows.append(
                            FeaturePoint(
                                implementation=implementation,
                                n_lane=n_lane,
                                egress_symbols_per_beat=egress_symbols,
                                ready_duty=float(ready_duty),
                                burstiness=float(burstiness),
                                scv=scv,
                                rho_lane=float(rho_lane),
                                service_symbols_per_cycle=service,
                                effective_load=float(effective_load),
                                effective_capacity=capacity,
                                loss_probability=float(loss),
                            )
                        )
    return rows


def add_reference_contours(ax: plt.Axes, x: np.ndarray, y: np.ndarray, z: np.ndarray) -> None:
    levels = [math.log10(1.0e-6), math.log10(1.0e-2), math.log10(5.0e-2)]
    labels = {
        math.log10(1.0e-6): "1e-6",
        math.log10(1.0e-2): "1%",
        math.log10(5.0e-2): "5%",
    }
    visible = [level for level in levels if float(np.min(z)) < level < float(np.max(z))]
    if not visible:
        return
    contours = ax.contour(
        x,
        y,
        z,
        levels=visible,
        colors=["#14213d"] * len(visible),
        linewidths=[1.1] * len(visible),
        linestyles=["dotted" if level == levels[0] else "dashed" if level == levels[1] else "solid" for level in visible],
    )
    ax.clabel(contours, fmt=labels, inline=True, fontsize=8)


def plot_opq_loss_surface(args: argparse.Namespace, output_dir: Path) -> None:
    b_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    rho_values = linspace(args.rho_min, args.rho_max, args.rate_count)
    b_grid, rho_grid = np.meshgrid(b_values, rho_values)

    fig, axes = plt.subplots(2, 2, figsize=(12.0, 9.2), sharex=True, sharey=True)
    features = [(4, 1), (8, 2), (16, 4), (16, 8)]
    levels = np.linspace(-12.0, 0.0, 49)

    for ax, (n_lane, egress_symbols) in zip(axes.flat, features):
        _, loss = loss_surface(
            "opq",
            n_lane,
            egress_symbols,
            1.0,
            b_grid,
            rho_grid,
            args.opq_capacity,
            args.time_merger_credit,
        )
        z = np.log10(np.maximum(loss, LOSS_FLOOR))
        mesh = ax.contourf(
            b_values,
            rho_values,
            z,
            levels=levels,
            cmap="magma_r",
            extend="both",
        )
        add_reference_contours(ax, b_values, rho_values, z)
        ax.set_title(f"OPQ N={n_lane}, egress={egress_symbols} word/beat", fontsize=11)
        ax.grid(True, alpha=0.22, linewidth=0.6)

    for ax in axes[-1, :]:
        ax.set_xlabel("burstiness B = (SCV - 1) / (SCV + 1)")
    for ax in axes[:, 0]:
        ax.set_ylabel("per-lane offered rate rho_lane")

    cbar_ax = fig.add_axes([0.895, 0.16, 0.024, 0.70])
    cbar = fig.colorbar(mesh, cax=cbar_ax)
    cbar.set_label("loss probability")
    cbar.set_ticks([-12, -9, -6, -3, 0])
    cbar.set_ticklabels(["1e-12", "1e-9", "1e-6", "1e-3", "1"])
    fig.suptitle("OPQ full-feature loss surface model", fontsize=15, y=0.985)
    fig.text(
        0.5,
        0.018,
        "Analytical finite-buffer model at ready duty=1.0; darker cells indicate higher loss. Reference contours: 1e-6, 1%, 5%.",
        ha="center",
        fontsize=9,
    )
    fig.subplots_adjust(left=0.075, right=0.84, bottom=0.085, top=0.93, wspace=0.16, hspace=0.20)
    fig.savefig(output_dir / "opq_full_feature_loss_surface.png", dpi=180)
    fig.savefig(output_dir / "opq_full_feature_loss_surface.svg")
    plt.close(fig)


def plot_ratio_surface(args: argparse.Namespace, output_dir: Path) -> dict[str, object]:
    b_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    ready_values = linspace(args.ready_min, args.ready_max, args.ready_count)
    b_grid, ready_grid = np.meshgrid(b_values, ready_values)
    rho_grid = np.full_like(b_grid, args.ratio_rho_lane)

    fig, axes = plt.subplots(2, 2, figsize=(12.0, 9.2), sharex=True, sharey=True)
    features = [(4, 1), (8, 2), (16, 4), (16, 8)]
    levels = np.linspace(0.0, 6.0, 49)
    summary: dict[str, object] = {}

    for ax, (n_lane, egress_symbols) in zip(axes.flat, features):
        _, opq_loss = loss_surface(
            "opq",
            n_lane,
            egress_symbols,
            ready_grid,
            b_grid,
            rho_grid,
            args.opq_capacity,
            args.time_merger_credit,
        )
        _, tm_loss = loss_surface(
            "time_merger",
            n_lane,
            egress_symbols,
            ready_grid,
            b_grid,
            rho_grid,
            args.opq_capacity,
            args.time_merger_credit,
        )
        ratio = np.clip(tm_loss / np.maximum(opq_loss, LOSS_FLOOR), 1.0, RATIO_CLIP)
        z = np.log10(ratio)
        mesh = ax.contourf(
            b_values,
            ready_values,
            z,
            levels=levels,
            cmap="magma_r",
            extend="max",
        )
        visible = [level for level in [3.0, 6.0] if np.min(z) < level < np.max(z)]
        if visible:
            contours = ax.contour(
                b_values,
                ready_values,
                z,
                levels=visible,
                colors="#fffbcc",
                linewidths=1.2,
                linestyles=["dashed" if level == 3.0 else "solid" for level in visible],
            )
            ax.clabel(contours, fmt={3.0: "1e3x", 6.0: "1e6x"}, inline=True, fontsize=8)
        ax.set_title(f"N={n_lane}, OPQ egress={egress_symbols}x vs time merger", fontsize=11)
        ax.grid(True, alpha=0.22, linewidth=0.6)

        key = f"N_LANE={n_lane},EGRESS={egress_symbols}x"
        summary[key] = {
            "max_ratio_clipped": float(np.max(ratio)),
            "min_ratio_clipped": float(np.min(ratio)),
            "fraction_ge_1e3": float(np.mean(ratio >= 1.0e3)),
            "fraction_ge_1e6": float(np.mean(ratio >= RATIO_CLIP)),
        }

    for ax in axes[-1, :]:
        ax.set_xlabel("burstiness B = (SCV - 1) / (SCV + 1)")
    for ax in axes[:, 0]:
        ax.set_ylabel("egress ready duty")

    cbar_ax = fig.add_axes([0.895, 0.16, 0.024, 0.70])
    cbar = fig.colorbar(mesh, cax=cbar_ax)
    cbar.set_label("time-merger loss / OPQ loss")
    cbar.set_ticks([0, 1, 2, 3, 4, 5, 6])
    cbar.set_ticklabels(["1x", "10x", "100x", "1e3x", "1e4x", "1e5x", "1e6x"])
    fig.suptitle("OPQ vs time-merger loss-ratio model", fontsize=15, y=0.985)
    fig.text(
        0.5,
        0.018,
        f"Analytical comparison at rho_lane={args.ratio_rho_lane:.4f}; contours mark 1e3x and 1e6x time-merger/OPQ loss ratio.",
        ha="center",
        fontsize=9,
    )
    fig.subplots_adjust(left=0.075, right=0.84, bottom=0.085, top=0.93, wspace=0.16, hspace=0.20)
    fig.savefig(output_dir / "opq_vs_time_merger_ready_burst_ratio.png", dpi=180)
    fig.savefig(output_dir / "opq_vs_time_merger_ready_burst_ratio.svg")
    plt.close(fig)
    return summary


def plot_feature_scaling(args: argparse.Namespace, output_dir: Path) -> dict[str, object]:
    n_values = [4, 8, 16]
    e_values = [1, 2, 4, 8]
    matrix = np.zeros((len(n_values), len(e_values)), dtype=float)
    ratio_values: dict[str, float] = {}

    for i, n_lane in enumerate(n_values):
        for j, egress_symbols in enumerate(e_values):
            b_grid = np.array([[args.scaling_burstiness]])
            rho_grid = np.array([[args.ratio_rho_lane]])
            ready_grid = np.array([[args.scaling_ready_duty]])
            _, opq_loss = loss_surface(
                "opq",
                n_lane,
                egress_symbols,
                ready_grid,
                b_grid,
                rho_grid,
                args.opq_capacity,
                args.time_merger_credit,
            )
            _, tm_loss = loss_surface(
                "time_merger",
                n_lane,
                egress_symbols,
                ready_grid,
                b_grid,
                rho_grid,
                args.opq_capacity,
                args.time_merger_credit,
            )
            ratio = float(np.clip(tm_loss / np.maximum(opq_loss, LOSS_FLOOR), 1.0, RATIO_CLIP)[0, 0])
            matrix[i, j] = math.log10(ratio)
            ratio_values[f"N_LANE={n_lane},EGRESS={egress_symbols}x"] = ratio

    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    image = ax.imshow(matrix, cmap="magma_r", norm=Normalize(vmin=0.0, vmax=6.0), aspect="auto")
    ax.set_xticks(np.arange(len(e_values)), labels=[f"{value}x" for value in e_values])
    ax.set_yticks(np.arange(len(n_values)), labels=[str(value) for value in n_values])
    ax.set_xlabel("OPQ egress width in 36-bit words/beat")
    ax.set_ylabel("N_LANE")
    ax.set_title("Feature-scaling loss-ratio model")
    for i in range(len(n_values)):
        for j in range(len(e_values)):
            value = matrix[i, j]
            ratio = 10.0 ** value
            if value >= 5.995:
                label = "1e6x"
            elif ratio >= 1.0e3:
                label = f"{ratio / 1.0e3:.1f}e3x"
            else:
                label = f"{ratio:.0f}x"
            ax.text(j, i, label, ha="center", va="center", color="white" if value > 3.0 else "black", fontsize=9)
    cbar = fig.colorbar(image, ax=ax, pad=0.025)
    cbar.set_label("time-merger loss / OPQ loss")
    cbar.set_ticks([0, 1, 2, 3, 4, 5, 6])
    cbar.set_ticklabels(["1x", "10x", "100x", "1e3x", "1e4x", "1e5x", "1e6x"])
    fig.text(
        0.5,
        0.018,
        f"Analytical stress point: B={args.scaling_burstiness:.2f}, ready duty={args.scaling_ready_duty:.2f}, rho_lane={args.ratio_rho_lane:.4f}.",
        ha="center",
        fontsize=9,
    )
    fig.subplots_adjust(left=0.11, right=0.88, bottom=0.16, top=0.88)
    fig.savefig(output_dir / "opq_vs_time_merger_feature_scaling.png", dpi=180)
    fig.savefig(output_dir / "opq_vs_time_merger_feature_scaling.svg")
    plt.close(fig)
    return ratio_values


def write_model_grids(args: argparse.Namespace, output_dir: Path) -> dict[str, str]:
    b_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    rho_values = linspace(args.rho_min, args.rho_max, args.rate_count)
    ready_values = linspace(args.ready_min, args.ready_max, args.ready_count)
    features = [(4, 1), (8, 2), (16, 4), (16, 8)]

    loss_csv = output_dir / "opq_full_feature_loss_surface_grid.csv"
    ratio_csv = output_dir / "opq_vs_time_merger_ready_burst_ratio_grid.csv"
    scaling_csv = output_dir / "opq_vs_time_merger_feature_scaling_grid.csv"

    b_grid, rho_grid = np.meshgrid(b_values, rho_values)
    with loss_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(
            [
                "implementation",
                "n_lane",
                "egress_symbols_per_beat",
                "ready_duty",
                "burstiness",
                "rho_lane",
                "effective_load",
                "loss_probability",
            ]
        )
        for n_lane, egress_symbols in features:
            effective_load, loss = loss_surface(
                "opq",
                n_lane,
                egress_symbols,
                1.0,
                b_grid,
                rho_grid,
                args.opq_capacity,
                args.time_merger_credit,
            )
            for row_idx, rho_lane in enumerate(rho_values):
                for col_idx, burstiness in enumerate(b_values):
                    writer.writerow(
                        [
                            "opq",
                            n_lane,
                            egress_symbols,
                            "1.000000",
                            f"{burstiness:.8f}",
                            f"{rho_lane:.8f}",
                            f"{effective_load[row_idx, col_idx]:.10f}",
                            f"{loss[row_idx, col_idx]:.12e}",
                        ]
                    )

    b_grid, ready_grid = np.meshgrid(b_values, ready_values)
    rho_grid = np.full_like(b_grid, args.ratio_rho_lane)
    with ratio_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(
            [
                "n_lane",
                "egress_symbols_per_beat",
                "burstiness",
                "ready_duty",
                "rho_lane",
                "opq_loss_probability",
                "time_merger_loss_probability",
                "loss_ratio_clipped",
            ]
        )
        for n_lane, egress_symbols in features:
            _, opq_loss = loss_surface(
                "opq",
                n_lane,
                egress_symbols,
                ready_grid,
                b_grid,
                rho_grid,
                args.opq_capacity,
                args.time_merger_credit,
            )
            _, tm_loss = loss_surface(
                "time_merger",
                n_lane,
                egress_symbols,
                ready_grid,
                b_grid,
                rho_grid,
                args.opq_capacity,
                args.time_merger_credit,
            )
            ratio = np.clip(tm_loss / np.maximum(opq_loss, LOSS_FLOOR), 1.0, RATIO_CLIP)
            for row_idx, ready_duty in enumerate(ready_values):
                for col_idx, burstiness in enumerate(b_values):
                    writer.writerow(
                        [
                            n_lane,
                            egress_symbols,
                            f"{burstiness:.8f}",
                            f"{ready_duty:.8f}",
                            f"{args.ratio_rho_lane:.8f}",
                            f"{opq_loss[row_idx, col_idx]:.12e}",
                            f"{tm_loss[row_idx, col_idx]:.12e}",
                            f"{ratio[row_idx, col_idx]:.10f}",
                        ]
                    )

    with scaling_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(
            [
                "n_lane",
                "egress_symbols_per_beat",
                "burstiness",
                "ready_duty",
                "rho_lane",
                "opq_loss_probability",
                "time_merger_loss_probability",
                "loss_ratio_clipped",
            ]
        )
        for n_lane in (4, 8, 16):
            for egress_symbols in (1, 2, 4, 8):
                b_grid = np.array([[args.scaling_burstiness]])
                rho_grid = np.array([[args.ratio_rho_lane]])
                ready_grid = np.array([[args.scaling_ready_duty]])
                _, opq_loss = loss_surface(
                    "opq",
                    n_lane,
                    egress_symbols,
                    ready_grid,
                    b_grid,
                    rho_grid,
                    args.opq_capacity,
                    args.time_merger_credit,
                )
                _, tm_loss = loss_surface(
                    "time_merger",
                    n_lane,
                    egress_symbols,
                    ready_grid,
                    b_grid,
                    rho_grid,
                    args.opq_capacity,
                    args.time_merger_credit,
                )
                ratio = float(
                    np.clip(
                        tm_loss / np.maximum(opq_loss, LOSS_FLOOR),
                        1.0,
                        RATIO_CLIP,
                    )[0, 0]
                )
                writer.writerow(
                    [
                        n_lane,
                        egress_symbols,
                        f"{args.scaling_burstiness:.8f}",
                        f"{args.scaling_ready_duty:.8f}",
                        f"{args.ratio_rho_lane:.8f}",
                        f"{opq_loss[0, 0]:.12e}",
                        f"{tm_loss[0, 0]:.12e}",
                        f"{ratio:.10f}",
                    ]
                )

    return {
        "opq_loss_surface_csv": str(loss_csv),
        "ready_burst_ratio_csv": str(ratio_csv),
        "feature_scaling_csv": str(scaling_csv),
    }


def parse_feature(value: str) -> tuple[int, int]:
    try:
        n_text, e_text = value.lower().replace("n", "").replace("e", "").split(",")
        return int(n_text), int(e_text)
    except Exception as exc:
        raise argparse.ArgumentTypeError(
            "feature must be formatted as 'N,E', for example '4,1'"
        ) from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--burstiness-min", type=float, default=-0.25)
    parser.add_argument("--burstiness-max", type=float, default=0.95)
    parser.add_argument("--burstiness-count", type=int, default=DEFAULT_BURSTINESS_COUNT)
    parser.add_argument("--rho-min", type=float, default=0.005)
    parser.add_argument("--rho-max", type=float, default=0.30)
    parser.add_argument("--rate-count", type=int, default=DEFAULT_RATE_COUNT)
    parser.add_argument("--ready-min", type=float, default=0.45)
    parser.add_argument("--ready-max", type=float, default=1.0)
    parser.add_argument("--ready-count", type=int, default=DEFAULT_READY_COUNT)
    parser.add_argument("--ratio-rho-lane", type=float, default=0.0075)
    parser.add_argument("--scaling-burstiness", type=float, default=0.70)
    parser.add_argument("--scaling-ready-duty", type=float, default=0.75)
    parser.add_argument("--opq-capacity", type=int, default=255)
    parser.add_argument("--time-merger-credit", type=float, default=96.0)
    parser.add_argument(
        "--feature",
        type=parse_feature,
        nargs="+",
        default=[(4, 1), (8, 2), (16, 4), (16, 8)],
        help="Feature tuple N,E. Example: --feature 4,1 8,2",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    grid_paths = write_model_grids(args, args.output_dir)
    plot_opq_loss_surface(args, args.output_dir)
    ratio_summary = plot_ratio_surface(args, args.output_dir)
    scaling_summary = plot_feature_scaling(args, args.output_dir)

    summary = {
        "model": "OPQ queueing/network-calculus analytical design-space model",
        "scope_note": (
            "Analytical model only.  It supports architecture comparison and "
            "report equations, but it is not direct RTL loss evidence."
        ),
        "burstiness_definition": "B = (SCV - 1) / (SCV + 1)",
        "arrival_curve": "A(t) <= sigma(B,rho) + N_LANE*rho_lane*t",
        "opq_service_curve": "beta_opq(t) = EGRESS_SYMBOLS_PER_BEAT*ready_duty*[t-T_opq]^+",
        "time_merger_service_curve": (
            "beta_tm(t) = ready_duty/(1+ceil(log2(N_LANE))^2)*[t-T_tm]^+"
        ),
        "blocking_proxy": (
            "p_loss ~= P_K(rho_eff), rho_eff=(N_LANE*rho_lane/R)*sqrt((1+SCV)/2)"
        ),
        "opq_capacity": args.opq_capacity,
        "time_merger_credit": args.time_merger_credit,
        "ratio_clip": RATIO_CLIP,
        "ratio_rho_lane": args.ratio_rho_lane,
        "scaling_stress_point": {
            "burstiness": args.scaling_burstiness,
            "ready_duty": args.scaling_ready_duty,
            "rho_lane": args.ratio_rho_lane,
        },
        "ratio_surface_summary": ratio_summary,
        "feature_scaling_ratio": scaling_summary,
        "artifacts": {
            **grid_paths,
            "opq_loss_surface_png": str(args.output_dir / "opq_full_feature_loss_surface.png"),
            "opq_loss_surface_svg": str(args.output_dir / "opq_full_feature_loss_surface.svg"),
            "ready_burst_ratio_png": str(args.output_dir / "opq_vs_time_merger_ready_burst_ratio.png"),
            "ready_burst_ratio_svg": str(args.output_dir / "opq_vs_time_merger_ready_burst_ratio.svg"),
            "feature_scaling_png": str(args.output_dir / "opq_vs_time_merger_feature_scaling.png"),
            "feature_scaling_svg": str(args.output_dir / "opq_vs_time_merger_feature_scaling.svg"),
        },
    }
    summary_path = args.output_dir / "queueing_model_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
    for path in grid_paths.values():
        print(f"Wrote {path}")
    print(f"Wrote {summary_path}")


if __name__ == "__main__":
    main()
