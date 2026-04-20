#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUT_IMPL="${DUT_IMPL:-native_sv}"

if [[ "${DUT_IMPL}" != "native_sv" ]]; then
  echo "run_perf.sh only supports DUT_IMPL=native_sv (got ${DUT_IMPL})" >&2
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  set -- \
    opq_prof_stress_test \
    opq_prof_lane_skew_test \
    opq_prof_whole_frame_skew_test \
    opq_prof_missing_empty_frame_test \
    opq_prof_long_soak_test \
    opq_prof_heavy_lane_skew_test \
    opq_prof_deep_whole_frame_skew_test \
    opq_prof_asymmetric_missing_empty_frame_test
fi

DUT_IMPL="${DUT_IMPL}" "${SCRIPT_DIR}/run_uvm.sh" "$@"
