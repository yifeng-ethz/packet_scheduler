#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
from collections import OrderedDict
from datetime import date
from functools import lru_cache
from pathlib import Path

from opq_catalog import BUCKET_SPECS, parse_bucket

TB_DIR = Path(__file__).resolve().parents[1]
SIM_LOG_DIR = TB_DIR / "sim_runs" / "logs"
SIM_COV_DIR = TB_DIR / "sim_runs" / "coverage"
REPORT_LOG_DIR = TB_DIR / "uvm" / "logs"
REPORT_COV_DIR = TB_DIR / "uvm" / "cov_after"
WORK_DIR = TB_DIR / "sim_runs" / "report_work"
REPORT_JSON = TB_DIR / "DV_REPORT.json"

QUESTA_HOME = Path(os.environ.get("QUESTA_HOME", "/data1/questaone_sim/questasim"))
DUT_INSTANCE_RE = re.compile(r"^/tb_top/gen_dut_[^/]+/dut[^/]*(?:/|$)")
RTL_VARIANT = "after"
SEED = 1
SIGNOFF_DUT_IMPL = os.environ.get("DUT_IMPL", "native_sv")
SIGNOFF_N_LANE = int(os.environ.get("OPQ_N_LANE", "4"))
SIGNOFF_N_SHD = int(os.environ.get("OPQ_N_SHD", "128"))
SIGNOFF_PAGE_RAM_DEPTH = int(os.environ.get("OPQ_PAGE_RAM_DEPTH", "65536"))

METRIC_MAP = OrderedDict(
    [
        ("Branches", "branch"),
        ("Conditions", "cond"),
        ("Expressions", "expr"),
        ("FSM States", "fsm_state"),
        ("FSM Transitions", "fsm_trans"),
        ("Statements", "stmt"),
        ("Toggles", "toggle"),
    ]
)

VCOVER = next(
    (
        candidate
        for candidate in (
            QUESTA_HOME / "bin" / "vcover",
            QUESTA_HOME / "linux_x86_64" / "vcover",
        )
        if candidate.is_file()
    ),
    None,
)
if VCOVER is None:
    raise SystemExit(f"vcover not found under {QUESTA_HOME}")


def derived_ticket_fifo_depth(n_shd: int) -> int:
    depth = 256
    while depth <= n_shd:
        depth *= 2
    return depth


def run_cmd(*args: str) -> str:
    proc = subprocess.run(args, check=True, text=True, capture_output=True)
    return proc.stdout


def relpath_from_tb(path: Path) -> str:
    return path.relative_to(TB_DIR).as_posix()


def parse_cov_text(text: str) -> dict:
    totals = {key: {"hits": 0, "bins": 0, "pct": 0.0} for key in METRIC_MAP.values()}
    metric_re = re.compile(
        r"^\s*(Branches|Conditions|Expressions|FSM States|FSM Transitions|Statements|Toggles)\s+"
        r"(\d+)\s+(\d+)\s+\d+\s+([0-9.]+)%"
    )
    current_instance: str | None = None
    in_dut_instance = False
    for line in text.splitlines():
        if line.startswith("=== Instance: "):
            current_instance = line.split("=== Instance: ", 1)[1].strip()
            in_dut_instance = bool(DUT_INSTANCE_RE.match(current_instance))
            continue
        if not in_dut_instance:
            continue
        match = metric_re.match(line)
        if not match:
            continue
        metric = METRIC_MAP[match.group(1)]
        bins = int(match.group(2))
        hits = int(match.group(3))
        totals[metric]["bins"] += bins
        totals[metric]["hits"] += hits
    for metric, payload in totals.items():
        bins = payload["bins"]
        payload["pct"] = round((payload["hits"] * 100.0 / bins), 2) if bins else 0.0
    return totals


@lru_cache(maxsize=None)
def code_cov_for_ucdb(ucdb: Path) -> dict:
    text = run_cmd(str(VCOVER), "report", "-codeAll", str(ucdb))
    return parse_cov_text(text)


@lru_cache(maxsize=None)
def functional_cov_for_ucdb(ucdb: Path) -> dict:
    text = run_cmd(str(VCOVER), "report", "-summary", "-cvg", str(ucdb))
    match = re.search(r"Covergroups\s+\d+\s+na\s+na\s+\d+\s+([0-9.]+)%", text)
    pct = float(match.group(1)) if match else 0.0
    return {"pct": round(pct, 2), "evidenced": 0, "planned": 0}


def cov_delta(after: dict, before: dict | None) -> dict:
    out = {}
    for metric in METRIC_MAP.values():
        after_pct = after.get(metric, {}).get("pct", 0.0)
        before_pct = (before or {}).get(metric, {}).get("pct", 0.0)
        delta = round(after_pct - before_pct, 2)
        out[metric] = {"pct": max(delta, 0.0)}
    return out


def flatten_pct(cov: dict) -> dict:
    return {metric: {"pct": round(values.get("pct", 0.0), 2)} for metric, values in cov.items()}


def scale_cov_per_txn(cov: dict, txn_count: int) -> dict:
    denom = max(int(txn_count), 1)
    return {
        metric: {"pct": round(values.get("pct", 0.0) / denom, 4)}
        for metric, values in cov.items()
    }


def artifact_candidates(case: dict) -> list[str]:
    candidates = [case["case_id"]]
    runtime_test = case.get("runtime_test") or case.get("legacy_test_name")
    if runtime_test and runtime_test not in candidates:
        candidates.append(runtime_test)
    return candidates


def resolve_ucdb_path(case: dict) -> tuple[Path | None, str | None]:
    for candidate_name in artifact_candidates(case):
        candidate = SIM_COV_DIR / f"{candidate_name}.ucdb"
        if candidate.is_file():
            return candidate, candidate_name
    return None, None


def resolve_log_path(case: dict) -> tuple[Path | None, str | None]:
    for candidate_name in artifact_candidates(case):
        candidate = SIM_LOG_DIR / f"{candidate_name}.log"
        if candidate.is_file():
            return candidate, candidate_name
    return None, None


def merge_ucdb(output: Path, inputs: list[Path]) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    run_cmd(str(VCOVER), "merge", str(output), *[str(path) for path in inputs])
    return output


@lru_cache(maxsize=None)
def extract_log_summary(log_path: Path | None) -> tuple[bool, bool, bool, dict]:
    if log_path is None or not log_path.is_file():
        return False, False, False, {}

    text = log_path.read_text(encoding="utf-8", errors="replace")
    engine_ok = "[run_uvm] DUT_IMPL=native_sv" in text
    pass_ok = bool(re.search(r"# UVM_ERROR :\s+0\b", text) and re.search(r"# UVM_FATAL :\s+0\b", text))
    pass_ok = pass_ok and "** Error:" not in text and "** Fatal:" not in text

    summary: dict[str, int | float | str] = {}
    run_cfg_match = re.search(
        r"\[run_uvm\]\s+DUT_IMPL=(\S+)\s+TEST=(\S+)\s+ARTIFACT=(\S+)\s+"
        r"OPQ_N_LANE=(\d+)\s+OPQ_N_SHD=(\d+)\s+OPQ_TICKET_FIFO_DEPTH=(\d+)\s+"
        r"OPQ_PAGE_RAM_DEPTH=(\d+)\s+COV_ENABLE=(\d+)",
        text,
    )
    if run_cfg_match:
        summary["cfg_dut_impl"] = run_cfg_match.group(1)
        summary["cfg_test"] = run_cfg_match.group(2)
        summary["cfg_artifact"] = run_cfg_match.group(3)
        summary["cfg_n_lane"] = int(run_cfg_match.group(4))
        summary["cfg_n_shd"] = int(run_cfg_match.group(5))
        summary["cfg_ticket_fifo_depth"] = int(run_cfg_match.group(6))
        summary["cfg_page_ram_depth"] = int(run_cfg_match.group(7))
        summary["cfg_cov_enable"] = int(run_cfg_match.group(8))

    hit_match = re.search(
        r"Hit integrity summary: expected=(\d+) actual=(\d+) missing=(\d+) ghost=(\d+)",
        text,
    )
    if hit_match:
        summary["hit_expected"] = int(hit_match.group(1))
        summary["hit_actual"] = int(hit_match.group(2))
        summary["hit_missing"] = int(hit_match.group(3))
        summary["hit_ghost"] = int(hit_match.group(4))

    cov_match = re.search(
        r"Coverage cfg=([0-9.]+) frame=([0-9.]+) subh=([0-9.]+) bp=([0-9.]+) csr=([0-9.]+) "
        r"credit=([0-9.]+) drop=([0-9.]+) drr=([0-9.]+) ingress=([0-9.]+) egress=([0-9.]+)",
        text,
    )
    if cov_match:
        summary["cg_cfg"] = float(cov_match.group(1))
        summary["cg_frame"] = float(cov_match.group(2))
        summary["cg_subh"] = float(cov_match.group(3))
        summary["cg_bp"] = float(cov_match.group(4))
        summary["cg_csr"] = float(cov_match.group(5))
        summary["cg_credit"] = float(cov_match.group(6))
        summary["cg_drop"] = float(cov_match.group(7))
        summary["cg_drr"] = float(cov_match.group(8))
        summary["cg_ingress"] = float(cov_match.group(9))
        summary["cg_egress"] = float(cov_match.group(10))

    monitored_frames = 0
    for match in re.finditer(r"lane(\d+) monitored_frames=(\d+) orphan_beats=(\d+) capture_err=(\d+)", text):
        lane = int(match.group(1))
        summary[f"lane{lane}_monitored_frames"] = int(match.group(2))
        summary[f"lane{lane}_orphan_beats"] = int(match.group(3))
        summary[f"lane{lane}_capture_err"] = int(match.group(4))
        monitored_frames += int(match.group(2))
    if monitored_frames:
        summary["observed_txn"] = monitored_frames

    return True, engine_ok, pass_ok, summary


def stage_report_artifacts(case_artifacts: list[dict]) -> None:
    REPORT_LOG_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_COV_DIR.mkdir(parents=True, exist_ok=True)

    for directory in (REPORT_LOG_DIR, REPORT_COV_DIR):
        for child in directory.iterdir():
            if child.is_symlink() or child.is_file():
                child.unlink()

    for case in case_artifacts:
        case_id = case["case_id"]
        src_log, _ = resolve_log_path(case)
        src_ucdb, _ = resolve_ucdb_path(case)
        dst_log = REPORT_LOG_DIR / f"{case_id}_{RTL_VARIANT}_s{SEED}.log"
        dst_ucdb = REPORT_COV_DIR / f"{case_id}_s{SEED}.ucdb"
        if src_log is not None and src_log.is_file():
            dst_log.symlink_to(Path("..") / ".." / src_log.relative_to(TB_DIR))
        if src_ucdb is not None and src_ucdb.is_file():
            dst_ucdb.symlink_to(Path("..") / ".." / src_ucdb.relative_to(TB_DIR))


def case_build_knobs(case: dict) -> dict:
    page_depth = 512 if case["runtime_test"] == "opq_error_ftable_overflow_test" else SIGNOFF_PAGE_RAM_DEPTH
    return {
        "OPQ_N_LANE": SIGNOFF_N_LANE,
        "OPQ_N_SHD": SIGNOFF_N_SHD,
        "OPQ_TICKET_FIFO_DEPTH": int(os.environ.get("OPQ_TICKET_FIFO_DEPTH", str(derived_ticket_fifo_depth(SIGNOFF_N_SHD)))),
        "OPQ_PAGE_RAM_DEPTH": page_depth,
        "DUT_IMPL": SIGNOFF_DUT_IMPL,
    }


def build() -> dict:
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    bucket_payloads: OrderedDict[str, dict] = OrderedDict()
    bucket_summary: list[dict] = []
    all_cases: list[dict] = []
    failed_cases: list[str] = []
    unimplemented_cases: list[str] = []
    all_passed_ucdbs_unique: list[Path] = []
    all_passed_ucdb_seen: set[Path] = set()
    all_passed_case_count = 0
    all_artifacts: list[dict] = []
    global_merged_cov_before: dict | None = None

    for bucket_name in BUCKET_SPECS:
        catalog_rows = parse_bucket(bucket_name)
        bucket_cases: list[dict] = []
        bucket_ucdbs_unique: list[Path] = []
        bucket_ucdb_seen: set[Path] = set()
        merge_trace: list[dict] = []
        evidenced_cases = 0
        bucket_merged_cov_before: dict | None = None

        for step, catalog_case in enumerate(catalog_rows, start=1):
            case_id = catalog_case["case_id"]
            all_artifacts.append(catalog_case)
            log_path, log_artifact_name = resolve_log_path(catalog_case)
            ucdb_path, ucdb_artifact_name = resolve_ucdb_path(catalog_case)
            log_exists, engine_ok, pass_ok, log_summary = extract_log_summary(log_path)
            has_ucdb = ucdb_path is not None
            scope_match = (
                int(log_summary.get("cfg_n_lane", -1)) == SIGNOFF_N_LANE
                and int(log_summary.get("cfg_n_shd", -1)) == SIGNOFF_N_SHD
                and int(log_summary.get("cfg_ticket_fifo_depth", -1)) == int(os.environ.get("OPQ_TICKET_FIFO_DEPTH", str(derived_ticket_fifo_depth(SIGNOFF_N_SHD))))
                and int(log_summary.get("cfg_page_ram_depth", -1)) == case_build_knobs(catalog_case)["OPQ_PAGE_RAM_DEPTH"]
                and str(log_summary.get("cfg_dut_impl", "")) == SIGNOFF_DUT_IMPL
                and int(log_summary.get("cfg_cov_enable", 0)) == 1
            )
            implemented = log_exists and has_ucdb and scope_match

            case = {
                "bucket": bucket_name,
                "case_id": case_id,
                "full_case_id": case_id,
                "report_case_id": case_id,
                "method": catalog_case["method"],
                "scenario": catalog_case["scenario"],
                "primary_checks": catalog_case["primary_checks"],
                "contract_anchor": f"{catalog_case['source']}::{case_id}",
                "catalog_alias": catalog_case["legacy_alias"] or "none",
                "legacy_test_name": catalog_case["runtime_test"],
                "test_name": catalog_case["runtime_test"],
                "runtime_plusargs": catalog_case["runtime_plusargs"],
                "log_artifact_name": log_artifact_name or "",
                "ucdb_artifact_name": ucdb_artifact_name or "",
                "implementation": catalog_case["implementation"],
                "implementation_mode": SIGNOFF_DUT_IMPL,
                "build_tag": RTL_VARIANT,
                "isolated_effort": "high" if catalog_case["method"] == "R" else "practical",
                "build_knobs": case_build_knobs(catalog_case),
                "log_summary": log_summary,
                "scope_match": scope_match,
            }

            if not implemented:
                case["implemented"] = False
                case["passed"] = False
                case["observed_txn"] = 0
                unimplemented_cases.append(case_id)
                failed_cases.append(case_id)
                bucket_cases.append(case)
                all_cases.append(case)
                continue

            standalone_cov = code_cov_for_ucdb(ucdb_path)
            case["implemented"] = True
            case["passed"] = bool(engine_ok and pass_ok)
            case["standalone_coverage"] = flatten_pct(standalone_cov)
            case["observed_txn"] = int(log_summary.get("observed_txn", 1) or 1)
            if case["method"] == "R":
                case["isolated_cov_per_txn"] = scale_cov_per_txn(standalone_cov, case["observed_txn"])
            else:
                case["isolated_cov_per_txn"] = flatten_pct(standalone_cov)

            if case["passed"]:
                evidenced_cases += 1
                if ucdb_path not in bucket_ucdb_seen:
                    bucket_ucdb_seen.add(ucdb_path)
                    bucket_ucdbs_unique.append(ucdb_path)
                    merged_after = code_cov_for_ucdb(
                        merge_ucdb(WORK_DIR / f"{bucket_name.lower()}_{step}.ucdb", bucket_ucdbs_unique)
                    )
                else:
                    merged_after = bucket_merged_cov_before or standalone_cov
                case["bucket_gain_by_case"] = cov_delta(merged_after, bucket_merged_cov_before)
                case["bucket_merged_total_after_case"] = flatten_pct(merged_after)
                if case["method"] == "R":
                    case["bucket_gain_per_txn"] = scale_cov_per_txn(case["bucket_gain_by_case"], case["observed_txn"])
                else:
                    case["bucket_gain_per_txn"] = dict(case["bucket_gain_by_case"])
                bucket_merged_cov_before = merged_after
                merge_trace.append(
                    {
                        "step": step,
                        "case_id": case_id,
                        "full_case_id": case_id,
                        "legacy_test_name": case["legacy_test_name"],
                        "merged_total_after_case": flatten_pct(merged_after),
                    }
                )
                all_passed_case_count += 1
                if ucdb_path not in all_passed_ucdb_seen:
                    all_passed_ucdb_seen.add(ucdb_path)
                    all_passed_ucdbs_unique.append(ucdb_path)
                    global_merged_cov_before = code_cov_for_ucdb(
                        merge_ucdb(WORK_DIR / f"global_{bucket_name.lower()}_{step}.ucdb", all_passed_ucdbs_unique)
                    )
            else:
                failed_cases.append(case_id)

            bucket_cases.append(case)
            all_cases.append(case)

        merged_bucket_total = flatten_pct(bucket_merged_cov_before or {})
        bucket_functional_cov = {"pct": 0.0, "evidenced": evidenced_cases, "planned": len(catalog_rows)}
        if bucket_ucdbs_unique:
            merged_bucket_ucdb = merge_ucdb(WORK_DIR / f"{bucket_name.lower()}_merged.ucdb", bucket_ucdbs_unique)
            bucket_functional_cov = functional_cov_for_ucdb(merged_bucket_ucdb)
            bucket_functional_cov["evidenced"] = evidenced_cases
            bucket_functional_cov["planned"] = len(catalog_rows)
        bucket_payloads[bucket_name] = {
            "bucket": bucket_name,
            "catalog_source": relpath_from_tb(BUCKET_SPECS[bucket_name]["path"]),
            "catalog_summary": f"Canonical {bucket_name} catalog from {BUCKET_SPECS[bucket_name]['path'].name}.",
            "catalog_planned_cases": len(catalog_rows),
            "promoted_cases": len(catalog_rows),
            "evidenced_cases": evidenced_cases,
            "catalog_pending_cases": 0,
            "ordered_case_ids": [case["case_id"] for case in bucket_cases],
            "merge_trace": merge_trace,
            "merged_bucket_total": merged_bucket_total,
            "functional_coverage": bucket_functional_cov,
            "cases": bucket_cases,
        }
        bucket_summary.append(
            {
                "bucket": bucket_name,
                "catalog_planned_cases": len(catalog_rows),
                "promoted_cases": len(catalog_rows),
                "evidenced_cases": evidenced_cases,
                "catalog_pending_cases": 0,
                "merged_bucket_total": merged_bucket_total,
                "ordered_case_ids": [case["case_id"] for case in bucket_cases],
                "functional_coverage": bucket_functional_cov,
            }
        )

    stage_report_artifacts(all_artifacts)

    merged_total_cov = flatten_pct(global_merged_cov_before or {})
    total_functional_cov = {"pct": 0.0, "evidenced": 0, "planned": len(all_cases)}
    if all_passed_ucdbs_unique:
        merged_total_ucdb = merge_ucdb(WORK_DIR / "all_buckets_merged.ucdb", all_passed_ucdbs_unique)
        total_functional_cov = functional_cov_for_ucdb(merged_total_ucdb)
        total_functional_cov["evidenced"] = all_passed_case_count
        total_functional_cov["planned"] = len(all_cases)

    return {
        "report_title": "packet_scheduler ordered_priority_queue native_sv",
        "dut_name": "ordered_priority_queue_monolithic_sv",
        "date": str(date.today()),
        "rtl_variant": RTL_VARIANT,
        "seed": SEED,
        "signoff_scope": {
            "DUT_IMPL": SIGNOFF_DUT_IMPL,
            "OPQ_N_LANE": [SIGNOFF_N_LANE],
            "OPQ_N_SHD": [SIGNOFF_N_SHD],
            "OPQ_TICKET_FIFO_DEPTH": [int(os.environ.get("OPQ_TICKET_FIFO_DEPTH", str(derived_ticket_fifo_depth(SIGNOFF_N_SHD))))],
            "OPQ_PAGE_RAM_DEPTH": [SIGNOFF_PAGE_RAM_DEPTH],
            "MODE": ["MERGING"],
            "probe_only_exclusions": [],
        },
        "case_id_policy": {
            "mode": "canonical_catalog",
            "summary": "Each report case ID is the canonical DV catalog case ID (`B/E/P/X###`).",
        },
        "coverage_category_status": {
            "supported_with_targets": {
                "stmt": "supported in the Questa native-SV flow; tracked against the 95% workflow target",
                "branch": "supported in the Questa native-SV flow; tracked against the 90% workflow target",
                "fsm_state": "supported in the Questa native-SV flow; tracked against the 95% workflow target",
                "fsm_trans": "supported in the Questa native-SV flow; tracked against the 90% workflow target",
                "toggle": "supported in the Questa native-SV flow; tracked against the 80% workflow target",
            },
            "supported_without_hard_target": {
                "cond": "supported in the Questa native-SV flow and reported explicitly",
                "expr": "supported in the Questa native-SV flow and reported explicitly",
            },
            "unsupported": {},
        },
        "failed_cases": failed_cases,
        "catalog_inventory": {
            bucket: {
                "count": len(parse_bucket(bucket)),
                "source": relpath_from_tb(BUCKET_SPECS[bucket]["path"]),
                "summary": f"Canonical {bucket} catalog from {BUCKET_SPECS[bucket]['path'].name}.",
            }
            for bucket in BUCKET_SPECS
        },
        "implementation_summary": {
            "unimplemented_cases": sorted(set(unimplemented_cases)),
            "unimplemented_count": len(set(unimplemented_cases)),
            "stale_artifacts_without_engine_marker": [],
            "stale_artifact_without_engine_marker_count": 0,
        },
        "non_claims": {
            "cross_scope": "DV_CROSS supplemental long-run ladders are tracked separately from the canonical per-case isolated matrix in this refresh.",
        },
        "execution_modes": {
            "isolated": {
                "bucket_order": list(BUCKET_SPECS.keys()),
                "per_bucket_case_order": {
                    bucket_name: [case["case_id"] for case in bucket_payload["cases"]]
                    for bucket_name, bucket_payload in bucket_payloads.items()
                },
            },
        },
        "cases": all_cases,
        "bucket_summary": bucket_summary,
        "buckets": bucket_payloads,
        "coverage_hole_disposition": [],
        "totals": {
            "planned_cases": len(all_cases),
            "catalog_planned_cases": len(all_cases),
            "catalog_pending_cases": 0,
            "promoted_cases": len(all_cases),
            "evidenced_cases": all_passed_case_count,
            "excluded_cases": 0,
            "merged_total_code_coverage": merged_total_cov,
            "functional_coverage": total_functional_cov,
        },
        "signoff_runs": [],
        "random_cases": [case for case in all_cases if case.get("method") == "R"],
    }


def main() -> int:
    payload = build()
    REPORT_JSON.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
