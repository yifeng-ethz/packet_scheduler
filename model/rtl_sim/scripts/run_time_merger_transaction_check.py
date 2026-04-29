#!/usr/bin/env python3
"""Run directed time-merger RTL traces and compare against structural TLM IDs."""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
TB_OLD = REPO_ROOT / "packet_scheduler" / "tb_old_reference"
MODEL_ROOT = REPO_ROOT / "packet_scheduler" / "model"
RTL_ROOT = MODEL_ROOT / "rtl_sim"
TXN_RE = re.compile(r"OLD_TM_TXN\s+(?P<blob>.*)")
RESULT_RE = re.compile(r"OLD_TM_LOSS_RESULT\s+(?P<blob>.*)")
DEBUG_RE = re.compile(r"OLD_TM_DEBUG_RESULT\s+(?P<blob>.*)")


@dataclass(frozen=True, order=True)
class TxnId:
    lane: int
    frame: int
    subheader: int
    hit: int
    payload: str

    @property
    def bucket(self) -> tuple[int, int]:
        return (self.frame, self.subheader)


@dataclass(frozen=True)
class TxnCase:
    case_id: str
    checkpoint: str
    n_lane: int = 4
    frame_count: int = 2
    subheaders: int = 4
    hits_per_subheader: int = 2
    queue_depth_words: int = 256
    rho_ppm: int = 100_000
    stage_fifo_depth: int = 128
    ready_high: int = 1
    ready_low: int = 0
    drain_cycles: int = 512
    expected_mode: str = "lossless"


def key_value_blob(blob: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for token in blob.strip().split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = value.rstrip(",")
    return fields


def make_payload(lane: int, frame: int, subheader: int, hit: int) -> str:
    payload = 0xD000_0000 ^ (lane * 0x0100_0000) ^ (frame * 0x0001_0000)
    payload ^= subheader * 0x0000_0100
    payload ^= hit
    return f"0x{payload:08x}"


def generated_ids(case: TxnCase) -> list[TxnId]:
    ids: list[TxnId] = []
    for frame in range(case.frame_count):
        for lane in range(case.n_lane):
            for subheader in range(case.subheaders):
                for hit in range(case.hits_per_subheader):
                    ids.append(
                        TxnId(
                            lane=lane,
                            frame=frame,
                            subheader=subheader,
                            hit=hit,
                            payload=make_payload(lane, frame, subheader, hit),
                        )
                    )
    return ids


def frame_words(case: TxnCase) -> int:
    return 6 + case.subheaders * (1 + case.hits_per_subheader)


def expected_tlm_events(case: TxnCase) -> dict[str, list[TxnId]]:
    offered = generated_ids(case)
    can_accept_empty_frame = frame_words(case) <= case.queue_depth_words
    events: dict[str, list[TxnId]] = {
        "offer": offered,
        "accept": [],
        "ingress_accept": [],
        "source_drop": [],
        "deliver": [],
    }
    if case.expected_mode == "source_queue_drop" or not can_accept_empty_frame:
        events["source_drop"] = offered
    elif case.expected_mode == "lossless":
        events["accept"] = offered
        events["ingress_accept"] = offered
        events["deliver"] = offered
    else:
        raise ValueError(f"unsupported expected_mode {case.expected_mode!r}")
    return events


def directed_cases() -> list[TxnCase]:
    return [
        TxnCase(
            case_id="tm_txn_per_subframe_basic",
            checkpoint="per-subframe basic",
            frame_count=2,
            subheaders=4,
            hits_per_subheader=2,
            queue_depth_words=256,
            rho_ppm=100_000,
            drain_cycles=512,
            expected_mode="lossless",
        ),
        TxnCase(
            case_id="tm_txn_multi_packet_lossless",
            checkpoint="per-subframe basic",
            frame_count=5,
            subheaders=8,
            hits_per_subheader=3,
            queue_depth_words=2048,
            rho_ppm=50_000,
            drain_cycles=2048,
            expected_mode="lossless",
        ),
        TxnCase(
            case_id="tm_txn_backpressure_drain_lossless",
            checkpoint="per-subframe basic",
            frame_count=4,
            subheaders=4,
            hits_per_subheader=2,
            queue_depth_words=1024,
            rho_ppm=25_000,
            ready_high=3,
            ready_low=1,
            drain_cycles=2048,
            expected_mode="lossless",
        ),
        TxnCase(
            case_id="tm_txn_source_queue_boundary",
            checkpoint="source queue boundary",
            frame_count=2,
            subheaders=2,
            hits_per_subheader=2,
            queue_depth_words=8,
            rho_ppm=100_000,
            drain_cycles=128,
            expected_mode="source_queue_drop",
        ),
    ]


def run_case(case: TxnCase, run_root: Path, no_run: bool) -> Path:
    run_root.mkdir(parents=True, exist_ok=True)
    log_path = run_root / f"{case.case_id}.log"
    build_dir = run_root / f"build_{case.case_id}"
    if no_run:
        if not log_path.exists():
            raise FileNotFoundError(f"missing log for {case.case_id}: {log_path}")
        return log_path

    plusargs = [
        "+OLD_TM_TRACE_TXN=1",
        f"+OLD_TM_FRAME_COUNT={case.frame_count}",
        f"+OLD_TM_SUBHEADERS={case.subheaders}",
        f"+OLD_TM_HITS_PER_SUBHEADER={case.hits_per_subheader}",
        f"+OLD_TM_QUEUE_DEPTH={case.queue_depth_words}",
        f"+OLD_TM_READY_HIGH={case.ready_high}",
        f"+OLD_TM_READY_LOW={case.ready_low}",
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
        print(f"[WARN] {case.case_id}: make loss returned {completed.returncode}; see {log_path}")
    else:
        print(f"[PASS] {case.case_id}: {log_path}")
    return log_path


def parse_txn_log(log_path: Path) -> tuple[dict[str, list[TxnId]], dict[str, str], dict[str, str], str]:
    text = log_path.read_text(errors="replace")
    events: dict[str, list[TxnId]] = {
        "offer": [],
        "accept": [],
        "ingress_accept": [],
        "source_drop": [],
        "deliver": [],
    }
    for match in TXN_RE.finditer(text):
        fields = key_value_blob(match.group("blob"))
        event = fields.get("event", "")
        if event not in events:
            continue
        events[event].append(
            TxnId(
                lane=int(fields["lane"]),
                frame=int(fields["frame"]),
                subheader=int(fields["subheader"]),
                hit=int(fields["hit"]),
                payload=fields["payload"].lower(),
            )
        )
    result_match = RESULT_RE.search(text)
    debug_match = DEBUG_RE.search(text)
    result = key_value_blob(result_match.group("blob")) if result_match else {}
    debug = key_value_blob(debug_match.group("blob")) if debug_match else {}
    return events, result, debug, text


def count_missing_extra(rtl_ids: list[TxnId], tlm_ids: list[TxnId]) -> tuple[int, int]:
    rtl_counter = Counter(rtl_ids)
    tlm_counter = Counter(tlm_ids)
    missing = sum((tlm_counter - rtl_counter).values())
    extra = sum((rtl_counter - tlm_counter).values())
    return missing, extra


def bucket_mismatch_count(rtl_ids: list[TxnId], tlm_ids: list[TxnId]) -> int:
    rtl_buckets = Counter(txn.bucket for txn in rtl_ids)
    tlm_buckets = Counter(txn.bucket for txn in tlm_ids)
    return sum((rtl_buckets - tlm_buckets).values()) + sum((tlm_buckets - rtl_buckets).values())


def bucket_order_violations(ids: list[TxnId]) -> int:
    violations = 0
    last = (-1, -1)
    for txn in ids:
        if txn.bucket < last:
            violations += 1
        last = txn.bucket
    return violations


def summarize_case(case: TxnCase, log_path: Path) -> dict[str, object]:
    rtl_events, result, debug, text = parse_txn_log(log_path)
    tlm_events = expected_tlm_events(case)
    rows: dict[str, object] = {
        "case_id": case.case_id,
        "checkpoint": case.checkpoint,
        "impl": "time_merger",
        "n_lane": case.n_lane,
        "frame_count": case.frame_count,
        "subheaders": case.subheaders,
        "hits_per_subheader": case.hits_per_subheader,
        "queue_depth_words": case.queue_depth_words,
        "stage_fifo_depth": case.stage_fifo_depth,
        "frame_words": frame_words(case),
        "rho_ppm": case.rho_ppm,
        "rho_unit": "hit_words_per_cycle_per_lane",
        "expected_mode": case.expected_mode,
        "loss_tier": "controlled" if case.expected_mode == "source_queue_drop" else "-",
        "rtl_sim_clean": "1" if "** Fatal:" not in text and "Errors: 0" in text else "0",
        "rtl_offered": len(rtl_events["offer"]),
        "rtl_source_accepted": len(rtl_events["accept"]),
        "rtl_ingress_accepted": len(rtl_events["ingress_accept"]),
        "rtl_source_dropped": len(rtl_events["source_drop"]),
        "rtl_delivered": len(rtl_events["deliver"]),
        "tlm_offered": len(tlm_events["offer"]),
        "tlm_source_accepted": len(tlm_events["accept"]),
        "tlm_ingress_accepted": len(tlm_events["ingress_accept"]),
        "tlm_source_dropped": len(tlm_events["source_drop"]),
        "tlm_delivered": len(tlm_events["deliver"]),
        "result_offered_hit_count": result.get("offered_hit_count", "-"),
        "result_accepted_hit_count": result.get("accepted_hit_count", "-"),
        "result_dropped_hit_count": result.get("dropped_hit_count", "-"),
        "result_delivered_hit_count": result.get("delivered_hit_count", "-"),
        "frame_gap_cycles": debug.get("frame_gap_cycles", "-"),
        "merged_output_utilization": debug.get("merged_output_utilization", "-"),
        "source_word_utilization": debug.get("source_word_utilization", "-"),
        "log": str(log_path),
    }

    total_missing = 0
    total_extra = 0
    total_bucket_mismatch = 0
    for event in ("offer", "accept", "ingress_accept", "source_drop", "deliver"):
        missing, extra = count_missing_extra(rtl_events[event], tlm_events[event])
        bucket_delta = bucket_mismatch_count(rtl_events[event], tlm_events[event])
        rows[f"{event}_missing"] = missing
        rows[f"{event}_extra"] = extra
        rows[f"{event}_bucket_mismatch"] = bucket_delta
        total_missing += missing
        total_extra += extra
        total_bucket_mismatch += bucket_delta

    deliver_exact_order = rtl_events["deliver"] == tlm_events["deliver"]
    deliver_bucket_order_violations = bucket_order_violations(rtl_events["deliver"])
    rows["deliver_exact_order"] = "1" if deliver_exact_order else "0"
    rows["deliver_bucket_order_violations"] = deliver_bucket_order_violations
    rows["deliver_order_policy"] = (
        "exact"
        if deliver_exact_order
        else "bucket_order_relaxed_for_round_robin_data_arbitration"
    )
    rows["total_missing"] = total_missing
    rows["total_extra"] = total_extra
    rows["total_bucket_mismatch"] = total_bucket_mismatch
    rows["match"] = (
        "PASS"
        if rows["rtl_sim_clean"] == "1"
        and total_missing == 0
        and total_extra == 0
        and total_bucket_mismatch == 0
        and deliver_bucket_order_violations == 0
        else "DEBUG"
    )
    return rows


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-run", action="store_true")
    parser.add_argument("--max-cases", type=int, default=0)
    args = parser.parse_args()

    cases = directed_cases()
    if args.max_cases > 0:
        cases = cases[: args.max_cases]

    run_root = RTL_ROOT / "runs" / "time_merger_transaction_check"
    rows: list[dict[str, object]] = []
    for case in cases:
        log_path = run_case(case, run_root, args.no_run)
        row = summarize_case(case, log_path)
        rows.append(row)
        print(
            "[CHECK] {case_id}: match={match} checkpoint={checkpoint!r} "
            "rtl offer/accept/pin/drop/deliver={offer}/{accept}/{pin}/{drop}/{deliver} "
            "missing={missing} extra={extra} bucket_mismatch={bucket}".format(
                case_id=case.case_id,
                match=row["match"],
                checkpoint=case.checkpoint,
                offer=row["rtl_offered"],
                accept=row["rtl_source_accepted"],
                pin=row["rtl_ingress_accepted"],
                drop=row["rtl_source_dropped"],
                deliver=row["rtl_delivered"],
                missing=row["total_missing"],
                extra=row["total_extra"],
                bucket=row["total_bucket_mismatch"],
            )
        )

    csv_path = RTL_ROOT / "data" / "time_merger_transaction_match.csv"
    json_path = RTL_ROOT / "data" / "time_merger_transaction_match_summary.json"
    write_csv(csv_path, rows)
    json_path.write_text(json.dumps(rows, indent=2) + "\n", encoding="ascii")
    print(f"[DONE] wrote {csv_path}")
    print(f"[DONE] wrote {json_path}")
    return 0 if all(row["match"] == "PASS" for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
