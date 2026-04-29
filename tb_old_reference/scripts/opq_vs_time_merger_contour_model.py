#!/usr/bin/env python3
"""Generate OPQ-vs-time-merger burst/rate contour comparison grids."""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path


DEFAULT_N_LANE = 4
DEFAULT_EGRESS_SYMBOLS_PER_BEAT = 1
DEFAULT_BURSTINESS_MIN = -1.0
DEFAULT_BURSTINESS_MAX = 1.0
DEFAULT_BURSTINESS_COUNT = 121
DEFAULT_RATE_MIN = 0.01
DEFAULT_RATE_MAX = 0.40
DEFAULT_RATE_COUNT = 101
DEFAULT_OPQ_CAPACITY = 255
DEFAULT_TIME_MERGER_NODE_CREDIT = 96.0
DEFAULT_TIME_MERGER_STAGE_BUBBLE = 1.0
MAX_ENDPOINT_SCV = 1_000.0


@dataclass
class ContourPoint:
    implementation: str
    n_lane: int
    egress_symbols_per_beat: int
    burstiness: float
    scv: float
    rate_per_lane: float
    effective_load: float
    effective_capacity: int
    loss_probability: float


def linspace(start: float, stop: float, count: int) -> list[float]:
    if count <= 1:
        return [float(start)]
    step = (stop - start) / float(count - 1)
    return [start + (idx * step) for idx in range(count)]


def burstiness_to_scv(burstiness: float) -> float:
    if burstiness <= -0.999_999:
        return 0.0
    if burstiness >= 0.999_999:
        return MAX_ENDPOINT_SCV
    cv = (1.0 + burstiness) / (1.0 - burstiness)
    return min(MAX_ENDPOINT_SCV, cv * cv)


def finite_queue_loss(load: float, capacity: int) -> float:
    if load <= 0.0:
        return 0.0
    if capacity <= 0:
        return 1.0
    if abs(load - 1.0) < 1.0e-9:
        return 1.0 / float(capacity + 1)
    log_load = math.log(load)
    if load < 1.0:
        # M/M/1/K blocking probability used as a smooth finite-buffer proxy.
        numerator = (1.0 - load) * math.exp(float(capacity) * log_load)
        denominator = 1.0 - math.exp(float(capacity + 1) * log_load)
        return max(0.0, min(1.0, numerator / denominator))
    if float(capacity + 1) * log_load > 700.0:
        return max(0.0, min(1.0, (load - 1.0) / load))
    numerator = (load - 1.0) * math.exp(float(capacity) * log_load)
    denominator = math.exp(float(capacity + 1) * log_load) - 1.0
    return max(0.0, min(1.0, numerator / denominator))


def variability_factor(scv: float) -> float:
    # Kingman-style variability factor: deterministic traffic is gentler than
    # Poisson, while bursty arrivals consume the finite buffer earlier.
    return max(0.10, min(12.0, math.sqrt((1.0 + scv) / 2.0)))


def time_merger_service_and_capacity(args: argparse.Namespace) -> tuple[float, int, int]:
    tree_depth = math.ceil(math.log2(max(1, args.n_lane)))
    service = 1.0 / (1.0 + (tree_depth * args.time_merger_stage_bubble))
    capacity = max(1, int(round(args.time_merger_node_credit * service)))
    return service, capacity, tree_depth


def build_rows(args: argparse.Namespace) -> tuple[list[ContourPoint], dict[str, object]]:
    rows: list[ContourPoint] = []
    burstiness_values = linspace(
        args.burstiness_min, args.burstiness_max, args.burstiness_count
    )
    rate_values = linspace(args.rate_min, args.rate_max, args.rate_count)
    time_merger_service, time_merger_capacity, tree_depth = time_merger_service_and_capacity(args)

    impls = [
        ("OPQ", float(args.egress_symbols_per_beat), args.opq_capacity),
        ("Time-Merger", time_merger_service, time_merger_capacity),
    ]

    for implementation, service_symbols_per_beat, capacity in impls:
        for burstiness in burstiness_values:
            scv = burstiness_to_scv(burstiness)
            variability = variability_factor(scv)
            for rate_per_lane in rate_values:
                offered_symbols_per_cycle = rate_per_lane * float(args.n_lane)
                load = (offered_symbols_per_cycle / service_symbols_per_beat) * variability
                rows.append(
                    ContourPoint(
                        implementation=implementation,
                        n_lane=args.n_lane,
                        egress_symbols_per_beat=args.egress_symbols_per_beat,
                        burstiness=burstiness,
                        scv=scv,
                        rate_per_lane=rate_per_lane,
                        effective_load=load,
                        effective_capacity=capacity,
                        loss_probability=finite_queue_loss(load, capacity),
                    )
                )

    summary = {
        "model": "finite-buffer OPQ vs time-merger burst/rate proxy",
        "scope_note": (
            "Analytical contour comparison.  It uses finite-buffer blocking as a "
            "smooth proxy and is not direct RTL drop-probability evidence."
        ),
        "n_lane": args.n_lane,
        "opq_egress_symbols_per_beat": args.egress_symbols_per_beat,
        "opq_capacity": args.opq_capacity,
        "time_merger_tree_depth": tree_depth,
        "time_merger_stage_bubble": args.time_merger_stage_bubble,
        "time_merger_service_symbols_per_beat": time_merger_service,
        "time_merger_capacity": time_merger_capacity,
        "burstiness_definition": "B = (CV - 1) / (CV + 1), CV=sigma_tau/m_tau",
        "effective_load": (
            "rho_eff = rate_per_lane * N_LANE / service_symbols_per_beat "
            "* sqrt((1+SCV)/2)"
        ),
        "rate_range": [args.rate_min, args.rate_max],
        "burstiness_range": [args.burstiness_min, args.burstiness_max],
    }
    return rows, summary


def write_csv(path: Path, rows: list[ContourPoint]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(asdict(rows[0]).keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def write_dat(
    path: Path,
    implementation: str,
    x_values: list[float],
    y_values: list[float],
    rows: list[ContourPoint],
) -> None:
    row_map = {
        (round(point.burstiness, 8), round(point.rate_per_lane, 8)): point
        for point in rows
        if point.implementation == implementation
    }
    with path.open("w", encoding="ascii") as handle:
        handle.write(f"{len(x_values)} {len(y_values)}\n")
        handle.write(" ".join(f"{value:.8f}" for value in x_values) + "\n")
        handle.write(" ".join(f"{value:.8f}" for value in y_values) + "\n")
        for burstiness in x_values:
            values = []
            for rate in y_values:
                point = row_map[(round(burstiness, 8), round(rate, 8))]
                values.append(f"{point.loss_probability:.10f}")
            handle.write(" ".join(values) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "REPORT",
    )
    parser.add_argument("--n-lane", type=int, default=DEFAULT_N_LANE)
    parser.add_argument(
        "--egress-symbols-per-beat",
        type=int,
        default=DEFAULT_EGRESS_SYMBOLS_PER_BEAT,
    )
    parser.add_argument("--burstiness-min", type=float, default=DEFAULT_BURSTINESS_MIN)
    parser.add_argument("--burstiness-max", type=float, default=DEFAULT_BURSTINESS_MAX)
    parser.add_argument("--burstiness-count", type=int, default=DEFAULT_BURSTINESS_COUNT)
    parser.add_argument("--rate-min", type=float, default=DEFAULT_RATE_MIN)
    parser.add_argument("--rate-max", type=float, default=DEFAULT_RATE_MAX)
    parser.add_argument("--rate-count", type=int, default=DEFAULT_RATE_COUNT)
    parser.add_argument("--opq-capacity", type=int, default=DEFAULT_OPQ_CAPACITY)
    parser.add_argument(
        "--time-merger-node-credit",
        type=float,
        default=DEFAULT_TIME_MERGER_NODE_CREDIT,
    )
    parser.add_argument(
        "--time-merger-stage-bubble",
        type=float,
        default=DEFAULT_TIME_MERGER_STAGE_BUBBLE,
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows, summary = build_rows(args)
    x_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    y_values = linspace(args.rate_min, args.rate_max, args.rate_count)

    csv_path = args.output_dir / "opq_vs_time_merger_contour_grid.csv"
    opq_dat_path = args.output_dir / "opq_vs_time_merger_contour_opq.dat"
    tm_dat_path = args.output_dir / "opq_vs_time_merger_contour_time_merger.dat"
    json_path = args.output_dir / "opq_vs_time_merger_contour_summary.json"
    png_path = args.output_dir / "opq_vs_time_merger_loss_contour.png"
    svg_path = args.output_dir / "opq_vs_time_merger_loss_contour.svg"

    write_csv(csv_path, rows)
    write_dat(opq_dat_path, "OPQ", x_values, y_values, rows)
    write_dat(tm_dat_path, "Time-Merger", x_values, y_values, rows)
    summary["artifacts"] = {
        "csv": str(csv_path),
        "opq_grid_dat": str(opq_dat_path),
        "time_merger_grid_dat": str(tm_dat_path),
        "png": str(png_path),
        "svg": str(svg_path),
    }
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
    print(f"Wrote {csv_path}")
    print(f"Wrote {opq_dat_path}")
    print(f"Wrote {tm_dat_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    main()
