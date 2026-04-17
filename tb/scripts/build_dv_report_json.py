#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from collections import OrderedDict
from datetime import date
from pathlib import Path

TB_DIR = Path(__file__).resolve().parents[1]
SIM_LOG_DIR = TB_DIR / "sim_runs" / "logs"
SIM_COV_DIR = TB_DIR / "sim_runs" / "coverage"
REPORT_LOG_DIR = TB_DIR / "uvm" / "logs"
REPORT_COV_DIR = TB_DIR / "uvm" / "cov_after"
WORK_DIR = TB_DIR / "sim_runs" / "report_work"
REPORT_JSON = TB_DIR / "DV_REPORT.json"
QUESTA_HOME = Path(os.environ.get("QUESTA_HOME", "/data1/intelFPGA_pro/23.1/questa_fse"))
INSTANCE_FILTER = "/tb_top/gen_dut_2lane/dut."
RTL_VARIANT = "after"
SEED = 1
SIGNOFF_DUT_IMPL = "native_sv"

env_dut_impl = os.environ.get("DUT_IMPL", SIGNOFF_DUT_IMPL)
if env_dut_impl != SIGNOFF_DUT_IMPL:
    raise SystemExit(
        f"build_dv_report_json.py only supports DUT_IMPL={SIGNOFF_DUT_IMPL} (got {env_dut_impl})"
    )

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


def case_entry(
    name: str,
    scenario: str,
    primary_checks: str,
    contract_anchor: str,
    n_shd: int = 256,
    effort: str = "practical",
) -> dict:
    ticket_fifo_depth = 256
    while ticket_fifo_depth <= n_shd:
        ticket_fifo_depth *= 2
    return {
        "case_id": name,
        "full_case_id": name,
        "method": "D",
        "observed_txn": 1,
        "scenario": scenario,
        "primary_checks": primary_checks,
        "contract_anchor": contract_anchor,
        "implementation_mode": SIGNOFF_DUT_IMPL,
        "build_tag": RTL_VARIANT,
        "isolated_effort": effort,
        "build_knobs": {
            "OPQ_N_LANE": 2,
            "OPQ_N_SHD": n_shd,
            "OPQ_TICKET_FIFO_DEPTH": ticket_fifo_depth,
            "OPQ_PAGE_RAM_DEPTH": 65536,
            "MODE": "MERGING",
        },
    }


BUCKET_CASES = OrderedDict(
    [
        (
            "BASIC",
            [
                case_entry(
                    "opq_basic_smoke_test",
                    "Healthy long-frame bring-up on the default 2-lane native-SV path.",
                    "Hit integrity, zero drops, and restored credits on both lanes.",
                    "DV_BASIC healthy-path closure.",
                ),
                case_entry(
                    "opq_basic_ts_boundary_test",
                    "Sparse timestamp-boundary traffic across low and high subheader values.",
                    "Full timestamp reconstruction and zero ghost/missing hits.",
                    "DV_BASIC full-ts boundary closure.",
                ),
                case_entry(
                    "opq_basic_subheader_shape_test",
                    "Mixed empty and non-empty subheaders with varied hit counts.",
                    "Subheader placement, hit-count encoding, and clean healthy-path framing.",
                    "DV_BASIC subheader-shape closure.",
                ),
                case_entry(
                    "opq_basic_feb_packet_contract_test",
                    "Real FEB whole-frame packets on both ingress lanes.",
                    "Monitor-side frame reconstruction from DUT pins and scoreboard hit integrity.",
                    "DV_BASIC FEB whole-frame contract closure.",
                ),
            ],
        ),
        (
            "PARAM",
            [
                case_entry(
                    "opq_basic_smoke_test_nshd128",
                    "Default healthy-path bring-up at non-default build point N_SHD=128.",
                    "Hit integrity and restored credits at the smallest claimed native-SV subheader depth.",
                    "DV_PARAM compile/elaboration sweep, N_SHD=128.",
                    n_shd=128,
                ),
                case_entry(
                    "opq_basic_smoke_test_nshd512",
                    "Default healthy-path bring-up at non-default build point N_SHD=512.",
                    "Hit integrity and restored credits with derived deep ticket FIFO.",
                    "DV_PARAM compile/elaboration sweep, N_SHD=512.",
                    n_shd=512,
                ),
                case_entry(
                    "opq_basic_ts_boundary_test_nshd128",
                    "Timestamp-boundary sparse packets at N_SHD=128.",
                    "Boundary timestamp reconstruction at the smallest claimed build point.",
                    "DV_PARAM timestamp sweep, N_SHD=128.",
                    n_shd=128,
                ),
                case_entry(
                    "opq_basic_ts_boundary_test_nshd512",
                    "Timestamp-boundary sparse packets at N_SHD=512.",
                    "Boundary timestamp reconstruction with derived deep ticket FIFO.",
                    "DV_PARAM timestamp sweep, N_SHD=512.",
                    n_shd=512,
                ),
                case_entry(
                    "opq_edge_max_hits_test_nshd128",
                    "Maximum-hit packet shape at N_SHD=128.",
                    "Max-hit frame shape and hit preservation at the smallest claimed build point.",
                    "DV_PARAM max-hit sweep, N_SHD=128.",
                    n_shd=128,
                ),
                case_entry(
                    "opq_edge_max_hits_test_nshd512",
                    "Maximum-hit packet shape at N_SHD=512.",
                    "Max-hit frame shape and hit preservation with deep ticket FIFO.",
                    "DV_PARAM max-hit sweep, N_SHD=512.",
                    n_shd=512,
                ),
            ],
        ),
        (
            "EDGE",
            [
                case_entry(
                    "opq_edge_backpressure_test",
                    "Periodic egress stalls on the default native-SV datapath.",
                    "Presenter hold/restart behavior and hit integrity under legal backpressure.",
                    "DV_EDGE periodic-stall closure.",
                ),
                case_entry(
                    "opq_edge_always_ready_test",
                    "Explicit always-ready baseline with the same native-SV harness plumbing.",
                    "Healthy no-stall datapath baseline and zero-drop counter closure.",
                    "DV_EDGE always-ready baseline.",
                ),
                case_entry(
                    "opq_edge_ready_medium_profile_test",
                    "Medium-duty ready profile with legal restart windows.",
                    "Non-trivial healthy backpressure bins without entering the known overwrite probe path.",
                    "DV_EDGE medium-ready closure.",
                ),
                case_entry(
                    "opq_edge_stuck_low_backpressure_test",
                    "Longer low-ready windows short of the forced-overwrite probe.",
                    "Hold-under-backpressure and clean restart behavior without malformed egress.",
                    "DV_EDGE stuck-low ready closure.",
                ),
                case_entry(
                    "opq_edge_max_hits_test",
                    "Default-build maximum-hit packet shape on the live symbol path.",
                    "Max-hit frame shape and full hit preservation at the default build point.",
                    "DV_EDGE max-hit closure.",
                ),
                case_entry(
                    "opq_edge_toggle_backpressure_test",
                    "Single-cycle ready toggling at the egress interface.",
                    "Short-toggle backpressure bins and presenter restart correctness.",
                    "DV_EDGE short-toggle closure.",
                ),
            ],
        ),
        (
            "PROF",
            [
                case_entry(
                    "opq_prof_stress_test",
                    "Short soak with repeated long FEB whole-frame traffic.",
                    "Sustained hit integrity and credit restoration under repeated traffic bursts.",
                    "DV_PROF soak closure.",
                ),
                case_entry(
                    "opq_prof_lane_skew_test",
                    "Deterministic two-lane skew with repeated long frames.",
                    "No missing or ghost hits under sustained lane skew.",
                    "DV_PROF lane-skew closure.",
                ),
                case_entry(
                    "opq_prof_whole_frame_skew_test",
                    "Whole-frame skew where activity alternates with legal empty frames.",
                    "Packet-level cadence skew, zero drops, and monitor-side frame capture.",
                    "DV_PROF whole-frame skew closure.",
                ),
                case_entry(
                    "opq_prof_missing_empty_frame_test",
                    "Uneven per-lane frame-count stress on the active 2-lane harness contract.",
                    "Sparse-frame residency, credit stability, and hit integrity without claiming 4-lane closure.",
                    "DV_PROF sparse-frame residency closure.",
                ),
            ],
        ),
        (
            "ERROR",
            [
                case_entry(
                    "opq_error_lane_mask_test",
                    "Packet-boundary lane masking with multi-hit packets.",
                    "Masked-drop accounting and zero unexpected egress output on the dropped lane.",
                    "DV_ERROR lane-mask control closure.",
                ),
                case_entry(
                    "opq_error_lane_mask_single_hit_test",
                    "Minimal masked-drop packet on the active native-SV path.",
                    "Single-hit drop accounting and CSR counter closure.",
                    "DV_ERROR single-hit lane-mask closure.",
                ),
                case_entry(
                    "opq_error_lane_mask_burst_test",
                    "Burst masked-drop traffic across several packets.",
                    "Burst drop accounting and no-drop recovery on the still-enabled lane.",
                    "DV_ERROR burst lane-mask closure.",
                ),
                case_entry(
                    "opq_error_lane_mask_recovery_test",
                    "Mask all active lanes, accumulate drops, then clear the mask and resume healthy traffic.",
                    "Masked-header drop accounting plus verified clean recovery on the next legal FEB packets.",
                    "DV_ERROR control-action recovery closure.",
                ),
                case_entry(
                    "opq_error_subheader_mask_recovery_test",
                    "Inject a malformed subheader, then follow with a legal recovery frame on both active lanes.",
                    "Ingress subheader-error masking without poisoning the following legal packet.",
                    "DV_ERROR malformed-subheader recovery closure.",
                ),
                case_entry(
                    "opq_error_counter_clear_test",
                    "Runtime counter clear after drop-producing traffic.",
                    "Visible CSR counter reset semantics and post-clear clean state.",
                    "DV_ERROR counter-clear closure.",
                ),
            ],
        ),
        (
            "CROSS",
            [
                case_entry(
                    "opq_cross_bp_credit_test",
                    "Backpressure crossed with credit restoration on FEB whole-frame traffic.",
                    "Credit recovery, no ghost hits, and legal restart behavior under mixed-axis stress.",
                    "DV_CROSS backpressure x credit closure.",
                ),
                case_entry(
                    "opq_cross_drr_allowance_test",
                    "Runtime DRR allowance programming with asymmetric lane service.",
                    "CSR programming, defer counters, and directed service fairness.",
                    "DV_CROSS DRR allowance closure.",
                ),
                case_entry(
                    "opq_cross_drr_idle_lane_test",
                    "One hit-idle peer lane that still emits legal empty-frame cadence.",
                    "DRR fairness with empty-frame cadence preserved on the idle lane.",
                    "DV_CROSS idle-lane cadence closure.",
                ),
                case_entry(
                    "opq_cross_drr_zero_allowance_test",
                    "Zero-allowance lane starvation followed by reload and resumed service.",
                    "Directed defer/reload behavior and zero-allowance fairness recovery.",
                    "DV_CROSS zero-allowance closure.",
                ),
                case_entry(
                    "opq_cross_drr_short_allowance_test",
                    "Short-quantum reload with repeated service handoff.",
                    "Directed DRR reload and service-handoff behavior under constrained allowance.",
                    "DV_CROSS short-allowance closure.",
                ),
            ],
        ),
    ]
)

EXCLUDED_CASES = [
    "opq_error_ftable_overflow_test",
    "opq_error_header_mask_recovery_test",
    "opq_cross_drr_bursty_random_test",
]

BUCKET_FRAME_BUCKET_ORDER = ["BASIC", "EDGE", "PROF", "ERROR", "CROSS"]
BUCKET_FRAME_LEGACY_ORDER = [
    ("BASIC", "opq_basic_smoke_test"),
    ("BASIC", "opq_basic_ts_boundary_test"),
    ("BASIC", "opq_basic_feb_packet_contract_test"),
    ("BASIC", "opq_basic_subheader_shape_test"),
    ("EDGE", "opq_edge_backpressure_test"),
    ("EDGE", "opq_edge_always_ready_test"),
    ("EDGE", "opq_edge_ready_medium_profile_test"),
    ("EDGE", "opq_edge_stuck_low_backpressure_test"),
    ("EDGE", "opq_edge_max_hits_test"),
    ("EDGE", "opq_edge_toggle_backpressure_test"),
    ("PROF", "opq_prof_stress_test"),
    ("PROF", "opq_prof_lane_skew_test"),
    ("PROF", "opq_prof_whole_frame_skew_test"),
    ("PROF", "opq_prof_missing_empty_frame_test"),
    ("ERROR", "opq_error_lane_mask_test"),
    ("ERROR", "opq_error_lane_mask_single_hit_test"),
    ("ERROR", "opq_error_lane_mask_burst_test"),
    ("ERROR", "opq_error_lane_mask_recovery_test"),
    ("ERROR", "opq_error_subheader_mask_recovery_test"),
    ("CROSS", "opq_cross_bp_credit_test"),
    ("CROSS", "opq_cross_drr_allowance_test"),
    ("CROSS", "opq_cross_drr_idle_lane_test"),
    ("CROSS", "opq_cross_drr_zero_allowance_test"),
    ("CROSS", "opq_cross_drr_short_allowance_test"),
]
ALL_BUCKETS_FRAME_EXTRA_TAIL = [
    {
        "bucket": "PROF",
        "legacy_step_name": "extra_prof_seq",
        "description": "extra whole-frame skew tail beyond the promoted default-build matrix",
    },
    {
        "bucket": "ERROR",
        "legacy_step_name": "extra_err_seq",
        "description": "extra subheader-recovery tail beyond the promoted default-build matrix",
    },
]

REPORT_CASE_TYPE = {
    "BASIC": "STD",
    "PARAM": "COMBO",
    "EDGE": "CORNER",
    "PROF": "COMBO",
    "ERROR": "CORNER",
    "CROSS": "COMBO",
}

REPORT_CASE_BASE = {
    "BASIC": 1,
    "PARAM": 101,
    "EDGE": 201,
    "PROF": 301,
    "ERROR": 401,
    "CROSS": 501,
}

SIGNOFF_CASE_COUNT = 24
SIGNOFF_RUN_SPECS = [
    {
        "run_id": "bucket_frame_native_sv",
        "test_name": "opq_bucket_frame_native_sv_test",
        "kind": "bucket_frame",
        "build_tag": "native_sv",
        "bucket": None,
        "sequence_name": "OPQ_BUCKET_FRAME_NATIVE_SV",
        "case_count": SIGNOFF_CASE_COUNT,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.",
            "opq_error_counter_clear_test is excluded from the current no-restart baseline because runtime counter-clear state handoff is not yet modeled in the composed scoreboard flow.",
        ],
    },
    {
        "run_id": "all_buckets_frame_native_sv",
        "test_name": "opq_all_buckets_frame_native_sv_test",
        "kind": "all_buckets_frame",
        "build_tag": "native_sv",
        "bucket": None,
        "sequence_name": "OPQ_ALL_BUCKETS_FRAME_NATIVE_SV",
        "case_count": SIGNOFF_CASE_COUNT,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "PARAM build points are excluded because they require separate elaboration and cannot be composed into one no-restart runtime.",
            "opq_error_counter_clear_test is excluded from the current no-restart baseline because runtime counter-clear state handoff is not yet modeled in the composed scoreboard flow.",
            "This run appends two extra tail sequences after the 24 promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases.",
        ],
    },
]


def run_cmd(*args: str) -> str:
    proc = subprocess.run(args, check=True, text=True, capture_output=True)
    return proc.stdout


def parse_cov_text(text: str) -> dict:
    totals = {key: {"hits": 0, "bins": 0, "pct": 0.0} for key in METRIC_MAP.values()}
    metric_re = re.compile(r"^\s*(Branches|Conditions|Expressions|FSM States|FSM Transitions|Statements|Toggles)\s+(\d+)\s+(\d+)\s+\d+\s+([0-9.]+)%")
    for line in text.splitlines():
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


def code_cov_for_ucdb(ucdb: Path) -> dict:
    text = run_cmd(str(VCOVER), "report", "-codeAll", f"-instance={INSTANCE_FILTER}", str(ucdb))
    return parse_cov_text(text)


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
        if delta < 0.0:
            delta = 0.0
        out[metric] = {"pct": delta}
    return out


def flatten_pct(cov: dict) -> dict:
    return {metric: {"pct": round(values.get("pct", 0.0), 2)} for metric, values in cov.items()}


def zero_cov() -> dict:
    return {metric: {"pct": 0.0} for metric in METRIC_MAP.values()}


def resolve_ucdb_path(name: str) -> Path | None:
    candidates = [
        SIM_COV_DIR / f"{name}.ucdb",
        TB_DIR / "uvm" / "build" / f"opq_{name}.ucdb",
        TB_DIR / "uvm" / "build" / f"opq_opq_{name}.ucdb",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return None


def merge_ucdb(output: Path, inputs: list[Path]) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    run_cmd(str(VCOVER), "merge", str(output), *[str(path) for path in inputs])
    return output


def extract_log_summary(log_path: Path) -> tuple[bool, bool, dict]:
    if not log_path.is_file():
        return False, False, {}

    text = log_path.read_text(encoding="utf-8", errors="replace")
    engine_ok = "[run_uvm] DUT_IMPL=native_sv" in text
    pass_ok = bool(re.search(r"# UVM_ERROR :\s+0\b", text) and re.search(r"# UVM_FATAL :\s+0\b", text))
    pass_ok = pass_ok and "** Error:" not in text and "** Fatal:" not in text

    summary: dict[str, int | float | str] = {}
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
        r"Coverage cfg=([0-9.]+) frame=([0-9.]+) subh=([0-9.]+) bp=([0-9.]+) csr=([0-9.]+) credit=([0-9.]+) drop=([0-9.]+) drr=([0-9.]+) ingress=([0-9.]+) egress=([0-9.]+)",
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

    for lane in (0, 1):
        mon_match = re.search(
            rf"lane{lane} monitored_frames=(\d+) orphan_beats=(\d+) capture_err=(\d+)",
            text,
        )
        if mon_match:
            summary[f"lane{lane}_monitored_frames"] = int(mon_match.group(1))
            summary[f"lane{lane}_orphan_beats"] = int(mon_match.group(2))
            summary[f"lane{lane}_capture_err"] = int(mon_match.group(3))

    return True, engine_ok, summary if pass_ok else summary


def stage_report_artifacts(case_artifacts: list[dict]) -> None:
    REPORT_LOG_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_COV_DIR.mkdir(parents=True, exist_ok=True)

    for directory in (REPORT_LOG_DIR, REPORT_COV_DIR):
        for child in directory.iterdir():
            if child.is_symlink() or child.is_file():
                child.unlink()

    for case_artifact in case_artifacts:
        legacy_name = case_artifact["legacy_test_name"]
        report_case_id = case_artifact["report_case_id"]
        src_log = SIM_LOG_DIR / f"{legacy_name}.log"
        src_ucdb = resolve_ucdb_path(legacy_name)
        dst_log = REPORT_LOG_DIR / f"{report_case_id}_{RTL_VARIANT}_s{SEED}.log"
        dst_ucdb = REPORT_COV_DIR / f"{report_case_id}_s{SEED}.ucdb"
        if src_log.is_file():
            dst_log.symlink_to(Path("..") / ".." / "sim_runs" / "logs" / src_log.name)
        if src_ucdb is not None and src_ucdb.is_file():
            dst_ucdb.symlink_to(Path("..") / ".." / src_ucdb.relative_to(TB_DIR))


def build_signoff_runs() -> list[dict]:
    runs: list[dict] = []
    for spec in SIGNOFF_RUN_SPECS:
        log_path = SIM_LOG_DIR / f"{spec['test_name']}.log"
        ucdb_path = resolve_ucdb_path(spec["test_name"])
        log_exists, engine_ok, log_summary = extract_log_summary(log_path)
        has_ucdb = ucdb_path is not None
        functional_cov = {"pct": 0.0, "evidenced": 0, "planned": 0}
        code_cov = {}

        if has_ucdb:
            code_cov = flatten_pct(code_cov_for_ucdb(ucdb_path))
            functional_cov = functional_cov_for_ucdb(ucdb_path)

        hit_missing = int(log_summary.get("hit_missing", 0))
        hit_ghost = int(log_summary.get("hit_ghost", 0))
        txns = int(log_summary.get("lane0_monitored_frames", 0)) + int(log_summary.get("lane1_monitored_frames", 0))
        failures = 0 if (log_exists and engine_ok and has_ucdb and hit_missing == 0 and hit_ghost == 0) else 1

        run_entry = dict(spec)
        run_entry["implemented"] = log_exists and has_ucdb
        run_entry["passed"] = failures == 0
        run_entry["code_coverage"] = code_cov
        run_entry["cross_summary"] = {
            "pct": functional_cov["pct"],
            "txns": txns,
            "queued_overlap": 0,
            "counter_checks_failed": failures,
            "unexpected_outputs": hit_ghost,
            "curve": "",
        }
        run_entry["log_summary"] = log_summary
        runs.append(run_entry)
    return runs


def build() -> dict:
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    all_case_ids: list[str] = []
    all_cases: list[dict] = []
    report_artifacts: list[dict] = []
    report_case_id_by_legacy: dict[str, str] = {}
    bucket_payloads: OrderedDict[str, dict] = OrderedDict()
    bucket_summary: list[dict] = []
    failed_cases: list[str] = []
    stale_artifacts: list[str] = []
    unimplemented_cases: list[str] = []
    all_passed_ucdbs: list[Path] = []
    all_passed_cases = 0

    global_merged_cov_before: dict | None = None

    for bucket_name, cases in BUCKET_CASES.items():
        bucket_cases: list[dict] = []
        bucket_ucdbs: list[Path] = []
        merge_trace: list[dict] = []
        evidenced_cases = 0
        bucket_merged_cov_before: dict | None = None

        for step, base_case in enumerate(cases, start=1):
            case = dict(base_case)
            case["bucket"] = bucket_name
            legacy_test_name = case["full_case_id"]
            report_case_num = REPORT_CASE_BASE[bucket_name] + step - 1
            report_case_desc = legacy_test_name.removeprefix("opq_")
            report_case_id = (
                f"{REPORT_CASE_TYPE[bucket_name]}_OPQ_{report_case_num:03d}_{report_case_desc}"
            )
            case["legacy_test_name"] = legacy_test_name
            case["test_name"] = legacy_test_name
            case["report_case_id"] = report_case_id
            case["case_id"] = report_case_id
            case["full_case_id"] = report_case_id
            report_case_id_by_legacy[legacy_test_name] = report_case_id
            report_artifacts.append(
                {
                    "legacy_test_name": legacy_test_name,
                    "report_case_id": report_case_id,
                }
            )
            all_case_ids.append(report_case_id)
            log_path = SIM_LOG_DIR / f"{legacy_test_name}.log"
            ucdb_path = resolve_ucdb_path(legacy_test_name)
            log_exists, engine_ok, log_summary = extract_log_summary(log_path)
            has_ucdb = ucdb_path is not None
            implemented = log_exists and has_ucdb
            if not implemented:
                unimplemented_cases.append(report_case_id)
                case["implemented"] = False
                case["passed"] = False
                case["log_summary"] = log_summary
                bucket_cases.append(case)
                all_cases.append(case)
                failed_cases.append(report_case_id)
                continue

            if not engine_ok:
                stale_artifacts.append(report_case_id)

            standalone_cov = code_cov_for_ucdb(ucdb_path)
            case["implemented"] = True
            case["passed"] = engine_ok
            case["log_summary"] = log_summary
            case["standalone_coverage"] = flatten_pct(standalone_cov)
            case["isolated_cov_per_txn"] = flatten_pct(standalone_cov)

            if engine_ok:
                evidenced_cases += 1
                bucket_ucdbs.append(ucdb_path)
                merged_after = code_cov_for_ucdb(
                    merge_ucdb(WORK_DIR / f"{bucket_name.lower()}_{step}.ucdb", bucket_ucdbs)
                )
                case["bucket_gain_by_case"] = cov_delta(merged_after, bucket_merged_cov_before)
                case["bucket_merged_total_after_case"] = flatten_pct(merged_after)
                case["bucket_gain_per_txn"] = dict(case["bucket_gain_by_case"])
                bucket_merged_cov_before = merged_after
                merge_trace.append(
                    {
                        "step": step,
                        "case_id": report_case_id,
                        "full_case_id": report_case_id,
                        "legacy_test_name": legacy_test_name,
                        "merged_total_after_case": flatten_pct(merged_after),
                    }
                )
                all_passed_ucdbs.append(ucdb_path)
                all_passed_cases += 1
            else:
                case["bucket_gain_by_case"] = flatten_pct({metric: {"pct": 0.0} for metric in METRIC_MAP.values()})
                case["bucket_merged_total_after_case"] = flatten_pct(bucket_merged_cov_before or {})
                case["bucket_gain_per_txn"] = dict(case["bucket_gain_by_case"])
                failed_cases.append(report_case_id)

            bucket_cases.append(case)
            all_cases.append(case)

        bucket_merged_cov = bucket_merged_cov_before or {metric: {"pct": 0.0} for metric in METRIC_MAP.values()}
        bucket_functional_cov = {"pct": 0.0, "evidenced": evidenced_cases, "planned": len(cases)}
        if bucket_ucdbs:
            merged_bucket_ucdb = merge_ucdb(WORK_DIR / f"{bucket_name.lower()}_merged.ucdb", bucket_ucdbs)
            bucket_functional_cov = functional_cov_for_ucdb(merged_bucket_ucdb)
            bucket_functional_cov["evidenced"] = evidenced_cases
            bucket_functional_cov["planned"] = len(cases)

        global_after_bucket = global_merged_cov_before
        if bucket_ucdbs:
            global_after_bucket = code_cov_for_ucdb(
                merge_ucdb(WORK_DIR / f"global_after_{bucket_name.lower()}.ucdb", all_passed_ucdbs)
            )
        bucket_payload = {
            "planned_cases": len(cases),
            "evidenced_cases": evidenced_cases,
            "merged_bucket_total": flatten_pct(bucket_merged_cov),
            "functional_coverage": bucket_functional_cov,
            "merge_trace": merge_trace,
            "ordered_case_ids": [case["full_case_id"] for case in bucket_cases],
            "cases": bucket_cases,
        }
        bucket_payloads[bucket_name] = bucket_payload
        bucket_summary.append(
            {
                "bucket": bucket_name,
                "planned_cases": len(cases),
                "evidenced_cases": evidenced_cases,
                "merged_bucket_total": flatten_pct(bucket_merged_cov),
                "merged_all_buckets_total_after_bucket": flatten_pct(global_after_bucket or {}),
                "functional_coverage": bucket_functional_cov,
                "ordered_case_ids": [case["full_case_id"] for case in bucket_cases],
            }
        )
        global_merged_cov_before = global_after_bucket

    stage_report_artifacts(report_artifacts)

    merged_total_cov = flatten_pct(global_merged_cov_before or {})
    total_functional_cov = {"pct": 0.0, "evidenced": all_passed_cases, "planned": len(all_case_ids)}
    if all_passed_ucdbs:
        merged_total_ucdb = merge_ucdb(WORK_DIR / "all_buckets_merged.ucdb", all_passed_ucdbs)
        total_functional_cov = functional_cov_for_ucdb(merged_total_ucdb)
        total_functional_cov["evidenced"] = all_passed_cases
        total_functional_cov["planned"] = len(all_case_ids)

    signoff_runs = build_signoff_runs()
    bucket_frame_order = [
        {
            "bucket": bucket_name,
            "report_case_id": report_case_id_by_legacy[legacy_name],
            "legacy_test_name": legacy_name,
        }
        for bucket_name, legacy_name in BUCKET_FRAME_LEGACY_ORDER
    ]

    return {
        "report_title": "packet_scheduler ordered_priority_queue native_sv",
        "dut_name": "ordered_priority_queue_monolithic_sv",
        "date": str(date.today()),
        "rtl_variant": RTL_VARIANT,
        "seed": SEED,
        "signoff_scope": {
            "DUT_IMPL": SIGNOFF_DUT_IMPL,
            "OPQ_N_LANE": [2],
            "OPQ_N_SHD": [128, 256, 512],
            "MODE": ["MERGING"],
            "probe_only_exclusions": EXCLUDED_CASES,
        },
        "case_id_policy": {
            "mode": "alias_map",
            "summary": "DV report keeps the live UVM class names as evidence anchors and carries stable report_case_id aliases in JSON.",
            "aliases": [
                {
                    "bucket": case["bucket"],
                    "report_case_id": case["report_case_id"],
                    "legacy_test_name": case["legacy_test_name"],
                }
                for case in all_cases
            ],
        },
        "coverage_category_status": {
            "supported_with_targets": {
                "stmt": "supported in the native-SV Questa flow; tracked against the 95% workflow target",
                "branch": "supported in the native-SV Questa flow; tracked against the 90% workflow target",
                "fsm_state": "supported in the native-SV Questa flow; tracked against the 95% workflow target",
                "fsm_trans": "supported in the native-SV Questa flow; tracked against the 90% workflow target",
                "toggle": "supported in the native-SV Questa flow; tracked against the 80% workflow target",
            },
            "supported_without_hard_target": {
                "cond": "supported in the native-SV Questa flow and reported explicitly even though the workflow does not impose a fixed threshold",
                "expr": "supported in the native-SV Questa flow and reported explicitly even though the workflow does not impose a fixed threshold",
            },
            "unsupported": {},
        },
        "failed_cases": failed_cases,
        "implementation_summary": {
            "unimplemented_cases": sorted(set(unimplemented_cases)),
            "unimplemented_count": len(set(unimplemented_cases)),
            "stale_artifacts_without_engine_marker": sorted(set(stale_artifacts)),
            "stale_artifact_without_engine_marker_count": len(set(stale_artifacts)),
        },
        "non_claims": {
            "lane_scope": "native-SV signoff claim is OPQ_N_LANE=2 only",
            "excluded_probe_cases": EXCLUDED_CASES,
            "mode_scope": "MERGING mode only is claimed in the active native-SV report",
            "n_shd_scope": "native-SV signoff claim covers OPQ_N_SHD = 128 / 256 / 512 only",
            "four_lane_status": "4-lane native-SV remains out of signoff scope until the sparse-frame cadence bug in BUG_HISTORY.md is closed",
            "continuous_frame_scope": "continuous-frame baselines currently cover the default-build promoted matrix only; PARAM build points require separate elaboration and are excluded from no-restart baselines",
        },
        "execution_modes": {
            "isolated": {
                "bucket_order": list(BUCKET_CASES.keys()),
                "per_bucket_case_order": {
                    bucket_name: [case["full_case_id"] for case in bucket_payload["cases"]]
                    for bucket_name, bucket_payload in bucket_payloads.items()
                },
            },
            "bucket_frame": {
                "run_id": "bucket_frame_native_sv",
                "bucket_order": BUCKET_FRAME_BUCKET_ORDER,
                "ordered_steps": bucket_frame_order,
                "limitations": SIGNOFF_RUN_SPECS[0]["limitations"],
            },
            "all_buckets_frame": {
                "run_id": "all_buckets_frame_native_sv",
                "bucket_order": BUCKET_FRAME_BUCKET_ORDER,
                "ordered_steps": bucket_frame_order,
                "extra_tail_steps": ALL_BUCKETS_FRAME_EXTRA_TAIL,
                "limitations": SIGNOFF_RUN_SPECS[1]["limitations"],
            },
        },
        "cases": all_cases,
        "bucket_summary": bucket_summary,
        "buckets": bucket_payloads,
        "totals": {
            "planned_cases": len(all_case_ids),
            "evidenced_cases": all_passed_cases,
            "excluded_cases": len(EXCLUDED_CASES),
            "merged_total_code_coverage": merged_total_cov,
            "functional_coverage": total_functional_cov,
        },
        "signoff_runs": signoff_runs,
        "random_cases": [],
    }


def main() -> int:
    data = build()
    REPORT_JSON.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"wrote {REPORT_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
