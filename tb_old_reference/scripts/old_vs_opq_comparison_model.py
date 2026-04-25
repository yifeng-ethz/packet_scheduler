#!/usr/bin/env python3
"""Generate an OPQ-vs-old-time-merger analytical loss comparison."""

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
DEFAULT_SKEW_COUNT = 121
DEFAULT_RHO = 0.92
DEFAULT_LANE_COUNT = 4
DEFAULT_ALIGNED_LANES = 3
DEFAULT_OPQ_TICKET_FIFO_DEPTH = 256
DEFAULT_OLD_NODE_SERVICE_CREDIT = 96.0
DEFAULT_OLD_STAGE_BUBBLE_CYCLES = 1.0
DEFAULT_TIMESTAMP_UNIT_NS = 8.0
LOSS_FLOOR = 1.0e-12
RATIO_CLIP = 1.0e6


@dataclass
class ComparisonPoint:
    n_shd: int
    skew_frames: float
    skew_timestamp_ticks: float
    skew_ns: float
    aligned_poisson_mean: float
    offered_poisson_mean: float
    opq_effective_capacity: int
    old_tree_depth: int
    old_effective_capacity: int
    opq_loss_rate: float
    old_time_merger_loss_rate: float
    loss_ratio_clipped: float
    log10_opq_loss_rate: float
    log10_old_time_merger_loss_rate: float
    log10_loss_ratio_clipped: float


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

        return max(0.0, (mu * poisson.sf(capacity - 1, mu)) - (capacity * poisson.sf(capacity, mu)))
    except Exception:
        sigma = math.sqrt(mu)
        if sigma == 0.0:
            return 0.0
        z = (capacity + 0.5 - mu) / sigma
        pdf = math.exp(-0.5 * z * z) / math.sqrt(2.0 * math.pi)
        sf = 0.5 * math.erfc(z / math.sqrt(2.0))
        return max(0.0, sigma * pdf + (mu - capacity) * sf)


def ceil_log2(value: int) -> int:
    if value <= 1:
        return 0
    return int(math.ceil(math.log2(float(value))))


def old_effective_capacity(args: argparse.Namespace) -> tuple[int, int, float]:
    tree_depth = ceil_log2(args.lane_count)
    service_efficiency = 1.0 / (1.0 + (tree_depth * args.old_stage_bubble_cycles))
    effective_capacity = max(1, int(round(args.old_node_service_credit * service_efficiency)))
    return tree_depth, effective_capacity, service_efficiency


def build_rows(args: argparse.Namespace) -> tuple[list[ComparisonPoint], dict[str, object]]:
    rows: list[ComparisonPoint] = []
    skew_values = linspace(args.skew_min_frames, args.skew_max_frames, args.skew_count)
    tree_depth, old_capacity, old_service_efficiency = old_effective_capacity(args)
    ratio_by_n: dict[int, float] = {}
    ratio_ge_1e3: dict[int, list[float]] = {}
    ratio_ge_1e6: dict[int, list[float]] = {}

    for n_shd in args.n_shd:
        frame_ticks = float(n_shd * 16)
        ratio_by_n[n_shd] = 0.0
        ratio_ge_1e3[n_shd] = []
        ratio_ge_1e6[n_shd] = []

        for skew_frames in skew_values:
            aligned_mean = args.aligned_lanes * args.rho * float(n_shd) * skew_frames
            offered_mean = args.lane_count * args.rho * float(n_shd) * skew_frames

            opq_overflow = poisson_overflow_mean(aligned_mean, args.opq_ticket_fifo_depth)
            old_overflow = poisson_overflow_mean(aligned_mean, old_capacity)

            opq_loss = 0.0 if offered_mean <= 0.0 else opq_overflow / offered_mean
            old_loss = 0.0 if offered_mean <= 0.0 else old_overflow / offered_mean
            raw_ratio = old_loss / max(opq_loss, LOSS_FLOOR)
            ratio = min(RATIO_CLIP, max(1.0, raw_ratio))

            ratio_by_n[n_shd] = max(ratio_by_n[n_shd], ratio)
            if ratio >= 1.0e3:
                ratio_ge_1e3[n_shd].append(skew_frames)
            if ratio >= RATIO_CLIP:
                ratio_ge_1e6[n_shd].append(skew_frames)

            rows.append(
                ComparisonPoint(
                    n_shd=n_shd,
                    skew_frames=skew_frames,
                    skew_timestamp_ticks=skew_frames * frame_ticks,
                    skew_ns=skew_frames * frame_ticks * args.timestamp_unit_ns,
                    aligned_poisson_mean=aligned_mean,
                    offered_poisson_mean=offered_mean,
                    opq_effective_capacity=args.opq_ticket_fifo_depth,
                    old_tree_depth=tree_depth,
                    old_effective_capacity=old_capacity,
                    opq_loss_rate=opq_loss,
                    old_time_merger_loss_rate=old_loss,
                    loss_ratio_clipped=ratio,
                    log10_opq_loss_rate=math.log10(max(opq_loss, LOSS_FLOOR)),
                    log10_old_time_merger_loss_rate=math.log10(max(old_loss, LOSS_FLOOR)),
                    log10_loss_ratio_clipped=math.log10(ratio),
                )
            )

    def span(values: list[float]) -> list[float] | None:
        if not values:
            return None
        return [min(values), max(values)]

    summary = {
        "model": "OPQ vs old time-merger analytical skew-loss proxy",
        "scope_note": (
            "This is not pin-equivalent RTL evidence.  It compares the OPQ finite "
            "ticket-window stress model against a simplified old tree-merger "
            "service-credit model derived from the historical VHDL architecture."
        ),
        "lane_count": args.lane_count,
        "aligned_lanes": args.aligned_lanes,
        "skewed_lanes": args.lane_count - args.aligned_lanes,
        "n_shd": args.n_shd,
        "rho": args.rho,
        "skew_frames_range": [args.skew_min_frames, args.skew_max_frames],
        "skew_count": args.skew_count,
        "timestamp_unit_ns": args.timestamp_unit_ns,
        "frame_tick_formula": "frame_ticks = N_SHD * 16",
        "opq_effective_capacity": args.opq_ticket_fifo_depth,
        "old_tree_depth": tree_depth,
        "old_stage_bubble_cycles": args.old_stage_bubble_cycles,
        "old_node_service_credit": args.old_node_service_credit,
        "old_service_efficiency": old_service_efficiency,
        "old_effective_capacity": old_capacity,
        "loss_formula": (
            "X~Poisson(3*rho*N_SHD*skew_frames); "
            "loss=E[max(0,X-capacity)]/(4*rho*N_SHD*skew_frames)"
        ),
        "ratio_floor": LOSS_FLOOR,
        "ratio_clip": RATIO_CLIP,
        "max_loss_ratio_clipped_by_n_shd": ratio_by_n,
        "skew_span_ratio_ge_1e3_by_n_shd": {str(k): span(v) for k, v in ratio_ge_1e3.items()},
        "skew_span_ratio_ge_1e6_by_n_shd": {str(k): span(v) for k, v in ratio_ge_1e6.items()},
    }
    return rows, summary


def write_csv(path: Path, rows: list[ComparisonPoint]) -> None:
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
        description="Emit an OPQ-vs-old-time-merger lane-skew loss comparison."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "REPORT",
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
    parser.add_argument("--rho", type=float, default=DEFAULT_RHO)
    parser.add_argument("--lane-count", type=int, default=DEFAULT_LANE_COUNT)
    parser.add_argument("--aligned-lanes", type=int, default=DEFAULT_ALIGNED_LANES)
    parser.add_argument(
        "--opq-ticket-fifo-depth",
        type=int,
        default=DEFAULT_OPQ_TICKET_FIFO_DEPTH,
        help="OPQ effective finite ticket-window capacity.",
    )
    parser.add_argument(
        "--old-node-service-credit",
        type=float,
        default=DEFAULT_OLD_NODE_SERVICE_CREDIT,
        help="Effective local work credit for one old merger node before tree penalty.",
    )
    parser.add_argument(
        "--old-stage-bubble-cycles",
        type=float,
        default=DEFAULT_OLD_STAGE_BUBBLE_CYCLES,
        help="Bubble/service penalty charged for each old tree stage.",
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

    rows, summary = build_rows(args)
    csv_path = args.output_dir / "old_vs_opq_loss_comparison.csv"
    json_path = args.output_dir / "old_vs_opq_loss_comparison_summary.json"
    png_path = args.output_dir / "old_vs_opq_loss_comparison.png"
    svg_path = args.output_dir / "old_vs_opq_loss_comparison.svg"

    write_csv(csv_path, rows)
    summary["artifacts"] = {
        "csv": str(csv_path),
        "png": str(png_path),
        "svg": str(svg_path),
    }
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")

    print(f"Wrote {csv_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    main()
