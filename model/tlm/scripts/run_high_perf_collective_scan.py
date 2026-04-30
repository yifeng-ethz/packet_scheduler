#!/usr/bin/env python3
"""Run the level-3 high-performance collective OPQ/time-merger TLM scan.

This is the accelerated LT scan used after the directed RTL/UVM transaction
gates pass. It keeps the same burstiness and physical-cadence rate points as
the 128-point RTL scan, but advances the finite queue by generation events
rather than by every RTL clock cycle.
"""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np

from opq_tlm_feature_sweep import (
    MU3E_DEMO_EGRESS_SYMBOLS,
    MU3E_DEMO_HANDLE_FIFO_DEPTH,
    MU3E_DEMO_LANE_FIFO_DEPTH,
    MU3E_DEMO_N_LANE,
    MU3E_DEMO_N_SHD,
    MU3E_DEMO_PAGE_RAM_DEPTH,
    MU3E_DEMO_PROFILE_NAME,
    MU3E_DEMO_TICKET_FIFO_DEPTH,
    burstiness_to_mean_generation_batch_hits,
    implementation_capacity,
    service_increment,
    time_merger_penalty,
)


REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_OUTPUT = REPO_ROOT / "packet_scheduler" / "model" / "tlm" / "data" / "tlm_high_perf_collective_scan128.csv"
DEFAULT_SUMMARY = REPO_ROOT / "packet_scheduler" / "model" / "tlm" / "data" / "tlm_high_perf_collective_scan128_summary.json"

BURSTINESS_MILLI = [0, 100, 200, 300, 403, 500, 600, 700]
RHO_HITS_PER_SUBHEADER = [
    0.1,
    0.2,
    0.3,
    0.4,
    0.5,
    0.6,
    0.75,
    0.9,
    1.0,
    1.2,
    1.5,
    2.0,
    3.0,
    4.0,
    6.0,
    8.0,
]


@dataclass(frozen=True)
class ScanPoint:
    implementation: str
    n_lane: int
    egress_symbols_per_beat: int
    burstiness: float
    rho_hits_per_subheader_lane: float
    rho_hit_words_per_cycle_lane: float
    target_hits: int
    offered_hits: int
    delivered_hits_after_drain: int
    dropped_hits: int
    loss_probability: float
    mean_batch_hits: float
    generation_events: int
    queue_capacity_hits: int
    service_hit_words_per_cycle: float
    max_occupancy_hits: float
    final_drain_cycles: float
    opq_persistent_knee_hits_per_subheader_lane: float
    model_persistent_knee_hits_per_subheader_lane: float
    loss_tier: str


def persistent_knee_hps(
    *,
    n_lane: int,
    n_shd: int,
    frame_period_cycles: int,
    service_hit_words_per_cycle: float,
) -> float:
    frame_overhead_words = 6 + n_shd
    usable_hit_words = max(0.0, (service_hit_words_per_cycle * frame_period_cycles) - frame_overhead_words)
    return usable_hit_words / float(n_lane * n_shd)


def run_event_queue(
    *,
    burstiness: np.ndarray,
    rho_hps: np.ndarray,
    implementation: str,
    n_lane: int,
    n_shd: int,
    frame_period_cycles: int,
    egress_symbols_per_beat: int,
    ready_duty: float,
    opq_capacity: int,
    time_merger_credit: float,
    target_hits: int,
) -> list[ScanPoint]:
    mean_batch = np.asarray(burstiness_to_mean_generation_batch_hits(burstiness), dtype=float)
    rho_cycle_lane = rho_hps * float(n_shd) / float(frame_period_cycles)
    total_arrival_rate = np.maximum(0.0, float(n_lane) * rho_cycle_lane)
    generation_rate = total_arrival_rate / np.maximum(mean_batch, 1.0e-12)
    raw_service_rate = ready_duty * service_increment(implementation, n_lane, egress_symbols_per_beat)
    frame_overhead_rate = float(6 + n_shd) / float(frame_period_cycles)
    service_rate = max(0.0, raw_service_rate - frame_overhead_rate)
    capacity = float(implementation_capacity(implementation, n_lane, opq_capacity, time_merger_credit))
    event_interval = np.divide(
        1.0,
        generation_rate,
        out=np.full_like(generation_rate, np.inf),
        where=generation_rate > 0.0,
    )
    target = float(target_hits)
    offered = np.zeros_like(generation_rate)
    dropped = np.zeros_like(generation_rate)
    occupancy = np.zeros_like(generation_rate)
    max_occupancy = np.zeros_like(generation_rate)
    event_count = np.zeros_like(generation_rate, dtype=np.int64)
    active = generation_rate > 0.0
    max_events = int(np.max(np.ceil(target / np.maximum(mean_batch, 1.0e-12))))

    for _ in range(max_events):
        active = active & (offered < target)
        if not np.any(active):
            break
        occupancy = np.where(
            active,
            np.maximum(0.0, occupancy - (service_rate * event_interval)),
            occupancy,
        )
        arrivals = np.where(active, np.minimum(mean_batch, target - offered), 0.0)
        post_arrival = occupancy + arrivals
        overflow = np.maximum(post_arrival - capacity, 0.0)
        occupancy = np.where(active, post_arrival - overflow, occupancy)
        offered += arrivals
        dropped += overflow
        event_count += active.astype(np.int64)
        max_occupancy = np.maximum(max_occupancy, occupancy)

    delivered = offered - dropped
    final_drain_cycles = np.divide(
        occupancy,
        service_rate,
        out=np.full_like(occupancy, np.inf),
        where=service_rate > 0.0,
    )
    loss = np.divide(dropped, np.maximum(offered, 1.0))
    opq_knee = persistent_knee_hps(
        n_lane=n_lane,
        n_shd=n_shd,
        frame_period_cycles=frame_period_cycles,
        service_hit_words_per_cycle=float(egress_symbols_per_beat) * ready_duty,
    )
    model_knee = persistent_knee_hps(
        n_lane=n_lane,
        n_shd=n_shd,
        frame_period_cycles=frame_period_cycles,
        service_hit_words_per_cycle=raw_service_rate,
    )
    tier = "controlled-model-overflow" if implementation == "opq" else "inferred-structural-overflow"

    rows: list[ScanPoint] = []
    for idx in range(burstiness.size):
        rows.append(
            ScanPoint(
                implementation=implementation,
                n_lane=n_lane,
                egress_symbols_per_beat=egress_symbols_per_beat,
                burstiness=float(burstiness[idx]),
                rho_hits_per_subheader_lane=float(rho_hps[idx]),
                rho_hit_words_per_cycle_lane=float(rho_cycle_lane[idx]),
                target_hits=target_hits,
                offered_hits=int(round(float(offered[idx]))),
                delivered_hits_after_drain=int(round(float(delivered[idx]))),
                dropped_hits=int(round(float(dropped[idx]))),
                loss_probability=float(loss[idx]),
                mean_batch_hits=float(mean_batch[idx]),
                generation_events=int(event_count[idx]),
                queue_capacity_hits=int(round(capacity)),
                service_hit_words_per_cycle=float(service_rate),
                max_occupancy_hits=float(max_occupancy[idx]),
                final_drain_cycles=float(final_drain_cycles[idx]),
                opq_persistent_knee_hits_per_subheader_lane=float(opq_knee),
                model_persistent_knee_hits_per_subheader_lane=float(model_knee),
                loss_tier=tier,
            )
        )
    return rows


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--summary", type=Path, default=DEFAULT_SUMMARY)
    parser.add_argument("--target-hits", type=int, default=1_000_000)
    parser.add_argument("--n-lane", type=int, default=MU3E_DEMO_N_LANE)
    parser.add_argument("--n-shd", type=int, default=MU3E_DEMO_N_SHD)
    parser.add_argument("--egress-symbols-per-beat", type=int, default=MU3E_DEMO_EGRESS_SYMBOLS)
    parser.add_argument("--frame-period-cycles", type=int, default=4096)
    parser.add_argument("--ready-duty", type=float, default=1.0)
    parser.add_argument(
        "--opq-capacity",
        type=int,
        default=0,
        help=(
            "Finite OPQ queue capacity for this LT event queue. Default 0 "
            "uses --opq-lane-fifo-depth from the Mu3e Demo profile."
        ),
    )
    parser.add_argument("--opq-lane-fifo-depth", type=int, default=MU3E_DEMO_LANE_FIFO_DEPTH)
    parser.add_argument("--opq-ticket-fifo-depth", type=int, default=MU3E_DEMO_TICKET_FIFO_DEPTH)
    parser.add_argument("--opq-handle-fifo-depth", type=int, default=MU3E_DEMO_HANDLE_FIFO_DEPTH)
    parser.add_argument("--opq-page-ram-depth", type=int, default=MU3E_DEMO_PAGE_RAM_DEPTH)
    parser.add_argument("--time-merger-credit", type=float, default=96.0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.opq_capacity <= 0:
        args.opq_capacity = args.opq_lane_fifo_depth
    burstiness = np.array([b / 1000.0 for b in BURSTINESS_MILLI for _ in RHO_HITS_PER_SUBHEADER], dtype=float)
    rho_hps = np.array(RHO_HITS_PER_SUBHEADER * len(BURSTINESS_MILLI), dtype=float)

    rows = []
    for implementation in ("opq", "time_merger"):
        rows.extend(
            run_event_queue(
                burstiness=burstiness,
                rho_hps=rho_hps,
                implementation=implementation,
                n_lane=args.n_lane,
                n_shd=args.n_shd,
                frame_period_cycles=args.frame_period_cycles,
                egress_symbols_per_beat=args.egress_symbols_per_beat,
                ready_duty=args.ready_duty,
                opq_capacity=args.opq_capacity,
                time_merger_credit=args.time_merger_credit,
                target_hits=args.target_hits,
            )
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(asdict(rows[0]).keys()))
        writer.writeheader()
        for row in rows:
            writer.writerow(asdict(row))

    by_impl = {}
    for implementation in ("opq", "time_merger"):
        impl_rows = [row for row in rows if row.implementation == implementation]
        by_impl[implementation] = {
            "points": len(impl_rows),
            "target_hits_per_point": args.target_hits,
            "total_offered_hits": sum(row.offered_hits for row in impl_rows),
            "total_dropped_hits": sum(row.dropped_hits for row in impl_rows),
            "min_loss": min(row.loss_probability for row in impl_rows),
            "max_loss": max(row.loss_probability for row in impl_rows),
            "persistent_knee_hits_per_subheader_lane": impl_rows[0].model_persistent_knee_hits_per_subheader_lane,
        }
    summary = {
        "model": "level-3 high-performance collective LT event-queue scan",
        "points_per_implementation": len(BURSTINESS_MILLI) * len(RHO_HITS_PER_SUBHEADER),
        "burstiness_definition": "B=(CV_timestamp-1)/(CV_timestamp+1), matching Goh-Barabasi",
        "rate_unit": "rho_hits_per_subheader_lane, converted to hit words/cycle/lane by rho*N_SHD/frame_period",
        "n_lane": args.n_lane,
        "n_shd": args.n_shd,
        "egress_symbols_per_beat": args.egress_symbols_per_beat,
        "frame_period_cycles": args.frame_period_cycles,
        "ready_duty": args.ready_duty,
        "opq_capacity": args.opq_capacity,
        "opq_profile": {
            "preset": MU3E_DEMO_PROFILE_NAME,
            "n_lane": args.n_lane,
            "n_shd": args.n_shd,
            "egress_symbols_per_beat": args.egress_symbols_per_beat,
            "lane_fifo_depth": args.opq_lane_fifo_depth,
            "ticket_fifo_depth": args.opq_ticket_fifo_depth,
            "handle_fifo_depth": args.opq_handle_fifo_depth,
            "page_ram_depth": args.opq_page_ram_depth,
            "event_queue_capacity_hits": args.opq_capacity,
        },
        "time_merger_penalty": time_merger_penalty(args.n_lane),
        "implementations": by_impl,
        "csv": str(args.output),
    }
    args.summary.write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
    print(f"Wrote {args.output}")
    print(f"Wrote {args.summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
