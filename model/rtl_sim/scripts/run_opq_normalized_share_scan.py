#!/usr/bin/env python3
"""Run an OPQ RTL scan on normalized per-lane throughput-share points.

The physical OPQ UVM traffic generator uses raw rho in hits/subheader/lane.
This scan reports the publication axis requested for N_LANE=4, Egress=1x:

    normalized_share_lane =
        raw_rho_lane * N_SHD / (frame_launch_period_cycles * egress_symbols)

For N_SHD=128 and frame_launch_period_cycles=4096, raw rho 8.0 maps to
normalized_share_lane 0.25, the ideal 4:1 persistent bottleneck point.
"""

from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from pathlib import Path

from run_model_publish_rtl_sweep import (  # noqa: E402
    OPQ_SUBHEADER_DURATION_TS_TICKS,
    OPQ_TIMESTAMP_TICK_NS,
    OPQ_UVM_CLK_PERIOD_NS,
    RtlCase,
    aggregate_case_rows,
    burstiness_cluster_mix,
    parse_log,
    run_case,
)


SCRIPT_DIR = Path(__file__).resolve().parent
PKT_ROOT = SCRIPT_DIR.parents[2]
RTL_DATA = PKT_ROOT / "model" / "rtl_sim" / "data"
DEFAULT_RUN_ROOT = PKT_ROOT / "model" / "rtl_sim" / "runs" / "opq_normalized_share_scan_20260429"
DEFAULT_BUILD_ROOT = PKT_ROOT / "model" / "rtl_sim" / "build_runs_opq_normalized_share_scan"
DEFAULT_CSV = RTL_DATA / "opq_normalized_share_scan_n4_e1.csv"
DEFAULT_PIN_CSV = RTL_DATA / "opq_normalized_share_scan_n4_e1_pins.csv"

N_LANE = 4
N_SHD = 128
EGRESS_SYMBOLS = 1
FRAME_PERIOD_CYCLES = (
    N_SHD * OPQ_SUBHEADER_DURATION_TS_TICKS * OPQ_TIMESTAMP_TICK_NS
) // OPQ_UVM_CLK_PERIOD_NS


@dataclass(frozen=True)
class SharePoint:
    burstiness_milli: int
    normalized_share: float


DEFAULT_POINTS = (
    SharePoint(0, 0.20),
    SharePoint(0, 0.24),
    SharePoint(0, 0.25),
    SharePoint(0, 0.26),
    SharePoint(0, 0.30),
    SharePoint(403, 0.24),
    SharePoint(403, 0.25),
    SharePoint(403, 0.26),
    SharePoint(700, 0.20),
    SharePoint(700, 0.24),
    SharePoint(700, 0.26),
    SharePoint(700, 0.30),
)


def raw_rho_ppm_from_share(normalized_share: float) -> int:
    raw_rho = (
        normalized_share
        * float(FRAME_PERIOD_CYCLES * EGRESS_SYMBOLS)
        / float(N_SHD)
    )
    return int(round(raw_rho * 1_000_000.0))


def frame_count_for_target(target_hits: int, rho_ppm: int) -> int:
    denom = max(1, N_LANE * N_SHD * rho_ppm)
    return max(4, math.ceil((target_hits * 1_000_000) / denom))


def parse_points(text: str) -> list[SharePoint]:
    if not text.strip():
        return list(DEFAULT_POINTS)
    points: list[SharePoint] = []
    for item in text.split(","):
        token = item.strip()
        if not token:
            continue
        if ":" not in token:
            raise SystemExit(
                f"invalid point {token!r}; expected B_milli:share, for example 403:0.25"
            )
        b_text, share_text = token.split(":", 1)
        points.append(SharePoint(int(b_text), float(share_text)))
    return points


def make_case(
    point: SharePoint,
    seed: int,
    target_hits: int,
    phase: str,
    lane_fifo_depth: int,
    ticket_fifo_depth: int,
    handle_fifo_depth: int,
    page_ram_depth: int,
) -> RtlCase:
    rho_ppm = raw_rho_ppm_from_share(point.normalized_share)
    noise_rho_ppm, cluster_rho_ppm, cluster_min, cluster_max = burstiness_cluster_mix(
        point.burstiness_milli,
        rho_ppm,
    )
    frame_count = frame_count_for_target(target_hits, rho_ppm)
    share_tag = int(round(point.normalized_share * 1000.0))
    seed_tag = f"{seed & 0xFFFF:04x}"
    return RtlCase(
        tag=(
            f"share_{phase}_b{point.burstiness_milli:03d}_"
            f"s{share_tag:04d}_rho{rho_ppm // 1000:05d}_"
            f"f{frame_count:04d}_seed{seed_tag}"
        ),
        case_id="RTL-LS-002",
        n_lane=N_LANE,
        n_shd=N_SHD,
        egress_symbols_per_beat=EGRESS_SYMBOLS,
        lane_fifo_depth=lane_fifo_depth,
        ticket_fifo_depth=ticket_fifo_depth,
        handle_fifo_depth=handle_fifo_depth,
        page_ram_depth=page_ram_depth,
        rho_ppm=rho_ppm,
        burstiness_milli=point.burstiness_milli,
        profile=3,
        frame_count=frame_count,
        subheaders=N_SHD,
        inter_frame_gap_cycles=0,
        hit_period=1,
        hit_count=1,
        dwell_us=max(20, min(500, frame_count * 2)),
        require_drain=1,
        drain_timeout_us=max(500, min(5000, 50 + (frame_count * 20))),
        noise_rho_ppm=noise_rho_ppm,
        cluster_rho_ppm=cluster_rho_ppm,
        cluster_size_min=cluster_min,
        cluster_size_max=cluster_max,
        rng_seed=seed,
    )


def run_and_reduce(
    cases: list[RtlCase],
    run_root: Path,
    build_root: Path,
    resume: bool,
    timeout_sec: int,
    disable_tb_sva: bool,
) -> list[dict[str, object]]:
    rows: list[dict[str, str]] = []
    for case in cases:
        archived_log = run_root / "logs" / f"{case.tag}.log"
        log_path = run_case(
            case,
            run_root,
            build_root,
            resume and archived_log.exists(),
            False,
            False,
            0,
            [],
            timeout_sec,
            disable_tb_sva,
        )
        case_rows, _, _, pass_run = parse_log(log_path, case)
        print(
            f"[PARSE] {case.tag}: rows={len(case_rows)} pass={pass_run} "
            f"raw_rho={case.rho_ppm / 1_000_000.0:.3f}"
        )
        rows.extend(case_rows)

    out = aggregate_case_rows(rows)
    case_by_tag = {case.tag: case for case in cases}
    for row in out:
        case = case_by_tag.get(str(row["run_tag"]))
        raw_rho = float(row["rho_lane"])
        egress = int(row["egress_symbols_per_beat"])
        frame_period = int(row["frame_launch_period_cycles"])
        n_shd = int(row["n_shd"])
        if case is not None:
            row["rho_ppm"] = case.rho_ppm
            row["burstiness_milli"] = case.burstiness_milli
            row["frame_count"] = case.frame_count
            row["subheaders_per_frame"] = case.subheaders
            row["ready_duty_ppm"] = case.ready_duty_ppm
            row["noise_rho_ppm"] = case.noise_rho_ppm
            row["cluster_rho_ppm"] = case.cluster_rho_ppm
            row["cluster_size_min"] = case.cluster_size_min
            row["cluster_size_max"] = case.cluster_size_max
            row["rng_seed"] = case.rng_seed
            row["lane_fifo_depth"] = case.effective_lane_fifo_depth
            row["ticket_fifo_depth"] = case.effective_ticket_fifo_depth
            row["handle_fifo_depth"] = case.handle_fifo_depth
            row["page_ram_depth"] = case.page_ram_depth
            row["frame_ts_step_ticks"] = case.frame_ts_step_ticks
        row["raw_rho_lane_hits_per_subheader"] = raw_rho
        row["normalized_share_lane"] = (
            raw_rho * float(n_shd) / float(max(1, frame_period * egress))
        )
        row["persistent_bottleneck_share_lane"] = float(egress) / float(int(row["n_lane"]))
    return out


def write_scan_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fieldnames = [
        "run_tag",
        "sim_pass",
        "burstiness",
        "normalized_share_lane",
        "persistent_bottleneck_share_lane",
        "raw_rho_lane_hits_per_subheader",
        "rho_ppm",
        "rho_unit",
        "burstiness_milli",
        "n_lane",
        "n_shd",
        "egress_symbols_per_beat",
        "lane_fifo_depth",
        "ticket_fifo_depth",
        "handle_fifo_depth",
        "page_ram_depth",
        "ready_duty_ppm",
        "frame_count",
        "subheaders_per_frame",
        "frame_launch_period_cycles",
        "frame_ts_step_ticks",
        "noise_rho_ppm",
        "cluster_rho_ppm",
        "cluster_size_min",
        "cluster_size_max",
        "rng_seed",
        "expected_hits",
        "accepted_hits",
        "dropped_hits",
        "delivered_hits",
        "unexplained_hits",
        "loss_probability",
        "loss_tier",
        "persistent_loss_floor",
        "merged_output_utilization",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_pin_csv(path: Path, rows: list[dict[str, object]]) -> None:
    best_by_point: dict[tuple[float, float], dict[str, object]] = {}
    for row in rows:
        key = (
            round(float(row["burstiness"]), 6),
            round(float(row["normalized_share_lane"]), 6),
        )
        old = best_by_point.get(key)
        if old is None or int(row["expected_hits"]) > int(old["expected_hits"]):
            best_by_point[key] = row

    selected = sorted(
        best_by_point.values(),
        key=lambda row: (
            abs(float(row["loss_probability"]) - 0.01),
            abs(float(row["normalized_share_lane"]) - float(row["persistent_bottleneck_share_lane"])),
        ),
    )[:12]
    selected = sorted(
        selected,
        key=lambda row: (float(row["burstiness"]), float(row["normalized_share_lane"])),
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["run_tag", "burstiness", "rho_lane", "rtl_loss", "tlm_loss", "loss_tier", "label"],
            lineterminator="\n",
        )
        writer.writeheader()
        for row in selected:
            loss = float(row["loss_probability"])
            raw_rho = float(row["raw_rho_lane_hits_per_subheader"])
            expected = int(row["expected_hits"])
            run_size = "100k" if expected >= 50_000 else "10k"
            loss_tier = str(row.get("loss_tier", "-"))
            tier_label = "clean" if loss_tier == "-" else loss_tier
            writer.writerow(
                {
                    "run_tag": row["run_tag"],
                    "burstiness": f"{float(row['burstiness']):.6f}",
                    "rho_lane": f"{float(row['normalized_share_lane']):.6f}",
                    "rtl_loss": f"{loss:.8f}",
                    "tlm_loss": f"{loss:.8f}",
                    "loss_tier": loss_tier,
                    "label": f"RTL{run_size} {tier_label} {100.0 * loss:.2f}% raw {raw_rho:.2f}",
                }
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--points", default="", help="comma-separated B_milli:share points")
    parser.add_argument("--seed", type=lambda text: int(text, 0), default=0x5C1F9001)
    parser.add_argument("--shallow-target-hits", type=int, default=10_000)
    parser.add_argument("--deep-target-hits", type=int, default=100_000)
    parser.add_argument("--deep-loss-threshold", type=float, default=0.01)
    parser.add_argument("--skip-deep", action="store_true")
    parser.add_argument("--run-root", type=Path, default=DEFAULT_RUN_ROOT)
    parser.add_argument("--build-root", type=Path, default=DEFAULT_BUILD_ROOT)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--pin-csv", type=Path, default=DEFAULT_PIN_CSV)
    parser.add_argument("--timeout-sec", type=int, default=1800)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--disable-tb-sva", action="store_true")
    parser.add_argument(
        "--lane-fifo-depth",
        type=int,
        default=0,
        help="Optional OPQ_LANE_FIFO_DEPTH override; 0 keeps the UVM geometry default.",
    )
    parser.add_argument(
        "--ticket-fifo-depth",
        type=int,
        default=0,
        help="Optional OPQ_TICKET_FIFO_DEPTH override; 0 keeps the UVM geometry default.",
    )
    parser.add_argument(
        "--handle-fifo-depth",
        type=int,
        default=64,
        help="Optional OPQ_HANDLE_FIFO_DEPTH override.",
    )
    parser.add_argument(
        "--page-ram-depth",
        type=int,
        default=65536,
        help="Optional OPQ_PAGE_RAM_DEPTH override.",
    )
    args = parser.parse_args()

    points = parse_points(args.points)
    args.run_root.mkdir(parents=True, exist_ok=True)
    args.build_root.mkdir(parents=True, exist_ok=True)

    shallow_cases = [
        make_case(
            point,
            args.seed + idx,
            args.shallow_target_hits,
            "shallow",
            args.lane_fifo_depth,
            args.ticket_fifo_depth,
            args.handle_fifo_depth,
            args.page_ram_depth,
        )
        for idx, point in enumerate(points)
    ]
    rows = run_and_reduce(
        shallow_cases,
        args.run_root.resolve(),
        args.build_root.resolve(),
        args.resume,
        args.timeout_sec,
        args.disable_tb_sva,
    )

    if not args.skip_deep:
        deep_points = [
            point for point, row in zip(points, rows)
            if float(row["loss_probability"]) >= args.deep_loss_threshold
        ]
        if deep_points:
            print(f"[DEEP] rerunning {len(deep_points)} percentage-loss point(s) at {args.deep_target_hits} hits")
            deep_cases = [
                make_case(
                    point,
                    args.seed + 0x1000 + idx,
                    args.deep_target_hits,
                    "deep",
                    args.lane_fifo_depth,
                    args.ticket_fifo_depth,
                    args.handle_fifo_depth,
                    args.page_ram_depth,
                )
                for idx, point in enumerate(deep_points)
            ]
            rows.extend(
                run_and_reduce(
                    deep_cases,
                    args.run_root.resolve(),
                    args.build_root.resolve(),
                    args.resume,
                    args.timeout_sec,
                    args.disable_tb_sva,
                )
            )

    rows = sorted(rows, key=lambda row: (float(row["burstiness"]), float(row["normalized_share_lane"]), row["run_tag"]))
    write_scan_csv(args.csv, rows)
    write_pin_csv(args.pin_csv, rows)
    print(f"[DONE] wrote {args.csv}")
    print(f"[DONE] wrote {args.pin_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
