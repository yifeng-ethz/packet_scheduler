#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"
RUN_SET="${RUN_SET:-canonical}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_edge.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  if [[ "${RUN_SET}" == "promoted" ]]; then
    set -- \
      opq_edge_backpressure_test \
      opq_edge_always_ready_test \
      opq_edge_ready_medium_profile_test \
      opq_edge_stuck_low_backpressure_test \
      opq_edge_max_hits_test \
      opq_edge_toggle_backpressure_test \
      opq_edge_burst_restart_profile_test \
      opq_edge_long_toggle_backpressure_test \
      opq_edge_max_hits_backpressure_test
  else
    mapfile -t CASE_IDS < <(python3 "${SCRIPT_DIR}/opq_catalog.py" --bucket EDGE --ids)
    set -- "${CASE_IDS[@]}"
  fi
fi

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "$@"
