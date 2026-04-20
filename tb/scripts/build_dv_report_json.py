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
LEGACY_TB_DIR = TB_DIR / "legacy" / "tb"

INSTANCE_HOLE_SPECS = [
    {
        "area": "Ingress parser recovery states",
        "instance_paths": [
            "/tb_top/gen_dut_2lane/dut/u_native/g_ingress_parser[0]/ingress_parser_i",
            "/tb_top/gen_dut_2lane/dut/u_native/g_ingress_parser[1]/ingress_parser_i",
        ],
        "classification": "real gap",
        "reason": (
            "The promoted header-error and header-word recovery cases now exercise "
            "the repaired parser re-entry path, but MASK_PKT_EXTENDED cleanup and "
            "the broader malformed-header recovery state space still sit below the "
            "merged signoff targets."
        ),
        "evidence_anchor": (
            "ordered_priority_queue_monolithic_ingress_parser.sv:305-320, 409-410; "
            "BUG-005-R / BUG-010-R; "
            "opq_error_header_mask_recovery_test, opq_error_header_word_mask_recovery_test"
        ),
        "next_action": (
            "Keep the header-recovery cases in the promoted ERROR bucket and add "
            "more chained malformed-header variants only if parser recovery "
            "coverage remains the limiting closure gap."
        ),
    },
    {
        "area": "Allocator and DRR transition space",
        "instance_paths": [
            "/tb_top/gen_dut_2lane/dut/u_native/page_allocator_i",
            "/tb_top/gen_dut_2lane/dut/u_native/block_path_i",
        ],
        "classification": "real gap",
        "reason": (
            "The remaining low FSM-transition coverage still lines up with the "
            "bursty DRR large-random screen, which re-opened hit-accounting loss "
            "on the latest native-SV rerun, plus the lack of dedicated signed-off "
            "4-lane DV evidence."
        ),
        "evidence_anchor": (
            "BUG-009-R; opq_cross_drr_bursty_random_test; "
            "opq_prof_missing_empty_frame_test @ OPQ_N_LANE=4; "
            "doc/SIGNOFF.md standalone_syn"
        ),
        "next_action": (
            "Keep the bursty DRR large-random screen probe-only, root-cause the "
            "remaining lane0 unexplained-hit loss, and record real 4-lane DV plus "
            "A10 standalone closure before expanding the signoff claim."
        ),
    },
    {
        "area": "Presenter flush/backpressure hybrids",
        "instance_paths": [
            "/tb_top/gen_dut_2lane/dut/u_native/presenter_i",
        ],
        "classification": "real gap",
        "reason": (
            "The new default-build pre-drop boundary screen now closes the "
            "\"must not drop\" half of the presenter/backpressure space, but the "
            "suite still lacks a complementary signed-off default-build hybrid "
            "that advances frame-table drop counters without falling back to the "
            "reduced-depth elaboration point."
        ),
        "evidence_anchor": (
            "ordered_priority_queue_monolithic_basic_presenter.sv:128-145, 165-188; "
            "DV_FORMAL.md B27/B28; CORNER_OPQ_409_error_ftable_overflow_test; "
            "opq_cross_bp_predrop_boundary_test"
        ),
        "next_action": (
            "Keep the reduced-depth overwrite point as the current must-drop proof, "
            "use opq_cross_bp_predrop_boundary_test as the default-build legal "
            "pre-drop proof, and only promote a default-build must-drop hybrid once "
            "it can advance ft_drop_* cleanly with no malformed accepted egress."
        ),
    },
    {
        "area": "Native wrapper fixed-scope decode paths",
        "instance_paths": [
            "/tb_top/gen_dut_2lane/dut/u_native",
            "/tb_top/gen_dut_2lane/dut",
        ],
        "classification": "justified exclusion",
        "reason": (
            "A large part of the wrapper hole count comes from fixed-scope native-SV "
            "configuration, dormant CSR decode/default branches, and status/meta "
            "observability that are outside the active 2-lane signoff claim."
        ),
        "evidence_anchor": (
            "ordered_priority_queue_dut_sv.sv:227-245, 268-337, 494-505; "
            "DV_REPORT non-claims for OPQ_N_LANE=2 and the reduced-depth supplemental overflow point"
        ),
        "next_action": (
            "Keep the wrapper holes documented as non-claims unless a dedicated CSR "
            "decode sweep becomes a signoff requirement."
        ),
    },
    {
        "area": "FIFO and page-RAM data-bit toggles",
        "instance_paths": [
            "/tb_top/gen_dut_2lane/dut/u_native/g_storage[0]/ticket_fifo_i",
            "/tb_top/gen_dut_2lane/dut/u_native/g_storage[0]/lane_fifo_i",
            "/tb_top/gen_dut_2lane/dut/u_native/g_storage[0]/handle_fifo_i",
            "/tb_top/gen_dut_2lane/dut/u_native/g_storage[1]/ticket_fifo_i",
            "/tb_top/gen_dut_2lane/dut/u_native/g_storage[1]/lane_fifo_i",
            "/tb_top/gen_dut_2lane/dut/u_native/g_storage[1]/handle_fifo_i",
            "/tb_top/gen_dut_2lane/dut/u_native/page_ram_i",
        ],
        "classification": "redundant case",
        "reason": (
            "The lowest remaining toggle bins are wide storage-array data bits. "
            "Extra fill-pattern tests would mostly churn memory bit coverage without "
            "closing a new architectural contract."
        ),
        "evidence_anchor": (
            "ticket_fifo / lane_fifo / handle_fifo / page_ram toggle summaries in the "
            "merged native-SV UCDB"
        ),
        "next_action": (
            "Do not promote memory-bit churn tests for signoff; only revisit if a "
            "real storage-corruption bug appears."
        ),
    },
]

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
    page_ram_depth: int = 65536,
    effort: str = "practical",
    method: str = "D",
    observed_txn: int = 1,
) -> dict:
    ticket_fifo_depth = 256
    while ticket_fifo_depth <= n_shd:
        ticket_fifo_depth *= 2
    return {
        "case_id": name,
        "full_case_id": name,
        "method": method,
        "observed_txn": observed_txn,
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
            "OPQ_PAGE_RAM_DEPTH": page_ram_depth,
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
                case_entry(
                    "opq_basic_single_active_lane_test",
                    "Only one active hit-producing lane while the peer lane still emits legal empty-frame cadence.",
                    "Hit integrity and credit restore with asymmetric legal FEB frame cadence.",
                    "DV_BASIC single-active-lane closure.",
                ),
                case_entry(
                    "opq_basic_single_active_lane_lane1_test",
                    "Only lane 1 produces hits while lane 0 remains on legal empty-frame cadence.",
                    "Hit integrity and credit restore when the non-default active lane owns all live traffic.",
                    "DV_BASIC single-active-lane lane-1 closure.",
                ),
                case_entry(
                    "opq_basic_single_active_lane_dense_test",
                    "Denser single-lane subheader packing on the healthy no-drop path.",
                    "Single-lane hit integrity under deeper subheader occupancy without introducing legal drops.",
                    "DV_BASIC dense single-lane closure.",
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
                case_entry(
                    "opq_edge_burst_restart_profile_test",
                    "Burstier legal ready restart profile with shorter ready windows and deeper low stretches.",
                    "Presenter hold/restart behavior across repeated medium-depth stall bursts.",
                    "DV_EDGE burst-restart profile closure.",
                ),
                case_entry(
                    "opq_edge_long_toggle_backpressure_test",
                    "Extended one-cycle ready toggling deep enough to revisit repeated presenter restart edges.",
                    "Longer toggle-driven restart stress without crossing into overwrite forcing.",
                    "DV_EDGE long-toggle closure.",
                ),
                case_entry(
                    "opq_edge_max_hits_backpressure_test",
                    "Maximum-hit packet shape crossed with legal periodic backpressure.",
                    "Hit preservation and presenter restart when the widest healthy packet shape meets repeated stalls.",
                    "DV_EDGE max-hit x backpressure closure.",
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
                case_entry(
                    "opq_prof_long_soak_test",
                    "Longer directed FEB whole-frame soak on the default 2-lane native-SV path.",
                    "Sustained hit integrity and clean credit restore beyond the short promoted soak.",
                    "DV_PROF extended directed soak closure.",
                ),
                case_entry(
                    "opq_prof_heavy_lane_skew_test",
                    "Heavier deterministic two-lane skew with the same healthy no-drop contract.",
                    "Sustained hit integrity under a wider active-lane skew gap than the base promoted case.",
                    "DV_PROF heavy lane-skew closure.",
                ),
                case_entry(
                    "opq_prof_deep_whole_frame_skew_test",
                    "Deeper whole-frame skew residency with reduced subheader density.",
                    "Longer packet-level cadence skew while preserving hit integrity and legal frame ordering.",
                    "DV_PROF deep whole-frame skew closure.",
                ),
                case_entry(
                    "opq_prof_asymmetric_missing_empty_frame_test",
                    "Explicit 2-lane asymmetry in whole-frame counts instead of relying on the shared 4-lane default stress shape.",
                    "Sparse-frame cadence accounting and hit integrity under directed asymmetric lane residency.",
                    "DV_PROF asymmetric missing-empty-frame closure.",
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
                    "opq_error_header_mask_recovery_test",
                    "Inject a malformed preamble/header, then follow with a legal recovery frame on both active lanes.",
                    "Header-error suppression without stale timestamp context leaking into the next legal FEB packet.",
                    "DV_ERROR malformed-header recovery closure.",
                ),
                case_entry(
                    "opq_error_header_word_mask_recovery_test",
                    "Inject a header-word error, then follow with a legal recovery frame on both active lanes.",
                    "Header-word suppression without corrupting the next legal frame timestamp base.",
                    "DV_ERROR header-word recovery closure.",
                ),
                case_entry(
                    "opq_error_counter_clear_test",
                    "Runtime counter clear after drop-producing traffic.",
                    "Visible CSR counter reset semantics and post-clear clean state.",
                    "DV_ERROR counter-clear closure.",
                ),
                case_entry(
                    "opq_error_ftable_overflow_test",
                    "Reduced-depth overwrite pressure under hard egress stall on the native-SV presenter path.",
                    "Frame-table drop counters increment, overwritten residents are suppressed, and no malformed accepted egress escapes under overwrite pressure.",
                    "DV_ERROR reduced-depth overwrite / flush-atomicity closure.",
                    page_ram_depth=512,
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
                case_entry(
                    "opq_cross_idle_lane_backpressure_test",
                    "One hit-idle lane crossed with periodic egress stalls on the active lane.",
                    "Idle-lane cadence preservation and clean restart behavior under backpressure.",
                    "DV_CROSS idle-lane cadence x backpressure closure.",
                ),
                case_entry(
                    "opq_cross_mixed_bucket_random_soak_test",
                    "Random mixed-bucket soak that draws safe directed scenarios from BASIC, EDGE, PROF, ERROR, and CROSS.",
                    "Multi-bucket chained hit integrity, bucket visitation, and no-restart drain stability under randomized sequencing.",
                    "DV_CROSS mixed-bucket random soak closure.",
                    effort="high",
                    method="R",
                    observed_txn=128,
                ),
                case_entry(
                    "opq_cross_drr_bursty_frame2_boundary_test",
                    "Deterministic bursty DRR boundary at the last green frame_count=2 envelope below the active retirement failure.",
                    "Named green-side DRR boundary where the hot-lane/cold-lane asymmetry still closes with complete hit conservation and no ghost hits.",
                    "DV_CROSS bursty DRR green-side boundary evidence.",
                    effort="high",
                ),
                case_entry(
                    "opq_cross_random_ready_overflow_step2_boundary_test",
                    "Two-step default-build random-ready overflow boundary in shape-check mode.",
                    "The first two overflow windows stay legal with ft_drop counters at zero, wr = rd + drop closed at each checkpoint, and no incomplete accepted packets.",
                    "DV_CROSS legal default-build overflow boundary evidence.",
                    effort="high",
                    method="R",
                    observed_txn=2,
                ),
            ],
        ),
    ]
)

EXCLUDED_CASES = [
    "opq_cross_drr_bursty_random_test",
]

CATALOG_SOURCES = {
    "BASIC": {
        "source": LEGACY_TB_DIR / "DV_BASIC.md",
        "mode": "table_rows",
        "pattern": r"^\|\s+[A-Z]\d+",
        "summary": "Archived directed BASIC catalog preserved in tb/legacy/tb/DV_BASIC.md.",
    },
    "PARAM": {
        "source": TB_DIR / "DV_PARAM.md",
        "mode": "derived_matrix",
        "count": 180,
        "summary": "Derived compile/elaboration matrix inventory: 3 testcase families x 3 N_SHD points x 5 N_LANE points x 2 MODE points x 2 TRACK_HEADER points.",
    },
    "EDGE": {
        "source": LEGACY_TB_DIR / "DV_EDGE.md",
        "mode": "table_rows",
        "pattern": r"^\|\s+[A-Z]\d+",
        "summary": "Archived directed EDGE catalog preserved in tb/legacy/tb/DV_EDGE.md.",
    },
    "PROF": {
        "source": LEGACY_TB_DIR / "DV_PROF.md",
        "mode": "table_rows",
        "pattern": r"^\|\s+[A-Z]\d+",
        "summary": "Archived directed PROF catalog preserved in tb/legacy/tb/DV_PROF.md.",
    },
    "ERROR": {
        "source": LEGACY_TB_DIR / "DV_ERROR.md",
        "mode": "table_rows",
        "pattern": r"^\|\s+[A-Z]\d+",
        "summary": "Archived directed ERROR catalog preserved in tb/legacy/tb/DV_ERROR.md.",
    },
    "CROSS": {
        "source": LEGACY_TB_DIR / "DV_CROSS.md",
        "mode": "heading_rows",
        "pattern": r"^###\s+[A-Z]\d{3}\b",
        "summary": "Archived chained CROSS catalog preserved in tb/legacy/tb/DV_CROSS.md.",
    },
}

BUCKET_FRAME_BUCKET_ORDER = ["BASIC", "EDGE", "PROF", "ERROR", "CROSS"]
BUCKET_FRAME_LEGACY_ORDER = [
    ("BASIC", "opq_basic_smoke_test"),
    ("BASIC", "opq_basic_ts_boundary_test"),
    ("BASIC", "opq_basic_feb_packet_contract_test"),
    ("BASIC", "opq_basic_subheader_shape_test"),
    ("BASIC", "opq_basic_single_active_lane_test"),
    ("BASIC", "opq_basic_single_active_lane_lane1_test"),
    ("BASIC", "opq_basic_single_active_lane_dense_test"),
    ("EDGE", "opq_edge_backpressure_test"),
    ("EDGE", "opq_edge_always_ready_test"),
    ("EDGE", "opq_edge_ready_medium_profile_test"),
    ("EDGE", "opq_edge_burst_restart_profile_test"),
    ("EDGE", "opq_edge_stuck_low_backpressure_test"),
    ("EDGE", "opq_edge_max_hits_test"),
    ("EDGE", "opq_edge_toggle_backpressure_test"),
    ("EDGE", "opq_edge_long_toggle_backpressure_test"),
    ("EDGE", "opq_edge_max_hits_backpressure_test"),
    ("PROF", "opq_prof_stress_test"),
    ("PROF", "opq_prof_lane_skew_test"),
    ("PROF", "opq_prof_whole_frame_skew_test"),
    ("PROF", "opq_prof_missing_empty_frame_test"),
    ("PROF", "opq_prof_long_soak_test"),
    ("PROF", "opq_prof_heavy_lane_skew_test"),
    ("PROF", "opq_prof_deep_whole_frame_skew_test"),
    ("PROF", "opq_prof_asymmetric_missing_empty_frame_test"),
    ("ERROR", "opq_error_lane_mask_test"),
    ("ERROR", "opq_error_lane_mask_single_hit_test"),
    ("ERROR", "opq_error_lane_mask_burst_test"),
    ("ERROR", "opq_error_lane_mask_recovery_test"),
    ("ERROR", "opq_error_subheader_mask_recovery_test"),
    ("ERROR", "opq_error_header_mask_recovery_test"),
    ("ERROR", "opq_error_header_word_mask_recovery_test"),
    ("CROSS", "opq_cross_bp_credit_test"),
    ("CROSS", "opq_cross_drr_allowance_test"),
    ("CROSS", "opq_cross_drr_idle_lane_test"),
    ("CROSS", "opq_cross_drr_zero_allowance_test"),
    ("CROSS", "opq_cross_drr_short_allowance_test"),
    ("CROSS", "opq_cross_idle_lane_backpressure_test"),
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

SIGNOFF_CASE_COUNT = len(BUCKET_FRAME_LEGACY_ORDER)
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
            "opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic.",
            "opq_cross_drr_bursty_frame2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the last known green bursty DRR envelope below the open frame_count=3 retirement failure.",
            "opq_cross_bp_predrop_boundary_test is tracked as a dedicated supplemental signoff run because it proves the default-build legal pre-drop boundary under sustained backpressure rather than a promoted fixed bucket-frame case.",
            "opq_cross_random_ready_overflow_step2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the current green two-step legal-overflow boundary while the later must-drop path remains probe-only.",
            "opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run.",
            "opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.",
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
            "opq_cross_mixed_bucket_random_soak_test is tracked as a dedicated supplemental signoff run; this fixed baseline remains case-ordered and deterministic.",
            "opq_cross_drr_bursty_frame2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the last known green bursty DRR envelope below the open frame_count=3 retirement failure.",
            "opq_cross_bp_predrop_boundary_test is tracked as a dedicated supplemental signoff run because it proves the default-build legal pre-drop boundary under sustained backpressure rather than a promoted fixed bucket-frame case.",
            "opq_cross_random_ready_overflow_step2_boundary_test is tracked as a dedicated supplemental signoff run because it freezes the current green two-step legal-overflow boundary while the later must-drop path remains probe-only.",
            "opq_error_counter_clear_test is tracked as a dedicated supplemental signoff run because it intentionally clears live CSR counters mid-run.",
            "opq_error_ftable_overflow_test is tracked as a dedicated supplemental signoff run because its reduced-depth OPQ_PAGE_RAM_DEPTH=512 build point requires separate elaboration.",
            f"This run appends two extra tail sequences after the {SIGNOFF_CASE_COUNT} promoted default-build cases; those tail sequences are stress-only and are not counted as separate promoted cases.",
        ],
    },
    {
        "run_id": "mixed_bucket_random_soak_native_sv",
        "test_name": "opq_cross_mixed_bucket_random_soak_test",
        "kind": "mixed_bucket_random_soak",
        "build_tag": "native_sv",
        "bucket": "CROSS",
        "sequence_name": "OPQ_MIXED_BUCKET_RANDOM_SOAK",
        "case_count": 1,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "This is a supplemental signoff run, not the fixed bucket-frame baseline; execution order is intentionally seed-driven rather than case-id ordered.",
            "The run reuses only already-promoted safe bucket slices so it can stress chained no-restart behavior without reopening known probe-only bursty DRR loss.",
        ],
    },
    {
        "run_id": "drr_bursty_frame2_boundary_native_sv",
        "test_name": "opq_cross_drr_bursty_frame2_boundary_test",
        "kind": "drr_bursty_frame2_boundary",
        "build_tag": "native_sv",
        "bucket": "CROSS",
        "sequence_name": "OPQ_DRR_BURSTY_FRAME2_BOUNDARY",
        "case_count": 1,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "This is a supplemental signoff run that freezes the largest green bursty DRR envelope below the open frame_count=3 active-lane retirement failure.",
            "It is intentionally tracked outside the promoted fixed bucket-frame baselines because the larger bursty DRR probe family remains open.",
        ],
    },
    {
        "run_id": "bp_predrop_boundary_native_sv",
        "test_name": "opq_cross_bp_predrop_boundary_test",
        "kind": "bp_predrop_boundary",
        "build_tag": "native_sv",
        "bucket": "CROSS",
        "sequence_name": "OPQ_BP_PREDROP_BOUNDARY",
        "case_count": 1,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "This is a supplemental signoff run that proves the default-build legal pre-drop boundary under sustained backpressure while keeping frame-table drop counters at zero.",
            "The testcase intentionally stages a mild no-drop phase followed by a heavier pressure phase, so it is tracked outside the promoted fixed bucket-frame baselines.",
        ],
    },
    {
        "run_id": "overflow_step2_boundary_native_sv",
        "test_name": "opq_cross_random_ready_overflow_step2_boundary_test",
        "kind": "overflow_step2_boundary",
        "build_tag": "native_sv",
        "bucket": "CROSS",
        "sequence_name": "OPQ_OVERFLOW_STEP2_BOUNDARY",
        "case_count": 1,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "This is a supplemental signoff run that freezes the current green two-step legal-overflow boundary on the default build with ft_drop counters held at zero.",
            "It does not close the later must-drop path; the longer random-ready overflow soak remains probe-only until the presenter overwrite accounting bug is fixed.",
        ],
    },
    {
        "run_id": "error_counter_clear_native_sv",
        "test_name": "opq_error_counter_clear_test",
        "kind": "error_counter_clear",
        "build_tag": "native_sv",
        "bucket": "ERROR",
        "sequence_name": "OPQ_ERROR_COUNTER_CLEAR",
        "case_count": 1,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "This is a supplemental signoff run that validates CSR zeroization semantics after masked-drop traffic.",
            "The testcase intentionally clears live counters before end-of-run reporting, so it is tracked outside the fixed bucket-frame baselines.",
        ],
    },
    {
        "run_id": "error_ftable_overflow_depth512_native_sv",
        "test_name": "opq_error_ftable_overflow_test",
        "kind": "error_ftable_overflow_depth512",
        "build_tag": "native_sv_depth512",
        "bucket": "ERROR",
        "sequence_name": "OPQ_ERROR_FTABLE_OVERFLOW_DEPTH512",
        "case_count": 1,
        "effort": "practical",
        "iter_cap": None,
        "payload_cap": None,
        "limitations": [
            "This is a supplemental signoff run that intentionally uses OPQ_PAGE_RAM_DEPTH=512 to force the overwrite / frame-table-drop path.",
            "Because it requires a separate elaboration point, it cannot be folded into the fixed default-build no-restart baselines.",
        ],
    },
]


def run_cmd(*args: str) -> str:
    proc = subprocess.run(args, check=True, text=True, capture_output=True)
    return proc.stdout


def relpath_from_tb(path: Path) -> str:
    return path.relative_to(TB_DIR).as_posix()


def load_catalog_inventory() -> dict[str, dict]:
    inventory: dict[str, dict] = {}
    for bucket_name, spec in CATALOG_SOURCES.items():
        source = spec["source"]
        mode = spec["mode"]
        if mode == "derived_matrix":
            count = int(spec["count"])
        else:
            text = source.read_text(encoding="utf-8")
            count = len(re.findall(spec["pattern"], text, flags=re.MULTILINE))
        inventory[bucket_name] = {
            "count": count,
            "source": relpath_from_tb(source),
            "summary": spec["summary"],
        }
    return inventory


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


def instance_cov_for_ucdb(ucdb: Path) -> dict[str, dict]:
    text = run_cmd(str(VCOVER), "report", "-codeAll", f"-instance={INSTANCE_FILTER}", str(ucdb))
    instance_cov: dict[str, dict] = {}
    current_instance: str | None = None
    metric_re = re.compile(
        r"^\s*(Branches|Conditions|Expressions|FSM States|FSM Transitions|Statements|Toggles)\s+"
        r"(\d+)\s+(\d+)\s+(\d+)\s+([0-9.]+)%"
    )
    for line in text.splitlines():
        inst_match = re.match(r"^=== Instance: (.+)$", line)
        if inst_match:
            current_instance = inst_match.group(1).strip()
            instance_cov.setdefault(current_instance, {"design_unit": None, "metrics": {}})
            continue
        du_match = re.match(r"^=== Design Unit: (.+)$", line)
        if du_match and current_instance is not None:
            instance_cov[current_instance]["design_unit"] = du_match.group(1).strip()
            continue
        metric_match = metric_re.match(line)
        if metric_match and current_instance is not None:
            metric = METRIC_MAP[metric_match.group(1)]
            instance_cov[current_instance]["metrics"][metric] = {
                "bins": int(metric_match.group(2)),
                "hits": int(metric_match.group(3)),
                "misses": int(metric_match.group(4)),
                "pct": round(float(metric_match.group(5)), 2),
            }
    return instance_cov


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


def scale_cov_per_txn(cov: dict, txn_count: int) -> dict:
    denom = max(int(txn_count), 1)
    return {
        metric: {"pct": round(values.get("pct", 0.0) / denom, 4)}
        for metric, values in cov.items()
    }


def zero_cov() -> dict:
    return {metric: {"pct": 0.0} for metric in METRIC_MAP.values()}


def summarize_instance_group(instance_cov: dict[str, dict], instance_paths: list[str]) -> dict:
    selected = [instance_cov[path] for path in instance_paths if path in instance_cov]
    summary_metrics: dict[str, float] = {}
    for metric in METRIC_MAP.values():
        metric_values = [
            payload["metrics"].get(metric, {}).get("pct")
            for payload in selected
            if payload.get("metrics", {}).get(metric) is not None
        ]
        metric_values = [value for value in metric_values if value is not None]
        if metric_values:
            summary_metrics[metric] = round(min(metric_values), 2)
    return {
        "instance_count": len(selected),
        "instances": [path for path in instance_paths if path in instance_cov],
        "metrics": summary_metrics,
    }


def build_coverage_hole_disposition(merged_total_ucdb: Path | None) -> list[dict]:
    if merged_total_ucdb is None or not merged_total_ucdb.is_file():
        return []

    instance_cov = instance_cov_for_ucdb(merged_total_ucdb)
    disposition: list[dict] = []
    for spec in INSTANCE_HOLE_SPECS:
        group_summary = summarize_instance_group(instance_cov, spec["instance_paths"])
        if not group_summary["instances"]:
            continue
        disposition.append(
            {
                "area": spec["area"],
                "classification": spec["classification"],
                "reason": spec["reason"],
                "evidence_anchor": spec["evidence_anchor"],
                "next_action": spec["next_action"],
                "instance_summary": group_summary,
            }
        )
    return disposition


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


def extract_log_summary(log_path: Path) -> tuple[bool, bool, bool, dict]:
    if not log_path.is_file():
        return False, False, False, {}

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

    mixed_soak_steps = [
        int(match.group(1))
        for match in re.finditer(r"Mixed-soak step (\d+) selected bucket", text)
    ]
    if mixed_soak_steps:
        summary["random_txn"] = max(mixed_soak_steps) + 1

    return True, engine_ok, pass_ok, summary


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
        log_exists, engine_ok, pass_ok, log_summary = extract_log_summary(log_path)
        has_ucdb = ucdb_path is not None
        functional_cov = {"pct": 0.0, "evidenced": 0, "planned": 0}
        code_cov = {}

        if has_ucdb:
            code_cov = flatten_pct(code_cov_for_ucdb(ucdb_path))
            functional_cov = functional_cov_for_ucdb(ucdb_path)

        hit_missing = int(log_summary.get("hit_missing", 0))
        hit_ghost = int(log_summary.get("hit_ghost", 0))
        txns = int(log_summary.get("lane0_monitored_frames", 0)) + int(log_summary.get("lane1_monitored_frames", 0))
        failures = 0 if (log_exists and engine_ok and pass_ok and has_ucdb and hit_missing == 0 and hit_ghost == 0) else 1

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

    catalog_inventory = load_catalog_inventory()
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
    total_catalog_cases = 0

    global_merged_cov_before: dict | None = None

    for bucket_name, cases in BUCKET_CASES.items():
        bucket_catalog = catalog_inventory[bucket_name]
        promoted_cases = len(cases)
        total_catalog_cases += bucket_catalog["count"]
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
            log_exists, engine_ok, pass_ok, log_summary = extract_log_summary(log_path)
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
            case["passed"] = pass_ok
            case["log_summary"] = log_summary
            case["standalone_coverage"] = flatten_pct(standalone_cov)
            if case.get("method") == "R":
                case["observed_txn"] = int(log_summary.get("random_txn", case.get("observed_txn", 1)) or 1)
                case["isolated_cov_per_txn"] = scale_cov_per_txn(standalone_cov, case["observed_txn"])
            else:
                case["observed_txn"] = int(case.get("observed_txn", 1) or 1)
                case["isolated_cov_per_txn"] = flatten_pct(standalone_cov)

            if pass_ok:
                evidenced_cases += 1
                bucket_ucdbs.append(ucdb_path)
                merged_after = code_cov_for_ucdb(
                    merge_ucdb(WORK_DIR / f"{bucket_name.lower()}_{step}.ucdb", bucket_ucdbs)
                )
                case["bucket_gain_by_case"] = cov_delta(merged_after, bucket_merged_cov_before)
                case["bucket_merged_total_after_case"] = flatten_pct(merged_after)
                if case.get("method") == "R":
                    case["bucket_gain_per_txn"] = scale_cov_per_txn(case["bucket_gain_by_case"], case["observed_txn"])
                else:
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
                if case.get("method") == "R":
                    case["bucket_gain_per_txn"] = scale_cov_per_txn(case["bucket_gain_by_case"], case["observed_txn"])
                else:
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
            "planned_cases": promoted_cases,
            "catalog_planned_cases": bucket_catalog["count"],
            "catalog_pending_cases": max(bucket_catalog["count"] - promoted_cases, 0),
            "catalog_source": bucket_catalog["source"],
            "catalog_summary": bucket_catalog["summary"],
            "promoted_cases": promoted_cases,
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
                "planned_cases": promoted_cases,
                "catalog_planned_cases": bucket_catalog["count"],
                "catalog_pending_cases": max(bucket_catalog["count"] - promoted_cases, 0),
                "catalog_source": bucket_catalog["source"],
                "catalog_summary": bucket_catalog["summary"],
                "promoted_cases": promoted_cases,
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
    merged_total_ucdb: Path | None = None
    if all_passed_ucdbs:
        merged_total_ucdb = merge_ucdb(WORK_DIR / "all_buckets_merged.ucdb", all_passed_ucdbs)
        total_functional_cov = functional_cov_for_ucdb(merged_total_ucdb)
        total_functional_cov["evidenced"] = all_passed_cases
        total_functional_cov["planned"] = len(all_case_ids)
    coverage_hole_disposition = build_coverage_hole_disposition(merged_total_ucdb)

    signoff_runs = build_signoff_runs()
    signoff_spec_by_run_id = {spec["run_id"]: spec for spec in SIGNOFF_RUN_SPECS}
    bucket_frame_order = [
        {
            "bucket": bucket_name,
            "report_case_id": report_case_id_by_legacy[legacy_name],
            "legacy_test_name": legacy_name,
        }
        for bucket_name, legacy_name in BUCKET_FRAME_LEGACY_ORDER
    ]
    mixed_bucket_random_soak_order = [
        {
            "bucket": "CROSS",
            "report_case_id": report_case_id_by_legacy["opq_cross_mixed_bucket_random_soak_test"],
            "legacy_test_name": "opq_cross_mixed_bucket_random_soak_test",
        }
    ]
    drr_bursty_frame2_boundary_order = [
        {
            "bucket": "CROSS",
            "report_case_id": report_case_id_by_legacy["opq_cross_drr_bursty_frame2_boundary_test"],
            "legacy_test_name": "opq_cross_drr_bursty_frame2_boundary_test",
        }
    ]
    overflow_step2_boundary_order = [
        {
            "bucket": "CROSS",
            "report_case_id": report_case_id_by_legacy["opq_cross_random_ready_overflow_step2_boundary_test"],
            "legacy_test_name": "opq_cross_random_ready_overflow_step2_boundary_test",
        }
    ]
    error_counter_clear_order = [
        {
            "bucket": "ERROR",
            "report_case_id": report_case_id_by_legacy["opq_error_counter_clear_test"],
            "legacy_test_name": "opq_error_counter_clear_test",
        }
    ]
    error_ftable_overflow_order = [
        {
            "bucket": "ERROR",
            "report_case_id": report_case_id_by_legacy["opq_error_ftable_overflow_test"],
            "legacy_test_name": "opq_error_ftable_overflow_test",
        }
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
        "catalog_inventory": catalog_inventory,
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
            "four_lane_status": "4-lane native-SV remains out of signoff scope until dedicated 4-lane DV evidence is promoted; the standalone Arria 10 synthesis result is now recorded separately in signoff",
            "bursty_drr_probe_status": "the named green-side companion opq_cross_drr_bursty_frame2_boundary_test now passes with expected=298 actual=298 missing=0 ghost=0, but the reduced deterministic opq_cross_drr_bursty_frame3_repro_test still fails with expected=484 actual=254 missing=230 ghost=0 and the full 8-frame screen still fails with lane0 unexplained=368; the larger failure family remains probe-only",
            "mixed_bucket_seconds_probe_status": "the exact 183..190 reproducer is green, and the full stretched mixed-bucket seconds soak now also passes end to end on the repaired allocator state; the screen remains probe-only because of runtime, not because of a live failure",
            "continuous_frame_scope": "fixed bucket-frame baselines cover the default-build promoted matrix only; dedicated supplemental signoff runs now track mixed-bucket random soak, the bursty DRR frame_count=2 green boundary, the default-build legal pre-drop boundary, the default-build two-step legal overflow boundary, counter-clear semantics, and the reduced-depth overflow build point, while PARAM elaboration points still remain separate",
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
                "limitations": signoff_spec_by_run_id["bucket_frame_native_sv"]["limitations"],
            },
            "all_buckets_frame": {
                "run_id": "all_buckets_frame_native_sv",
                "bucket_order": BUCKET_FRAME_BUCKET_ORDER,
                "ordered_steps": bucket_frame_order,
                "extra_tail_steps": ALL_BUCKETS_FRAME_EXTRA_TAIL,
                "limitations": signoff_spec_by_run_id["all_buckets_frame_native_sv"]["limitations"],
            },
            "mixed_bucket_random_soak": {
                "run_id": "mixed_bucket_random_soak_native_sv",
                "bucket_order": ["CROSS"],
                "ordered_steps": mixed_bucket_random_soak_order,
                "limitations": signoff_spec_by_run_id["mixed_bucket_random_soak_native_sv"]["limitations"],
            },
            "drr_bursty_frame2_boundary": {
                "run_id": "drr_bursty_frame2_boundary_native_sv",
                "bucket_order": ["CROSS"],
                "ordered_steps": drr_bursty_frame2_boundary_order,
                "limitations": signoff_spec_by_run_id["drr_bursty_frame2_boundary_native_sv"]["limitations"],
            },
            "bp_predrop_boundary": {
                "run_id": "bp_predrop_boundary_native_sv",
                "bucket_order": ["CROSS"],
                "limitations": signoff_spec_by_run_id["bp_predrop_boundary_native_sv"]["limitations"],
            },
            "overflow_step2_boundary": {
                "run_id": "overflow_step2_boundary_native_sv",
                "bucket_order": ["CROSS"],
                "ordered_steps": overflow_step2_boundary_order,
                "limitations": signoff_spec_by_run_id["overflow_step2_boundary_native_sv"]["limitations"],
            },
            "error_counter_clear": {
                "run_id": "error_counter_clear_native_sv",
                "bucket_order": ["ERROR"],
                "ordered_steps": error_counter_clear_order,
                "limitations": signoff_spec_by_run_id["error_counter_clear_native_sv"]["limitations"],
            },
            "error_ftable_overflow_depth512": {
                "run_id": "error_ftable_overflow_depth512_native_sv",
                "bucket_order": ["ERROR"],
                "ordered_steps": error_ftable_overflow_order,
                "limitations": signoff_spec_by_run_id["error_ftable_overflow_depth512_native_sv"]["limitations"],
            },
        },
        "cases": all_cases,
        "bucket_summary": bucket_summary,
        "buckets": bucket_payloads,
        "coverage_hole_disposition": coverage_hole_disposition,
        "totals": {
            "planned_cases": len(all_case_ids),
            "catalog_planned_cases": total_catalog_cases,
            "catalog_pending_cases": max(total_catalog_cases - len(all_case_ids), 0),
            "promoted_cases": len(all_case_ids),
            "evidenced_cases": all_passed_cases,
            "excluded_cases": len(EXCLUDED_CASES),
            "merged_total_code_coverage": merged_total_cov,
            "functional_coverage": total_functional_cov,
        },
        "signoff_runs": signoff_runs,
        "random_cases": [case for case in all_cases if case.get("method") == "R"],
    }


def main() -> int:
    data = build()
    REPORT_JSON.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"wrote {REPORT_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
