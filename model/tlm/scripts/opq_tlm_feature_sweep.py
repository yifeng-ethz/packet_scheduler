#!/usr/bin/env python3
"""Generate packet_scheduler OPQ/time-merger TLM loss-sweep data.

This is a deterministic transaction-level finite-FIFO model.  It is not RTL
simulation and it is not the closed-form analytical blocking proxy.  The model
keeps explicit offered/dropped/delivered transaction counters and sweeps the
same feature grid used by the analytical DISLIN report plots.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np


DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parents[1] / "data"
DEFAULT_PLOT_OUTPUT_DIR = Path(__file__).resolve().parents[1] / "plots"
DEFAULT_BURSTINESS_COUNT = 61
DEFAULT_RATE_COUNT = 61
DEFAULT_READY_COUNT = 51
LOSS_FLOOR = 1.0e-12
RATIO_CLIP = 1.0e6
MAX_ENDPOINT_SCV = 1_000.0
PUBLISHED_FEATURES = tuple(
    (n_lane, egress_symbols)
    for n_lane in (4, 8, 16)
    for egress_symbols in (1, 2, 4, 8)
)


@dataclass(frozen=True)
class TlmPoint:
    implementation: str
    n_lane: int
    egress_symbols_per_beat: int
    ready_duty: float
    burstiness: float
    scv: float
    rho_lane: float
    cycles: int
    warmup_cycles: int
    effective_capacity: int
    offered_transactions: int
    delivered_transactions: int
    dropped_transactions: int
    mean_occupancy: float
    max_occupancy: int
    loss_probability: float


@dataclass(frozen=True)
class TlmResult:
    loss: np.ndarray
    offered: np.ndarray
    delivered: np.ndarray
    dropped: np.ndarray
    mean_occupancy: np.ndarray
    max_occupancy: np.ndarray
    capacity: int


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


def time_merger_penalty(n_lane: int) -> float:
    depth = max(1, math.ceil(math.log2(max(1, n_lane))))
    return float(1 + (depth * depth))


def implementation_capacity(
    implementation: str,
    n_lane: int,
    opq_capacity: int,
    time_merger_credit: float,
) -> int:
    if implementation == "opq":
        return int(opq_capacity)
    return max(1, int(round(float(time_merger_credit) / time_merger_penalty(n_lane))))


def service_increment(
    implementation: str,
    n_lane: int,
    egress_symbols_per_beat: int,
) -> float:
    if implementation == "opq":
        return float(egress_symbols_per_beat)
    return 1.0 / time_merger_penalty(n_lane)


def burst_source_duty(
    burstiness: np.ndarray,
    min_duty: float,
    max_duty: float,
) -> np.ndarray:
    scv = np.asarray(burstiness_to_scv(burstiness), dtype=float)
    burst_gain = np.sqrt(np.maximum(scv, 0.0))
    positive_duty = 1.0 / (1.0 + (6.0 * burst_gain))
    negative_duty = 0.92 + np.minimum(np.maximum(-burstiness, 0.0), 0.50) * 0.12
    duty = np.where(burstiness > 0.0, positive_duty, negative_duty)
    return np.clip(duty, min_duty, max_duty)


def simulate_tlm_grid(
    implementation: str,
    n_lane: int,
    egress_symbols_per_beat: int,
    ready_duty: np.ndarray | float,
    burstiness_grid: np.ndarray,
    rho_grid: np.ndarray,
    args: argparse.Namespace,
) -> TlmResult:
    burstiness = np.asarray(burstiness_grid, dtype=float)
    rho = np.broadcast_to(np.asarray(rho_grid, dtype=float), burstiness.shape)
    ready = np.broadcast_to(np.asarray(ready_duty, dtype=float), burstiness.shape)
    shape = burstiness.shape

    capacity = implementation_capacity(
        implementation,
        n_lane,
        args.opq_capacity,
        args.time_merger_credit,
    )
    service_per_ready_cycle = service_increment(
        implementation,
        n_lane,
        egress_symbols_per_beat,
    )

    source_duty = burst_source_duty(
        burstiness,
        args.min_burst_source_duty,
        args.max_burst_source_duty,
    )
    source_on_len = np.clip(
        np.ceil(source_duty * float(args.burst_period)).astype(np.int64),
        1,
        args.burst_period,
    )
    ready_on_len = np.clip(
        np.ceil(np.clip(ready, 0.0, 1.0) * float(args.ready_period)).astype(np.int64),
        0,
        args.ready_period,
    )

    mean_arrival_rate = np.maximum(0.0, float(n_lane) * rho)
    burst_arrival_rate = mean_arrival_rate / np.maximum(source_duty, 1.0e-9)

    arrival_credit = np.zeros(shape, dtype=float)
    service_credit = np.zeros(shape, dtype=float)
    occupancy = np.zeros(shape, dtype=float)
    offered = np.zeros(shape, dtype=float)
    delivered = np.zeros(shape, dtype=float)
    dropped = np.zeros(shape, dtype=float)
    occupancy_sum = np.zeros(shape, dtype=float)
    max_occupancy = np.zeros(shape, dtype=float)

    measured_cycles = max(1, args.cycles - args.warmup_cycles)
    for cycle in range(args.cycles):
        source_active = (cycle % args.burst_period) < source_on_len
        arrival_credit += np.where(source_active, burst_arrival_rate, 0.0)
        arrivals = np.floor(arrival_credit)
        arrival_credit -= arrivals

        occupancy += arrivals
        overflow = np.maximum(occupancy - float(capacity), 0.0)
        occupancy -= overflow

        ready_active = (cycle % args.ready_period) < ready_on_len
        service_credit += np.where(ready_active, service_per_ready_cycle, 0.0)
        service_slots = np.floor(service_credit)
        service_credit -= service_slots
        served = np.minimum(occupancy, service_slots)
        occupancy -= served

        if cycle >= args.warmup_cycles:
            offered += arrivals
            delivered += served
            dropped += overflow
            occupancy_sum += occupancy
            max_occupancy = np.maximum(max_occupancy, occupancy)

    loss = np.divide(
        dropped,
        np.maximum(offered, 1.0),
        out=np.zeros_like(dropped),
        where=offered > 0.0,
    )
    return TlmResult(
        loss=np.maximum(loss, LOSS_FLOOR),
        offered=offered,
        delivered=delivered,
        dropped=dropped,
        mean_occupancy=occupancy_sum / float(measured_cycles),
        max_occupancy=max_occupancy,
        capacity=capacity,
    )


def write_dat_matrix(
    path: Path,
    x_values: np.ndarray,
    y_values: np.ndarray,
    z_by_y_then_x: np.ndarray,
) -> None:
    with path.open("w", encoding="ascii") as handle:
        handle.write(f"{len(x_values)} {len(y_values)}\n")
        handle.write(" ".join(f"{float(value):.8f}" for value in x_values) + "\n")
        handle.write(" ".join(f"{float(value):.8f}" for value in y_values) + "\n")
        for x_idx in range(len(x_values)):
            row = [
                f"{float(z_by_y_then_x[y_idx, x_idx]):.12e}"
                for y_idx in range(len(y_values))
            ]
            handle.write(" ".join(row) + "\n")


def write_loss_curve_dat(
    path: Path,
    rho_values: np.ndarray,
    opq_loss: np.ndarray,
    time_merger_loss: np.ndarray,
) -> None:
    with path.open("w", encoding="ascii") as handle:
        handle.write(f"{len(rho_values)}\n")
        handle.write(" ".join(f"{float(value):.8f}" for value in rho_values) + "\n")
        handle.write(" ".join(f"{float(value):.12e}" for value in opq_loss) + "\n")
        handle.write(" ".join(f"{float(value):.12e}" for value in time_merger_loss) + "\n")


def write_tlm_point_csv(path: Path, rows: list[TlmPoint]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(asdict(rows[0]).keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def append_point_rows(
    rows: list[TlmPoint],
    implementation: str,
    n_lane: int,
    egress_symbols: int,
    ready_duty: float,
    b_values: np.ndarray,
    rho_values: np.ndarray,
    result: TlmResult,
    args: argparse.Namespace,
) -> None:
    for rho_idx, rho_lane in enumerate(rho_values):
        for b_idx, burstiness in enumerate(b_values):
            rows.append(
                TlmPoint(
                    implementation=implementation,
                    n_lane=n_lane,
                    egress_symbols_per_beat=egress_symbols,
                    ready_duty=ready_duty,
                    burstiness=float(burstiness),
                    scv=float(burstiness_to_scv(float(burstiness))),
                    rho_lane=float(rho_lane),
                    cycles=args.cycles,
                    warmup_cycles=args.warmup_cycles,
                    effective_capacity=result.capacity,
                    offered_transactions=int(result.offered[rho_idx, b_idx]),
                    delivered_transactions=int(result.delivered[rho_idx, b_idx]),
                    dropped_transactions=int(result.dropped[rho_idx, b_idx]),
                    mean_occupancy=float(result.mean_occupancy[rho_idx, b_idx]),
                    max_occupancy=int(result.max_occupancy[rho_idx, b_idx]),
                    loss_probability=float(result.loss[rho_idx, b_idx]),
                )
            )


def compute_ratio_summary(
    b_values: np.ndarray,
    ready_values: np.ndarray,
    args: argparse.Namespace,
) -> dict[str, object]:
    b_grid, ready_grid = np.meshgrid(b_values, ready_values)
    rho_grid = np.full_like(b_grid, args.ratio_rho_lane)
    summary: dict[str, object] = {}

    for n_lane, egress_symbols in PUBLISHED_FEATURES:
        opq = simulate_tlm_grid(
            "opq",
            n_lane,
            egress_symbols,
            ready_grid,
            b_grid,
            rho_grid,
            args,
        )
        time_merger = simulate_tlm_grid(
            "time_merger",
            n_lane,
            egress_symbols,
            ready_grid,
            b_grid,
            rho_grid,
            args,
        )
        ratio = np.clip(time_merger.loss / np.maximum(opq.loss, LOSS_FLOOR), 1.0, RATIO_CLIP)
        summary[f"N_LANE={n_lane},EGRESS={egress_symbols}x"] = {
            "max_ratio_clipped": float(np.max(ratio)),
            "min_ratio_clipped": float(np.min(ratio)),
            "fraction_ge_1e3": float(np.mean(ratio >= 1.0e3)),
            "fraction_ge_1e6": float(np.mean(ratio >= RATIO_CLIP)),
        }
    return summary


def compute_scaling_summary(args: argparse.Namespace) -> dict[str, float]:
    summary: dict[str, float] = {}
    b_grid = np.array([[args.scaling_burstiness]], dtype=float)
    rho_grid = np.array([[args.ratio_rho_lane]], dtype=float)
    ready_grid = np.array([[args.scaling_ready_duty]], dtype=float)

    for n_lane, egress_symbols in PUBLISHED_FEATURES:
        opq = simulate_tlm_grid(
            "opq",
            n_lane,
            egress_symbols,
            ready_grid,
            b_grid,
            rho_grid,
            args,
        )
        time_merger = simulate_tlm_grid(
            "time_merger",
            n_lane,
            egress_symbols,
            ready_grid,
            b_grid,
            rho_grid,
            args,
        )
        ratio = float(
            np.clip(time_merger.loss / np.maximum(opq.loss, LOSS_FLOOR), 1.0, RATIO_CLIP)[0, 0]
        )
        summary[f"N_LANE={n_lane},EGRESS={egress_symbols}x"] = ratio
    return summary


def write_tlm_grids(
    args: argparse.Namespace,
    output_dir: Path,
    plot_output_dir: Path,
) -> dict[str, object]:
    dislin_dir = output_dir / "dislin"
    dislin_dir.mkdir(parents=True, exist_ok=True)
    plot_output_dir.mkdir(parents=True, exist_ok=True)

    b_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    rho_values = linspace(args.rho_min, args.rho_max, args.rate_count)
    ready_values = linspace(args.ready_min, args.ready_max, args.ready_count)
    b_rho_grid, rho_grid = np.meshgrid(b_values, rho_values)
    b_ready_grid, ready_grid = np.meshgrid(b_values, ready_values)
    ratio_rho_grid = np.full_like(b_ready_grid, args.ratio_rho_lane)

    point_rows: list[TlmPoint] = []
    ready_ratio_rows: list[dict[str, object]] = []
    scaling_rows: list[dict[str, object]] = []
    loss_dat: dict[str, str] = {}
    opq_loss_dat: dict[str, str] = {}
    time_merger_loss_dat: dict[str, str] = {}
    ratio_dat: dict[str, str] = {}
    loss_curve_dat: dict[str, str] = {}
    published_png: dict[str, str] = {}

    for n_lane, egress_symbols in PUBLISHED_FEATURES:
        key = f"N_LANE={n_lane},EGRESS={egress_symbols}x"
        loss_stem = f"opq_loss_surface_nlane{n_lane:02d}_egress{egress_symbols:02d}x"
        overlay_stem = (
            f"opq_vs_time_merger_loss_contour_nlane{n_lane:02d}_egress{egress_symbols:02d}x"
        )
        curve_stem = (
            f"opq_vs_time_merger_loss_curve_nlane{n_lane:02d}_egress{egress_symbols:02d}x"
        )
        ratio_stem = (
            f"opq_vs_time_merger_ready_burst_ratio_nlane{n_lane:02d}_egress{egress_symbols:02d}x"
        )

        opq = simulate_tlm_grid(
            "opq",
            n_lane,
            egress_symbols,
            1.0,
            b_rho_grid,
            rho_grid,
            args,
        )
        time_merger = simulate_tlm_grid(
            "time_merger",
            n_lane,
            egress_symbols,
            1.0,
            b_rho_grid,
            rho_grid,
            args,
        )
        append_point_rows(
            point_rows,
            "opq",
            n_lane,
            egress_symbols,
            1.0,
            b_values,
            rho_values,
            opq,
            args,
        )
        append_point_rows(
            point_rows,
            "time_merger",
            n_lane,
            egress_symbols,
            1.0,
            b_values,
            rho_values,
            time_merger,
            args,
        )

        loss_dat_path = dislin_dir / f"{loss_stem}.dat"
        opq_dat_path = dislin_dir / f"{overlay_stem}_opq.dat"
        tm_dat_path = dislin_dir / f"{overlay_stem}_time_merger.dat"
        write_dat_matrix(loss_dat_path, b_values, rho_values, opq.loss)
        write_dat_matrix(opq_dat_path, b_values, rho_values, opq.loss)
        write_dat_matrix(tm_dat_path, b_values, rho_values, time_merger.loss)
        loss_dat[key] = str(loss_dat_path)
        opq_loss_dat[key] = str(opq_dat_path)
        time_merger_loss_dat[key] = str(tm_dat_path)
        published_png[f"{key},OPQ_LOSS_SURFACE"] = str(plot_output_dir / f"{loss_stem}.png")
        published_png[f"{key},LOSS_CONTOUR_OVERLAY"] = str(plot_output_dir / f"{overlay_stem}.png")

        curve_b = np.full_like(rho_values, args.scaling_burstiness)
        curve_rho = rho_values
        opq_curve = simulate_tlm_grid(
            "opq",
            n_lane,
            egress_symbols,
            args.scaling_ready_duty,
            curve_b,
            curve_rho,
            args,
        )
        tm_curve = simulate_tlm_grid(
            "time_merger",
            n_lane,
            egress_symbols,
            args.scaling_ready_duty,
            curve_b,
            curve_rho,
            args,
        )
        curve_dat_path = dislin_dir / f"{curve_stem}.dat"
        write_loss_curve_dat(curve_dat_path, rho_values, opq_curve.loss, tm_curve.loss)
        loss_curve_dat[key] = str(curve_dat_path)
        published_png[f"{key},LOSS_CURVE"] = str(plot_output_dir / f"{curve_stem}.png")

        opq_ready = simulate_tlm_grid(
            "opq",
            n_lane,
            egress_symbols,
            ready_grid,
            b_ready_grid,
            ratio_rho_grid,
            args,
        )
        tm_ready = simulate_tlm_grid(
            "time_merger",
            n_lane,
            egress_symbols,
            ready_grid,
            b_ready_grid,
            ratio_rho_grid,
            args,
        )
        ratio = np.clip(tm_ready.loss / np.maximum(opq_ready.loss, LOSS_FLOOR), 1.0, RATIO_CLIP)
        ratio_dat_path = dislin_dir / f"{ratio_stem}.dat"
        write_dat_matrix(ratio_dat_path, b_values, ready_values, ratio)
        ratio_dat[key] = str(ratio_dat_path)
        published_png[f"{key},READY_BURST_RATIO"] = str(plot_output_dir / f"{ratio_stem}.png")
        for ready_idx, ready_duty in enumerate(ready_values):
            for b_idx, burstiness in enumerate(b_values):
                ready_ratio_rows.append(
                    {
                        "n_lane": n_lane,
                        "egress_symbols_per_beat": egress_symbols,
                        "burstiness": f"{burstiness:.8f}",
                        "ready_duty": f"{ready_duty:.8f}",
                        "rho_lane": f"{args.ratio_rho_lane:.8f}",
                        "opq_loss_probability": f"{opq_ready.loss[ready_idx, b_idx]:.12e}",
                        "time_merger_loss_probability": f"{tm_ready.loss[ready_idx, b_idx]:.12e}",
                        "loss_ratio_clipped": f"{ratio[ready_idx, b_idx]:.10f}",
                    }
                )

    n_values = np.array([4.0, 8.0, 16.0])
    e_values = np.array([1.0, 2.0, 4.0, 8.0])
    scaling_matrix = np.zeros((len(n_values), len(e_values)), dtype=float)
    b_grid = np.array([[args.scaling_burstiness]], dtype=float)
    rho_grid = np.array([[args.ratio_rho_lane]], dtype=float)
    ready_grid = np.array([[args.scaling_ready_duty]], dtype=float)
    for n_idx, n_lane_value in enumerate(n_values):
        for e_idx, egress_value in enumerate(e_values):
            opq = simulate_tlm_grid(
                "opq",
                int(n_lane_value),
                int(egress_value),
                ready_grid,
                b_grid,
                rho_grid,
                args,
            )
            tm = simulate_tlm_grid(
                "time_merger",
                int(n_lane_value),
                int(egress_value),
                ready_grid,
                b_grid,
                rho_grid,
                args,
            )
            ratio = float(np.clip(tm.loss / np.maximum(opq.loss, LOSS_FLOOR), 1.0, RATIO_CLIP)[0, 0])
            scaling_matrix[n_idx, e_idx] = ratio
            scaling_rows.append(
                {
                    "n_lane": int(n_lane_value),
                    "egress_symbols_per_beat": int(egress_value),
                    "burstiness": f"{args.scaling_burstiness:.8f}",
                    "ready_duty": f"{args.scaling_ready_duty:.8f}",
                    "rho_lane": f"{args.ratio_rho_lane:.8f}",
                    "opq_loss_probability": f"{opq.loss[0, 0]:.12e}",
                    "time_merger_loss_probability": f"{tm.loss[0, 0]:.12e}",
                    "loss_ratio_clipped": f"{ratio:.10f}",
                }
            )

    scaling_dat = dislin_dir / "opq_vs_time_merger_feature_scaling.dat"
    write_dat_matrix(scaling_dat, e_values, n_values, scaling_matrix)
    published_png["FEATURE_SCALING"] = str(plot_output_dir / "opq_vs_time_merger_feature_scaling.png")

    loss_csv = output_dir / "tlm_full_feature_loss_surface_grid.csv"
    ratio_csv = output_dir / "tlm_opq_vs_time_merger_ready_burst_ratio_grid.csv"
    scaling_csv = output_dir / "tlm_opq_vs_time_merger_feature_scaling_grid.csv"
    write_tlm_point_csv(loss_csv, point_rows)
    with ratio_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(ready_ratio_rows[0].keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(ready_ratio_rows)
    with scaling_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(scaling_rows[0].keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(scaling_rows)

    return {
        "loss_surface_csv": str(loss_csv),
        "ready_burst_ratio_csv": str(ratio_csv),
        "feature_scaling_csv": str(scaling_csv),
        "dislin_dir": str(dislin_dir),
        "published_plot_dir": str(plot_output_dir),
        "opq_loss_surface_dat": loss_dat,
        "opq_loss_overlay_dat": opq_loss_dat,
        "time_merger_loss_overlay_dat": time_merger_loss_dat,
        "loss_curve_dat": loss_curve_dat,
        "ready_burst_ratio_dat": ratio_dat,
        "feature_scaling_dat": str(scaling_dat),
        "published_png": published_png,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--plot-output-dir", type=Path, default=DEFAULT_PLOT_OUTPUT_DIR)
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
    parser.add_argument("--cycles", type=int, default=8192)
    parser.add_argument("--warmup-cycles", type=int, default=1024)
    parser.add_argument("--burst-period", type=int, default=1024)
    parser.add_argument("--ready-period", type=int, default=37)
    parser.add_argument("--min-burst-source-duty", type=float, default=0.025)
    parser.add_argument("--max-burst-source-duty", type=float, default=0.98)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    args.plot_output_dir.mkdir(parents=True, exist_ok=True)

    artifacts = write_tlm_grids(args, args.output_dir, args.plot_output_dir)
    b_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    ready_values = linspace(args.ready_min, args.ready_max, args.ready_count)
    summary = {
        "model": "OPQ/time-merger deterministic TLM finite-FIFO event model",
        "scope_note": (
            "Transaction-level model only.  It uses explicit offered, delivered, "
            "and dropped transaction counters, but it is not HDL simulation or "
            "on-board evidence."
        ),
        "slide_alignment": (
            "The sweep follows the delay-jitter/RTO buffer-loss framing from "
            "the reordering slides: bursty arrivals create finite-buffer "
            "outliers, and old time-merger throughput falls with tree depth."
        ),
        "burstiness_definition": "B = (SCV - 1) / (SCV + 1)",
        "scv_definition": "SCV = (1 + B) / (1 - B)",
        "traffic_model": (
            "Each point runs a deterministic on/off transaction source with "
            "mean arrival rate N_LANE*rho_lane and source duty tau(B)."
        ),
        "ready_model": (
            "Egress ready is a deterministic vacation process with configured "
            "duty q and period ready_period."
        ),
        "time_merger_penalty": "P_tm = 1 + ceil(log2(N_LANE))^2",
        "opq_service_tokens": "EGRESS_SYMBOLS_PER_BEAT tokens on each ready cycle",
        "time_merger_service_tokens": "1/P_tm token on each ready cycle",
        "opq_capacity": args.opq_capacity,
        "time_merger_credit": args.time_merger_credit,
        "cycles": args.cycles,
        "warmup_cycles": args.warmup_cycles,
        "burst_period": args.burst_period,
        "ready_period": args.ready_period,
        "ratio_clip": RATIO_CLIP,
        "ratio_rho_lane": args.ratio_rho_lane,
        "scaling_stress_point": {
            "burstiness": args.scaling_burstiness,
            "ready_duty": args.scaling_ready_duty,
            "rho_lane": args.ratio_rho_lane,
        },
        "ratio_surface_summary": compute_ratio_summary(b_values, ready_values, args),
        "feature_scaling_ratio": compute_scaling_summary(args),
        "artifacts": artifacts,
    }
    summary_path = args.output_dir / "tlm_model_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
    print(f"Wrote {summary_path}")
    print(f"Wrote DISLIN TLM data under {args.output_dir / 'dislin'}")


if __name__ == "__main__":
    main()
