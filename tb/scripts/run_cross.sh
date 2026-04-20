#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_cross.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_cross_bp_credit_test \
    opq_cross_drr_allowance_test \
    opq_cross_drr_idle_lane_test \
    opq_cross_drr_zero_allowance_test \
    opq_cross_drr_short_allowance_test \
    opq_cross_idle_lane_backpressure_test
fi

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "$@"
