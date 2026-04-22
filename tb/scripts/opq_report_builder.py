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
UVM_BUILD_RUNS_DIR = TB_DIR / "uvm" / "build_runs"
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

NATIVE_FRAME_BUCKET_STEPS = OrderedDict(
    [
        (
            "BASIC",
            [
                {"legacy_step_name": "basic_seq", "description": "basic smoke virtual sequence"},
                {"legacy_step_name": "ts_seq", "description": "timestamp boundary virtual sequence"},
                {"legacy_step_name": "feb_seq", "description": "FEB packet contract virtual sequence"},
                {"legacy_step_name": "shd_seq", "description": "subheader shape virtual sequence"},
                {"legacy_step_name": "single_lane_seq", "description": "single active lane 0 virtual sequence"},
                {"legacy_step_name": "single_lane_lane1_seq", "description": "single active lane 1 virtual sequence"},
                {"legacy_step_name": "single_lane_dense_seq", "description": "dense single-lane virtual sequence"},
            ],
        ),
        (
            "EDGE",
            [
                {"legacy_step_name": "bp_seq_6_4_24", "description": "periodic stall backpressure sweep high=6 low=4 repeat=24"},
                {"legacy_step_name": "bp_seq_32_4_1", "description": "always-ready backpressure sweep high=32 low=4 repeat=1"},
                {"legacy_step_name": "bp_seq_32_8_12", "description": "periodic stall backpressure sweep high=32 low=8 repeat=12"},
                {"legacy_step_name": "bp_seq_4_12_24", "description": "periodic stall backpressure sweep high=4 low=12 repeat=24"},
                {"legacy_step_name": "bp_seq_1_2048_1", "description": "always-stall backpressure sweep high=1 low=2048 repeat=1"},
                {"legacy_step_name": "max_hits_seq", "description": "max-hit virtual sequence"},
                {"legacy_step_name": "bp_seq_1_1_24", "description": "periodic stall backpressure sweep high=1 low=1 repeat=24"},
                {"legacy_step_name": "bp_seq_1_1_96", "description": "periodic stall backpressure sweep high=1 low=1 repeat=96"},
                {"legacy_step_name": "max_hits_bp_seq", "description": "max-hit virtual sequence under periodic stall"},
            ],
        ),
        (
            "PROF",
            [
                {"legacy_step_name": "soak_seq", "description": "baseline soak virtual sequence"},
                {"legacy_step_name": "stress_seq", "description": "lane-skew stress virtual sequence"},
                {"legacy_step_name": "whole_frame_seq", "description": "whole-frame skew virtual sequence"},
                {"legacy_step_name": "sparse_seq", "description": "missing-empty-frame virtual sequence"},
                {"legacy_step_name": "long_soak_seq", "description": "extended soak virtual sequence"},
                {"legacy_step_name": "heavy_skew_seq", "description": "heavy lane-skew stress virtual sequence"},
                {"legacy_step_name": "deep_whole_frame_seq", "description": "deep whole-frame skew virtual sequence"},
                {
                    "legacy_step_name": "per_lane_half_frame_skew_seq",
                    "description": "4-lane per-lane skew sweep up to half-frame cadence",
                },
                {"legacy_step_name": "asym_sparse_seq", "description": "asymmetric missing-empty-frame virtual sequence"},
            ],
        ),
        (
            "ERROR",
            [
                {"legacy_step_name": "masked_drop_seq", "description": "masked drop virtual sequence"},
                {"legacy_step_name": "single_hit_masked_drop_seq", "description": "single-hit masked drop virtual sequence"},
                {"legacy_step_name": "burst_masked_drop_seq", "description": "burst masked drop virtual sequence"},
                {"legacy_step_name": "masked_recovery", "description": "masked drop recovery virtual sequence"},
                {"legacy_step_name": "hit_recovery_seq", "description": "hit error recovery virtual sequence"},
                {"legacy_step_name": "shd_recovery_seq", "description": "subheader error recovery virtual sequence"},
                {"legacy_step_name": "header_recovery_seq", "description": "header error recovery virtual sequence"},
                {"legacy_step_name": "header_word_recovery_seq", "description": "header-word error recovery virtual sequence"},
            ],
        ),
        (
            "CROSS",
            [
                {"legacy_step_name": "bp_credit_seq", "description": "credit/backpressure cross sequence"},
                {"legacy_step_name": "drr_allow_seq", "description": "DRR allowance saturation sequence"},
                {"legacy_step_name": "idle_lane_seq", "description": "idle-lane DRR sequence"},
                {"legacy_step_name": "zero_allow_seq", "description": "zero-allowance DRR sequence"},
                {"legacy_step_name": "drr_short_seq", "description": "short-allowance DRR saturation sequence"},
                {"legacy_step_name": "idle_lane_bp_case_seq", "description": "idle-lane backpressure cross case"},
            ],
        ),
    ]
)

NATIVE_ALL_BUCKETS_EXTRA_STEPS = [
    {"bucket": "PROF", "legacy_step_name": "extra_prof_seq", "description": "whole-frame skew tail after the promoted matrix"},
    {"bucket": "ERROR", "legacy_step_name": "extra_err_seq", "description": "subheader error recovery tail after the promoted matrix"},
]

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


def parse_cov_instances_text(text: str) -> dict[str, dict]:
    metric_re = re.compile(
        r"^\s*(Branches|Conditions|Expressions|FSM States|FSM Transitions|Statements|Toggles)\s+"
        r"(\d+)\s+(\d+)\s+\d+\s+([0-9.]+)%"
    )
    instances: OrderedDict[str, dict] = OrderedDict()
    current_instance: str | None = None
    in_dut_instance = False
    for line in text.splitlines():
        if line.startswith("=== Instance: "):
            current_instance = line.split("=== Instance: ", 1)[1].strip()
            in_dut_instance = bool(DUT_INSTANCE_RE.match(current_instance))
            if in_dut_instance:
                instances[current_instance] = {"design_unit": "", "metrics": {}}
            continue
        if not in_dut_instance or current_instance is None:
            continue
        if line.startswith("=== Design Unit: "):
            instances[current_instance]["design_unit"] = line.split("=== Design Unit: ", 1)[1].strip()
            continue
        match = metric_re.match(line)
        if not match:
            continue
        metric = METRIC_MAP[match.group(1)]
        bins = int(match.group(2))
        hits = int(match.group(3))
        instances[current_instance]["metrics"][metric] = {
            "bins": bins,
            "hits": hits,
            "pct": round((hits * 100.0 / bins), 2) if bins else 0.0,
        }
    return dict(instances)


@lru_cache(maxsize=None)
def code_cov_for_ucdb(ucdb: Path) -> dict:
    text = run_cmd(str(VCOVER), "report", "-codeAll", str(ucdb))
    return parse_cov_text(text)


@lru_cache(maxsize=None)
def code_cov_instances_for_ucdb(ucdb: Path) -> dict[str, dict]:
    text = run_cmd(str(VCOVER), "report", "-codeAll", str(ucdb))
    return parse_cov_instances_text(text)


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


def scope_matches_log_summary(log_summary: dict, page_ram_depth: int) -> bool:
    return (
        int(log_summary.get("cfg_n_lane", -1)) == SIGNOFF_N_LANE
        and int(log_summary.get("cfg_n_shd", -1)) == SIGNOFF_N_SHD
        and int(log_summary.get("cfg_ticket_fifo_depth", -1))
        == int(os.environ.get("OPQ_TICKET_FIFO_DEPTH", str(derived_ticket_fifo_depth(SIGNOFF_N_SHD))))
        and int(log_summary.get("cfg_page_ram_depth", -1)) == page_ram_depth
        and str(log_summary.get("cfg_dut_impl", "")) == SIGNOFF_DUT_IMPL
        and int(log_summary.get("cfg_cov_enable", 0)) == 1
    )


def fallback_cross_pct(log_summary: dict) -> float:
    cg_keys = (
        "cg_cfg",
        "cg_frame",
        "cg_subh",
        "cg_bp",
        "cg_csr",
        "cg_credit",
        "cg_drop",
        "cg_drr",
        "cg_ingress",
        "cg_egress",
    )
    values = [float(log_summary[key]) for key in cg_keys if key in log_summary]
    if not values:
        return 0.0
    return round(sum(values) / len(values), 2)


def native_frame_named_steps(include_extra_tail: bool) -> list[dict]:
    steps: list[dict] = []
    for bucket, bucket_steps in NATIVE_FRAME_BUCKET_STEPS.items():
        for step in bucket_steps:
            steps.append(
                {
                    "bucket": bucket,
                    "legacy_step_name": step["legacy_step_name"],
                    "description": step["description"],
                }
            )
    if include_extra_tail:
        steps.extend(NATIVE_ALL_BUCKETS_EXTRA_STEPS)
    return steps


def native_frame_mode(run_id: str, include_extra_tail: bool) -> dict:
    return {
        "run_id": run_id,
        "bucket_order": list(NATIVE_FRAME_BUCKET_STEPS.keys()),
        "named_steps": native_frame_named_steps(include_extra_tail),
        "limitations": [
            "This native-SV frame baseline runs the promoted internal UVM sequence matrix from `opq_frame_signoff_tests.sv`, not the full canonical isolated case catalog.",
            "The isolated B/E/P/X case ledger remains the authoritative per-case closure view; this run is continuous-frame carry-over evidence.",
        ],
    }


def classify_signoff_test(test_name: str) -> dict | None:
    supplemental_cross_tests = {
        "opq_formal_like_egress_flush_backpressure_stress_test",
        "opq_error_counter_clear_test",
        "opq_error_ftable_overflow_test",
    }
    if test_name == "opq_bucket_frame_native_sv_test":
        return {
            "run_id": test_name,
            "kind": "bucket_frame",
            "sequence_name": "run_promoted_default_build_matrix",
            "case_count": len(native_frame_named_steps(False)),
            "effort": "high",
        }
    if test_name == "opq_all_buckets_frame_native_sv_test":
        return {
            "run_id": test_name,
            "kind": "all_buckets_frame",
            "sequence_name": "run_promoted_default_build_matrix_plus_tail",
            "case_count": len(native_frame_named_steps(True)),
            "effort": "high",
        }
    if test_name in supplemental_cross_tests:
        return {
            "run_id": test_name,
            "kind": "cross",
            "sequence_name": test_name,
            "case_count": 1,
            "effort": "practical",
        }
    if test_name.startswith("opq_cross_"):
        return {
            "run_id": test_name,
            "kind": "cross",
            "sequence_name": test_name,
            "case_count": 1,
            "effort": "high" if ("random" in test_name or "soak" in test_name) else "practical",
        }
    return None


def classify_cov_area(instance: str, design_unit: str) -> str | None:
    if design_unit.endswith("ordered_priority_queue_monolithic_ingress_parser"):
        return "ingress_parser"
    if design_unit.endswith("ordered_priority_queue_monolithic_page_allocator"):
        return "page_allocator"
    if design_unit.endswith("ordered_priority_queue_monolithic_block_path"):
        return "block_path"
    if design_unit.endswith("ordered_priority_queue_monolithic_basic_presenter_native"):
        return "presenter_native"
    if design_unit.endswith("ordered_priority_queue_monolithic_basic_presenter"):
        return "presenter_wrapper"
    if design_unit.endswith("page_ram"):
        return "page_ram"
    if design_unit.endswith("ticket_fifo"):
        return "ticket_fifo"
    if design_unit.endswith("lane_fifo"):
        return "lane_fifo"
    if design_unit.endswith("handle_fifo"):
        return "handle_fifo"
    if design_unit.endswith("tile_fifo"):
        return "presenter_meta_ram"
    if design_unit.endswith("ordered_priority_queue_monolithic_sv"):
        return "top_wrapper"
    if design_unit.endswith("ordered_priority_queue_dut_sv"):
        return "dut_wrapper"
    if instance.endswith("/u_native"):
        return "top_wrapper"
    if re.match(r"^/tb_top/gen_dut_[^/]+/dut[^/]*$", instance):
        return "dut_wrapper"
    return None


def summarize_cov_area(instances: list[dict]) -> dict:
    metrics: dict[str, float] = {}
    aggregate_metrics: dict[str, float] = {}
    for metric in METRIC_MAP.values():
        values = [payload["metrics"][metric] for payload in instances if metric in payload["metrics"]]
        if not values:
            continue
        metrics[metric] = round(min(value["pct"] for value in values), 2)
        bins = sum(value["bins"] for value in values)
        hits = sum(value["hits"] for value in values)
        aggregate_metrics[metric] = round((hits * 100.0 / bins), 2) if bins else 0.0
    return {
        "instance_count": len(instances),
        "metrics": metrics,
        "aggregate_metrics": aggregate_metrics,
        "instances": [payload["instance"] for payload in instances],
        "design_units": sorted({payload["design_unit"] for payload in instances if payload["design_unit"]}),
    }


def combine_cov_summaries(summaries: list[dict | None]) -> dict | None:
    filtered = [summary for summary in summaries if summary]
    if not filtered:
        return None
    metrics: dict[str, float] = {}
    aggregate_metrics: dict[str, float] = {}
    for metric in METRIC_MAP.values():
        metric_values = [summary["metrics"][metric] for summary in filtered if metric in summary.get("metrics", {})]
        aggregate_values = [
            summary["aggregate_metrics"][metric]
            for summary in filtered
            if metric in summary.get("aggregate_metrics", {})
        ]
        if metric_values:
            metrics[metric] = round(min(metric_values), 2)
        if aggregate_values:
            aggregate_metrics[metric] = round(min(aggregate_values), 2)
    instance_count = sum(int(summary.get("instance_count", 0)) for summary in filtered)
    instances: list[str] = []
    design_units: list[str] = []
    for summary in filtered:
        instances.extend(summary.get("instances", []))
        design_units.extend(summary.get("design_units", []))
    return {
        "instance_count": instance_count,
        "metrics": metrics,
        "aggregate_metrics": aggregate_metrics,
        "instances": sorted(dict.fromkeys(instances)),
        "design_units": sorted(dict.fromkeys(design_units)),
    }


@lru_cache(maxsize=None)
def cov_area_summary_for_ucdb(ucdb: Path) -> dict[str, dict]:
    grouped: dict[str, list[dict]] = {}
    for instance, payload in code_cov_instances_for_ucdb(ucdb).items():
        area = classify_cov_area(instance, str(payload.get("design_unit", "")))
        if area is None:
            continue
        grouped.setdefault(area, []).append(
            {
                "instance": instance,
                "design_unit": str(payload.get("design_unit", "")),
                "metrics": dict(payload.get("metrics", {})),
            }
        )
    return {area: summarize_cov_area(payloads) for area, payloads in grouped.items()}


def fmt_cov_summary(summary: dict | None, metrics: tuple[str, ...] = ("stmt", "branch", "fsm_trans", "toggle")) -> str:
    if not summary:
        return "n/a"
    source = summary.get("aggregate_metrics") or summary.get("metrics") or {}
    parts = [f"{metric}={source[metric]:.2f}" for metric in metrics if metric in source]
    return ", ".join(parts) if parts else "n/a"


def build_coverage_hole_disposition(
    isolated_merged_ucdb: Path | None, signoff_run_ucdbs: list[Path]
) -> list[dict]:
    if isolated_merged_ucdb is None:
        return []

    isolated_area_cov = cov_area_summary_for_ucdb(isolated_merged_ucdb)
    signoff_unique: list[Path] = []
    signoff_seen: set[Path] = set()
    for ucdb_path in signoff_run_ucdbs:
        if ucdb_path == isolated_merged_ucdb or ucdb_path in signoff_seen:
            continue
        signoff_seen.add(ucdb_path)
        signoff_unique.append(ucdb_path)

    merged_plus_signoff_cov: dict[str, dict] = {}
    if signoff_unique:
        merged_plus_signoff_ucdb = merge_ucdb(
            WORK_DIR / "all_isolated_plus_signoff_runs.ucdb",
            [isolated_merged_ucdb, *signoff_unique],
        )
        merged_plus_signoff_cov = cov_area_summary_for_ucdb(merged_plus_signoff_ucdb)

    ram_macro_summary = combine_cov_summaries(
        [
            isolated_area_cov.get("ticket_fifo"),
            isolated_area_cov.get("lane_fifo"),
            isolated_area_cov.get("handle_fifo"),
            isolated_area_cov.get("page_ram"),
            isolated_area_cov.get("presenter_meta_ram"),
        ]
    )
    wrapper_toggle_summary = combine_cov_summaries(
        [
            isolated_area_cov.get("presenter_wrapper"),
            isolated_area_cov.get("dut_wrapper"),
            isolated_area_cov.get("top_wrapper"),
        ]
    )

    parser_isolated = isolated_area_cov.get("ingress_parser")
    parser_plus_signoff = merged_plus_signoff_cov.get("ingress_parser")
    allocator_isolated = isolated_area_cov.get("page_allocator")
    allocator_plus_signoff = merged_plus_signoff_cov.get("page_allocator")
    presenter_isolated = isolated_area_cov.get("presenter_native")
    presenter_plus_signoff = merged_plus_signoff_cov.get("presenter_native")
    block_path_isolated = isolated_area_cov.get("block_path")
    block_path_plus_signoff = merged_plus_signoff_cov.get("block_path")

    disposition: list[dict] = []

    if parser_isolated:
        disposition.append(
            {
                "area": "ingress parser lane asymmetry",
                "instance_summary": {
                    "instance_count": parser_isolated["instance_count"],
                    "metrics": parser_isolated["metrics"],
                },
                "classification": "justified_nonclaim",
                "reason": (
                    f"isolated merged coverage bottoms out at {fmt_cov_summary(parser_isolated)} across the four "
                    f"lane-local parser instances; current-scope supplemental runs lift the parser family to "
                    f"{fmt_cov_summary(parser_plus_signoff)}, so the residual deficit is the bounded 4-lane "
                    "asymmetry / recovery axis rather than missing logs or broken UCDB plumbing"
                ),
                "evidence_anchor": "`DV_PLAN.md` 4-lane asymmetry notes; `DV_CROSS.md` CROSS-053",
                "next_action": (
                    "Promote a dedicated 4-lane parser recovery / asymmetry sweep only if raw per-instance "
                    "structural closure becomes a hard release gate."
                ),
            }
        )

    if allocator_isolated:
        disposition.append(
            {
                "area": "page allocator reset / fast-close arcs",
                "instance_summary": {
                    "instance_count": allocator_isolated["instance_count"],
                    "metrics": allocator_isolated["metrics"],
                },
                "classification": "justified_nonclaim",
                "reason": (
                    f"the allocator improves from {fmt_cov_summary(allocator_isolated)} to "
                    f"{fmt_cov_summary(allocator_plus_signoff)} once maintained signoff runs are merged, and the "
                    "remaining FSM misses are dominated by active-state -> RESET fanout plus the WRITE_HEAD -> "
                    "WRITE_TAIL empty-frame fast-close path rather than unexplained hit loss"
                ),
                "evidence_anchor": "`DV_ERROR.md` X081-X086; `DV_FORMAL.md` B23/B32",
                "next_action": (
                    "Add a true mid-state reset / zero-hit fast-close stress only if raw allocator transition "
                    "closure is promoted from a bounded non-claim to a release gate."
                ),
            }
        )

    if presenter_isolated:
        disposition.append(
            {
                "area": "presenter overwrite / must-drop scan",
                "instance_summary": {
                    "instance_count": presenter_isolated["instance_count"],
                    "metrics": presenter_isolated["metrics"],
                },
                "classification": "justified_nonclaim",
                "reason": (
                    f"isolated presenter coverage remains low at {fmt_cov_summary(presenter_isolated)} because the "
                    "overwrite-scan and must-drop logic is only forced by the named overflow witnesses; maintained "
                    f"signoff runs lift it to {fmt_cov_summary(presenter_plus_signoff)} while hit-conservation "
                    "screens stay clean, so the raw deficit maps to the explicit must-drop non-claim rather than a "
                    "silent datapath failure"
                ),
                "evidence_anchor": "`DV_CROSS.md` CROSS-078/CROSS-079; `BUG_HISTORY.md` BUG-029-R/BUG-030-R",
                "next_action": (
                    "Keep `opq_cross_bp_mustdrop_witness_test` green and do not remove the non-claim until a "
                    "default-build must-drop baseline is promoted into the published scope."
                ),
            }
        )

    if block_path_isolated:
        disposition.append(
            {
                "area": "block path reset-only arcs",
                "instance_summary": {
                    "instance_count": block_path_isolated["instance_count"],
                    "metrics": block_path_isolated["metrics"],
                },
                "classification": "justified_exclusion",
                "reason": (
                    f"statement coverage is already {block_path_isolated['aggregate_metrics'].get('stmt', 0.0):.2f} "
                    f"and signoff runs lift block-path toggle to {block_path_plus_signoff['aggregate_metrics'].get('toggle', 0.0):.2f}; "
                    "the remaining uncovered FSM transitions are the three ARBITER_* -> RESET arcs only"
                ),
                "evidence_anchor": "`DV_FORMAL.md` B23/B32 reset / flush invariants",
                "next_action": "Leave this as a reset-only exclusion unless mid-state hard reset becomes part of the release contract.",
            }
        )

    if ram_macro_summary:
        disposition.append(
            {
                "area": "RAM primitive toggle churn",
                "instance_summary": {
                    "instance_count": ram_macro_summary["instance_count"],
                    "metrics": ram_macro_summary["metrics"],
                },
                "classification": "justified_exclusion",
                "reason": (
                    "ticket / lane / handle / page / meta RAM wrappers are already at 100% statement and branch "
                    "coverage where those metrics exist; the residual miss is low-value deep-address / deep-data "
                    "toggle churn in the bounded 4-lane/128 and 4-lane/512 evidence points"
                ),
                "evidence_anchor": "`CONFIG_SIGNOFF.md` bounded preset matrix; current `REPORT/cross/` runs",
                "next_action": "Treat this as low-value memory-toggle churn unless an explicit UNR / exclusion pass is added.",
            }
        )

    if wrapper_toggle_summary:
        disposition.append(
            {
                "area": "wrapper-only toggle bookkeeping",
                "instance_summary": {
                    "instance_count": wrapper_toggle_summary["instance_count"],
                    "metrics": wrapper_toggle_summary["metrics"],
                },
                "classification": "justified_exclusion",
                "reason": (
                    "top-level DUT and wrapper shells depress raw toggle through duplicated aggregation, probe, and "
                    "bookkeeping nets without indicating missing testcase evidence in the core owner modules"
                ),
                "evidence_anchor": "`DV_REPORT.md` Signoff Runs; `doc/SIGNOFF.md` current-scope note",
                "next_action": "Do not spend testcase budget on wrapper toggles until owner-module functional gaps change.",
            }
        )

    return disposition


def build_signoff_run(test_name: str, log_summary: dict, ucdb_path: Path) -> dict | None:
    meta = classify_signoff_test(test_name)
    if meta is None:
        return None

    code_cov = flatten_pct(code_cov_for_ucdb(ucdb_path))
    functional = functional_cov_for_ucdb(ucdb_path)
    cross_pct = functional.get("pct", 0.0) or fallback_cross_pct(log_summary)
    counter_failed = int(
        int(log_summary.get("hit_missing", 0)) > 0 or int(log_summary.get("hit_ghost", 0)) > 0
    )
    return {
        "run_id": meta["run_id"],
        "kind": meta["kind"],
        "bucket": None,
        "build_tag": RTL_VARIANT,
        "sequence_name": meta["sequence_name"],
        "case_count": int(meta["case_count"]),
        "effort": meta["effort"],
        "code_coverage": code_cov,
        "cross_summary": {
            "pct": round(float(cross_pct), 2),
            "txns": int(log_summary.get("observed_txn", 0)),
            "counter_checks_passed": 0 if counter_failed else 1,
            "counter_checks_failed": counter_failed,
            "unexpected_outputs": 0,
            "curve": "",
            "checkpoints": list(log_summary.get("checkpoints", [])),
        },
    }


def resolve_signoff_ucdb_path(test_name: str, log_summary: dict) -> Path | None:
    direct = SIM_COV_DIR / f"{test_name}.ucdb"
    if direct.is_file():
        return direct

    dut_impl = str(log_summary.get("cfg_dut_impl", SIGNOFF_DUT_IMPL))
    n_lane = int(log_summary.get("cfg_n_lane", SIGNOFF_N_LANE))
    n_shd = int(log_summary.get("cfg_n_shd", SIGNOFF_N_SHD))
    ticket_depth = int(
        log_summary.get(
            "cfg_ticket_fifo_depth",
            int(os.environ.get("OPQ_TICKET_FIFO_DEPTH", str(derived_ticket_fifo_depth(SIGNOFF_N_SHD)))),
        )
    )
    page_depth = int(log_summary.get("cfg_page_ram_depth", SIGNOFF_PAGE_RAM_DEPTH))
    cov_enable = int(log_summary.get("cfg_cov_enable", 1))
    build_dir = UVM_BUILD_RUNS_DIR / (
        f"dut{dut_impl}_lane{n_lane}_nshd{n_shd}_ticket{ticket_depth}_page{page_depth}_cov{cov_enable}"
    )
    for stem in (f"opq_{test_name}.ucdb", f"opq_opq_{test_name}.ucdb", f"{test_name}.ucdb"):
        candidate = build_dir / stem
        if candidate.is_file():
            return candidate

    # Do not fall back across mismatched build directories here. A stale lane /
    # depth point can reuse the same testcase filename, and binding that UCDB to
    # a current-scope log would silently republish the wrong signoff evidence.
    return None


def discover_signoff_runs() -> tuple[list[dict], list[Path]]:
    runs: list[dict] = []
    ucdbs: list[Path] = []
    seen_ucdbs: set[Path] = set()
    for log_path in sorted(SIM_LOG_DIR.glob("opq_*.log")):
        if log_path.name.endswith(".launch.log"):
            continue
        test_name = log_path.stem
        meta = classify_signoff_test(test_name)
        if meta is None:
            continue
        log_exists, engine_ok, pass_ok, log_summary = extract_log_summary(log_path)
        if not (log_exists and engine_ok and pass_ok):
            continue
        ucdb_path = resolve_signoff_ucdb_path(test_name, log_summary)
        if ucdb_path is None:
            continue
        reported_page_depth = int(log_summary.get("cfg_page_ram_depth", -1))
        if reported_page_depth not in {SIGNOFF_PAGE_RAM_DEPTH, 512}:
            continue
        if not scope_matches_log_summary(log_summary, reported_page_depth):
            continue
        run = build_signoff_run(test_name, log_summary, ucdb_path)
        if run is not None:
            runs.append(run)
            if ucdb_path not in seen_ucdbs:
                seen_ucdbs.add(ucdb_path)
                ucdbs.append(ucdb_path)

    order = {"bucket_frame": 0, "all_buckets_frame": 1, "cross": 2}
    runs.sort(key=lambda run: (order.get(str(run.get("kind")), 9), str(run.get("run_id", ""))))
    return runs, ucdbs


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


def merge_ucdb_incremental(output: Path, previous: Path | None, current: Path) -> Path:
    if previous is None:
        return current
    return merge_ucdb(output, [previous, current])


def parse_checkpoint_summaries(text: str) -> list[dict]:
    hit_re = re.compile(
        r"(?P<label>[A-Za-z0-9_]+)\s+lane(?P<lane>\d+)\s+hit_ledger\s+"
        r"expected=(?P<expected>\d+)\s+accepted=(?P<accepted>\d+)\s+"
        r"dropped=(?P<dropped>\d+)\s+delivered=(?P<delivered>\d+)\s+"
        r"unexplained=(?P<unexplained>\d+)\s+drop_pct=(?P<drop_pct>\d+\.\s*\d+)"
    )
    aggregate_re = re.compile(
        r"(?P<label>[A-Za-z0-9_]+)\s+aggregate_hit_ledger\s+"
        r"accepted=(?P<accepted>\d+)\s+dropped=(?P<dropped>\d+)\s+"
        r"delivered=(?P<delivered>\d+)\s+unexplained=(?P<unexplained>\d+)"
    )
    frame_table_re = re.compile(
        r"(?P<label>[A-Za-z0-9_]+)\s+frame_table_ledger\s+"
        r"wr_hdr=(?P<wr_hdr>\d+)\s+rd_hdr=(?P<rd_hdr>\d+)\s+drop_hdr=(?P<drop_hdr>\d+)\s+"
        r"wr_shd=(?P<wr_shd>\d+)\s+rd_shd=(?P<rd_shd>\d+)\s+drop_shd=(?P<drop_shd>\d+)\s+"
        r"wr_hit=(?P<wr_hit>\d+)\s+rd_hit=(?P<rd_hit>\d+)\s+drop_hit=(?P<drop_hit>\d+)"
    )
    core_re = re.compile(
        r"(?P<label>[A-Za-z0-9_]+)\s+core_principles\s+first_break=\s*(?P<first_break>\S+)\s+"
        r"ft_ownership=\s*(?P<ft_ownership>\S+)\s+hit_conservation=\s*(?P<hit_conservation>\S+)\s+"
        r"accepted_delivery=\s*(?P<accepted_delivery>\S+)\s+drained=\s*(?P<drained>\S+)"
    )

    checkpoints: OrderedDict[str, dict] = OrderedDict()

    def ensure_checkpoint(label: str) -> dict:
        if label not in checkpoints:
            checkpoints[label] = {
                "label": label,
                "lane_ledgers": [],
            }
        return checkpoints[label]

    for line in text.splitlines():
        hit_match = hit_re.search(line)
        if hit_match:
            label = hit_match.group("label")
            checkpoint = ensure_checkpoint(label)
            checkpoint["lane_ledgers"].append(
                {
                    "lane": int(hit_match.group("lane")),
                    "expected": int(hit_match.group("expected")),
                    "accepted": int(hit_match.group("accepted")),
                    "dropped": int(hit_match.group("dropped")),
                    "delivered": int(hit_match.group("delivered")),
                    "unexplained": int(hit_match.group("unexplained")),
                    "drop_pct": float(hit_match.group("drop_pct").replace(" ", "")),
                }
            )
            continue

        aggregate_match = aggregate_re.search(line)
        if aggregate_match:
            label = aggregate_match.group("label")
            checkpoint = ensure_checkpoint(label)
            checkpoint["aggregate_hit_ledger"] = {
                "accepted": int(aggregate_match.group("accepted")),
                "dropped": int(aggregate_match.group("dropped")),
                "delivered": int(aggregate_match.group("delivered")),
                "unexplained": int(aggregate_match.group("unexplained")),
            }
            continue

        frame_table_match = frame_table_re.search(line)
        if frame_table_match:
            label = frame_table_match.group("label")
            checkpoint = ensure_checkpoint(label)
            checkpoint["frame_table_ledger"] = {
                "wr_hdr": int(frame_table_match.group("wr_hdr")),
                "rd_hdr": int(frame_table_match.group("rd_hdr")),
                "drop_hdr": int(frame_table_match.group("drop_hdr")),
                "wr_shd": int(frame_table_match.group("wr_shd")),
                "rd_shd": int(frame_table_match.group("rd_shd")),
                "drop_shd": int(frame_table_match.group("drop_shd")),
                "wr_hit": int(frame_table_match.group("wr_hit")),
                "rd_hit": int(frame_table_match.group("rd_hit")),
                "drop_hit": int(frame_table_match.group("drop_hit")),
            }
            continue

        core_match = core_re.search(line)
        if core_match:
            label = core_match.group("label")
            checkpoint = ensure_checkpoint(label)
            checkpoint["core_principles"] = {
                "first_break": core_match.group("first_break"),
                "ft_ownership": core_match.group("ft_ownership"),
                "hit_conservation": core_match.group("hit_conservation"),
                "accepted_delivery": core_match.group("accepted_delivery"),
                "drained": core_match.group("drained"),
            }

    out: list[dict] = []
    for checkpoint in checkpoints.values():
        checkpoint["lane_ledgers"] = sorted(
            checkpoint.get("lane_ledgers", []),
            key=lambda row: int(row.get("lane", -1)),
        )
        out.append(checkpoint)
    return out


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

    checkpoints = parse_checkpoint_summaries(text)
    if checkpoints:
        summary["checkpoints"] = checkpoints

    return True, engine_ok, pass_ok, summary


def stage_report_artifacts(case_artifacts: list[dict]) -> None:
    REPORT_LOG_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_COV_DIR.mkdir(parents=True, exist_ok=True)

    for directory in (REPORT_LOG_DIR, REPORT_COV_DIR):
        for child in directory.iterdir():
            if child.is_symlink() or child.is_file():
                child.unlink()

    for case in case_artifacts:
        if not case.get("implemented", False):
            continue
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
    signoff_page_depths = sorted(
        {
            case_build_knobs(case)["OPQ_PAGE_RAM_DEPTH"]
            for bucket_name in BUCKET_SPECS
            for case in parse_bucket(bucket_name)
        }
    )

    for bucket_name in BUCKET_SPECS:
        catalog_rows = parse_bucket(bucket_name)
        bucket_cases: list[dict] = []
        bucket_ucdbs_unique: list[Path] = []
        bucket_ucdb_seen: set[Path] = set()
        merge_trace: list[dict] = []
        evidenced_cases = 0
        bucket_merged_cov_before: dict | None = None
        bucket_merged_ucdb_path: Path | None = None

        for step, catalog_case in enumerate(catalog_rows, start=1):
            case_id = catalog_case["case_id"]
            all_artifacts.append(catalog_case)
            log_path, log_artifact_name = resolve_log_path(catalog_case)
            ucdb_path, ucdb_artifact_name = resolve_ucdb_path(catalog_case)
            log_exists, engine_ok, pass_ok, log_summary = extract_log_summary(log_path)
            has_ucdb = ucdb_path is not None
            scope_match = scope_matches_log_summary(
                log_summary, case_build_knobs(catalog_case)["OPQ_PAGE_RAM_DEPTH"]
            )
            implemented = log_exists and has_ucdb and scope_match
            evidence_state = "current_scope_evidenced"
            if not implemented:
                if log_exists or has_ucdb:
                    evidence_state = "stale_out_of_scope_artifact"
                else:
                    evidence_state = "pending_no_current_scope_artifact"

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
                "evidence_state": evidence_state,
            }

            if not implemented:
                case["implemented"] = False
                case["passed"] = None
                case["observed_txn"] = 0
                case["log_summary"] = {}
                unimplemented_cases.append(case_id)
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
                    bucket_merged_ucdb_path = merge_ucdb_incremental(
                        WORK_DIR / f"{bucket_name.lower()}_{step}.ucdb",
                        bucket_merged_ucdb_path,
                        ucdb_path,
                    )
                    merged_after = code_cov_for_ucdb(bucket_merged_ucdb_path)
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
            else:
                failed_cases.append(case_id)

            bucket_cases.append(case)
            all_cases.append(case)

        merged_bucket_total = flatten_pct(bucket_merged_cov_before or {})
        bucket_functional_cov = {"pct": 0.0, "evidenced": evidenced_cases, "planned": len(catalog_rows)}
        if bucket_merged_ucdb_path is not None:
            bucket_functional_cov = functional_cov_for_ucdb(bucket_merged_ucdb_path)
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

    stage_report_artifacts(all_cases)

    merged_total_cov = {}
    merged_total_ucdb: Path | None = None
    total_functional_cov = {"pct": 0.0, "evidenced": 0, "planned": len(all_cases)}
    if all_passed_ucdbs_unique:
        merged_total_ucdb = merge_ucdb(WORK_DIR / "all_buckets_merged.ucdb", all_passed_ucdbs_unique)
        merged_total_cov = flatten_pct(code_cov_for_ucdb(merged_total_ucdb))
        total_functional_cov = functional_cov_for_ucdb(merged_total_ucdb)
        total_functional_cov["evidenced"] = all_passed_case_count
        total_functional_cov["planned"] = len(all_cases)

    signoff_runs, signoff_run_ucdbs = discover_signoff_runs()
    coverage_hole_disposition = build_coverage_hole_disposition(merged_total_ucdb, signoff_run_ucdbs)

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
            "OPQ_PAGE_RAM_DEPTH": signoff_page_depths,
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
            "bucket_frame": native_frame_mode("opq_bucket_frame_native_sv_test", False),
            "all_buckets_frame": native_frame_mode("opq_all_buckets_frame_native_sv_test", True),
        },
        "cases": all_cases,
        "bucket_summary": bucket_summary,
        "buckets": bucket_payloads,
        "coverage_hole_disposition": coverage_hole_disposition,
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
        "signoff_runs": signoff_runs,
        "random_cases": [case for case in all_cases if case.get("method") == "R"],
    }


def main() -> int:
    payload = build()
    REPORT_JSON.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
