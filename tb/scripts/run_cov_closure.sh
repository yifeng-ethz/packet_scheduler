#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COV_DIR="${TB_DIR}/sim_runs/coverage"

QUESTA_HOME="${QUESTA_HOME:-/data1/intelFPGA_pro/23.1/questa_fse}"
VCOVER="$(find "${QUESTA_HOME}" -maxdepth 2 -type f -name vcover | head -n1)"

if [[ -z "${VCOVER}" ]]; then
  echo "vcover not found under ${QUESTA_HOME}" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  TESTS=(
    opq_basic_smoke_test
    opq_basic_ts_boundary_test
    opq_basic_feb_packet_contract_test
    opq_basic_subheader_shape_test
    opq_edge_backpressure_test
    opq_edge_always_ready_test
    opq_edge_ready_medium_profile_test
    opq_edge_stuck_low_backpressure_test
    opq_edge_max_hits_test
    opq_edge_toggle_backpressure_test
    opq_prof_stress_test
    opq_prof_lane_skew_test
    opq_prof_whole_frame_skew_test
    opq_prof_missing_empty_frame_test
    opq_error_lane_mask_test
    opq_error_lane_mask_single_hit_test
    opq_error_lane_mask_burst_test
    opq_error_lane_mask_recovery_test
    opq_error_subheader_mask_recovery_test
    opq_error_counter_clear_test
    opq_cross_bp_credit_test
    opq_cross_drr_allowance_test
    opq_cross_drr_idle_lane_test
    opq_cross_drr_zero_allowance_test
    opq_cross_drr_short_allowance_test
  )
else
  TESTS=("$@")
fi

rm -rf "${COV_DIR}"
mkdir -p "${COV_DIR}"

OPQ_N_SHD=256 OPQ_TICKET_FIFO_DEPTH=512 COV_ENABLE=1 DUT_IMPL="${DUT_IMPL:-native_sv}" \
  "${SCRIPT_DIR}/run_uvm.sh" "${TESTS[@]}"
OPQ_N_SHD_LIST=128,512 COV_ENABLE=1 DUT_IMPL="${DUT_IMPL:-native_sv}" "${SCRIPT_DIR}/run_param.sh" \
  opq_basic_smoke_test \
  opq_basic_ts_boundary_test \
  opq_edge_max_hits_test

mapfile -t UCDBS < <(find "${COV_DIR}" -maxdepth 1 -type f -name '*.ucdb' | sort)
if [[ "${#UCDBS[@]}" -eq 0 ]]; then
  echo "No UCDB files produced under ${COV_DIR}" >&2
  exit 1
fi

"${VCOVER}" merge "${COV_DIR}/opq_merged.ucdb" "${UCDBS[@]}"
"${SCRIPT_DIR}/coverage_report.sh" "${COV_DIR}/opq_merged.ucdb"
