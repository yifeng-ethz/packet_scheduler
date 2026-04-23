#!/usr/bin/env python3
"""Sweep an OPQ-inspired finite-buffer queue and emit a regular loss grid."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, List


DEFAULT_BURSTINESS_MIN = -1.0
DEFAULT_BURSTINESS_MAX = 0.90
DEFAULT_BURSTINESS_COUNT = 17
DEFAULT_RATE_MIN = 0.86
DEFAULT_RATE_MAX = 1.04
DEFAULT_RATE_COUNT = 13
DEFAULT_BUFFER_CAPACITY = 255
DEFAULT_WARMUP_ARRIVALS = 10_000
DEFAULT_MEASURED_ARRIVALS = 100_000
DEFAULT_SEED = 20_260_423


@dataclass
class SweepPoint:
    burstiness_target: float
    burstiness_measured: float
    scv_target: float
    scv_measured: float
    rate_per_lane: float
    loss_probability: float
    arrivals_measured: int
    drops_measured: int


def linspace(start: float, stop: float, count: int) -> List[float]:
    if count <= 1:
        return [float(start)]
    step = (stop - start) / float(count - 1)
    return [start + (step * idx) for idx in range(count)]


def burstiness_to_scv(burstiness: float) -> float:
    if burstiness <= -0.999_999:
        return 0.0
    return (1.0 + burstiness) / (1.0 - burstiness)


def scv_to_burstiness(scv: float) -> float:
    if scv <= 0.0:
        return -1.0
    return (scv - 1.0) / (scv + 1.0)


def make_interarrival_sampler(
    rng: random.Random,
    rate_per_lane: float,
    burstiness_target: float,
):
    mean_interarrival = 1.0 / rate_per_lane
    scv_target = burstiness_to_scv(burstiness_target)

    if scv_target == 0.0:
        def deterministic_sample() -> float:
            return mean_interarrival

        return deterministic_sample, scv_target

    gamma_shape = 1.0 / scv_target
    gamma_scale = mean_interarrival / gamma_shape

    def gamma_sample() -> float:
        return rng.gammavariate(gamma_shape, gamma_scale)

    return gamma_sample, scv_target


def sample_scv(samples: Iterable[float]) -> float:
    values = list(samples)
    if not values:
        return 0.0
    mean_v = sum(values) / float(len(values))
    if mean_v == 0.0:
        return 0.0
    variance_v = sum((value - mean_v) ** 2 for value in values) / float(len(values))
    return variance_v / (mean_v * mean_v)


def simulate_loss_point(
    rate_per_lane: float,
    burstiness_target: float,
    buffer_capacity: int,
    warmup_arrivals: int,
    measured_arrivals: int,
    seed: int,
) -> SweepPoint:
    rng = random.Random(seed)
    sample_interarrival, scv_target = make_interarrival_sampler(
        rng, rate_per_lane, burstiness_target
    )

    total_arrivals = warmup_arrivals + measured_arrivals
    arrival_index = 0
    dropped_measured = 0
    measured_seen = 0
    interarrivals_measured: list[float] = []

    queue_depth = 0
    now = 0.0
    next_arrival = sample_interarrival()
    next_departure = math.inf
    previous_arrival_time: float | None = None

    while arrival_index < total_arrivals:
        if next_departure <= next_arrival:
            now = next_departure
            queue_depth -= 1
            next_departure = now + 1.0 if queue_depth > 0 else math.inf
            continue

        now = next_arrival
        if previous_arrival_time is not None and arrival_index >= warmup_arrivals:
            interarrivals_measured.append(now - previous_arrival_time)
        previous_arrival_time = now

        in_measurement_window = arrival_index >= warmup_arrivals
        if in_measurement_window:
            measured_seen += 1

        if queue_depth < buffer_capacity:
            queue_depth += 1
            if queue_depth == 1:
                next_departure = now + 1.0
        elif in_measurement_window:
            dropped_measured += 1

        arrival_index += 1
        next_arrival = now + sample_interarrival()

    scv_measured = sample_scv(interarrivals_measured)
    return SweepPoint(
        burstiness_target=burstiness_target,
        burstiness_measured=scv_to_burstiness(scv_measured),
        scv_target=scv_target,
        scv_measured=scv_measured,
        rate_per_lane=rate_per_lane,
        loss_probability=(dropped_measured / measured_seen) if measured_seen else 0.0,
        arrivals_measured=measured_seen,
        drops_measured=dropped_measured,
    )


def write_grid_dat(
    output_path: Path,
    x_values: list[float],
    y_values: list[float],
    rows: list[SweepPoint],
) -> None:
    row_map = {
        (round(point.burstiness_target, 8), round(point.rate_per_lane, 8)): point
        for point in rows
    }
    with output_path.open("w", encoding="utf-8") as handle:
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
    parser = argparse.ArgumentParser(
        description="Emit an OPQ-inspired burstiness/rate loss surface."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "REPORT" / "math",
        help="Directory for CSV, DAT, and JSON outputs.",
    )
    parser.add_argument(
        "--burstiness-min",
        type=float,
        default=DEFAULT_BURSTINESS_MIN,
        help="Minimum target burstiness on the x-axis.",
    )
    parser.add_argument(
        "--burstiness-max",
        type=float,
        default=DEFAULT_BURSTINESS_MAX,
        help="Maximum target burstiness on the x-axis.",
    )
    parser.add_argument(
        "--burstiness-count",
        type=int,
        default=DEFAULT_BURSTINESS_COUNT,
        help="Number of x-axis sweep points.",
    )
    parser.add_argument(
        "--rate-min",
        type=float,
        default=DEFAULT_RATE_MIN,
        help="Minimum offered rate per lane (rho).",
    )
    parser.add_argument(
        "--rate-max",
        type=float,
        default=DEFAULT_RATE_MAX,
        help="Maximum offered rate per lane (rho).",
    )
    parser.add_argument(
        "--rate-count",
        type=int,
        default=DEFAULT_RATE_COUNT,
        help="Number of y-axis sweep points.",
    )
    parser.add_argument(
        "--buffer-capacity",
        type=int,
        default=DEFAULT_BUFFER_CAPACITY,
        help="Finite queue capacity K in the GI/D/1/K abstraction.",
    )
    parser.add_argument(
        "--warmup-arrivals",
        type=int,
        default=DEFAULT_WARMUP_ARRIVALS,
        help="Warm-up arrivals discarded before measuring loss.",
    )
    parser.add_argument(
        "--measured-arrivals",
        type=int,
        default=DEFAULT_MEASURED_ARRIVALS,
        help="Measured arrivals used per sweep point.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help="Base RNG seed for repeatable sweeps.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    burstiness_values = linspace(
        args.burstiness_min, args.burstiness_max, args.burstiness_count
    )
    rate_values = linspace(args.rate_min, args.rate_max, args.rate_count)

    rows: list[SweepPoint] = []
    for burstiness_idx, burstiness in enumerate(burstiness_values):
        for rate_idx, rate_per_lane in enumerate(rate_values):
            point_seed = args.seed + (burstiness_idx * 1009) + (rate_idx * 9176)
            rows.append(
                simulate_loss_point(
                    rate_per_lane=rate_per_lane,
                    burstiness_target=burstiness,
                    buffer_capacity=args.buffer_capacity,
                    warmup_arrivals=args.warmup_arrivals,
                    measured_arrivals=args.measured_arrivals,
                    seed=point_seed,
                )
            )

    csv_path = args.output_dir / "loss_surface_grid.csv"
    dat_path = args.output_dir / "loss_surface_grid.dat"
    json_path = args.output_dir / "loss_surface_summary.json"

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(asdict(rows[0]).keys()))
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))

    write_grid_dat(dat_path, burstiness_values, rate_values, rows)

    measured_burstiness_error = [
        abs(point.burstiness_measured - point.burstiness_target) for point in rows
    ]
    summary = {
        "model": "GI/D/1/K",
        "scope_note": (
            "OPQ-inspired analytical loss surface; not a direct RTL drop-probability "
            "measurement."
        ),
        "buffer_capacity": args.buffer_capacity,
        "service_cycles_per_hit": 1.0,
        "burstiness_definition": "B = (SCV - 1) / (SCV + 1)",
        "rate_definition": "rho = lambda / mu",
        "burstiness_range": [args.burstiness_min, args.burstiness_max],
        "rate_range": [args.rate_min, args.rate_max],
        "burstiness_count": args.burstiness_count,
        "rate_count": args.rate_count,
        "warmup_arrivals": args.warmup_arrivals,
        "measured_arrivals": args.measured_arrivals,
        "seed": args.seed,
        "loss_probability_min": min(point.loss_probability for point in rows),
        "loss_probability_max": max(point.loss_probability for point in rows),
        "measured_burstiness_abs_err_max": max(measured_burstiness_error),
        "measured_burstiness_abs_err_mean": (
            sum(measured_burstiness_error) / len(measured_burstiness_error)
        ),
        "artifacts": {
            "csv": str(csv_path),
            "grid_dat": str(dat_path),
        },
    }
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {csv_path}")
    print(f"Wrote {dat_path}")
    print(f"Wrote {json_path}")
    print(
        "Loss range: {:.6f} .. {:.6f}".format(
            summary["loss_probability_min"], summary["loss_probability_max"]
        )
    )


if __name__ == "__main__":
    main()
