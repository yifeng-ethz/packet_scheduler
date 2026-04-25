#!/usr/bin/env python3
"""Generate an OPQ-inspired lane-skew loss curve for the math report."""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path


DEFAULT_N_SHD_VALUES = (64, 128, 256)
DEFAULT_SKEW_MIN_FRAMES = 0.0
DEFAULT_SKEW_MAX_FRAMES = 2.0
DEFAULT_SKEW_COUNT = 81
DEFAULT_RHO = 0.92
DEFAULT_LANE_COUNT = 4
DEFAULT_ALIGNED_LANES = 3
DEFAULT_TICKET_FIFO_DEPTH = 256
DEFAULT_TIMESTAMP_UNIT_NS = 8.0


@dataclass
class SkewPoint:
    n_shd: int
    ticket_fifo_depth: int
    skew_frames: float
    skew_timestamp_ticks: float
    skew_ns: float
    aligned_poisson_mean: float
    offered_poisson_mean: float
    overflow_mean: float
    loss_rate: float


def linspace(start: float, stop: float, count: int) -> list[float]:
    if count <= 1:
        return [start]
    step = (stop - start) / float(count - 1)
    return [start + idx * step for idx in range(count)]


def poisson_overflow_mean(mu: float, capacity: int) -> float:
    if mu <= 0.0:
        return 0.0
    try:
        from scipy.stats import poisson

        # For X~Poisson(mu), E[(X-D)+] = mu P(X>=D) - D P(X>D).
        return max(0.0, (mu * poisson.sf(capacity - 1, mu)) - (capacity * poisson.sf(capacity, mu)))
    except Exception:
        # Continuity-corrected normal fallback for environments without SciPy.
        sigma = math.sqrt(mu)
        if sigma == 0.0:
            return 0.0
        z = (capacity + 0.5 - mu) / sigma
        pdf = math.exp(-0.5 * z * z) / math.sqrt(2.0 * math.pi)
        sf = 0.5 * math.erfc(z / math.sqrt(2.0))
        return max(0.0, sigma * pdf + (mu - capacity) * sf)


def build_rows(args: argparse.Namespace) -> list[SkewPoint]:
    rows: list[SkewPoint] = []
    skew_values = linspace(args.skew_min_frames, args.skew_max_frames, args.skew_count)

    for n_shd in args.n_shd:
        frame_ticks = float(n_shd * 16)
        ticket_depth = args.ticket_fifo_depth
        for skew_frames in skew_values:
            aligned_mean = args.aligned_lanes * args.rho * float(n_shd) * skew_frames
            offered_mean = args.lane_count * args.rho * float(n_shd) * skew_frames
            overflow_mean = poisson_overflow_mean(aligned_mean, ticket_depth)
            loss_rate = 0.0 if offered_mean <= 0.0 else overflow_mean / offered_mean
            skew_ticks = skew_frames * frame_ticks

            rows.append(
                SkewPoint(
                    n_shd=n_shd,
                    ticket_fifo_depth=ticket_depth,
                    skew_frames=skew_frames,
                    skew_timestamp_ticks=skew_ticks,
                    skew_ns=skew_ticks * args.timestamp_unit_ns,
                    aligned_poisson_mean=aligned_mean,
                    offered_poisson_mean=offered_mean,
                    overflow_mean=overflow_mean,
                    loss_rate=loss_rate,
                )
            )
    return rows


def write_csv(path: Path, rows: list[SkewPoint]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=list(asdict(rows[0]).keys()),
            lineterminator="\n",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Emit an OPQ-inspired lane-skew loss-rate curve."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "REPORT" / "math",
        help="Directory for CSV and JSON outputs.",
    )
    parser.add_argument(
        "--n-shd",
        type=int,
        nargs="+",
        default=list(DEFAULT_N_SHD_VALUES),
        help="N_SHD values to plot.",
    )
    parser.add_argument(
        "--skew-min-frames",
        type=float,
        default=DEFAULT_SKEW_MIN_FRAMES,
        help="Minimum one-lane skew in frame units.",
    )
    parser.add_argument(
        "--skew-max-frames",
        type=float,
        default=DEFAULT_SKEW_MAX_FRAMES,
        help="Maximum one-lane skew in frame units.",
    )
    parser.add_argument(
        "--skew-count",
        type=int,
        default=DEFAULT_SKEW_COUNT,
        help="Number of skew samples.",
    )
    parser.add_argument(
        "--rho",
        type=float,
        default=DEFAULT_RHO,
        help="Poisson offered subheader-equivalent load per lane per frame slot.",
    )
    parser.add_argument(
        "--lane-count",
        type=int,
        default=DEFAULT_LANE_COUNT,
        help="Total lane count in the skew model.",
    )
    parser.add_argument(
        "--aligned-lanes",
        type=int,
        default=DEFAULT_ALIGNED_LANES,
        help="Number of lanes aligned ahead of the skewed lane.",
    )
    parser.add_argument(
        "--ticket-fifo-depth",
        type=int,
        default=DEFAULT_TICKET_FIFO_DEPTH,
        help="Fixed finite ticket window used to isolate frame-SOP skew effects.",
    )
    parser.add_argument(
        "--timestamp-unit-ns",
        type=float,
        default=DEFAULT_TIMESTAMP_UNIT_NS,
        help="Header timestamp tick period in ns.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    rows = build_rows(args)
    csv_path = args.output_dir / "lane_skew_loss.csv"
    json_path = args.output_dir / "lane_skew_loss_summary.json"
    png_path = args.output_dir / "lane_skew_loss.png"
    svg_path = args.output_dir / "lane_skew_loss.svg"

    write_csv(csv_path, rows)
    summary = {
        "model": "OPQ-inspired finite ticket-window skew proxy",
        "scope_note": (
            "Analytical Poisson stress proxy; not a direct RTL drop-probability "
            "measurement."
        ),
        "lane_count": args.lane_count,
        "aligned_lanes": args.aligned_lanes,
        "skewed_lanes": args.lane_count - args.aligned_lanes,
        "n_shd": args.n_shd,
        "ticket_fifo_depth": args.ticket_fifo_depth,
        "rho": args.rho,
        "skew_frames_range": [args.skew_min_frames, args.skew_max_frames],
        "skew_count": args.skew_count,
        "timestamp_unit_ns": args.timestamp_unit_ns,
        "frame_tick_formula": "frame_ticks = N_SHD * 16",
        "n_shd_128_frame_ticks": 128 * 16,
        "n_shd_128_frame_tick_hex": "0x800",
        "loss_formula": (
            "X~Poisson(3*rho*N_SHD*skew_frames); "
            "loss_rate=E[max(0,X-ticket_fifo_depth)]/(4*rho*N_SHD*skew_frames)"
        ),
        "ticket_fifo_depth_policy": (
            "fixed at the active 256-entry scope to isolate the N_SHD-dependent "
            "frame-SOP timestamp displacement"
        ),
        "artifacts": {
            "csv": str(csv_path),
            "png": str(png_path),
            "svg": str(svg_path),
        },
    }
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")

    print(f"Wrote {csv_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    main()
