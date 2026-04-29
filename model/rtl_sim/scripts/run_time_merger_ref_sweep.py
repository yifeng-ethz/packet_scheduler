#!/usr/bin/env python3
"""Run old time-merger reference loss probes and reduce OLD_TM_LOSS_RESULT."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
TB_OLD = REPO_ROOT / "packet_scheduler" / "tb_old_reference"
MODEL_ROOT = REPO_ROOT / "packet_scheduler" / "model"
RTL_ROOT = MODEL_ROOT / "rtl_sim"
RESULT_RE = re.compile(r"OLD_TM_LOSS_RESULT\s+(?P<blob>.*)")
DEBUG_RE = re.compile(r"OLD_TM_DEBUG_RESULT\s+(?P<blob>.*)")


@dataclass(frozen=True)
class TimeMergerCase:
    tag: str
    n_lane: int
    rho_ppm: int
    burstiness_milli: int = 0
    frame_count: int = 64
    subheaders: int = 128
    hits_per_subheader: int = 1
    queue_depth_words: int = 1024
    stage_fifo_depth: int = 128
    ready_high: int = 1
    ready_low: int = 0
    drain_cycles: int = 32768


def key_value_blob(blob: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for token in blob.strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = value.rstrip(",")
    return fields


def boundary_cases() -> list[TimeMergerCase]:
    cases: list[TimeMergerCase] = []
    rho_by_lane = {
        4: [100_000, 150_000, 180_000, 190_000, 200_000, 220_000, 250_000, 300_000, 600_000, 1_000_000],
        8: [50_000, 80_000, 100_000, 110_000, 120_000, 150_000, 200_000, 300_000],
    }
    for n_lane, rho_values in rho_by_lane.items():
        for rho_ppm in rho_values:
            cases.append(
                TimeMergerCase(
                    tag=f"tm_n{n_lane}_rho{rho_ppm // 1000:04d}_q1024_s128",
                    n_lane=n_lane,
                    rho_ppm=rho_ppm,
                )
            )
    return cases


def run_case(case: TimeMergerCase, run_root: Path, no_run: bool) -> Path:
    run_root.mkdir(parents=True, exist_ok=True)
    log_path = run_root / f"{case.tag}.log"
    build_dir = run_root / f"build_{case.tag}"
    if no_run:
        if not log_path.exists():
            raise FileNotFoundError(f"missing log for {case.tag}: {log_path}")
        return log_path

    plusargs = [
        f"+OLD_TM_FRAME_COUNT={case.frame_count}",
        f"+OLD_TM_SUBHEADERS={case.subheaders}",
        f"+OLD_TM_HITS_PER_SUBHEADER={case.hits_per_subheader}",
        f"+OLD_TM_QUEUE_DEPTH={case.queue_depth_words}",
        f"+OLD_TM_READY_HIGH={case.ready_high}",
        f"+OLD_TM_READY_LOW={case.ready_low}",
        f"+OLD_TM_BURSTINESS_MILLI={case.burstiness_milli}",
        f"+OLD_TM_RHO_PPM={case.rho_ppm}",
        f"+OLD_TM_DRAIN_CYCLES={case.drain_cycles}",
    ]
    cmd = [
        "make",
        "-C",
        str(TB_OLD),
        "loss",
        f"BUILD_DIR={build_dir}",
        f"OLD_TM_LANE_COUNT={case.n_lane}",
        f"OLD_TM_STAGE_FIFO_DEPTH={case.stage_fifo_depth}",
        f"VSIM_PLUSARGS={' '.join(plusargs)}",
    ]
    with log_path.open("w") as log:
        completed = subprocess.run(
            cmd,
            cwd=REPO_ROOT,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
    if completed.returncode != 0:
        print(f"[WARN] {case.tag}: make loss returned {completed.returncode}; keeping log")
    else:
        print(f"[PASS] {case.tag}: {log_path}")
    return log_path


def parse_log(log_path: Path, case: TimeMergerCase) -> dict[str, object]:
    text = log_path.read_text(errors="replace")
    match = RESULT_RE.search(text)
    if not match:
        raise RuntimeError(f"{case.tag}: missing OLD_TM_LOSS_RESULT in {log_path}")
    fields = key_value_blob(match.group("blob"))
    debug_match = DEBUG_RE.search(text)
    debug_fields = key_value_blob(debug_match.group("blob")) if debug_match else {}
    offered = int(fields.get("offered_hit_count", "0"))
    delivered = int(fields.get("delivered_hit_count", "0"))
    dropped = int(fields.get("dropped_hit_count", "0"))
    controlled_source_loss = dropped
    inferred_missing = max(0, offered - delivered - controlled_source_loss)
    end_to_end_missing = max(0, offered - delivered)
    loss_probability = float(fields.get("loss_probability", "0"))
    total_inferred_loss = (offered - delivered) / offered if offered else 0.0
    n_lane = int(fields.get("n_lane", str(case.n_lane)))
    subheaders = int(fields.get("subheaders", str(case.subheaders)))
    hits_per_subheader = int(fields.get("hits_per_subheader", str(case.hits_per_subheader)))
    merged_overhead_words = 6 + subheaders
    merged_hit_words = n_lane * subheaders * hits_per_subheader
    merged_words_per_frame = merged_overhead_words + merged_hit_words
    persistent_knee = (
        (subheaders * hits_per_subheader) / float(merged_words_per_frame)
        if merged_words_per_frame > 0
        else 0.0
    )
    rho = int(fields.get("rho_ppm", str(case.rho_ppm))) / 1_000_000.0
    source_hit_utilization = float(debug_fields.get("source_hit_utilization", rho))
    source_word_utilization = float(debug_fields.get("source_word_utilization", "0"))
    merged_output_utilization = float(debug_fields.get("merged_output_utilization", "0"))
    hits_per_subheader_per_lane = float(debug_fields.get("hits_per_subheader_per_lane", hits_per_subheader))
    queue_depth_words = int(fields.get("queue_depth_words", str(case.queue_depth_words)))
    max_source_queue_words = int(debug_fields.get("max_source_queue_words", "0"))
    fifo_full_stall_cycles = int(debug_fields.get("debug_fifo_full_stall_cycles", "0"))
    node_blocked_cycles = int(debug_fields.get("debug_node_blocked_cycles", "0"))
    role_mismatch_cycles = int(debug_fields.get("debug_role_mismatch_cycles", "0"))
    join_wait_cycles = int(debug_fields.get("debug_join_wait_cycles", "0"))
    if controlled_source_loss:
        loss_tier = "mixed" if inferred_missing else "controlled"
    else:
        loss_tier = "inferred" if inferred_missing else "-"
    if controlled_source_loss and merged_output_utilization > 1.0:
        root_cause = "persistent_output_overload"
    elif controlled_source_loss and queue_depth_words and max_source_queue_words >= int(0.9 * queue_depth_words):
        root_cause = "finite_source_queue_backpressure"
    elif controlled_source_loss and (fifo_full_stall_cycles or node_blocked_cycles or role_mismatch_cycles):
        root_cause = "source_backpressure_from_merger_tree"
    elif role_mismatch_cycles:
        root_cause = "role_mismatch_hol"
    elif fifo_full_stall_cycles:
        root_cause = "stage_fifo_full"
    else:
        root_cause = "no_loss_observed" if end_to_end_missing == 0 else "unlocalized"
    row: dict[str, object] = {
        "run_tag": case.tag,
        "sim_pass": "1" if "** Fatal:" not in text and "Errors: 0" in text else "0",
        "loss_tier": loss_tier,
        "root_cause": root_cause,
        "implementation": fields.get("implementation", "time_merger"),
        "n_lane": n_lane,
        "egress_symbols_per_beat": int(fields.get("egress_symbols_per_beat", "1")),
        "burstiness_milli": int(fields.get("burstiness_milli", str(case.burstiness_milli))),
        "rho_ppm": int(fields.get("rho_ppm", str(case.rho_ppm))),
        "rho": rho,
        "rho_unit": "hit_words_per_cycle_per_lane",
        "link_utilization": source_hit_utilization,
        "source_word_utilization": source_word_utilization,
        "merged_output_utilization": merged_output_utilization,
        "hits_per_subheader_per_lane": hits_per_subheader_per_lane,
        "persistent_knee_rho": persistent_knee,
        "above_persistent_knee": "1" if rho > persistent_knee else "0",
        "persistent_loss_floor": max(0.0, (rho - persistent_knee) / rho) if rho > 0.0 else 0.0,
        "opq_80pct_lossless_target_rho": 0.8 * persistent_knee,
        "ready_high": int(fields.get("ready_high", str(case.ready_high))),
        "ready_low": int(fields.get("ready_low", str(case.ready_low))),
        "frame_gap_cycles": int(debug_fields.get("frame_gap_cycles", "0")),
        "frame_count": int(fields.get("frame_count", str(case.frame_count))),
        "subheaders": subheaders,
        "hits_per_subheader": hits_per_subheader,
        "queue_depth_words": queue_depth_words,
        "stage_fifo_depth": int(fields.get("stage_fifo_depth", str(case.stage_fifo_depth))),
        "offered_hit_count": offered,
        "accepted_hit_count": int(fields.get("accepted_hit_count", "0")),
        "source_queue_drop_hit_count": dropped,
        "delivered_hit_count": delivered,
        "controlled_loss_hit_count": controlled_source_loss,
        "asserted_loss_hit_count": 0,
        "end_to_end_missing_hit_count": end_to_end_missing,
        "source_drop_loss_probability": loss_probability,
        "inferred_missing_hit_count": inferred_missing,
        "total_inferred_loss_probability": total_inferred_loss,
        "asserted_join_wait_cycles": join_wait_cycles,
        "asserted_role_mismatch_cycles": role_mismatch_cycles,
        "asserted_node_blocked_cycles": node_blocked_cycles,
        "asserted_fifo_full_stall_cycles": fifo_full_stall_cycles,
        "asserted_fifo_max_occupancy": int(debug_fields.get("debug_fifo_max_occupancy", "0")),
        "source_dropped_frame_count": int(debug_fields.get("source_dropped_frame_count", "0")),
        "max_source_queue_words": max_source_queue_words,
        "log": str(log_path),
    }
    return row


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "run_tag",
        "sim_pass",
        "loss_tier",
        "root_cause",
        "implementation",
        "n_lane",
        "egress_symbols_per_beat",
        "burstiness_milli",
        "rho_ppm",
        "rho",
        "rho_unit",
        "link_utilization",
        "source_word_utilization",
        "merged_output_utilization",
        "hits_per_subheader_per_lane",
        "persistent_knee_rho",
        "above_persistent_knee",
        "persistent_loss_floor",
        "opq_80pct_lossless_target_rho",
        "ready_high",
        "ready_low",
        "frame_gap_cycles",
        "frame_count",
        "subheaders",
        "hits_per_subheader",
        "queue_depth_words",
        "stage_fifo_depth",
        "offered_hit_count",
        "accepted_hit_count",
        "source_queue_drop_hit_count",
        "delivered_hit_count",
        "controlled_loss_hit_count",
        "asserted_loss_hit_count",
        "end_to_end_missing_hit_count",
        "source_drop_loss_probability",
        "inferred_missing_hit_count",
        "total_inferred_loss_probability",
        "asserted_join_wait_cycles",
        "asserted_role_mismatch_cycles",
        "asserted_node_blocked_cycles",
        "asserted_fifo_full_stall_cycles",
        "asserted_fifo_max_occupancy",
        "source_dropped_frame_count",
        "max_source_queue_words",
        "log",
    ]
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", choices=["boundary"], default="boundary")
    parser.add_argument("--max-cases", type=int, default=0)
    parser.add_argument("--no-run", action="store_true")
    args = parser.parse_args()

    cases = boundary_cases()
    if args.max_cases > 0:
        cases = cases[: args.max_cases]

    run_root = RTL_ROOT / "runs" / "time_merger_ref_sweep"
    rows: list[dict[str, object]] = []
    for case in cases:
        log_path = run_case(case, run_root, args.no_run)
        row = parse_log(log_path, case)
        print(
            "[PARSE] {tag}: n={n_lane} rho={rho} offered={offered} "
            "delivered={delivered} source_drop={dropped} inferred_missing={missing} "
            "util={util:.6g} out_util={out_util:.6g} root={root} total_loss={loss:.6g}".format(
                tag=case.tag,
                n_lane=row["n_lane"],
                rho=row["rho_ppm"],
                offered=row["offered_hit_count"],
                delivered=row["delivered_hit_count"],
                dropped=row["source_queue_drop_hit_count"],
                missing=row["inferred_missing_hit_count"],
                util=row["link_utilization"],
                out_util=row["merged_output_utilization"],
                root=row["root_cause"],
                loss=row["total_inferred_loss_probability"],
            )
        )
        rows.append(row)

    out_path = RTL_ROOT / "data" / "time_merger_ref_loss_sweep.csv"
    write_csv(out_path, rows)
    print(f"[DONE] wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
