#!/usr/bin/env python3
"""Run OPQ component-replay RTL cases and reduce each one against the TLM.

This is the long component-standalone gate for RTL-shaped TLM calibration.
Every case enables native boundary trace and OPQ_TXN trace so the reducer can
check ingress ticket/lane-FIFO behavior, controlled drop classification,
allocator/handle FIFO behavior, frame-table accounting, and delivered
transaction bucket identity.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from opq_component_replay import run_one, write_csv  # noqa: E402
from run_model_publish_rtl_sweep import (  # noqa: E402
    RtlCase,
    burstiness_cluster_mix,
    run_case,
)


DEFAULT_RUN_ROOT = Path("model/rtl_sim/runs/component_replay_100k_20260429")
DEFAULT_BUILD_ROOT = Path("model/rtl_sim/build_runs_component_replay_100k")
DEFAULT_CSV = Path("model/rtl_sim/data/opq_component_replay_100k.csv")
DEFAULT_JSON = Path("model/rtl_sim/data/opq_component_replay_100k_summary.json")

POINTS: dict[str, tuple[int, int]] = {
    "b000_rho0750": (0, 750_000),
    "b000_rho0800": (0, 800_000),
    "b403_rho0750": (403, 750_000),
    "b700_rho0700": (700, 700_000),
}
POINT_RE = re.compile(r"^b(?P<b>-?\d+)_rho(?P<rho>\d+)$")


def parse_seed(text: str) -> int:
    return int(text, 0)


def parse_csv(text: str) -> list[str]:
    return [item.strip() for item in text.split(",") if item.strip()]


def frame_count_for_target(target_hits: int, n_lane: int, n_shd: int, rho_ppm: int) -> int:
    denom = max(1, n_lane * n_shd * rho_ppm)
    return max(4, math.ceil((target_hits * 1_000_000) / denom))


def make_case(point_name: str, burstiness_milli: int, rho_ppm: int, seed: int, target_hits: int) -> RtlCase:
    noise_rho_ppm, cluster_rho_ppm, cluster_min, cluster_max = burstiness_cluster_mix(
        burstiness_milli,
        rho_ppm,
    )
    frame_count = frame_count_for_target(target_hits, 4, 128, rho_ppm)
    seed_tag = f"{seed & 0xFFFF:04x}"
    return RtlCase(
        tag=f"component_{point_name}_f{frame_count:04d}_seed{seed_tag}",
        case_id="RTL-LS-002",
        n_lane=4,
        n_shd=128,
        egress_symbols_per_beat=1,
        rho_ppm=rho_ppm,
        burstiness_milli=burstiness_milli,
        profile=3,
        frame_count=frame_count,
        subheaders=128,
        inter_frame_gap_cycles=0,
        hit_period=1,
        hit_count=1,
        dwell_us=max(5000, min(45000, 3000 + (frame_count * 10))),
        require_drain=1,
        drain_timeout_us=max(8000, min(60000, 3000 + (frame_count * 20))),
        noise_rho_ppm=noise_rho_ppm,
        cluster_rho_ppm=cluster_rho_ppm,
        cluster_size_min=cluster_min,
        cluster_size_max=cluster_max,
        rng_seed=seed,
    )


def build_cases(args: argparse.Namespace) -> list[RtlCase]:
    point_names = parse_csv(args.points)
    seeds = [parse_seed(item) for item in parse_csv(args.seeds)]
    cases: list[RtlCase] = []
    for point_name in point_names:
        if point_name in POINTS:
            burstiness_milli, rho_ppm = POINTS[point_name]
        else:
            match = POINT_RE.match(point_name)
            if match is None:
                raise SystemExit(
                    f"unknown point {point_name!r}; expected one of {sorted(POINTS)} "
                    "or b<milli>_rho<permille>, for example b500_rho0254"
                )
            burstiness_milli = int(match.group("b"))
            rho_ppm = int(match.group("rho")) * 1000
        for seed in seeds:
            cases.append(make_case(point_name, burstiness_milli, rho_ppm, seed, args.target_hits))
    if args.max_runs > 0:
        cases = cases[: args.max_runs]
    return cases


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-hits", type=int, default=100_000)
    parser.add_argument(
        "--points",
        default="b000_rho0750,b000_rho0800,b403_rho0750,b700_rho0700",
        help="comma-separated point names",
    )
    parser.add_argument(
        "--seeds",
        default="0x5c1f7101,0x5c1f7102,0x5c1f7103",
        help="comma-separated integer seeds",
    )
    parser.add_argument("--run-root", type=Path, default=DEFAULT_RUN_ROOT)
    parser.add_argument("--build-root", type=Path, default=DEFAULT_BUILD_ROOT)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON)
    parser.add_argument("--threshold", type=float, default=0.01)
    parser.add_argument("--timeout-sec", type=int, default=14_400)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-runs", type=int, default=0)
    parser.add_argument("--disable-tb-sva", action="store_true")
    parser.add_argument(
        "--calibrated-only",
        action="store_true",
        help="write only the parser-ticket component closure rows to CSV",
    )
    args = parser.parse_args()

    cases = build_cases(args)
    for case in cases:
        print(
            "[CASE] {tag} seed=0x{seed:08x} frames={frames} rho_ppm={rho} "
            "B_milli={b} target_hits={target}".format(
                tag=case.tag,
                seed=case.rng_seed,
                frames=case.frame_count,
                rho=case.rho_ppm,
                b=case.burstiness_milli,
                target=args.target_hits,
            )
        )
    if args.dry_run:
        return 0

    args.run_root = args.run_root.resolve()
    args.build_root = args.build_root.resolve()
    args.csv = args.csv.resolve()
    args.json = args.json.resolve()
    args.run_root.mkdir(parents=True, exist_ok=True)
    args.build_root.mkdir(parents=True, exist_ok=True)
    all_rows: list[dict[str, object]] = []
    summaries: list[dict[str, object]] = []

    for case in cases:
        log_path = args.run_root / "logs" / f"{case.tag}.log"
        if args.resume and log_path.exists() and "MODEL_PUBLISH_AGG" in log_path.read_text(errors="replace"):
            print(f"[RESUME] using existing {log_path}")
        else:
            log_path = run_case(
                case,
                args.run_root,
                args.build_root,
                False,
                False,
                True,
                0,
                ["+OPQ_NATIVE_TRACE_INGRESS_CREDIT", "+OPQ_TRACE_TXN"],
                args.timeout_sec,
                args.disable_tb_sva,
            )

        stdout_log = args.run_root / "stdout" / f"{case.tag}.stdout.log"
        replay_log = stdout_log if stdout_log.exists() else log_path
        rows, summary = run_one(case.tag, replay_log, args.threshold)
        if args.calibrated_only:
            rows = [
                row for row in rows
                if str(row["component"]).endswith("_parser_ticket_stream")
                and row["status"] != "NOT_CHECKED"
            ]
        all_rows.extend(rows)
        summaries.append(summary)
        write_csv(args.csv, all_rows)
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(summaries, indent=2) + "\n", encoding="ascii")
        debug_rows = [row for row in rows if row["status"] in {"DEBUG", "NOT_CHECKED"}]
        print(f"[REPLAY] {case.tag}: rows={len(rows)} debug_or_not_checked={len(debug_rows)}")

    print(f"[DONE] wrote {args.csv}")
    print(f"[DONE] wrote {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
