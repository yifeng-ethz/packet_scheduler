#!/usr/bin/env python3
"""Run OPQ UVM transaction traces and reduce them into packet ID checkpoints."""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from check_opq_transaction_trace import RTL_ROOT, summarize


REPO_ROOT = Path(__file__).resolve().parents[4]
RUN_UVM = REPO_ROOT / "packet_scheduler" / "tb" / "scripts" / "run_uvm.sh"


@dataclass(frozen=True)
class OpqTxnCase:
    case_id: str
    test_name: str
    checkpoint: str
    plusargs: str = "+OPQ_TRACE_TXN"
    n_lane: int = 4
    n_shd: int = 128
    page_ram_rd_width: int = 36


def directed_cases() -> list[OpqTxnCase]:
    physical_frame_gap = 4096
    return [
        OpqTxnCase(
            case_id="opq_txn_uvm_smoke_bucket",
            test_name="opq_basic_smoke_test",
            checkpoint="per-subframe basic",
        ),
        OpqTxnCase(
            case_id="opq_txn_uvm_feb_packet_contract",
            test_name="opq_basic_feb_packet_contract_test",
            checkpoint="per-subframe basic",
        ),
        OpqTxnCase(
            case_id="opq_txn_uvm_single_lane_multi_packet",
            test_name="opq_basic_single_active_lane_test",
            checkpoint="per-subframe basic",
        ),
        OpqTxnCase(
            case_id="opq_txn_uvm_model_publish_multiframe",
            test_name="opq_model_publish_loss_sweep_test",
            checkpoint="per-subframe basic",
            plusargs=(
                "+OPQ_TRACE_TXN "
                "+OPQ_MODEL_CASE=TXN_OPQ_MULTI "
                "+OPQ_MODEL_PROFILE=0 "
                "+OPQ_MODEL_FRAME_COUNT=4 "
                "+OPQ_MODEL_SUBHEADERS=4 "
                "+OPQ_MODEL_HIT_PERIOD=1 "
                "+OPQ_MODEL_HIT_COUNT=2 "
                f"+OPQ_MODEL_INTER_GAP={physical_frame_gap} "
                "+OPQ_MODEL_DWELL_US=350 "
                "+OPQ_MODEL_DRAIN_TIMEOUT_US=350 "
                "+OPQ_MODEL_REQUIRE_DRAIN=1"
            ),
        ),
        OpqTxnCase(
            case_id="opq_txn_uvm_aligned_multiframe",
            test_name="opq_model_publish_loss_sweep_test",
            checkpoint="per-subframe basic aligned",
            plusargs=(
                "+OPQ_TRACE_TXN "
                "+OPQ_MODEL_CASE=TXN_OPQ_PROFILE1_MULTI "
                "+OPQ_MODEL_PROFILE=1 "
                "+OPQ_MODEL_FRAME_COUNT=4 "
                "+OPQ_MODEL_SUBHEADERS=4 "
                "+OPQ_MODEL_HIT_COUNT=2 "
                "+OPQ_MODEL_DWELL_US=350 "
                "+OPQ_MODEL_DRAIN_TIMEOUT_US=350 "
                "+OPQ_MODEL_REQUIRE_DRAIN=1"
            ),
        ),
        OpqTxnCase(
            case_id="opq_txn_uvm_physical_scifi_anchor",
            test_name="opq_model_publish_loss_sweep_test",
            checkpoint="per-subframe basic physical anchor",
            plusargs=(
                "+OPQ_TRACE_TXN "
                "+OPQ_MODEL_CASE=TXN_OPQ_PROFILE3_ANCHOR "
                "+OPQ_MODEL_PROFILE=3 "
                "+OPQ_MODEL_FRAME_COUNT=4 "
                "+OPQ_MODEL_SUBHEADERS=16 "
                f"+OPQ_MODEL_INTER_GAP={physical_frame_gap} "
                "+OPQ_MODEL_RHO_PPM=600000 "
                "+OPQ_MODEL_NOISE_RHO_PPM=100000 "
                "+OPQ_MODEL_CLUSTER_RHO_PPM=500000 "
                "+OPQ_MODEL_CLUSTER_SIZE_MIN=4 "
                "+OPQ_MODEL_CLUSTER_SIZE_MAX=8 "
                "+OPQ_MODEL_BURSTINESS_MILLI=403 "
                "+OPQ_MODEL_RNG_SEED=1545533441 "
                "+OPQ_MODEL_DWELL_US=500 "
                "+OPQ_MODEL_DRAIN_TIMEOUT_US=500 "
                "+OPQ_MODEL_REQUIRE_DRAIN=1"
            ),
        ),
    ]


def run_case(case: OpqTxnCase, run_root: Path, no_run: bool) -> Path:
    log_dir = run_root / "logs"
    run_log_path = log_dir / f"{case.test_name}.log"
    case_log_path = log_dir / f"{case.case_id}.log"
    if no_run:
        if case_log_path.exists():
            return case_log_path
        if run_log_path.exists():
            return run_log_path
        raise FileNotFoundError(f"missing log for {case.case_id}: {case_log_path}")

    env = os.environ.copy()
    env.update(
        {
            "RUN_DIR": str(run_root),
            "LOG_DIR": str(log_dir),
            "BUILD_ROOT": str(run_root / "build"),
            "OPQ_N_LANE": str(case.n_lane),
            "OPQ_N_SHD": str(case.n_shd),
            "OPQ_PAGE_RAM_RD_WIDTH": str(case.page_ram_rd_width),
            "VSIM_PLUSARGS": case.plusargs,
        }
    )
    completed = subprocess.run(
        [str(RUN_UVM), case.test_name],
        cwd=REPO_ROOT,
        env=env,
        text=True,
        check=False,
    )
    if run_log_path.exists():
        shutil.copy2(run_log_path, case_log_path)
    if completed.returncode != 0:
        print(f"[WARN] {case.case_id}: run_uvm returned {completed.returncode}; see {case_log_path}")
    else:
        print(f"[PASS] {case.case_id}: {case_log_path}")
    return case_log_path


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
    parser.add_argument("--run-root", type=Path, default=RTL_ROOT / "runs" / "opq_transaction_check")
    parser.add_argument("--csv", type=Path, default=RTL_ROOT / "data" / "opq_transaction_match.csv")
    parser.add_argument("--json", type=Path, default=RTL_ROOT / "data" / "opq_transaction_match_summary.json")
    args = parser.parse_args()

    cases = directed_cases()
    if args.max_cases > 0:
        cases = cases[: args.max_cases]

    rows: list[dict[str, object]] = []
    for case in cases:
        log_path = run_case(case, args.run_root, args.no_run)
        row = summarize(log_path, case_id=case.case_id, checkpoint=case.checkpoint)
        rows.append(row)
        print(
            "[CHECK] {case_id}: match={match} offer/ingress/drop/deliver="
            "{offer}/{ingress}/{drop}/{deliver} exact_lane={exact_lane}/{deliver} "
            "deliver_missing={missing} deliver_extra={extra}".format(
                case_id=row["case_id"],
                match=row["match"],
                offer=row["offer_count"],
                ingress=row["ingress_accept_count"],
                drop=row["controlled_drop_count"],
                deliver=row["deliver_count"],
                exact_lane=row["deliver_lane_known_count"],
                missing=row["deliver_missing"],
                extra=row["deliver_extra"],
            )
        )

    write_csv(args.csv, rows)
    args.json.write_text(json.dumps(rows, indent=2) + "\n", encoding="ascii")
    print(f"[DONE] wrote {args.csv}")
    print(f"[DONE] wrote {args.json}")
    return 0 if all(row["match"] == "PASS" for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
