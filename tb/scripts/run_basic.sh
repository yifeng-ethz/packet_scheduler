#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"
RUN_SET="${RUN_SET:-canonical}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_basic.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  if [[ "${RUN_SET}" == "promoted" ]]; then
    set -- \
      opq_basic_smoke_test \
      opq_basic_ts_boundary_test \
      opq_basic_subheader_shape_test \
      opq_basic_feb_packet_contract_test \
      opq_basic_single_active_lane_test \
      opq_basic_single_active_lane_lane1_test \
      opq_basic_single_active_lane_dense_test
  else
    mapfile -t CASE_IDS < <(python3 "${SCRIPT_DIR}/opq_catalog.py" --bucket BASIC --ids)
    set -- "${CASE_IDS[@]}"
  fi
fi

if [[ " ${VSIM_PLUSARGS:-} " != *" +OPQ_STRICT_PACKET_FORMAT "* ]]; then
  VSIM_PLUSARGS="${VSIM_PLUSARGS:-} +OPQ_STRICT_PACKET_FORMAT"
fi
export VSIM_PLUSARGS

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "$@"
