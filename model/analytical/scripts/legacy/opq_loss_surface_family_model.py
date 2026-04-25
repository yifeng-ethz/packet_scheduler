#!/usr/bin/env python3
"""Generate OPQ loss-contour grids for lane-count and egress-width sweeps."""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path


DEFAULT_N_LANE_VALUES = (4, 8, 16)
DEFAULT_EGRESS_SYMBOLS = (1, 2, 4, 8)
DEFAULT_BURSTINESS_MIN = -1.0
DEFAULT_BURSTINESS_MAX = 1.0
DEFAULT_BURSTINESS_COUNT = 121
DEFAULT_RATE_MIN = 0.01
DEFAULT_RATE_MAX = 1.05
DEFAULT_RATE_COUNT = 121
DEFAULT_BUFFER_CAPACITY = 255
MAX_ENDPOINT_SCV = 1_000.0


@dataclass
class FamilyPoint:
    n_lane: int
    egress_symbols_per_beat: int
    burstiness: float
    scv: float
    rate_per_lane: float
    effective_load: float
    buffer_capacity: int
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
    return (1.0 + burstiness) / (1.0 - burstiness)


def variability_factor(scv: float) -> float:
    return max(0.10, min(12.0, math.sqrt((1.0 + scv) / 2.0)))


def finite_queue_loss(load: float, capacity: int) -> float:
    if load <= 0.0:
        return 0.0
    if abs(load - 1.0) < 1.0e-9:
        return 1.0 / float(capacity + 1)
    log_load = math.log(load)
    if load < 1.0:
        numerator = (1.0 - load) * math.exp(float(capacity) * log_load)
        denominator = 1.0 - math.exp(float(capacity + 1) * log_load)
        return max(0.0, min(1.0, numerator / denominator))
    if float(capacity + 1) * log_load > 700.0:
        return max(0.0, min(1.0, (load - 1.0) / load))
    numerator = (load - 1.0) * math.exp(float(capacity) * log_load)
    denominator = math.exp(float(capacity + 1) * log_load) - 1.0
    return max(0.0, min(1.0, numerator / denominator))


def build_rows(args: argparse.Namespace) -> list[FamilyPoint]:
    rows: list[FamilyPoint] = []
    burstiness_values = linspace(
        args.burstiness_min, args.burstiness_max, args.burstiness_count
    )
    rate_values = linspace(args.rate_min, args.rate_max, args.rate_count)

    for n_lane in args.n_lane:
        for egress_symbols in args.egress_symbols:
            for burstiness in burstiness_values:
                scv = burstiness_to_scv(burstiness)
                variability = variability_factor(scv)
                for rate_per_lane in rate_values:
                    load = (
                        rate_per_lane
                        * float(n_lane)
                        / float(egress_symbols)
                        * variability
                    )
                    rows.append(
                        FamilyPoint(
                            n_lane=n_lane,
                            egress_symbols_per_beat=egress_symbols,
                            burstiness=burstiness,
                            scv=scv,
                            rate_per_lane=rate_per_lane,
                            effective_load=load,
                            buffer_capacity=args.buffer_capacity,
                            loss_probability=finite_queue_loss(load, args.buffer_capacity),
                        )
                    )
    return rows


def write_dat(
    path: Path,
    rows: list[FamilyPoint],
    n_lane: int,
    egress_symbols: int,
    x_values: list[float],
    y_values: list[float],
) -> None:
    row_map = {
        (round(point.burstiness, 8), round(point.rate_per_lane, 8)): point
        for point in rows
        if point.n_lane == n_lane and point.egress_symbols_per_beat == egress_symbols
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
        default=Path(__file__).resolve().parents[1] / "REPORT" / "math" / "opq_family",
    )
    parser.add_argument("--n-lane", type=int, nargs="+", default=list(DEFAULT_N_LANE_VALUES))
    parser.add_argument(
        "--egress-symbols",
        type=int,
        nargs="+",
        default=list(DEFAULT_EGRESS_SYMBOLS),
    )
    parser.add_argument("--burstiness-min", type=float, default=DEFAULT_BURSTINESS_MIN)
    parser.add_argument("--burstiness-max", type=float, default=DEFAULT_BURSTINESS_MAX)
    parser.add_argument("--burstiness-count", type=int, default=DEFAULT_BURSTINESS_COUNT)
    parser.add_argument("--rate-min", type=float, default=DEFAULT_RATE_MIN)
    parser.add_argument("--rate-max", type=float, default=DEFAULT_RATE_MAX)
    parser.add_argument("--rate-count", type=int, default=DEFAULT_RATE_COUNT)
    parser.add_argument("--buffer-capacity", type=int, default=DEFAULT_BUFFER_CAPACITY)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows = build_rows(args)
    x_values = linspace(args.burstiness_min, args.burstiness_max, args.burstiness_count)
    y_values = linspace(args.rate_min, args.rate_max, args.rate_count)

    csv_path = args.output_dir / "opq_loss_surface_family.csv"
    json_path = args.output_dir / "opq_loss_surface_family_summary.json"
    dat_paths: dict[str, str] = {}

    with csv_path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(asdict(rows[0]).keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))

    for n_lane in args.n_lane:
        for egress_symbols in args.egress_symbols:
            stem = f"opq_loss_surface_nlane{n_lane:02d}_egress{egress_symbols:02d}x"
            dat_path = args.output_dir / f"{stem}.dat"
            write_dat(dat_path, rows, n_lane, egress_symbols, x_values, y_values)
            dat_paths[f"N_LANE={n_lane},EGRESS={egress_symbols}x"] = str(dat_path)

    summary = {
        "model": "OPQ finite-buffer bandwidth contour family",
        "scope_note": (
            "Analytical bandwidth/finite-buffer proxy; not direct RTL "
            "drop-probability evidence."
        ),
        "n_lane": args.n_lane,
        "egress_symbols_per_beat": args.egress_symbols,
        "buffer_capacity": args.buffer_capacity,
        "burstiness_definition": "B = (SCV - 1) / (SCV + 1)",
        "effective_load": (
            "rho_eff = rate_per_lane * N_LANE / EGRESS_SYMBOLS_PER_BEAT "
            "* sqrt((1+SCV)/2)"
        ),
        "rate_range": [args.rate_min, args.rate_max],
        "burstiness_range": [args.burstiness_min, args.burstiness_max],
        "artifacts": {
            "csv": str(csv_path),
            "grid_dat": dat_paths,
        },
    }
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
    print(f"Wrote {csv_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    main()
