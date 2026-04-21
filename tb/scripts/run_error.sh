#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_error.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_error_lane_mask_test \
    opq_error_lane_mask_single_hit_test \
    opq_error_lane_mask_burst_test \
    opq_error_lane_mask_recovery_test \
    opq_error_hit_mask_recovery_test \
    opq_error_subheader_mask_recovery_test \
    opq_error_header_mask_recovery_test \
    opq_error_header_word_mask_recovery_test \
    opq_error_counter_clear_test
fi

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "$@"
